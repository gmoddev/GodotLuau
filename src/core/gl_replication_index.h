#ifndef GL_REPLICATION_INDEX_H
#define GL_REPLICATION_INDEX_H

// Server query projection. Native SceneTree/ObjectID state remains the
// authority; this index stores only bounded server-owned query snapshots.
#include <cmath>
#include <cstdint>
#include <map>
#include <new>
#include <set>
#include <tuple>
#include <vector>

namespace GLReplication {
using Identity = uint64_t;
struct Position { double X = 0, Y = 0, Z = 0; };
struct Item {
    Identity Id = 0, Object = 0, Parent = 0;
    Position Point;
    bool Global = false;
    std::vector<Identity> References;
};
struct QueryResult {
    enum class Status { Ready, Invalid, MissingDependency, Limit } Result = Status::Invalid;
    std::set<Identity> Desired;
    size_t Cells = 0, Candidates = 0;
};
class Index {
    using Cell = std::tuple<int64_t, int64_t, int64_t>;
    std::map<Identity, Item> Items;
    std::map<Cell, std::set<Identity>> Cells;
    std::set<Identity> Globals;
    static bool Valid(Position Point) {
        return std::isfinite(Point.X) && std::isfinite(Point.Y) && std::isfinite(Point.Z) &&
            std::abs(Point.X) <= 1e12 && std::abs(Point.Y) <= 1e12 && std::abs(Point.Z) <= 1e12;
    }
    static Cell Location(Position Point) {
        return {int64_t(std::floor(Point.X / 256)), int64_t(std::floor(Point.Y / 256)), int64_t(std::floor(Point.Z / 256))};
    }
    void Unlink(const Item& Value) {
        if (Value.Global) Globals.erase(Value.Id);
        else {
            auto Found = Cells.find(Location(Value.Point));
            if (Found == Cells.end()) return;
            Found->second.erase(Value.Id);
            if (Found->second.empty()) Cells.erase(Found);
        }
    }
public:
    static constexpr size_t MaximumObjects = 16384, MaximumView = 4096, MaximumReferences = 64;
    const Item* Get(Identity Id) const {
        auto Found = Items.find(Id); return Found == Items.end() ? nullptr : &Found->second;
    }
    size_t Size() const { return Items.size(); }
    bool Set(Item Value) {
        if (!Value.Id || !Value.Object || !Valid(Value.Point) || Value.References.size() > MaximumReferences ||
            (!Items.count(Value.Id) && Items.size() == MaximumObjects)) return false;
        auto Found = Items.find(Value.Id);
        const bool Existed = Found != Items.end();
        const bool OldGlobal = Existed && Found->second.Global;
        const Cell NewCell = Location(Value.Point);
        const Cell OldCell = Existed ? Location(Found->second.Point) : NewCell;
        const bool Same = Existed && OldGlobal == Value.Global && (OldGlobal || OldCell == NewCell);
        bool Linked = false;
        try {
            if (!Same) {
                if (Value.Global) Linked = Globals.insert(Value.Id).second;
                else Linked = Cells[NewCell].insert(Value.Id).second;
            }
            // Item's vector move assignment cannot allocate. A new map node
            // can fail, in which case the previous item and membership survive.
            Items.insert_or_assign(Value.Id, std::move(Value));
        } catch (const std::bad_alloc&) {
            if (!Same && Linked) {
                if (Value.Global) Globals.erase(Value.Id);
                else Cells.find(NewCell)->second.erase(Value.Id);
            }
            auto Bucket = Cells.find(NewCell);
            if (Bucket != Cells.end() && Bucket->second.empty()) Cells.erase(Bucket);
            return false;
        }
        if (Existed && !Same) {
            if (OldGlobal) Globals.erase(Value.Id);
            else {
                auto Bucket = Cells.find(OldCell);
                Bucket->second.erase(Value.Id);
                if (Bucket->second.empty()) Cells.erase(Bucket);
            }
        }
        return true;
    }
    void Remove(Identity Id) {
        auto Found = Items.find(Id);
        if (Found == Items.end()) return;
        Unlink(Found->second); Items.erase(Found);
    }
    QueryResult Query(Position Center, double Radius, bool IncludeSpatial = true) const {
        QueryResult Result;
        if (!Valid(Center) || !std::isfinite(Radius) || Radius <= 0 || Radius > 512) return Result;
        if (Globals.size() > MaximumView) { Result.Result = QueryResult::Status::Limit; return Result; }
        auto Minimum = Location({Center.X - Radius, Center.Y - Radius, Center.Z - Radius});
        auto Maximum = Location({Center.X + Radius, Center.Y + Radius, Center.Z + Radius});
        std::set<Identity> Scheduled = Globals;
        std::vector<Identity> Seeds(Globals.begin(), Globals.end());
        const double Distance = Radius * Radius;
        if (IncludeSpatial) for (int64_t X = std::get<0>(Minimum); X <= std::get<0>(Maximum); ++X)
            for (int64_t Y = std::get<1>(Minimum); Y <= std::get<1>(Maximum); ++Y)
                for (int64_t Z = std::get<2>(Minimum); Z <= std::get<2>(Maximum); ++Z) {
                    ++Result.Cells;
                    auto Found = Cells.find({X, Y, Z});
                    if (Found == Cells.end()) continue;
                    for (Identity Id : Found->second) {
                        ++Result.Candidates;
                        const auto& Point = Items.at(Id).Point;
                        double DX = Point.X - Center.X, DY = Point.Y - Center.Y, DZ = Point.Z - Center.Z;
                        if (DX * DX + DY * DY + DZ * DZ <= Distance && Scheduled.insert(Id).second) Seeds.push_back(Id);
                        if (Scheduled.size() > MaximumView) { Result.Result = QueryResult::Status::Limit; return Result; }
                    }
                }
        while (!Seeds.empty()) {
            Identity Id = Seeds.back(); Seeds.pop_back();
            if (Result.Desired.count(Id)) continue;
            auto Found = Items.find(Id);
            if (Found == Items.end()) { Result.Result = QueryResult::Status::MissingDependency; Result.Desired.clear(); return Result; }
            if (Result.Desired.size() == MaximumView) { Result.Result = QueryResult::Status::Limit; Result.Desired.clear(); return Result; }
            Result.Desired.insert(Id);
            if (Found->second.Parent && Scheduled.insert(Found->second.Parent).second) Seeds.push_back(Found->second.Parent);
            for (Identity Reference : Found->second.References) if (Reference && Scheduled.insert(Reference).second) Seeds.push_back(Reference);
            if (Scheduled.size() > MaximumView) { Result.Result = QueryResult::Status::Limit; Result.Desired.clear(); return Result; }
        }
        Result.Result = QueryResult::Status::Ready;
        return Result;
    }
};
}
#endif
