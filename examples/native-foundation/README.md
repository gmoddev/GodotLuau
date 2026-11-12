# Native foundation projects

Unmerged GL-053 acceptance workloads. Sources are implemented; qualification is
tracked in [the campaign journal](../../newdocs/gl-053-native-development.md).
These projects contain no application GDScript. Godot owns rendering, physics,
navigation, controls and resources; the Luau entrypoints own their Scene scopes.

| Profile | Entry | Behavior |
| --- | --- | --- |
| Native2D | TwoD.tscn / TwoD.luau | Animated sprite, native character-body movement/jump, Area pickups, audio, HUD, round transition |
| Native3D | ThreeD.tscn / ThreeD.luau | Character-body movement, following camera, native animation, navigation guide, MultiMesh, project shader, pickups/audio |
| UI | UI.tscn / UI.luau | Native tabs, icons, theme, lists, text entry/editor, sliders, focus and responsive margins |

Use the existing explicit stager, supplying a qualified candidate or retained test
adapter identity. An adapter is for qualification only. For example:

```powershell
python examples/luau-only/PrepareProject.py --profile Native2D --candidate C:\Path\Candidate --engine C:\Path\AdmittedRuntime.exe --host-manifest C:\Path\remote-host.json --output C:\Path\FreshProject
```

Use Native3D or UI for the other profiles. The default OrbRun profile is unchanged.
The stager preserves existing directories, does not download/install/update, and
excludes the disabled updater. Supplied runtime/manifest pairs must satisfy the
existing admitted-host checks. Open the staged project with the verified editor;
play its main scene, or explicitly preview its Luau source in the authoring panel.

2D/3D controls are WASD/arrows or the left gamepad stick, with Space/A to jump.
Collect three markers; Restart becomes Next round when complete. Restart creates
fresh native identities and removes the old scope. 3D's green guide uses native
navigation, and the player visual uses a sealed native animation library.
The navigation guide requires a host with Godot's navigation module, such as
the verified official editor. The existing admitted headless/renderer templates
omit that module; the guide remains stationary there while player gameplay
continues. Those host profiles are unchanged by this campaign.

The UI uses Tab/Shift+Tab and native arrow navigation. Apply changes only the
displayed local session settings; it grants no networking or persistence authority.

The 3D shader and MultiMesh require a renderer-enabled host. Admitted headless
server builds do not qualify renderer-backed data or graphical behavior. Headless
fixtures separately exercise 2D gameplay, UI behavior, 3D construction and the
native physics/navigation/animation implementations. Actual rendered play,
editor restart and independent export/startup remain separate acceptance evidence.

The existing RunLuauExport.py accepts the same --profile choices and stages,
exports and starts the standalone product using existing candidate/companion
verification. It remains headless evidence, not interactive qualification.
Relay Siege remains the separate qualified multiplayer/persistence regression.

All assets in Assets and all source files in this directory were authored for
this repository under its MIT license. Textures are native procedural gradients,
the theme uses native style boxes, and the navigation mesh is a four-vertex
authored polygon. No third-party images, fonts or imported models were added.
