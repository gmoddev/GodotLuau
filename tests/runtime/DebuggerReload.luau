local Scope = Scene.new(script.Parent)
local Box = Scope:New("Node3D", {Name = "OldDebugBox"})
local Button = Scope:New("Button", {Name = "OldDebugButton"})
Scope:Connect(Button, "Pressed", function() game:SetAttribute("ReloadOldSignal", true) end)
game:SetAttribute("ReloadPrimed", true)
while not game:GetAttribute("ReloadObserved") do task.wait() end
task.delay(0.5, function() game:SetAttribute("ReloadOldTimer", true) end)
local Value = 1
Value += 1 -- GL055:ReloadOld
game:SetAttribute("ReloadOldResumed", true)
while true do task.wait() end
