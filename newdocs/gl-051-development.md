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

## Editor/native follow-up

The declaration workflow `43042497368` passes Windows/Linux at `23d7a67`, after
correcting the test probe's call to the actual pinned five-argument definition
loader. It loads/checks the emitted definitions and eleven positive/negative
programs; the earlier compile failures remain retained. This is type evidence,
not native runtime evidence.

Windows run `43039608365` exposes two C++ namespace collisions: the imported
Vector kind conflicts with godot::Vector, and the Classes callback conflicts with
the generated class table. Qualify the two enum uses and rename only the private
callback. Linux run `43041827223` independently repeats the Azure mirror stall;
it also never compiles C++. Cancel its obsolete Windows build, which has the same
known source collisions. No canceled attempt counts as qualification.

The next revision routes ephemeral Ubuntu provisioning through the official
HTTPS archive with bounded APT retries/timeouts. Compiler package selection,
signature verification, step deadlines, engine pins and admission remain unchanged.
This corrects observed mirror behavior, not product tests.

Review also corrects the new ClassDB resource-construction path to retain its
owning Variant until the scoped Ref acquires ownership. This is a source-verified
ownership correction, not a claimed reproduced crash. New runtime coverage tests
resource identity/cache reuse and immutable getter handles through native methods.

Editor implementation now shares checked metadata/AST inspection between actual
Godot language completion/validation hooks and `LuauScript.InspectNativeCode`.
It provides approved constructor/property/method/signal completion and bounded,
source-located native policy diagnostics without executing scripts. It conserves
dynamic child lookup and unrelated legacy completion. This is focused native
analysis, not a complete replacement Luau type checker or runtime debugger.
The new production-path editor fixture and changed native code await execution.

## Representative migration and current evidence

At `26e281f`, core workflow `43045290405` and generated-binding workflow
`43045290450` pass on Windows/Linux, including the actual pinned Luau checker.
Native workflow `43045290491` still fails Linux before compilation. Its retained
log now identifies temporary DNS failure for archive.ubuntu.com; the prior
configured Azure mirror also failed DNS. The next bounded provisioning correction
selects a reachable signed Ubuntu archive before APT, forces IPv4, and rejects
index-update errors. It keeps clang-19, all engine/dependency pins and deadlines.
Windows is still building the admitted host; no native pass is claimed.

Relay Siege now uses a preauthored native relay PackedScene through a caller-scope
Luau module factory, shared native texture/material/UI references, typed text
signals and metadata-driven audio calls. Geometry, collision positions, gameplay
rules, session/network/persistence and shutdown ordering stay the same. The
bootstrap's remaining ClassDB/NetworkService/Player lifecycle duties are native
authority and initialization boundaries; moving them through this scoped scene
API would improperly widen authority. The module setup is the appropriate small
bootstrap addition, not a cosmetic rewrite. Graphical/game execution is pending.

Local `Game.gd` headless syntax checking, generation drift and all nine policy
tests pass. Source review also adds embedded-NUL rejection to PackedScene node
names, matching existing authored-name validation. DockerPC remains leased by
the unrelated LuiSdkRecovery campaign at 15:17 UTC; no worker workload is started.
[The API guide](gl-051-native-api.md) records exact supported behavior and limits.

A focused editor fixture now opens a real Luau resource in Godot's headless
ScriptEditor and requests completion through its public CodeEdit API, in addition
to reusing production diagnostics cases. It exercises the actual language hook,
does not execute the source, and adds no debugger/IDE abstraction. Hosted execution
and the new scene/resource/game migration remain pending, not passing by syntax.

Focused boundary review finds a concrete new dispatch gap: Connect cast a valid
resource target to Node and consulted signal metadata without checking the cast.
Reject non-Node sources first, and add a resource/Pressed negative case. This is
a source-verified null-dereference path, not a claimed reproduced crash. The same
fixture adds real Font UI/3D reuse, serialized Control layout and pre-instantiation
node/depth-budget rejection. These cover new behavior rather than retesting the
qualification runner. Native execution remains pending.

The corrected Linux provisioning step passes in `43047956663` and reaches the
unchanged admitted host build. Its Windows job also builds the host. The preceding
Windows revision reaches extension compilation. The next complete qualification
cohort is `3150d9c` with the non-Node signal guard and expanded boundary fixture;
later package documentation changes preserve those native/fixture inputs.
Staging now ships both API guides and keeps external source links at the exact
game commit, alongside the already packaged generated native definitions.

