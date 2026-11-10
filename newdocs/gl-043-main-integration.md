# GL-043 main integration

On 2026-11-09, main `eee10f8779a1002c664a81267d9ab96d1dae1e62` normally
merges retained `fix/gl-043-raycast-impulses` at
`49440c05eff582c20c62e993021763a2c0c2f0e2` through
`e7f8ac42919041421d80a6d81653bfbfbc32deb6`. All twelve branch commits remain
ancestors. The merge tree exactly equals source tree
`7dcf605c82867740dcdca5b21df43fc15283fc3e`; no conflict or runtime change occurs.

The qualified runtime and fixture revision remains
`3227290c1137fe4c52237aab7eecf001aee83e18`. All subsequent source-branch
commits change documentation/evidence only. Its 101-file native fingerprint is
`7d540a81ecf0bcf83742e94386796df6e4df36310ad330ec1d9bfe54bdac2f56`.
The [original receipt](evidence/gl043/qualification-2026-11-09.json) retains
baseline failures, compiler failure, actual artifacts and package identities.

At integration, GitHub confirms the exact qualified revision and successful
[core](https://github.com/gmoddev/GodotLuau/actions/runs/42610522541),
[141-actor native](https://github.com/gmoddev/GodotLuau/actions/runs/42610522588),
[matching full-native sanitizer](https://github.com/gmoddev/GodotLuau/actions/runs/42610532744)
and [ten-gate non-publishing candidate](https://github.com/gmoddev/GodotLuau/actions/runs/42610528726)
workflows. Reuse those unchanged source/fixture/profile/package results; no
second candidate build is needed merely for the identical normal merge.
Ordinary push-triggered main CI is separate fresh integration observation.

Authority, normalized-ray/MaxDistance convention, collision configuration,
dependencies, admitted hosts and pins remain unchanged. Headless profile scope,
unsupported RaycastParams options, graphical/device and Windows LSan limitations
remain as recorded. Both release jobs remain disabled with read-only permissions;
updater distribution and upstream remain unchanged. GL-044/045 and Relay Siege
migration are separate follow-up work on a development branch.
