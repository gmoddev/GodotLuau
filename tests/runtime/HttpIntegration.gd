extends SceneTree

var Game: Node
var Failed := false
var LastFrame := 0
var PeakGap := 0.0

func Check(Value: bool, Label: String) -> void:
    if not Value:
        Failed = true
        print("[Runtime:HttpTest] FAIL ", Label)

func Script(Type: String, Name: String, Source: String, Parent: Node = null) -> Node:
    var Result: Node = ClassDB.instantiate(Type)
    var Resource: Script = ClassDB.instantiate("LuauScript")
    Resource.source_code = Source
    Result.name = Name
    Result.call("set_codigo_luau", Resource)
    (Game if Parent == null else Parent).add_child(Result)
    return Result

func Scene(Origins: Dictionary) -> void:
    Game = Node.new()
    Game.name = "Game"
    root.add_child(Game)
    current_scene = Game
    for Name in Origins: Game.set_meta(Name + "Origin", Origins[Name])

func Until(Name: String, Timeout: int = 20000) -> bool:
    var Deadline := Time.get_ticks_msec() + Timeout
    while not Game.get_meta(Name, false):
        if Failed: return false
        if Time.get_ticks_msec() >= Deadline:
            Check(false, "timeout " + Name)
            return false
        await process_frame
    return true

func Stats(Client: bool = false) -> Dictionary:
    var Host := Game.get_node_or_null("GodotLuauRuntime")
    return Host.call("GetResourceStats", Client) if Host else {}

func Pending(Count: int) -> bool:
    var Deadline := Time.get_ticks_msec() + 5000
    while int(Stats().get("HttpPending", 0)) != Count:
        if Time.get_ticks_msec() >= Deadline:
            Check(false, "pending request count " + str(Count))
            return false
        await process_frame
    return true

func Counter(Client: bool = false, CloseSave: bool = false) -> void:
    var Prefix := ""
    if CloseSave:
        # The first script creates the host after itself. Its close-hook owner
        # remains live when the host exits, as in the existing GL-003 fixture.
        Prefix = "local Origin=game:GetAttribute('HttpOrigin'); local Store=game:GetService('DataStoreService'):GetDataStore('GL005'); game:BindToClose(function() assert(not pcall(_HTTP.get,Origin..'/forbidden/close')); Store:SetAsync('Close',7) end); game:SetAttribute('CloseReady',true); "
    Script("LocalScript" if Client else "ServerScript", "ClientCounter" if Client else "Counter",
        Prefix + "while true do game:SetAttribute('" + ("ClientCounter" if Client else "Counter") + "',(game:GetAttribute('" + ("ClientCounter" if Client else "Counter") + "') or 0)+1); task.wait() end")

func _initialize() -> void:
    call_deferred("Run")

func _process(_Delta: float) -> bool:
    var Now := Time.get_ticks_usec()
    if LastFrame: PeakGap = maxf(PeakGap, float(Now - LastFrame) / 1000000.0)
    LastFrame = Now
    return false

func Baseline() -> void:
    var Source := """
local Origin=game:GetAttribute('HttpOrigin')
local Start=os.clock()
assert(_HTTP.get(Origin..'/slow')=='slow')
game:SetAttribute(script.Name..'Elapsed',os.clock()-Start)
assert(game:GetService('HttpService'):GetAsync(Origin..'/ok')=='ok')
assert(_HTTP.post(Origin..'/echo','payload','text/plain')=='payload')
local Result=_HTTP.request('GET',Origin..'/truncated')
assert(Result.Success and Result.StatusCode==200 and Result.Body=='partial')
game:SetAttribute(script.Name..'PartialSuccess',true)
game:SetAttribute(script.Name..'Done',true)
"""
    Script("ServerScript", "Server", Source)
    Script("LocalScript", "Client", Source)
    var Deadline := Time.get_ticks_msec() + 12000
    while (not Game.get_meta("ServerDone", false) or not Game.get_meta("ClientDone", false)) and Time.get_ticks_msec() < Deadline:
        await process_frame
    await process_frame
    for Name in ["Server", "Client"]:
        Check(bool(Game.get_meta(Name + "Done", false)), Name + " direct/public native completion")
        Check(bool(Game.get_meta(Name + "PartialSuccess", false)), Name + " truncated 2xx success reproduced")
        Check(float(Game.get_meta(Name + "Elapsed", 0.0)) >= 0.3, Name + " blocking time observed")
    Check(PeakGap >= 0.3, "main frame stall reproduced")
    print("[Runtime:HttpTest] Baseline peak frame gap seconds=", PeakGap)

