local Build=require("res://Shared/World3D.luau")
local Round,State=1,nil
local function Restart(Advance)
    if State then State.Scope:Destroy() end
    if Advance then Round=Round%2+1 end
    State=Build(Scene.new(script.Parent),Round)
    if not __IS_CLIENT then return end
    State.Scope:Call(State.Material,"SetShaderParameter","Tint",Scene.Value("Color",{R=0.2,G=0.7,B=0.95,A=1}))
    State.Scope:Call(State.Animator,"Play","idle")
    State.Scope:Connect(State.Next,"Pressed",function() Restart(State.Collected==3) end)
end
Restart(false)
if not __IS_CLIENT then return end
local Controls=game:GetService("InputService"):AddContext("Foundation3D")
local Move=Controls:AddAction("Move",{ValueType=Enum.InputActionValueType.Vector2})
Move:BindKeyboardVector2()
Move:BindGamepadStick(Enum.InputStick.Left,{Device=-1})
local Jump=Controls:AddAction("Jump")
Jump:AddBinding(Enum.KeyCode.Space)
Jump:AddBinding(Enum.KeyCode.ButtonA,{Device=-1})
local JumpRequested=false
Jump.Pressed:Connect(function() JumpRequested=true end)
local function NextPath() return State.Scope:Call(State.Agent,"GetNextPathPosition") end
game:GetService("RunService").Stepped:Connect(function(Delta)
    local Value=Move:GetPhysicsValue()
    local Vertical=math.max(State.Body.Velocity.Y-20*math.min(Delta,0.05),-40)
    if JumpRequested and State.Scope:Call(State.Body,"IsOnFloor") then Vertical=7 end
    JumpRequested=false
    State.Body.Velocity=Vector3.new(Value.X*5,Vertical,Value.Y*5)
    State.Scope:Call(State.Body,"MoveAndSlide")
    local Ready,Next=pcall(NextPath)
    if Ready then
        local Difference=Next-State.Guide.Position
        local Length=math.sqrt(Difference.X^2+Difference.Z^2)
        State.Guide.Velocity=Vector3.new(Length>0.1 and Difference.X/Length*2 or 0,math.max(State.Guide.Velocity.Y-20*math.min(Delta,0.05),-40),Length>0.1 and Difference.Z/Length*2 or 0)
        State.Scope:Call(State.Guide,"MoveAndSlide")
        if State.Scope:Call(State.Agent,"IsNavigationFinished") then State.Agent.TargetPosition=Vector3.new(State.Guide.Position.X>0 and -3 or 3,0,-3) end
    end
    if State.Body.Position.Y < -5 then Restart(false);return end
    for Index,Token in State.Tokens do
        if Token then
            local Difference=State.Body.Position-Token.Position
            if Difference.X^2+Difference.Z^2<0.8 then
                Token:Destroy();State.Tokens[Index]=false;State.Collected+=1
                State.Scope:Call(State.Audio,"Play")
                State.Status.Text=string.format("Round %d • %d / 3 • follow the patrolling guide",Round,State.Collected)
                if State.Collected==3 then State.Next.Text="Next round" end
            end
        end
    end
end)
print("[Foundation:3D] Ready")
