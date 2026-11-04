extends "res://RemoteDeliveryBenchmark.gd"

# Shared production workload for immutable main/candidate products. The base
# records Fire/echo, frame/dispatch samples, bounded native observations and
# coordinated teardown; this adds real world, Character and Function activity.
var WorldCount := 64
var Relevance := false
var World: Node
var Supplement := {}
var MinimumParts := 0x7fffffff
var MaximumParts := 0
var MaximumCharacters := 0
var Parts := 0
var Characters := {}

func Enter(Item: Node) -> void:
    if Item.is_class("RBXCharacter"):
        var Body := Item.get_node_or_null("PhysicsBody")
        Characters[Item.get_instance_id()] = Body.get_instance_id() if Body else 0
    elif Item.is_class("RobloxPart"): Parts += 1

func Leave(Item: Node) -> void:
    if Item.is_class("RBXCharacter"): Characters.erase(Item.get_instance_id())
    elif Item.is_class("RobloxPart"): Parts -= 1

func _initialize() -> void:
    var Arguments := OS.get_cmdline_user_args()
    for Position in range(Arguments.size() - 1):
        if Arguments[Position] == "--world-count": WorldCount = int(Arguments[Position + 1])
        if Arguments[Position] == "--relevance": Relevance = Arguments[Position + 1] == "true"
    super._initialize()

func Run() -> void:
    if not Check(WorldCount in [64, 512], "bounded world size"): return
    ProjectSettings.set_setting("godot_luau/network/replication_relevance", Relevance)
    await super.Run()
    if Failed: return
    var File := "res://bench-" + Role + str(Index) + ".json"
    var Record: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(File))
    Record["Foundation"] = Supplement
    Record["Characters"] = MaximumCharacters
    Record["Foundation"]["WorldObjects"] = WorldCount
    Record["Foundation"]["Relevance"] = Relevance
    Record["Foundation"]["MinimumObservedParts"] = MinimumParts
    Record["Foundation"]["MaximumObservedParts"] = MaximumParts
    Record["Foundation"]["MaximumObservedCharacters"] = MaximumCharacters
    Record["Foundation"]["Animation"] = "Server-approved looping native Character Visual scale track; headless"
    FileAccess.open(File, FileAccess.WRITE).store_string(JSON.stringify(Record))

func _process(Delta: float) -> bool:
    if is_instance_valid(World):
        for Identity in Characters:
            if is_instance_id_valid(Identity):
                var Item: Node = instance_from_id(Identity)
                Item.set_process(false); Item.set_physics_process(false)
                if not is_instance_id_valid(int(Characters[Identity])):
                    var Body := Item.get_node_or_null("PhysicsBody")
                    if Body: Characters[Identity] = Body.get_instance_id()
                if is_instance_id_valid(int(Characters[Identity])): instance_from_id(int(Characters[Identity])).set_physics_process(false)
        if Recording:
            MinimumParts = mini(MinimumParts, Parts); MaximumParts = maxi(MaximumParts, Parts)
            MaximumCharacters = maxi(MaximumCharacters, Characters.size())
            Supplement["FunctionCalls"] = int(Game.get_meta("FunctionCalls", 0))
            Supplement["AnimationStarts"] = int(Game.get_meta("AnimationStarts", 0))
            Supplement["Reparents"] = int(Game.get_meta("Reparents", 0))
            if Game.has_meta("Stats") and not Supplement.has("SnapshotTaken"):
                Supplement["SnapshotTaken"] = true
                if Network.has_method("GetReplicationState"): Supplement["Replication"] = Network.call("GetReplicationState")
    return super._process(Delta)

func Until(Test: Callable, Label: String) -> void:
    await super.Until(Test, Label)
    if Label == "coordinated close":
        var Started := Time.get_ticks_usec()
        var Final := int(FileAccess.get_file_as_string("res://foundation-final-counter"))
        await super.Until(func(): return Game.has_node("ReplicatedStorage/Counter") and int(Game.get_node("ReplicatedStorage/Counter").get("Value")) == Final, "final structural convergence")
        Supplement["ConvergenceUsec"] = Time.get_ticks_usec() - Started
        Supplement["FinalCounter"] = Final
        Supplement["MeasuredWire"] = Wire()
        if Network.has_method("GetReplicationState"): Supplement["Replication"] = Network.call("GetReplicationState")

func Mark(Name: String) -> void:
    if Name == "close" or Name.begins_with("done-"):
        Supplement["FunctionCalls"] = int(Game.get_meta("FunctionCalls", 0))
        Supplement["AnimationStarts"] = int(Game.get_meta("AnimationStarts", 0))
        Supplement["Reparents"] = int(Game.get_meta("Reparents", 0))
        Supplement["AnimationStates"] = Network.call("GetAnimationStates")
    if Name == "close":
        var Final: int = Game.get_node("ReplicatedStorage/Counter").get("Value")
        FileAccess.open("res://foundation-final-counter", FileAccess.WRITE).store_string(str(Final))
        Supplement["FinalCounter"] = Final
        if Network.has_method("GetReplicationState"): Supplement["Replication"] = Network.call("GetReplicationState")
        Supplement["MeasuredWire"] = Wire()
    super.Mark(Name)

