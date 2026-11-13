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
    Info = Resource.call("InspectNativeCode","local Value=Scene.Enums.Control.MouseFilter.MOUSE_FILTER_"+Marker,"res://NativeEditor.lua")
    Runner.Check(Info.Handled and "MOUSE_FILTER_IGNORE" in Names(Info.Options), "Native editor completes approved enum constants")
    Info = Resource.call("InspectNativeCode","local Scene={}\nScene.Enums.Control.MouseFilter."+Marker,"res://NativeEditor.lua")
    Runner.Check(not Info.Handled,"Native enum completion respects local Scene shadowing")
    Info = Resource.call("InspectNativeCode",Prefix+"local List=Scope:New('ItemList',{})\nScope:Call(List,'AddItem',"+Marker+")","res://NativeEditor.lua")
    Runner.Check(Info.Handled and str(Info.call_hint).contains("ItemList.AddItem(text: string") and str(Info.call_hint).contains("icon: Texture2D = null"),"Native editor call hints include exact metadata names types and defaults")
    Info = Resource.call("InspectNativeCode","local Value=Scene.Value('Packed"+Marker+"',{})","res://NativeEditor.lua")
    Runner.Check(Info.Handled and "PackedVector4Array" in Names(Info.Options),"Native editor discovers pure value representations")
    Info = Resource.call("InspectNativeCode",Prefix+"local Timer=Scope:New('Timer',{})\nTimer.TimeLeft=1\nScope:Configure(Timer,{TimeLeft=2})","res://NativeEditor.lua")
    Runner.Check(Info.Diagnostics.size()==2 and Info.Diagnostics[0].code=="E_NATIVE_READONLY" and Info.Diagnostics[1].code=="E_NATIVE_READONLY","Native editor diagnoses direct and batch observation writes")
    var Module := FileAccess.open("res://EditorModule.luau",FileAccess.WRITE)
    Module.store_string("local function Build()\n return 42\nend\nreturn {Build=Build}\n")
    Module.close()
    Info = Resource.call("NavigateNativeCode","local World=require('res://EditorModule.luau')\nWorld.Build"+Marker+"()","Build","res://NativeEditor.luau")
    Runner.Check(Info.result==OK and Info.script_path=="res://EditorModule.luau" and Info.location==1,"Native module navigation resolves imported exported functions through the existing Luau AST")
    Info = Resource.call("NavigateNativeCode","local X=1\ndo local X=2; print(X"+Marker+") end\nprint(X)","X","res://NativeEditor.luau")
    Runner.Check(Info.result==OK and Info.location==2 and Info.references.size()==1 and Info.references[0].line==2,"Native lexical navigation and references preserve shadowed local identity")
    Info = Resource.call("NavigateNativeCode","local M=require('user://Private.luau')\nM.Build"+Marker+"()","Build","res://NativeEditor.luau")
    Runner.Check(Info.result==ERR_UNAVAILABLE,"Native module lookup cannot read outside project resource paths")
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
