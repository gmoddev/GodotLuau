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

## Implemented contracts

The existing Server/Client sender guards and `peer_seq_uid` remain authoritative.
Animation receives are reliable AUTHORITY RPCs; client relays remain reliable
ANY_PEER with Server-role and current transport/sender checks. Both directions
also require this live NetworkService to own the current transport. Targets need
a positive assigned session, not a completed puppet or PlayerObject. Cached
records include the assigned UserId, checked during puppet creation and late join.
Invalid role/session/service, nonfinite or out-of-range speed (0–20), overlong
ID/name (1,024/128 characters) and empty play name return without cache or relay.

Existing names, argument counts/order, wire representations, channel and reliable
delivery remain intact. AUTHORITY filtering is an intentional receive-policy
correction. No new wire message, session registry, VM model or foundational
dependency is introduced. Mixed historical application versions are not qualified.

Puppet exit/removal, session departure, server loss, full disconnect, transport
replacement and service shutdown clear animation state. Puppet exit callbacks
bind the exiting ObjectID so queued old characters cannot erase replacement state.
Local respawn sends the existing stop message while the session is live. Session
initialization replays tracks already playing, recovering preconnection playback.
The local character identity is numeric; no new long-lived raw pointer is stored.
AnimationTrack now resolves its AnimationPlayer ObjectID. Speed/loop changes and
natural completion replicate; callback notification order and copied callback
lists avoid accessing track members after user signal dispatch. Per-character
clip resources prevent loop changes leaking between characters. Default-library
reuse supports replacement; current-clip settings do not restart playback.

`NetworkService.GetAnimationStates()` returns a detached native Dictionary keyed
by transport peer with Id/Name/Speed/Looped/Play/UserId fields. It is a read-only
diagnostic, not an RPC or a second animation-state implementation. Fixtures assert
this actual cache and actual AnimationPlayer clip/speed/loop/playback/position.