func Wire() -> Dictionary:
    var Transport = Network.get_multiplayer().get_multiplayer_peer()
    if not Transport is ENetMultiplayerPeer: return {}
    var Host: ENetConnection = Transport.get_host()
    # ENetConnection.pop_statistic returns and resets the corresponding counter.
    return {"SentBytes": Host.pop_statistic(ENetConnection.HOST_TOTAL_SENT_DATA), "ReceivedBytes": Host.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_DATA), "SentPackets": Host.pop_statistic(ENetConnection.HOST_TOTAL_SENT_PACKETS), "ReceivedPackets": Host.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_PACKETS)}

func Script(Name: String, Source: String) -> void:
    if Name in ["Measure", "WarmReset"]: Supplement["StartupWire"] = Wire()
    if Name in ["Setup", "Connect"] and not is_instance_valid(World):
        var Settings := Node.new(); Settings.name = "SettingsMenu"; Game.add_child(Settings)
        World = ClassDB.instantiate("RobloxWorkspace"); World.name = "Workspace"; Game.add_child(World); World.set_process(false)
        for Item in World.get_children(): Enter(Item)
        World.child_entered_tree.connect(Enter); World.child_exiting_tree.connect(Leave)
        Game.set_meta("WorldCount", WorldCount)
    if Name == "Setup":
        var Clip := Animation.new(); Clip.length = 1.0; Clip.loop_mode = Animation.LOOP_LINEAR
        var Track := Clip.add_track(Animation.TYPE_SCALE_3D)
        Clip.track_set_path(Track, NodePath("Visual"))
        Clip.track_insert_key(Track, 0, Vector3.ONE); Clip.track_insert_key(Track, 0.5, Vector3(0.98,0.98,0.98))
        if not Check(ResourceSaver.save(Clip, "res://FoundationLoop.tres") == OK, "native animation fixture saved"): return
        Source = Source.replace("CharacterAutoLoads = false", "CharacterAutoLoads = true")
        Source = Source.replace("assert(#Payload == 1024)", """
assert(#Payload == 1024)
if Number > game:GetAttribute('Warmup') then
    game.ReplicatedStorage.Counter.Value = Number
    game.Workspace.Near_1.Color = Color3.new((Number % 7)/7, 0.5, 0.25)
    if Number % 16 == 0 then
        local C = Player.Character
        if C then
            C.Position = Vector3.new((Number % 32 == 0) and 1000 or 0, 5, 0)
            local T = C:LoadAnimation('res://FoundationLoop.tres'); T.Looped = true; T:Play()
            game:SetAttribute('AnimationStarts', (game:GetAttribute('AnimationStarts') or 0)+1)
        end
        local Child = game.ReplicatedStorage.ParentA.Child
        Child.Parent = game.ReplicatedStorage.ParentB; Child.Parent = game.ReplicatedStorage.ParentA
        game:SetAttribute('Reparents', (game:GetAttribute('Reparents') or 0)+2)
        local Temporary = Instance.new('Folder'); Temporary.Parent = game.ReplicatedStorage; Temporary:Destroy()
    end
end
""")
        Source = Source.replace("game:SetAttribute('Started', true)", """
assert(game:GetService('NetworkService'):RegisterCharacterAnimation('res://FoundationLoop.tres'))
local Counter = Instance.new('IntValue'); Counter.Name='Counter'; Counter.Parent=game.ReplicatedStorage
local A=Instance.new('Folder'); A.Name='ParentA'; A.Parent=game.ReplicatedStorage
local B=Instance.new('Folder'); B.Name='ParentB'; B.Parent=game.ReplicatedStorage
local Child=Instance.new('Folder'); Child.Name='Child'; Child.Parent=A
local Function=Instance.new('RemoteFunction'); Function.Name='Function'
Function.OnServerInvoke=function(_, Number) return Number end; Function.Parent=game.ReplicatedStorage
for N=1,game:GetAttribute('WorldCount') do
    local P=Instance.new('Part'); P.Anchored=true
    if N<=64 then P.Name='Near_'..N; P.Position=Vector3.new((N % 8)*16,0,math.floor(N/8)*16)
    elseif N<=128 then P.Name='Far_'..(N-64); P.Position=Vector3.new(1000+(N % 8)*16,0,math.floor((N-64)/8)*16)
    else P.Name='Distant_'..N; P.Position=Vector3.new(10000+N*16,0,0) end
    P.Parent=game.Workspace
    if N % 4 == 0 then task.wait() end
end
game:SetAttribute('Started', true)
""")
    elif Name == "Warmup":
        Source = "while not game.Workspace:FindFirstChild('Near_64') or not game.ReplicatedStorage:FindFirstChild('Function') do task.wait() end\n" + Source
    elif Name == "Measure":
        Source = Source.replace("R:FireServer(Number, Stamp, Payload)", """
R:FireServer(Number, Stamp, Payload)
if Number % 8 == 0 then
    assert(game.ReplicatedStorage.Function:InvokeServer(Number) == Number)
    game:SetAttribute('FunctionCalls',(game:GetAttribute('FunctionCalls') or 0)+1)
end
""")
    elif Name == "Report": Source = "task.wait(0.25)\n" + Source
    super.Script(Name, Source)