func Denied() -> void:
    var Source := """
local Origin=game:GetAttribute('HttpOrigin')
local Service=game:GetService('HttpService')
assert(not pcall(function() Service.HttpEnabled=true end) and not Service.HttpEnabled)
_GL_NET_ROLE=0
local Native=_HTTP.get
local Raw=function(...) return Native(...) end
setfenv(Raw,setmetatable({_GL_NET_ROLE=0},{__index=getfenv(Raw)}))
assert(not pcall(Raw,Origin..'/forbidden/default?token=PrivateSentinel'))
assert(not pcall(_HTTP.post,Origin..'/forbidden/default','value'))
assert(not pcall(_HTTP.request,'GET',Origin..'/forbidden/default'))
assert(not pcall(Service.GetAsync,Service,Origin..'/forbidden/default?token=PrivateSentinel'))
assert(not pcall(Service.PostAsync,Service,Origin..'/forbidden/default','value'))
assert(not pcall(Service.RequestAsync,Service,{Url=Origin..'/forbidden/default'}))
local Request=Instance.new('HTTPRequest')
assert(not pcall(function() Request:request(Origin..'/forbidden/node') end))
Request:Destroy()
assert(not pcall(_GL_NET.call,'request',Origin..'/forbidden/helper'))
game:SetAttribute(script.Name..'Denied',true)
"""
    Script("ServerScript", "Server", Source)
    Script("LocalScript", "Client", Source)
    await Until("ServerDenied")
    await Until("ClientDenied")
    Check(int(Stats().get("HttpPending", 0)) == 0 and int(Stats().get("HttpPeak", 0)) == 0, "default denial had no request/root admission")

