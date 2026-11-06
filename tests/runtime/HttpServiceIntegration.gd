extends SceneTree

var Game: Node
var Failed := false
var LastFrame := 0
var PeakGap := 0.0

func Check(Value: bool, Label: String) -> void:
    if not Value:
        Failed = true
        print("[Runtime:HttpServiceTest] FAIL ", Label)

func _initialize() -> void:
    call_deferred("Run")

func _process(_Delta: float) -> bool:
    var Now := Time.get_ticks_usec()
    if LastFrame: PeakGap = maxf(PeakGap, float(Now - LastFrame) / 1000000.0)
    LastFrame = Now
    return false

func Script(Name: String, Source: String, Client := false) -> Node:
    var Result: Node = ClassDB.instantiate("LocalScript" if Client else "ServerScript")
    Result.name = Name
    var Resource: Script = ClassDB.instantiate("LuauScript")
    Resource.source_code = Source
    Result.call("set_codigo_luau", Resource)
    Game.add_child(Result)
    return Result

func Until(Name: String, Timeout := 10000) -> void:
    var Deadline := Time.get_ticks_msec() + Timeout
    while not Game.get_meta(Name, false) and Time.get_ticks_msec() < Deadline: await process_frame
    Check(bool(Game.get_meta(Name, false)), "completion " + Name)

func Stats(Client := false) -> Dictionary:
    return Game.get_node("GodotLuauRuntime").call("GetResourceStats", Client)

func Pending(Count: int) -> void:
    var Deadline := Time.get_ticks_msec() + 5000
    while int(Stats().get("HttpPending", 0)) != Count and Time.get_ticks_msec() < Deadline: await process_frame
    Check(int(Stats().get("HttpPending", 0)) == Count, "native pending count")

