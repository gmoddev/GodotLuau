extends RefCounted
## Calls the production inspection API shared by Godot's actual language hooks.

func Names(Options: Array) -> Array[String]:
    var Result: Array[String] = []
    for Option in Options:
        Result.append(str(Option.insert_text))
    return Result

func Run(Runner) -> void:
    var Resource: Object = ClassDB.instantiate("LuauScript")
    var Marker := String.chr(0xFFFF)
    var Prefix := "local Scope = Scene.new(script.Parent)\n"
    var Info: Dictionary = Resource.call("InspectNativeCode",Prefix+"Scope:"+Marker,"res://NativeEditor.lua")
    var Options := Names(Info.Options)
    var Shape: bool = typeof(Info.result)==TYPE_INT and Info.result==OK
    for Option in Info.Options:
        Shape = Shape and Option.has("icon") and typeof(Option.font_color)==TYPE_COLOR and typeof(Option.matches)==TYPE_PACKED_INT32_ARRAY
    Runner.Check(Shape, "Native completion follows the actual Godot ScriptLanguageExtension option contract")
    Runner.Check(Info.Handled and "New" in Options and "Call" in Options and "Instantiate" in Options and "free" not in Options, "Native editor completion uses approved scope operations")
    Info = Resource.call("InspectNativeCode",Prefix+"Scope:New(\"Tex"+Marker+"\", {})","res://NativeEditor.lua")
    Options = Names(Info.Options)
    Runner.Check(Info.Handled and "TextureRect" in Options and "Texture2D" not in Options and "ClassDB" not in Options, "Native editor constructor completion excludes unavailable capabilities")
    Info = Resource.call("InspectNativeCode",Prefix+"local Button = Scope:New('Button', {})\nButton.Te"+Marker,"res://NativeEditor.lua")
    Runner.Check(Info.Handled and "Text" in Names(Info.Options) and "Transparency" not in Names(Info.Options), "Native editor node property completion is metadata typed")
    Info = Resource.call("InspectNativeCode",Prefix+"local Button = Scope:New('Button', {})\nScope:Call(Button, 'Is"+Marker+"')","res://NativeEditor.lua")
    Runner.Check(Info.Handled and "IsPressed" in Names(Info.Options) and "free" not in Names(Info.Options), "Native editor method string completion uses the same policy")
    Info = Resource.call("InspectNativeCode",Prefix+"local Button = Scope:New('Button', {})\nScope:Connect(Button, 'To"+Marker+"', function() end)","res://NativeEditor.lua")
    Runner.Check(Info.Handled and "Toggled" in Names(Info.Options) and "Touched" not in Names(Info.Options), "Native editor signal completion uses actual inheritance")
    Info = Resource.call("InspectNativeCode", "math."+Marker,"res://NativeEditor.lua")
    Runner.Check(not Info.Handled, "Native editor preserves unrelated legacy completion routing")
    var Code := Prefix+"-- Scope:New('OS',{}) in a comment must not execute or diagnose\nlocal Button = Scope:New('Button', {WrongProperty = true})\nScope:Call(Button, 'free')\nScope:Call(Button, 'SetPressedNoSignal', 'wrong')\n"
    Info = Resource.call("InspectNativeCode",Code,"res://NativeEditor.lua")
    var Codes: Array[String] = []
    var Locations := true
    for Item in Info.Diagnostics:
        Codes.append(str(Item.code))
        Locations = Locations and Item.line>=3 and Item.path=="res://NativeEditor.lua" and Item.column>0
    Runner.Check(Locations and "E_NATIVE_PROPERTY" in Codes and "E_NATIVE_MEMBER" in Codes and "E_NATIVE_TYPE" in Codes and "E_NATIVE_CLASS" not in Codes, "Native editor diagnostics use syntax locations and ignore comments")
    Info = Resource.call("InspectNativeCode",Prefix+"local Texture = Scope:Load('Texture2D', 'res://Image.tres')\nScope:Configure(Texture, {})","res://NativeEditor.lua")
    Runner.Check(not Info.Diagnostics.is_empty() and Info.Diagnostics[0].code=="E_NATIVE_IMMUTABLE", "Native editor diagnoses immutable loaded handles")
    Info = Resource.call("InspectNativeCode",Prefix+"local A=Scope:New('Node3D',{})\nlocal B=A:FindFirstChild('Visual')\nlocal C=A.Visual","res://NativeEditor.lua")
    Runner.Check(Info.Diagnostics.is_empty(), "Native editor preserves dynamic child lookup compatibility")
    Info = Resource.call("InspectNativeCode", "local Scope = {}\nScope:New('OS', {})","res://NativeEditor.lua")
    Runner.Check(Info.Diagnostics.is_empty(), "Native editor does not confuse a shadowed ordinary table with a capability")
    Resource = null
    print("[Bindings:Editor] PASS")