Windows `43045290491` compiles the expanded scene runtime but fails the new
standalone editor translation unit: Dictionary/Array headers forward-declare
Variant, so the inspector needs an explicit variant.hpp include. Add that one
include; retained diagnostics identify this compile error rather than a runtime
failure. Obsolete `1f2a5a4`/`3150d9c` native builds have the same missing include
and are canceled to avoid repeating known failed inputs. Core passes remain
valid for their unchanged core sources. No canceled run counts as native evidence.

At `6a04029` the single corrected editor translation unit passes a local MSVC
syntax-only probe in 1.91 seconds, using headers generated from the pinned API.
The initial command quoting failure is retained separately. This is a lightweight
compile check, not a local full build or native runtime pass. Fresh workflows are
native `43049375469`, full-native sanitizers `43049541634`, and non-publishing
candidate `43049547160`; all remain pending.

External tooling documentation now gives an explicit standard-platform Luau-LSP
profile instead of suggesting the inherited Roblox definitions are appropriate.
Those historical definitions advertise unsupported compatibility APIs and remain
outside the generated native contract. Add actual RelayFactory source checking
to the existing pinned checker probe; this qualifies a production composition
module, without pretending every inherited game/service global is statically
declared. The shipped example settings do not modify user editor preferences.

Review against the exact admitted Godot revision's ScriptLanguageExtension
adapter finds a real editor contract discrepancy before UI execution: `result`
must be an Error integer, not the options Array, and each option requires icon
and font_color fields. Correct the new native completion shape and the two
inherited legacy result assignments; no completion algorithm is refactored.
Use PackedInt32Array matches and test the production response shape plus actual
native and legacy CodeEdit completion. Validation's error dictionaries already
match the engine contract. This is source-verified evidence, not a claimed UI pass.

Linux `43049375469` compiles the runtime and passes the initial Integration,
listen/dedicated/editor lifecycle stage at `6a04029`. Retained logs include
`[Bindings:Qualification] PASS`: actual font/layout/resource calls, scene
preflight and budgets, clone/reparent, foreign/stale owners and callback retirement
all execute successfully. Its subsequent real ScriptEditor stage fails because
the fixture searched only CodeEdit descendants: get_base_editor can itself be
the CodeEdit. Correct that fixture selection without weakening its completion
assertion. Startup also exposes three inherited missing required public-metadata
hooks; implement explicit empty function/constant/annotation lists, and reject
those observed missing-hook errors. Do not advertise unimplemented public globals.
The completion-shape correction and actual UI completion still await execution.

Latest Linux `43052421375` stops in provisioning: the working kernel mirror's TLS
handshake exceeds the four-second connect bound after two DNS failures. Retain
that attempt, prefer the empirically working mirror and allow one bounded retry
with a ten-second connection/fifteen-second transfer limit. The five-minute step
deadline and signed APT checks stay unchanged; no machine DNS settings change.

The next candidate cohort also runs the existing real-editor fixture against
each SCons production library before the adapter build, using the already pinned
official editor. This directly qualifies the new editor feature in Debug/Release
on both platforms and retains its normal logs/results in existing profile
evidence. It adds no new harness, host profile, assertion relaxation or qualifier
test suite. Core/native/sanitizer and package gates remain intact.

Full-native run `43049541634` passes both platforms at `6a04029`: 1167 instrumented
translation units, all controls, 85 core/141 native actors and expanded binding
assertions pass without unexpected reports. Retained required evidence/hashes
verify. [The qualification record](gl-051-qualification.md) separates that exact
product from the corrected current editor source and pending final cohorts.
The current language-header syntax probe passes in 2.55 seconds after matching
the pinned Windows TYPED_METHOD_BIND compile definition; the initial probe-only
configuration failure is retained and is not a product build failure.

The first candidate `43049547160` is accepted at `6a04029`: all four production
profiles and both extracted-package gates pass. Verified Windows package hashes
and aggregate acceptance are retained. With its exact Windows libraries and the
unchanged admitted renderer, actual solo play passes 27 checks, fresh-process
recovery seven, menu teardown/retry five and four-player listen play passes.
Solo mean frame time is 33.476 ms at the same 30 FPS cap versus retained 33.489 ms;
this is not a speed improvement claim. The reporting-point node count is 175
versus 170, matching the additional relay roots/module/texture control.

