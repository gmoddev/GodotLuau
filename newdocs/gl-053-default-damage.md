# GL-053: Safe default GameManager combat boundary

Status: **resolved for the default templates**, fixed and independently qualified
at `60913fbf1ab849a7e354ba7397f8fbc5845cad55` on the unmerged GL-052 branch. Release publication
and updater distribution remain disabled.

## Verified baseline and scope

The default `ServerScriptService/GameManager.luau` publishes DamageEvent and
accepts a client-selected target name and amount. It checks string/number types,
clamps the amount to 0..35 and logs the request. Its target lookup and TakeDamage
calls are comments: no current arbitrary-health mutation is demonstrated. Object
targets fail the string check, and the existing native payload codec rejects
nonfinite numbers. Preserve this counterevidence.

The commented example would act through a privileged Server callback without
weapon state, hit/range checks, target eligibility or attack-frequency policy.
Transport sender/session validation authenticates a peer; it does not authorize
a hit. The skeleton contains no combat policy from which to derive those facts,
and no shipped client calls DamageEvent.

Remove that unconfigured endpoint and its unsafe damage recipe from the disk
template and regenerated `src/core/luau_templates_gen.h` fallback. Keep player
lifecycle and round startup. Games must define server-owned combat policy before
publishing attack intent; clients must not choose authoritative damage or targets.
Native RemoteEvent admission, Character health authority and valid Server damage
are unchanged. No new combat system or runtime endpoint deletion is introduced.

## Compatibility

`gl_luau_template` in `src/core/luau_script.h` reads a disk template when present
and otherwise uses its embedded copy. Both sources must agree. Generate the
header with `python tools/generar_plantillas_luau.py` after changing the `.luau`.

Existing customized scripts require review and manual removal/replacement of old
handlers. `RobloxDataModel::_gl_sync_one` retains its existing policy: untouched
managed scripts can update, while customized or unknown-base scripts are
preserved and offered an update. This fix does not migrate user project content.
See the [default-script guidance](../GodotLuau/DefaultScripts/README.md).

## Focused evidence

`tests/runtime/DefaultScriptCases.gd` executes the actual template body in the
existing native Integration actor. Preparation checks exact normalized equality
of its disk and embedded source. The case requires no default damage endpoint,
attempts the historical client call with target-name/high-damage, object and table
payloads, and checks health remains unchanged. A trusted Server damage control
still succeeds; direct Client health/damage writes remain rejected. Destroy the
template owner and its round task through the existing native lifecycle.

At retained pre-fix adapter `1197f3d`, the old template fails the endpoint assertion
and accepts the historical string request, causing the explicit client assertion
to fail. This is endpoint exposure evidence, not a reproduced health exploit.
With the corrected template, the complete local Integration actor exits 0 with
no diagnostics. Existing native authoring/binding/editor and lifecycle assertions
pass in the same actor. These runs exercise source execution using an unchanged
adapter; they do not yet claim a new compiled fallback product.

Commands: the repository's existing `Prepare`, `Start` and `Check` helpers launch
official Godot 4.7.1 headlessly with `Integration.gd`, a 40-second deadline, isolated
profiles, suppressed Windows crash UI and owned-process cleanup. The campaign
retains `gl052-followup-20261112/default-before` and `default-after-source`.
Final hosted evidence at that exact source:

- [Native Windows/Linux](https://github.com/gmoddev/GodotLuau/actions/runs/43154348629)
  pass all existing actors, including the new DefaultScripts case in Integration.
- [Full-native sanitizers](https://github.com/gmoddev/GodotLuau/actions/runs/43154353439)
  pass Windows/Linux, including that case, with zero unexpected reports.
- [Core](https://github.com/gmoddev/GodotLuau/actions/runs/43154348664) passes both
  platforms. [Production candidate](https://github.com/gmoddev/GodotLuau/actions/runs/43154350153)
  passes all four source builds, both extracted packages and final acceptance.
  The embedded header is compiled into those source-identified products.
- [Current package/export](https://github.com/gmoddev/GodotLuau/actions/runs/43164852674)
  passes independently. Current Windows rendered Orb Run also passes 14 checks.

Downloaded Windows/Linux native and sanitizer Integration logs each contain
`[Runtime:DefaultScripts] PASS`. The preparer requires exact disk/fallback text
equality; the runtime test executes that actual source through native domains.
The historical call no longer succeeds because the default endpoint does not
exist. Legitimate Server damage succeeds and direct Client writes leave health
unchanged. This closes the unsafe template path, not combat correctness in
customized games. [GL-052's receipt](evidence/gl052-qualification.json) retains
exact native/product hashes and independent remaining editor limits.

The independent read-only candidate review finds no concrete surviving bypass or
regression. It verifies Python parsing, disk/fallback parity, endpoint absence and
the diff; it does not claim a Godot run. The parent separately runs the focused
native control and rejection cases above; final hosted qualification now passes.
