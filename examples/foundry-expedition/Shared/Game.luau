local World=require('res://Shared/World.luau')
local Art=require('res://Shared/Art.luau')
local Enemies=require('res://Shared/Enemies.luau')
local Progress=require('res://Shared/Progress.luau')
local Http=game:GetService('HttpService')
local Game={Phase='Loading',Level=1,Health=100,Cells=0,Kills=0,Energy=100,Revision=0,Clock=0,ShotClock=0,DamageClock=0,SaveClock=0,Last={},Facing=Vector3.new(0,0,-1),Message='Recover the foundry power cells'}
local function Finite(Value,Low,High)
 return type(Value)=='number' and Value==Value and Value>=Low and Value<=High
end
function Game.Command(Name)
 local Value=game:GetAttribute('Foundry'..Name)
 if not Finite(Value,0,2147483647) or Value~=math.floor(Value) then return false end
 local Old=Game.Last[Name] or 0
 if Value<=Old or Value>Old+32 then return false end
 Game.Last[Name]=Value
 return true
end
function Game.Start(Level)
 if Game.World then Game.World.Scope:Destroy() end
 Game.Level=Level or 1
 Game.Health,Game.Cells,Game.Kills,Game.Energy=100,0,0,100
 Game.Phase='Active'
 Game.ShotClock,Game.DamageClock=0,0
 Game.Receipt=Http:GenerateGUID(false)
 Game.World=World.Build(Game.Parent,Game.Level,function() Game.Cells+=1 end)
 Game.Message='Explore • collect cells • pulse guards • extract at the gate'
 Game.Revision+=1
end
function Game.Publish()
 local Remaining=0
 if Game.World then for _ in pairs(Game.World.Guards) do Remaining+=1 end end
 game:SetAttribute('FoundrySnapshot',Http:JSONEncode({Phase=Game.Phase,Level=Game.Level,Room=Game.World and Game.World.Name or 'Foundry',Health=Game.Health,Energy=math.floor(Game.Energy),Cells=Game.Cells,Kills=Game.Kills,Remaining=Remaining,Message=Game.Message,Persistence=Progress.Status,Completed=Progress.Value.Completed,Wins=Progress.Value.Wins,Revision=Game.Revision}))
end
function Game.Step(Delta)
 Delta=math.min(Delta,0.05)
 Game.Clock+=Delta
 Game.ShotClock=math.max(0,Game.ShotClock-Delta)
 Game.DamageClock=math.max(0,Game.DamageClock-Delta)
 Game.SaveClock=math.max(0,Game.SaveClock-Delta)
 if Game.Command('Start') and (Game.Phase=='Menu' or Game.Phase=='Dead' or Game.Phase=='Complete') then Game.Start(1) end
 if Game.Command('Restart') and (Game.Phase=='Paused' or Game.Phase=='Dead' or Game.Phase=='Complete') then Game.Start(1) end
 if Game.Command('Pause') and Game.World and (Game.Phase=='Active' or Game.Phase=='Paused') then Game.Phase=Game.Phase=='Active' and 'Paused' or 'Active' end
 if Game.Command('Save') then Game.SaveClock=0;Progress.Attempts=0 end
 if Progress.Dirty and not Progress.Busy and Game.SaveClock==0 then Game.SaveClock=2;task.spawn(Progress.Save) end
 if Game.Phase=='Active' then
  local W=Game.World
  local X,Z=game:GetAttribute('FoundryMoveX'),game:GetAttribute('FoundryMoveY')
  X=Finite(X,-1,1) and X or 0;Z=Finite(Z,-1,1) and Z or 0
  local Length=math.sqrt(X*X+Z*Z)
  if Length>1 then X,Z=X/Length,Z/Length end
  if Length>0.1 then Game.Facing=Vector3.new(X,0,Z);W.Visual.RotationDegrees=Vector3.new(0,math.deg(math.atan2(-X,-Z)),0) end
  local Dash=game:GetAttribute('FoundryDash')==true and Game.Energy>5 and Length>0.1
  local Speed=Dash and 8 or 4.5
  Game.Energy=math.clamp(Game.Energy+(Dash and -35 or 18)*Delta,0,100)
  local Vertical=math.max(-35,W.Body.Velocity.Y-22*Delta)
  if Game.Command('Jump') and W.Scope:Call(W.Body,'IsOnFloor') then Vertical=7 end
  W.Body.Velocity=Vector3.new(X*Speed,Vertical,Z*Speed)
  W.Scope:Call(W.Body,'MoveAndSlide')
  if Game.Command('Fire') and Game.ShotClock==0 then
   Game.ShotClock=0.25
   W.Cast.TargetPosition=Game.Facing*8
   W.Scope:Call(W.Cast,'ForceUpdate')
   W.Scope:Call(W.Sound,'Play')
   if W.Scope:Call(W.Cast,'IsColliding') then
    local Hit=W.Scope:Call(W.Cast,'GetCollider',0)
    local Enemy=Hit and W.Guards[Hit.Name]
    if Enemy then
     Enemy.Health-=1
     if Enemy.Health<=0 then W.Guards[Hit.Name]=nil;Enemy.Body:Destroy();Game.Kills+=1 end
    end
   end
  end
  for _,Enemy in pairs(W.Guards) do
   if Enemies.Step(W.Scope,Enemy,W.Body.Position,Delta) and Game.DamageClock==0 then
    Game.Health=math.max(0,Game.Health-12);Game.DamageClock=0.6
   end
  end
  if W.Body.Position.Y < -5 then Game.Health=0 end
  if Game.Health==0 then Game.Phase='Dead';Game.Message='Expedition lost • start another attempt'
  elseif Game.Command('Interact') then
   if Game.Cells==3 and next(W.Guards)==nil and Art.Distance(W.Body.Position,W.Exit.Position)<2.2 then
    Progress.Complete(Game.Level,Game.Receipt)
    if Game.Level<3 then Game.Start(Game.Level+1)
    else Game.Phase='Complete';Game.Message='Foundry restored • check the persistence acknowledgment below' end
   else Game.Message='Gate needs 3 cells, no remaining guards, and a nearby explorer' end
  end
  local Fov=game:GetAttribute('FoundryFov')
  if Finite(Fov,55,90) then W.Camera.Fov=Fov end
  local Volume=game:GetAttribute('FoundryVolume')
  if Finite(Volume,-60,0) then W.Sound.VolumeDb=Volume end
 end
 if Game.Clock>=0.1 then Game.Clock=0;Game.Publish() end
end
function Game.Load()
 Progress.Load()
 Game.Phase='Menu'
 Game.Publish()
end
function Game.Close()
 local Waited=0
 while Progress.Busy and Waited<2 do task.wait(0.05);Waited+=0.05 end
 assert(not Progress.Busy,'Pending progress has not been acknowledged')
 Progress.Save()
 assert(not Progress.Dirty,'Progress save not acknowledged; retained previous commit')
end
return Game
