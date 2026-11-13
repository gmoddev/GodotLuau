# Starting a native Luau project

Use a matching qualified GodotLuau candidate and Godot host. The runtime updater
and release publication remain disabled. Candidate packages are explicit private
qualification inputs; inherited repository binaries are not qualified fork builds.
See the [GL-055 integration record](gl-055-main-integration.md) for current
main verification and the [qualification record](gl-055-debugger-qualification.md)
for supported debugger/profile limits.

## Create and edit

In Godot's Luau Authoring panel, select Empty, 2D, 3D or UI and choose New Luau
Scene. Pick a fresh project-local path. The action creates a normal Godot scene,
a LocalScript node and its `.luau` resource; it refuses existing files. Attach a
ServerScript entrypoint separately when authoritative gameplay/services need it.
No GDScript bootstrap is required.

The Empty template starts with:

```luau
local Scope = Scene.new(script.Parent)
Scope.Name = "Application"
```

Create approved native nodes/resources through that scope. It owns their cleanup
when the script generation retires. Use generated
[native declarations](../GodotLuau/Types/Native.d.luau) and the checked
[catalog](../bindings/NativeCatalog.json) for exact members, defaults and domain
permissions. An inherited Godot member is not automatically exposed to Luau.
Object/resource handles keep their original scope authority when passed around.
Do not cache scene handles in a module across entrypoint generations; return a
factory that constructs caller-owned session state instead.

The ScriptEditor supplies native completion, signatures, diagnostics and static
module navigation. Project Uses lists exact static imported-member references,
including the active unsaved buffer. It is bounded and labels partial results;
dynamic/re-export analysis is outside its [contract](gl-054-native-development.md).
Project Symbols adds bounded function/type definitions, static imports and
lexical reference locations through the same cache. Large queries can reach the
250-ms soft deadline and return explicit partial results.

## Preview, run and debug

Preview Luau explicitly reconstructs a restricted private native scene. It has no
gameplay services, network, persistence or input capability. Clear Preview retires
it. Save Preview As creates an independent PackedScene without live VM scopes and
refuses an existing output. Keep the source entrypoint for later reconstruction.

Run the normal scene for physics, native input and services. Native remains the
Character controller default; Scripted is an explicit opt-in. Foundry's independent
native Explorer does not replace Character V2 or its replication contracts.

Editor-connected runtime failures provide a bounded historical stack with primitive
locals, execution domain and owner generation. Open Runtime Error or activate a
frame to navigate explicitly. Native handles/tables remain opaque in these
historical error snapshots.
Fix the source and run again; editor restart is not the normal recovery path.

For live debugging, run from a supported editor host with its debugger connected
and set a Luau gutter breakpoint. The Debugger's Luau tab shows actual admission
and supplies pause, continue, stepping, restricted Watch, profiling and saved-source
reload. Godot's native stack/variable panes inspect the stopped coroutine. Watch
reads bounded local/upvalue/table/native-property projections; arbitrary calls
and mutation are unavailable. Use Luau Watch rather than Godot's stock Evaluate
path. Pausing stops the game process, including both domains and physics;
independent peers can time out. See the [debugger guide](gl-055-debugger.md) for
reload, disconnect, dedicated development hosts and remaining limits. Production
release templates do not acquire interactive debugging.

## Choose an example

| Profile | Starting point | Purpose |
| --- | --- | --- |
| OrbRun | [Luau-only game](../examples/luau-only/README.md) | Small native physics/UI/module example |
| Native2D | [Foundation projects](../examples/native-foundation/README.md) | 2D character, pickups, animation and audio |
| Native3D | [Foundation projects](../examples/native-foundation/README.md) | Native 3D physics, camera, navigation and resources |
| UI | [Foundation projects](../examples/native-foundation/README.md) | Native layouts, theme, text controls and focus |
| Foundry | [Foundry Expedition](../examples/foundry-expedition/README.md) | Modular solo game, inherited rooms, AI, combat, reload and durable progress |
| Relay Siege | [Multiplayer game](../examples/e2e-game/README.md) | Existing Server-authoritative solo/listen/dedicated networking |

Stage a profile in a fresh directory:

```powershell
python examples/luau-only/PrepareProject.py --profile Foundry --candidate <candidate-directory> --output <fresh-project-directory>
```

Open that directory with the matching full-featured editor and allow normal asset
import. The stager preserves existing projects and omits the disabled updater.
Test-adapter staging is explicitly qualification-only and unsuitable for distribution.
Navigation-dependent examples require a full host; existing lightweight admitted
network/sanitizer hosts have documented module limitations.

## Export and retain data

Export ordinary Godot resources plus `*.lua,*.luau`. Keep the native library and
DataStore companion together through the extension dependency declaration. Use
matching Debug/Release products and templates. The explicit official-template
path in RunLuauExport avoids installing templates or changing global settings;
it is a solo profile, not an admission of a new networking/sanitizer host.
On Linux preserve candidate Unix modes and restore executable mode 0755 on the
exported DataStore companion; Godot's dependency copy drops that bit. The helper
does this after verifying unchanged native bytes. See the
[Foundry export notes](../examples/foundry-expedition/README.md).

Foundry's HUD distinguishes a completed sector from durable acknowledgment.
Reload reads committed progress; an unacknowledged commit may already have taken
effect. Volatile combat and pending session state
are not a saved checkpoint. Back up the existing user-data root before deployment
changes, and preserve GL-009's prohibition on concurrent legacy writers.
Application startup/export evidence and actual interactive gameplay are reported
separately in the qualification journal.