func Api() -> void:
    Script("Api", """
local H=game:GetService('HttpService'); local O=game:GetAttribute('Origin')
assert(H.HttpEnabled and not pcall(function() H.HttpEnabled=false end))
assert(not pcall(rawset,H,'HttpEnabled',true) and getmetatable(H)=='HttpService')
_HTTP.enabled=function() return false end; assert(H.HttpEnabled)
assert(H:GetAsync(O..'/ok')=='ok' and H:GetAsync(O..'/no-content')=='')
assert(H:PostAsync(O..'/echo','POST')=='POST')
local Binary='utf8 '..utf8.char(0x96ea)..string.char(0,255)
assert(H:PostAsync(O..'/echo',Binary,'application/octet-stream',false)==Binary)
for _,Method in {'GET','POST','PUT','PATCH','DELETE','HEAD','OPTIONS'} do
    local R=H:RequestAsync({Url=O..'/method',Method=Method})
    assert(R.Success and R.StatusCode==200 and R.Body==(Method=='HEAD' and '' or Method))
end
local R=H:RequestAsync({Url=O..'/response-headers'})
assert(R.Success and R.StatusMessage=='Fixture Success' and R.Headers['x-mixed-case']=='first, second')
assert(R.Headers['X-Mixed-Case']==nil and #R.HeaderValues['x-mixed-case']==2)
assert(R.HeaderValues['x-mixed-case'][1]=='first' and R.HeaderValues['x-mixed-case'][2]=='second')
assert(R.Headers['x-empty']=='' and #R.HeaderValues['set-cookie']==2 and R.HeaderValues['set-cookie'][2]=='b=2')
assert(R.Headers['set-cookie']==R.HeaderValues['set-cookie'][1])
local Status=H:RequestAsync({Url=O..'/status'})
assert(not Status.Success and Status.StatusCode==418 and Status.StatusMessage=="I'm a Teapot" and Status.Body=='teapot' and Status.Headers['content-length']=='6')
for _,Call in {function() H:GetAsync(O..'/status') end,function() H:PostAsync(O..'/status','x') end} do
    local OK,Error=pcall(Call); assert(not OK and Error:find('418',1,true))
end
for _,Path in {'/truncated','/header-overflow','/response-header-count','/response-header-name','/response-folded'} do
    assert(not pcall(H.RequestAsync,H,{Url=O..Path}),Path)
end
local OK,Error=pcall(H.GetAsync,H,game:GetAttribute('DeniedOrigin')..'/forbidden/PrivateSentinel')
assert(not OK and Error:find('Origin denied',1,true) and not Error:find('PrivateSentinel',1,true))
assert(not pcall(H.RequestAsync,H,{Url=game:GetAttribute('RefusedOrigin')..'/refused'}))
local Before=game:GetAttribute('Counter') or 0
assert(H:GetAsync(O..'/slow')=='slow' and (game:GetAttribute('Counter') or 0)>Before+5)
local Headers={X='value'}; local Inspect=H:JSONDecode(H:GetAsync(O..'/inspect',true,Headers))
assert(Inspect.CacheControl=='no-cache' and Inspect.Pragma=='no-cache' and Headers['Cache-Control']==nil)
local Types={'application/json','application/xml','application/x-www-form-urlencoded','text/plain','text/xml'}
for I,Mime in Types do
    Inspect=H:JSONDecode(H:PostAsync(O..'/inspect','text',I-1,false))
    assert(Inspect.ContentType==Mime and Inspect.Body=='text')
end
Inspect=H:JSONDecode(H:PostAsync(O..'/inspect','text','text/plain',false))
assert(Inspect.ContentType=='text/plain')
for _,Options in {{Url=O..'/forbidden/options',Timeout=1},{Url=O..'/forbidden/options',Compress=1},{Url=O..'/forbidden/options',Unknown=true},{Url=O..'/forbidden/options',Body=''},
    {Url=O..'/forbidden/options',Headers=false},{Url=O..'/forbidden/options',Method='CONNECT'}} do assert(not pcall(H.RequestAsync,H,Options)) end
assert(not pcall(H.PostAsync,H,O..'/forbidden/compress','x',0,true))
assert(not pcall(H.PostAsync,H,O..'/forbidden/content','x',99,false))
assert(not pcall(H.PostAsync,H,O..'/forbidden/content','x',0,false,{['content-type']='text/plain'}))
assert(not pcall(H.GetAsync,H,O..'/forbidden/cache','true'))
assert(not pcall(H.GetAsync,H,O..'/forbidden/cache',true,{['Cache-Control']='public'}))
assert(H:RequestAsync({Url=O..'/ok',Compress=Enum.HttpCompression.None}).Success)
game:SetAttribute('ApiDone',true)
""")
    await Until("ApiDone")

func Denied() -> void:
    for Client in [false, true]:
        Script("DeniedClient" if Client else "DeniedServer", """
local H=game:GetService('HttpService')
assert(not H.HttpEnabled and not pcall(function() H.HttpEnabled=true end))
assert(not pcall(rawset,H,'HttpEnabled',true))
_HTTP.enabled=function() return true end; assert(not H.HttpEnabled)
assert(not pcall(H.GetAsync,H,game:GetAttribute('Origin')..'/forbidden/default'))
assert(not pcall(H.PostAsync,H,game:GetAttribute('Origin')..'/forbidden/default','data'))
assert(not pcall(H.RequestAsync,H,{Url=game:GetAttribute('Origin')..'/forbidden/default'}))
assert(type(H:GenerateGUID())=='string' and H:JSONDecode('{"OK":true}').OK)
game:SetAttribute(script.Name..'Done',true)
""", Client)
    await Until("DeniedServerDone")
    await Until("DeniedClientDone")
    Check(int(Stats().get("HttpPeak", -1)) == 0, "denial before native admission")

