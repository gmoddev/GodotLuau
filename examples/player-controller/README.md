# Player.Character controller example

This LocalScript uses InputService and the existing Player.Character body.
Copy PlayerController.luau to StarterPlayerScripts. Native remains the default
for projects that do not opt in.

- WASD / left stick: camera-relative movement.
- Shift / L3: sprint. Space / A: grounded jump.
- RMB + mouse / right stick: camera look.
- Escape / Start: menu context. Text-field focus suspends movement.
- F6: remap jump between Space and E.
- F8: replace the controller lease without replacing the Character.
- F9: explicitly switch Native / Scripted.

For the isolated runnable example, use the established bounded launcher:

```sh
python tests/runtime/RunPlayerController.py --godot /path/to/verified/godot \
  --extension /path/to/godot_luau.so --output /fresh/output --interactive --seconds 180
```

Windows uses the DLL extension. For an admitted template runtime, pass its
matching verified editor with --asset-godot for import/remap preparation.
Automated --graphical uses the established offscreen Windows renderer and avoids
physical mouse capture. Headless replay does not establish graphical coverage.

The launcher creates a native floor, the actual default Character, a focused
text field and menu buttons. The Luau script owns movement/look and input
contexts; its teardown leaves neutral Scripted control. CharacterAdded selects a
fresh lease after respawn. A superseded example retires its contexts/connections.

See the [API](../../newdocs/player-character-control.md) and
[qualification journal](../../newdocs/player-controller-development.md).

