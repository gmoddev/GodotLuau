local Hud = require("res://Shared/Hud.luau")
return function(Scope: NativeSceneScope, Round: number)
    Scope.Name = "Round2D"
    local Background = Scope:New("ColorRect", {Size=Vector2.new(960,640), Color=Color3.new(0.035,0.065,0.1)})
    local Ground = Scope:New("StaticBody2D", {Name="Ground", Position=Vector2.new(480,540)})
    Scope:New("CollisionShape2D", {Shape=Scope:New("RectangleShape2D", {Size=Vector2.new(960,40)})}, Ground)
    Scope:New("ColorRect", {Position=Vector2.new(0,520), Size=Vector2.new(960,40), Color=Color3.new(0.1,0.25,0.3)})
    local Body = Scope:New("CharacterBody2D", {Name="Player", Position=Vector2.new(100,480)})
    Scope:New("CollisionShape2D", {Shape=Scope:New("RectangleShape2D", {Size=Vector2.new(28,28)})}, Body)
    local Texture = Scope:Load("Texture2D","res://Assets/Token.tres")
    local Frames = Scope:New("SpriteFrames", {})
    Scope:Call(Frames,"AddAnimation","move")
    Scope:Call(Frames,"AddFrame","move",Texture)
    Scope:Call(Frames,"AddFrame","move",Scope:Load("Texture2D","res://Assets/PlayerPulse.tres"))
    Scope:Call(Frames,"SetAnimationSpeed","move",8)
    local Sprite = Scope:New("AnimatedSprite2D", {Name="Visual", SpriteFrames=Frames}, Body)
    local Tokens = {}
    for Index, X in {280,500,740} do
        local Token = Scope:New("Area2D", {Name="Token"..Index, Position=Vector2.new(Round==1 and X or 960-X,480)})
        Scope:New("CollisionShape2D", {Shape=Scope:New("CircleShape2D", {Radius=20})}, Token)
        Scope:New("Sprite2D", {Texture=Texture, Scale=Vector2.new(1.5,1.5)}, Token)
        table.insert(Tokens,Token)
    end
    local Status, Next = Hud(Scope,"NATIVE 2D • WASD / stick • Space / A")
    local Audio = Scope:New("AudioStreamPlayer2D", {Stream=Scope:Tone(700,0.08), VolumeDb=-20})
    return {Scope=Scope,Body=Body,Sprite=Sprite,Tokens=Tokens,Status=Status,Next=Next,Audio=Audio,Collected=0}
end
