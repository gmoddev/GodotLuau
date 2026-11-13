local Scope = Scene.new(script.Parent)
local Box = Scope:New("Node3D", {Name = "JourneyBox"})
local Increment = 1
local function Add(Value)
    local Current = Value + Increment
    Current += 1
    return Current
end
local Result = Add(40) -- GL055:Entry
assert(Result == 42)
game:SetAttribute("JourneyResult", Result)
while true do task.wait() end
