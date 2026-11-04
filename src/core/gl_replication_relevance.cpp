#include "roblox_network.h"
#include "gl_remote_payload.h"
#include <algorithm>
#include <functional>

namespace {
using namespace GLReplication;
bool Positive(const Variant& Value) { return Value.get_type() == Variant::INT && int64_t(Value) > 0; }
bool NativeCapacity(const Dictionary& Native, size_t Bytes) {
    if (int64_t(Native.get("Version", 0)) != 1) return false;
    const int64_t Packet = int64_t(Bytes) + GLRemotePayload::RpcAllowance;
    const int64_t Fragment = Native.get("UnfragmentedPacketBytes", 0);
    if (Fragment <= 0) return false;
    const int64_t Commands = 2 + (Packet + Fragment - 1) / Fragment;
    auto Fits = [](int64_t Used, int64_t Added, int64_t Limit) { return Used >= 0 && Added >= 0 && Used <= Limit && Added <= Limit - Used; };
    return Fits(Native.get("PeerBytes", -1), Packet, Native.get("PeerByteLimit", 0)) &&
        Fits(Native.get("HostBytes", -1), Packet, Native.get("HostByteLimit", 0)) &&
        Fits(Native.get("PeerCommands", -1), Commands, Native.get("PeerCommandLimit", 0)) &&
        Fits(Native.get("HostCommands", -1), Commands, Native.get("HostCommandLimit", 0));
}
// Existing encoded Instance properties are weak native references. Normalize a
// retired target to nil before forming a new immutable snapshot/dependency set.
bool References(Variant& Value, const std::map<uint64_t, uint64_t>& Live, std::vector<Identity>& Output, int Depth = 0) {
    if (Depth >= GLRemotePayload::MaxDepth) return false;
    if (Value.get_type() == Variant::ARRAY) {
        Array Values = Value;
        for (int Index = 0; Index < Values.size(); ++Index) {
            Variant Item = Values[Index]; if (!References(Item, Live, Output, Depth + 1)) return false; Values[Index] = Item;
        }
    } else if (Value.get_type() == Variant::DICTIONARY) {
        Dictionary Values = Value;
        if (Values.get("__glnet", Variant()) == Variant("inst")) {
            if (!Values.has("id") || Values["id"].get_type() != Variant::INT || int64_t(Values["id"]) < 0) return false;
            uint64_t Id = int64_t(Values["id"]);
            if (!Id) return Values.get("p", Variant()).get_type() == Variant::STRING;
            auto Found = Live.find(Id);
            if (Found == Live.end() || !ObjectDB::get_instance(Found->second)) { Value = Variant(); return true; }
            if (std::find(Output.begin(), Output.end(), Id) == Output.end()) Output.push_back(Id);
            return Output.size() <= Index::MaximumReferences;
        }
        Array Keys = Values.keys();
        for (int Index = 0; Index < Keys.size(); ++Index) {
            Variant Key = Keys[Index];
            Variant Item = Values[Key]; if (!References(Item, Live, Output, Depth + 1)) return false; Values[Key] = Item;
        }
    }
    return true;
}
}

void NetworkService::TouchReplication(uint64_t Id) {
    if (!Replication.Enabled || !Id) return;
    if ((!Replication.Dirty.count(Id) && Replication.Dirty.size() >= GLReplication::Index::MaximumObjects) || Replication.NextRevision == uint64_t(INT64_MAX)) {
        Replication.Failed = true; return;
    }
    if (Replication.Dirty.count(Id) && Replication.Catalog.count(Id) && Replication.Dirty.at(Id) != Replication.Catalog.at(Id).Revision) CountRemote(Replication.Coalesced);
    Replication.Dirty[Id] = ++Replication.NextRevision;
}

bool NetworkService::SetReplicationGlobal(Object* ObjectValue) {
    Node* NodeValue = Object::cast_to<Node>(ObjectValue);
    if (mode != 1 || !is_server() || GLExecutionDomain::IsClientExecution() || !Replication.Enabled ||
        !NodeValue || !NodeValue->has_meta("_gl_netid") || !VisibleRemoteReference(NodeValue)) return false;
    uint64_t Id = int64_t(NodeValue->get_meta("_gl_netid"));
    if (!Id || _rep_node(Id) != NodeValue || Replication.Globals.size() >= GLReplication::Index::MaximumObjects) return false;
    Replication.Globals.insert(Id); TouchReplication(Id); return true;
}

void NetworkService::RestoreReplication() {
    auto& Registry = GLReplication::Registry();
    std::array<uint64_t, 3> Roots{RemoteScopeRoots[0], RemoteScopeRoots[1], RemoteScopeRoots[2]};
    if (Registry.Roots != Roots) { Registry = GLReplication::ServerRegistry(); Registry.Roots = Roots; }
    for (auto Iterator = Registry.Objects.begin(); Iterator != Registry.Objects.end();) {
        auto Value = Object::cast_to<Node>(ObjectDB::get_instance(Iterator->second));
        if (!Value || !Value->is_inside_tree() || !VisibleRemoteReference(Value)) {
            Registry.Globals.erase(Iterator->first); Iterator = Registry.Objects.erase(Iterator);
        } else {
            net_instances[Iterator->first] = Iterator->second;
            if (Registry.Globals.count(Iterator->first)) Replication.Globals.insert(Iterator->first);
            ++Iterator;
        }
    }
}

