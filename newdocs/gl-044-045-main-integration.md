# GL-044/045 and Relay Siege main integration

On 2026-11-10, main `6db2e2c563dfb4680dc09f1451f05dba5b778069` normally
merges retained `codex/gl-044-045-relay-luau` at
`67ae0d31618765a0d72a52c3e21c784a7c3bffcf` through
`ee8e059a1c5d6a45cb64e6c1e104caa6f5590ad4`. All 17 source commits remain
ancestors. Both merge parents match the verified starting refs. The merge tree
exactly equals qualified source tree `5551063caef823662622eb82450d2322b59d1ee1`;
there are no conflicts or additional runtime changes.

## Preserved qualification

The [branch journal](gl-044-045-relay-development.md) and
[receipt](evidence/gl044045/qualification-2026-11-09.json) remain unchanged,
including original failures and their attribution limits. Their statements that
the branch is unmerged describe that historical checkpoint, superseded here.

Integration checks establish exact Git equality for native inputs (`src`,
`SConstruct`, dependency pins and `.gitmodules`) against implementation
`30682a33c418cde73c710c168fe09c1c14af4155`, all runtime fixtures against
`e65e3b89a72c4e8a2017410f2eb67f54e44d1938`, and the four game/controller
runtime scripts against `0ecc2b5443f3f3405479a53a50c5b0b63a6283eb`.
The 101-file native fingerprint remains
`40270fc0232566b9cd3f06584feba29cfbf88902be7609cdb140f2e12e00132c`.
Godot-cpp stays `d5cc777a89d899665fb61f1650ef0dc0cf6488c4`; Luau stays
`9e2984fd0334414a2ef62ceede0c06dab7574d55`.

GitHub confirms successful existing qualification runs:

- [Core](https://github.com/gmoddev/GodotLuau/actions/runs/42755853368) and
  [native](https://github.com/gmoddev/GodotLuau/actions/runs/42755853334) at
  `e65e3b8`: Windows/Linux each 85 core cases, 29 graph assertions, 141 native
  actors and 107 Model checks, including final corrected fixture inputs.
- [Full-native sanitizers](https://github.com/gmoddev/GodotLuau/actions/runs/42748739079)
  at `8eddb82`: unchanged native implementation, matching Windows ASan/Linux
  ASan-LSan profiles, 85 core cases and 141 actors. This predates later security
  marker/retirement fixture changes; it is not a final-harness or full-game
  sanitizer claim.
- [Accepted native candidate](https://github.com/gmoddev/GodotLuau/actions/runs/42752234638)
  at `4510ab4`: all ten required gates, Windows/Linux Debug/Release, downloaded
  package provenance/hashes, companions and extracted startup. The later
  retirement fixture is qualified separately by the native run above.
- [Standalone game package](https://github.com/gmoddev/GodotLuau/actions/runs/42762178179)
  at `c9c03b0`: all 157 payloads verified, extracted startup exit 0/Rules ready,
  empty stderr. Game ZIP SHA-256:
  `29e1348146a0b9417b114d3f62146462c87a1ea9e7cbc9f346bb93ed5a46c521`.

The existing actual production Windows rendered replay at `0ecc2b5` passes
55 listen and 57 dedicated checks across nine actors, with no unhandled script
diagnostics. Four known retired-channel engine errors and eight display warnings
remain recorded. Reuse these exact inputs; an unchanged merge does not justify
repeating the expensive candidate, sanitizer or rendered gameplay matrices.

## Fresh integration observation

[Fresh core CI](https://github.com/gmoddev/GodotLuau/actions/runs/42764545794)
passes Windows/Linux at the exact merge `ee8e059`. Downloaded XML/logs confirm
85 core cases and 29 input-graph assertions on each platform. The optional
benchmark-host export job is skipped because it was not requested; it is not a
required core gate.

[Fresh native CI](https://github.com/gmoddev/GodotLuau/actions/runs/42764545584)
is still running on both platforms during bounded integration observation.
Neither job has yet produced its required complete summary. Do not count these
pending jobs as passed or as fresh execution of all 141 actors. The successful
exact-input branch qualification above remains the reused native evidence.
The [integration receipt](evidence/gl044045/main-integration-2026-11-10.json)
records observed states separately from those historical results.

Classification: **INTEGRATED WITH LIMITATIONS**. The qualified source and all
17 commits are integrated and published; fresh native CI remains pending.

## Retained scope

CFrame directional/Position values remain stdlib coordinate tables, requiring
explicit native Vector3 construction where that API requires userdata. Bound
Vector3 methods preserve valid dot/colon calls and reject wrong arity/receiver.
GL-046/047 are scoped fixture corrections; GL-048 handles only the exact native
peer-not-ready pre-admission rejection at the game caller. No native authority,
networking protocol, cancellation, resource limit or physics solver changes.

GL-017 engine diagnostics, admitted-host/Windows LSan limits, full-game sanitizer
gaps, Linux rendered gameplay, physical-device coverage, WAN/NAT, asset provenance,
older-glibc/pristine-consumer and allocation-profiling limitations remain. Capped
frame observations do not establish uncapped performance improvements, and no
byte-for-byte reproducibility is claimed. Existing scene/UI/audio/cloth adapters
remain where no qualified reusable Luau API replaces them.

Both publishing jobs remain disabled and workflows retain read-only permissions.
Updater distribution and upstream are untouched. No new local builds or runtime
tests are started for this source-identical integration; worker caches and task
evidence are preserved. The source branch is retained. Stop after integration.
