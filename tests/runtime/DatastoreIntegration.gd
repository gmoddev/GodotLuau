extends SceneTree
var Game: Node
var Failed := false
var Last := 0
var Gap := 0.0

func Script(Name: String, Source: String, Type: String="ServerScript") -> void:
    var NodeObject: Node=ClassDB.instantiate(Type)
    var Code: Script=ClassDB.instantiate("LuauScript")
    Code.source_code=Source
    NodeObject.name=Name
    NodeObject.call("set_codigo_luau",Code)
    Game.add_child(NodeObject)

func _process(_Delta: float) -> bool:
    var Now := Time.get_ticks_usec()
    if Last: Gap=maxf(Gap,float(Now-Last)/1000000.0)
    Last=Now
    return false

func _initialize() -> void:
    call_deferred("Run")

func Run() -> void:
    var Started := Time.get_ticks_msec()
    var Loaded := GDExtensionManager.load_extension("res://godot_luau.gdextension")
    if Loaded not in [GDExtensionManager.LOAD_STATUS_OK,GDExtensionManager.LOAD_STATUS_ALREADY_LOADED]: quit(2); return
    Game=Node.new(); Game.name="Game"; root.add_child(Game); current_scene=Game
    Script("Counter","local Store=game:GetService('DataStoreService'):GetDataStore('GL009'); game:BindToClose(function() Store:SetAsync('Close',99) end); while true do game:SetAttribute('Counter',(game:GetAttribute('Counter') or 0)+1); task.wait() end")
    Script("Client","assert(not pcall(function() game:GetService('DataStoreService'):GetDataStore('GL009'):SetAsync('Client',1) end)); game:SetAttribute('ClientDone',true)","LocalScript")
    Script("Store","""
local Store=game:GetService('DataStoreService'):GetDataStore('GL009')
assert(Store:GetAsync('Missing')==nil)
Store:SetAsync('Value',false)
assert(Store:GetAsync('Value')==false)
Store:SetAsync('Value',{Count=1})
assert(Store:GetAsync('Value').Count==1)
local Updated=Store:UpdateAsync('Value',function(Old) task.wait(.05); return {Count=Old.Count+1} end)
assert(Updated.Count==2)
assert(Store:UpdateAsync('Value',function(Old) Old.Count=77; return nil end)==nil)
assert(Store:GetAsync('Value').Count==2)
assert(not pcall(Store.UpdateAsync,Store,'Value',function() error('transform') end))
assert(Store:GetAsync('Value').Count==2)
assert(Store:RemoveAsync('Value').Count==2 and Store:GetAsync('Value')==nil)
assert(Store:IncrementAsync('Number')==1 and Store:IncrementAsync('Number',2)==3)
assert(not pcall(Store.IncrementAsync,Store,'Number',0/0))
assert(not pcall(Store.SetAsync,Store,'Value',function() end))
local Cycle={}; Cycle.Self=Cycle
assert(not pcall(Store.SetAsync,Store,'Value',Cycle))
assert(not pcall(Store.SetAsync,Store,'Value',nil))
Store:SetAsync('Limit',9007199254740991)
assert(not pcall(Store.IncrementAsync,Store,'Limit',1) and Store:GetAsync('Limit')==9007199254740991)
Store:SetAsync('Limit',false)
assert(not pcall(Store.IncrementAsync,Store,'Limit',1) and Store:GetAsync('Limit')==false)
local Attempts=0
Store:SetAsync('Conflict',0)
local Ok,Error=pcall(Store.UpdateAsync,Store,'Conflict',function(Old)
    Attempts+=1
    Store:SetAsync('Conflict',Old+1)
    return Old+2
end)
assert(not Ok and Error:find('Conflict retry limit',1,true) and Attempts==8 and Store:GetAsync('Conflict')==8)
local Ordered=game:GetService('DataStoreService'):GetOrderedDataStore('GL009')
Ordered:SetAsync('Rank',19)
assert(Ordered:GetSortedAsync(true,10):GetCurrentPage()[1].value==19)
assert(Ordered:ListVersionsAsync('Rank'):GetCurrentPage()[1].Version=='1')
assert(Ordered:GetVersionAsync('Rank','ignored')==19)
assert(Ordered:RemoveVersionAsync('Rank','ignored')==19)
local Scoped=game:GetService('DataStoreService'):GetDataStore('GL009Scope','alias')
Scoped:SetAsync('Key',17)
assert(game:GetService('DataStoreService'):GetDataStore('GL009Scope_alias'):GetAsync('Key')==17)
assert((game:GetAttribute('Counter') or 0)>5)
game:SetAttribute('Done',true)
""")
    var Deadline := Time.get_ticks_msec()+20000
    while (not Game.has_meta("Done") or not Game.has_meta("ClientDone")) and Time.get_ticks_msec()<Deadline: await process_frame
    if not Game.has_meta("Done") or not Game.has_meta("ClientDone"): Failed=true
    print("[Persistence:DataStore] Small-operation elapsed milliseconds=",Time.get_ticks_msec()-Started," peak frame gap=",Gap)
    if Gap>=0.25: Failed=true
    Gap=0.0; Started=Time.get_ticks_msec()
    Script("Large","""
local Store=game:GetService('DataStoreService'):GetDataStore('GL009')
local Payload=string.rep('x',4*1024*1024)
local Before=game:GetAttribute('Counter') or 0
Store:SetAsync('Large',Payload)
assert(Store:GetAsync('Large')==Payload)
assert(Store:RemoveAsync('Large')==Payload)
assert((game:GetAttribute('Counter') or 0)>Before)
game:SetAttribute('LargeDone',true)
""")
    Deadline=Time.get_ticks_msec()+20000
    while not Game.has_meta("LargeDone") and Time.get_ticks_msec()<Deadline: await process_frame
    if not Game.has_meta("LargeDone"): Failed=true
    print("[Persistence:DataStore] 4MiB set/get/remove elapsed milliseconds=",Time.get_ticks_msec()-Started," peak frame gap=",Gap)
    Game.queue_free(); await process_frame; await process_frame
    var File := FileAccess.open("user://ds_GL009_Close.json",FileAccess.READ)
    if File==null or File.get_as_text()!="99": Failed=true
    print("[Persistence:DataStore] ","FAIL" if Failed else "PASS"," prototype")
    quit(1 if Failed else 0)
