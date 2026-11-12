-- Native Control application with keyboard focus, lists, text entry and signals.
local Scope = Scene.new(script.Parent)
Scope.Name = "SettingsApp"
local Layer = Scope:New("CanvasLayer", {Name="UI"})
local Panel = Scope:New("PanelContainer", {Name="Panel", FullRect=true, OffsetLeft=24, OffsetTop=24, OffsetRight=-24, OffsetBottom=-24}, Layer)
local Tabs = Scope:New("TabContainer", {Name="Tabs", MinSize=Vector2.new(480,320)}, Panel)
local Settings = Scope:New("VBoxContainer", {Name="Settings", Separation=12}, Tabs)
Scope:New("Label", {Text="NATIVE SETTINGS", FontSize=26}, Settings)
local Name = Scope:New("LineEdit", {Name="NameInput", Text="Player", PlaceholderText="Display name", TooltipText="Name shown in this session"}, Settings)
local Volume = Scope:New("HSlider", {Name="Volume", MinValue=0, MaxValue=100, Step=1, Value=60, TooltipText="Preview volume"}, Settings)
local Quality = Scope:New("ItemList", {Name="Quality", MinSize=Vector2.new(320,100), TooltipText="Choose a presentation preset"}, Settings)
for _, Item in {"Low", "Balanced", "High"} do Scope:Call(Quality,"AddItem",Item) end
Scope:Call(Quality,"Select",1)
local Status = Scope:New("Label", {Name="Status", Text="Change settings, then apply."}, Settings)
local Apply = Scope:New("Button", {Name="Apply", Text="Apply settings", TooltipText="Applies this application's local presentation settings"}, Settings)
local About = Scope:New("VBoxContainer", {Name="About", Separation=12}, Tabs)
Scope:New("RichTextLabel", {Text="Built entirely with Luau and native Godot Controls.\nUse Tab, Shift+Tab and arrow keys to navigate.", FitContent=true}, About)
if not __IS_CLIENT then return end
Scope:Connect(Apply,"Pressed",function()
    local Selection = Scope:Call(Quality,"GetSelectedItems")
    local Preset = #Selection > 0 and Scope:Call(Quality,"GetItemText",Selection[1]) or "Balanced"
    Status.Text = string.format("%s • %s • volume %d",Name.Text,Preset,Volume.Value)
end)
Scope:Call(Name,"GrabFocus")
