extends SceneTree
## Controlled admission probe; not a representative production game.

func _initialize() -> void:
    call_deferred("Run")

func Run() -> void:
    var Arguments=OS.get_cmdline_user_args()
    var Requested=int(Arguments[0]) if Arguments.size()>0 else 65
    var Expected=int(Arguments[1]) if Arguments.size()>1 else Requested
    if Requested<1 or Requested>1024:
        quit(2)
        return
    var Loaded=GDExtensionManager.load_extension("res://godot_luau.gdextension")
    if Loaded!=GDExtensionManager.LOAD_STATUS_OK and Loaded!=GDExtensionManager.LOAD_STATUS_ALREADY_LOADED:
        quit(2)
        return
    DirAccess.make_dir_recursive_absolute("res://Capacity")
    for Index in range(1,Requested+1):
        var File=FileAccess.open("res://Capacity/Item%d.luau" % Index,FileAccess.WRITE)
        File.store_string("export type Item={Id:number,Price:number,Mass:number}\nlocal Item:Item={Id=%d,Price=%d,Mass=%d}\nreturn Item\n" % [Index,Index*7,Index%13+1])
        File.close()
    var Game=Node.new()
    Game.name="Game"
    root.add_child(Game)
    var Owner=ClassDB.instantiate("ServerScript")
    var Resource=ClassDB.instantiate("LuauScript")
    Resource.source_code="""
local Admitted=0
local Failure=''
for Index=1,%d do
 local Ok,Value=pcall(require,'res://Capacity/Item'..Index..'.luau')
 if not Ok then Failure=tostring(Value); break end
 assert(Value.Id==Index and Value.Price==Index*7 and Value.Mass==Index%%13+1)
 Admitted+=1
end
game:SetAttribute('CapacityAdmitted',Admitted)
game:SetAttribute('CapacityFailure',Failure)
game:SetAttribute('CapacityDone',true)
""" % Requested
    Owner.call("set_codigo_luau",Resource)
    Game.add_child(Owner)
    var Deadline=Time.get_ticks_msec()+15000
    while not Game.get_meta("CapacityDone",false) and Time.get_ticks_msec()<Deadline:
        await process_frame
    var Result={"Requested":Requested,"Admitted":Game.get_meta("CapacityAdmitted",0),"Failure":Game.get_meta("CapacityFailure","No completion"),"Completed":Game.get_meta("CapacityDone",false),"Synthetic":true}
    Result.Passed=Result.Completed and Result.Admitted==Expected
    var Output=FileAccess.open("res://module-capacity.json",FileAccess.WRITE)
    Output.store_string(JSON.stringify(Result));Output.close()
    print("[Runtime:ModuleCapacity] ","PASS " if Result.Passed else "FAIL ",JSON.stringify(Result))
    Game.queue_free()
    await process_frame
    quit(0 if Result.Passed else 1)
