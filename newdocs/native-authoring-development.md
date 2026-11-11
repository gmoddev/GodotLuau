# Luau-first native authoring development

## Baseline and acceptance — 2026-11-11

Isolated branch `feature/luau-native-authoring` starts at verified main
`5d5bb84cfecfff46d7d5048db3171a199fd754be`. Shared original checkout and existing
worktrees are preserved. Native/core main workflows `42764545584` and
`42764545794` have completed successfully; the prior integration document's
pending native observation is historical. Dependency pins and admitted hosts stay
unchanged.

Source inspection confirms Node-only ObjectID wrappers, narrow scalar/value
conversion, and no retained native Resource constructor in `_InstanceNew`.
Relay Siege's geometry/material/lighting/collision/cloth and bot presentation are
still GDScript. Existing UI/Sound wrappers have separate inherited callback gaps;
the new surface will use fixed native families and existing owner-aware dispatch
without rewriting those legacy systems.

Implementation sequence: establish [ADR-014](adr-014-native-scene-authoring.md),
implement typed scope/resource construction and focused actual-native tests,
migrate the arena and presentation, then qualify game and package inputs. Expand
UI/audio only where a complete slice can be tested. Preserve game rules, network
readiness, persistence, native Character physics and controller behavior.

Acceptance requires native property effects and invalid-batch rejection without
mutation, type/size bounds, owner/domain rejection, resource GC and retirement,
destruction/reload and callback edges, then actual migrated game scenarios.
Headless/rendered/package/sanitizer evidence must remain distinct. Unsupported
families and platform/device gaps stay explicit. No main merge is authorized.

## Worker admission

At 06:21 UTC DockerPC's heavy lease is held by `SDKCleanWindows20261111`, with
3.70 GiB disk free. No build is admitted there, no workload is terminated and no
cache/evidence/source is removed. MainPC has approximately 222 GiB free disk.
Use hosted CI for sustained builds while the worker is unavailable; keep local
runtime checks bounded and capture output with crash UI suppressed.

## First implementation milestone

`SceneScope` uses existing ObjectID Node wrappers and separate Ref-backed resource
slots. Batches validate before native setters; fixed families include primitives,
materials, shapes, lights/cameras, native controls/audio and local SoftBody3D.
Loaded/getter resources are immutable, native input is bounded, and owner
invalidation retires subscriptions/resources before queued subtree deletion.
Native and generic network publication paths exclude the subtree. Legacy unbound
Destroy/Clone/ClearAllChildren entrypoints also validate scene ownership.

Read-only independent review caught concrete callback-identity, detached cleanup,
source-deletion, StringName and generic replication/mutation gaps. Corrections
stay within the new boundary; no legacy bridge refactor is bundled. The focused
production fixture is part of the existing Integration actor, not a new framework.

Arena.luau now constructs geometry/materials/light/environment/collision/cloth and
updates bot/relay visuals with shared resources. Presentation.luau constructs the
menu/HUD/results and native audio and consumes existing snapshots/intents.
Game.gd retains transport/session/lifecycle bootstrap and observation handles for
the existing playtest. UI/arena readiness is bounded at five seconds. Native
Character construction can precede deferred arena construction; gameplay starts
after readiness, and actual spawn/physics qualification must exercise this order.

Both new Luau files pass `luau-compile --null`; `git diff --check` passes.
Runtime/platform qualification has not yet run at this milestone.
