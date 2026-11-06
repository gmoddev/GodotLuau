extends SceneTree

var Game: Node
var Failed := false

func Check(Value: bool, Label: String) -> void:
    if not Value:
        Failed = true
        print("[Runtime:FilesystemTest] FAIL ", Label)

func Script(Type: String, Name: String, Source: String, Parent: Node) -> Node:
    var Result: Node = ClassDB.instantiate(Type)
    var Resource: Script = ClassDB.instantiate("LuauScript")
    Resource.source_code = Source
    Result.name = Name
    Result.call("set_codigo_luau", Resource)
    Parent.add_child(Result)
    return Result

func Create(Type: String, Name: String, Parent: Node) -> Node:
    var Result: Node = ClassDB.instantiate(Type)
    Result.name = Name
    Parent.add_child(Result)
    return Result

func Assets() -> void:
    var ImageData := Image.create(2,2,false,Image.FORMAT_RGBA8)
    ImageData.fill(Color.RED)
    var Texture := ImageTexture.create_from_image(ImageData)
    Check(ResourceSaver.save(Texture,"res://protected/texture.tres")==OK,"prepare texture")
    var Wav := AudioStreamWAV.new()
    Wav.data=PackedByteArray([0,0,0,0])
    Check(ResourceSaver.save(Wav,"res://protected/sound.tres")==OK,"prepare sound")
    var Clip := Animation.new()
    Clip.length=1
    Check(ResourceSaver.save(Clip,"res://protected/animation.tres")==OK,"prepare animation")
    var Uid := ResourceUID.create_id()
    ResourceUID.add_id(Uid,"res://protected/texture.tres")
    Game.set_meta("TextureUID",ResourceUID.id_to_text(Uid))
    Game.set_meta("AbsoluteTexture",ProjectSettings.globalize_path("res://protected/texture.tres"))
    Game.set_meta("AbsoluteSound",ProjectSettings.globalize_path("res://protected/sound.tres"))
    Create("Players","Players",Game)
    var Character := Create("RobloxPlayer","LocalPlayer",Game)
    Character.set_process(false)
    Character.set_physics_process(false)
    if not Character.has_node("Humanoid"): Create("Humanoid","Humanoid",Character)
    for Name in ["Allowed","Absolute","Traversal"]:
        var Object := Create("AnimationObject","Clip"+Name,Game)
        Object.call("set_anim_name",Name)
        Object.call("set_animation_id", "res://protected/animation.tres" if Name=="Allowed" else ProjectSettings.globalize_path("res://protected/animation.tres") if Name=="Absolute" else "res://protected/../protected/animation.tres")
    Script("ServerScript","AssetProbe","""
local A=Instance.new('ImageLabel'); A.Name='AllowedImage'; A.Parent=game; A.Image='res://protected/texture.tres'
local U=Instance.new('ImageLabel'); U.Name='UidImage'; U.Parent=game; U.Image=game:GetAttribute('TextureUID')
local D=Instance.new('ImageLabel'); D.Name='DeniedImage'; D.Parent=game; D.Image=game:GetAttribute('AbsoluteTexture')
local S=Instance.new('Sound'); S.Name='AllowedSound'; S.Parent=game; S.SoundId='res://protected/sound.tres'
local X=Instance.new('Sound'); X.Name='DeniedSound'; X.Parent=game; X.SoundId=game:GetAttribute('AbsoluteSound')
for _,Name in {'Allowed','Absolute','Traversal'} do game.LocalPlayer.Humanoid:LoadAnimation(game['Clip'..Name]) end
game:SetAttribute('AssetsRan',true)
""",Game)
    for Index in range(5): await process_frame
    Check(bool(Game.get_meta("AssetsRan",false)),"asset paths reached native APIs")
    for Name in ["AllowedImage","UidImage"]:
        var Object := Game.get_node_or_null(Name)
        Check(Object!=null and Object.get("texture")!=null,Name)
    var DeniedImage := Game.get_node_or_null("DeniedImage")
    Check(DeniedImage!=null and DeniedImage.get("texture")==null,"absolute image denied")
    var AllowedSound := Game.get_node_or_null("AllowedSound/__player2d__")
    Check(AllowedSound!=null and AllowedSound.get("stream")!=null,"project sound allowed")
    Check(not Game.has_node("DeniedSound/__player2d__"),"absolute sound denied")
    var Animator := Character.get_node_or_null("AnimationPlayer") as AnimationPlayer
    Check(Animator!=null and Animator.has_animation("Allowed"),"project animation allowed")
    Check(Animator!=null and not Animator.has_animation("Absolute") and not Animator.has_animation("Traversal"),"external/traversal animation denied")
    print("[Runtime:FilesystemTest] Assets checked")

