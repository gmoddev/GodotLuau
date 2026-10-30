extends SceneTree
var Game: Node
var Failed := false
var Mode := "lifecycle"

func Check(Value: bool, Label: String) -> void:
    if not Value: Failed=true; print("[Persistence:Lifecycle] FAIL ",Label)

func Script(Name: String,Source: String,Type: String="ServerScript",Parent: Node=null) -> Node:
    var Object: Node=ClassDB.instantiate(Type)
    var Code: Script=ClassDB.instantiate("LuauScript")
    Code.source_code=Source; Object.name=Name; Object.call("set_codigo_luau",Code)
    (Game if Parent==null else Parent).add_child(Object)
    return Object

func Host() -> Node:
    for Child in Game.get_children():
        if Child.is_class("GLDomainHost"): return Child
    return null

func Stats() -> Dictionary:
    return Host().call("GetResourceStats",false)

func Until(Name: String) -> void:
    var Deadline := Time.get_ticks_msec()+10000
    while not Game.has_meta(Name) and Time.get_ticks_msec()<Deadline: await process_frame
    Check(Game.has_meta(Name),"timeout "+Name)

func Pending() -> void:
    var Deadline := Time.get_ticks_msec()+3000
    while int(Stats().DataStorePending)==0 and Time.get_ticks_msec()<Deadline: await process_frame
    Check(int(Stats().DataStorePending)==1,"pending admission")

func _initialize() -> void:
    Mode=OS.get_cmdline_user_args()[0]
    call_deferred("Run")

func Run() -> void:
    GDExtensionManager.load_extension("res://godot_luau.gdextension")
    if Mode=="memory": ProjectSettings.set_setting("godot_luau/server_limits/vm_memory_bytes",8*1024*1024)
    Game=Node.new(); Game.name="Game"; root.add_child(Game); current_scene=Game
    var Prefix := "local Store=game:GetService('DataStoreService'):GetDataStore('GL009'); "
    Script("Baseline","while true do task.wait() end")
    if Mode=="memory":
        Script("Exhaust",Prefix+"task.spawn(function() Store:GetAsync('Missing'); game:SetAttribute('Late',true) end); pcall(function() shared.Large=table.create(1024*1024) end)")
        await process_frame; await process_frame
        Check(Stats().MemoryFailed and Stats().References==0 and Stats().DataStorePending==0,"terminal OOM cancels persistence")
    else:
        Script("ManualResume",Prefix+"""
for _,Resume in {task.spawn,coroutine.resume} do
    local Done=false
    local Pending=task.spawn(function()
        local Ok,Error=pcall(Store.GetAsync,Store,'Missing')
        assert(not Ok and string.find(Error,'Request resumed outside completion',1,true))
        assert(Store:GetAsync('Missing')==nil)
        Done=true
    end)
    Resume(Pending,'forged')
    while not Done do task.wait() end
end
game:SetAttribute('ManualDone',true)
""")
        await Until("ManualDone")
        Script("TaskCancel",Prefix+"local Pending=task.spawn(function() Store:GetAsync('Missing'); game:SetAttribute('Late',true) end); task.cancel(Pending); game:SetAttribute('TaskDone',true)")
        await Until("TaskDone")
        var Owner := Script("Disabled",Prefix+"Store:GetAsync('Missing'); game:SetAttribute('Late',true)")
        await Pending()
        Check(Stats().DataStorePending==1,"owner admitted")
        Owner.call("set_enabled",false)
        Check(Stats().DataStorePending==0,"owner cancellation")
        Owner.get("codigo_luau").source_code=Prefix+"Store:SetAsync('Reload',17); game:SetAttribute('ReloadDone',true)"
        Owner.call("set_enabled",true)
        await Until("ReloadDone")
        var Storage := Node.new(); Storage.name="ReplicatedStorage"; Game.add_child(Storage)
        Script("Data",Prefix+"task.wait(.05); return {Value=Store:GetAsync('Reload')}","ModuleScript",Storage)
        var Caller := Script("Caller","require(game.ReplicatedStorage.Data); game:SetAttribute('Late',true)")
        Caller.call("set_enabled",false)
        Script("NextCaller","assert(require(game.ReplicatedStorage.Data).Value==17); game:SetAttribute('ModuleDone',true)")
        await Until("ModuleDone")
        Script("Admission",Prefix+"""
local A=task.spawn(function() Store:GetAsync('Missing'); game:SetAttribute('Late',true) end)
local B=task.spawn(function() Store:GetAsync('Missing'); game:SetAttribute('Late',true) end)
assert(not pcall(Store.GetAsync,Store,'Missing'))
task.cancel(A); task.cancel(B)
game:SetAttribute('AdmissionDone',true)
""")
        await Until("AdmissionDone")
        var Transform := Script("Transform",Prefix+"Store:UpdateAsync('Reload',function(Old) game:SetAttribute('TransformEntered',true); task.wait(60); return 99 end); game:SetAttribute('Late',true)")
        await Until("TransformEntered"); Transform.call("set_enabled",false)
        Script("Verify",Prefix+"assert(Store:GetAsync('Reload')==17); game:SetAttribute('Verified',true)")
        await Until("Verified")
        Script("PendingClose",Prefix+"Store:GetAsync('Missing'); game:SetAttribute('Late',true)")
        await Pending()
        Check(Stats().DataStorePending==1,"shutdown pending")
        var Runtime := Host(); Game.remove_child(Runtime)
        var Closed: Dictionary=Runtime.call("GetResourceStats",false)
        Check(Closed.Closing and Closed.References==0 and Closed.DataStorePending==0,"shutdown cleanup")
        Runtime.free()
    Check(not Game.has_meta("Late"),"stale completion")
    Game.queue_free(); await process_frame; await process_frame
    print("[Persistence:Lifecycle] ","FAIL" if Failed else "PASS"," ",Mode)
    quit(1 if Failed else 0)