bool NetworkService::RefreshReplication() {
    using namespace GLReplication;
    struct RefreshObservation {
        State& Value; uint64_t Started;
        ~RefreshObservation() {
            uint64_t Elapsed = Time::get_singleton()->get_ticks_usec() - Started;
            CountRemote(Value.RefreshCalls); CountRemote(Value.RefreshUsec, Elapsed);
            Value.RefreshMaximumUsec = std::max(Value.RefreshMaximumUsec, Elapsed);
        }
    } Observation{Replication, Time::get_singleton()->get_ticks_usec()};
    auto Reject = [&](int Line) { if (!Replication.FailureLine) Replication.FailureLine = Line; return false; };
    for (auto Iterator = net_instances.begin(); Iterator != net_instances.end();) {
        if (!ObjectDB::get_instance(Iterator->second)) Iterator = net_instances.erase(Iterator); else ++Iterator;
    }
    if (net_instances.size() > Index::MaximumObjects) return Reject(__LINE__);
    Index Spatial;
    std::map<Identity, CatalogRecord> Catalog;
    size_t Bytes = 0;
    std::set<Identity> Removed;
    // Verify each captured scope once. A direct child needs only its own
    // exclusion checks; its already verified ancestry cannot differ per child.
    std::array<uint64_t, 3> VisibleRoots{};
    for (size_t Scope = 0; Scope < VisibleRoots.size(); ++Scope)
        if (auto Root = Object::cast_to<Node>(ObjectDB::get_instance(RemoteScopeRoots[Scope])))
            if (VisibleRemoteReference(Root)) VisibleRoots[Scope] = RemoteScopeRoots[Scope];
    for (const auto& Old : Replication.Catalog) if (!net_instances.count(Old.first) || !ObjectDB::get_instance(net_instances.at(Old.first))) Removed.insert(Old.first);
    for (const auto& Entry : net_instances) {
        uint64_t Checkpoint = Time::get_singleton()->get_ticks_usec();
        auto Observe = [&](uint64_t& Total) {
            uint64_t Now = Time::get_singleton()->get_ticks_usec();
            CountRemote(Total, Now - Checkpoint); Checkpoint = Now;
        };
        CountRemote(Replication.RefreshVisited);
        Node* NodeValue = Object::cast_to<Node>(ObjectDB::get_instance(Entry.second));
        if (!NodeValue) continue;
        Node* NativeParent = NodeValue->get_parent();
        // Native components remain constructed and owned by RobloxPart.
        // Exclusion grants nothing, so avoid traversing their visibility path.
        if (Object::cast_to<RobloxPart>(NativeParent) &&
            (NodeValue->is_class("MeshInstance3D") || NodeValue->is_class("CollisionShape3D") || NodeValue->is_class("OccluderInstance3D"))) continue;
        if (!NodeValue->is_inside_tree() || NodeValue->is_queued_for_deletion()) continue;
        uint64_t ParentObject = NativeParent ? uint64_t(NativeParent->get_instance_id()) : 0;
        bool Direct = false;
        for (uint64_t Root : VisibleRoots) if (Root && ParentObject == Root) Direct = true;
        if (Direct) {
            StringName Name = NodeValue->get_name();
            if (Name == StringName("ServerStorage") || Name == StringName("ServerScriptService") ||
                NodeValue->is_class("ServerStorage") || NodeValue->is_class("ServerScriptService")) continue;
        } else if (!VisibleRemoteReference(NodeValue)) continue;
        if (NodeValue->get_script().get_type() != Variant::NIL) return Reject(__LINE__);
        Observe(Replication.RefreshScanUsec);
        CatalogRecord Record;
        Record.Object = Entry.second; Record.Static = gl_is_static_netid(Entry.first);
        Variant NativeReference;
        if (auto Typed = Object::cast_to<RobloxValue>(NodeValue)) if (Typed->roblox_class == "ObjectValue") {
            Variant Stored = Typed->get_value();
            Node* Target = Stored.get_type() == Variant::OBJECT ? Object::cast_to<Node>(Stored.operator Object*()) : nullptr;
            if (Target && Target->is_inside_tree() && !Target->is_queued_for_deletion()) {
                Record.ReferenceObject = uint64_t(Target->get_instance_id());
                if (Target->has_meta("_gl_netid")) {
                    int64_t Id = Target->get_meta("_gl_netid");
                    if (Id > 0 && _rep_node(uint64_t(Id)) == Target) Record.ReferenceId = uint64_t(Id);
                }
                bool Root = false;
                for (uint64_t Scope : RemoteScopeRoots) if (Scope == Record.ReferenceObject) Root = true;
                if (Record.ReferenceId || Root) {
                    Dictionary Reference; Reference["__glnet"] = "inst"; Reference["id"] = int64_t(Record.ReferenceId);
                    Reference["p"] = Root ? String(Target->get_path()) : String(); NativeReference = Reference;
                }
            }
        }
        if (auto Transform = Object::cast_to<Node3D>(NodeValue)) Record.Pose = Transform->get_global_transform();
        int64_t Parent = 0;
        if (NativeParent && NativeParent->has_meta("_gl_netid")) {
            int64_t Candidate = NativeParent->get_meta("_gl_netid");
            if (Candidate > 0 && _rep_node(uint64_t(Candidate)) == NativeParent) Parent = Candidate;
        }
        else for (int Scope = 0; Scope < 3; ++Scope) if (NativeParent && uint64_t(NativeParent->get_instance_id()) == RemoteScopeRoots[Scope]) Parent = -(Scope + 1);
        if (!Parent) return Reject(__LINE__);
        RobloxPart* SpatialPart = Object::cast_to<RobloxPart>(NodeValue);
        bool Workspace = VisibleRoots[1] && ParentObject == VisibleRoots[1];
        if (!Workspace) {
            Node* Ancestor = NodeValue;
            SpatialPart = nullptr;
            for (int Depth = 0; Ancestor && Depth <= 64; ++Depth, Ancestor = Ancestor->get_parent()) {
                if (Ancestor->is_class("RBXCharacter") || Ancestor->is_class("RobloxPlayer2D")) { SpatialPart = nullptr; break; }
                if (!SpatialPart) SpatialPart = Object::cast_to<RobloxPart>(Ancestor);
                if (uint64_t(Ancestor->get_instance_id()) == RemoteScopeRoots[1]) { Workspace = true; break; }
            }
        }
        bool Eligible = !Record.Static && Workspace && SpatialPart && SpatialPart->get_anchored();
        // Internal geometry follows its anchored Part. Gameplay descendants
        // conservatively pin the complete hierarchy globally for its lifetime.
        if (SpatialPart && SpatialPart->get_child_count() > int(Index::MaximumObjects)) return Reject(__LINE__);
        if (Eligible) for (int Child = 0; Child < SpatialPart->get_child_count(); ++Child) {
            Node* Value = SpatialPart->get_child(Child);
            bool Registered = false;
            if (Value->has_meta("_gl_netid")) Registered = _rep_node(int64_t(Value->get_meta("_gl_netid"))) == Value;
            if (Registered && !Value->is_class("MeshInstance3D") && !Value->is_class("CollisionShape3D") && !Value->is_class("OccluderInstance3D")) Eligible = false;
        }
        if (!Eligible) Replication.Globals.insert(Entry.first);
        if (!Record.Static && Replication.Globals.count(Entry.first)) Registry().Globals.insert(Entry.first);
        Record.Global = !Eligible || Replication.Globals.count(Entry.first);
        Vector3 Point;
        if (SpatialPart) Point = SpatialPart == NodeValue ? Record.Pose.origin : SpatialPart->get_global_position();
        if (!Point.is_finite()) return Reject(__LINE__);
        auto Previous = Replication.Catalog.find(Entry.first);
        auto Dirty = Replication.Dirty.find(Entry.first);
        uint64_t Revision = Dirty == Replication.Dirty.end() ? 0 : Dirty->second;
        bool Semantic = Previous == Replication.Catalog.end() || Previous->second.Object != Record.Object || Previous->second.Revision != Revision ||
            Previous->second.ReferenceObject != Record.ReferenceObject || Previous->second.ReferenceId != Record.ReferenceId ||
            Previous->second.Global != Record.Global || Previous->second.Data->Parent != Parent || Previous->second.Data->Name != String(NodeValue->get_name());
        bool Rebuild = Semantic;
        if (!Rebuild && Previous != Replication.Catalog.end()) {
            const auto* OldPoint = Replication.Spatial.Get(Entry.first);
            bool Moved = !OldPoint || OldPoint->Point.X != Point.x || OldPoint->Point.Y != Point.y || OldPoint->Point.Z != Point.z || Previous->second.Pose != Record.Pose;
            Rebuild = Moved;
            if (Moved && (!SpatialPart || SpatialPart->get_anchored())) Semantic = true;
            for (auto Reference : Previous->second.Data->References) if (Removed.count(Reference)) Rebuild = Semantic = true;
        }
        Observe(Replication.RefreshMetadataUsec);
        if (Rebuild) {
            CountRemote(Replication.RefreshRebuilt);
            Dictionary Properties = (Record.Static ? rep_build_shadow_props(NodeValue) : rep_build_props(NodeValue)).duplicate(true);
            Properties.erase("Name"); // Structural metadata owns the actual native name.
            if (auto Typed = Object::cast_to<RobloxValue>(NodeValue)) if (Typed->get_value().get_type() == Variant::NIL) Properties["Value"] = Variant();
            if (auto Typed = Object::cast_to<RobloxValue>(NodeValue)) if (Typed->roblox_class == "ObjectValue") Properties["Value"] = NativeReference;
            if (Object::cast_to<RobloxPart>(NodeValue)) {
                Properties["__gl_owner"] = NodeValue->get_meta("_gl_owner", 0);
                Properties["__gl_owner_auto"] = NodeValue->get_meta("_gl_owner_auto", true);
            }
            if (!Record.Static) if (auto Transform = Object::cast_to<Node3D>(NodeValue)) {
                Properties["Position"] = Transform->get_global_position();
                Properties["Rotation"] = Transform->get_global_rotation_degrees();
            }
            Variant Value = Properties;
            std::vector<Identity> Refs;
            if (!References(Value, net_instances, Refs)) return Reject(__LINE__);
            const Dictionary Validated = Value;
            if (Validated.size() > 128) return Reject(__LINE__);
            std::function<bool(const Variant&, int)> RootReferences = [&](const Variant& Item, int Depth) {
                if (Depth >= GLRemotePayload::MaxDepth) return Reject(__LINE__);
                if (Item.get_type() == Variant::ARRAY) {
                    Array Values = Item;
                    for (int Index = 0; Index < Values.size(); ++Index) if (!RootReferences(Values[Index], Depth + 1)) return Reject(__LINE__);
                } else if (Item.get_type() == Variant::DICTIONARY) {
                    Dictionary Values = Item;
                    if (Values.get("__glnet", Variant()) == Variant("inst") && int64_t(Values.get("id", 0)) == 0) {
                        for (int Scope = 0; Scope < 3; ++Scope) if (auto Root = Object::cast_to<Node>(ObjectDB::get_instance(RemoteScopeRoots[Scope])))
                            if (Values.get("p", Variant()) == Variant(String(Root->get_path()))) return true;
                        return Reject(__LINE__);
                    }
                    Array Keys = Values.keys();
                    for (int Index = 0; Index < Keys.size(); ++Index) if (!RootReferences(Values[Keys[Index]], Depth + 1)) return Reject(__LINE__);
                }
                return true;
            };
            if (!RootReferences(Validated, 0)) return Reject(__LINE__);
            GLRemotePayload::Codec Encoded;
            Encoded.Value(Validated);
            if (!Encoded.Valid || Encoded.Nodes > 512 || size_t(Encoded.Bytes.size()) > MaximumSnapshotBytes || String(NodeValue->get_name()).utf8().length() > 256) return Reject(__LINE__);
            if (Semantic || !Revision) {
                if (Replication.NextRevision == uint64_t(INT64_MAX)) return Reject(__LINE__);
                Revision = ++Replication.NextRevision;
                Replication.Dirty[Entry.first] = Revision;
            }
            Record.Data = std::make_shared<const Snapshot>(NodeValue->get_class(), String(NodeValue->get_name()), Parent, Encoded.Bytes, Encoded.Nodes, Refs);
        } else Record.Data = Previous->second.Data;
        Observe(Replication.RefreshEncodeUsec);
        Record.Revision = Revision;
        Bytes += size_t(Record.Data->Bytes.size());
        if (Bytes > MaximumCatalogBytes || !Spatial.Set({Entry.first, Record.Object, Parent > 0 ? uint64_t(Parent) : 0, {Point.x, Point.y, Point.z}, Record.Global, Record.Data->References})) return Reject(__LINE__);
        Catalog.emplace(Entry.first, std::move(Record));
        Observe(Replication.RefreshIndexUsec);
    }
    Replication.Catalog.swap(Catalog); Replication.Spatial = std::move(Spatial); Replication.CatalogBytes = Bytes;
    for (auto Iterator = Registry().Objects.begin(); Iterator != Registry().Objects.end();) {
        if (!net_instances.count(Iterator->first) || !ObjectDB::get_instance(Iterator->second)) {
            Registry().Globals.erase(Iterator->first); Iterator = Registry().Objects.erase(Iterator);
        } else ++Iterator;
    }
    for (auto Iterator = Replication.Dirty.begin(); Iterator != Replication.Dirty.end();) {
        if (!Replication.Catalog.count(Iterator->first)) Iterator = Replication.Dirty.erase(Iterator); else ++Iterator;
    }
    for (auto Iterator = Replication.Globals.begin(); Iterator != Replication.Globals.end();) {
        if (!Replication.Catalog.count(*Iterator)) Iterator = Replication.Globals.erase(Iterator); else ++Iterator;
    }
    for (auto Iterator = Replication.Controls.begin(); Iterator != Replication.Controls.end();) {
        if (!Replication.Catalog.count(Iterator->first)) Iterator = Replication.Controls.erase(Iterator); else ++Iterator;
    }
    for (auto Iterator = Replication.Owners.begin(); Iterator != Replication.Owners.end();) {
        if (!Replication.Catalog.count(Iterator->first)) Iterator = Replication.Owners.erase(Iterator); else ++Iterator;
    }
    return true;
}