func Utilities() -> void:
    Script("Utilities", r"""
local H=game:GetService('HttpService')
assert(not H.HttpEnabled)
local Value=H:JSONDecode('{"a":[null,false,1],"empty":{},"list":[]}')
assert(Value.a[1]==H.JSONNull and Value.a[2]==false and Value.a[3]==1)
assert(H:JSONEncode(Value.empty)=='{}' and H:JSONEncode(Value.list)=='[]')
assert(H:JSONDecode('null')==H.JSONNull and H:JSONEncode(nil)=='null' and H:JSONEncode({})=='[]')
local S=utf8.char(0x96ea,0x1f600)..string.char(0,10,31)..'"\\'
assert(H:JSONDecode(H:JSONEncode(S))==S)
assert(H:JSONDecode('"\\uD83D\\uDE00"')==utf8.char(0x1f600))
for _,S in {'','not-json','[1,]','{"x":null,"x":2}','01','1e9999','"\\uD800"',string.char(255),string.rep(' ',1024*1024+1),string.rep('[',34)..'0'..string.rep(']',34)} do assert(not pcall(H.JSONDecode,H,S)) end
local Cycle={}; Cycle.Self=Cycle
for _,V in {Cycle,{[2]=1},{[1]=1,x=1},function() end,math.huge,0/0,string.char(255),string.rep('x',1024*1024)} do assert(not pcall(H.JSONEncode,H,V)) end
assert(H:JSONDecode(H:JSONEncode({OK=true})).OK)
assert(H:UrlEncode(utf8.char(0x96ea)..string.char(0)..' /%?#&=+~._-')=='%E9%9B%AA%00%20%2F%25%3F%23%26%3D%2B~._-')
assert(H:UrlEncode(string.char(255))=='%FF' and not pcall(H.UrlEncode,H,123))
local GUIDs,Seen={},{}
for I=1,2000 do
    local G=H:GenerateGUID(false)
    assert(#G==36 and G:match('^%x%x%x%x%x%x%x%x%-%x%x%x%x%-4%x%x%x%-[89ab]%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$') and not Seen[G])
    GUIDs[I]=G; Seen[G]=true
end
assert(#H:GenerateGUID()==38 and H:GenerateGUID(true):sub(1,1)=='{' and not pcall(H.GenerateGUID,H,1))
game:SetAttribute('GUIDs',table.concat(GUIDs,'\n'))
game:SetAttribute('UtilitiesDone',true)
""")
    await Until("UtilitiesDone")
    var File := FileAccess.open("res://guids.txt", FileAccess.WRITE)
    File.store_string(str(Game.get_meta("GUIDs", "")))
    File.close()
    Check(not Stats().get("MemoryFailed", true), "JSON rejection leaves domain live")
    print("[Runtime:HttpServiceTest] JSON PASS; UUID v4 sample=2000")

func Lifecycle() -> void:
    Script("Lifecycle", """
local H=game:GetService('HttpService'); local O=game:GetAttribute('Origin')
local OK,Error=pcall(H.GetAsync,H,O..'/hold')
assert(not OK and Error:find('deadline',1,true))
for _,Resume in {task.spawn,coroutine.resume} do
    local Done=false
    local Pending=task.spawn(function()
        local OK,Error=pcall(H.GetAsync,H,O..'/hold')
        assert(not OK and Error:find('Request resumed outside completion',1,true))
        assert(H:GetAsync(O..'/ok')=='ok'); Done=true
    end)
    task.wait(0.02); Resume(Pending,'forged')
    while not Done do task.wait() end
end
game:SetAttribute('LifecycleDone',true)
""")
    await Until("LifecycleDone")
    var Retired := Script("Retired", "game:GetService('HttpService'):GetAsync(game:GetAttribute('Origin')..'/hold'); game:SetAttribute('RetiredLate',true)")
    await Pending(1)
    Retired.call("set_enabled", false)
    await Pending(0)
    Retired.get("codigo_luau").source_code = "assert(game:GetService('HttpService'):GetAsync(game:GetAttribute('Origin')..'/ok')=='ok'); game:SetAttribute('ReloadDone',true)"
    Retired.call("set_enabled", true)
    await Until("ReloadDone")
    Check(not Game.has_meta("RetiredLate"), "retired public completion suppressed")
    Script("Shutdown", "game:GetService('HttpService'):GetAsync(game:GetAttribute('Origin')..'/hold')")
    await Pending(1)
    var Before := Time.get_ticks_msec()
    Game.free()
    Game = null
    await process_frame
    Check(Time.get_ticks_msec() - Before < 250, "public HTTP shutdown stays nonblocking")
    Check(FileAccess.get_file_as_string("user://ds_GL023_Close.json") == "23", "public close callback ran with HTTP admission closed")

