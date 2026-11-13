local Scope = Scene.new(script.Parent)
local Box = Scope:New("Node3D", {Name = "DebugBox"})
local Material = Scope:New("StandardMaterial3D", {Color = Color3.new(0.2, 0.5, 0.8)})
local Increment = 1
local State = {Answer = 40, Password = "GL055-Secret-Sentinel"}
State.Cycle = State
local function Add(Value)
    local Current = Value + Increment -- GL055:Into
    Current += 1 -- GL055:Over
    return Current
end
local Result = Add(State.Answer) -- GL055:Entry
assert(Result == 42) -- GL055:Out
local Module = require("res://DebuggerModule.luau")
assert(Module.Value == 9)
local Button = Scope:New("Button", {Name = "DebugButton"})
Scope:Connect(Button, "Pressed", function()
    local CallbackValue = Result -- GL055:Callback
    game:SetAttribute("CallbackDone", CallbackValue)
end)
game:SetAttribute("DebuggerReady", true)
while not game:GetAttribute("CallbackDone") do task.wait() end
Box:Destroy()
task.wait()
local Missing = Box
assert(Material ~= nil and Missing ~= nil) -- GL055:Stale
game:SetAttribute("DebuggerDone", Result)
