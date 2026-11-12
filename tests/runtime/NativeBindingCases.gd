extends RefCounted
## Real native GL-051 policy/composition cases in the existing Integration actor.

func Write(Path: String, Text: String) -> void:
    var File := FileAccess.open(Path, FileAccess.WRITE)
    File.store_string(Text)

func Run(Runner, Game: Node) -> void:
    Write("res://BindingFont.tres", """[gd_resource type="SystemFont" format=3]
[resource]
font_names = PackedStringArray("sans-serif")
""")
    Write("res://BindingUI.tscn", """[gd_scene format=3]
[node name="NativeUI" type="Control"]
layout_mode = 0
offset_left = 4.0
offset_top = 6.0
offset_right = 104.0
offset_bottom = 36.0
""")
    var Deep := "[gd_scene format=3]\n[node name=\"Deep\" type=\"Node3D\"]\n"
    var ParentPath := "."
    for Index in range(33):
        Deep += "[node name=\"N%d\" type=\"Node3D\" parent=\"%s\"]\n" % [Index, ParentPath]
        ParentPath = "N0" if Index==0 else ParentPath+"/N%d" % Index
    Write("res://BindingDeep.tscn", Deep)
    var Wide := "[gd_scene format=3]\n[node name=\"Wide\" type=\"Node3D\"]\n"
    for Index in range(2048):
        Wide += "[node name=\"N%d\" type=\"Node3D\" parent=\".\"]\n" % Index
    Write("res://BindingWide.tscn", Wide)
    Write("res://BindingTexture.tres", """[gd_resource type="GradientTexture2D" load_steps=2 format=3]
[sub_resource type="Gradient" id="Gradient_native"]
colors = PackedColorArray(0.1,0.8,0.9,1,0.9,0.4,0.1,1)
[resource]
gradient = SubResource("Gradient_native")
width = 16
height = 16
""")
    Write("res://BindingMesh.tres", """[gd_resource type="BoxMesh" format=3]
[resource]
size = Vector3(1,2,3)
""")
    Write("res://BindingReusable.tscn", """[gd_scene load_steps=2 format=3]
[sub_resource type="BoxMesh" id="Box_native"]
size = Vector3(2,3,4)
[node name="Reusable" type="Node3D"]
transform = Transform3D(0,0,-2,0,2,0,2,0,0,1,0,0)
[node name="Visual" type="MeshInstance3D" parent="."]
mesh = SubResource("Box_native")
""")
    Write("res://BindingDenied.gd", """extends Node3D
func _init():
    var Tree := Engine.get_main_loop() as SceneTree
    Tree.current_scene.set_meta("BindingUnsafeInit", true)
""")
    Write("res://BindingScripted.tscn", """[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://BindingDenied.gd" id="1"]
[node name="Denied" type="Node3D"]
script = ExtResource("1")
""")
    Write("res://BindingConnected.tscn", """[gd_scene format=3]
[node name="Connected" type="Button"]
[connection signal="pressed" from="." to="." method="queue_free"]
""")
    Write("res://BindingNested.tscn", """[gd_scene load_steps=2 format=3]
[ext_resource type="PackedScene" path="res://BindingReusable.tscn" id="1"]
[node name="Nested" instance=ExtResource("1")]
""")
    Write("res://BindingGrouped.tscn", """[gd_scene format=3]
[node name="Grouped" type="Node3D" groups=["native_capability"]]
""")
    Write("res://BindingNetwork.tscn", """[gd_scene format=3]
[node name="Network" type="NetworkService"]
""")
    for Item in [
        ["Shear", "1,0,0,0.5,1,0,0,0,1,0,0,0"],
        ["Mirror", "-1,0,0,0,1,0,0,0,1,0,0,0"],
        ["LargePosition", "1,0,0,0,1,0,0,0,1,100001,0,0"],
        ["ZeroScale", "0,0,0,0,1,0,0,0,1,0,0,0"],
    ]:
        Write("res://Binding" + Item[0] + ".tscn", '[gd_scene format=3]\n[node name="Invalid" type="Node3D"]\ntransform=Transform3D(' + Item[1] + ')\n')
    Write("res://BindingCameraTakeover.tscn", '[gd_scene format=3]\n[node name="Camera" type="Camera3D"]\ncurrent=true\n')
    var Owner = Runner.CreateScript("ServerScript", "BindingOwner", """
local S=Scene.new(script.Parent)
S.Name='BindingScope'
local Names=Scene.Classes()
assert(#Names>48 and Scene.Describe('ClassDB')==nil)
assert(Scene.Describe('Object').Constructible==false)
local Info=Scene.Describe('TextureRect')
assert(Info.Constructible and Info.Available and Info.Properties.Texture.ResourceClass=='Texture2D')
assert(Info.Properties.Position.Type=='Vector2' and Info.Signals.Resized~=nil)
assert(#Scene.PolicySHA256==64 and #Scene.ApiSHA256==64)
assert(not pcall(function() Scene.Enums.Control.MouseFilter.MOUSE_FILTER_IGNORE=100 end))
local Texture=S:Load('Texture2D','res://BindingTexture.tres')
local Font=S:Load('Font','res://BindingFont.tres')
local Caption=S:New('Label',{Name='Caption',Text='Native font',Font=Font})
S:New('Label3D',{Name='WorldCaption',Text='Native font',Font=Font})
assert(S:Get(Caption,'Font')==Font)
local UI=S:Instantiate(S:Load('PackedScene','res://BindingUI.tscn'))
assert(UI:IsA('Control') and UI.Position.X==4 and UI.Size.X==100)
assert(Texture==S:Load('Texture2D','res://BindingTexture.tres'))
assert(S:Call(Texture,'GetWidth')==16 and S:Call(Texture,'GetHeight')==16)
local Image=S:New('TextureRect',{Name='Image',Texture=Texture,MinSize=Vector2.new(48,48),
    ExpandMode=Scene.Enums.TextureRect.ExpandMode.EXPAND_IGNORE_SIZE})
local Toggle=S:New('CheckButton',{Name='Toggle',Text='Toggle',ToggleMode=true})
local Slider=S:New('HSlider',{Name='Slider',MinValue=0,MaxValue=100,Step=1})
local Text=S:New('LineEdit',{Name='Text',Text='original'})
local Material=S:New('StandardMaterial3D',{AlbedoTexture=Texture,Metallic=0.3})
local Mesh=S:New('PlaneMesh',{Size=Vector2.new(4,5)})
local Display=S:New('MeshInstance3D',{Name='Display',Mesh=Mesh,Material=Material})
S:Call(Material,'SetRoughness',0.4)
assert(not pcall(function() S:Call(S:Get(Display,'Material'),'SetRoughness',0.5) end))
local A=S:New('Node3D',{Name='A',Position=Vector3.new(3,0,0)})
local B=S:New('Node3D',{Name='B',Position=Vector3.new(7,0,0)})
local Child=S:New('Node3D',{Name='Child',Position=Vector3.new(2,0,0)},A)
assert(S:Call(Child,'GetGlobalPosition').X==5)
S:Reparent(Child,B,true)
assert(Child.Parent==B and S:Call(Child,'GetGlobalPosition').X==5 and Child.Position.X==-2)
S:Reparent(Child,A,false)
assert(Child.Parent==A and S:Call(Child,'GetGlobalPosition').X==1)
local P=S:Load('PackedScene','res://BindingReusable.tscn')
local First=S:Instantiate(P,A)
First.Name='First'
assert(First:IsA('Node3D') and First.Visual:IsA('MeshInstance3D'))
local Copy=S:Clone(First,B)
Copy.Name='Copy'
local SourceButton=S:New('Button',{Name='SourceButton',Text='Native'})
S:Connect(SourceButton,'Pressed',function() game:SetAttribute('BindingCloneSignal',(game:GetAttribute('BindingCloneSignal') or 0)+1) end)
local CopyButton=S:Clone(SourceButton)
CopyButton.Name='CopyButton'
local Click=S:Connect(Toggle,'Toggled',function(Value)
    assert(type(Value)=='boolean')
    game:SetAttribute('BindingToggle',Value)
    game:SetAttribute('BindingCallbackStarted',true)
    task.wait(0.1)
    game:SetAttribute('BindingCallbackAfterRetire',true)
end)
S:Connect(Slider,'ValueChanged',function(Value) assert(type(Value)=='number'); game:SetAttribute('BindingNumber',Value) end)
S:Connect(Text,'TextChanged',function(Value) assert(type(Value)=='string'); game:SetAttribute('BindingText',Value) end)
S:Call(Toggle,'SetPressedNoSignal',false)
S:Call(Slider,'SetValueNoSignal',12)
S:Call(Text,'Clear')
assert(Text.Text=='')
local Audio=S:New('AudioStreamPlayer',{Name='Audio',Stream=S:Tone(440,0.05)})
S:Call(Audio,'Play') -- pinned default argument, no unbounded argument forwarding
assert(S:Call(Audio,'IsPlaying'))
S:Call(Audio,'Stop')
local Before=#S:GetDescendants()
local Bad={
 function() S:New('Object',{}) end,
 function() S:New('ClassDB',{}) end,
 function() S:Call(Toggle,'free') end,
 function() S:Call(Toggle,'set_script',nil) end,
 function() S:Call(Toggle,'SetPressedNoSignal','bad') end,
 function() S:Call(Toggle,'IsPressed',true) end,
 function() S:Call(Child,'ToGlobal',{X=1,Y=2,Z=3}) end,
 function() S:Call(Child,'ToGlobal',Vector3.new(0/0,0,0)) end,
 function() S:Configure(Texture,{Width=99}) end,
 function() S:Reparent(A,Child) end,
 function() S:Reparent(Child,game) end,
 function() S:Clone(S) end,
 function() S:Clone(game) end,
 function() S:Instantiate(Texture) end,
 function() S:Call(Toggle,'IsPressed'..string.char(0)..'extra') end,
 function() S:Connect(Texture,'Pressed',function() end) end,
 function() S:Instantiate(S:Load('PackedScene','res://BindingDeep.tscn')) end,
 function() S:Instantiate(S:Load('PackedScene','res://BindingWide.tscn')) end,
 function() S:Instantiate(S:Load('PackedScene','res://BindingScripted.tscn')) end,
 function() S:Instantiate(S:Load('PackedScene','res://BindingConnected.tscn')) end,
 function() S:Instantiate(S:Load('PackedScene','res://BindingNested.tscn')) end,
 function() S:Instantiate(S:Load('PackedScene','res://BindingGrouped.tscn')) end,
 function() S:Instantiate(S:Load('PackedScene','res://BindingNetwork.tscn')) end,
 function() S:Instantiate(S:Load('PackedScene','res://BindingShear.tscn')) end,
 function() S:Instantiate(S:Load('PackedScene','res://BindingMirror.tscn')) end,
 function() S:Instantiate(S:Load('PackedScene','res://BindingLargePosition.tscn')) end,
 function() S:Instantiate(S:Load('PackedScene','res://BindingZeroScale.tscn')) end,
 function() S:Instantiate(S:Load('PackedScene','res://BindingCameraTakeover.tscn')) end,
}
for Index,F in ipairs(Bad) do assert(not pcall(F),'Binding rejection '..tostring(Index)) end
assert(#S:GetDescendants()==Before and not game:GetAttribute('BindingUnsafeInit'))
local Ok,Message=pcall(function() S:Call(Toggle,'SetPressedNoSignal','bad') end)
assert(not Ok and string.find(tostring(Message),'pressed',1,true) and string.find(tostring(Message),'Scene:Type',1,true))
game:SetAttribute('BindingDiagnostic',tostring(Message))
shared.BindingAPI={Scope=S,Call=S.Call,Reparent=S.Reparent,Toggle=Toggle,Mesh=Mesh,Texture=Texture}
game:SetAttribute('BindingReady',true)
""", Game)
    if not await Runner.Until("BindingReady"):
        return
    var Scope := Game.get_node("BindingScope")
    var Image := Scope.get_node("Image") as TextureRect
    var Caption := Scope.get_node("Caption") as Label
    var WorldCaption := Scope.get_node("WorldCaption") as Label3D
    Runner.Check(Caption.get_theme_font("font") is SystemFont and Caption.get_theme_font("font")==WorldCaption.font,
        "Binding project fonts share typed native UI and 3D label resources")
    var Material := (Scope.get_node("Display") as MeshInstance3D).material_override as StandardMaterial3D
    Runner.Check(Image.texture is GradientTexture2D and Image.texture.get_width()==16, "Binding typed texture loading and native UI presentation")
    Runner.Check(Material.albedo_texture==Image.texture and is_equal_approx(Material.metallic,0.3), "Binding native material shares the loaded texture")
    Runner.Check(is_equal_approx(Material.roughness,0.4), "Binding resource methods enforce getter immutability without mutation")
    var First := Scope.get_node("A/First/Visual") as MeshInstance3D
    var Copy := Scope.get_node("B/Copy/Visual") as MeshInstance3D
    Runner.Check(First.mesh==Copy.mesh and First.mesh is BoxMesh, "Binding native PackedScene and clone preserve reusable resources")
    Runner.Check(First.get_parent().scale.is_equal_approx(Vector3(2,2,2)) and First.get_parent().position.is_equal_approx(Vector3(1,0,0)), "Binding native serialization preserves bounded rotation scale and position")
    var ButtonNode := Scope.get_node("SourceButton") as Button
    var CopyButton := Scope.get_node("CopyButton") as Button
    ButtonNode.pressed.emit()
    CopyButton.pressed.emit()
    Runner.Check(Game.get_meta("BindingCloneSignal",0)==1 and CopyButton.get_signal_connection_list("pressed").is_empty(), "Binding clone excludes retained native subscriptions")
    var Toggle := Scope.get_node("Toggle") as CheckButton
    var Slider := Scope.get_node("Slider") as HSlider
    var Text := Scope.get_node("Text") as LineEdit
    Slider.value=27
    Text.text_changed.emit("native-text")
    Runner.Check(Game.get_meta("BindingNumber",0)==27 and Game.get_meta("BindingText","")=="native-text", "Binding number and string signal payloads")
    Runner.Check(str(Game.get_meta("BindingDiagnostic","")).contains("BindingOwner"), "Binding diagnostics preserve script source identity")
    Runner.CreateScript("ServerScript", "BindingGuest", """
local A=shared.BindingAPI
assert(not pcall(function() A.Call(A.Scope,A.Toggle,'Hide') end))
assert(not pcall(function() A.Reparent(A.Scope,A.Toggle,A.Scope) end))
assert(not pcall(function() A.Scope:Configure(A.Mesh,{Size=Vector2.new(1,1)}) end))
game:SetAttribute('BindingGuestRejected',true)
""", Game)
    if not await Runner.Until("BindingGuestRejected"):
        return
    Runner.CreateScript("LocalScript", "BindingClient", """
local S=game.BindingScope
assert(not pcall(function() S:Call(S.Toggle,'Hide') end))
assert(not pcall(function() S:Clone(S.Toggle) end))
game:SetAttribute('BindingClientRejected',true)
""", Game)
    if not await Runner.Until("BindingClientRejected"):
        return
    Runner.Check(Toggle.visible, "Binding wrong-owner and cross-domain calls reject without mutation")
    Toggle.button_pressed=true
    Runner.Check(Game.get_meta("BindingToggle",false) and Game.get_meta("BindingCallbackStarted",false), "Binding typed boolean native callback starts")
    Owner.queue_free()
    await Runner.process_frame
    await Runner.create_timer(0.15).timeout
    Runner.Check(not Game.has_meta("BindingCallbackAfterRetire") and not is_instance_valid(Scope), "Binding retirement cancels yielded callbacks and native composition")
    Runner.CreateScript("ServerScript", "BindingStale", """
local A=shared.BindingAPI
assert(not pcall(function() A.Call(A.Scope,A.Toggle,'Hide') end))
game:SetAttribute('BindingStaleRejected',true)
""", Game)
    await Runner.Until("BindingStaleRejected")
    Runner.Check(not Game.has_meta("BindingUnsafeInit"), "Binding PackedScene preflight prevents node script initialization")
    print("[Bindings:Qualification] PASS")