func Tls() -> void:
    Script("Tls", """
local H=game:GetService('HttpService')
assert(H:GetAsync(game:GetAttribute('TlsOrigin')..'/ok')=='ok')
for _,Name in {'BadName','Untrusted','Stall'} do
    local OK,Error=pcall(H.RequestAsync,H,{Url=game:GetAttribute(Name..'Origin')..'/forbidden/tls-public'})
    assert(not OK and type(Error)=='string')
end
game:SetAttribute('TlsDone',true)
""")
    await Until("TlsDone")

func Run() -> void:
    var Args := OS.get_cmdline_user_args()
    var Parameters := {}
    for Index in range(Args.size() - 1):
        if Args[Index].begins_with("--http-"): Parameters[Args[Index].substr(7)] = Args[Index + 1]
    var Case := str(Parameters.get("case", "api"))
    var Enabled := Case in ["api", "lifecycle", "tls"]
    var Allowed := PackedStringArray()
    for Name in ["origin", "refused", "tls", "badname", "untrusted", "stall"]:
        if Parameters.has(Name): Allowed.append(Parameters[Name])
    ProjectSettings.set_setting("godot_luau/http/enabled", Enabled)
    ProjectSettings.set_setting("godot_luau/http/allowed_origins", Allowed)
    ProjectSettings.set_setting("godot_luau/http/timeout_milliseconds", 500 if Case == "lifecycle" else 1000)
    GDExtensionManager.load_extension("res://godot_luau.gdextension")
    Game = Node.new()
    Game.name = "Game"
    root.add_child(Game)
    current_scene = Game
    for Pair in [["origin", "Origin"], ["denied", "DeniedOrigin"], ["refused", "RefusedOrigin"], ["tls", "TlsOrigin"], ["badname", "BadNameOrigin"], ["untrusted", "UntrustedOrigin"], ["stall", "StallOrigin"]]:
        Game.set_meta(Pair[1], Parameters.get(Pair[0], ""))
    var Prefix := ""
    if Case == "lifecycle":
        # Create this owner before its host, so it remains live during host exit.
        Prefix = "local H=game:GetService('HttpService'); local Store=game:GetService('DataStoreService'):GetDataStore('GL023'); game:BindToClose(function() assert(not H.HttpEnabled); assert(not pcall(H.GetAsync,H,game:GetAttribute('Origin')..'/forbidden/close')); Store:SetAsync('Close',23) end); "
    Script("Counter", Prefix + "while true do game:SetAttribute('Counter',(game:GetAttribute('Counter') or 0)+1); task.wait() end")
    for Index in range(3): await process_frame
    LastFrame = Time.get_ticks_usec()
    if Case == "api": await Api()
    elif Case == "denied": await Denied()
    elif Case == "utilities": await Utilities()
    elif Case == "lifecycle": await Lifecycle()
    elif Case == "tls": await Tls()
    else: Check(false, "unknown case")
    Check(PeakGap < 0.25, "public API frame progress")
    print("[Runtime:HttpServiceTest] Peak frame gap seconds=", PeakGap)
    if is_instance_valid(Game): Game.free()
    await process_frame
    print("[Runtime:HttpServiceTest] ", "FAIL" if Failed else "PASS", " ", Case)
    quit(1 if Failed else 0)