Actual Windows editor run `43052421375` removes the missing-hook errors but has
an inactive completion list and then times out on legacy math completion. The
fixture now waits for initial filesystem scanning and activates/focuses the
Script CodeEdit inside the headless process before requesting completion.
This changes no desktop focus or user editor settings.

The timeout also exposes a genuine inherited native bug: analyze_usage passes
signed UTF-8 cursor bytes to std::isalnum. A tiny controlled MSVC Debug CRT probe
reproduces the c>=-1 && c<=255 assertion with report dialogs explicitly disabled.
Cast byte classifiers to unsigned char, bound the UTF-32 identifier scan to ASCII,
and correct the remaining early completion status returns. This is a bounded
editor fix, not a completion refactor. Native/legacy actual-editor assertions
remain required; no timeout or assertion is weakened.

Four-player dedicated rendered play also passes with the same verified runtime;
the server is headless and four clients render. In the `358d613` production Linux
Debug editor attempt, legacy math completes but the first native request precedes
initial editor-layout loading. This supports the readiness/focus fixture fix.
That execution additionally reports a concrete shutdown diagnostic from the
legacy static PlaceholderTexture2D icon Ref after RenderingServer destruction.
Return an empty optional icon instead: Godot already selects themed icons by
completion kind. No static rendering resource is needed. Keep this small lifetime
correction separate from the passing gameplay/runtime evidence.

The focused local execution with the retained `358d613` SCons product establishes
that readiness/focus alone does not fix colon completion. The exact Godot source
configures CodeEdit prefixes without `:`; its candidate filter cancels the empty
word after a colon even when forced. The same exact cursor text returns native
options from InspectNativeCode, and a controlled diagnostic addition of the colon
prefix makes the real language/UI route pass. That experiment is attribution,
not final product qualification.

Add a small editor-only native plugin using public ScriptEditor/CodeEdit APIs to
configure colon completion for Luau tabs. It holds no tab/resource pointers,
coalesces deferred changes and disconnects on exit. Register it only at Godot's
existing editor module level. The production fixture must observe this automatic
configuration, exercise native/legacy completion and leave GDScript tabs alone;
it does not set the prefix itself. Also reject any unhandled editor error,
including the observed shutdown diagnostic. No engine or admitted-host change.

At `5f876d3`, Linux native `43063379869` passes all 141 actors and 19 actual editor
checks. Downloaded evidence matches the current 114-file native fingerprint
`728d0c69fb1f717448897166514b500ee097c50815c777e574fdc866f2d2b5dc`;
all 420 native log hashes verify. Automatic colon setup, actual native/legacy
completion, GDScript-tab isolation and error-free editor shutdown pass. Windows
and four production profiles continue. Final sanitizer run `43066333042` targets
the same native/fixture inputs at docs tip `d4d8711`; no pending pass is inferred.
Obsolete native runs at `a1d49b6`/`6da3442` were canceled for the known missing-prefix
input; the `358d613` candidate already completed with its retained editor failures.

Windows native `43063379869` now also passes the final 728d/114-file inputs:
141 actors and 19 actual editor checks. All 425 Windows retained native log
hashes verify, alongside the 420 Linux hashes. Both actual editors configure the
Luau colon prefix automatically, preserve legacy math completion and GDScript
tabs, and shut down without unhandled errors. Core `43063379932` also passes
Windows/Linux at `5f876d3`. Production candidate and final sanitizer gates remain
pending; no feature code changes are needed for these passing outcomes.

Final full-native sanitizer `43066333042` passes both platforms at `d4d8711`,
whose native/fixture inputs match `5f876d3`. The final 728d set instruments 1168
translation units, including the editor plugin: Windows has 25 passing stages,
Linux 26, all detection controls and 85 core/141 native actors pass without
unexpected reports. All 680 Windows / 684 Linux retained file hashes verify.
Linux omits only one disposable messaging JSON; required evidence is present.
Current candidate Linux Debug/Release profiles also pass all existing gates and
19 actual editor checks each. Windows production profiles and extracted-package
acceptance are still running. Retain all earlier failed and passing cohorts.

