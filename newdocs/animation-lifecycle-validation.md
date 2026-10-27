# GL-020 animation lifecycle qualification

Investigation baseline: `132970c6f7270062952ef872d609844b762058f8`,
2026-10-27. Working branch: `fix/gl-020-animation-lifecycle`.

## Findings recorded before implementation

- `_setup_rpcs` configures both animation directions ANY_PEER. `_relay_anim`
  uses the transport sender without checking Server role or session membership;
  `_recv_anim` trusts `who` except for ignoring the local peer.
- `peer_anim` intentionally remembers updates before puppet creation and supplies
  late joiners. It has no assigned UserId binding. Server disconnect erases it,
  but client `_recv_remove`, server loss and external puppet destruction do not.
- Local `net_anim_state` ignores disconnected playback. No initialization replay
  recovers an animation already playing when session identity arrives.
- Tracks notify on explicit play/stop only. Speed/loop changes and natural
  completion do not update remote state. `gl_anim_apply` adds a new default
  animation library on replacement, potentially colliding with the old library;
  loaded Animation resources share mutable loop configuration.
- AnimationTrack retains a raw AnimationPlayer pointer. Stop/completion dispatch
  callbacks before network notification, permitting owner destruction before
  subsequent native access. Local respawn has no animation reset notification.

These are source traces, not reproduced crashes or adversarial transport proof.
Existing GL-006/008 sender helpers, server-assigned `peer_seq_uid`, ObjectID
resolution and bounded native fixture runner supply the implementation patterns.
No independent session registry or transport redesign is needed.

## Acceptance and scope

Exercise actual AnimationPlayers and cache snapshots through the existing Godot
fixture runner: play/stop, speed/loop changes, replacement, independent players,
pre-puppet delivery, late join, respawn, disconnect/reconnect, invalid roles and
missing sessions, service replacement and scene destruction. Run the unchanged
39-case core and existing multiplayer regressions on Windows/Linux Debug/Release,
Windows core ASan and Linux full-native ASan/LSan. Keep GL-017 diagnostics and
GL-018's Windows full-native host limitation visible. No full security closure
is claimed by this functional task. Final commands/results follow qualification.
