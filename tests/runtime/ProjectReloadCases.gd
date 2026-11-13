extends RefCounted
## Real cached Luau project resources, transitive imports and selective reload.

func Write(Path: String, Source: String) -> void:
    var File := FileAccess.open(Path,FileAccess.WRITE)
    File.store_string(Source)
    File.close()

func Run(Runner, Game: Node) -> void:
    Write("res://ReloadLeaf.luau", "return {Value=1}")
    Write("res://ReloadParent.luau", "local Leaf=require('res://ReloadLeaf.luau'); shared.ReloadParentRuns=(shared.ReloadParentRuns or 0)+1; task.delay(0.5,function() game:SetAttribute('ReloadOldCallback',true) end); return {Leaf=Leaf}")
    Write("res://ReloadRoot.luau", "return {Parent=require('res://ReloadParent.luau')}")
    Write("res://ReloadOther.luau", "return {}")
    var Owner = Runner.CreateScript("ServerScript","ProjectReloadOwner","""
local Old=require('res://ReloadRoot.luau')
local Other=require('res://ReloadOther.luau')
game:SetAttribute('ReloadReady',true)
for Version=2,11 do
 while game:GetAttribute('ReloadRequested')~=Version do task.wait() end
 local Fresh=require('res://ReloadRoot.luau')
 assert(Fresh.Parent.Leaf.Value==Version and Old.Parent.Leaf.Value==1)
 assert(require('res://ReloadOther.luau')==Other and shared.ReloadParentRuns==Version)
 game:SetAttribute('ReloadObserved',Version)
end
""",Game)
    if not await Runner.Until("ReloadReady"):
        return
    var Leaf: Script = ResourceLoader.load("res://ReloadLeaf.luau","LuauScript")
    var Started := Time.get_ticks_usec()
    for Version in range(2,12):
        Leaf.source_code="return {Value=%d}" % Version
        Game.set_meta("ReloadRequested",Version)
        for Frame in range(120):
            if Game.get_meta("ReloadObserved",0)==Version:
                break
            await Runner.process_frame
        Runner.Check(Game.get_meta("ReloadObserved",0)==Version,"Project dependency reload %d replaces transitive cache" % Version)
    Leaf.source_code="return {Value=12}"
    await Runner.create_timer(0.6).timeout
    Runner.Check(not Game.has_meta("ReloadOldCallback"),"Project reload cancels callbacks from every dependent module generation")
    Owner.queue_free()
    print("[Authoring:Reload] PASS ",JSON.stringify({"Reloads":10,"Microseconds":Time.get_ticks_usec()-Started,"Graphical":false}))
