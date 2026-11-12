extends RefCounted
## Actual native physics/navigation/bone dispatch, never mocked engine state.

func Run(Runner, Game: Node) -> void:
    var Mesh := NavigationMesh.new()
    Mesh.set_vertices(PackedVector3Array([Vector3(-5,0,-5),Vector3(-5,0,5),Vector3(5,0,5),Vector3(5,0,-5)]))
    Mesh.add_polygon(PackedInt32Array([0,1,2,3]))
    ResourceSaver.save(Mesh,"res://GameplayNavigation.tres")
    var Owner = Runner.CreateScript("ServerScript","NativeGameplayOwner","""
local S=Scene.new(script.Parent)
S.Name='NativeGameplayScope'
local Layer=33554432
local Floor=S:New('StaticBody3D',{Name='Floor',Position=Vector3.new(100,-0.5,100),CollisionLayer=Layer})
S:New('CollisionShape3D',{Shape=S:New('BoxShape3D',{Size=Vector3.new(20,1,20)})},Floor)
local Body=S:New('CharacterBody3D',{Name='Walker',Position=Vector3.new(100,2,100),CollisionMask=Layer})
S:New('CollisionShape3D',{Shape=S:New('BoxShape3D',{Size=Vector3.new(1,2,1)})},Body)
local Ray=S:New('RayCast3D',{Position=Vector3.new(100,3,100),TargetPosition=Vector3.new(0,-10,0),CollisionMask=Layer})
local Floor2=S:New('StaticBody2D',{Position={X=400,Y=200},CollisionLayer=Layer})
S:New('CollisionShape2D',{Shape=S:New('RectangleShape2D',{Size={X=200,Y=10}})},Floor2)
local Body2=S:New('CharacterBody2D',{Name='Walker2D',Position={X=400,Y=150},CollisionMask=Layer})
S:New('CollisionShape2D',{Shape=S:New('RectangleShape2D',{Size={X=12,Y=12}})},Body2)
local Ray2=S:New('RayCast2D',{Position={X=400,Y=100},TargetPosition={X=0,Y=150},CollisionMask=Layer})
local Skeleton=S:New('Skeleton3D',{Name='Skeleton'})
assert(S:Call(Skeleton,'AddBone','Root')==0)
assert(S:Call(Skeleton,'AddBone','Tip')==1)
S:Call(Skeleton,'SetBoneParent',1,0)
S:Call(Skeleton,'SetBonePosePosition',1,Vector3.new(0,1,0))
assert(S:Call(Skeleton,'GetBonePosePosition',1).Y==1)
assert(not pcall(function() S:Call(Skeleton,'AddBone','Root') end))
assert(not pcall(function() S:Call(Skeleton,'SetBoneParent',0,1) end))
assert(not pcall(function() S:Call(Skeleton,'SetBonePoseRotation',1,{X=0,Y=0,Z=0,W=0}) end))
assert(not pcall(function() S:Call(Skeleton,'GetBonePose',2) end))
assert(not pcall(function() S:Call(Body,'MoveAndSlide') end))
assert(not pcall(function() S:Configure(Body,{UpDirection=Vector3.new(0,0,0)}) end))
local Region=S:New('NavigationRegion3D',{Position=Vector3.new(300,0,300),NavigationMesh=S:Load('NavigationMesh','res://GameplayNavigation.tres')})
local Navigator=S:New('Node3D',{Position=Vector3.new(298,0,298)})
local Agent=S:New('NavigationAgent3D',{TargetPosition=Vector3.new(302,0,302),PathDesiredDistance=0.1,TargetDesiredDistance=0.1},Navigator)
assert(not pcall(function() S:Call(Agent,'GetNextPathPosition') end))
local Frames=0
local Connection
Connection=game:GetService('RunService').Stepped:Connect(function(Dt)
 Frames+=1
 Body.Velocity=Vector3.new(2,Body.Velocity.Y-20*Dt,0)
 Body2.Velocity={X=20,Y=180}
 S:Call(Body,'MoveAndSlide');S:Call(Body2,'MoveAndSlide')
 S:Call(Ray,'ForceRaycastUpdate');S:Call(Ray2,'ForceRaycastUpdate')
 if Frames==3 then
  assert(S:Call(Ray,'IsColliding') and S:Call(Ray,'GetCollider')==Floor)
  assert(S:Call(Ray2,'IsColliding') and S:Call(Ray2,'GetCollider')==Floor2)
  assert(S:Call(Ray,'GetCollisionNormal').Y>0.9)
  S:Call(Ray,'AddException',Floor);S:Call(Ray,'ForceRaycastUpdate')
  assert(not S:Call(Ray,'IsColliding'))
  S:Call(Ray,'ClearExceptions')
  game:SetAttribute('GameplayRays',true)
 end
 local Angle=math.sin(Frames*0.02)*0.2
 S:Call(Skeleton,'SetBonePoseRotation',1,{X=0,Y=math.sin(Angle/2),Z=0,W=math.cos(Angle/2)})
 if S:Call(Body,'IsOnFloor') and S:Call(Body2,'IsOnFloor') and Body.Position.X>100.5 then
  game:SetAttribute('GameplayMovement',true)
 end
 local Ready,Next=pcall(function() return S:Call(Agent,'GetNextPathPosition') end)
 if Ready then
  local Path=S:Call(Agent,'GetCurrentNavigationPath')
  if #Path>=2 and Next.X>=295 and Next.X<=305 and Next.Z>=295 and Next.Z<=305 then game:SetAttribute('GameplayNavigation',true) end
 end
 if Frames>=90 then
  assert(math.abs(S:Call(Skeleton,'GetBonePoseRotation',1).Y)>0.01)
  game:SetAttribute('GameplayBones',true)
  Connection:Disconnect()
 end
end)
game:SetAttribute('GameplayReady',true)
""",Game)
    if not await Runner.Until("GameplayReady"):
        return
    await Runner.Until("GameplayRays",240)
    await Runner.Until("GameplayMovement",240)
    await Runner.Until("GameplayNavigation",240)
    await Runner.Until("GameplayBones",240)
    var Scope := Game.get_node("NativeGameplayScope")
    var Walker := Scope.get_node("Walker") as CharacterBody3D
    var Walker2 := Scope.get_node("Walker2D") as CharacterBody2D
    Runner.Check(Walker.position.x>100.5 and Walker.is_on_floor() and Walker2.position.x>400,"Gameplay movement reaches native 2D/3D physics bodies")
    var Bones := Scope.get_node("Skeleton") as Skeleton3D
    Runner.Check(Bones.get_bone_count()==2 and Bones.get_bone_parent(1)==0 and absf(Bones.get_bone_pose_rotation(1).y)>0.01,"Gameplay procedural animation reaches actual native skeleton state")
    Owner.queue_free()
    await Runner.process_frame
    await Runner.process_frame
    Runner.Check(not is_instance_valid(Scope),"Gameplay owner destruction retires physics navigation and skeleton nodes")
    print("[Runtime:NativeGameplay] PASS")
