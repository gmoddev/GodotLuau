local Hud = require("res://Shared/Hud.luau")
return function(Scope: NativeSceneScope, Round: number)
    Scope.Name = "Round3D"
    Scope:New("DirectionalLight3D",{RotationDegrees=Vector3.new(-55,-25,0)})
    local Floor = Scope:New("StaticBody3D",{Name="Ground",Position=Vector3.new(0,-0.5,0)})
    Scope:New("CollisionShape3D",{Shape=Scope:New("BoxShape3D",{Size=Vector3.new(12,1,12)})},Floor)
    Scope:New("MeshInstance3D",{Mesh=Scope:New("BoxMesh",{Size=Vector3.new(12,1,12)}),Material=Scope:New("StandardMaterial3D",{Color=Color3.new(0.1,0.2,0.28)})},Floor)
    local Material = Scope:New("ShaderMaterial",{Shader=Scope:Load("Shader","res://Assets/Tint.gdshader")})
    local Body = Scope:New("CharacterBody3D",{Name="Player",Position=Vector3.new(0,0.8,3)})
    Scope:New("CollisionShape3D",{Shape=Scope:New("BoxShape3D",{Size=Vector3.new(0.8,1.6,0.8)})},Body)
    Scope:New("MeshInstance3D",{Name="Visual",Mesh=Scope:New("BoxMesh",{Size=Vector3.new(0.8,1.6,0.8)}),Material=Material},Body)
    Scope:New("Camera3D",{Position=Vector3.new(0,6,8),RotationDegrees=Vector3.new(-35,0,0)},Body)
    Scope:New("NavigationRegion3D",{NavigationMesh=Scope:Load("NavigationMesh","res://Assets/Navigation.tres")})
    local Guide = Scope:New("CharacterBody3D",{Name="Guide",Position=Vector3.new(-3,0.8,-3)})
    Scope:New("CollisionShape3D",{Shape=Scope:New("BoxShape3D",{Size=Vector3.new(0.7,1.6,0.7)})},Guide)
    Scope:New("MeshInstance3D",{Mesh=Scope:New("BoxMesh",{Size=Vector3.new(0.7,1.6,0.7)}),Material=Scope:New("StandardMaterial3D",{Color=Color3.new(0.2,0.9,0.6)})},Guide)
    local Agent = Scope:New("NavigationAgent3D",{TargetPosition=Vector3.new(3,0,-3),PathDesiredDistance=0.25,TargetDesiredDistance=0.5},Guide)
    local Multi = Scope:New("MultiMesh",{TransformFormat=1,InstanceCount=16,Mesh=Scope:New("BoxMesh",{Size=Vector3.new(0.15,0.6,0.15)})})
    local Basis = {X=Vector3.new(1,0,0),Y=Vector3.new(0,1,0),Z=Vector3.new(0,0,1)}
    for Index=0,15 do
        Scope:Call(Multi,"SetInstanceTransform",Index,{Basis=Basis,Origin=Vector3.new(-4.5+(Index%8)*1.3,0.3,Index<8 and -5 or 5)})
    end
    Scope:New("MultiMeshInstance3D",{Multimesh=Multi,Material=Scope:New("StandardMaterial3D",{Color=Color3.new(0.1,0.65,0.75)})})
    local Tokens = {}
    for Index, Position in {Vector3.new(-3,0.6,1),Vector3.new(3,0.6,1),Vector3.new(0,0.6,-2)} do
        local Token=Scope:New("MeshInstance3D",{Name="Token"..Index,Position=Round==1 and Position or Vector3.new(-Position.X,Position.Y,-Position.Z),Mesh=Scope:New("SphereMesh",{Radius=0.3,Height=0.6}),Material=Scope:New("StandardMaterial3D",{Color=Color3.new(1,0.75,0.15)})})
        table.insert(Tokens,Token)
    end
    local Animator=Scope:New("AnimationPlayer",{},Body)
    local Clip=Scope:New("Animation",{Length=1,LoopMode=1})
    local Track=Scope:Call(Clip,"AddTrack",Scene.Enums.Animation.TrackType.TYPE_VALUE)
    Scope:Call(Clip,"TrackSetPath",Track,"Visual:scale")
    Scope:Call(Clip,"TrackInsertKey",Track,0,Vector3.new(1,1,1))
    Scope:Call(Clip,"TrackInsertKey",Track,0.5,Vector3.new(1.05,0.95,1.05))
    Scope:Call(Clip,"TrackInsertKey",Track,1,Vector3.new(1,1,1))
    local Library=Scope:New("AnimationLibrary",{})
    Scope:Call(Library,"AddAnimation","idle",Clip)
    Scope:Call(Animator,"AddAnimationLibrary","",Library)
    local Status,Next=Hud(Scope,"NATIVE 3D • WASD / stick • Space / A")
    local Audio=Scope:New("AudioStreamPlayer3D",{Stream=Scope:Tone(600,0.08),VolumeDb=-20},Body)
    return {Scope=Scope,Body=Body,Guide=Guide,Agent=Agent,Material=Material,Animator=Animator,Tokens=Tokens,Status=Status,Next=Next,Audio=Audio,Collected=0}
end