func Enabled() -> void:
    Counter()
    Script("LocalScript", "Client", """
_GL_NET_ROLE=0
local Service=game:GetService('HttpService')
assert(not pcall(function() Service.HttpEnabled=true end) and not Service.HttpEnabled)
local Native=_HTTP.get
local Raw=function(...) return Native(...) end
setfenv(Raw,setmetatable({_GL_NET_ROLE=0},{__index=getfenv(Raw)}))
assert(not pcall(Raw,game:GetAttribute('HttpOrigin')..'/forbidden/client'))
assert(not pcall(_HTTP.request,'GET',game:GetAttribute('HttpOrigin')..'/forbidden/client'))
game:SetAttribute('ClientDone',true)
""")
    Script("ServerScript", "Server", """
local Origin=game:GetAttribute('HttpOrigin')
local Service=game:GetService('HttpService')
_HTTP.Marker=true
assert(_HTTP.Marker)
local Before=game:GetAttribute('Counter') or 0
assert(_HTTP.get(Origin..'/slow')=='slow')
assert((game:GetAttribute('Counter') or 0)>Before+5)
assert(Service:GetAsync(Origin..'/ok',true)=='ok')
local Binary='UTF8 '..utf8.char(0x96ea)..string.char(0,255)
assert(_HTTP.post(Origin..'/echo',Binary,'application/octet-stream')==Binary)
assert(Service:PostAsync(Origin..'/echo','payload','text/plain',false)=='payload')
assert(_HTTP.post(Origin..'/headers','', 'text/plain',{['X-Number']=7})=='7|text/plain')
for _,Method in {'GET','POST','PUT','PATCH','DELETE','HEAD','OPTIONS'} do
    local Result=Service:RequestAsync({Url=Origin..'/method',Method=Method})
    assert(Result.Success and Result.StatusCode==200 and type(Result.Headers)=='table')
    assert(Result.Body==(Method=='HEAD' and '' or Method))
end
local Status=_HTTP.request('GET',Origin..'/status')
assert(not Status.Success and Status.StatusCode==418 and Status.StatusMessage=="I'm a Teapot" and Status.Body=='teapot')
assert(_HTTP.get(Origin..'/status')=='teapot')
local Redirect=_HTTP.request('GET',Origin..'/redirect')
assert(not Redirect.Success and Redirect.StatusCode==302 and Redirect.Body=='redirect')
assert(_HTTP.get(Origin..'/chunked')=='chunked')
assert(_HTTP.get(Origin..'/chunked-case')=='chunked')
assert(_HTTP.get(Origin..'/chunked-keepalive')=='chunked')
for _,Resume in {task.spawn,coroutine.resume} do
    local Done=false
    local Pending=task.spawn(function()
        local Ok,Error=pcall(_HTTP.get,Origin..'/slow')
        assert(not Ok and string.find(Error,'Request resumed outside completion',1,true))
        local Start=os.clock()
        assert(_HTTP.get(Origin..'/hold')=='slow' and os.clock()-Start>=1.8)
        Done=true
    end)
    task.wait(0.05)
    Resume(Pending,'forged completion')
    while not Done do task.wait() end
end
assert(_HTTP.request('GET',Origin..'/no-content').Success)
assert(_HTTP.request('HEAD',Origin..'/oversized-length').Success)
local Payload=string.rep('p',1024*1024)
assert(_HTTP.post(Origin..'/echo',Payload,'application/octet-stream')==Payload)
Payload=nil
local Large=_HTTP.request('GET',Origin..'/large')
assert(Large.Success and #Large.Body==4*1024*1024 and Large.Body:sub(-1)=='x')
Large=nil
local function Reject(Method,Url,Body,Headers)
    assert(not pcall(_HTTP.request,Method,Url,Body,Headers))
end
for _,Url in {'file:///tmp/x','http://a@b/','http://[::1]/',Origin..'/forbidden/#fragment',Origin..'/forbidden/'..string.char(0),Origin..'/forbidden/\\r\\nX: y',Origin..'/forbidden/%zz',game:GetAttribute('DeniedOrigin')..'/forbidden/port'} do
    Reject('GET',Url)
end
Reject('CONNECT',Origin..'/forbidden/method')
Reject('unknown',Origin..'/forbidden/method')
Reject('GET',Origin..'/forbidden/body','body')
Reject('POST',Origin..'/forbidden/body',string.rep('x',1024*1024+1))
for _,Header in {{Host='evil'}, {['Content-Length']='1'}, {['Transfer-Encoding']='chunked'}, {['Accept-Encoding']='gzip'}, {['X']='bad\\r\\nInjected: yes'}, {['X']=string.char(0)}, {['Bad:Name']='value'}, {X='a',x='b'}} do
    Reject('POST',Origin..'/forbidden/header','',Header)
end
local Headers={}
for Index=1,33 do Headers['X-'..Index]='value' end
Reject('POST',Origin..'/forbidden/header-count','',Headers)
assert(not pcall(_HTTP.post,Origin..'/forbidden/content-type','','x',{['Content-Type']='y'}))
for _,Path in {'/truncated','/oversized-length','/chunk-overflow','/header-overflow','/invalid-header','/invalid-length','/invalid-status','/ambiguous'} do
    local Result=_HTTP.request('GET',Origin..Path)
    assert(not Result.Success and Result.StatusCode==0 and Result.Body=='',Path)
end
local Wire=_HTTP.request('GET',Origin..'/wire-overflow')
print('[Runtime:HttpTest] Wire disposition '..Wire.StatusMessage)
assert(not Wire.Success and Wire.StatusCode==0 and Wire.Body=='' and Wire.StatusMessage:find('limit'))
local Start=os.clock()
local Stream=_HTTP.request('GET',Origin..'/stream')
assert(not Stream.Success and Stream.StatusCode==0 and Stream.Body=='' and Stream.StatusMessage=='Request deadline exceeded')
assert(os.clock()-Start>=4.8 and os.clock()-Start<6.5)
local Refused=_HTTP.request('GET',game:GetAttribute('RefusedOrigin')..'/refused')
assert(not Refused.Success and Refused.StatusCode==0 and Refused.Body=='')
local Dns=_HTTP.request('GET',game:GetAttribute('DnsOrigin')..'/dns')
assert(not Dns.Success and Dns.StatusCode==0 and Dns.Body=='')
game:SetAttribute('ServerDone',true)
""")
    await Until("ClientDone")
    await Until("ServerDone", 40000)
    await Pending(0)
    Check(PeakGap < 0.25, "bounded frame progress during HTTP")
    print("[Runtime:HttpTest] Candidate peak frame gap seconds=", PeakGap)

