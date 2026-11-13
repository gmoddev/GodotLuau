# GL-055 qualification

Status: unmerged implementation; final native/profile qualification in progress.
The [journal](gl-055-debugger-development.md) preserves attempts, corrections and
their original identities. The [guide](gl-055-debugger.md) describes the supported
interface and [ADR-018](adr-018-native-luau-debugger.md) defines its authority and
lifecycle contract. This record does not qualify unsupported features by inference.

## Source and configuration

Baseline main: `b5389f0ff08c50e38bc11d868dbe12729a293535`.
Branch: `feature/gl-055-native-debugger`, with normal qualification-branch merges
retaining prior commits. Current native implementation: `fd86f83223ae4bb3c87b333b875cdd6307903a12`;
136-file LF-normalized native fingerprint:
`ad749d8f7db2bf367e07eb35255d08056384797a2b185a98436a731992819b83`.
Later documentation/fixture commits must be identified separately from that
implementation and from immutable binaries used below.

Dependencies remain godot-cpp `d5cc777a89d899665fb61f1650ef0dc0cf6488c4`
and Luau `9e2984fd0334414a2ef62ceede0c06dab7574d55`. Native editor tests use
the verified official Godot 4.7.1 host; headless network/sanitizer tests retain
the existing admitted GL-018/GL-029 hosts and patches. No new host, dependency,
gameplay authority, persistence protocol or distribution channel is introduced.

## Evidence boundaries

| Evidence | Result and scope |
| --- | --- |
| [Focused 43456316423](https://github.com/gmoddev/GodotLuau/actions/runs/43456316423) | Windows/Linux actual protocol and native editor PASS, including displayed stack/locals, watch, stepping, profiling, saved-source reload, restart and detach; immutable `37bba2f` native inputs |
| Windows `graphical-37bba2f-01` | PASS rendered native editor journey; all four PNGs inspected. Offscreen programmatic controls, no physical input. Predates hit/display corrections |
| [Core 43460714151](https://github.com/gmoddev/GodotLuau/actions/runs/43460714151) | Windows/Linux 87 original cases and eight debugger scenarios PASS at `d1c62a7`, including allocation-key validation; predates maximum-hit saturation correction |
| [Candidate 43450118761](https://github.com/gmoddev/GodotLuau/actions/runs/43450118761) | All four source-built Debug/Release profiles, packages and Linux core ASan/LSan PASS at `37bba2f`; retained within unchanged behavior scope |
| [Declarations 43448955594](https://github.com/gmoddev/GodotLuau/actions/runs/43448955594) | Windows/Linux policy, generated drift and type checks PASS. Later changes do not modify these declaration/policy inputs |
| [Sanitizers 43455004645](https://github.com/gmoddev/GodotLuau/actions/runs/43455004645) | Overall FAIL; missing test-peer class cache rejects stderr after successful local debugger assertions. Linux controls, core and 141 native actors pass; no unexpected sanitizer report. Not a full debugger sanitizer pass |
| [Native 43461738974](https://github.com/gmoddev/GodotLuau/actions/runs/43461738974) | Pending final native implementation |
| [Candidate 43461782730](https://github.com/gmoddev/GodotLuau/actions/runs/43461782730) | Pending final native implementation |
| [Sanitizers 43461776259](https://github.com/gmoddev/GodotLuau/actions/runs/43461776259) | Pending corrected peer fixture and final native implementation |

The existing native suite includes Foundry Expedition persistence restart,
Relay Siege solo/listen/dedicated, Character/animation/network authority,
HTTP/storage/resource limits and lifecycle checks. New debugger observations do
not replace those assertions or silently modify the games to pass them.

## Performance

[43460768309](https://github.com/gmoddev/GodotLuau/actions/runs/43460768309)
builds baseline main and candidate `d1c62a7` with the same pinned Luau and Release
toolchain. Each mode runs one warmup and five measured 100,000-operation trials.
Values below are median wall milliseconds; individual trials, CPU time, complete
Execute duration, C++ new counts/bytes and VM peaks remain in its artifacts.

| Mode | Windows | Linux |
| --- | ---: | ---: |
| Baseline disabled | 3.230 | 3.066 |
| Candidate disabled | 3.277 | 3.030 |
| Attached | 10.609 | 9.551 |
| Breakpoints, 100,000 actual stops | 39.082 | 28.541 |
| Stepping, 200,002 actual stops | 146.257 | 98.256 |
| Stack/raw-local inspection at 100,000 stops | 88.949 | 45.770 |
| Profiling native observations | 6.383 | 5.681 |

Disabled/attached modes allocate zero C++ objects during the measured loop.
All modes report the same 504,336-byte VM peak for this workload. Profiling now
allocates only its two initial map records (104 Windows / 91 Linux bytes), versus
100,002 allocations in [the retained first measurement](https://github.com/gmoddev/GodotLuau/actions/runs/43459001752).
The correction removes steady-state temporary-key allocations; timings from
different hosted runners are not a controlled before/after speedup claim.

Disabled median delta is +1.45% Windows / -1.19% Linux in this short workload.
Attached cost is material: the pinned VM's debug interpreter is deliberately
active to support immediate stepping. These are production-core measurements,
not whole-game frame performance, native Godot projection cost, GUI latency or
complete allocator accounting. Breakpoint/step inspection includes copying and
destroying frame descriptions; C++ counts exclude Luau's malloc allocations.
The later counter fix changes only saturation beyond this workload's hit count.

Existing editor index receipts report cold, warm, navigation and changed-buffer
latency. Native protocol receipts additionally retain stack/variables and watch
round-trip observations, including process polling and Godot transport. Final
receipts and rendered state corrections remain pending.

## Supported and limited behavior

Implemented: native source breakpoints and admission feedback, exact hit targets,
pause/continue/into/over/out, imported modules/callbacks/coroutines, bounded live
frames/locals/arguments/upvalues/table/native projections, restricted watches,
domain/session identity, fail-closed disconnect, selective saved-source reload,
copied ownership/profiling reports and bounded cached project navigation.

Limits are explicit rather than simulated compatibility:

- Pausing stops the game process, including both domains, physics and networking.
  Independent peers may time out. No production multiplayer pause protocol is added.
- Step intent ends at yield/completion boundaries. Native C++ and bootstrap
  frames are opaque. Generation labels identify the executing owner, not the
  lexical version of every retained module closure.
- Use the supported Luau Watch tab. Godot 4.7's stock Evaluate path requires a
  ScriptInstance, which this runtime does not fabricate to bypass authority.
- Arbitrary conditional/call evaluation, all-script live reload and in-process
  remote reattach are unsupported. Start a fresh Play session after detach.
- Navigation is bounded/syntactic, with exact lexical local bindings where
  available; dynamic global/member names are candidates, not semantic proof.
- Profiling reports inclusive owner/resume intervals and accepted native call
  counts. It does not provide sampling, arbitrary function-call counts,
  native-only CPU attribution or a full allocation history.
- Windows full-native LSan remains unavailable under GL-018's established
  limitation. Linux graphical presentation and physical input are not qualified
  by headless or offscreen programmatic editor tests.
- The successful rendered editor run has four ObjectDB exit warnings. It is not
  evidence of a leak-free editor process; game/native sanitizer scope is separate.

Native remains the default Character controller and Scripted remains opt-in.
Main, release publication and updater distribution remain unchanged. Integration
readiness requires the outstanding final native/profile receipts above; this
campaign does not authorize a merge.
