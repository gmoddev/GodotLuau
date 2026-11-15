local Scope=Scene.new(script.Parent)
Scope.Name='ReattachOldScope'
local Box=Scope:New('Node3D',{Name='OldBox'})
local Value=1 -- GL067:ReattachOld
game:SetAttribute('ReattachOldContinued',true)
while not game:GetAttribute('ReattachDone') do task.wait(0.02) end
