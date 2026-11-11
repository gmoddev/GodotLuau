# Approved native Luau definitions

`Native.d.luau` is generated from `bindings/NativePolicy.json` and the pinned
godot-cpp extension metadata. Load it as an additional **definition file** in a
Luau language server; do not `require` it or run it as a game script. It defines
the Scene API, approved native handle classes, property tables, literal-class
constructor overloads, typed calls/signals, optional arguments and enums.

This is the native Scene surface, not declarations for every inherited Roblox
compatibility service. Runtime ownership, live generations, numeric/resource
bounds and immutable loaded/getter handles still require native checks. Types do
not grant authority or prove that a value belongs to a particular script owner.

Regenerate from the repository root with:

```text
python tools/GenerateNativeBindings.py
python tools/GenerateNativeBindings.py --check
```

The generator validates native class/property/method/signal names, inheritance
and Variant types against the pinned API. The build and native CI reject drift.
Do not edit generated declarations or runtime descriptors by hand.
