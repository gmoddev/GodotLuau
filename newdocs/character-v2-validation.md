# Character V2 qualification

Status: implementation under qualification on `runtime/character-v2-model`,
stacked on qualified GL-007 tip `514d12f`. No merge or distribution is authorized.
See [development evidence](character-v2-development.md),
[ADR-007](adr-007-model-character.md) and [API migration](character-v2-api.md).

Preparation commit `9ec71c024b012aada68750ab9bae3349115a165d` passed both hosted
core jobs in run `41039974670` and both native jobs in run `41039974656`.
Main remains `4ea53113a98961a64347c672890f65bf9b5c8a54`; GL-007 remains
`514d12f1bf1add924214492248a459e0763d4ca0`, verified against origin.

## Executed development checks

Windows/Linux Debug V13 pass all 17 character actors (16 existing scenarios plus
the native Model fixture). The focused fixture passes 61 checks for genuine
identity/Model operations, parent transforms, camera-controller math and deletion,
NPC movement/jump/fall/collision, health bounds, actual Animator completions,
playback ownership, destruction, templates and repeated/reentrant respawn.
The earlier V9 also passes all 10 animation and 10 network authority actors on
both platforms. These development results do not substitute for the final matrix.

## Final configuration matrix

Final native input fingerprint (88 LF-normalized production files):
`c34d100ee297acb76670ccb0e25546bd12ae7ca632ca365b241af3a9804ed283`.
The final Model fixture has 76 checks, including repeated import rejection,
keyboard/gamepad/mobile input, script reload and a custom visual template.

Pending. Required core configurations are Windows/Linux Debug, Release and core
ASan; native configurations are Windows/Linux Debug and Release plus matching
Linux full-native ASan/LSan. Each native configuration requires all eight groups,
83 complete actors and GL-009 companion fault/recovery evidence. Four SCons
products, process/packaging checks, R6/custom-rig fixtures, performance measurements
and source-identical hosted core/native CI remain to be recorded.

## Qualification boundaries

Headless camera/transform and animation assertions do not establish visual
correctness. No graphical display/Xvfb is available in the qualification Linux
environment. Windows worker tests remain hidden/headless to avoid disrupting
foreground use; no graphical correctness claim is made.

GL-018's Windows full-native sanitizer-host limitation remains. GL-017's separate
engine relay edge, production anti-cheat/collision truth, broad GL-020 security
qualification and arbitrary custom content remain outside these passing claims.
Protocol 3 intentionally rejects historical character protocol readiness;
mixed-build gameplay is unsupported. Existing user content requires manual
migration. Releases and updater distribution stay disabled.