bool NetworkService::FailReplicationPeer(int Peer, const char* Reason) {
    int64_t User = mode == 2 ? gl_local_user_id() : (peer_seq_uid.count(Peer) ? peer_seq_uid.at(Peer) : 0);
    if (Replication.FailedSessions.count(Peer) && Replication.FailedSessions.at(Peer) == User) return true;
    if (Replication.FailedSessions.size() < GLReplication::MaximumPeers) Replication.FailedSessions[Peer] = User;
    CountRemote(Replication.Failures);
    Replication.Outgoing.Retire([Peer](const auto& Entry) { return Entry.Key.Peer == Peer; });
    Replication.Peers.erase(Peer);
    QueueRemoteFailure(Peer, User);
    UtilityFunctions::print(String("[Network:Replication] Peer failure pending: ") + Reason + " source=" + String::num_int64(Replication.FailureLine));
    return true;
}

bool NetworkService::ReplicationReferenceReady(uint64_t Id, int Peer) const {
    if (gl_is_static_netid(Id)) return true; // Matching preloaded place contract.
    if (Replication.Enabled) {
        if (!Replication.Globals.count(Id)) return false;
        if (!Peer) return true;
        auto View = Replication.Peers.find(Peer);
        if (View == Replication.Peers.end()) return false;
        auto Known = View->second.Known.find(Id);
        auto Native = net_instances.find(Id);
        return Known != View->second.Known.end() && Known->second.Global && Known->second.GlobalSequence <= View->second.Acked && Known->second.Materialized && View->second.Desired.count(Id) &&
            Native != net_instances.end() && Known->second.Object == Native->second;
    }
    if (Replication.Receiving) {
        auto Known = Replication.Replicas.find(Id);
        return Known != Replication.Replicas.end() && Known->second.Global && ObjectDB::get_instance(Known->second.Object);
    }
    return true;
}

bool NetworkService::ReplicationPayloadReady(const Variant& Body, int Peer, int Depth, bool Tagged) const {
    if (Depth >= GLRemotePayload::MaxDepth) return false;
    if (Body.get_type() == Variant::ARRAY) {
        Array Values = Body;
        for (int Index = 0; Index < Values.size(); ++Index) if (!ReplicationPayloadReady(Values[Index], Peer, Depth + 1)) return false;
    } else if (Body.get_type() == Variant::DICTIONARY) {
        Dictionary Values = Body;
        String Tag;
        if (Tagged && Values.get("__glnet", Variant()).get_type() == Variant::STRING) Tag = Values["__glnet"];
        if (Tag == "inst" && Values.has("id") && Positive(Values["id"]))
            return ReplicationReferenceReady(uint64_t(int64_t(Values["id"])), Peer);
        Array Keys = Values.keys();
        for (int Index = 0; Index < Keys.size(); ++Index) {
            bool Inner = !((Tag == "rawdict" && Keys[Index] == Variant("d")) || (Tag == "typed" && Keys[Index] == Variant("f")));
            if (!ReplicationPayloadReady(Values[Keys[Index]], Peer, Depth + 1, Inner)) return false;
        }
    }
    return true;
}

bool NetworkService::ResetReplication() {
    if (!Replication.Enabled && !Replication.Expected && !Replication.Receiving) { Replication = GLReplication::State(); return true; }
    const uint64_t Identity = uint64_t(get_instance_id());
    std::set<uint64_t> Objects;
    if (mode == 2) for (auto Iterator = net_instances.begin(); Iterator != net_instances.end();) {
        if (!gl_is_static_netid(Iterator->first)) { Objects.insert(Iterator->second); Iterator = net_instances.erase(Iterator); }
        else ++Iterator;
    }
    Replication = GLReplication::State();
    std::vector<uint64_t> Roots;
    for (uint64_t NativeIdentity : Objects) {
        Node* Value = Object::cast_to<Node>(ObjectDB::get_instance(NativeIdentity));
        if (!Value) continue;
        bool Nested = false;
        for (Node* Parent = Value->get_parent(); Parent; Parent = Parent->get_parent()) if (Objects.count(uint64_t(Parent->get_instance_id()))) { Nested = true; break; }
        if (!Nested) Roots.push_back(NativeIdentity);
    }
    // No service pointer is needed after callback dispatch. Exact captured
    // native identities can be retired even when a callback destroys the owner.
    for (uint64_t NativeIdentity : Roots) {
        Node* Value = Object::cast_to<Node>(ObjectDB::get_instance(NativeIdentity));
        if (!Value) continue;
        if (Value->get_parent()) Value->get_parent()->remove_child(Value);
        Value = Object::cast_to<Node>(ObjectDB::get_instance(NativeIdentity));
        if (Value && !Value->is_queued_for_deletion()) Value->queue_free();
    }
    return ObjectDB::get_instance(Identity) == this;
}

Dictionary NetworkService::GetReplicationState(int PeerValue) const {
    Dictionary Result;
    Result["Enabled"] = Replication.Enabled; Result["Receiving"] = Replication.Receiving; Result["Failed"] = Replication.Failed;
    Result["FailureLine"] = Replication.FailureLine;
    Result["Catalog"] = int64_t(Replication.Catalog.size()); Result["CatalogBytes"] = int64_t(Replication.CatalogBytes);
    Result["Desired"] = int64_t(Replication.Desired); Result["Known"] = int64_t(Replication.Known); Result["Materialized"] = int64_t(Replication.Materialized);
    Result["Deferred"] = int64_t(Replication.Deferred); Result["Submitted"] = int64_t(Replication.Submitted); Result["Bytes"] = int64_t(Replication.Bytes);
    Result["Enters"] = int64_t(Replication.Enters); Result["Leaves"] = int64_t(Replication.Leaves); Result["Retired"] = int64_t(Replication.Retired);
    Result["Updates"] = int64_t(Replication.Updates); Result["Coalesced"] = int64_t(Replication.Coalesced);
    Result["QueryCells"] = int64_t(Replication.QueryCells); Result["QueryCandidates"] = int64_t(Replication.QueryCandidates);
    Result["Rejected"] = int64_t(Replication.Rejected); Result["Failures"] = int64_t(Replication.Failures);
    Result["RefreshCalls"] = int64_t(Replication.RefreshCalls); Result["RefreshUsec"] = int64_t(Replication.RefreshUsec); Result["RefreshMaximumUsec"] = int64_t(Replication.RefreshMaximumUsec);
    Result["RefreshVisited"] = int64_t(Replication.RefreshVisited); Result["RefreshRebuilt"] = int64_t(Replication.RefreshRebuilt);
    Result["RefreshScanUsec"] = int64_t(Replication.RefreshScanUsec); Result["RefreshMetadataUsec"] = int64_t(Replication.RefreshMetadataUsec);
    Result["RefreshEncodeUsec"] = int64_t(Replication.RefreshEncodeUsec); Result["RefreshIndexUsec"] = int64_t(Replication.RefreshIndexUsec);
    Result["PendingMessages"] = int64_t(Replication.Outgoing.GetTotals().Messages);
    Result["PendingBytes"] = int64_t(Replication.Outgoing.GetTotals().Bytes);
    auto Peer = Replication.Peers.find(PeerValue);
    if (Peer != Replication.Peers.end()) {
        Result["Desired"] = int64_t(Peer->second.Desired.size()); Result["Known"] = int64_t(Peer->second.Known.size());
        int64_t Materialized = 0; for (const auto& Entry : Peer->second.Known) if (Entry.second.Materialized) ++Materialized;
        Result["Materialized"] = Materialized; Result["SentSequence"] = int64_t(Peer->second.Sent); Result["AckedSequence"] = int64_t(Peer->second.Acked);
    }
#ifdef GL_RUNTIME_TESTS
    Array Entries;
    if (Peer != Replication.Peers.end()) for (const auto& Entry : Peer->second.Known) {
        if (Entries.size() == 128) break;
        Dictionary Value; Value["Id"] = int64_t(Entry.first); Value["Generation"] = int64_t(Entry.second.Generation);
        Value["Object"] = int64_t(Entry.second.Object); Value["Materialized"] = Entry.second.Materialized;
        Entries.push_back(Value);
    }
    Result["Entries"] = Entries;
    Array Sources;
    for (const auto& Entry : Replication.Catalog) {
        if (Sources.size() == 128) break;
        Dictionary Value; Value["Id"] = int64_t(Entry.first); Value["Parent"] = Entry.second.Data->Parent;
        Value["Global"] = Entry.second.Global; Array References;
        for (uint64_t Ref : Entry.second.Data->References) References.push_back(int64_t(Ref));
        Value["References"] = References; Sources.push_back(Value);
    }
    Result["Sources"] = Sources;
#endif
    if (Replication.Receiving) Result["ReceivedSequence"] = int64_t(Replication.ReceivedSequence);
    return Result;
}

