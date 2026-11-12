-- Caller-owned controls; factories never cache scope or resource handles.
return function(Scope: NativeSceneScope, Title: string)
    local Layer = Scope:New("CanvasLayer", {Name="HUD"})
    local Box = Scope:New("VBoxContainer", {Name="Box", Position=Vector2.new(24,20), MinSize=Vector2.new(480,120), Separation=8}, Layer)
    Scope:New("Label", {Text=Title, FontSize=26}, Box)
    local Status = Scope:New("Label", {Name="Status", Text="Collect the three markers."}, Box)
    local Next = Scope:New("Button", {Name="Next", Text="Restart round", MinSize=Vector2.new(180,36)}, Box)
    return Status, Next
end
