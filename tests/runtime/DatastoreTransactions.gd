extends SceneTree
var Game: Node
var Mode := "update"
var Role := "A"
var Expected := 2
var Failed := false

func Check(Value: bool, Label: String) -> void:
    if not Value: Failed=true; print("[Persistence:Transactions] FAIL ",Label)

func Script(Source: String) -> Node:
    var Object: Node=ClassDB.instantiate("ServerScript")
    var Code: Script=ClassDB.instantiate("LuauScript")
    Code.source_code=Source; Object.call("set_codigo_luau",Code); Game.add_child(Object)
    return Object

func Until(Name: String) -> void:
    var Deadline := Time.get_ticks_msec()+25000
    while not Game.has_meta(Name) and Time.get_ticks_msec()<Deadline: await process_frame
    Check(Game.has_meta(Name),"timeout "+Name)

func Mark(Name: String) -> void:
    var File := FileAccess.open("res://"+Name,FileAccess.WRITE)
    File.store_string("ready"); File.close()

func Write(Key: String,Value: String) -> void:
    var File := FileAccess.open("user://ds_GL009_"+Key+".json",FileAccess.WRITE)
    File.store_string(Value); File.close()

func _initialize() -> void:
    var Args := OS.get_cmdline_user_args()
    for Index in range(Args.size()-1):
        if Args[Index]=="--mode": Mode=Args[Index+1]
        if Args[Index]=="--role": Role=Args[Index+1]
        if Args[Index]=="--expected": Expected=int(Args[Index+1])
    call_deferred("Run")

func Run() -> void:
    var Loaded := GDExtensionManager.load_extension("res://godot_luau.gdextension")
    Check(Loaded in [GDExtensionManager.LOAD_STATUS_OK,GDExtensionManager.LOAD_STATUS_ALREADY_LOADED],"load")
    Game=Node.new(); Game.name="Game"; root.add_child(Game); current_scene=Game
    var Prefix := "local Store=game:GetService('DataStoreService'):GetDataStore('GL009'); "
    if Mode in ["unavailable","incompatible"]:
        Write("Sentinel","123")
        Script(Prefix+"assert(not pcall(Store.GetAsync,Store,'Sentinel')); assert(not pcall(Store.SetAsync,Store,'Sentinel',999)); game:SetAttribute('Done',true)")
        await Until("Done")
        Check(FileAccess.get_file_as_string("user://ds_GL009_Sentinel.json")=="123","helper failure retains committed sentinel")
    elif Mode=="contention":
        var Location := FileAccess.open("res://root.txt",FileAccess.WRITE)
        Location.store_string(OS.get_user_data_dir()); Location.close()
        var Deadline := Time.get_ticks_msec()+10000
        while not FileAccess.file_exists("res://locked.marker") and Time.get_ticks_msec()<Deadline: await process_frame
        Check(FileAccess.file_exists("res://locked.marker"),"native lock held")
        Script(Prefix+"local Start=os.clock(); local Ok,Error=pcall(Store.GetAsync,Store,'Missing'); assert(not Ok and Error:find('Lock contention',1,true)); assert(os.clock()-Start>=.8 and os.clock()-Start<3); game:SetAttribute('Done',true)")
        var Frames := 0
        while not Game.has_meta("Done") and Frames<3000: Frames+=1; await process_frame
        Check(Frames>10,"frames progress during lock contention")
    elif Mode=="seed":
        Script(Prefix+"Store:SetAsync('Counter',0); game:SetAttribute('Done',true)")
    elif Mode=="verify":
        Script(Prefix+"assert(Store:GetAsync('Counter')=="+str(Expected)+"); game:SetAttribute('Done',true)")
    elif Mode=="increment":
        Script(Prefix+"for I=1,20 do Store:IncrementAsync('Counter') end; game:SetAttribute('Done',true)")
    elif Mode in ["update","set","remove"]:
        if Role=="A" and Mode!="update":
            var Action := "Store:SetAsync('Counter',99)" if Mode=="set" else "assert(Store:RemoveAsync('Counter')==0)"
            Script(Prefix+"assert(Store:GetAsync('Counter')==0); game:SetAttribute('Observed',true); while not game:GetAttribute('Release') do task.wait() end; "+Action+"; game:SetAttribute('Done',true)")
        else:
            Script(Prefix+"""
local Calls=0
local Value=Store:UpdateAsync('Counter',function(Old)
    Calls+=1
    if Calls==1 then
        assert(Old==0)
        game:SetAttribute('Observed',true)
        while not game:GetAttribute('Release') do task.wait() end
    end
    return (Old or 0)+1
end)
game:SetAttribute('Value',Value)
game:SetAttribute('Calls',Calls)
game:SetAttribute('Done',true)
""")
        await Until("Observed"); Mark("observed-"+Role)
        var Deadline := Time.get_ticks_msec()+20000
        while not FileAccess.file_exists("res://release-"+Role) and Time.get_ticks_msec()<Deadline: await process_frame
        Check(FileAccess.file_exists("res://release-"+Role),"release barrier")
        Game.set_meta("Release",true)
        await Until("Done")
        if Role=="B":
            Check(Game.get_meta("Calls",0)==2,"transform repeats after conflict")
            Check(Game.get_meta("Value",0)==Expected,"retry uses latest committed value")
    elif Mode=="failures":
        Script(Prefix+"shared.Store=Store; Store:SetAsync('Cache',42); game:SetAttribute('Seeded',true)")
        await Until("Seeded")
        Check(DirAccess.remove_absolute(OS.get_user_data_dir()+"/ds_GL009_Cache.json")==OK,"delete cached backing")
        Script("assert(shared.Store:GetAsync('Cache')==nil and shared.Store._cache.Cache==nil); game:SetAttribute('Missing',true)")
        await Until("Missing")
        Write("Cache","{")
        Script("assert(not pcall(shared.Store.GetAsync,shared.Store,'Cache')); game:SetAttribute('Corrupt',true)")
        await Until("Corrupt")
        Write("Legacy","\ufeff{\"Value\":19}")
        Write("False","false")
        Write("Remove","19")
        Write("Depth","[".repeat(50)+"0"+"]".repeat(50))
        Write("Nodes","["+"0,".repeat(65536)+"0]")
        Write("Nul","\"\\u0000\"")
        Script("assert(shared.Store:GetAsync('Legacy').Value==19); assert(shared.Store:GetAsync('False')==false); assert(shared.Store:RemoveAsync('Remove')==19); game:SetAttribute('Legacy',true)")
        await Until("Legacy")
        Script("for _,Key in {'Depth','Nodes','Nul'} do assert(not pcall(shared.Store.GetAsync,shared.Store,Key)) end; game:SetAttribute('Bounds',true)")
        await Until("Bounds")
        Write("Blocked","7")
        Check(DirAccess.remove_absolute(OS.get_user_data_dir()+"/ds_GL009_Blocked.json")==OK,"replace file")
        Check(DirAccess.make_dir_absolute("user://ds_GL009_Blocked.json")==OK,"invalid leaf")
        Script("assert(not pcall(shared.Store.SetAsync,shared.Store,'Blocked',99)); assert(not pcall(shared.Store.GetAsync,shared.Store,'Blocked')); assert(not pcall(shared.Store.RemoveAsync,shared.Store,'Blocked')); game:SetAttribute('Done',true)")
    await Until("Done")
    Game.queue_free(); await process_frame; await process_frame
    print("[Persistence:Transactions] ","FAIL" if Failed else "PASS"," ",Mode," ",Role)
    quit(1 if Failed else 0)
