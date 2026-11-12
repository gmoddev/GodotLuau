extends RefCounted
## Production Scene dispatch, native physics and owner retirement; no replacement API.

func Run(Runner, Game: Node, Rendered := false) -> void:
    var File := FileAccess.open("res://Expansion.gdshader", FileAccess.WRITE)
    File.store_string("shader_type canvas_item;\nuniform vec4 Tint : source_color = vec4(1.0);\nuniform float Amount = 0.5;\nvoid fragment() { COLOR = Tint * Amount; }\n")
    File.close()
    var Owner = Runner.CreateScript("ServerScript", "ExpansionOwner", """
local S=Scene.new(script.Parent)
local Rendered=__GL053_RENDERED__
S.Name='ExpansionScope'
local V=Scene.Value
local X,Y,Z=Vector3.new(1,0,0),Vector3.new(0,1,0),Vector3.new(0,0,1)
local Basis={X=X,Y=Y,Z=Z}
local Values={
 {'Vector2i',{X=2,Y=-3}}, {'Vector3i',{X=2,Y=3,Z=4}},
 {'Vector4',{X=1,Y=2,Z=3,W=4}}, {'Vector4i',{X=1,Y=2,Z=3,W=4}},
 {'Quaternion',{X=0,Y=0,Z=0,W=1}},
 {'Rect2',{Position={X=1,Y=2},Size={X=3,Y=4}}},
 {'Rect2i',{Position={X=1,Y=2},Size={X=3,Y=4}}},
 {'Basis',Basis}, {'Transform3D',{Basis=Basis,Origin=Vector3.new(2,3,4)}},
 {'Transform2D',{X={X=1,Y=0},Y={X=0,Y=1},Origin={X=2,Y=3}}},
 {'Plane',{Normal=Y,D=2}}, {'AABB',{Position=X,Size=Vector3.new(2,3,4)}},
 {'Color',{R=0.2,G=0.4,B=0.6,A=0.25}},
 {'PackedByteArray',{0,127,255}}, {'PackedInt32Array',{-2147483648,2147483647}},
 {'PackedInt64Array',{-10000000000,10000000000}},
 {'PackedFloat32Array',{0.25,-1.5}}, {'PackedFloat64Array',{0.25,1.5}},
 {'PackedStringArray',{'One','Two'}}, {'PackedVector2Array',{{X=1,Y=2}}},
 {'PackedVector3Array',{X,Y}}, {'PackedColorArray',{{R=1,G=0,B=0,A=0.5}}},
 {'PackedVector4Array',{{X=1,Y=2,Z=3,W=4}}},
 {'Array',{1,'Two',true,{Nested=5}}}, {'Dictionary',{One=1,Children={2,3}}},
}
for _,Entry in ipairs(Values) do
 local Result=V(Entry[1],Entry[2])
 assert(Result.__NativeType==Entry[1] and table.isfrozen(Result),Entry[1])
 local Copy=V(Entry[1],Result)
 assert(Copy.__NativeType==Entry[1])
end
local Cycle={};Cycle.Child=Cycle
local Huge={};for I=1,1025 do Huge[I]=I end
local BadValues={
 function() V('Vector2i',{X=0.5,Y=1}) end,
 function() V('Vector4',{X=0/0,Y=0,Z=0,W=1}) end,
 function() V('PackedByteArray',{256}) end,
 function() V('PackedInt32Array',{2147483648}) end,
 function() V('PackedStringArray',{1}) end,
 function() V('Array',{1,Named=2}) end,
 function() V('Array',{[1]=1,[3]=3}) end,
 function() V('Dictionary',Cycle) end,
 function() V('Array',Huge) end,
 function() V('Dictionary',{Bad=game}) end,
 function() V('Dictionary',{Bad=function() end}) end,
 function() V('Dictionary',{Bad={__NativeType='Object'}}) end,
 function() V('AABB',{Position=X,Size=Vector3.new(-1,1,1)}) end,
 function() V('Color',{R=1,G=1,B=1,A=2}) end,
}
for I,Check in ipairs(BadValues) do assert(not pcall(Check),'Value rejection '..I) end
local Timer=S:New('Timer',{Name='Timer',WaitTime=0.03,OneShot=true})
assert(Timer.TimeLeft==0 and Scene.Describe('Timer').Properties.TimeLeft.ReadOnly)
assert(not pcall(function() Timer.TimeLeft=1 end))
assert(not pcall(function() S:Configure(Timer,{WaitTime=2,TimeLeft=1}) end))
assert(math.abs(Timer.WaitTime-0.03)<0.001)
S:Connect(Timer,'Timeout',function() game:SetAttribute('ExpansionTimer',true) end)
S:Call(Timer,'Start')
local Gradient=S:New('Gradient',{})
S:Call(Gradient,'SetColor',0,{R=0.1,G=0.2,B=0.3,A=0.25})
assert(math.abs(S:Call(Gradient,'GetColor',0).A-0.25)<0.001)
assert(not pcall(function() S:Call(Gradient,'GetColor',99) end))
local Texture=S:New('GradientTexture2D',{Gradient=Gradient,Width=16,Height=16})
local Frames=S:New('SpriteFrames',{})
S:Call(Frames,'AddAnimation','pulse')
S:Call(Frames,'SetAnimationLoop','pulse',false)
S:Call(Frames,'SetAnimationSpeed','pulse',60)
S:Call(Frames,'AddFrame','pulse',Texture)
S:Call(Frames,'AddFrame','pulse',Texture)
assert(#S:Call(Frames,'GetAnimationNames')==2 and S:Call(Frames,'GetFrameCount','pulse')==2)
assert(not pcall(function() S:Call(Frames,'AddAnimation','pulse') end))
assert(not pcall(function() S:Call(Frames,'GetFrameTexture','absent',0) end))
assert(not pcall(function() S:Call(Frames,'RemoveFrame','pulse',2) end))
local Sprite=S:New('AnimatedSprite2D',{Name='Sprite',SpriteFrames=Frames})
S:Connect(Sprite,'AnimationFinished',function() game:SetAttribute('ExpansionAnimation',true) end)
S:Call(Sprite,'Play','pulse')
local List=S:New('ItemList',{Name='List',FixedIconSize={X=16,Y=16}})
assert(S:Call(List,'AddItem','First')==0)
S:Call(List,'AddItem','Second',Texture)
S:Call(List,'Select',1)
assert(List.ItemCount==2 and S:Call(List,'GetSelectedItems')[1]==1)
assert(S:Call(List,'GetItemText',0)=='First' and S:Call(List,'GetItemIcon',0)==nil)
assert(not pcall(function() S:Call(List,'SetItemText',2,'bad') end))
assert(S:Call(List,'GetItemText',1)=='Second')
local Mesh=S:New('BoxMesh',{Size=Vector3.new(2,3,4)})
local Bounds=S:Call(Mesh,'GetAabb')
assert(Bounds.Size.X==2 and Bounds.Size.Y==3)
local Multi=S:New('MultiMesh',{TransformFormat=1,UseColors=true,InstanceCount=2,Mesh=Mesh})
local Transform={Basis=Basis,Origin=Vector3.new(2,3,4)}
S:Call(Multi,'SetInstanceTransform',1,Transform)
S:Call(Multi,'SetInstanceColor',1,{R=1,G=0.5,B=0.25,A=0.5})
if Rendered then
 assert(S:Call(Multi,'GetInstanceTransform',1).Origin.Y==3)
 assert(math.abs(S:Call(Multi,'GetInstanceColor',1).A-0.5)<0.01)
end
assert(not pcall(function() S:Call(Multi,'SetInstanceTransform',2,Transform) end))
assert(not pcall(function() S:Call(Multi,'GetInstanceTransform2d',0) end))
assert(not pcall(function() S:Configure(Multi,{TransformFormat=0}) end))
local Shader=S:Load('Shader','res://Expansion.gdshader')
local Material=S:New('ShaderMaterial',{Shader=Shader})
if Rendered then
 S:Call(Material,'SetShaderParameter','Tint',V('Color',{R=0.2,G=0.4,B=0.6,A=0.25}))
 S:Call(Material,'SetShaderParameter','Amount',0.75)
 assert(math.abs(S:Call(Material,'GetShaderParameter','Tint').A-0.25)<0.001)
 assert(S:Call(Material,'GetShaderParameter','Amount')==0.75)
 assert(not pcall(function() S:Call(Material,'SetShaderParameter','Unknown',1) end))
 assert(not pcall(function() S:Call(Material,'SetShaderParameter','Amount','bad') end))
 assert(S:Call(Material,'GetShaderParameter','Amount')==0.75)
end
local Shape=S:New('RectangleShape2D',{Size={X=8,Y=8}})
local Body=S:New('RigidBody2D',{Name='Body',GravityScale=0,Position={X=200,Y=200}})
S:New('CollisionShape2D',{Shape=Shape},Body)
local Area=S:New('Area2D',{Name='Area',Position={X=200,Y=200}})
S:New('CollisionShape2D',{Shape=Shape},Area)
S:Connect(Area,'BodyEntered',function(Node)
 if Node~=nil then assert(Node==Body);game:SetAttribute('ExpansionOverlap',true)
 else game:SetAttribute('ExpansionForeignNil',true) end
end)
S:Connect(List,'ItemActivated',function(Index)
 assert(Index==0);game:SetAttribute('ExpansionCallback',true)
 task.wait(0.2)
 game:SetAttribute('ExpansionStaleCallback',true)
end)
shared.Expansion={Scope=S,Body=Body,Area=Area,Material=Material,Call=S.Call,Configure=S.Configure}
game:SetAttribute('ExpansionReady',true)
while not game:GetAttribute('ExpansionImpulseReady') do task.wait() end
S:Call(Body,'ApplyImpulse',{X=0.1,Y=0}) -- pinned Vector2 default position
game:SetAttribute('ExpansionImpulseApplied',true)
""".replace("__GL053_RENDERED__","true" if Rendered else "false"), Game)
    if not await Runner.Until("ExpansionReady"):
        return
    await Runner.Until("ExpansionTimer")
    await Runner.Until("ExpansionAnimation")
    await Runner.Until("ExpansionOverlap")
    var Scope := Game.get_node("ExpansionScope")
    var Area := Scope.get_node("Area") as Area2D
    var Body := Scope.get_node("Body") as RigidBody2D
    await Runner.physics_frame
    await Runner.physics_frame
    Game.set_meta("ExpansionImpulseReady",true)
    await Runner.Until("ExpansionImpulseApplied")
    await Runner.physics_frame
    await Runner.physics_frame
    Runner.Check(Body.linear_velocity.x>0,"Expansion impulse reaches the initialized native 2D simulation")
    Runner.Check(Area.overlaps_body(Body), "Expansion uses actual native 2D overlap state")
    var Foreign := StaticBody2D.new()
    Game.add_child(Foreign)
    Area.body_entered.emit(Foreign)
    Runner.Check(Game.get_meta("ExpansionForeignNil", false), "Expansion foreign signal node carries no scope capability")
    Foreign.queue_free()
    Runner.CreateScript("ServerScript", "ExpansionGuest", """
local A=shared.Expansion
assert(not pcall(function() A.Call(A.Scope,A.Body,'ApplyCentralImpulse',{X=1,Y=0}) end))
assert(not pcall(function() A.Call(A.Scope,A.Material,'SetShaderParameter','Amount',0) end))
assert(not pcall(function() A.Configure(A.Scope,A.Body,{Mass=2}) end))
game:SetAttribute('ExpansionGuestRejected',true)
""", Game)
    await Runner.Until("ExpansionGuestRejected")
    (Scope.get_node("List") as ItemList).item_activated.emit(0)
    Runner.Check(Game.get_meta("ExpansionCallback", false), "Expansion native collection callback enters the original owner")
    Owner.queue_free()
    await Runner.process_frame
    await Runner.create_timer(0.25).timeout
    Runner.Check(not is_instance_valid(Scope) and not Game.has_meta("ExpansionStaleCallback"), "Expansion owner retirement removes nodes and yielded native callbacks")
    print("[Runtime:NativeExpansion] PASS ","renderer" if Rendered else "headless; renderer checks require the rendered fixture")
