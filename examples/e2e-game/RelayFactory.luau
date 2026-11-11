-- The caller supplies its live scope; module caching never owns native handles.
return function(Scope: NativeSceneScope, Template: NativePackedScene,
    Position: NativeVector3, Index: number, Material: NativeMaterial)
    local Root = Scope:Instantiate(Template) :: NativeNode3D
    Root.Name = "Relay" .. tostring(Index)
    Root.Position = Position
    local Visual = Root:FindFirstChild("Visual") :: NativeMeshInstance3D
    Visual.Material = Material
    local Title = Root:FindFirstChild("Title") :: NativeLabel3D
    Title.Text = string.format("RELAY %d\nE to activate", Index)
    return Visual
end
