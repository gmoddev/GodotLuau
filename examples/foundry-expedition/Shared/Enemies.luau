local Art=require('res://Shared/Art.luau')
local Enemies={}
function Enemies.New(Scope,Index,Position,Level)
 local Body=Scope:New('CharacterBody3D',{Name='Guard'..Index,Position=Position,CollisionLayer=1048576,CollisionMask=4194304})
 Scope:New('CollisionShape3D',{Shape=Scope:New('BoxShape3D',{Size=Vector3.new(0.8,1.6,0.8)})},Body)
 local Visual=Art.Box(Scope,'Visual',Vector3.new(0,0,0),Vector3.new(0.8,1.6,0.8),Color3.new(0.9,0.25,0.2),Body)
 local Animator=Art.Animation(Scope,Visual,Body)
 local Agent=Scope:New('NavigationAgent3D',{TargetPosition=Position,PathDesiredDistance=0.9,TargetDesiredDistance=1.4},Body)
 return {Body=Body,Agent=Agent,Animator=Animator,Health=2+Level,Attack=0,PathClock=0,Speed=1.3+Level*0.25}
end
function Enemies.Step(Scope,Enemy,Player,Delta)
 Enemy.Attack=math.max(0,Enemy.Attack-Delta)
 Enemy.PathClock-=Delta
 if Enemy.PathClock<=0 then Enemy.Agent.TargetPosition=Vector3.new(Player.X,0,Player.Z);Enemy.PathClock=0.25 end
 local Ready,Next=pcall(function() return Scope:Call(Enemy.Agent,'GetNextPathPosition') end)
 local X,Z=0,0
 if Ready then
  local Difference=Next-Enemy.Body.Position
  local Length=math.sqrt(Difference.X^2+Difference.Z^2)
  if Length>0.2 then X,Z=Difference.X/Length*Enemy.Speed,Difference.Z/Length*Enemy.Speed end
 end
 Enemy.Body.Velocity=Vector3.new(X,math.max(-30,Enemy.Body.Velocity.Y-22*Delta),Z)
 Scope:Call(Enemy.Body,'MoveAndSlide')
 if Art.Distance(Enemy.Body.Position,Player)<1.5 and Enemy.Attack==0 then Enemy.Attack=1.2;return true end
 return false
end
return Enemies
