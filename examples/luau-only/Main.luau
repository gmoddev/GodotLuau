-- This exact entrypoint constructs editor preview and the independent game.
local Build = require("res://World.luau")
local Round = 1
local State
local function Restart(Advance)
    if State then State.Scope:Destroy() end
    if Advance then Round = Round % 2 + 1 end
    State = Build(Scene.new(script.Parent), Round)
    if __IS_CLIENT then
        State.Scope:Connect(State.Next, "Pressed", function() Restart(State.Collected == 3) end)
        State.Scope:Connect(State.Quit, "Pressed", function() game:Shutdown() end)
    end
end
Restart(false)
if not __IS_CLIENT then return end -- Preview never initializes gameplay services.

local Run = game:GetService("RunService")
local Input = game:GetService("InputService")
local Controls = Input:AddContext("OrbRun")
local Move = Controls:AddAction("Move", {ValueType = Enum.InputActionValueType.Vector2})
Move:BindKeyboardVector2()
Move:BindGamepadStick(Enum.InputStick.Left, {Device = -1})
local Jump = Controls:AddAction("Jump")
Jump:AddBinding(Enum.KeyCode.Space)
Jump:AddBinding(Enum.KeyCode.ButtonA, {Device = -1})
Jump.Pressed:Connect(function()
    if State.Body.Position.Y < 0.85 then State.Scope:Impulse(State.Body, Vector3.new(0, 4, 0)) end
end)
Run.Heartbeat:Connect(function(Delta)
    if State.Collected == 3 then return end
    local Value = Move:GetValue()
    State.Scope:Impulse(State.Body, Vector3.new(Value.X, 0, Value.Y) * math.min(Delta, 0.05) * 8)
    local Position = State.Body.Position
    if Position.Y < -5 then Restart(false); return end
    for Index, Marker in State.Markers do
        if Marker then
            local Difference = Position - Marker.Position
            if Difference.X * Difference.X + Difference.Z * Difference.Z < 0.9 then
                Marker:Destroy()
                State.Markers[Index] = false
                State.Collected += 1
                State.Scope:Play(State.Audio)
                State.Status.Text = string.format("Round %d • %d / 3 markers", Round, State.Collected)
            end
        end
    end
    if State.Collected == 3 then
        State.Status.Text = "Complete! Advance to the next native scene."
        State.Next.Text = "NEXT ROUND"
    end
end)
print("[OrbRun:Lifecycle] Ready")