bool NetworkService::QueueReplication(int PeerValue, const std::vector<std::pair<int, uint64_t>>& Operations) {
    using namespace GLReplication;
    auto Reject = [&](int Line) { if (!Replication.FailureLine) Replication.FailureLine = Line; return false; };
    auto Found = Replication.Peers.find(PeerValue);
    if (Found == Replication.Peers.end() || Operations.size() > MaximumOperations || RemotePendingFailures.count(PeerValue)) return Reject(__LINE__);
    auto& View = Found->second;
    uint64_t Sequence = 0;
    if (!GLRemoteDelivery::NextSequence(View.PlannedSequence, Sequence)) return Reject(__LINE__);
    auto Planned = View.Planned;
    auto Dependents = View.Dependents;
    std::set<uint64_t> Removing;
    for (const auto& Operation : Operations) if (Operation.first == 1 || Operation.first == 2) Removing.insert(Operation.second);
    for (const auto& Entry : Planned) if (!Removing.count(Entry.first)) {
        if (Entry.second.Parent > 0 && Removing.count(uint64_t(Entry.second.Parent))) return Reject(__LINE__);
        for (uint64_t Ref : Entry.second.References) if (Removing.count(Ref)) return Reject(__LINE__);
    }
    auto Prepared = std::make_shared<Commit>(); Prepared->Sequence = Sequence;
    GLRemotePayload::Codec Frame;
    Frame.Word(FrameMagic, 4); Frame.Word(uint64_t(RemoteEpoch)); Frame.Word(uint64_t(View.Session)); Frame.Word(Sequence);
    Frame.Word(Sequence == 1 ? 1 : 0, 1); Frame.Word(Operations.size(), 2);
    auto Edge = [&](uint64_t Target, bool Add) {
        if (!Target) return;
        if (Add) ++Dependents[Target];
        else {
            auto Count = Dependents.find(Target);
            if (Count != Dependents.end() && --Count->second == 0) Dependents.erase(Count);
        }
    };
    auto Edges = [&](const Accepted& Value, bool Add) {
        if (Value.Parent > 0) Edge(uint64_t(Value.Parent), Add);
        for (uint64_t Ref : Value.References) Edge(Ref, Add);
    };
    std::set<uint64_t> Unique;
    for (const auto& Operation : Operations) {
        const int Kind = Operation.first; const uint64_t Id = Operation.second;
        if (!Id || !Unique.insert(Id).second || Kind < 0 || Kind > 4) return Reject(__LINE__);
        auto Old = Planned.find(Id);
        uint64_t Generation = 0;
        const bool Removal = Kind == 1 || Kind == 2;
        Frame.Word(uint64_t(Variant::ARRAY), 1); Frame.Word(Removal ? 3 : 8, 4); ++Frame.Nodes;
        if (Removal) {
            if (Old == Planned.end()) return Reject(__LINE__);
            Generation = Old->second.Generation;
            Edges(Old->second, false); Planned.erase(Old);
            Prepared->Removed.push_back(Id);
            if (Kind == 1) ++Prepared->Leaves; else ++Prepared->Retired;
        } else {
            auto Source = Replication.Catalog.find(Id);
            if (Source == Replication.Catalog.end()) return Reject(__LINE__);
            const auto& Record = Source->second;
            if (Kind == 4 && (Old == Planned.end() || Old->second.Object != Record.Object)) return Reject(__LINE__);
            if (Kind != 4 && Old != Planned.end()) return Reject(__LINE__);
            Generation = Kind == 4 ? Old->second.Generation : Sequence;
            Accepted Next;
            Next.Object = Record.Object; Next.Generation = Generation; Next.Revision = Record.Revision;
            Next.Parent = Record.Data->Parent; Next.References = Record.Data->References;
            Next.Global = Record.Global; Next.LastSequence = Sequence;
            Next.ControlRevision = Replication.Controls.count(Id) ? Replication.Controls.at(Id) : 0;
            Next.GlobalSequence = Record.Global ? (Old != Planned.end() && Old->second.Global ? Old->second.GlobalSequence : Sequence) : 0;
            Next.EnteredSequence = Kind == 4 ? Old->second.EnteredSequence : Sequence;
            if (Old != Planned.end()) { Next.Materialized = Old->second.Materialized; Edges(Old->second, false); }
            Edges(Next, true);
            Planned.insert_or_assign(Id, Next); Prepared->Changes.emplace(Id, std::move(Next));
            if (Kind == 4) ++Prepared->Updates; else ++Prepared->Enters;
        }
        Frame.Value(Kind); Frame.Value(int64_t(Id)); Frame.Value(int64_t(Generation));
        if (!Removal) {
            const auto& Record = Replication.Catalog.at(Id);
            Frame.Value(Record.Data->Class); Frame.Value(Record.Data->Name); Frame.Value(Record.Data->Parent);
            const auto& Bytes = Record.Data->Bytes;
            if (!Frame.Space(Bytes.size()) || Frame.Nodes + Record.Data->Nodes > GLRemotePayload::MaxNodes) return Reject(__LINE__);
            memcpy(Frame.Bytes.ptrw() + Frame.Position, Bytes.ptr(), Bytes.size());
            Frame.Position += Bytes.size(); Frame.Nodes += Record.Data->Nodes;
            Frame.Value(Record.Global);
        }
    }
    if (!Frame.Valid || Frame.Bytes.size() > 60 * 1024 || Planned.size() > Index::MaximumView) return Reject(__LINE__);
    for (const auto& Entry : Prepared->Changes) {
        if (Entry.second.Parent > 0 && !Planned.count(uint64_t(Entry.second.Parent))) return Reject(__LINE__);
        for (uint64_t Ref : Entry.second.References) if (!Planned.count(Ref)) return Reject(__LINE__);
    }
    auto Payload = std::make_shared<Batch>(); Payload->Bytes = Frame.Bytes; Payload->Prepared = Prepared;
    GLRemoteDelivery::Message<Batch> Message;
    Message.Key = {PeerValue, uint64_t(RemoteEpoch), uint64_t(View.Session), 1, 1, 1};
    Message.Object = uint64_t(get_instance_id()); Message.LocalGeneration = Sequence;
    Message.Bytes = size_t(Frame.Bytes.size()); Message.EnqueuedUsec = RemoteNow(); Message.Body = Payload;
    if (Replication.Outgoing.Push(Message) != GLRemoteDelivery::Result::Accepted) return Reject(__LINE__);
    // Application acceptance is distinct from native handoff and client ACK.
    View.Planned.swap(Planned); View.Dependents.swap(Dependents); View.PlannedSequence = Sequence;
    return true;
}

void NetworkService::QueueReplicationReparent(uint64_t Id) {
    using namespace GLReplication;
    if (!RefreshReplication()) { Replication.Failed = true; return; }
    std::vector<int> Failures;
    for (auto& Entry : Replication.Peers) {
        auto& View = Entry.second;
        if (!View.Planned.count(Id)) continue; // Unpublished objects use their eventual enter snapshot.
        std::set<uint64_t> Visited;
        std::vector<std::pair<int, uint64_t>> Operations;
        std::function<bool(uint64_t)> Visit = [&](uint64_t Target) {
            if (!Visited.insert(Target).second) return true;
            if (Visited.size() > MaximumOperations) return false;
            auto Source = Replication.Catalog.find(Target);
            if (Source == Replication.Catalog.end()) return false;
            auto Known = View.Planned.find(Target);
            if (Known != View.Planned.end() && Known->second.Object == Source->second.Object && Known->second.Revision == Source->second.Revision && Target != Id) return true;
            if (Source->second.Data->Parent > 0 && !Visit(uint64_t(Source->second.Data->Parent))) return false;
            for (uint64_t Ref : Source->second.Data->References) if (!Visit(Ref)) return false;
            Operations.emplace_back(Known == View.Planned.end() ? (Source->second.Static ? 3 : 0) : 4, Target);
            return true;
        };
        if (!Visit(Id) || !QueueReplication(Entry.first, Operations)) Failures.push_back(Entry.first);
    }
    for (int Peer : Failures) FailReplicationPeer(Peer, "structural barrier could not be admitted");
}

