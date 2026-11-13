local Art={}
function Art.Material(Scope,Color)
 return Scope:New('StandardMaterial3D',{Color=Color,Roughness=0.8})
end
function Art.Box(Scope,Name,Position,Size,Color,Parent)
 return Scope:New('MeshInstance3D',{Name=Name,Position=Position,Mesh=Scope:New('BoxMesh',{Size=Size}),Material=Art.Material(Scope,Color)},Parent)
end
function Art.Animation(Scope,Visual,Parent)
 local Player=Scope:New('AnimationPlayer',{},Parent)
 local Clip=Scope:New('Animation',{Length=1,LoopMode=1})
 local Track=Scope:Call(Clip,'AddTrack',Scene.Enums.Animation.TrackType.TYPE_VALUE)
 Scope:Call(Clip,'TrackSetPath',Track,Visual.Name..':scale')
 Scope:Call(Clip,'TrackInsertKey',Track,0,Vector3.new(1,1,1))
 Scope:Call(Clip,'TrackInsertKey',Track,0.5,Vector3.new(1.05,0.94,1.05))
 Scope:Call(Clip,'TrackInsertKey',Track,1,Vector3.new(1,1,1))
 local Library=Scope:New('AnimationLibrary',{})
 Scope:Call(Library,'AddAnimation','pulse',Clip)
 Scope:Call(Player,'AddAnimationLibrary','',Library)
 Scope:Call(Player,'Play','pulse')
 return Player
end
function Art.Distance(A,B)
 local X,Z=A.X-B.X,A.Z-B.Z
 return math.sqrt(X*X+Z*Z)
end
return Art
