extends SceneTree

var Game: Node
var Role := "writer"
var Failed := false

func Check(Value: bool, Label: String) -> void:
    if not Value:
        Failed=true
        print("[Runtime:FilesystemTest] FAIL ",Role," ",Label)

func Mark(Name: String) -> void:
    var File := FileAccess.open("res://fs-"+Name,FileAccess.WRITE)
    File.store_string("ready")
    File.close()

func WaitFile(Name: String) -> void:
    var Deadline := Time.get_ticks_msec()+12000
    while not FileAccess.file_exists("res://fs-"+Name):
        if Time.get_ticks_msec()>=Deadline:
            Check(false,"barrier "+Name)
            quit(1)
            return
        await process_frame

func WaitMeta(Name: String) -> void:
    var Deadline := Time.get_ticks_msec()+12000
    while not Game.has_meta(Name):
        if Time.get_ticks_msec()>=Deadline:
            Check(false,"metadata "+Name)
            quit(1)
            return
        await process_frame

func Script(Source: String) -> void:
    var Object: Node = ClassDB.instantiate("ServerScript")
    var Resource: Script = ClassDB.instantiate("LuauScript")
    Resource.source_code=Source
    Object.call("set_codigo_luau",Resource)
    Game.add_child(Object)

func _initialize() -> void:
    var Args := OS.get_cmdline_user_args()
    for Index in range(Args.size()-1):
        if Args[Index]=="--filesystem-role": Role=Args[Index+1]
    call_deferred("Run")

func Run() -> void:
    var Loaded := GDExtensionManager.load_extension("res://godot_luau.gdextension")
    Check(Loaded in [GDExtensionManager.LOAD_STATUS_OK,GDExtensionManager.LOAD_STATUS_ALREADY_LOADED],"extension")
    Game=ClassDB.instantiate("RobloxTemplate")
    Game.name="Game"
    root.add_child(Game)
    current_scene=Game
    var Network: Node = ClassDB.instantiate("NetworkService")
    Network.name="NetworkService"
    Game.add_child(Network)
    for Index in range(4): await process_frame
    Check(int(Network.call("get_mode"))==1,"actual server process")
    if Role=="writer":
        Script("""
local Data=game:GetService('DataStoreService'):GetDataStore('GL003Cross')
local Ordered=game:GetService('DataStoreService'):GetOrderedDataStore('GL003Cross')
local Memory=game:GetService('MemoryStoreService'):GetSortedMap('GL003Cross')
local Messaging=game:GetService('MessagingService')
Data:SetAsync('Key',{Value=123})
Ordered:SetAsync('Rank',19)
Memory:SetAsync('Shared','writer',60)
game:SetAttribute('Prepared',true)
while not game:GetAttribute('HelloRequested') do
    Messaging:PublishAsync('GL003-shared','probe')
    task.wait(.2)
end
Messaging:PublishAsync('GL003-shared','hello')
game:SetAttribute('HelloPublished',true)
while not game:GetAttribute('ReadReturn') do task.wait(.1) end
assert(Memory:GetAsync('Return')=='reader')
game:SetAttribute('Returned',true)
""")
        await WaitMeta("Prepared")
        Mark("writer-ready")
        await WaitFile("reader-warm")
        Game.set_meta("HelloRequested",true)
        await WaitMeta("HelloPublished")
        await WaitFile("reader-done")
        Game.set_meta("ReadReturn",true)
        await WaitMeta("Returned")
        Mark("writer-done")
    else:
        await WaitFile("writer-ready")
        Script("""
local Data=game:GetService('DataStoreService'):GetDataStore('GL003Cross')
assert(Data:GetAsync('Key').Value==123)
local Ordered=game:GetService('DataStoreService'):GetOrderedDataStore('GL003Cross')
assert(Ordered:GetAsync('Rank')==19 and Ordered:GetSortedAsync(true,10):GetCurrentPage()[1].value==19)
local Memory=game:GetService('MemoryStoreService'):GetSortedMap('GL003Cross')
assert(Memory:GetAsync('Shared')=='writer')
Memory:SetAsync('Return','reader',60)
game:GetService('MessagingService'):SubscribeAsync('GL003-shared',function(Message)
    if Message.Data=='probe' then game:SetAttribute('Warm',true) end
    if Message.Data=='hello' then game:SetAttribute('Hello',true) end
end)
game:SetAttribute('Read',true)
""")
        await WaitMeta("Read")
        await WaitMeta("Warm")
        Mark("reader-warm")
        await WaitMeta("Hello")
        Script("local M=game:GetService('MemoryStoreService'):GetSortedMap('GL003Cross'); M:SetAsync('Expiring',17,1); assert(M:GetAsync('Expiring')==17); task.wait(2); assert(M:GetAsync('Expiring')==nil); game:SetAttribute('Expired',true)")
        await WaitMeta("Expired")
        Check(FileAccess.file_exists("user://ds_GL003Cross_Key.json"),"shared datastore filename")
        Check(FileAccess.file_exists("user://ds___ord_GL003Cross_Rank.json"),"shared ordered filename")
        Check(FileAccess.file_exists("user://mem_GL003Cross.json"),"shared memory filename")
        var Mailboxes := 0
        for Name in DirAccess.get_files_at("user://"):
            if Name.begins_with("msg_GL003-shared__"): Mailboxes+=1
        Check(Mailboxes==1,"own native sender mailbox")
        Mark("reader-done")
        await WaitFile("writer-done")
    Game.queue_free()
    await process_frame
    await process_frame
    print("[Runtime:FilesystemTest] ","FAIL" if Failed else "PASS"," ",Role)
    quit(1 if Failed else 0)
