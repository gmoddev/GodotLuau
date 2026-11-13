local Expedition=require('res://Shared/Game.luau')
Expedition.Parent=script.Parent
game:GetService('RunService').Stepped:Connect(Expedition.Step)
game:BindToClose(Expedition.Close)
task.spawn(Expedition.Load)
game:SetAttribute('FoundryServerReady',true)
print('[Foundry:Server] Ready; solo rules own physics health rewards and persistence')
