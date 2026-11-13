local Build = require("res://Shared/World2D.luau")
local Round, State = 1, nil
local function Restart(Advance)
    if State then State.Scope:Destroy() end
    if Advance then Round = Round % 2 + 1 end
    State = Build(Scene.new(script.Parent),Round)
    if not __IS_CLIENT then return end
    State.Scope:Call(State.Sprite,"Play","move")
    State.Scope:Connect(State.Next,"Pressed",function() Restart(State.Collected==3) end)
    for _, Token in State.Tokens do
        local Collected = false
        State.Scope:Connect(Token,"BodyEntered",function(Body)
            if Body~=State.Body or Collected then return end
            Collected = true
            Token:Destroy()
            State.Collected += 1
            State.Status.Text = string.format("Round %d • %d / 3 • reach the glowing markers",Round,State.Collected)
            State.Scope:Call(State.Audio,"Play")
            if State.Collected==3 then State.Next.Text="Next round" end
        end)
    end
end
Restart(false)
if not __IS_CLIENT then return end
local Controls = game:GetService("InputService"):AddContext("Foundation2D")
local Move = Controls:AddAction("Move",{ValueType=Enum.InputActionValueType.Vector2})
Move:BindKeyboardVector2()
Move:BindGamepadStick(Enum.InputStick.Left,{Device=-1})
local Jump = Controls:AddAction("Jump")
Jump:AddBinding(Enum.KeyCode.Space)
Jump:AddBinding(Enum.KeyCode.ButtonA,{Device=-1})
local JumpRequested = false
Jump.Pressed:Connect(function() JumpRequested=true end)
game:GetService("RunService").Stepped:Connect(function(Delta)
    local Vertical = math.min(State.Body.Velocity.Y + 600*math.min(Delta,0.05),600)
    if JumpRequested and State.Scope:Call(State.Body,"IsOnFloor") then Vertical=-280 end
    JumpRequested=false
    State.Body.Velocity=Vector2.new(Move:GetPhysicsValue().X*200,Vertical)
    State.Scope:Call(State.Body,"MoveAndSlide")
    if State.Body.Position.Y>800 then Restart(false) end
end)
print("[Foundation:2D] Ready")
