extends SceneTree

var Game: Node
var Role := "A"
var Mode := "writers"
var Failed := false

func Check(Value: bool, Label: String) -> void:
    if not Value:
        Failed=true
        print("[Persistence:Baseline] FAIL ", Label)

func Mark(Name: String) -> void:
    var File := FileAccess.open("res://"+Name,FileAccess.WRITE)
    File.store_string("ready")
    File.close()

func Until(Name: String) -> void:
    var Deadline := Time.get_ticks_msec()+10000
    while not Game.has_meta(Name):
        if Time.get_ticks_msec()>=Deadline:
            Check(false,"metadata timeout "+Name)
            return
        await process_frame

func Script(Source: String) -> void:
    var Object: Node=ClassDB.instantiate("ServerScript")
    var Code: Script=ClassDB.instantiate("LuauScript")
    Code.source_code=Source
    Object.call("set_codigo_luau",Code)
    Game.add_child(Object)

func Write(Leaf: String, Data: String) -> void:
    var File := FileAccess.open("user://"+Leaf,FileAccess.WRITE)
    File.store_string(Data)
    File.close()

func _initialize() -> void:
    var Args := OS.get_cmdline_user_args()
    for Index in range(Args.size()-1):
        if Args[Index]=="--role": Role=Args[Index+1]
        if Args[Index]=="--mode": Mode=Args[Index+1]
    call_deferred("Run")

func Run() -> void:
    var Loaded := GDExtensionManager.load_extension("res://godot_luau.gdextension")
    Check(Loaded in [GDExtensionManager.LOAD_STATUS_OK,GDExtensionManager.LOAD_STATUS_ALREADY_LOADED],"extension load")
    Game=Node.new()
    Game.name="Game"
    root.add_child(Game)
    current_scene=Game
    if Mode=="writers":
        Script("""
local Store=game:GetService('DataStoreService'):GetDataStore('GL009')
local Result=Store:UpdateAsync('Counter',function(Old)
    assert(Old==0)
    game:SetAttribute('Observed',Old)
    while not game:GetAttribute('Release') do task.wait() end
    return Old+1
end)
assert(Result==1)
game:SetAttribute('Done',true)
""")
        await Until("Observed")
        Mark("observed-"+Role)
        var Deadline := Time.get_ticks_msec()+10000
        while not FileAccess.file_exists("res://release-"+Role) and Time.get_ticks_msec()<Deadline: await process_frame
        Check(FileAccess.file_exists("res://release-"+Role),"release barrier")
        Game.set_meta("Release",true)
        await Until("Done")
    elif Mode=="seed":
        Script("game:GetService('DataStoreService'):GetDataStore('GL009'):SetAsync('Counter',0); game:SetAttribute('Seeded',true)")
        await Until("Seeded")
    elif Mode=="verify":
        Script("assert(game:GetService('DataStoreService'):GetDataStore('GL009'):GetAsync('Counter')==1); game:SetAttribute('Verified',true)")
        await Until("Verified")
        print("[Persistence:Baseline] Two transforms observed0 and returned1; final committed value1 instead of2")
    else:
        Script("shared.Store=game:GetService('DataStoreService'):GetDataStore('GL009'); shared.Store:SetAsync('Cache',42); game:SetAttribute('Seeded',true)")
        await Until("Seeded")
        Check(DirAccess.remove_absolute(OS.get_user_data_dir()+"/ds_GL009_Cache.json")==OK,"remove backing file")
        Script("assert(shared.Store:GetAsync('Cache')==42); game:SetAttribute('Stale',true)")
        await Until("Stale")
        Write("ds_GL009_Cache.json","{")
        Script("assert(shared.Store:GetAsync('Cache')==nil); game:SetAttribute('Corrupt',true)")
        await Until("Corrupt")
        Write("ds_GL009_False.json","false")
        Write("ds_GL009_Remove.json","19")
        Script("assert(shared.Store:GetAsync('False')==nil); assert(shared.Store:RemoveAsync('Remove')==nil); game:SetAttribute('FalseAndRemove',true)")
        await Until("FalseAndRemove")
        Script("shared.Store:SetAsync('Blocked',7); game:SetAttribute('BlockedSeed',true)")
        await Until("BlockedSeed")
        Check(DirAccess.remove_absolute(OS.get_user_data_dir()+"/ds_GL009_Blocked.json")==OK,"replace backing file")
        Check(DirAccess.make_dir_absolute("user://ds_GL009_Blocked.json")==OK,"prepare invalid leaf")
        Script("assert(not pcall(shared.Store.SetAsync,shared.Store,'Blocked',99)); assert(shared.Store._cache.Blocked==7); assert(not pcall(shared.Store.GetAsync,shared.Store,'Blocked')); assert(not pcall(shared.Store.RemoveAsync,shared.Store,'Blocked')); game:SetAttribute('Failures',true)")
        await Until("Failures")
        print("[Persistence:Baseline] Missing returns stale42; corrupt/false return nil; fresh Remove returns nil; write/read/delete errors propagate")
    Game.queue_free()
    await process_frame
    await process_frame
    print("[Persistence:Baseline] ","FAIL" if Failed else "PASS"," ",Mode," ",Role)
    quit(1 if Failed else 0)
