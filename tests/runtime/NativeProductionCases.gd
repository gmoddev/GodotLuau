extends RefCounted
## Real production dispatch: typed collections, effects, ownership and physics.

func Run(Runner, Game: Node, NavigationAvailable := false) -> void:
    var ForeignBody := StaticBody3D.new()
    ForeignBody.position=Vector3(202.5,1,200)
    ForeignBody.collision_layer=16777216
    var ForeignShape := CollisionShape3D.new()
    var ForeignBox := BoxShape3D.new()
    ForeignBox.size=Vector3(1,1,1)
    ForeignShape.shape=ForeignBox
    ForeignBody.add_child(ForeignShape)
    Game.add_child(ForeignBody)
    if NavigationAvailable:
        var Polygon := NavigationPolygon.new()
        Polygon.vertices=PackedVector2Array([Vector2(-100,-100),Vector2(100,-100),Vector2(100,100),Vector2(-100,100)])
        Polygon.add_polygon(PackedInt32Array([0,1,2,3]))
        ResourceSaver.save(Polygon,"res://ProductionNavigation.tres")
    var Owner=Runner.CreateScript("ServerScript","ProductionOwner","""
local S=Scene.new(script.Parent)
S.Name='ProductionScope'
local V2=function(X,Y) return {X=X,Y=Y} end
local Edit=S:New('CodeEdit',{Name='Code',Text='local Value = 1'})
S:Call(Edit,'SetStringDelimiters',{'" "'})
S:Call(Edit,'SetCommentDelimiters',{'--'})
S:Call(Edit,'SetLineLengthGuidelines',{80,120})
assert(S:Call(Edit,'GetStringDelimiters')[1]=='" "')
assert(S:Call(Edit,'GetCommentDelimiters')[1]=='--')
assert(S:Call(Edit,'GetLineLengthGuidelines')[2]==120)
for _,Bad in ipairs({{1.5},{0/0},{'80'},{[1]=80,[3]=120},{80,Extra=2},{-1}}) do
 assert(not pcall(function() S:Call(Edit,'SetLineLengthGuidelines',Bad) end))
 assert(S:Call(Edit,'GetLineLengthGuidelines')[2]==120)
end
assert(not pcall(function() S:Call(Edit,'SetCommentDelimiters',{'--','--'}) end))
local Image=S:New('Image',{})
assert(S:Call(Image,'IsEmpty'))
assert(not pcall(function() S:Call(Image,'Fill',{R=1,G=0,B=0,A=1}) end))
local Bytes={255,0,0,255, 0,255,0,255, 0,0,255,255, 255,255,255,255}
S:Call(Image,'SetData',2,2,false,Scene.Enums.Image.Format.FORMAT_RGBA8,Bytes)
assert(S:Call(Image,'GetWidth')==2 and S:Call(Image,'GetHeight')==2)
assert(S:Call(Image,'GetFormat')==5 and #S:Call(Image,'GetData')==16)
assert(not pcall(function() S:Call(Image,'SetData',2,2,false,5,{1}) end))
assert(S:Call(Image,'GetWidth')==2 and #S:Call(Image,'GetData')==16)
S:Call(Image,'Fill',{R=0.1,G=0.5,B=0.8,A=1})
local Texture=S:New('ImageTexture',{})
S:Call(Texture,'SetImage',Image)
S:Call(Texture,'Update',Image)
local Readback=S:Call(Texture,'GetImage')
if Readback then
 assert(S:Call(Readback,'GetWidth')==2 and #S:Call(Readback,'GetData')==16)
 assert(not pcall(function() S:Call(Readback,'Fill',{R=1,G=0,B=0,A=1}) end))
end
local Layers=S:New('Texture2DArray',{})
assert(S:Call(Layers,'CreateFromImages',{Image,Image})==0)
assert(S:Call(Layers,'GetLayers')==2)
local Other=Scene.new(script.Parent)
local Foreign=Other:New('Image',{})
assert(not pcall(function() S:Call(Layers,'CreateFromImages',{Image,Foreign}) end))
assert(not pcall(function() S:Call(Layers,'CreateFromImages',{[1]=Image,[3]=Image}) end))
assert(not pcall(function() S:Call(Layers,'CreateFromImages',{Image,Extra=Image}) end))
assert(S:Call(Layers,'GetLayers')==2)
Other:Destroy()
local Pattern=S:New('TileMapPattern',{})
S:Call(Pattern,'SetCell',V2(0,0),0,V2(0,0),0)
S:Call(Pattern,'SetCell',V2(1,0)) -- exact Vector2i defaults, no expression evaluator
local Cells=S:Call(Pattern,'GetUsedCells')
assert(#Cells==2 and Cells[1].X==0 and Cells[2].X==1 and S:Call(Pattern,'GetSize').X==2)
local Map=S:New('TileMapLayer',{Name='Tiles',TileSet=S:New('TileSet',{})})
assert(#S:Call(Map,'GetUsedCells')==0)
local Copy=S:Call(Map,'GetPattern',{V2(0,0),V2(1,0)})
assert(Copy~=nil)
assert(not pcall(function() S:Call(Map,'GetPattern',{V2(0.5,0)}) end))
S:New('PointLight2D',{Name='PointLight',Energy=0.5,Color={R=0.5,G=0.6,B=1,A=1},Texture=Texture,TextureScale=2})
S:New('DirectionalLight2D',{Name='Sun2D',Enabled=true,Energy=0.2,ShadowEnabled=false})
S:New('CPUParticles2D',{Name='Particles2D',Texture=Texture,Amount=8,Lifetime=1,Color={R=1,G=1,B=1,A=1},Emitting=false})
S:New('CPUParticles3D',{Name='Particles3D',Mesh=S:New('SphereMesh',{}),Amount=8,Lifetime=1,Emitting=false})
S:New('Decal',{Name='Decal',Albedo=Texture,Size=Vector3.new(2,2,2),Modulate={R=1,G=1,B=1,A=0.5}})
local Layer=16777216
local Body=S:New('StaticBody3D',{Name='Body3',Position=Vector3.new(200,1,200),CollisionLayer=Layer})
S:New('CollisionShape3D',{Shape=S:New('BoxShape3D',{Size=Vector3.new(2,2,2)})},Body)
local Area=S:New('Area3D',{Name='Area3',Position=Vector3.new(200,1,200),CollisionMask=Layer})
S:New('CollisionShape3D',{Shape=S:New('BoxShape3D',{Size=Vector3.new(8,8,8)})},Area)
local PeerArea=S:New('Area3D',{Position=Vector3.new(200,1,200),CollisionLayer=Layer,CollisionMask=Layer})
S:New('CollisionShape3D',{Shape=S:New('BoxShape3D',{Size=Vector3.new(2,2,2)})},PeerArea)
local Cast=S:New('ShapeCast3D',{Position=Vector3.new(200,5,200),Shape=S:New('SphereShape3D',{Radius=0.2}),TargetPosition=Vector3.new(0,-10,0),CollisionMask=Layer,MaxResults=4})
local Body2=S:New('StaticBody2D',{Name='Body2',Position=V2(800,800),CollisionLayer=Layer})
S:New('CollisionShape2D',{Shape=S:New('RectangleShape2D',{Size=V2(20,20)})},Body2)
local Area2=S:New('Area2D',{Position=V2(800,800),CollisionMask=Layer})
S:New('CollisionShape2D',{Shape=S:New('RectangleShape2D',{Size=V2(100,100)})},Area2)
local Cast2=S:New('ShapeCast2D',{Position=V2(800,700),Shape=S:New('CircleShape2D',{Radius=2}),TargetPosition=V2(0,200),CollisionMask=Layer})
assert(not pcall(function() S:Call(Cast,'ForceUpdate') end))
local Entered=0
S:Connect(Area,'BodyEntered',function(Value) if Value and Value.Name=='Body3' then Entered+=1 end end)
local Agent
if __NAVIGATION__ then
 local Walker=S:New('CharacterBody2D',{Position=V2(10000,10000)})
 S:New('NavigationRegion2D',{Position=V2(10000,10000),NavigationPolygon=S:Load('NavigationPolygon','res://ProductionNavigation.tres')})
 Agent=S:New('NavigationAgent2D',{TargetPosition=V2(10050,10000),PathDesiredDistance=1,TargetDesiredDistance=1},Walker)
 S:New('NavigationObstacle2D',{Position=V2(10080,10080),Radius=4,AvoidanceEnabled=true})
 S:New('NavigationObstacle3D',{Position=Vector3.new(200,0,200),Radius=1,AvoidanceEnabled=true})
end
local Frames=0
local Connection
Connection=game:GetService('RunService').Stepped:Connect(function()
 Frames+=1
 if Frames<5 then return end
 S:Call(Cast,'ForceUpdate');S:Call(Cast2,'ForceUpdate')
 assert(S:Call(Cast,'IsColliding') and S:Call(Cast2,'IsColliding'))
 for _,Item in ipairs({Cast,Cast2}) do
  assert(S:Call(Item,'GetCollisionCount')>0)
  assert(S:Call(Item,'GetCollider',0)~=nil)
  assert(S:Call(Item,'GetCollisionPoint',0)~=nil and S:Call(Item,'GetCollisionNormal',0)~=nil)
  assert(not pcall(function() S:Call(Item,'GetCollider',999) end))
 end
 S:Call(Cast,'AddException',Body);S:Call(Cast,'ForceUpdate');assert(not S:Call(Cast,'IsColliding'))
 S:Call(Cast,'RemoveException',Body);S:Call(Cast,'ClearExceptions')
 S:Call(Cast2,'AddException',Body2);S:Call(Cast2,'ForceUpdate');assert(not S:Call(Cast2,'IsColliding'))
 S:Call(Cast2,'RemoveException',Body2);S:Call(Cast2,'ClearExceptions')
 assert(S:Call(Area,'HasOverlappingBodies') and S:Call(Area2,'HasOverlappingBodies'))
 assert(S:Call(Area,'HasOverlappingAreas') and S:Call(Area,'OverlapsArea',PeerArea))
 assert(S:Call(Area,'OverlapsBody',Body) and S:Call(Area2,'OverlapsBody',Body2))
 assert(#S:Call(Area,'GetOverlappingBodies')==1 and #S:Call(Area2,'GetOverlappingBodies')==1)
 assert(#S:Call(Area,'GetOverlappingAreas')==1 and #S:Call(Area2,'GetOverlappingAreas')==0)
 assert(not S:Call(Area2,'HasOverlappingAreas') and Entered==1)
 assert(not S:Call(Area2,'OverlapsArea',Area2))
 if Agent then
  local OK=pcall(function() S:Call(Agent,'GetNextPathPosition') end)
  if not OK then assert(Frames<120);return end
  assert(#S:Call(Agent,'GetCurrentNavigationPath')>=2)
  assert(S:Call(Agent,'DistanceToTarget')>0)
  assert(not S:Call(Agent,'IsTargetReached') and S:Call(Agent,'IsTargetReachable'))
  assert(not S:Call(Agent,'IsNavigationFinished') and S:Call(Agent,'GetFinalPosition').X>10000)
 end
 Connection:Disconnect()
 game:SetAttribute('ProductionPhysics',true)
end)
shared.Production={Scope=S,Call=S.Call,Image=Image,Texture=Texture}
game:SetAttribute('ProductionReady',true)
""".replace("__NAVIGATION__","true" if NavigationAvailable else "false"),Game)
    if not await Runner.Until("ProductionReady"):
        return
    await Runner.Until("ProductionPhysics",240)
    var Scope=Game.get_node("ProductionScope")
    Runner.Check((Scope.get_node("Code") as CodeEdit).get_line_length_guidelines()==[80,120],"Production typed int-array dispatch reaches CodeEdit")
    Runner.CreateScript("ServerScript","ProductionWrongOwner","""
local P=shared.Production
assert(not pcall(function() P.Call(P.Scope,P.Texture,'SetImage',P.Image) end))
game:SetAttribute('ProductionWrongOwnerRejected',true)
""",Game)
    await Runner.Until("ProductionWrongOwnerRejected")
    Owner.queue_free()
    await Runner.process_frame
    await Runner.process_frame
    Runner.Check(not is_instance_valid(Scope),"Production owner retirement destroys casts navigation particles and resource handles")
    ForeignBody.queue_free()
    print("[Runtime:NativeProduction] PASS navigation=",NavigationAvailable)
