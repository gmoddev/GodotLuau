# GL-020 animation authority qualification

Starting main: `3d1cf07cd44c999450b1e611b1435e64403103c0`.
Branch: `security/gl-020-animation-qualification`. Qualified implementation input:
`358d6ffc491303e498d512792d09bdb62332bb25`; final execution results are recorded
below. No external security-testing service is used. Main, dependency pins,
production publication and updater admission remain unchanged.

## Source investigation and acceptance

The historical finding predates the integrated GL-020 role/session checks and
GL-007 presentation catalog. Current `_relay_anim_v2` derives the writer from
the actual transport sender, checks its current session/correction epoch/live
Character and applies separate admission limits. `_recv_anim_v2` requires the
live server, assigned target session and admitted Character life. Legacy methods
are inert. Checked copies, target validation and gameplay-timeline protection
remain the governing ADR-006/007 contract. These are source observations; actual
rejection and positive controls must be exercised over ENet before closure.

The existing ten animation actors are extended, retaining Local, Listen,
Dedicated and Editor roles and all previous playback/lifecycle assertions.
Both normal AUTHORITY filtering and deliberately relaxed receive filtering
exercise production handlers. Cases compare actual cache, AnimationPlayer
play/speed/clip/resource identity, health, animation signal counts and controlled
resource-initializer effects. Legitimate owner traffic is a positive control.
Callback/Animator ownership, replacement lives, old sessions and actual reconnect
receive additional checks. No mocked authorization or replacement transport is
introduced. The complete native actor count remains 110; case-level evidence
must prove the new phases executed.

## Baseline and preserved attempts

DockerPC is the only local execution worker used so far. The baseline reuses the
verified Windows Debug/Release native adapters from integrated-main candidate
run `41276341255` at `b88a88b`, whose native inputs match starting main exactly.
The 89-file native fingerprint is
`559961ab22bc22ec349b8bb80cc4dd0fdc4cc4a2b180c78d37f06a59a4d401b0`.
Product hashes are verified against the retained profile manifests before use.
The frozen test-only tree is `de991451a7db9677948db8c7438d57fb5e108818`;
its source ZIP SHA256 is
`5df454c7d80908d02c57ac98d7e2f9c5f33d23230f08f9d7c26887cebe378d80`.
Raw attempts are retained under `C:/Sandbox/Codex/AnimationSecurity/`.

`baseline-Local-first` fails the combined callback-retirement assertion. The
fixture disables a newly added executable immediately, before its deferred
startup is guaranteed, and then requires its startup marker. The corrected
fixture waits with a deadline and asserts that marker before retiring the owner.
The original logs, JSON assertions and source archive remain preserved. This is
a fixture sequencing error, not a reproduced callback escape. After a bounded
ready barrier, the unchanged baseline passes Local callback ownership checks.

`baseline-Dedicated-first` also reveals that the inserted positive-control
animation phase invalidates the old seek position. Moving the original server
seek after that phase preserves the original assertion. The snapshot attempt
initially places the seek on clients without a Puppet, producing a script error
and barrier timeout; the precise server-only relocation corrects the fixture.
Both failed attempts remain retained. No runtime correction is inferred from
these harness failures.

## Reproduced defect and correction

`baseline-Dedicated-packet-cases` isolates six genuine client-to-server failures.
Godot reports invalid argument conversions yet invokes the typed native method:
integer identity/name become strings, string speed becomes a number, string loop
and integer play become booleans, and fractional epoch becomes an integer. Each
packet separately changes the real server cache, AnimationPlayer state or stop
state, then reaches the second client. The other owner's animation and health
remain unchanged. This demonstrates malformed presentation mutation/replication;
it does not demonstrate a cross-owner movement or health bypass.

`baseline-Dedicated-receive-packet-cases` reproduces eight malformed server-origin
receive cases on client2: the same primitive coercions, fractional life/target and
a 64-bit target that truncates to an existing 32-bit peer. These deliberately
malformed trusted-sender packets test receiver validation. They do not establish
that an untrusted client can forge the server's ENet sender identity.

Only `src/services/roblox_network.h` changes runtime behavior. Both v2 handlers
receive original Variants, check receiver/session authority first, then require
canonical string identity/name, boolean loop/play, finite numeric speed in 0–20,
integer epoch/life and positive signed-32-bit receive target. Bounds apply before
float narrowing. Existing catalog, Character life, admission, health, playback,
replication and lifetime checks follow unchanged. Legacy animation methods stay
inert. No dependency, native capability, ownership model or transport changes.

