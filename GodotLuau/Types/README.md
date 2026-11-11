# Approved native Luau definitions

`Native.d.luau` is generated from `bindings/NativePolicy.json` and the pinned
godot-cpp extension metadata. Load it as a project **definition file** in a
Luau language server using its standard platform; do not execute or require it. It defines
the Scene API, approved native handle classes, property tables, literal-class
constructor overloads, typed calls/signals, optional arguments and enums.

This is the native Scene surface, not declarations for every inherited Roblox
compatibility service. Runtime ownership, live generations, numeric/resource
bounds and immutable loaded/getter handles still require native checks. Types do
not grant authority or prove that a value belongs to a particular script owner.

For Luau-LSP, copy the values in `settings.example.json` into the project's VS Code
settings. The standard platform disables Roblox's default API, and the definition
map loads this engine surface. These keys follow the
[official client configuration](https://github.com/JohnnyMorganz/luau-lsp/blob/main/src/include/LSP/ClientConfiguration.hpp).
Adjust the definition path when the project root differs. This is an opt-in
configuration example; staging does not change the user's editor settings.

Do not load the inherited `Scripts/globalTypes.d.luau` as GodotLuau's runtime
contract: it describes the wider Roblox API, including unavailable classes and
services. Native definitions also do not supply every `game`/`script` compatibility
global; entrypoints need accurate project-specific declarations. The typed
`RelayFactory.luau` module can be checked directly using this native profile.

Regenerate from the repository root with:

```text
python tools/GenerateNativeBindings.py
python tools/GenerateNativeBindings.py --check
```

The generator validates native class/property/method/signal names, inheritance
and Variant types against the pinned API. The build and native CI reject drift.
Do not edit generated declarations or runtime descriptors by hand.
