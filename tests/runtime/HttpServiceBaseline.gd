extends SceneTree

func _initialize() -> void:
    call_deferred("Run")

func Run() -> void:
    var Args := OS.get_cmdline_user_args()
    var Origin := Args[Args.find("--origin") + 1]
    var Denied := Args[Args.find("--denied") + 1]
    var Enabled := not "--unavailable" in Args
    ProjectSettings.set_setting("godot_luau/http/enabled", Enabled)
    ProjectSettings.set_setting("godot_luau/http/allowed_origins", PackedStringArray([Origin]))
    GDExtensionManager.load_extension("res://godot_luau.gdextension")
    var Game := Node.new()
    Game.name = "Game"
    root.add_child(Game)
    current_scene = Game
    Game.set_meta("Origin", Origin)
    Game.set_meta("Denied", Denied)
    Game.set_meta("Enabled", Enabled)
    for Type in ["ServerScript", "LocalScript"]:
        var Executable: Node = ClassDB.instantiate(Type)
        Executable.name = Type
        var Resource: Script = ClassDB.instantiate("LuauScript")
        Resource.source_code = """
local H=game:GetService('HttpService')
local Seen={}
Seen.HttpEnabled=H.HttpEnabled
Seen.MalformedBecomesTable=type(H:JSONDecode('not-json'))=='table'
Seen.NullBecomesTable=type(H:JSONDecode('null'))=='table'
Seen.FunctionBecomesNull=H:JSONEncode(function() end)=='null'
Seen.DefaultGuidHasBraces=H:GenerateGUID():sub(1,1)=='{'
Seen.NumericUrlCoercion=H:UrlEncode(123)=='123'
Seen.Utf8Url=H:UrlEncode(utf8.char(0x96ea)..' /%')=='%E9%9B%AA%20%2F%25'
Seen.NulUrl=H:UrlEncode('a'..string.char(0)..'b')=='a%00b'
if script.Name=='ServerScript' and game:GetAttribute('Enabled') then
    local Origin=game:GetAttribute('Origin')
    Seen.EmptySuccess=H:GetAsync(Origin..'/no-content')==''
    Seen.DeniedAlsoEmpty=H:GetAsync(game:GetAttribute('Denied')..'/forbidden/baseline')==''
    local Response=H:RequestAsync({Url=Origin..'/ok'})
    Seen.ResponseHeadersLost=next(Response.Headers)==nil
    local Status=H:RequestAsync({Url=Origin..'/status'})
    Seen.Non2xxStatusPreserved=not Status.Success and Status.StatusCode==418 and Status.Body=='teapot'
    Seen.Non2xxGetReturnsBody=H:GetAsync(Origin..'/status')=='teapot'
end
for Key,Value in Seen do game:SetAttribute(script.Name..Key,Value) end
game:SetAttribute(script.Name..'Done',true)
"""
        Executable.call("set_codigo_luau", Resource)
        Game.add_child(Executable)
    var Deadline := Time.get_ticks_msec() + 10000
    while not (Game.get_meta("ServerScriptDone", false) and Game.get_meta("LocalScriptDone", false)) and Time.get_ticks_msec() < Deadline:
        await process_frame
    var Complete: bool = Game.get_meta("ServerScriptDone", false) and Game.get_meta("LocalScriptDone", false)
    var Observations := {}
    for Key in Game.get_meta_list(): Observations[Key] = Game.get_meta(Key)
    print("[Runtime:HttpServiceBaseline] ", JSON.stringify(Observations))
    Game.free()
    await process_frame
    print("[Runtime:HttpServiceBaseline] ", "PASS" if Complete else "FAIL")
    quit(0 if Complete else 1)