The RPC names, argument order/count, reliable delivery and protocol 3 are
unchanged. Normal AnimationTrack callers already emit these shapes; integer and
floating speed are both supported and exercised. Raw callers relying on implicit
string/number/bool or fractional-identifier coercion must send canonical values.
Malformed packets are dropped without mutation or replication.

Test commits `edaaa670bdfdfc875e01ad50fafa8d450178481b` and
`ede79e449b27b37e1697be386d86d598660c57ae` precede implementation commit
`358d6ffc491303e498d512792d09bdb62332bb25`. The implementation tree is
`32ae6ddf15c7a6aa115ab4bea327bff4275a0e50`; its 89-file native fingerprint is
`c651c1ff730bb2de8c16da996c09d2567e26d45865dfa25118df812d1f51d91f`.
The frozen source-2 archive SHA256 is
`f1f6c0a0bcc679dbc7ce5fcabf70f0d32a7407e4d10c53190dd5cb8f6371f59e`.
Later evidence-only commits do not change qualified runtime/fixture inputs.

## Transport, state and lifecycle coverage

`AnimationAdversarial.gd` extends the existing ten `AnimationIntegration.gd`
actors: Local server plus server/two clients in Listen, Dedicated and Editor
modes. Godot ENet and production RPC methods perform all transport checks.
AUTHORITY filtering runs first; receivers are then deliberately configured as
ANY_PEER to reach and test native sender/role checks. Correct current lives keep
forged packets from passing merely because of unrelated stale-life rejection.

Each complete profile executes 510 authority checks and 1,003 total assertions.
There are 23 separately observed client-input cases and 20 separately observed
server-input cases per network mode. Before/after snapshots inspect real cache,
clip/resource/loop identity, playback state and speed, health, start/completion
signals and controlled resource-initializer effects. The strict existing native
CI checker requires all ten phase records, successful assertions and packet
counts. Local archives retain separate actor JSON; hosted `summary.json` embeds
the complete actor records, including before/after snapshots. Downloaded records
are independently checked against the corresponding actor stdout markers.
No assertions or diagnostics are removed and the full suite remains 110 actors.

Coverage includes wrong receiver role, forged server sender, unmapped targets,
forged UID assignment, inert legacy RPCs, wrong/null Character and detached
Animator/track ownership, unauthorized assets, bounds/nonfinite/oversized values,
invalid play transitions, stale epoch/life/removed targets, Character replacement,
actual disconnect/reconnect, pre-puppet state and actual late joining. Valid play,
stop, loop changes, speeds 0/1/20, completion, integer speed, recovery after rejected
traffic and service replacement remain positive controls. Callback Disconnect is
reentrant; executable-owner retirement cancels callbacks; scene teardown precedes
final evidence. Existing GL-007 delayed/reordered transport and GL-022 ownership
regressions remain part of the unchanged surrounding suite.

Authenticated duplicate same-life state is intentionally idempotent, preserving
playback position and callback counts. Older life/epoch traffic after replacement
is rejected. This does not add a sequence-number protocol or promise to reject
every same-life owner replay. Reliable ENet ordering and existing lifecycle epochs
remain the contract. Trusted server future-life state may be buffered ahead of
the unreliable Character birth snapshot; checked client-selected assets and
trusted server gameplay timelines retain their distinct existing authority.

## Execution and remaining boundaries

All local compilation and runtime execution use DockerPC: Windows MSVC
14.51.36231 and the existing task-owned Linux container (Clang 19.1.1, glibc 2.39,
two CPUs, 6 GiB). MainPC fallback and other workers are unused. Existing caches,
CMake qualification adapters and pinned dependencies are reused. All 1,017
tracked Linux dependency files match the clean pinned Git inputs; the retained
dependency manifest SHA256 is
`ab90721864ae6031959e200da5083aeb6aa2ea18ccb8bfc594ffd852024cb219`.
Godot is hash-verified official 4.7.1. Source/fixture/product identities accompany
each run; startup and companion checks remain in the full native suites.

Linux core ASan/LSan executes with `detect_leaks=1:halt_on_error=1`. An attempted
Linux native ASan load with the matching Clang runtime fails before assertions:
stock Godot uses `RTLD_DEEPBIND`, rejected by AddressSanitizer. The original
`asan-report.2101`, logs and failed command are retained. The host also reports
missing optional libfontconfig; this does not replace the decisive sanitizer
diagnostic. No sanitizer suppression, engine patch or substitute pass is used.
Windows full-native ASan remains GL-018's separate unqualified host gap.

