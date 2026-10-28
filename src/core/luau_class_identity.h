#ifndef LUAU_CLASS_IDENTITY_H
#define LUAU_CLASS_IDENTITY_H

namespace godot { class Object; class String; }

// Internal synchronous identity adapter. Object is borrowed and must be live;
// callers retain responsibility for ObjectID resolution. Null names "Instance".
// Returns an owned value: no shared mutable UTF-8 buffer or borrowed name pointer.
// Existing class-specific Player/Value/Mouse dispatch may override this mapping.
godot::String GetLuauClassName(godot::Object* Object);
// Existing exact/Roblox-parent/Godot is_class rules; null Object/Query is false.
// No object/query pointer is retained; class-name bytes are owned for this call.
bool IsLuauClass(godot::Object* Object, const char* Query);

#endif // LUAU_CLASS_IDENTITY_H
