#ifndef GL_REMOTE_DELIVERY_H
#define GL_REMOTE_DELIVERY_H

// Remote-owned encoded/decoded work. This component does not execute Lua,
// resolve objects, own transport handles or manufacture native ACK evidence.
#include <cstdint>
#include <cstddef>
#include <limits>
#include <list>
#include <map>
#include <memory>
#include <new>
#include <optional>
#include <tuple>
#include <vector>

namespace GLRemoteDelivery {
struct Stream {
    int Peer = 0;
    uint64_t Epoch = 0, Session = 0, Endpoint = 0, Publication = 0;
    unsigned Direction = 0;
    bool operator==(const Stream& Other) const {
        return std::tie(Peer, Epoch, Session, Endpoint, Publication, Direction) ==
            std::tie(Other.Peer, Other.Epoch, Other.Session, Other.Endpoint, Other.Publication, Other.Direction);
    }
};

struct Limits {
    size_t PeerBytes = 1024 * 1024, PeerMessages = 1024;
    size_t TotalBytes = 16 * 1024 * 1024, TotalMessages = 16384;
    size_t Peers = 4095, FrameBytes = 65536;
};

enum class Result { Accepted, Replaced, Invalid, Stale, PeerFull, GlobalFull, Allocation };

inline bool NextSequence(uint64_t Current, uint64_t& Candidate) {
    if (Current >= uint64_t(std::numeric_limits<int64_t>::max())) return false;
    Candidate = Current + 1;
    return true;
}

template<class Payload> struct Message {
    Stream Key;
    int Delivery = 0;
    uint64_t Sequence = 0, EnqueuedUsec = 0;
    uint64_t Object = 0, LocalGeneration = 0;
    size_t Bytes = 0;
    std::shared_ptr<const Payload> Body;
};

template<class Payload, class Allocator = std::allocator<Message<Payload>>> class Queue {
public:
    using Entry = Message<Payload>;
    struct Totals { size_t Bytes = 0, Messages = 0, Peers = 0; };

private:
    struct PeerQueue { size_t Bytes = 0; std::list<Entry, Allocator> Entries; };
    Limits Policy;
    std::map<int, PeerQueue> Peers;
    size_t Bytes = 0, Messages = 0;

    static bool Exceeds(size_t Current, size_t Added, size_t Limit) {
        return Current > Limit || Added > Limit - Current;
    }
    static bool Positive(uint64_t Value) {
        return Value && Value <= uint64_t(std::numeric_limits<int64_t>::max());
    }
    static typename std::list<Entry, Allocator>::const_iterator Replacement(const PeerQueue& Peer, const Entry& Candidate) {
        if (Candidate.Delivery == 2) {
            for (auto It = Peer.Entries.begin(); It != Peer.Entries.end(); ++It)
                if (It->Delivery == 2 && It->Key == Candidate.Key) return It;
        }
        return Peer.Entries.end();
    }

public:
    explicit Queue(Limits Value = Limits()) : Policy(Value) {}
    Totals GetTotals() const { return {Bytes, Messages, Peers.size()}; }
    Totals GetPeerTotals(int Peer) const {
        auto Found = Peers.find(Peer);
        return Found == Peers.end() ? Totals() : Totals{Found->second.Bytes, Found->second.Entries.size(), 1};
    }
    int NextPeer(int After) const {
        if (Peers.empty()) return 0;
        auto It = Peers.upper_bound(After);
        return (It == Peers.end() ? Peers.begin() : It)->first;
    }
    const Entry* Front(int Peer) const {
        auto Found = Peers.find(Peer);
        return Found == Peers.end() ? nullptr : &Found->second.Entries.front();
    }
    Result Assess(const Entry& Candidate, bool Supersede = true, bool CheckGlobal = true) const {
        const Stream& Key = Candidate.Key;
        if (Key.Peer <= 0 || Key.Direction > 1 || !Positive(Key.Epoch) || !Positive(Key.Session) ||
            !Positive(Key.Endpoint) || !Positive(Key.Publication) || !Candidate.Object || !Candidate.LocalGeneration ||
            !Candidate.Body || !Candidate.Bytes || Candidate.Bytes > Policy.FrameBytes || Candidate.Delivery < 0 || Candidate.Delivery > 2 ||
            (Candidate.Delivery == 2 ? !Positive(Candidate.Sequence) : Candidate.Sequence != 0)) return Result::Invalid;
        auto Found = Peers.find(Key.Peer);
        size_t Previous = 0, AddedMessages = 1, PeerBytes = 0, PeerMessages = 0;
        if (Found != Peers.end()) {
            const PeerQueue& Peer = Found->second;
            PeerBytes = Peer.Bytes; PeerMessages = Peer.Entries.size();
            if (Supersede) {
                auto Pending = Replacement(Peer, Candidate);
                if (Pending != Peer.Entries.end()) {
                    if (Pending->Object != Candidate.Object || Pending->LocalGeneration != Candidate.LocalGeneration) return Result::Invalid;
                    if (Candidate.Sequence <= Pending->Sequence) return Result::Stale;
                    Previous = Pending->Bytes; AddedMessages = 0;
                }
            }
        } else if (Peers.size() >= Policy.Peers) return Result::PeerFull;
        if (Exceeds(PeerBytes - Previous, Candidate.Bytes, Policy.PeerBytes) ||
            Exceeds(PeerMessages, AddedMessages, Policy.PeerMessages)) return Result::PeerFull;
        if (CheckGlobal && (Exceeds(Bytes - Previous, Candidate.Bytes, Policy.TotalBytes) ||
            Exceeds(Messages, AddedMessages, Policy.TotalMessages))) return Result::GlobalFull;
        return AddedMessages ? Result::Accepted : Result::Replaced;
    }
    Result Push(const Entry& Candidate, bool Supersede = true) {
        Result Admission = Assess(Candidate, Supersede);
        if (Admission != Result::Accepted && Admission != Result::Replaced) return Admission;
        auto Found = Peers.find(Candidate.Key.Peer);
        if (Admission == Result::Replaced) {
            PeerQueue& Peer = Found->second;
            for (Entry& Pending : Peer.Entries) if (Pending.Delivery == 2 && Pending.Key == Candidate.Key) {
                Bytes -= Pending.Bytes; Peer.Bytes -= Pending.Bytes;
                Pending = Candidate; // shared immutable ownership; no allocation.
                Bytes += Pending.Bytes; Peer.Bytes += Pending.Bytes;
                return Result::Replaced;
            }
            return Result::Invalid;
        }
        bool Created = false;
        try {
            if (Found == Peers.end()) {
                Found = Peers.emplace(Candidate.Key.Peer, PeerQueue()).first;
                Created = true;
            }
            Found->second.Entries.push_back(Candidate);
        } catch (const std::bad_alloc&) {
            if (Created) Peers.erase(Found);
            return Result::Allocation;
        }
        Found->second.Bytes += Candidate.Bytes; Bytes += Candidate.Bytes; ++Messages;
        return Result::Accepted;
    }
    const Entry* Pending(const Stream& Key) const {
        auto Found = Peers.find(Key.Peer);
        if (Found == Peers.end()) return nullptr;
        for (const Entry& Entry : Found->second.Entries)
            if (Entry.Delivery == 2 && Entry.Key == Key) return &Entry;
        return nullptr;
    }
    // One destination entry per peer. Allocate all nodes before committing any
    // fanout, so an allocation/global-bound rejection leaves existing work intact.
    Result PushBatch(const std::vector<Entry>& Candidates) {
        if (Candidates.size() > Policy.Peers) return Result::PeerFull;
        size_t FinalBytes = Bytes, FinalMessages = Messages, NewPeers = 0;
        int PreviousPeer = 0;
        for (const Entry& Candidate : Candidates) {
            if (Candidate.Key.Peer <= PreviousPeer) return Result::Invalid;
            PreviousPeer = Candidate.Key.Peer;
            Result Admission = Assess(Candidate, true, false);
            if (Admission != Result::Accepted && Admission != Result::Replaced) return Admission;
            if (Admission == Result::Replaced) FinalBytes -= Pending(Candidate.Key)->Bytes;
            else {
                if (Exceeds(FinalMessages, 1, Policy.TotalMessages)) return Result::GlobalFull;
                ++FinalMessages;
            }
            if (!Peers.count(Candidate.Key.Peer)) ++NewPeers;
        }
        if (Exceeds(Peers.size(), NewPeers, Policy.Peers)) return Result::PeerFull;
        for (const Entry& Candidate : Candidates) {
            if (Exceeds(FinalBytes, Candidate.Bytes, Policy.TotalBytes)) return Result::GlobalFull;
            FinalBytes += Candidate.Bytes;
        }
        std::map<int, PeerQueue> Staged;
        try {
            for (const Entry& Candidate : Candidates) {
                auto Added = Staged.emplace(Candidate.Key.Peer, PeerQueue()).first;
                Added->second.Entries.push_back(Candidate);
                Added->second.Bytes = Candidate.Bytes;
            }
        } catch (const std::bad_alloc&) { return Result::Allocation; }
        for (auto It = Staged.begin(); It != Staged.end();) {
            auto Current = Peers.find(It->first);
            if (Current == Peers.end()) {
                Peers.insert(Staged.extract(It++)); // Node ownership transfer; no allocation.
                continue;
            }
            PeerQueue& Peer = Current->second;
            const Entry& Candidate = It->second.Entries.front();
            const Entry* Old = Candidate.Delivery == 2 ? Pending(Candidate.Key) : nullptr;
            if (Old) {
                for (Entry& Pending : Peer.Entries) if (&Pending == Old) {
                    Peer.Bytes -= Pending.Bytes;
                    Pending = Candidate;
                    Peer.Bytes += Candidate.Bytes;
                    break;
                }
            } else {
                Peer.Bytes += Candidate.Bytes;
                Peer.Entries.splice(Peer.Entries.end(), It->second.Entries);
            }
            ++It;
        }
        Bytes = FinalBytes; Messages = FinalMessages;
        return Result::Accepted;
    }
    std::optional<Entry> Take(int Peer) {
        auto Found = Peers.find(Peer);
        if (Found == Peers.end()) return std::nullopt;
        Entry Value = Found->second.Entries.front();
        Found->second.Entries.pop_front();
        Found->second.Bytes -= Value.Bytes; Bytes -= Value.Bytes; --Messages;
        if (Found->second.Entries.empty()) Peers.erase(Found);
        return Value;
    }
    template<class Predicate> size_t Retire(Predicate Match) {
        size_t Removed = 0;
        for (auto Peer = Peers.begin(); Peer != Peers.end();) {
            for (auto It = Peer->second.Entries.begin(); It != Peer->second.Entries.end();) {
                if (!Match(*It)) { ++It; continue; }
                Bytes -= It->Bytes; Peer->second.Bytes -= It->Bytes; --Messages; ++Removed;
                It = Peer->second.Entries.erase(It);
            }
            if (Peer->second.Entries.empty()) Peer = Peers.erase(Peer); else ++Peer;
        }
        return Removed;
    }
    void Clear() { Peers.clear(); Bytes = 0; Messages = 0; }
};
} // namespace GLRemoteDelivery
#endif