bool NetworkService::SendReplicationPeer(int PeerValue) {
    using namespace GLReplication;
    auto Reject = [&](int Line) { if (!Replication.FailureLine) Replication.FailureLine = Line; return false; };
    auto Found = Replication.Peers.find(PeerValue);
    if (Found == Replication.Peers.end()) return Reject(__LINE__);
    auto& View = Found->second;
    if (Replication.Outgoing.GetPeerTotals(PeerValue).Messages) return true;
    std::vector<std::pair<int, uint64_t>> Operations;
    // Retire absent canonical identities before publishing their same-name
    // replacements. Retained dependency edges must be cleared by an update
    // first; a still-referenced object is never removed out from under it.
    for (const auto& Known : View.Planned) {
        if (!Replication.Catalog.count(Known.first) && !View.Desired.count(Known.first) && !View.Dependents.count(Known.first))
            Operations.emplace_back(2, Known.first);
        if (Operations.size() == MaximumOperations) break;
    }
    if (!Operations.empty()) return QueueReplication(PeerValue, Operations);
    std::set<uint64_t> Selected;
    size_t EstimatedBytes = 64, Nodes = 0;
    bool InvalidGroup = false;
    for (uint64_t Id : View.Desired) {
        auto Source = Replication.Catalog.find(Id);
        if (Source == Replication.Catalog.end()) return Reject(__LINE__);
        auto Known = View.Planned.find(Id);
        if (Known != View.Planned.end() && Known->second.Object == Source->second.Object && Known->second.Revision == Source->second.Revision) continue;
        std::set<uint64_t> Group;
        std::vector<std::pair<int, uint64_t>> Additions;
        std::function<bool(uint64_t)> Visit = [&](uint64_t Target) {
            if (Selected.count(Target) || !Group.insert(Target).second) return true;
            if (Group.size() > MaximumOperations) return Reject(__LINE__);
            auto Candidate = Replication.Catalog.find(Target);
            if (Candidate == Replication.Catalog.end()) return Reject(__LINE__);
            auto Previous = View.Planned.find(Target);
            if (Previous != View.Planned.end() && Previous->second.Object == Candidate->second.Object && Previous->second.Revision == Candidate->second.Revision) return true;
            if (Previous != View.Planned.end() && Previous->second.Object != Candidate->second.Object) return Reject(__LINE__);
            if (Candidate->second.Data->Parent > 0 && !Visit(uint64_t(Candidate->second.Data->Parent))) return Reject(__LINE__);
            for (uint64_t Ref : Candidate->second.Data->References) if (!Visit(Ref)) return Reject(__LINE__);
            Additions.emplace_back(Previous == View.Planned.end() ? (Candidate->second.Static ? 3 : 0) : 4, Target);
            return true;
        };
        if (!Visit(Id)) { InvalidGroup = true; break; }
        size_t Bytes = 0, AddedNodes = 0;
        for (const auto& Added : Additions) {
            const auto& Data = *Replication.Catalog.at(Added.second).Data;
            Bytes += size_t(Data.Bytes.size()) + Data.Class.utf8().length() + Data.Name.utf8().length() + 128;
            AddedNodes += size_t(Data.Nodes) + 8;
        }
        if (Additions.size() > MaximumOperations || Bytes > 60 * 1024 - 64 || AddedNodes > GLRemotePayload::MaxNodes) { InvalidGroup = true; break; }
        if (Operations.size() + Additions.size() > MaximumOperations || EstimatedBytes + Bytes > 60 * 1024 || Nodes + AddedNodes > GLRemotePayload::MaxNodes) continue;
        Operations.insert(Operations.end(), Additions.begin(), Additions.end());
        for (const auto& Added : Additions) Selected.insert(Added.second);
        EstimatedBytes += Bytes; Nodes += AddedNodes;
        if (Operations.size() == MaximumOperations) break;
    }
    if (InvalidGroup) return Reject(__LINE__);
    if (!Operations.empty()) return QueueReplication(PeerValue, Operations);
    // Required dependency edges are taken from the accepted/planned frames,
    // rather than guessed from the current source after references changed.
    auto Dependents = View.Dependents;
    std::set<uint64_t> Removed;
    auto DropEdge = [&](uint64_t Target) {
        auto Count = Dependents.find(Target);
        if (Count != Dependents.end() && --Count->second == 0) Dependents.erase(Count);
    };
    for (size_t Pass = 0; Pass < MaximumOperations && Operations.size() < MaximumOperations; ++Pass) {
        bool Progress = false;
        for (const auto& Known : View.Planned) {
            if (Removed.count(Known.first) || View.Desired.count(Known.first) || Dependents.count(Known.first)) continue;
            Operations.emplace_back(Replication.Catalog.count(Known.first) ? 1 : 2, Known.first);
            Removed.insert(Known.first); Progress = true;
            if (Known.second.Parent > 0) DropEdge(uint64_t(Known.second.Parent));
            for (uint64_t Ref : Known.second.References) DropEdge(Ref);
            if (Operations.size() == MaximumOperations) break;
        }
        if (!Progress) break;
    }
    if (!Operations.empty() || !View.PlannedSequence) return QueueReplication(PeerValue, Operations);
    if (View.Planned.size() != View.Desired.size()) {
        // Bounded reference cycles can depart together. Validate the entire
        // retiring set against retained edges at queue admission, then order
        // native child removal before its parent; no reference is left dangling.
        for (const auto& Known : View.Planned) if (!View.Desired.count(Known.first)) {
            Operations.emplace_back(Replication.Catalog.count(Known.first) ? 1 : 2, Known.first);
            if (Operations.size() > MaximumOperations) return Reject(__LINE__);
        }
        auto Depth = [&](uint64_t Id) {
            int Count = 0;
            for (auto Found = View.Planned.find(Id); Found != View.Planned.end() && Found->second.Parent > 0 && Count <= 64;
                 Found = View.Planned.find(uint64_t(Found->second.Parent))) ++Count;
            return Count;
        };
        std::stable_sort(Operations.begin(), Operations.end(), [&](const auto& A, const auto& B) { return Depth(A.second) > Depth(B.second); });
        return QueueReplication(PeerValue, Operations);
    }
    return true;
}

void NetworkService::TickReplication() {
    using namespace GLReplication;
    if (mode == 2 && Replication.Expected && !Replication.Receiving && net_connected && Replication.ConnectedAt &&
        RemoteNow() >= Replication.ConnectedAt && RemoteNow() - Replication.ConnectedAt > 10000000) {
        FailReplicationPeer(1, "matching structural protocol did not begin within ten seconds"); return;
    }
    if (Replication.Receiving && mode == 2 && RemoteServiceActive()) {
        const uint64_t Identity = uint64_t(get_instance_id());
        auto Pending = Replication.Incoming.Take(1);
        if (Pending) {
            const bool Live = Pending->Object == Identity && Pending->Key.Epoch == uint64_t(Replication.ReceivedEpoch) &&
                Pending->Key.Session == uint64_t(gl_local_user_id()) && _mp()->get_peers().has(1);
            bool Applied = Live && RemoteNow() - Pending->EnqueuedUsec <= 10000000 && ApplyReplicationFrame(*Pending->Body);
            if (ObjectDB::get_instance(Identity) != this || is_queued_for_deletion()) return;
            if (!Applied && mode == 2 && RemoteServiceActive()) FailReplicationPeer(1, "received structural frame could not be materialized");
        }
        return;
    }
    if (!Replication.Enabled || mode != 1 || !RemoteServiceActive()) return;
    const uint64_t Identity = uint64_t(get_instance_id()), Now = RemoteNow(), Started = Time::get_singleton()->get_ticks_usec();
    try {
        if (!Replication.LastRefresh || Now - Replication.LastRefresh >= 100000) {
            if (!RefreshReplication()) Replication.Failed = true;
            Replication.LastRefresh = Now;
        }
        for (auto Iterator = Replication.Peers.begin(); Iterator != Replication.Peers.end();) {
            if (!peer_seq_uid.count(Iterator->first) || peer_seq_uid.at(Iterator->first) != Iterator->second.Session || !_mp()->get_peers().has(Iterator->first) || RemotePendingFailures.count(Iterator->first)) {
                int Peer = Iterator->first;
                Replication.Outgoing.Retire([Peer](const auto& Value) { return Value.Key.Peer == Peer; });
                Iterator = Replication.Peers.erase(Iterator);
            } else ++Iterator;
        }
        for (auto Iterator = Replication.FailedSessions.begin(); Iterator != Replication.FailedSessions.end();) {
            if (!peer_seq_uid.count(Iterator->first) || peer_seq_uid.at(Iterator->first) != Iterator->second) Iterator = Replication.FailedSessions.erase(Iterator);
            else ++Iterator;
        }
        for (const auto& Entry : peer_seq_uid) if (Entry.first > 1 && _mp()->get_peers().has(Entry.first) && !RemotePendingFailures.count(Entry.first) && !Replication.Peers.count(Entry.first) && !Replication.FailedSessions.count(Entry.first)) {
            if (Replication.Peers.size() >= MaximumPeers) { QueueRemoteFailure(Entry.first, Entry.second); continue; }
            Peer Value; Value.Session = Entry.second; Replication.Peers.emplace(Entry.first, std::move(Value));
        }
        std::vector<int> Failures;
        for (size_t Turn = 0; Turn < std::min(size_t(8), Replication.Peers.size()); ++Turn) {
            auto Iterator = Replication.Peers.upper_bound(Replication.Cursor);
            if (Iterator == Replication.Peers.end()) Iterator = Replication.Peers.begin();
            const int PeerValue = Iterator->first; Replication.Cursor = PeerValue;
            auto& View = Iterator->second;
            if (Replication.Failed) { Failures.push_back(PeerValue); continue; }
            Vector3 Center; bool HasFocus = false;
            auto Authority = CharacterAuthorities.find(PeerValue);
            if (Authority != CharacterAuthorities.end() && LiveCharacter(Authority->second.Identity) && Authority->second.Position.is_finite()) { Center = Authority->second.Position; HasFocus = true; }
            auto Selection = Replication.Spatial.Query({Center.x, Center.y, Center.z}, 250, HasFocus);
            if (Selection.Result != QueryResult::Status::Ready) { Replication.FailureLine = -int(Selection.Result); Failures.push_back(PeerValue); continue; }
            CountRemote(Replication.QueryCells, Selection.Cells); CountRemote(Replication.QueryCandidates, Selection.Candidates);
            View.Desired.swap(Selection.Desired);
            if (!SendReplicationPeer(PeerValue)) { Failures.push_back(PeerValue); continue; }
            if (View.TailDirty) {
                bool Ready = true;
                TypedArray<Node> Roster = get_players_roster();
                for (int Index = 0; Index < Roster.size(); ++Index) if (auto Player = Object::cast_to<PlayerObject>(Roster[Index])) {
                    auto Team = Object::cast_to<Node>(ObjectDB::get_instance(Player->team_id));
                    if (Team && Team->has_meta("_gl_netid")) Ready = Ready && ReplicationReferenceReady(int64_t(Team->get_meta("_gl_netid")), PeerValue);
                }
                if (Ready && View.Acked) { View.TailDirty = false; SyncReplicationPresentation(PeerValue); }
                if (ObjectDB::get_instance(Identity) != this) return;
            }
            if (View.Sent > View.Acked && View.WaitingSince && Now - View.WaitingSince > 10000000) { Failures.push_back(PeerValue); continue; }
            const auto* Pending = Replication.Outgoing.Front(PeerValue);
            if (Pending && View.Sent - View.Acked < 64) {
                if (Now >= Pending->EnqueuedUsec && Now - Pending->EnqueuedUsec > 10000000) { Failures.push_back(PeerValue); continue; }
                Dictionary Capacity = NativeRemoteAdmission(PeerValue);
                bool WouldBlock = !NativeCapacity(Capacity, Pending->Bytes);
#ifdef GL_RUNTIME_TESTS
                WouldBlock = WouldBlock || RemoteBusyPeer == PeerValue;
#endif
                if (WouldBlock) CountRemote(Replication.Deferred);
                else {
                    auto Message = *Pending;
                    auto CommitValue = Message.Body->Prepared;
                    Error Sent = rpc_id(PeerValue, "_replication_frame", Message.Body->Bytes);
                    if (ObjectDB::get_instance(Identity) != this || is_queued_for_deletion()) return;
                    if (Sent != OK) { Failures.push_back(PeerValue); continue; }
                    for (auto Change = CommitValue->Changes.begin(); Change != CommitValue->Changes.end();) {
                        auto Node = CommitValue->Changes.extract(Change++);
                        auto Previous = View.Known.find(Node.key());
                        bool Materialized = Node.mapped().EnteredSequence <= View.Acked || (Previous != View.Known.end() && Previous->second.Generation == Node.mapped().Generation && Previous->second.Materialized);
                        Node.mapped().Materialized = Materialized;
                        if (Previous != View.Known.end()) Previous->second = std::move(Node.mapped());
                        else View.Known.insert(std::move(Node));
                    }
                    for (uint64_t Removed : CommitValue->Removed) View.Known.erase(Removed);
                    View.Sent = CommitValue->Sequence;
                    if (!View.WaitingSince) View.WaitingSince = Now;
                    Replication.Outgoing.Take(PeerValue);
                    CountRemote(Replication.Submitted); CountRemote(Replication.Bytes, Message.Bytes);
                    CountRemote(Replication.Enters, CommitValue->Enters); CountRemote(Replication.Leaves, CommitValue->Leaves);
                    CountRemote(Replication.Retired, CommitValue->Retired); CountRemote(Replication.Updates, CommitValue->Updates);
                }
            }
            if (Time::get_singleton()->get_ticks_usec() - Started >= 4000) break;
        }
        for (int PeerValue : Failures) FailReplicationPeer(PeerValue, "bounded selection, backlog or dependency failure");
        std::vector<std::pair<uint64_t, OwnerRequest>> ReadyOwners;
        for (const auto& Entry : Replication.Owners) {
            auto Native = net_instances.find(Entry.first);
            if (Native == net_instances.end() || Native->second != Entry.second.Object || !peer_seq_uid.count(Entry.second.Peer) || peer_seq_uid.at(Entry.second.Peer) != Entry.second.Session || ReplicationPhysicsReady(Entry.first, Entry.second.Peer)) ReadyOwners.push_back(Entry);
        }
        for (const auto& Entry : ReadyOwners) {
            Replication.Owners.erase(Entry.first);
            if (net_instances.count(Entry.first) && net_instances.at(Entry.first) == Entry.second.Object && peer_seq_uid.count(Entry.second.Peer) && peer_seq_uid.at(Entry.second.Peer) == Entry.second.Session)
                net_set_owner(int64_t(Entry.first), Entry.second.Peer, Entry.second.Automatic);
        }
        Replication.Desired = Replication.Known = Replication.Materialized = 0;
        for (const auto& Entry : Replication.Peers) {
            CountRemote(Replication.Desired, Entry.second.Desired.size()); CountRemote(Replication.Known, Entry.second.Known.size());
            for (const auto& Known : Entry.second.Known) if (Known.second.Materialized) CountRemote(Replication.Materialized);
        }
    } catch (const std::bad_alloc&) {
        Replication.Failed = true;
    }
}

