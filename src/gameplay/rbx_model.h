#ifndef RBX_MODEL_H
#define RBX_MODEL_H
#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/classes/mesh_instance3d.hpp>
#include <godot_cpp/variant/aabb.hpp>
#include <godot_cpp/core/class_db.hpp>
#include "roblox_part.h"
#include <cmath>
using namespace godot;

// ── Model ───────────────────────────────────────────────────────────
class RBXModel : public Node3D {
    GDCLASS(RBXModel, Node3D);

    NodePath primary_part;
    Transform3D world_pivot;
    float scale_factor = 1.0f;

    void _collect_aabb(Node* Item, AABB& Box, bool& First) const {
        if (!Item || Item->is_queued_for_deletion() || Item->get_name() == StringName("PhysicsBody") ||
            Item->get_name() == StringName("Overhead")) return;
        AABB Bounds; bool HasBounds = false;
        if (auto Part = Object::cast_to<RobloxPart>(Item)) {
            Bounds = Part->get_global_transform().xform(AABB(-Part->get_size() * 0.5f, Part->get_size()));
            HasBounds = true;
        } else if (auto Mesh = Object::cast_to<MeshInstance3D>(Item)) {
            if (Mesh->get_mesh().is_valid()) { Bounds = Mesh->get_global_transform().xform(Mesh->get_aabb()); HasBounds = true; }
        }
        if (HasBounds) { Box = First ? Bounds : Box.merge(Bounds); First = false; }
        for (int Index = 0; Index < Item->get_child_count(); ++Index)
            _collect_aabb(Item->get_child(Index), Box, First);
    }

protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("set_primary_part", "p"), &RBXModel::set_primary_part);
        ClassDB::bind_method(D_METHOD("get_primary_part"),      &RBXModel::get_primary_part);
        ADD_PROPERTY(PropertyInfo(Variant::NODE_PATH, "PrimaryPart"),
                     "set_primary_part", "get_primary_part");

        ClassDB::bind_method(D_METHOD("set_world_pivot", "t"), &RBXModel::set_world_pivot);
        ClassDB::bind_method(D_METHOD("get_world_pivot"),      &RBXModel::get_world_pivot);
        ADD_PROPERTY(PropertyInfo(Variant::TRANSFORM3D, "WorldPivot"),
                     "set_world_pivot", "get_world_pivot");

        ClassDB::bind_method(D_METHOD("set_scale_factor", "f"), &RBXModel::set_scale_factor);
        ClassDB::bind_method(D_METHOD("get_scale_factor"),      &RBXModel::get_scale_factor);
        ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "ScaleFactor"),
                     "set_scale_factor", "get_scale_factor");

        ClassDB::bind_method(D_METHOD("GetPivot"),           &RBXModel::get_pivot);
        ClassDB::bind_method(D_METHOD("PivotTo", "t"),       &RBXModel::pivot_to);
        ClassDB::bind_method(D_METHOD("MoveTo", "pos"),      &RBXModel::move_to);
        ClassDB::bind_method(D_METHOD("GetBoundingBox"),     &RBXModel::get_bounding_box);
        ClassDB::bind_method(D_METHOD("GetExtentsSize"),     &RBXModel::get_extents_size);
    }

public:
    void set_primary_part(const NodePath &p) {
        auto Part = p.is_empty() ? nullptr : Object::cast_to<Node3D>(get_node_or_null(p));
        if (p.is_empty() || (Part && is_ancestor_of(Part))) primary_part = p;
    }
    NodePath get_primary_part() const { return primary_part; }
    void set_world_pivot(const Transform3D &t) { if (AcceptTransform(t)) world_pivot = (is_inside_tree() ? get_global_transform() : get_transform()).affine_inverse() * t; }
    Transform3D get_world_pivot() const { return (is_inside_tree() ? get_global_transform() : get_transform()) * world_pivot; }
    virtual bool AcceptTransform(const Transform3D& Pose) const { return Pose.is_finite() && Math::abs(Pose.basis.determinant()) > 0.000001f; }
    void set_scale_factor(float f) { if (std::isfinite(f) && f > 0 && f <= 100) scale_factor = f; }
    float get_scale_factor() const { return scale_factor; }

    // Si hay PrimaryPart el pivote es el suyo, como en Roblox.
    Transform3D get_pivot() const {
        if (!primary_part.is_empty()) {
            Node3D *pp = Object::cast_to<Node3D>(get_node_or_null(primary_part));
            if (pp) return pp->get_global_transform();
        }
        return get_world_pivot();
    }

    void pivot_to(const Transform3D &t) {
        if (!AcceptTransform(t)) return;
        Transform3D cur = get_pivot();
        Transform3D delta = t * cur.affine_inverse();
        Transform3D Pose = delta * (is_inside_tree() ? get_global_transform() : get_transform());
        if (!AcceptTransform(Pose)) return;
        if (is_inside_tree()) { set_global_transform(Pose); force_update_transform(); }
        else set_transform(Pose);
    }

    void move_to(const Vector3 &pos) {
        Transform3D t = get_pivot();
        t.origin = pos;
        pivot_to(t);
    }

    AABB get_bounding_box() const {
        AABB box; bool first = true;
        for (int k = 0; k < get_child_count(); k++)
            _collect_aabb(get_child(k), box, first);
        return first ? AABB((is_inside_tree() ? get_global_position() : get_position()), Vector3()) : box;
    }

    Vector3 get_extents_size() const { return get_bounding_box().size; }
};

#endif
