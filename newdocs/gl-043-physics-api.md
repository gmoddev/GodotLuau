# GL-043 physics binding contract

This contract is [qualified](gl-043-development.md#scoped-qualification-complete)
at `3227290` on `fix/gl-043-raycast-impulses`. It is not merged into main.
Existing engine, dependency, authority and controller contracts remain in place.

## Workspace raycasts

The existing `Workspace:Raycast(Origin, Direction, Params?)` returns nil on a
miss, or a table with Instance, Position, Normal, Distance and the existing nil
Material field. `FindPartOnRay` retains its existing alias/call shape; this does
not add the separate Roblox Ray-object overload.

Origin/Direction accept native Vector3 or explicit numeric X/Y/Z tables. Their
coordinates and computed endpoint must be finite; direction squared magnitude
must also be finite. The existing direction normalization, zero/small-direction
negative-Z fallback and MaxDistance default of 1000 remain unchanged. Direction
length is not changed into Roblox's segment-length contract in this issue.
The legacy numeric third argument remains MaxDistance. A zero distance misses;
negative/nonfinite distances fail.

| Params field | Supported behavior |
| --- | --- |
| FilterDescendantsInstances | Dense array of up to 64 native Instance wrappers; a collider matches its own node or an ancestor in the array |
| FilterType | Enum.RaycastFilterType.Include (0) accepts matching colliders; Exclude (1, default) skips them |
| MaxDistance | Finite nonnegative distance, as before for valid input |

Empty Include misses; empty Exclude performs an ordinary cast. Duplicate roots
are valid and count toward the entry limit. Destroyed or queued-for-deletion
roots do not match. Parameters are read afresh on every invocation. The returned
Instance remains the actual collision node, including the internal PhysicsBody
for Character hits; a Character filter root still includes that descendant.
Anonymous Godot server bodies retain the existing hit table with nil Instance;
they have no Node ancestry to match an Include root.

Filtering reissues the same original segment with rejected collision RIDs in a
native exclusion array. It does not shift the origin, mutate collision layers,
scan the scene or return a farther ineligible hit. At most 128 native queries
and 256 collider/ancestor nodes per hit are examined. Exceeding either work bound
raises an explicit error rather than silently reporting a miss. Native query
containers are destroyed before raising that error.

Malformed filter arrays, unsupported FilterType values, wrong userdata and
nonfinite input raise errors. Plain table fields are read without metamethod
callbacks. IgnoreWater and RespectCanCollide remain unsupported inherited
options; no collision-group or material compatibility claim is added here.

## Impulses

`Part:ApplyImpulse(Value)` and `Part:ApplyAngularImpulse(Value)` accept native
Vector3 and legacy `{X=number, Y=number, Z=number}` tables. They invoke Godot's
central impulse and torque impulse respectively, and return no values.
All three explicit components must be numeric and finite after conversion to
native coordinates. Missing, wrong-type and nonfinite values fail before an
impulse is applied; they no longer silently substitute zero components.

These methods keep the existing CanWriteCharacter check and native network
ownership behavior. They grant no new authority. Retained methods capture an
ObjectID through the existing helper and resolve the live Part at invocation;
deleted/queued Parts produce a no-op. The argument's table fields cannot run
metamethod callbacks during native validation. No solver, collision response,
mass policy, Vector3 math convention or replication format is changed.