func Lifecycle(Origins: Dictionary) -> void:
    Counter(false, true)
    Script("ServerScript", "TaskCancel", """
local Pending=task.spawn(function() _HTTP.get(game:GetAttribute('HttpOrigin')..'/hold'); game:SetAttribute('TaskLate',true) end)
task.defer(function() task.cancel(Pending); game:SetAttribute('TaskCancelled',true) end)
""")
    await Until("TaskCancelled")
    await Pending(0)
    var Disabled := Script("ServerScript", "Disabled", "_HTTP.get(game:GetAttribute('HttpOrigin')..'/hold'); game:SetAttribute('DisabledLate',true)")
    await Pending(1)
    for Index in range(5): await process_frame
    Disabled.call("set_enabled", false)
    await Pending(0)
    Disabled.get("codigo_luau").source_code = "assert(_HTTP.get(game:GetAttribute('HttpOrigin')..'/ok')=='ok'); game:SetAttribute('ReloadDone',true)"
    Disabled.call("set_enabled", true)
    await Until("ReloadDone")
    var Storage := Node.new()
    Storage.name = "ReplicatedStorage"
    Game.add_child(Storage)
    Script("ModuleScript", "Web", "shared.WebLoads=(shared.WebLoads or 0)+1; return {Body=_HTTP.get(game:GetAttribute('HttpOrigin')..'/slow')}", Storage)
    var Caller := Script("ServerScript", "FirstCaller", "require(game.ReplicatedStorage.Web); game:SetAttribute('RetiredRequireLate',true)")
    await Pending(1)
    Caller.call("set_enabled", false)
    Check(int(Stats().get("HttpPending", 0)) == 1, "module HTTP survives first caller retirement")
    Script("ServerScript", "SecondCaller", "local M=require(game.ReplicatedStorage.Web); assert(M==require(game.ReplicatedStorage.Web) and M.Body=='slow' and shared.WebLoads==1); game:SetAttribute('ModuleDone',true)")
    await Until("ModuleDone")
    var Module := Script("ModuleScript", "CancelledWeb", "_HTTP.get(game:GetAttribute('HttpOrigin')..'/hold'); return true", Storage)
    Script("ServerScript", "ModuleCancelCaller", "assert(not pcall(require,game.ReplicatedStorage.CancelledWeb)); game:SetAttribute('ModuleCancelled',true)")
    await Pending(1)
    Module.queue_free()
    await Until("ModuleCancelled")
    await Pending(0)
    Script("ServerScript", "SignalOwner", """
game.ChildAdded:Connect(function(Child)
    if Child.Name=='HttpTrigger' then assert(_HTTP.get(game:GetAttribute('HttpOrigin')..'/slow')=='slow'); game:SetAttribute('SignalDone',true) end
end)
game:SetAttribute('SignalReady',true)
""")
    await Until("SignalReady")
    var Trigger := Node.new()
    Trigger.name = "HttpTrigger"
    Game.add_child(Trigger)
    await Until("SignalDone")
    # Two requests per owner and four per host; rejection is before any I/O.
    Script("ServerScript", "LimitA", """
for Index=1,2 do task.spawn(function() _HTTP.get(game:GetAttribute('HttpOrigin')..'/hold') end) end
assert(not pcall(_HTTP.get,game:GetAttribute('HttpOrigin')..'/forbidden/owner-limit'))
game:SetAttribute('LimitA',true)
""")
    await Until("LimitA")
    Script("ServerScript", "LimitB", """
for Index=1,2 do task.spawn(function() _HTTP.get(game:GetAttribute('HttpOrigin')..'/hold') end) end
assert(not pcall(_HTTP.get,game:GetAttribute('HttpOrigin')..'/forbidden/host-limit'))
game:SetAttribute('LimitB',true)
""")
    await Until("LimitB")
    await Pending(4)
    Check(int(Stats().get("HttpPeak", 0)) == 4, "native request capacity exercised")
    for Name in ["LimitA", "LimitB"]: Game.get_node(Name).call("set_enabled", false)
    await Pending(0)
    await Until("CloseReady")
    for Index in range(10): await process_frame
    Check(not Game.has_meta("TaskLate") and not Game.has_meta("DisabledLate") and not Game.has_meta("RetiredRequireLate"), "cancelled continuations stay retired")
    Script("ServerScript", "PendingScene", "_HTTP.get(game:GetAttribute('HttpOrigin')..'/hold'); game:SetAttribute('SceneLate',true)")
    await Pending(1)
    var Start := Time.get_ticks_msec()
    Game.queue_free()
    await process_frame
    await process_frame
    Check(Time.get_ticks_msec()-Start < 250, "scene cancellation does not wait for remote server")
    Check(FileAccess.get_file_as_string("user://ds_GL005_Close.json") == "7", "GL-003 final storage remains available")
    ProjectSettings.set_setting("godot_luau/server_limits/vm_memory_bytes", 8 * 1024 * 1024)
    Scene(Origins)
    Counter(true)
    Script("ServerScript", "Fresh", "assert(not pcall(_FileAccess.read,'user://ds_GL005_Close.json')); assert(game:GetService('DataStoreService'):GetDataStore('GL005'):GetAsync('Close')==7); assert(_HTTP.get(game:GetAttribute('HttpOrigin')..'/ok')=='ok'); game:SetAttribute('FreshDone',true)")
    await Until("FreshDone")
    await Pending(0)
    Script("ServerScript", "BeforeOom", "_HTTP.get(game:GetAttribute('HttpOrigin')..'/hold'); game:SetAttribute('OomLate',true)")
    await Pending(1)
    for Index in range(5): await process_frame
    Script("ServerScript", "Oom", "local Ok=pcall(string.rep,'x',16*1024*1024); shared.OomCaught=not Ok")
    var Deadline := Time.get_ticks_msec()+5000
    while not Stats().get("MemoryFailed", false) and Time.get_ticks_msec() < Deadline: await process_frame
    Check(bool(Stats().get("MemoryFailed", false)) and int(Stats().get("HttpPending", -1)) == 0, "GL-004 terminal OOM cancels HTTP")
    var Before := int(Game.get_meta("ClientCounter", 0))
    for Index in range(10): await process_frame
    Check(int(Game.get_meta("ClientCounter", 0)) > Before and not Stats(true).get("MemoryFailed", true), "other domain survives HTTP-owner OOM")
    Check(not Game.has_meta("OomLate") and not Game.has_meta("SceneLate"), "no stale response crosses domain replacement")
    Check(PeakGap < 0.25, "lifecycle frame progress")

