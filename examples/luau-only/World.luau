-- A reusable factory receives the caller's capability; it never caches owners.
return function(Scope: NativeSceneScope, Round: number)
    local function Material(Color)
        return Scope:New("StandardMaterial3D", {Color = Color})
    end
    Scope:New("DirectionalLight3D", {RotationDegrees = Vector3.new(-55, -25, 0)})
    Scope:New("Camera3D", {Position = Vector3.new(0, 9, 12), RotationDegrees = Vector3.new(-35, 0, 0)})
    local Floor = Scope:New("StaticBody3D", {Position = Vector3.new(0, -0.5, 0)})
    Scope:New("CollisionShape3D", {Shape = Scope:New("BoxShape3D", {Size = Vector3.new(12, 1, 12)})}, Floor)
    local Ground = Material(Color3.new(0.25, 0.35, 0.45))
    Ground.AlbedoTexture = Scope:Load("Texture2D", "res://Pattern.tres")
    Scope:New("MeshInstance3D", {Mesh = Scope:New("BoxMesh", {Size = Vector3.new(12, 1, 12)}), Material = Ground}, Floor)
    local Body = Scope:New("RigidBody3D", {Name = "Orb", Position = Vector3.new(0, 0.6, 0), Mass = 1})
    Scope:New("CollisionShape3D", {Shape = Scope:New("SphereShape3D", {Radius = 0.45})}, Body)
    Scope:New("MeshInstance3D", {Mesh = Scope:New("SphereMesh", {Radius = 0.45, Height = 0.9}), Material = Material(Color3.new(1, 0.65, 0.2))}, Body)
    local Template = Scope:Load("PackedScene", "res://Marker.tscn")
    local Positions = {Vector3.new(-3, 0.8, -3), Vector3.new(3, 0.8, -3), Vector3.new(0, 0.8, 4)}
    local Markers = {}
    for Index, Position in Positions do
        local Marker = Scope:Instantiate(Template)
        Marker.Name = "Marker" .. Index
        Marker.Position = Round == 1 and Position or Vector3.new(-Position.Z, Position.Y, Position.X)
        table.insert(Markers, Marker)
    end
    local Layer = Scope:New("CanvasLayer", {})
    local Box = Scope:New("VBoxContainer", {Position = Vector2.new(20, 16), MinSize = Vector2.new(420, 130), Separation = 8}, Layer)
    Scope:New("Label", {Text = "ORB RUN  •  LUAU NATIVE", FontSize = 26}, Box)
    local Status = Scope:New("Label", {Text = "Collect three green markers. WASD / left stick • Space to jump", FontSize = 17}, Box)
    local Next = Scope:New("Button", {Text = "RESTART", MinSize = Vector2.new(180, 36)}, Box)
    local Quit = Scope:New("Button", {Text = "QUIT", MinSize = Vector2.new(180, 36)}, Box)
    local Audio = Scope:New("AudioStreamPlayer", {Stream = Scope:Tone(660, 0.12), VolumeDb = -20})
    return {Scope = Scope, Body = Body, Markers = Markers, Status = Status, Next = Next, Quit = Quit, Audio = Audio, Collected = 0}
end
