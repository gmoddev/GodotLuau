# ADR-017: Owned native animation effects

Status: accepted for GL-053 implementation, with Windows/Linux native and
full-native sanitizer evidence in the
[qualification record](gl-053-native-qualification.md). Remaining campaign gates
stay explicit. Extends ADR-015 without changing
Character V2, GL-020 replication, VM scheduling or native object identity.

Native AnimationPlayer executes tracks autonomously after the originating Luau
call returns. Plain reflection is insufficient: a relative track can escape a
root, a method/audio track can invoke unapproved effects, and a mutable clip can
change after admission. Preserve native playback with an explicit effect check.

Scene-owned Animation and AnimationLibrary remain mutable during construction.
Attaching a library to an owned AnimationPlayer validates every clip and target,
then seals the library and clips for the remaining resource lifetime. Every
mutable alias consults the same scope's sealed ObjectID set. Getter/loaded handles
are already immutable. No extra native ownership registry or graph is introduced;
Godot Ref/resource ownership and ObjectDB identity remain authoritative.

Admission allows at most 16 clips per library, 16 libraries per player, 32 tracks
per clip, 256 keys per track and 1,024 sealed resources per scope. Clip duration
is 0.01–600 seconds. Only nearest/linear TYPE_VALUE tracks with unit key transition
are accepted. Every key must match a writable approved continuous property with
its existing bounds. Paths are relative descendants of the player's owned parent,
with one property subname. Parent traversal, absolute/unique-name escapes, method,
audio, resource and nested-property tracks reject before attachment/playback.

AnimationPlayer root_node stays '..'; no root mutation, autoplay, arbitrary
callable, movie shutdown or engine authority is exposed. Play revalidates current
targets; preview playback is denied. AnimationPlayer owns native playback and
native target lifetime handling. Existing scope retirement disconnects callbacks,
cancels yielded Luau completions and deletes owned players with their hierarchy.

Sealing intentionally changes the construction workflow: build a fresh clip/library
to revise attached animation. It prevents a mutable alias from bypassing prior
admission while Godot continues playback. It is not historical versioning or a
new resource format. Ordinary native project assets remain trusted inputs;
arbitrary imported rig/root-motion/method-track playback is not qualified by this
bounded path. GL-020's Character animation system remains separate and unchanged.