func Tls() -> void:
    Counter()
    Script("ServerScript", "Tls", """
local Origin=game:GetAttribute('TlsOrigin')
local Before=game:GetAttribute('Counter') or 0
assert(_HTTP.get(Origin..'/ok')=='ok')
local Binary='tls'..string.char(0,255)
assert(_HTTP.post(Origin..'/echo',Binary,'application/octet-stream')==Binary)
local BadName=_HTTP.request('GET',game:GetAttribute('BadNameOrigin')..'/forbidden/tls-hostname')
assert(not BadName.Success and BadName.StatusCode==0 and BadName.Body=='')
local Untrusted=_HTTP.request('GET',game:GetAttribute('UntrustedOrigin')..'/forbidden/tls-untrusted')
assert(not Untrusted.Success and Untrusted.StatusCode==0 and Untrusted.Body=='')
local Start=os.clock()
local Stall=_HTTP.request('GET',game:GetAttribute('StallOrigin')..'/tls-stall')
assert(not Stall.Success and Stall.StatusCode==0 and Stall.Body=='' and Stall.StatusMessage=='Request deadline exceeded')
assert(os.clock()-Start>=4.8 and os.clock()-Start<6.5)
assert((game:GetAttribute('Counter') or 0)>Before+5)
game:SetAttribute('TlsDone',true)
""")
    await Until("TlsDone")
    await Pending(0)
    Check(PeakGap < 0.25, "TLS does not stall main frame")

