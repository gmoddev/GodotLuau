#ifndef GL_NATIVE_EDITOR_API_H
#define GL_NATIVE_EDITOR_API_H
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/dictionary.hpp>

// Shared by the actual Godot language hooks and inspectable Script resource API.
// No VM, scene execution, filesystem access or mutable native object is involved.
godot::Dictionary GLInspectNativeCode(const godot::String& Code, const godot::String& Path);
godot::Dictionary GLNavigateNativeCode(const godot::String& Code, const godot::String& Symbol, const godot::String& Path);
// Trusted native editor only. Bounded project reads and pure cached AST results.
godot::Dictionary GLIndexProjectModule(const godot::String& Module,const godot::String& Member,const godot::Dictionary& Buffers);
#endif
