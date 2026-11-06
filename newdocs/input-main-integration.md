# Input Action foundation main integration

The Input foundation is integrated by normal merge
`f3c575728a7d40b291a3e8f55015f24b5c542396` from main
`091c13da85b1d082249b525123f5cae4d3c17dd1`. All four commits on retained branch
`feature/input-action-api-foundation` at `435bb6917b847c0405a9574cfe5fccfcdb1b9340`
are preserved. The merge tree exactly equals that source tree
`dea70a7c9297b12eff866f5d8a3047a2b51cdbe9`.

Qualified implementation `c03747277dfd1ccdfcfed2d2bf453659da553af5` has the
same 99-file native source fingerprint
`0cf632015b905ead12291e1dc148f6a8606f1ef169a6cccddd3c39c096bccedf`.
The final source-branch commit changes documentation and evidence only.
See the [retained qualification receipt](evidence/input-final-qualification-2026-11-06.json)
for the completed core, native, full-native sanitizer, real rendered example and
performance qualification. Those unchanged tests were reused.

## Candidate and package gates

The previously outstanding [non-publishing candidate workflow](https://github.com/gmoddev/GodotLuau/actions/runs/42185879161)
passes all ten gates at the exact source tip: four Windows/Linux Debug/Release
source profiles, Linux core ASan/LSan, both rejection/retention checks, both
extracted-package startup jobs and final acceptance. Every profile executes
85 core cases and 134 native actors. Downloaded logs contain 51 input, 20 motor
and 20 headless example checks, including 20 restarts. This closes the missing
Linux Release headless/profile scope; it does not establish Linux graphical or
physical-device coverage.

Downloaded Windows/Linux ZIPs, native members and embedded provenance match
the accepted manifests. Both Debug/Release startup logs execute the actual
persistence companion fixture. The Linux companion retains mode 0755.
The [integration receipt](evidence/input-main-integration-2026-11-06.json)
records job links, artifact identities, package/native hashes and source identity.
All products build from the same immutable revision and unchanged dependency pins.

This integration changes no qualified runtime or fixture inputs. Ordinary main CI
may run normally; no additional manual rerun of the same qualified suite is needed.
GL-042's post-GUI raw-event timing change follows the documented
[migration contract](input-actions-api.md#userinputservice-migration).

## Retained limits

Physical devices, actual OS mouse capture, Linux graphical coverage and complete
allocation profiling remain unqualified. Windows LSan is unsupported. Admitted-host,
GL-017/018, older-glibc and pristine consumer-environment limits remain explicit.
No byte-for-byte reproducibility or distribution support is added. Releases and
updater distribution remain disabled.

Optional scripted Player.Character control is separate development from this
integration. The independent motor example does not replace Character V2.