void NetworkService::_replication_ack(PackedByteArray Bytes) {
    const int Sender = GetClientRpcSender();
    if (!Sender || !Replication.Enabled || !NativeRemoteCall("_replication_ack") || Bytes.size() != 28) { CountRemote(Replication.Rejected); return; }
    GLRemotePayload::Codec Frame; Frame.Bytes = Bytes; Frame.Reading = true;
    uint32_t Magic = uint32_t(Frame.Word(0, 4)); int64_t Epoch = int64_t(Frame.Word()), User = int64_t(Frame.Word()); uint64_t Sequence = Frame.Word();
    auto Found = Replication.Peers.find(Sender);
    if (Magic != GLReplication::AckMagic || Epoch != RemoteEpoch || Found == Replication.Peers.end() || User != Found->second.Session || !Sequence || Sequence > Found->second.Sent) { CountRemote(Replication.Rejected); return; }
    auto& View = Found->second;
    if (Sequence <= View.Acked) return;
    View.Acked = Sequence; View.WaitingSince = View.Acked == View.Sent ? 0 : RemoteNow();
    for (auto& Known : View.Known) if (Known.second.EnteredSequence <= Sequence) Known.second.Materialized = true;
}

void NetworkService::_replication_frame(PackedByteArray Bytes) {
    using namespace GLReplication;
    if (!NativeRemoteCall("_replication_frame") || !AcceptServerRpc() || !Replication.Expected || ReplicationTransition ||
        Bytes.size() < 31 || Bytes.size() > 60 * 1024) { CountRemote(Replication.Rejected); return; }
    GLRemotePayload::Codec Frame; Frame.Bytes = Bytes; Frame.Reading = true;
    const uint32_t Magic = uint32_t(Frame.Word(0, 4));
    const int64_t Epoch = int64_t(Frame.Word()), Session = int64_t(Frame.Word());
    const uint64_t Sequence = Frame.Word(), Begin = Frame.Word(0, 1), Count = Frame.Word(0, 2);
    if (Magic != FrameMagic || Epoch <= 0 || Session != gl_local_user_id() || Session <= 0 || !Sequence || Sequence > uint64_t(INT64_MAX) ||
        Sequence != Replication.ReceivedQueued + 1 || Begin != uint64_t(Replication.ReceivedQueued == 0) || Count > MaximumOperations ||
        (RemoteEpoch && RemoteEpoch != Epoch) || (Replication.Receiving && (Replication.ReceivedEpoch != Epoch || Replication.ReceivedSession != Session))) {
        CountRemote(Replication.Rejected); return;
    }
    try {
        auto& Budget = RemoteBudgets[1];
        if (Budget.Messages >= 256 || Budget.Bytes > 256 * 1024 - Bytes.size() || RemoteAggregate.Messages >= 1024 || RemoteAggregate.Bytes > 1024 * 1024 - Bytes.size()) {
            QueueRemoteFailure(1, Session); return;
        }
        GLRemoteDelivery::Message<PackedByteArray> Message;
        Message.Key = {1, uint64_t(Epoch), uint64_t(Session), 1, 1, 0};
        Message.Object = uint64_t(get_instance_id()); Message.LocalGeneration = Sequence;
        Message.Bytes = size_t(Bytes.size()); Message.EnqueuedUsec = RemoteNow();
        Message.Body = std::make_shared<const PackedByteArray>(Bytes);
        if (Replication.Incoming.Push(Message) != GLRemoteDelivery::Result::Accepted) { QueueRemoteFailure(1, Session); return; }
        Replication.Receiving = true; Replication.ReceivedEpoch = Epoch; Replication.ReceivedSession = Session; Replication.ReceivedQueued = Sequence;
        if (!RemoteEpoch) RemoteEpoch = Epoch;
        ++Budget.Messages; Budget.Bytes += Bytes.size(); ++RemoteAggregate.Messages; RemoteAggregate.Bytes += Bytes.size();
    } catch (const std::bad_alloc&) { QueueRemoteFailure(1, Session); }
}

