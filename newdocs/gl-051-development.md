# GL-051 first-class native Luau integration

## Verified baseline — 2026-11-11

Freshly fetched remote main is `c60919a42416d5e6c72d2b23f7801500879c3195`.
An isolated worktree/branch `feature/gl-051-first-class-luau` preserves all prior
worktrees and GL-049 qualification. GL-050 is explicitly excluded.

GL-049 has fixed constructor/property/signal lists and no generated native
declarations. Resource wrappers already retain Ref ownership with exact owner
retirement. The existing editor provides heuristic completion and compiler syntax
validation; its debug-stack API returns an empty list. Do not describe that as a
working runtime debugger or full type checker.

The pinned godot-cpp revision is unchanged. Its `extension_api.json` describes
Godot 4.3 and hashes to
`dfd54f071d53ef63d9c1be51150b38f5c55abdd68eb8b2caa357abeab4086a0f`.
The admitted runtime remains 4.7.1. Use the intersection validated by this pinned
metadata, not speculative newer engine features.

At 14:01 UTC DockerPC is leased by `LuiSdkRecovery20261111` and has about 5.15 GiB
free disk. No lease is acquired, workload disturbed, cache removed or heavy job
started there. MainPC has about 218 GiB free. Use existing hosted CI for sustained
builds while the worker is unavailable; retain bounded headless local probes.

## Implementation sequence and acceptance

1. Replace manual binding lists with checked policy/generated descriptors, while
   retaining aliases, bounds and exact GL-049 ownership. Add approved metadata
   discovery, typed methods/signals/enums and explicit denial cases.
2. Expand project resources and presentation; implement preflighted PackedScene
   adoption, same-owner clone/reparent and module factories.
3. Generate Luau declarations and editor completion from the same policy, with
   reproducible generation/drift checks and actionable native diagnostics.
4. Exercise representative scene/resource/signal composition in Relay Siege;
   evaluate bootstrap responsibilities without cosmetic language rewrites.
5. Qualify changed behavior and integration: native Windows/Linux, Debug/Release,
   existing core/native regressions, sanitizers, editor and actual game/package
   scenarios. Preserve limits and original failures; reuse unchanged evidence.

[ADR-015](adr-015-policy-driven-native-bindings.md) records the binding/composition
contract. This is implementation work; no runtime expansion is qualified merely
because metadata or declarations have been generated. Commit and push coherent
milestones, leave main untouched and keep releases/updater disabled.

## First runtime milestone

`bindings/NativePolicy.json` now declares 48 constructible classes, 105 property
entries, 26 typed native methods and 12 signal selections. These are implementation
counts, not independent runtime qualification claims. Pinned metadata validates
names/types/inheritance, and generation emits runtime tables, an inspectable
catalog and Luau definitions. SCons/native CI reject output drift. The native
fingerprint now includes the policy, generator, catalog and shipped declarations.

The runtime uses those constructors/properties, checked native calls, bounded
signal marshalling and immutable enum/discovery data. Composition implements
preflighted PackedScene adoption, same-owner clone and reparent with node/depth
budgets and reentrant liveness checks. Stored scripts/signals/groups and nested/
inherited scenes are rejected. Loading remains trusted project-only/synchronous.

Compilation, generated-type analysis, new adversarial/native cases, editor
integration and migrated gameplay are not yet qualified. Start fresh hosted
compilation/regression while independent editor/fixture work continues. Existing
GL-049 tests remain intact; new behavior receives separate assertions.

## Typed declarations and first adversarial fixtures

The next policy revision adds bounded native UI anchors/offsets needed by real
serialized controls. Metadata reports 4.3 offsets as integers, so their policy
matches that pinned type. Optional native arguments now use checked pinned
defaults rather than silently inheriting a newer host default.

Generation and nine adversarial policy tests pass locally. A real pinned-Luau
type-checker probe is added for emitted definitions and positive/negative calls;
its hosted execution is pending. The new native Integration cases cover texture/
material reuse, metadata/enums, native methods, typed signals, PackedScene
preflight, clone/reparent, foreign owner/domain denial and callback retirement.
Godot headless syntax checking passes after correcting a fixture variable that
shadowed the native Button type; the failed parse log is retained.

First native run `43039608365` fails Linux **before C++ compilation**: the Azure
Ubuntu mirror stalls downloading clang-19 packages until the existing five-minute
provisioning deadline. The retained job log establishes that environmental cause.
Windows continues compiling. No product defect or deadline change is inferred.
The next changed-source run includes the new fixtures; do not relabel this failed
provisioning attempt as runtime qualification.
