-- Native 2D starter: static preview, real physics/input during gameplay.
local Scope = Scene.new(script.Parent)
Scope.Name = "PlatformStarter"
local Gradient = Scope:New("Gradient", {})
Scope:Call(Gradient, "SetColor", 0, {R=0.2, G=0.7, B=0.95, A=1})
local Texture = Scope:New("GradientTexture2D", {Gradient=Gradient, Width=24, Height=24})
local Body = Scope:New("CharacterBody2D", {Name="Player", Position=Vector2.new(160,160)})
Scope:New("CollisionShape2D", {Shape=Scope:New("RectangleShape2D", {Size=Vector2.new(24,24)})}, Body)
Scope:New("Sprite2D", {Texture=Texture}, Body)
local Floor = Scope:New("StaticBody2D", {Position=Vector2.new(320,360)})
Scope:New("CollisionShape2D", {Shape=Scope:New("RectangleShape2D", {Size=Vector2.new(640,32)})}, Floor)
Scope:New("ColorRect", {Position=Vector2.new(0,344), Size=Vector2.new(640,32), Color=Color3.new(0.15,0.25,0.35)})
local Layer = Scope:New("CanvasLayer", {})
Scope:New("Label", {Text="2D STARTER • WASD / left stick • Space / A to jump", Position=Vector2.new(20,20)}, Layer)
if not __IS_CLIENT then return end
local Controls = game:GetService("InputService"):AddContext("Native2D")
local Move = Controls:AddAction("Move", {ValueType=Enum.InputActionValueType.Vector2})
Move:BindKeyboardVector2()
Move:BindGamepadStick(Enum.InputStick.Left, {Device=-1})
local Jump = Controls:AddAction("Jump")
Jump:AddBinding(Enum.KeyCode.Space)
Jump:AddBinding(Enum.KeyCode.ButtonA, {Device=-1})
local JumpRequested = false
Jump.Pressed:Connect(function() JumpRequested = true end)
game:GetService("RunService").Stepped:Connect(function(Delta)
    local Velocity = Body.Velocity
    local Vertical = math.min(Velocity.Y + 600 * math.min(Delta,0.05), 600)
    if JumpRequested and Scope:Call(Body,"IsOnFloor") then Vertical = -280 end
    JumpRequested = false
    Body.Velocity = Vector2.new(Move:GetValue().X * 180, Vertical)
    Scope:Call(Body,"MoveAndSlide")
    if Body.Position.Y > 900 then Body.Position = Vector2.new(160,160) end
end)
