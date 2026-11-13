local Value = 41
while not game:GetAttribute("NetworkReady") do task.wait() end
Value += 1 -- GL055:Network
game:SetAttribute("NetworkContinued", Value)