bool NetworkService::ApplyReplicationFrame(const PackedByteArray& Bytes) {
    using namespace GLReplication;
    const uint64_t Identity = uint64_t(get_instance_id());
    const int64_t Epoch = Replication.ReceivedEpoch, Session = Replication.ReceivedSession;
    if (ReplicationApplying) return false;
    ReplicationApplying = true;
    struct ApplyingScope {
        uint64_t Identity;
        ~ApplyingScope() { if (auto Owner = Object::cast_to<NetworkService>(ObjectDB::get_instance(Identity))) Owner->ReplicationApplying = false; }
    } Applying{Identity};
    auto Live = [&]() { return ObjectDB::get_instance(Identity) == this && !is_queued_for_deletion() && mode == 2 &&
        !ReplicationTransition && Replication.Receiving && Replication.ReceivedEpoch == Epoch && Replication.ReceivedSession == Session && gl_local_user_id() == Session; };
    struct AllocatedNodes {
        std::vector<uint64_t> Values;
        bool Committed = false;
        ~AllocatedNodes() {
            if (Committed) return;
            for (uint64_t Id : Values) if (auto Value = Object::cast_to<Node>(ObjectDB::get_instance(Id)))
                if (!Value->is_inside_tree() && !Value->is_queued_for_deletion()) memdelete(Value);
        }
    } Allocated;
    try {
        GLRemotePayload::Codec Frame; Frame.Bytes = Bytes; Frame.Reading = true;
        if (Frame.Word(0, 4) != FrameMagic || int64_t(Frame.Word()) != Epoch || int64_t(Frame.Word()) != Session) return false;
        const uint64_t Sequence = Frame.Word(), Begin = Frame.Word(0, 1), Count = Frame.Word(0, 2);
        if (Sequence != Replication.ReceivedSequence + 1 || Begin != uint64_t(Replication.ReceivedSequence == 0) || Count > MaximumOperations) return false;
        std::vector<Array> Operations;
        auto Next = Replication.Replicas;
        std::set<uint64_t> Unique, Entering;
        for (size_t Index = 0; Index < Count; ++Index) {
            Variant Input = Frame.Value();
            if (!Frame.Valid || Input.get_type() != Variant::ARRAY) return false;
            Array Operation = Input;
            if (Operation.size() < 3 || Operation[0].get_type() != Variant::INT || !Positive(Operation[1]) || !Positive(Operation[2])) return false;
            const int64_t Kind = Operation[0]; const uint64_t Id = int64_t(Operation[1]), Generation = int64_t(Operation[2]);
            const bool Removal = Kind == 1 || Kind == 2;
            if (Kind < 0 || Kind > 4 || Operation.size() != (Removal ? 3 : 8) || !Unique.insert(Id).second) return false;
            auto Previous = Next.find(Id);
            if (Removal || Kind == 4) {
                if (Previous == Next.end() || Previous->second.Generation != Generation) return false;
                if (Removal) { Next.erase(Previous); Operations.push_back(Operation); continue; }
            } else {
                if (Previous != Next.end() || Generation != Sequence || (Kind == 3) != gl_is_static_netid(Id)) return false;
                Entering.insert(Id);
                if (Kind == 0 && net_instances.count(Id)) return false;
                Received Value; Value.Generation = Generation; Value.Static = Kind == 3;
                if (Kind == 3) {
                    Node* Existing = _rep_node(Id);
                    if (!Existing || !VisibleRemoteReference(Existing)) return false;
                    Value.Object = uint64_t(Existing->get_instance_id());
                }
                Next.emplace(Id, Value);
            }
            if (Operation[3].get_type() != Variant::STRING || Operation[4].get_type() != Variant::STRING ||
                Operation[5].get_type() != Variant::INT || Operation[6].get_type() != Variant::DICTIONARY || Operation[7].get_type() != Variant::BOOL) return false;
            const String Class = Operation[3], Name = Operation[4]; const int64_t Parent = Operation[5]; const Dictionary Properties = Operation[6];
            if (Class.utf8().length() > 128 || Name.utf8().length() > 256 || Name.is_empty() || !Parent || Parent < -3 || Properties.size() > 128 ||
                !ClassDBSingleton::get_singleton()->class_exists(Class) || !ClassDBSingleton::get_singleton()->is_parent_class(Class, "Node")) return false;
            Array Keys = Properties.keys();
            for (int Key = 0; Key < Keys.size(); ++Key) if (Keys[Key].get_type() != Variant::STRING || String(Keys[Key]).utf8().length() > 128 || String(Keys[Key]) == "Parent" || String(Keys[Key]) == "Name") return false;
            auto& Value = Next.at(Id); Value.Parent = Parent; Value.Global = Operation[7];
            if (Value.Object) {
                Node* Existing = Object::cast_to<Node>(ObjectDB::get_instance(Value.Object));
                if (!Existing || Existing->get_class() != Class || _rep_node(Id) != Existing) return false;
            }
            Operations.push_back(Operation);
        }
        if (!Frame.Valid || Frame.Position != Bytes.size() || Next.size() > Index::MaximumView) return false;
        std::function<bool(const Variant&, int)> ValidReferences = [&](const Variant& Value, int Depth) {
            if (Depth >= GLRemotePayload::MaxDepth) return false;
            if (Value.get_type() == Variant::ARRAY) {
                Array Values = Value;
                for (int Index = 0; Index < Values.size(); ++Index) if (!ValidReferences(Values[Index], Depth + 1)) return false;
            } else if (Value.get_type() == Variant::DICTIONARY) {
                Dictionary Values = Value;
                if (Values.get("__glnet", Variant()) == Variant("inst")) {
                    if (!Values.has("id") || Values["id"].get_type() != Variant::INT || int64_t(Values["id"]) < 0) return false;
                    uint64_t Id = int64_t(Values["id"]);
                    if (Id) return Next.count(Id) != 0;
                    if (Values.get("p", Variant()).get_type() != Variant::STRING) return false;
                    for (int Scope = 0; Scope < 3; ++Scope) if (auto Root = Object::cast_to<Node>(ObjectDB::get_instance(RemoteScopeRoots[Scope])))
                        if (String(Root->get_path()) == String(Values["p"])) return true;
                    return false;
                }
                Array Keys = Values.keys();
                for (int Key = 0; Key < Keys.size(); ++Key) if (!ValidReferences(Values[Keys[Key]], Depth + 1)) return false;
            }
            return true;
        };
        for (const auto& Operation : Operations) {
            int Kind = Operation[0]; if (Kind == 1 || Kind == 2) continue;
            uint64_t Id = int64_t(Operation[1]);
            int64_t Parent = Operation[5];
            if (Parent > 0 && !Next.count(uint64_t(Parent))) return false;
            if (Parent < 0) {
                Node* Root = Object::cast_to<Node>(ObjectDB::get_instance(RemoteScopeRoots[-Parent - 1]));
                if (!Root || !VisibleRemoteReference(Root)) return false;
            }
            int Depth = 0;
            for (int64_t Ancestor = Parent; Ancestor > 0; Ancestor = Next.at(uint64_t(Ancestor)).Parent)
                if (uint64_t(Ancestor) == Id || !Next.count(uint64_t(Ancestor)) || ++Depth > 64) return false;
            if (!ValidReferences(Operation[6], 0)) return false;
        }
        // Validate all data before allocating or mutating any replica. Native
        // identities for same-frame references exist before attaching any node.
        Allocated.Values.reserve(Entering.size());
        for (const auto& Operation : Operations) if (int64_t(Operation[0]) == 0) {
            Object* Created = ClassDB::instantiate(StringName(String(Operation[3])));
            Node* Value = Object::cast_to<Node>(Created);
            if (!Value) { if (Created) memdelete(Created); return false; }
            uint64_t Id = int64_t(Operation[1]), Native = uint64_t(Value->get_instance_id());
            Allocated.Values.push_back(Native); Next.at(Id).Object = Native;
        }
        for (uint64_t Id : Entering) {
            Node* Value = Object::cast_to<Node>(ObjectDB::get_instance(Next.at(Id).Object));
            if (!Value) return false;
            Value->set_meta("_gl_netid", int64_t(Id)); net_instances[Id] = Next.at(Id).Object;
        }
        for (const auto& Operation : Operations) {
            const int Kind = Operation[0]; if (Kind != 1 && Kind != 2) continue;
            const uint64_t Id = int64_t(Operation[1]);
            auto Previous = Replication.Replicas.find(Id);
            if (Previous == Replication.Replicas.end()) return false;
            const uint64_t Native = Previous->second.Object;
            Replication.Replicas.erase(Previous); net_instances.erase(Id); phys_targets.erase(Id);
            Node* Value = Object::cast_to<Node>(ObjectDB::get_instance(Native));
            if (Value) {
                if (Value->get_parent()) Value->get_parent()->remove_child(Value);
                if (!Live()) return false;
                Value = Object::cast_to<Node>(ObjectDB::get_instance(Native));
                if (Value && !Value->is_queued_for_deletion()) Value->queue_free();
            }
        }
        auto Resolve = [&](int64_t Id) -> Node* {
            if (Id < 0 && Id >= -3) return Object::cast_to<Node>(ObjectDB::get_instance(RemoteScopeRoots[-Id - 1]));
            auto Found = Next.find(uint64_t(Id));
            if (Found == Next.end()) return nullptr;
            Node* Value = Object::cast_to<Node>(ObjectDB::get_instance(Found->second.Object));
            return Value && _rep_node(uint64_t(Id)) == Value && !Value->is_queued_for_deletion() ? Value : nullptr;
        };
        std::set<uint64_t> Attached;
        for (size_t Pass = 0; Pass < Operations.size() + 1; ++Pass) {
            bool Progress = false;
            for (const auto& Operation : Operations) {
                const int Kind = Operation[0]; if (Kind == 1 || Kind == 2) continue;
                const uint64_t Id = int64_t(Operation[1]); if (Attached.count(Id)) continue;
                const int64_t ParentId = Operation[5];
                if (ParentId > 0 && Entering.count(uint64_t(ParentId)) && !Attached.count(uint64_t(ParentId))) continue;
                Node* Value = Resolve(int64_t(Id)); Node* Parent = Resolve(ParentId);
                if (!Value || !Parent || !Parent->is_inside_tree() || Value == Parent || Value->is_ancestor_of(Parent)) return false;
                const uint64_t Native = Next.at(Id).Object, ParentNative = uint64_t(Parent->get_instance_id());
                Value->set_name(String(Operation[4]));
                if (!Live()) return false;
                Value = Resolve(int64_t(Id)); Parent = Object::cast_to<Node>(ObjectDB::get_instance(ParentNative));
                if (!Value || !Parent || Parent->is_queued_for_deletion()) return false;
                if (Value->get_parent() != Parent) {
                    if (Value->get_parent()) Value->get_parent()->remove_child(Value);
                    if (!Live()) return false;
                    Value = Object::cast_to<Node>(ObjectDB::get_instance(Native)); Parent = Object::cast_to<Node>(ObjectDB::get_instance(ParentNative));
                    if (!Value || !Parent || Value->is_queued_for_deletion()) return false;
                    Parent->add_child(Value);
                    if (!Live()) return false;
                }
                Value = Resolve(int64_t(Id));
                if (!Value || !Value->is_inside_tree() || String(Value->get_name()) != String(Operation[4]) ||
                    Value->get_parent() != ObjectDB::get_instance(ParentNative)) return false;
                Attached.insert(Id); Progress = true;
            }
            if (!Progress) break;
        }
        for (const auto& Operation : Operations) {
            const int Kind = Operation[0]; if (Kind == 1 || Kind == 2) continue;
            const int64_t Id = Operation[1]; if (!Attached.count(uint64_t(Id))) return false;
            Dictionary Properties = Operation[6];
            Node* Value = Resolve(Id); if (!Value) return false;
            if (Properties.has("__gl_owner")) {
                if (!Object::cast_to<RobloxPart>(Value) || Properties["__gl_owner"].get_type() != Variant::INT ||
                    int64_t(Properties["__gl_owner"]) < 0 || int64_t(Properties["__gl_owner"]) > INT32_MAX || Properties["__gl_owner_auto"].get_type() != Variant::BOOL) return false;
                _apply_owner(uint64_t(Id), int64_t(Properties["__gl_owner"]), bool(Properties["__gl_owner_auto"]));
                Properties.erase("__gl_owner"); Properties.erase("__gl_owner_auto");
            }
            if (auto Typed = Object::cast_to<RobloxValue>(Value)) if (Properties.has("__glvclass")) {
                if (Properties["__glvclass"].get_type() != Variant::STRING) return false;
                Typed->roblox_class = Properties["__glvclass"]; Properties.erase("__glvclass");
            }
            if (auto Typed = Object::cast_to<RobloxValue>(Value)) if (Typed->roblox_class == "ObjectValue" && Properties.has("Value")) {
                Variant Reference = Properties["Value"];
                if (Reference.get_type() == Variant::DICTIONARY) {
                    Dictionary Encoded = Reference;
                    if (Encoded.get("__glnet", Variant()) != Variant("inst") || Encoded.get("id", Variant()).get_type() != Variant::INT || int64_t(Encoded["id"]) < 0) return false;
                    Node* Target = nullptr;
                    if (Positive(Encoded["id"])) Target = Resolve(int64_t(Encoded["id"]));
                    else for (int Scope = 0; Scope < 3; ++Scope) if (auto Root = Resolve(-(Scope + 1)))
                        if (Encoded.get("p", Variant()) == Variant(String(Root->get_path()))) Target = Root;
                    if (!Target) return false;
                    Reference = Target;
                } else if (Reference.get_type() != Variant::NIL) return false;
                Properties.erase("Value"); Typed->set_value(Reference);
                if (!Live()) return false;
            }
            Array Keys = Properties.keys();
            for (int Key = 0; Key < Keys.size(); ++Key) {
                Value = Resolve(Id);
                if (!Value || !ValidReferences(Properties[Keys[Key]], 0)) return false;
                std::function<bool(const Variant&, int)> LiveReferences = [&](const Variant& Item, int Depth) {
                    if (Depth >= GLRemotePayload::MaxDepth) return false;
                    if (Item.get_type() == Variant::ARRAY) {
                        Array Values = Item;
                        for (int Index = 0; Index < Values.size(); ++Index) if (!LiveReferences(Values[Index], Depth + 1)) return false;
                    } else if (Item.get_type() == Variant::DICTIONARY) {
                        Dictionary Values = Item;
                        if (Values.get("__glnet", Variant()) == Variant("inst") && int64_t(Values.get("id", 0)) > 0) return Resolve(int64_t(Values["id"])) != nullptr;
                        Array Keys = Values.keys();
                        for (int Index = 0; Index < Keys.size(); ++Index) if (!LiveReferences(Values[Keys[Index]], Depth + 1)) return false;
                    }
                    return true;
                };
                if (!LiveReferences(Properties[Keys[Key]], 0)) return false;
                if (gl_apply_prop_hook()) gl_apply_prop_hook()(Value, String(Keys[Key]), Properties[Keys[Key]]);
                if (!Live()) return false;
            }
        }
        for (const auto& Entry : Next) {
            Node* Value = Resolve(int64_t(Entry.first));
            if (!Value || !Value->is_inside_tree()) return false;
        }
        Replication.Replicas.swap(Next); Replication.ReceivedSequence = Sequence; Allocated.Committed = true;
        GLRemotePayload::Codec Ack; Ack.Word(AckMagic, 4); Ack.Word(uint64_t(Epoch)); Ack.Word(uint64_t(Session)); Ack.Word(Sequence);
        return rpc_id(1, "_replication_ack", Ack.Bytes) == OK;
    } catch (const std::bad_alloc&) { return false; }
}

