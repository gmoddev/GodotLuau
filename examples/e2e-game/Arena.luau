-- Local native presentation; gameplay authority and snapshots stay in Server.luau.
local Scope = Scene.new(script.Parent)
Scope.Name = "Arena"
local Run = game:GetService("RunService")
local Http = game:GetService("HttpService")
local Visuals = {}
local RelayVisuals = {}
local Snapshot = {}
local LastJSON = ""
local RelayFactory = require(script.Parent:FindFirstChild("RelayFactory"))
local RelayTemplate = Scope:Load("PackedScene", "res://Scenes/Relay.tscn")
local RelayTexture = Scope:Load("Texture2D", "res://Textures/RelayPattern.tres")

local function Material(Colour, Emission)
    return Scope:New("StandardMaterial3D", {
        Color = Colour,
        Roughness = 0.8,
        EmissionEnabled = Emission == true,
        Emission = Colour,
    })
end

local function Block(Position, Size, Colour, Solid)
    local Value = Scope:New("MeshInstance3D", {
        Position = Position,
        Mesh = Scope:New("BoxMesh", {Size = Size}),
        Material = Material(Colour),
    })
    if Solid ~= false then
        local Body = Scope:New("StaticBody3D", {Position = Position})
        Scope:New("CollisionShape3D", {
            Shape = Scope:New("BoxShape3D", {Size = Size}),
        }, Body)
    end
    return Value
end

Block(Vector3.new(0, -1.5, 0), Vector3.new(48, 1, 56), Color3.new(0.12, 0.18, 0.23))
for _, X in ipairs({-24, 24}) do
    Block(Vector3.new(X, 2, 0), Vector3.new(1, 7, 56), Color3.new(0.19, 0.28, 0.34))
end
for _, Z in ipairs({-28, 28}) do
    Block(Vector3.new(0, 2, Z), Vector3.new(48, 7, 1), Color3.new(0.19, 0.28, 0.34))
end
for _, X in ipairs({-8, 8}) do
    Block(Vector3.new(X, 1, 0), Vector3.new(3, 4, 3), Color3.new(0.25, 0.32, 0.38))
end
Block(Vector3.new(0, -0.94, -9), Vector3.new(6, 0.1, 6), Color3.new(0.9, 0.12, 0.05), false)
Block(Vector3.new(0, 1, 0), Vector3.new(3, 4, 3), Color3.new(0.1, 0.55, 0.8))
for Index, Position in ipairs({Vector3.new(-14, 0, -10), Vector3.new(14, 0, -10), Vector3.new(0, 0, -20)}) do
    RelayVisuals[Index] = RelayFactory(Scope, RelayTemplate, Position, Index, Material(Color3.new(0.95, 0.6, 0.1)))
end

Scope:New("DirectionalLight3D", {RotationDegrees = Vector3.new(-45, -30, 0)})
Scope:New("WorldEnvironment", {
    Environment = Scope:New("Environment", {
        BackgroundMode = 1,
        BackgroundColor = Color3.new(0.07, 0.12, 0.2),
        AmbientLightSource = 2,
        AmbientLightColor = Color3.new(0.6, 0.8, 1),
        AmbientLightEnergy = 0.8,
    }),
})
local Sphere = Scope:New("SphereMesh", {Radius = 1.4, Height = 2.8, RadialSegments = 12, Rings = 6})
local Canopy = Scope:New("SoftBody3D", {
    Name = "PhysicsCanopy",
    Mesh = Scope:Mesh(Sphere),
    Material = Material(Color3.new(0.15, 0.8, 0.65)),
    Position = Vector3.new(10, 5, 14),
    CollisionLayer = 2,
    CollisionMask = 1,
})
Scope:Pin(Canopy, 0, true)

local RelayActive = Material(Color3.new(0.1, 0.9, 0.6), true)
local RelayInactive = Material(Color3.new(0.95, 0.6, 0.1), true)
Scope:Configure(RelayActive, {AlbedoTexture = RelayTexture})
Scope:Configure(RelayInactive, {AlbedoTexture = RelayTexture})
local BotMesh = Scope:New("SphereMesh", {Radius = 1, Height = 2})
local BotMaterial = Material(Color3.new(0.95, 0.2, 0.18), true)

local function DrawState()
    for Index, Active in ipairs(Snapshot.Relays or {}) do
        if Index > #RelayVisuals then break end
        Scope:Configure(RelayVisuals[Index], {Material = Active and RelayActive or RelayInactive})
    end
    local Present = {}
    for _, Bot in ipairs(Snapshot.Bots or {}) do
        local Key = tostring(Bot.Id)
        Present[Key] = true
        if not Visuals[Key] then
            Visuals[Key] = Scope:New("MeshInstance3D", {
                Name = "Drone" .. Key,
                Mesh = BotMesh,
                Material = BotMaterial,
                Position = Vector3.new(Bot.Position.X, Bot.Position.Y, Bot.Position.Z),
            })
        end
    end
    for Key, Value in pairs(Visuals) do
        if not Present[Key] then Value:Destroy(); Visuals[Key] = nil end
    end
end

Run.Heartbeat:Connect(function(Delta)
    -- This anchor controls only decorative native soft-body simulation.
    if game:GetAttribute("ClothReleaseRequested") then
        game:SetAttribute("ClothReleaseRequested", false)
        Scope:Pin(Canopy, 0, false)
    end
    local Raw = game:GetAttribute("ClientSnapshot") or game:GetAttribute("ServerSnapshot") or ""
    if Raw ~= "" and Raw ~= LastJSON then
        LastJSON = Raw
        local Ok, Decoded = pcall(function() return Http:JSONDecode(Raw) end)
        if Ok and type(Decoded) == "table" then Snapshot = Decoded; DrawState() end
    end
    for _, Bot in ipairs(Snapshot.Bots or {}) do
        local Value = Visuals[tostring(Bot.Id)]
        if Value then
            local Target = Vector3.new(Bot.Position.X, Bot.Position.Y, Bot.Position.Z)
            Scope:Configure(Value, {Position = Scope:Get(Value, "Position"):Lerp(Target, math.min(1, Delta * 14))})
        end
    end
end)

-- The live script owner retains the scope and its Heartbeat connection.
game:SetAttribute("ArenaReady", true)