func Run() -> void:
    var Args := OS.get_cmdline_user_args()
    var Parameters := {}
    for Index in range(Args.size()-1):
        if Args[Index].begins_with("--http-"): Parameters[Args[Index].substr(7)] = Args[Index+1]
    var IsBaseline := "--baseline" in Args
    var Case := str(Parameters.get("case", "enabled"))
    var Origins := {"Http": str(Parameters.get("origin", ""))}
    for Name in ["Denied", "Refused", "Dns", "Tls", "BadName", "Untrusted", "Stall"]:
        Origins[Name] = str(Parameters.get(Name.to_lower(), ""))
    Check(not Origins["Http"].is_empty(), "controlled origin supplied")
    if IsBaseline:
        ProjectSettings.set_setting("godot_luau/server_limits/resume_milliseconds", 2000)
        ProjectSettings.set_setting("godot_luau/client_limits/resume_milliseconds", 2000)
    elif Case != "denied":
        var Allowed := PackedStringArray()
        for Name in Origins:
            if Name != "Denied" and not Origins[Name].is_empty(): Allowed.append(Origins[Name])
        ProjectSettings.set_setting("godot_luau/http/enabled", true)
        ProjectSettings.set_setting("godot_luau/http/allowed_origins", Allowed)
        ProjectSettings.set_setting("godot_luau/http/timeout_milliseconds", 1000 if Case == "lifecycle" else 5000)
    var Loaded := GDExtensionManager.load_extension("res://godot_luau.gdextension")
    Check(Loaded in [GDExtensionManager.LOAD_STATUS_OK, GDExtensionManager.LOAD_STATUS_ALREADY_LOADED], "extension load")
    Scene(Origins)
    for Index in range(3): await process_frame
    PeakGap=0
    LastFrame=Time.get_ticks_usec()
    if IsBaseline: await Baseline()
    elif Case == "denied": await Denied()
    elif Case == "enabled": await Enabled()
    elif Case == "lifecycle": await Lifecycle(Origins)
    elif Case == "tls": await Tls()
    else: Check(false, "unknown fixture case")
    Game.queue_free()
    await process_frame
    await process_frame
    print("[Runtime:HttpTest] ", "FAIL" if Failed else "PASS", " ", "baseline" if IsBaseline else Case)
    quit(1 if Failed else 0)