bool NetworkService::ReplicationPhysicsReady(uint64_t Id, int Peer) const {
    if (!Replication.Enabled || gl_is_static_netid(Id)) return true;
    auto View = Replication.Peers.find(Peer);
    if (View == Replication.Peers.end()) return false;
    auto Known = View->second.Known.find(Id);
    auto Native = net_instances.find(Id);
    auto Control = Replication.Controls.find(Id);
    const uint64_t Revision = Control == Replication.Controls.end() ? 0 : Control->second;
    return Known != View->second.Known.end() && Known->second.Materialized && Known->second.LastSequence <= View->second.Acked &&
        Known->second.ControlRevision == Revision && View->second.Desired.count(Id) && Native != net_instances.end() && Native->second == Known->second.Object;
}

void NetworkService::SendReplicationPhysics(int Peer, uint64_t Id, const Transform3D& Pose, const Vector3& Linear, const Vector3& Angular) {
    uint64_t Generation = 0;
    int64_t Session = 0;
    if (mode == 1) {
        if (!ReplicationPhysicsReady(Id, Peer) || !peer_seq_uid.count(Peer)) return;
        Generation = Replication.Peers.at(Peer).Known.at(Id).Generation; Session = peer_seq_uid.at(Peer);
    } else {
        auto Found = Replication.Replicas.find(Id);
        if (!Replication.Receiving || Peer != 1 || Found == Replication.Replicas.end()) return;
        Generation = Found->second.Generation; Session = gl_local_user_id();
    }
    GLRemotePayload::Codec Frame;
    Frame.Word(0x31505247, 4); Frame.Word(uint64_t(RemoteEpoch)); Frame.Word(uint64_t(Session)); Frame.Word(Id); Frame.Word(Generation);
    for (int Row = 0; Row < 3; ++Row) for (int Column = 0; Column < 3; ++Column) Frame.Number(Pose.basis[Row][Column]);
    for (const Vector3& Value : {Pose.origin, Linear, Angular}) { Frame.Number(Value.x); Frame.Number(Value.y); Frame.Number(Value.z); }
    if (Frame.Valid) rpc_id(Peer, "_replication_physics", Frame.Bytes);
}

void NetworkService::_replication_physics(PackedByteArray Bytes) {
    const int Sender = mode == 1 ? GetClientRpcSender() : (AcceptServerRpc() ? 1 : 0);
    if (!Sender || !NativeRemoteCall("_replication_physics", false) || Bytes.size() != 180 || (!Replication.Enabled && !Replication.Receiving)) { CountRemote(Replication.Rejected); return; }
    GLRemotePayload::Codec Frame; Frame.Bytes = Bytes; Frame.Reading = true;
    const uint32_t Magic = uint32_t(Frame.Word(0, 4));
    const int64_t Epoch = int64_t(Frame.Word()), Session = int64_t(Frame.Word());
    const uint64_t Id = Frame.Word(), Generation = Frame.Word();
    if (Magic != 0x31505247 || Epoch != RemoteEpoch || !Id || gl_is_static_netid(Id) || !Generation) { CountRemote(Replication.Rejected); return; }
    RobloxPart* Part = Object::cast_to<RobloxPart>(_rep_node(Id));
    if (!Part || Part->get_anchored()) { CountRemote(Replication.Rejected); return; }
    if (mode == 1) {
        if (!peer_seq_uid.count(Sender) || peer_seq_uid.at(Sender) != Session || !ReplicationPhysicsReady(Id, Sender) ||
            Replication.Peers.at(Sender).Known.at(Id).Generation != Generation || int64_t(Part->get_meta("_gl_owner", 0)) != Sender) { CountRemote(Replication.Rejected); return; }
    } else {
        auto Known = Replication.Replicas.find(Id);
        if (Session != gl_local_user_id() || Known == Replication.Replicas.end() || Known->second.Generation != Generation ||
            Known->second.Object != uint64_t(Part->get_instance_id()) || _phys_authority(Part)) { CountRemote(Replication.Rejected); return; }
    }
    Transform3D Pose;
    for (int Row = 0; Row < 3; ++Row) for (int Column = 0; Column < 3; ++Column) Pose.basis[Row][Column] = Frame.Number();
    Vector3 Values[3];
    for (auto& Value : Values) { Value.x = Frame.Number(); Value.y = Frame.Number(); Value.z = Frame.Number(); }
    Pose.origin = Values[0];
    if (!Frame.Valid || !Pose.is_finite() || !Values[1].is_finite() || !Values[2].is_finite() ||
        Values[0].length_squared() > 1e24 || Values[1].length_squared() > 1e24 || Values[2].length_squared() > 1e24) { CountRemote(Replication.Rejected); return; }
    auto& Budget = RemoteBudgets[Sender];
    if (Budget.Messages >= 256 || Budget.Bytes > 256 * 1024 - Bytes.size() || RemoteAggregate.Messages >= 1024 || RemoteAggregate.Bytes > 1024 * 1024 - Bytes.size()) { CountRemote(RemoteDropped); return; }
    ++Budget.Messages; Budget.Bytes += Bytes.size(); ++RemoteAggregate.Messages; RemoteAggregate.Bytes += Bytes.size();
    _phys_apply_remote(Part, Id, Pose, Values[1], Values[2]);
    if (mode == 1) _phys_send_culled(Id, Pose, Values[1], Values[2], _peer_positions(), Sender);
}
