#ifndef GL_REPLICATION_STATE_H
#define GL_REPLICATION_STATE_H

#include "gl_replication_index.h"
#include "gl_remote_delivery.h"
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/transform3d.hpp>
#include <memory>
#include <array>

namespace GLReplication {
constexpr size_t MaximumPeers = 64, MaximumOperations = 64;
constexpr size_t MaximumSnapshotBytes = 8 * 1024, MaximumCatalogBytes = 8 * 1024 * 1024;
constexpr uint32_t FrameMagic = 0x31565247, AckMagic = 0x31415247; // GRV1 / GRA1.
struct ServerRegistry {
    std::array<uint64_t, 3> Roots{};
    std::map<Identity, Identity> Objects;
    std::set<Identity> Globals;
};
inline ServerRegistry& Registry() { static ServerRegistry Value; return Value; }

struct Snapshot {
    godot::String Class, Name;
    int64_t Parent = 0; // Positive net ID, or -(scope index + 1).
    godot::PackedByteArray Bytes;
    int Nodes = 0;
    std::vector<Identity> References;
    Snapshot(const godot::String& ClassValue, const godot::String& NameValue, int64_t ParentValue,
        const godot::PackedByteArray& BytesValue, int NodesValue,
        const std::vector<Identity>& ReferencesValue) : Class(ClassValue), Name(NameValue), Parent(ParentValue),
        Bytes(BytesValue), Nodes(NodesValue), References(ReferencesValue) {}
};
struct CatalogRecord {
    Identity Object = 0;
    Identity ReferenceObject = 0, ReferenceId = 0;
    uint64_t Revision = 0;
    uint64_t Scan = 0;
    bool Static = false, Global = true;
    godot::Transform3D Pose;
    std::shared_ptr<const Snapshot> Data;
};
struct Accepted {
    Identity Object = 0;
    uint64_t Generation = 0, Revision = 0, EnteredSequence = 0, GlobalSequence = 0, LastSequence = 0, ControlRevision = 0;
    int64_t Parent = 0;
    bool Materialized = false, Global = true;
    std::vector<Identity> References;
};
struct Peer {
    int64_t Session = 0;
    uint64_t DependencySince = 0;
    uint64_t Sent = 0, Acked = 0, WaitingSince = 0, BlockedSince = 0;
    uint64_t PlannedSequence = 0;
    bool TailDirty = true;
    std::set<Identity> Desired;
    std::map<Identity, Accepted> Known;
    std::map<Identity, Accepted> Planned;
    std::map<Identity, size_t> Dependents;
};
struct Commit {
    uint64_t Sequence = 0;
    std::map<Identity, Accepted> Changes;
    std::vector<Identity> Removed;
    uint64_t Enters = 0, Leaves = 0, Retired = 0, Updates = 0;
};
struct Batch {
    godot::PackedByteArray Bytes;
    std::shared_ptr<Commit> Prepared;
};
inline GLRemoteDelivery::Limits StructuralLimits() {
    GLRemoteDelivery::Limits Value;
    Value.PeerBytes = 256 * 1024; Value.PeerMessages = 256;
    Value.TotalBytes = 16 * 1024 * 1024; Value.TotalMessages = 16384; Value.Peers = MaximumPeers;
    return Value;
}
inline GLRemoteDelivery::Limits StructuralReceiveLimits() {
    auto Value = StructuralLimits();
    Value.PeerBytes = Value.TotalBytes = 4 * 1024 * 1024;
    Value.PeerMessages = Value.TotalMessages = 64; Value.Peers = 1;
    return Value;
}
struct Received {
    Identity Object = 0;
    uint64_t Generation = 0;
    int64_t Parent = 0;
    bool Static = false, Global = true;
};
struct OwnerRequest { uint64_t Object = 0; int Peer = 0; int64_t Session = 0; bool Automatic = false; };
struct State {
    bool Enabled = false, Expected = false, Receiving = false, Failed = false;
    uint64_t ConnectedAt = 0;
    int FailureLine = 0;
    uint64_t NextRevision = 0, LastRefresh = 0, ReceivedSequence = 0;
    uint64_t RefreshGeneration = 0, RefreshCursor = 0;
    int RefreshStage = 0;
    uint64_t ReceivedQueued = 0;
    int64_t ReceivedEpoch = 0, ReceivedSession = 0;
    int Cursor = 0;
    size_t CatalogBytes = 0;
    Index Spatial;
    std::map<Identity, CatalogRecord> Catalog;
    std::map<Identity, uint64_t> Dirty;
    std::map<Identity, uint64_t> Controls;
    std::map<Identity, OwnerRequest> Owners;
    std::set<Identity> Globals;
    std::map<int, Peer> Peers;
    std::map<int, int64_t> FailedSessions;
    std::map<Identity, Received> Replicas;
    GLRemoteDelivery::Queue<Batch> Outgoing{StructuralLimits()};
    GLRemoteDelivery::Queue<godot::PackedByteArray> Incoming{StructuralReceiveLimits()};
    uint64_t Desired = 0, Known = 0, Materialized = 0, Deferred = 0, Submitted = 0, Bytes = 0;
    uint64_t Enters = 0, Leaves = 0, Retired = 0, Updates = 0, Coalesced = 0;
    uint64_t QueryCells = 0, QueryCandidates = 0, Rejected = 0, Failures = 0;
    uint64_t RefreshCalls = 0, RefreshUsec = 0, RefreshMaximumUsec = 0;
    uint64_t RefreshVisited = 0, RefreshRebuilt = 0;
    uint64_t RefreshScanUsec = 0, RefreshMetadataUsec = 0, RefreshEncodeUsec = 0, RefreshIndexUsec = 0;
};
}
#endif
