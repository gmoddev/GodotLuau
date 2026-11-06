# Independent Luau controller

The [controller](Controller.luau) uses semantic InputActions and the local native
KinematicMotor3D. It never polls keys, modifies Player.Character or sends movement
RPCs. Godot provides collision, gravity, the viewport camera and GUI routing.

Build the normal native test adapter, then launch from the repository root:

```powershell
python tests/runtime/RunInputController.py --godot C:/Tools/Godot.exe `
  --extension build/native/Debug/godot_luau.dll `
  --output .runtime-tests/controller-play --interactive --seconds 600
```

Use the actual paths for your existing Godot installation and built extension;
Linux uses `godot_luau.so`. The runner copies an isolated project and the exact
example source using the existing qualification infrastructure. Each output
directory must be new. Closing the game ends manual play; the time bound cleans
up task-owned processes. Omit `--interactive` for the headless gameplay fixture.
`--graphical` uses the established offscreen Windows rendering profile, records
a PNG and never captures the worker's physical mouse. It is distinct from manual
physical-device qualification.

Controls: WASD/left stick move, mouse/right stick look, Shift/L3 sprint, Space/A
jump, Escape/Start menu, F6 remaps jump between Space and E, F8 stops/restarts.
The text box demonstrates native GUI consumption. Menu buttons resume, remap and
restart through ordinary UI commands. Held controls need a neutral/fresh press
after disabling gameplay; a menu close does not synthesize movement.

Move and sprint sample at RunService.Stepped, before the motor consumes its
command once at the native physics tick. Look samples at RenderStepped. Mouse
motion is a per-frame displacement; stick look is a rate multiplied by delta.
Frame and physics deltas have separate accumulators; repeated reads are stable.
The camera and body retire with the creator. Stop disconnects callbacks, destroys
the gameplay context/body and restores the prior camera. UI actions remain alive
to support restart, then retire with the script.

The native body is independent local gameplay, with a fixed 0.35-radius,
1.8-height capsule, gravity 24 and terminal fall speed 100 in Godot units. Use a
unit-scale 3D parent. Horizontal speed commands are finite and at most 100;
jump speed is (0,50], teleport coordinates are bounded by +/-100,000, and pitch
is +/-1.45 radians. Commands return false on rejection. Observations are
read-only. This API does not confer server physics authority, replace Character
V2, implement prediction or make the example a networked player controller.

See [API and qualification](../../newdocs/input-actions-api.md) and the
[development journal](../../newdocs/input-action-development.md) for the actual
tested configurations and remaining device/sanitizer/performance limitations.
