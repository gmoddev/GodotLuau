local Interface=require('res://Shared/Interface.luau')
local Input=game:GetService('InputService')
local Run=game:GetService('RunService')
local Http=game:GetService('HttpService')
local Counts={}
local function Send(Name)
 Counts[Name]=(Counts[Name] or 0)+1
 game:SetAttribute('Foundry'..Name,Counts[Name])
end
local UI=Interface.Build(script.Parent,Send)
local Controls=Input:AddContext('FoundryGameplay',{Priority=5})
local Move=Controls:AddAction('Move',{ValueType=Enum.InputActionValueType.Vector2})
Move:BindKeyboardVector2()
Move:BindGamepadStick(Enum.InputStick.Left,{Device=-1})
local Jump=Controls:AddAction('Jump')
Jump:AddBinding(Enum.KeyCode.Space)
Jump:AddBinding(Enum.KeyCode.ButtonA,{Device=-1})
local Pulse=Controls:AddAction('Pulse')
Pulse:AddBinding(Enum.KeyCode.F)
Pulse:AddBinding(Enum.KeyCode.ButtonR1,{Device=-1})
local Interact=Controls:AddAction('Interact')
Interact:AddBinding(Enum.KeyCode.E)
Interact:AddBinding(Enum.KeyCode.ButtonX,{Device=-1})
local Dash=Controls:AddAction('Dash')
Dash:AddBinding(Enum.KeyCode.LeftShift)
Dash:AddBinding(Enum.KeyCode.ButtonL1,{Device=-1})
local Menu=Input:AddContext('FoundryMenu',{Priority=10})
local Pause=Menu:AddAction('Pause')
Pause:AddBinding(Enum.KeyCode.Escape)
Pause:AddBinding(Enum.KeyCode.ButtonStart,{Device=-1})
Jump.Pressed:Connect(function() Send('Jump') end)
Pulse.Pressed:Connect(function() Send('Fire') end)
Interact.Pressed:Connect(function() Send('Interact') end)
Pause.Pressed:Connect(function() Send('Pause') end)
local Active=false
local Encoded
Run.RenderStepped:Connect(function()
 local Next=game:GetAttribute('FoundrySnapshot')
 if type(Next)=='string' and Next~=Encoded then
  local OK,State=pcall(function() return Http:JSONDecode(Next) end)
  if OK and type(State)=='table' then
   Encoded=Next
   Active=State.Phase=='Active'
   UI.Update(State)
   Controls.Enabled=Active
  end
 end
end)
Run.Stepped:Connect(function()
 local Value=Move:GetPhysicsValue()
 game:SetAttribute('FoundryMoveX',Active and Value.X or 0)
 game:SetAttribute('FoundryMoveY',Active and Value.Y or 0)
 game:SetAttribute('FoundryDash',Active and Dash:GetPhysicsValue())
end)
game:SetAttribute('FoundryClientReady',true)
print('[Foundry:Client] Ready; native UI and semantic input only')
