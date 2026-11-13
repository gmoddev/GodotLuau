local Art=require('res://Shared/Art.luau')
local Enemies=require('res://Shared/Enemies.luau')
local World={}
local Names={'Dock','Reactor','Vault'}
local Colors={Color3.new(0.12,0.7,0.8),Color3.new(0.95,0.3,0.15),Color3.new(0.85,0.65,0.15)}
function World.Build(Parent,Level,OnPickup)
 local S=Scene.new(Parent)
 S.Name='ExpeditionWorld'
 local Room=S:Instantiate(S:Load('PackedScene','res://Rooms/'..Names[Level]..'.tscn'))
 local Texture=S:Load('Texture2D','res://Assets/Metal.svg')
 local Floor=Room:FindFirstChild('Floor'):FindFirstChild('Surface')
 Floor.Material=S:New('StandardMaterial3D',{Color=Color3.new(0.3,0.45,0.55),AlbedoTexture=Texture,Roughness=0.9})
 S:New('MeshInstance3D',{Name='Cargo',Position=Vector3.new(8,0.6,8),Mesh=S:Load('Mesh','res://Assets/Cargo.obj'),Material=Art.Material(S,Colors[Level])})
 S:New('DirectionalLight3D',{RotationDegrees=Vector3.new(-55,-20,0),Energy=1.1})
 S:New('OmniLight3D',{Position=Vector3.new(0,5,-4),Range=14,Energy=1.3,Color=Colors[Level]})
 for Index,Entry in {{Vector3.new(-10,1,0),Vector3.new(0.5,3,20)},{Vector3.new(10,1,0),Vector3.new(0.5,3,20)},{Vector3.new(0,1,10),Vector3.new(20,3,0.5)},{Vector3.new(0,1,-10),Vector3.new(20,3,0.5)}} do
  local Wall=S:New('StaticBody3D',{Name='Wall'..Index,Position=Entry[1],CollisionLayer=4194304})
  S:New('CollisionShape3D',{Shape=S:New('BoxShape3D',{Size=Entry[2]})},Wall)
  Art.Box(S,'WallVisual',Vector3.new(0,0,0),Entry[2],Color3.new(0.08,0.15,0.22),Wall)
 end
 local Body=S:New('CharacterBody3D',{Name='Explorer',Position=Vector3.new(0,1,6),CollisionLayer=2097152,CollisionMask=4194304})
 S:New('CollisionShape3D',{Shape=S:New('CapsuleShape3D',{Radius=0.35,Height=1.6})},Body)
 local Visual=Art.Box(S,'Visual',Vector3.new(0,0,0),Vector3.new(0.7,1.6,0.7),Color3.new(0.15,0.8,0.85),Body)
 Art.Animation(S,Visual,Body)
 local Camera=S:New('Camera3D',{Name='Camera',Position=Vector3.new(0,12,11),RotationDegrees=Vector3.new(-48,0,0),Fov=65},Body)
 local Cast=S:New('ShapeCast3D',{Name='PulseCast',Shape=S:New('SphereShape3D',{Radius=0.4}),TargetPosition=Vector3.new(0,0,-8),CollisionMask=1048576,MaxResults=8},Body)
 local Sound=S:New('AudioStreamPlayer3D',{Stream=S:Tone(720,0.08),VolumeDb=-18},Body)
 local Chime=S:New('AudioStreamPlayer3D',{Stream=S:Load('AudioStream','res://Assets/Chime.tres'),VolumeDb=-18},Body)
 local Burst=S:New('CPUParticles3D',{Name='PickupBurst',Mesh=S:New('SphereMesh',{Radius=0.06,Height=0.12}),Amount=16,Lifetime=0.5,OneShot=true,Explosiveness=1,InitialVelocityMin=1,InitialVelocityMax=3,Gravity=Vector3.new(0,-3,0),Color={R=0.3,G=1,B=0.8,A=1},Emitting=false},Body)
 local Pickups={}
 for Index,Position in {Vector3.new(-6,1,2),Vector3.new(6,1,2),Vector3.new(0,1,-5)} do
  local Area=S:New('Area3D',{Name='Cell'..Index,Position=Position,CollisionMask=2097152})
  S:New('CollisionShape3D',{Shape=S:New('SphereShape3D',{Radius=0.9})},Area)
  local Material=S:New('ShaderMaterial',{Shader=S:Load('Shader','res://Assets/Beacon.gdshader')})
  S:Call(Material,'SetShaderParameter','Tint',Scene.Value('Color',{R=0.15,G=0.9,B=0.8,A=1}))
  S:New('MeshInstance3D',{Name='CellVisual',Mesh=S:New('SphereMesh',{Radius=0.3,Height=0.6}),Material=Material},Area)
  Pickups[Index]={Area=Area,Collected=false}
  S:Connect(Area,'BodyEntered',function(Value)
   if Value and Value.Name=='Explorer' and not Pickups[Index].Collected then
    Pickups[Index].Collected=true
    Area.Visible=false
    Burst.Emitting=false;Burst.Emitting=true
    S:Call(Chime,'Play')
    OnPickup(Index)
   end
  end)
 end
 local Guards={}
 for Index=1,Level+1 do
  local Position=Vector3.new(Index%2==0 and 5 or -5,1,-3-math.floor(Index/2)*2)
  local Guard=Enemies.New(S,Index,Position,Level)
  Guards[Guard.Body.Name]=Guard
 end
 local Exit=Art.Box(S,'Exit',Vector3.new(0,1,-8),Vector3.new(3,2,0.3),Colors[Level])
 S:New('Label3D',{Text=Names[Level]..' • recover 3 cells, clear guards, E to extract',Position=Vector3.new(0,3,-8),FontSize=30,Billboard=1})
 return {Scope=S,Room=Room,Body=Body,Visual=Visual,Camera=Camera,Cast=Cast,Sound=Sound,Burst=Burst,Guards=Guards,Pickups=Pickups,Exit=Exit,Name=Names[Level]}
end
return World
