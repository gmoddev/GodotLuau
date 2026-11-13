-- Native authoring entrypoint: no GDScript adapter is needed.
local Scope = Scene.new(script.Parent)
local Material = Scope:New("StandardMaterial3D", {Color = Color3.new(0.2, 0.65, 0.9)})
Scope:New("MeshInstance3D", {Name = "Cube", Mesh = Scope:New("BoxMesh", {}), Material = Material})
Scope:New("DirectionalLight3D", {RotationDegrees = Vector3.new(-45, -30, 0)})
Scope:New("Camera3D", {Position = Vector3.new(0, 2, 5), RotationDegrees = Vector3.new(-20, 0, 0)})