GL-017's engine disconnect relay issue, GL-018, hostile project resources and
general engine security are outside this bounded result. Headless presentation
regressions are not graphical/device qualification. This task adds no rendered
coverage, allocation profiling, production transport deployment, release support
or byte-for-byte reproducibility claim. Existing broader release, portability and
consumer-environment limitations remain intact.

## Fresh qualification results

| Profile | Execution | Core | Native |
| --- | --- | --- | --- |
| Windows Debug | DockerPC | 80/80 | 110/110 |
| Windows Release | DockerPC | 80/80 | 110/110 |
| Linux Debug | DockerPC container | 80/80 | Hosted result below |
| Linux Release | DockerPC container | 80/80 | 110/110 |
| Windows core ASan | DockerPC | 80/80 | Not a native qualification |
| Linux core ASan/LSan | DockerPC container | 80/80 | Stock-host load blocked as above |

Each of the three complete local native profiles passes all 510 authority checks
and 1,003 total animation assertions, with all 23/20 before/after matrices
unchanged. Existing regression, network security, Character, resource, filesystem,
HTTP, public HttpService, published caller, presentation, performance-execution
and transactional persistence groups pass. The strict checker requires 110 actors;
all 64 recorded fixture inputs and the native fingerprint match qualified source.
Core qualification
uses complete CTest output and the unchanged strict 80-case checker. No new
performance-speed or graphical claim follows from these regression runs.

Reproduction uses the existing CMake qualification adapter and companion/probe
targets with two build jobs, `RunCoreQualification.py`, the existing native group
runners and `CheckNativeCI.py`. The focused command is:

```text
python tests/runtime/RunQualification.py --godot <verified-engine> --extension <qualified-adapter> --output <new-output> --animation --timeout 90
```

Do not reuse output directories containing previous barrier files. The local
evidence archive records each exact compiler/configure/build/test command,
timeout, exit status, logs and source/fixture/product hashes. Windows Debug native
products were built against frozen source-1; its native inputs equal final
source-2 exactly. All final full-matrix fixture execution uses source-2.

The retained local archive is
`.runtime-tests/AnimationSecurity/animation-authority-local-evidence.zip`, SHA256
`2c37badc51249298c7287f63970a7cd9d72d832b02f181d6d3978b516272c577`.
It contains 1,123 evidence files plus the embedded Linux archive (494 files),
SHA256 `4d189b17e58a5e832653e030c2d038b3f89f2bfe6c68983e3e0efd99e3323d90`.
Raw inputs and failures remain on DockerPC and in the controlling checkout's
ignored evidence directory. No task-owned native/fixture process remains;
`codex-character-linux` is stopped, with its volume and build caches retained.

[Hosted core CI](https://github.com/gmoddev/GodotLuau/actions/runs/41287591306)
passes both Windows/Linux Debug profiles. Downloaded complete reports each
contain 80 distinct successful cases. The
[hosted native run](https://github.com/gmoddev/GodotLuau/actions/runs/41287591371)
passes Windows/Linux Debug. Both downloaded native artifacts pass independent
source/pin/64-fixture/log-hash checks, all 110 actor checks, all ten embedded
authority records and their stdout markers, and every 23/20 no-mutation matrix.
All four core/native artifact ZIP digests match GitHub's recorded SHA256 values.
The full independent inspection record SHA256 is
`e58b75bc12ecaec562a96b919d359c1a14e14d17ab03c3f5f416afdb8aef0fba`;
it retains actual embedded actor records, product hashes and assertion details.

The first artifact inspection incorrectly expected standalone authority JSON
files in the inherited upload glob. Its assertion failure is retained in the
inspection record. `CheckNativeCI.py` already embeds the full records and
snapshots in uploaded `summary.json`; checking those against actor stdout fixes
the inspector assumption without changing fixtures, assertions or upload policy.

See the [machine-readable evidence](evidence/gl020-animation-authority-2026-11-01.json)
for exact product/artifact identities, preserved failures and remaining gates.

## Disposition

**PARTIALLY QUALIFIED.** Actual two-client role/sender/ownership rejection,
no unauthorized cache/playback/replication/callback effects, valid playback and
late-join/lifecycle behavior satisfy GL-020's bounded authority closure criteria
on this development branch. The reproduced malformed-field defect is corrected.
Full native sanitizer qualification is not established. Hosted core/native CI
and all required new fixture execution are verified. The result is not a general
animation/engine security certification. Main remains at the starting revision; integration is a
separate decision. No release/updater distribution or unrelated development occurs.