## Final qualification and delivery — 2026-11-11

Candidate `43063482878` is accepted at implementation `5f876d3`, tree
`692d059c2ed48a75e795376e4b8563eb56770410`: all ten jobs pass. Downloaded Windows
and Linux candidate archives, provenance and Debug/Release extracted-companion
startup records pass the existing CheckPackage/CheckJobs checks. All four SCons
production libraries separately pass 19 actual editor checks. Ordinary core/native
and final full-native sanitizer cohorts pass with the same 728d native inputs.
No checks, deadlines or admission requirements are weakened.

Non-publishing game package `43073257426` at docs tip `94de286` uses that exact
accepted candidate. It passes extracted startup independently of source paths,
with empty stderr. All 167 payload hashes verify, including the factory, scene,
texture, generated declarations, guides and three exact candidate native files.
The archive SHA256 is `d7c4225f2aad0523620bfee3834e8140e490630608e29d2229ed13754164f6d5`.
Retained Windows rendered solo/recovery/menu/listen/dedicated runs total 151
passing checks across twelve actors, with no failed checks. Reuse is explicit:
the later six native file changes affect only editor integration; scene binding,
gameplay and native-binding fixture sources are unchanged since that rendered
runtime. Current-product package/startup and editor/sanitizer checks are fresh.

The [qualification record](gl-051-qualification.md) and
[versioned receipt](evidence/gl051/qualification-20261111.json) retain exact
identities, verified hashes, performance samples and remaining limitations.
No new regression is observed in the exercised profiles. Partial native inference
does not supply a full debugger/navigation system; asynchronous loading, nested
scene inheritance and scope serialization remain outside the admitted contract.
GL-050 remains separately recorded and unfixed.

Final inspection finds a clean isolated checkout, no task-owned game/editor
process, unchanged dependency pins and remote main still at `c60919a`. All work is
pushed on `feature/gl-051-first-class-luau`, unmerged. Native controller default,
Scripted opt-in, release disablement and updater rejection are unchanged.

## Authorized main integration — 2026-11-11

The owner now explicitly requests a normal main merge, preserving all commits,
verifying CI and keeping releases/updater distribution disabled. This supersedes
the earlier campaign's unmerged/no-merge disposition without changing its
historical evidence or expanding qualification claims.

Freshly fetched main `c60919a` and source `2307c04` match the last verified refs.
Normal merge `11be0e8f6d5f1d1e2a0f8fb8ad70d74faba151d7` preserves all 22 feature
commits. Its tree exactly matches qualified source tree
`8a12d2c7d02fb0d3238216c5b314913f13397356`, with no conflicts or runtime
corrections. GitHub confirms the six retained qualification workflows passed.
Native/fixture/gameplay/build inputs and original qualification receipt remain
unchanged, so prior expensive sanitizer, candidate and gameplay evidence is
reused within its recorded scope. Following changes document integration only.

The [integration record](gl-051-main-integration.md) tracks fresh Windows/Linux
core/native/type CI after the main push. Those outcomes remain pending until
actual completion and evidence review. No publishing workflow is dispatched.

Main push succeeds at `397dde847b736d8d14ea222754124c44dde2d38d`. Fresh workflows
are core `43112156523`, native `43112156884` and definitions `43112156562`.
Windows core completes successfully and its downloaded XML/discovery pass the
existing 85-case checker. Linux jobs await hosted runners; Windows native/types
are building. Integration is not marked verified while those jobs are pending.

Fresh main core and definitions now pass both platforms at `397dde8`.
Downloaded core XML/discovery pass the established 85-case checker and both
input logs contain 29 passing assertions. Each generated-type log passes eleven
representative programs plus actual RelayFactory, and its declarations/catalog
match main. Both native jobs are building their existing admitted host/adapter;
final integration verification still awaits those results and retained evidence.

Linux main native CI now passes all 141 actors and 19 actual editor checks at
`397dde8`. The downloaded summary matches the qualified 728d/114-file native
inputs; all 420 retained log hashes verify, including expanded-binding PASS
markers, and actual editor shutdown has no unhandled errors. Windows native is
still building its adapter. No runtime change, retry or assertion change has
been required for integration.
