-- Local UI and audio presentation; session/transport bootstrap stays native.
local Scope = Scene.new(script.Parent)
Scope.Name = "Presentation"
local Http = game:GetService("HttpService")
local Layer = Scope:New("CanvasLayer", {Name = "Layer"})
local Back = Scope:New("ColorRect", {
    Name = "Backdrop",
    Color = Color3.new(0.035, 0.055, 0.09),
    FullRect = true,
    MouseFilter = 2,
}, Layer)
local Menu = Scope:New("PanelContainer", {
    Name = "Menu",
    Position = Vector2.new(65, 65),
    Size = Vector2.new(440, 540),
}, Layer)
local Box = Scope:New("VBoxContainer", {Name = "Box", Separation = 13}, Menu)

local function TextFor(Text, Parent, FontSize, Name)
    return Scope:New("Label", {Name = Name or "Label", Text = Text, FontSize = FontSize or 20}, Parent)
end

local function Request(Action)
    game:SetAttribute("UIAction", Action)
end

local function ButtonFor(Text, Parent, Action)
    local Value = Scope:New("Button", {Text = Text, MinSize = Vector2.new(270, 42)}, Parent)
    Scope:Connect(Value, "Pressed", function() Request(Action) end)
    return Value
end

TextFor("RELAY SIEGE", Box, 42)
TextFor("Cooperative survival • 1–4 players", Box)
TextFor("Activate 3 relays. Destroy 6 drones.\nKeep the reactor alive for extraction.", Box, 18)
ButtonFor("PLAY SOLO", Box, "solo")
ButtonFor("HOST CO-OP", Box, "host")
local Address = Scope:New("LineEdit", {
    Name = "Address",
    Text = game:GetAttribute("UIHost") or "127.0.0.1",
    PlaceholderText = "Server address",
}, Box)
local PortField = Scope:New("LineEdit", {
    Name = "PortField",
    Text = tostring(game:GetAttribute("UIPort") or 24870),
    PlaceholderText = "UDP port (1024–65535)",
}, Box)
ButtonFor("JOIN SERVER", Box, "join")
ButtonFor("QUIT", Box, "quit")
local HUD = TextFor("", Layer, 22, "HUD")
Scope:Configure(HUD, {Position = Vector2.new(22, 18), MouseFilter = 2, Visible = false})
local Status = TextFor("WASD move • RMB look • Space jump • Shift sprint\nLMB fire • R reload • E relay • P impulse crate • Esc menu", Layer, 17, "Status")
Scope:Configure(Status, {Position = Vector2.new(22, 636), MouseFilter = 2, Visible = false})
local Feedback = TextFor("+", Layer, 28, "Feedback")
Scope:Configure(Feedback, {Position = Vector2.new(568, 342), MouseFilter = 2, Visible = false})
local Results = Scope:New("PanelContainer", {
    Name = "Results",
    Position = Vector2.new(370, 180),
    Size = Vector2.new(470, 300),
    Visible = false,
}, Layer)
local ResultBox = Scope:New("VBoxContainer", {Name = "Box"}, Results)
local ResultText = TextFor("", ResultBox, 25, "ResultText")
ButtonFor("PLAY ANOTHER ROUND", ResultBox, "Again")
ButtonFor("RETRY SAVE", ResultBox, "Save")
ButtonFor("MAIN MENU", ResultBox, "menu")
ButtonFor("QUIT", ResultBox, "quit")
local Audio = Scope:New("AudioStreamPlayer", {
    Name = "ShotAudio",
    Stream = Scope:Tone(220, 1500 / 22050),
    VolumeDb = -25,
})

local Snapshot = {}
local LastJSON = ""
local LastShot = 0
local SessionStarted = false
local LastMessage = ""
local FeedbackColour = Color3.new(1, 1, 1)
local White = Color3.new(1, 1, 1)

local function DrawState()
    local PlayerID = game:GetAttribute("LocalUserId") or 0
    local Mine = {}
    for _, Player in ipairs(Snapshot.Players or {}) do
        if Player.Id == PlayerID then Mine = Player end
    end
    local Enabled = 0
    for _, Active in ipairs(Snapshot.Relays or {}) do
        if Active then Enabled += 1 end
    end
    local Progress = Snapshot.Progress or {}
    local Text = string.format("RELAY SIEGE  |  %s  |  %ds\nHealth %d  |  Ammo %d/12 %s  |  Deaths %d\nRelays %d/3  |  Drones %d/6  |  Reactor %d\nTeam: %d/4  |  Career wins %d  |  Credits %d",
        Snapshot.Phase or "Connecting", Snapshot.Time or 0, Mine.Health or 0, Mine.Ammo or 0,
        Mine.Reload and "RELOADING" or "", Mine.Deaths or 0, Enabled, Snapshot.Kills or 0,
        Snapshot.Reactor or 0, #(Snapshot.Players or {}), Progress.Wins or 0, Progress.Credits or 0)
    if (Mine.Health or 1) <= 0 then Text ..= "\nDOWN — respawning in 2 seconds" end
    Scope:Configure(HUD, {Text = Text})
    Scope:Configure(ResultText, {Text = string.format("%s\nReward: %d credits\n%s\nEsc to resume during a round",
        Snapshot.Phase or "Paused", Snapshot.Reward or 0, Snapshot.Save or "")})
end

game:SetAttribute("UIReady", true)
local Previous = os.clock()
-- A task can render the menu before the session creates RunService.
while not game:GetAttribute("ShuttingDown") do
    local Now = os.clock()
    local Delta = math.max(0, Now - Previous)
    Previous = Now
    local Started = game:GetAttribute("SessionStarted") == true
    if Started and not SessionStarted then
        SessionStarted = true
        Scope:Configure(Menu, {Visible = false})
        Scope:Configure(Back, {Visible = false})
        Scope:Configure(HUD, {Visible = true, Text = "Starting session…"})
        Scope:Configure(Status, {Visible = true})
        Scope:Configure(Feedback, {Visible = true})
    end
    local Message = game:GetAttribute("UIMessage") or ""
    if Message ~= LastMessage then
        LastMessage = Message
        if Message ~= "" then Scope:Configure(HUD, {Text = Message, Visible = true}) end
    end
    if Started then
        local Raw = game:GetAttribute("ClientSnapshot") or game:GetAttribute("ServerSnapshot") or ""
        if Raw ~= "" and Raw ~= LastJSON then
            LastJSON = Raw
            local Ok, Decoded = pcall(function() return Http:JSONDecode(Raw) end)
            if Ok and type(Decoded) == "table" then Snapshot = Decoded; DrawState() end
        end
        local Shot = game:GetAttribute("LocalShot") or 0
        if Shot ~= LastShot then
            LastShot = Shot
            FeedbackColour = Color3.new(1, 0.75, 0.25)
            Scope:Play(Audio)
        else
            FeedbackColour = Color3.lerp(FeedbackColour, White, math.min(1, Delta * 12))
        end
        Scope:Configure(Feedback, {Modulate = FeedbackColour})
        local SessionError = game:GetAttribute("SessionError") or ""
        local Phase = Snapshot.Phase or ""
        Scope:Configure(Results, {Visible = Phase == "Victory" or Phase == "Defeat" or Phase == "StorageError"
            or game:GetAttribute("PlayerControllerMenu") == true or SessionError ~= ""})
        if SessionError ~= "" then
            Scope:Configure(ResultText, {Text = SessionError .. "\nReturn to the main menu to retry."})
            game:SetAttribute("PlayerControllerSuspended", true)
        end
    end
    task.wait()
end
Scope:Stop(Audio)