func _initialize() -> void:
    call_deferred("Run")

func Run() -> void:
    var Baseline := OS.get_cmdline_user_args().has("--baseline")
    var Loaded := GDExtensionManager.load_extension("res://godot_luau.gdextension")
    Check(Loaded in [GDExtensionManager.LOAD_STATUS_OK, GDExtensionManager.LOAD_STATUS_ALREADY_LOADED], "extension")
    Game = Node.new()
    Game.name = "Game"
    root.add_child(Game)
    current_scene = Game
    var Storage := Node.new()
    Storage.name = "ReplicatedStorage"
    Game.add_child(Storage)
    if not Baseline:
        var Network: Node = ClassDB.instantiate("NetworkService")
        Network.name = "NetworkService"
        Game.add_child(Network)
        var Editor: Node = ClassDB.instantiate("RobloxTemplate")
        Editor.name = "EditorProbe"
        Editor.set_meta("_gl_bridge", true) # host authorization never grants editor I/O to Lua
        Game.add_child(Editor)
        DirAccess.make_dir_recursive_absolute("user://")
        var Existing := FileAccess.open("user://ds_GL003_Existing.json", FileAccess.WRITE)
        Existing.store_string("17")
        Existing.close()
        var LegacyName := ""
        for Byte in "ds_GL003_雪_Existing.json".to_utf8_buffer(): LegacyName += String.chr(Byte)
        Existing = FileAccess.open("user://"+LegacyName, FileAccess.WRITE)
        Existing.store_string("17")
        Existing.close()
    DirAccess.make_dir_recursive_absolute("res://protected")
    var Path := ProjectSettings.globalize_path("res://protected/sentinel.txt")
    var File := FileAccess.open(Path, FileAccess.WRITE)
    File.store_string("sentinel")
    File.close()
    Game.set_meta("ProbePath", Path)
    Game.set_meta("ProbeDirectory", ProjectSettings.globalize_path("res://protected"))
    if not Baseline: await Assets()
    Script("ModuleScript", "Probe", "return function() return _FileAccess.read(game:GetAttribute('ProbePath')) end", Storage)
    var Source := """
local Path = game:GetAttribute('ProbePath')
assert(_FileAccess.exists(Path))
assert(_FileAccess.read(Path)=='sentinel')
shared.GL003Read=_FileAccess.read
assert(require(game.ReplicatedStorage.Probe)()=='sentinel')
local Files=_FileAccess.list(game:GetAttribute('ProbeDirectory'))
assert(#Files>=1)
_FileAccess.write(Path..'.copy','copy')
assert(_FileAccess.read(Path..'.copy')=='copy')
_FileAccess.delete(Path..'.copy')
assert(not _FileAccess.exists(Path..'.copy'))
game:SetAttribute(script.Name..'Passed',true)
game.ChildAdded:Connect(function(Child)
    if Child.Name=='CallbackProbe' then
        assert(_FileAccess.read(Path)=='sentinel')
        game:SetAttribute(script.Name..'Callback',true)
    end
end)
"""
    if not Baseline:
        Source = """
local Path=game:GetAttribute('ProbePath')
local function Denied(Function,...)
    local Ok,Error=pcall(Function,...)
    assert(not Ok and string.find(tostring(Error),'Runtime:'),tostring(Error))
end
local RawRead=_FileAccess.read
shared.GL003Read=RawRead
Denied(RawRead,Path)
Denied(_FileAccess.write,Path,'changed')
Denied(_FileAccess.write,Path..'.copy','created')
Denied(_FileAccess.exists,Path)
Denied(_FileAccess.delete,Path)
Denied(_FileAccess.list,game:GetAttribute('ProbeDirectory'))
Denied(require(game.ReplicatedStorage.Probe))
coroutine.wrap(function() Denied(RawRead,Path) end)()
task.defer(function() Denied(RawRead,Path); game:SetAttribute(script.Name..'Deferred',true) end)
assert(_ServiceStorage==nil)
local Data=game:GetService('DataStoreService')
assert(getfenv(Data.GetDataStore)._ServiceStorage==nil)
Denied(_GL_NET.call,'get_host_key')
Denied(_GL_NET.call,'read_or_make_host_key')
Denied(function() game:SetAttribute('_gl_bridge',true) end)
Denied(function() game.EditorProbe:UpdateStructure() end)
Denied(function() game.EditorProbe.Modo_Roblox_Studio=3 end)
local Memory=game:GetService('MemoryStoreService'):GetSortedMap('GL003')
if __IS_CLIENT then
    _GL_NET_ROLE=function() return 0 end
    assert(not pcall(function() Data:GetDataStore('GL003'):GetAsync('Existing') end))
    Denied(function() Memory:SetAsync('Key','bad',60) end)
    Denied(function() Memory:GetAsync('Key') end)
    game:SetAttribute('ClientServiceDenied',true)
else
    local Store=Data:GetDataStore('GL003')
    assert(Store:GetAsync('Existing')==17)
    Store:SetAsync('Key',{Value=42}); assert(Store:GetAsync('Key').Value==42)
    local Payload=string.rep('a',4*1024*1024)
    Store:SetAsync('Payload',Payload); assert(Store:GetAsync('Payload')==Payload); Store:RemoveAsync('Payload')
    local OldName=Store._name
    for _,Name in {'../outside','/absolute','C:drive','bad/name','bad'..string.char(0)..'name',string.char(255),string.rep('x',201)} do
        Store._name=Name
        Denied(function() Store:SetAsync('Key',99) end)
        assert(Store._cache.Key.Value==42)
    end
    Store._name=OldName
    local Unicode=Data:GetDataStore('GL003_雪')
    assert(Unicode:GetAsync('Existing')==17)
    Unicode:SetAsync('valid key','unicode'); assert(Unicode:GetAsync('valid key')=='unicode')
    local Ordered=Data:GetOrderedDataStore('GL003')
    Ordered:SetAsync('Rank',12)
    assert(Ordered:GetAsync('Rank')==12 and Ordered:GetSortedAsync(true,10):GetCurrentPage()[1].value==12)
    Memory:SetAsync('Key','memory',60); assert(Memory:GetAsync('Key')=='memory')
    Memory:RemoveAsync('Key'); assert(Memory:GetAsync('Key')==nil)
    assert(Store:RemoveAsync('Key').Value==42 and Store:GetAsync('Key')==nil)
    Data:GetDataStore('GL003 trailing. '):SetAsync('key. ',5)
    assert(Data:GetDataStore('GL003 trailing. '):GetAsync('key. ')==5)
end
local Messaging=game:GetService('MessagingService')
local Connection=Messaging:SubscribeAsync('GL003-local',function(Message)
    assert(Message.Data=='hello'); game:SetAttribute(script.Name..'Message',true)
end)
Messaging:PublishAsync('GL003-local','hello')
Denied(function() Messaging:PublishAsync('../outside','bad') end)
game:SetAttribute(script.Name..'Passed',true)
game.ChildAdded:Connect(function(Child)
    if Child.Name=='CallbackProbe' then
        Denied(RawRead,Path); game:SetAttribute(script.Name..'Callback',true)
    elseif Child.Name=='AfterDisable' then game:SetAttribute(script.Name..'RetiredCallbackRan',true) end
end)
"""
    Script("ServerScript", "Server", Source, Game)
    var ClientSource := Source
    if Baseline:
        ClientSource += "\nlocal Ok=pcall(function() game:GetService('DataStoreService'):GetDataStore('Probe'):GetAsync('Key') end); assert(not Ok); game:SetAttribute('ClientServiceDenied',true)"
    Script("LocalScript", "Client", ClientSource, Game)
    for Index in range(5): await process_frame
    var Trigger := Node.new()
    Trigger.name = "CallbackProbe"
    Game.add_child(Trigger)
    for Index in range(5): await process_frame
    for Name in ["ServerPassed", "ClientPassed", "ServerCallback", "ClientCallback", "ClientServiceDenied"]:
        Check(bool(Game.get_meta(Name, false)), Name)
    # Source replacement retires the old attempt and executes through the same
    # native boundary again; no real user paths are touched.
    var Server: Node = Game.get_node("Server")
    Server.call("set_enabled",false)
    Script("ServerScript","RetiredDelegate",("assert(shared.GL003Read(game:GetAttribute('ProbePath'))=='sentinel')" if Baseline else "assert(not pcall(shared.GL003Read,game:GetAttribute('ProbePath')))")+"; game:SetAttribute('RetiredDelegate',true)",Game)
    var Retired := Node.new()
    Retired.name = "AfterDisable"
    Game.add_child(Retired)
    for Index in range(3): await process_frame
    Check(not Game.has_meta("ServerRetiredCallbackRan"), "retired callback cancelled")
    Check(bool(Game.get_meta("RetiredDelegate",false)),"captured native reference after retirement")
    Server.get("codigo_luau").source_code = ("assert(_FileAccess.read(game:GetAttribute('ProbePath'))=='sentinel')" if Baseline else "assert(not pcall(_FileAccess.read,game:GetAttribute('ProbePath')))") + "; game:SetAttribute('ReloadPassed',true)"
    Server.call("set_enabled",true)
    for Index in range(5): await process_frame
    Check(bool(Game.get_meta("ReloadPassed", false)), "ReloadPassed")
    Check(FileAccess.get_file_as_string(Path)=="sentinel", "original retained")
    if not Baseline:
        for Name in ["ServerDeferred","ClientDeferred","ServerMessage","ClientMessage"]:
            Check(bool(Game.get_meta(Name,false)),Name)
        Check(not FileAccess.file_exists(Path+".copy"),"denied creation had no side effect")
        Check(FileAccess.file_exists("user://ds___ord_GL003_Rank.json"),"legacy ordered filename")
        var Mailboxes := 0
        for Name in DirAccess.get_files_at("user://"):
            if Name.begins_with("msg_GL003-local__"): Mailboxes += 1
        Check(Mailboxes==1,"only Server persisted its mailbox")
    Game.queue_free()
    await process_frame
    await process_frame
    if not Baseline:
        Game=Node.new()
        Game.name="Game"
        root.add_child(Game)
        current_scene=Game
        Script("ServerScript","Fresh","assert(not pcall(_FileAccess.read,'user://ds_GL003_Existing.json')); local Store=game:GetService('DataStoreService'):GetDataStore('GL003'); assert(Store:GetAsync('Existing')==17); game:BindToClose(function() assert(not pcall(_FileAccess.read,'user://ds_GL003_Existing.json')); Store:SetAsync('Close',99) end); game:SetAttribute('Fresh',true)",Game)
        for Index in range(5): await process_frame
        Check(bool(Game.get_meta("Fresh",false)),"fresh scene storage authority")
        Game.queue_free()
        await process_frame
        await process_frame
        Check(FileAccess.get_file_as_string("user://ds_GL003_Close.json")=="99","authorized final close save")
    print("[Runtime:FilesystemTest] ", "FAIL" if Failed else "PASS", " ", "baseline" if Baseline else "enforced")
    quit(1 if Failed else 0)
