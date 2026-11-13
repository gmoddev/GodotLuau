extends RefCounted
## Shared ancestor writes must obey the existing descendant-scope ownership.
func Run(Runner,Game: Node) -> void:
    var Bootstrap := Node3D.new()
    Bootstrap.name='AncestorBootstrap'
    Game.add_child(Bootstrap)
    Runner.CreateScript('ServerScript','AncestorOwner',"""
local S=Scene.new(script.Parent)
S.Name='ServerScope'
S:New('Node3D',{Name='Target',Position=Vector3.new(1,0,0)})
script.Parent.Position=Vector3.new(2,0,0)
assert(script.Parent.Position.X==2)
game:SetAttribute('AncestorOwnerReady',true)
""",Bootstrap)
    if not await Runner.Until('AncestorOwnerReady'):return
    var Target=Bootstrap.get_node('ServerScope/Target') as Node3D
    var Before=Target.global_transform
    Runner.CreateScript('LocalScript','AncestorGuest',"""
local R=script.Parent
local S=Scene.new(R)
S.Name='ClientScope'
local Attempts={
 function() R.Position=Vector3.new(123,0,0) end,
 function() R.Rotation=Vector3.new(0,90,0) end,
 function() R.CFrame=CFrame.new(123,0,0) end,
 function() R.position=Vector3.new(123,0,0) end,
 function() R.Name='MovedRoot' end,
}
for _,Attempt in ipairs(Attempts) do assert(not pcall(Attempt)) end
R:SetAttribute('ApplicationChannel',54)
assert(R:GetAttribute('ApplicationChannel')==54)
game:SetAttribute('AncestorGuestRejected',true)
""",Bootstrap)
    await Runner.Until('AncestorGuestRejected')
    Runner.Check(Target.global_transform==Before and Bootstrap.name=='AncestorBootstrap' and not Bootstrap.has_meta('position'),'Wrong-owner ancestor aliases reject before changing the native descendant or metadata')
    Runner.Check(Bootstrap.get_meta('ApplicationChannel',0)==54,'Explicit shared application attributes remain supported')
    Bootstrap.queue_free()
    await Runner.process_frame
    await Runner.process_frame
    Runner.Check(not is_instance_valid(Target),'Ancestor subtree destruction retires its independent owners and native targets')
    print('[Runtime:NativeAncestor] PASS')
