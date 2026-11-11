extends RefCounted

# Runs inside the existing production Integration actor. GDScript observes native
# state and emits native signals; construction and mutation use the real Luau API.
func Run(Host: SceneTree, Game: Node) -> void:
    var Runner = Host
    var AssetPath := "res://NativeAuthoringMesh.tres"
    var DeniedAssetPath := "res://NativeAuthoringDenied.tres"
    var Asset := BoxMesh.new()
    Asset.size = Vector3(7, 8, 9)
    Runner.Check(ResourceSaver.save(Asset, AssetPath) == OK, "Scene prepare typed project mesh")
    Runner.Check(ResourceSaver.save(Resource.new(), DeniedAssetPath) == OK, "Scene prepare unadmitted project resource")
    Asset = null
    var BaselineObjects := Performance.get_monitor(Performance.OBJECT_COUNT)
    var BaselineResources := Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
    var Started := Time.get_ticks_usec()
    var Owner: Node = Runner.CreateScript("ServerScript", "NativeAuthoringOwner", """
local Scope = Scene.new(script.Parent)
Scope.Name = 'NativeAuthoring'
local LegacyClone = game.Clone
assert(type(LegacyClone) == 'function' and type(_InstanceNew) == 'function')
assert(not pcall(function() LegacyClone(Scope) end))
assert(not pcall(function() _InstanceNew('SceneScope') end))
local Root = Scope:New('Node3D', {Name='Root', Position=Vector3.new(1, 2, 3)})
local Mesh = Scope:New('BoxMesh', {Size=Vector3.new(2, 3, 4)})
local Shape = Scope:New('BoxShape3D', {Size=Vector3.new(4, 1, 4)})
local Sphere = Scope:New('SphereMesh', {Radius=1, Height=2, RadialSegments=8, Rings=4})
local SphereShape = Scope:New('SphereShape3D', {Radius=0.5})
local Material = Scope:New('StandardMaterial3D', {
    Color=Color3.new(0.25, 0.5, 0.75), Roughness=0.6,
    EmissionEnabled=true, Emission=Color3.new(0.1, 0.2, 0.3)})
local Display = Scope:New('MeshInstance3D', {Name='Display', Mesh=Mesh, Material=Material}, Root)
local Floor = Scope:New('StaticBody3D', {Name='Floor', CollisionLayer=1, CollisionMask=1}, Root)
Scope:New('CollisionShape3D', {Name='FloorShape', Shape=Shape}, Floor)
local Body = Scope:New('RigidBody3D', {
    Name='Body', Position=Vector3.new(0, 100, 0), Mass=2,
    GravityScale=0, CollisionLayer=0, CollisionMask=0}, Root)
Scope:New('CollisionShape3D', {Name='BodyShape', Shape=SphereShape}, Body)
local Environment = Scope:New('Environment', {
    BackgroundMode=1, BackgroundColor=Color3.new(0.1, 0.2, 0.3),
    AmbientLightSource=3, AmbientLightColor=Color3.new(0.4, 0.5, 0.6), AmbientLightEnergy=0.7})
Scope:New('WorldEnvironment', {Name='WorldEnvironment', Environment=Environment}, Root)
Scope:New('DirectionalLight3D', {Name='Sun', Energy=1.5, ShadowEnabled=true}, Root)
Scope:New('Camera3D', {Name='Camera', Fov=65, Near=0.1, Far=200}, Root)
Scope:New('Label3D', {Name='Caption', Text='Native scene', FontSize=24}, Root)
local ClothMesh = Scope:Mesh(Sphere)
local Cloth = Scope:New('SoftBody3D', {
    Name='Cloth', Mesh=ClothMesh, Position=Vector3.new(0, 10, 0),
    CollisionLayer=0, CollisionMask=0, SimulationPrecision=2, TotalMass=0.5}, Root)
Scope:Pin(Cloth, 0, true)
local Canvas = Scope:New('CanvasLayer', {Name='Canvas', Layer=3})
local Panel = Scope:New('Control', {Name='Panel', Size={X=320, Y=200}, MouseFilter=2}, Canvas)
local Button = Scope:New('Button', {Name='Button', Text='Native', Size={X=120, Y=32}, FontSize=20}, Panel)
local Input = Scope:New('LineEdit', {Name='Input', Text='', PlaceholderText='Submit'}, Panel)
local Audio = Scope:New('AudioStreamPlayer', {
    Name='Audio', Stream=Scope:Tone(440, 0.25), VolumeDb=-80, PitchScale=1})
local Primary, Secondary
Primary = Scope:Connect(Button, 'Pressed', function()
    game:SetAttribute('NAClickA', (game:GetAttribute('NAClickA') or 0) + 1)
    if game:GetAttribute('NADisconnectPeer') then
        Secondary:Disconnect()
        Primary:Disconnect()
    end
end)
Secondary = Scope:Connect(Button, 'Pressed', function()
    game:SetAttribute('NAClickB', (game:GetAttribute('NAClickB') or 0) + 1)
end)
Scope:Connect(Input, 'TextSubmitted', function(Text)
    assert(Text == 'native-text')
    game:SetAttribute('NATextSubmitted', Text)
end)
Scope:Connect(Audio, 'Finished', function()
    game:SetAttribute('NAAudioFinished', (game:GetAttribute('NAAudioFinished') or 0) + 1)
end)
assert(Primary.Connected and Secondary.Connected)
assert(Scope:Get(Root, 'Position') == Root.Position)
assert(Display == Root:FindFirstChild('Display') and Display.ClassName == 'MeshInstance3D')
local Loaded = Scope:Load('Mesh', 'res://NativeAuthoringMesh.tres')
local Cached = Scope:Load('Mesh', 'res://NativeAuthoringMesh.tres')
Scope:New('MeshInstance3D', {Name='Loaded', Mesh=Loaded}, Root)
assert(not pcall(function() Scope:Configure(Loaded, {Size=Vector3.new(1, 1, 1)}) end))
assert(not pcall(function() Scope:Configure(Cached, {Size=Vector3.new(1, 1, 1)}) end))
local ReadOnlyMesh = Scope:Get(Display, 'Mesh')
assert(not pcall(function() Scope:Configure(ReadOnlyMesh, {Size=Vector3.new(1, 1, 1)}) end))
assert(not pcall(function() Scope:Configure(ClothMesh, {}) end))
local Before = #Scope:GetDescendants()
local Nul = string.char(0)
local Rejections = {
    function() Scope:Configure(Body, {Name='Changed', Mass=-1}) end,
    function() Scope:Configure(Mesh, {Size=Vector3.new(9, 9, 9), Unknown=true}) end,
    function() Scope:New('MeshInstance3D', {Name='Rejected', Mesh=Shape}) end,
    function() Scope:New('PackedScene', {}) end,
    function() Scope:New('Node3D', {Position={X=1, Y=2, Z=3}}) end,
    function() Scope:New('Node3D', {Scale=Vector3.new(-1, 1, 1)}) end,
    function() Scope:New('Control', {Size={X=-1, Y=1}}) end,
    function() Scope:Configure(Sphere, {Radius=0/0}) end,
    function() Scope:Configure(Sphere, {RadialSegments=65}) end,
    function() Scope:Configure(Material, {Roughness=math.huge}) end,
    function() Scope:Configure(Body, {Mass='2'}) end,
    function() Scope:Configure(Root, {Name='bad/name'}) end,
    function() Scope:Configure(Root, {Parent=game}) end,
    function() Scope:New('Node3D', {}, game) end,
    function() Scope:Pin(Cloth, -1, true) end,
    function() Scope:Pin(Cloth, 8192, true) end,
    function() Scope:Pin(Cloth, 0.5, true) end,
    function() Scope:Pin(Cloth, 0, 1) end,
    function() Scope:Tone(0/0, 0.1) end,
    function() Scope:Tone(440, 1.01) end,
    function() Scope:Impulse(Body, Vector3.new(math.huge, 0, 0)) end,
    function() Scope:Connect(Button, 'TextSubmitted', function() end) end,
    function() Scope:Load('PackedScene', 'res://NativeAuthoringMesh.tres') end,
    function() Scope:Load('Mesh', 'res://NativeAuthoringDenied.tres') end,
    function() Scope:Load('Mesh', 'user://NativeAuthoringMesh.tres') end,
    function() Scope:Load('Mesh', 'res://../NativeAuthoringMesh.tres') end,
    function() Scope:Load('Mesh', 'C:/NativeAuthoringMesh.tres') end,
    function() Scope:New('BoxMesh' .. Nul .. 'Extra', {}) end,
    function() Scope:Configure(Root, {['Name' .. Nul .. 'Extra']='Changed'}) end,
    function() Scope:Get(Root, 'Name' .. Nul .. 'Extra') end,
    function() return Root['Name' .. Nul .. 'Extra'] end,
    function() Root['Name' .. Nul .. 'Extra'] = 'Changed' end,
    function() Scope:Connect(Button, 'Pressed' .. Nul .. 'Extra', function() end) end,
    function() Scope:Load('Mesh' .. Nul .. 'Extra', 'res://NativeAuthoringMesh.tres') end,
    function() Scope:Load('Mesh', 'res://NativeAuthoringMesh.tres' .. Nul .. 'Extra') end,
    function() Scene.new(script) end,
}
for Index, Reject in ipairs(Rejections) do
    assert(not pcall(Reject), 'Scene rejection accepted case ' .. tostring(Index))
end
assert(#Scope:GetDescendants() == Before and Body.Name == 'Body' and Scope:Get(Body, 'Mass') == 2)
assert(Scope:Get(Mesh, 'Size') == Vector3.new(2, 3, 4) and Scope:Get(Sphere, 'Radius') == 1)
assert(Scope:Get(Material, 'Roughness') > 0.59 and Scope:Get(Material, 'Roughness') < 0.61)
local Batch = Scope:New('Node3D', {Name='Batch'})
for Index=1,64 do
    Scope:New('MeshInstance3D', {Name='Item' .. tostring(Index), Mesh=Mesh, Material=Material}, Batch)
end
local GarbageResource = Scope:New('BoxMesh', {Size=Vector3.new(1, 2, 3)})
local Consumer = Scope:New('MeshInstance3D', {Name='GcConsumer', Mesh=GarbageResource})
GarbageResource = nil
shared.NativeAuthoring = {
    Scope=Scope, Configure=Scope.Configure, New=Scope.New,
    Mesh=Mesh, Material=Material, Display=Display, Primary=Primary, Secondary=Secondary}
game:SetAttribute('NAReady', true)
while not game:GetAttribute('NAImpulseReady') do task.wait() end
Scope:Impulse(Body, Vector3.new(4, 0, 0))
game:SetAttribute('NAImpulseApplied', true)
while not game:GetAttribute('NAAudioPlay') do task.wait() end
Scope:Play(Audio)
game:SetAttribute('NAAudioPlaying', true)
while not game:GetAttribute('NAAudioStop') do task.wait() end
Scope:Stop(Audio)
Scope:Pin(Cloth, 0, false)
game:SetAttribute('NAAudioStopped', true)
while not game:GetAttribute('NAAudioRestart') do task.wait() end
Scope:Play(Audio)
game:SetAttribute('NAAudioRestarted', true)
while not game:GetAttribute('NAGcStart') do task.wait() end
local function Collect()
    local Previous, Collected = gcinfo(), false
    for Index=1,20000 do
        local Garbage = {string.rep('scene-gc-', 24) .. tostring(Index), Index, {Index}}
        local Current = gcinfo()
        if Current < Previous then Collected = true end
        Previous = Current
        if Index % 1000 == 0 then task.wait() end
    end
    assert(Collected, 'Scene GC allocation workload did not observe collection')
end
Collect()
game:SetAttribute('NAGcRetained', true)
while not game:GetAttribute('NAGcRelease') do task.wait() end
Consumer.Mesh = nil
Collect()
game:SetAttribute('NAGcReleased', true)
""", Game)
    if not await Runner.Until("NAReady"):
        return
    var Scope := Game.get_node_or_null("NativeAuthoring")
    Runner.Check(Scope != null and Scope.is_class("SceneScope"), "Scene scope is a real native node")
    if Scope == null:
        return
    var Display := Scope.get_node("Root/Display") as MeshInstance3D
    var Body := Scope.get_node("Root/Body") as RigidBody3D
    var Cloth := Scope.get_node("Root/Cloth") as SoftBody3D
    var Audio := Scope.get_node("Audio") as AudioStreamPlayer
    var ButtonNode := Scope.get_node("Canvas/Panel/Button") as Button
    var InputNode := Scope.get_node("Canvas/Panel/Input") as LineEdit
    var Consumer := Scope.get_node("GcConsumer") as MeshInstance3D
    var CollectedResource: WeakRef = weakref(Consumer.mesh)
    var RetiredResource: WeakRef = weakref(Display.mesh)
    var NativeMesh := Display.mesh as BoxMesh
    var NativeMaterial := Display.material_override as StandardMaterial3D
    var FloorCollision := Scope.get_node("Root/Floor/FloorShape") as CollisionShape3D
    var BodyCollision := Body.get_node("BodyShape") as CollisionShape3D
    Runner.Check(NativeMesh != null and NativeMesh.size == Vector3(2, 3, 4), "Scene native mesh and atomic resource rejection")
    Runner.Check(NativeMaterial != null and is_equal_approx(NativeMaterial.roughness, 0.6), "Scene native material")
    Runner.Check(FloorCollision.shape is BoxShape3D, "Scene native box collision shape")
    Runner.Check(BodyCollision.shape is SphereShape3D and Body.mass == 2.0, "Scene native sphere shape and atomic body rejection")
    NativeMesh = null
    NativeMaterial = null
    var World := Scope.get_node("Root/WorldEnvironment") as WorldEnvironment
    var NativeEnvironment: Environment = World.environment
    Runner.Check(NativeEnvironment != null and is_equal_approx(NativeEnvironment.ambient_light_energy, 0.7), "Scene native environment")
    NativeEnvironment = null
    var LoadedMesh := (Scope.get_node("Root/Loaded") as MeshInstance3D).mesh as BoxMesh
    Runner.Check(LoadedMesh != null and LoadedMesh.size == Vector3(7, 8, 9), "Scene immutable loaded resource and cache hit")
    LoadedMesh = null
    Runner.Check(Scope.get_node("Batch").get_child_count() == 64, "Scene 64-object construction workload")
    Runner.Check(Cloth.mesh is ArrayMesh and Cloth.mesh.get_surface_count() == 1 and Cloth.is_point_pinned(0), "Scene bounded native soft body mesh and pin")
    var NativeAudio := Audio.stream as AudioStreamWAV
    Runner.Check(NativeAudio != null and NativeAudio.mix_rate == 22050 and NativeAudio.data.size() == 11024, "Scene bounded generated native audio")
    NativeAudio = null
    print("[Scene:Qualification] Native graph construction ", JSON.stringify({
        "Microseconds": Time.get_ticks_usec() - Started,
        "Objects": Performance.get_monitor(Performance.OBJECT_COUNT) - BaselineObjects,
        "Resources": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT) - BaselineResources,
        "BatchChildren": 64}))
    await Host.physics_frame
    await Host.physics_frame
    Game.set_meta("NAImpulseReady", true)
    if not await Runner.Until("NAImpulseApplied"):
        return
    await Host.physics_frame
    await Host.physics_frame
    print("[Scene:Qualification] Initialized rigid-body velocity=", Body.linear_velocity)
    Runner.Check(Body.linear_velocity.x > 1.0 and Body.linear_velocity.x < 3.0, "Scene impulse reaches native rigid-body simulation")
    ButtonNode.pressed.emit()
    Runner.Check(Game.get_meta("NAClickA", 0) == 1 and Game.get_meta("NAClickB", 0) == 1, "Scene duplicate subscriptions each dispatch exactly once")
    Game.set_meta("NADisconnectPeer", true)
    ButtonNode.pressed.emit()
    ButtonNode.pressed.emit()
    Runner.Check(Game.get_meta("NAClickA", 0) == 2 and Game.get_meta("NAClickB", 0) == 1 and ButtonNode.get_signal_connection_list("pressed").is_empty(), "Scene reentrant self/peer disconnect removes native subscriptions")
    InputNode.text_submitted.emit("native-text")
    Runner.Check(Game.get_meta("NATextSubmitted", "") == "native-text", "Scene native text submission payload")
    Game.set_meta("NAAudioPlay", true)
    if not await Runner.Until("NAAudioPlaying"):
        return
    Runner.Check(Audio.playing, "Scene Play starts native audio")
    Game.set_meta("NAAudioStop", true)
    if not await Runner.Until("NAAudioStopped"):
        return
    Runner.Check(not Audio.playing and not Game.has_meta("NAAudioFinished"), "Scene Stop stops native audio without a finished callback")
    Runner.Check(not Cloth.is_point_pinned(0), "Scene unpin reaches the native soft body")
    Game.set_meta("NAAudioRestart", true)
    if not await Runner.Until("NAAudioFinished", 2400):
        return
    Runner.Check(not Audio.playing and Game.get_meta("NAAudioFinished", 0) == 1, "Scene natural audio completion dispatches once")

    var DetachedContainer := Node.new()
    DetachedContainer.name = "NADetachContainer"
    Game.add_child(DetachedContainer)
    var DetachedOwner: Node = Runner.CreateScript("ServerScript", "NADetachOwner", """
local Scope = Scene.new(script.Parent)
Scope.Name = 'NADetachScope'
Scope:New('Node3D', {Name='Child'})
game:SetAttribute('NADetachReady', true)
""", DetachedContainer)
    if not await Runner.Until("NADetachReady"):
        return
    var DetachedScope := DetachedContainer.get_node("NADetachScope")
    var DetachedChild := DetachedScope.get_node("Child")

    for Type in ["ServerScript", "LocalScript"]:
        var Marker: String = "NAForeign" + Type
        var Foreign: Node = Runner.CreateScript(Type, Marker, """
local Foreign = game:FindFirstChild('NativeAuthoring')
local Display = Foreign:FindFirstChild('Root'):FindFirstChild('Display')
assert(Foreign.Name == 'NativeAuthoring' and Foreign.ClassName == 'SceneScope')
assert(Display.Position == Vector3.new(0, 0, 0) and Display.ClassName == 'MeshInstance3D')
assert(Display == Foreign:FindFirstChild('Root'):FindFirstChild('Display'))
assert(not pcall(function() Foreign.Name = 'Stolen' end))
assert(not pcall(function() Display.Position = Vector3.new(9, 9, 9) end))
assert(not pcall(function() return Display.Mesh end))
assert(not pcall(function() return Foreign.New end))
assert(not pcall(function() Foreign:Destroy() end))
local LegacyDestroy, LegacyClone, LegacyClear = game.Destroy, game.Clone, game.ClearAllChildren
assert(type(LegacyDestroy) == 'function' and type(LegacyClone) == 'function' and type(LegacyClear) == 'function')
assert(not pcall(function() LegacyDestroy(Foreign) end))
assert(not pcall(function() LegacyClone(Foreign) end))
assert(not pcall(function() LegacyClear(Foreign) end))
local Own = Scene.new(script.Parent)
assert(not pcall(function() Foreign.Parent = Own end))
assert(not pcall(function() game:FindFirstChild('NADetachContainer').Parent = Own end))
if not __IS_CLIENT then
    local Saved = shared.NativeAuthoring
    assert(not pcall(function() Saved.Configure(Saved.Scope, Saved.Display, {Name='Stolen'}) end))
    assert(not pcall(function() Own:New('MeshInstance3D', {Mesh=Saved.Mesh}) end))
    assert(not pcall(function() Own:Configure(Saved.Material, {Roughness=0}) end))
end
Own:Destroy()
game:SetAttribute('%s', true)
""" % Marker, Game)
        if not await Runner.Until(Marker):
            return
        Foreign.queue_free()
        await Host.process_frame
    Runner.Check(Display.name == "Display" and Display.position == Vector3.ZERO and Scope.name == "NativeAuthoring", "Scene Server/Client foreign-owner rejection leaves native state unchanged")
    Runner.Check(DetachedContainer.get_parent() == Game and DetachedScope.get_parent() == DetachedContainer, "Scene foreign scope/container parenting is rejected")
    DetachedContainer.remove_child(DetachedScope)
    Runner.Check(is_instance_valid(DetachedScope) and not DetachedScope.is_inside_tree(), "Scene detached lifetime setup")
    DetachedOwner.queue_free()
    await Host.process_frame
    await Host.process_frame
    Runner.Check(not is_instance_valid(DetachedScope) and not is_instance_valid(DetachedChild), "Scene owner destruction frees an already-retired detached scope")
    DetachedContainer.queue_free()

    var ForbiddenParent := RigidBody3D.new()
    ForbiddenParent.name = "NAForbiddenParent"
    ForbiddenParent.freeze = true
    Game.add_child(ForbiddenParent)
    Runner.CreateScript("ServerScript", "NAForbiddenOwner", """
assert(not pcall(function() Scene.new(script.Parent) end))
game:SetAttribute('NAParentRejected', true)
""", ForbiddenParent)
    if not await Runner.Until("NAParentRejected"):
        return
    Runner.Check(ForbiddenParent.get_child_count() == 1, "Scene physical parent rejection creates no scope")
    ForbiddenParent.queue_free()

    Game.set_meta("NAGcStart", true)
    if not await Runner.Until("NAGcRetained"):
        return
    Runner.Check(CollectedResource.get_ref() != null and Consumer.mesh != null, "Scene GC preserves resources held by a native consumer")
    Game.set_meta("NAGcRelease", true)
    if not await Runner.Until("NAGcReleased"):
        return
    Runner.Check(Consumer.mesh == null and CollectedResource.get_ref() == null, "Scene GC releases the last unconsumed resource handle")

    var ReloadOwner: Node = Runner.CreateScript("ServerScript", "NAReloadOwner", """
local Scope = Scene.new(script.Parent)
Scope.Name = 'NAReloadScope'
local Mesh = Scope:New('BoxMesh', {Size=Vector3.new(1, 1, 1)})
Scope:New('MeshInstance3D', {Name='Display', Mesh=Mesh})
local Button = Scope:New('Button', {Name='Button'})
shared.NativeAuthoringReload = {Scope=Scope, Resource=Mesh, New=Scope.New,
    Connection=Scope:Connect(Button, 'Pressed', function() error('retired callback ran') end)}
game:SetAttribute('NAReloadReady', true)
""", Game)
    if not await Runner.Until("NAReloadReady"):
        return
    var OldScope := Game.get_node("NAReloadScope")
    var ReloadResource: WeakRef = weakref((OldScope.get_node("Display") as MeshInstance3D).mesh)
    var OldButton := OldScope.get_node("Button")
    var ReloadScript: Script = ReloadOwner.call("get_codigo_luau")
    ReloadScript.source_code = """
local Saved = shared.NativeAuthoringReload
assert(not Saved.Connection.Connected)
Saved.Connection:Disconnect()
assert(not pcall(function() Saved.New(Saved.Scope, 'Node3D', {}) end))
local Scope = Scene.new(script.Parent)
Scope.Name = 'NAReloadReplacement'
assert(not pcall(function() Scope:Configure(Saved.Resource, {Size=Vector3.new(2, 2, 2)}) end))
assert(not pcall(function() Scope:New('MeshInstance3D', {Mesh=Saved.Resource}) end))
game:SetAttribute('NAReloaded', true)
"""
    if not await Runner.Until("NAReloaded"):
        return
    await Host.process_frame
    await Host.process_frame
    Runner.Check(not is_instance_valid(OldScope) and not is_instance_valid(OldButton) and ReloadResource.get_ref() == null, "Scene reload destroys old native graph and clears retained resource slots")
    ReloadOwner.queue_free()
    await Host.process_frame
    await Host.process_frame
    Runner.Check(Game.get_node_or_null("NAReloadReplacement") == null, "Scene replacement owner destruction retires its scope")

    var CallbackOwner: Node = Runner.CreateScript("ServerScript", "NACallbackOwner", """
local Scope = Scene.new(script.Parent)
Scope.Name = 'NACallbackScope'
local Button = Scope:New('Button', {Name='Button'})
Scope:Connect(Button, 'Pressed', function()
    game:SetAttribute('NACallbackEntered', true)
    script:Destroy()
    task.wait()
    game:SetAttribute('NAStaleCallbackResumed', true)
end)
game:SetAttribute('NACallbackReady', true)
""", Game)
    if not await Runner.Until("NACallbackReady"):
        return
    var CallbackButton := Game.get_node("NACallbackScope/Button") as Button
    CallbackButton.pressed.emit()
    for Index in range(4):
        await Host.process_frame
    Runner.Check(Game.has_meta("NACallbackEntered") and not Game.has_meta("NAStaleCallbackResumed"), "Scene callback owner destruction cancels yielded continuation")
    Runner.Check(not is_instance_valid(CallbackOwner) and not is_instance_valid(CallbackButton) and Game.get_node_or_null("NACallbackScope") == null, "Scene callback reentrancy retires native scope safely")

    Owner.queue_free()
    await Host.process_frame
    await Host.process_frame
    Runner.Check(not is_instance_valid(Scope) and not is_instance_valid(Display) and RetiredResource.get_ref() == null, "Scene owner destruction releases native subtree and resources despite retained Luau handles")
    var Witness: Node = Runner.CreateScript("ServerScript", "NAWitness", """
local Saved = shared.NativeAuthoring
assert(not Saved.Primary.Connected and not Saved.Secondary.Connected)
Saved.Primary:Disconnect()
assert(not pcall(function() Saved.Configure(Saved.Scope, Saved.Display, {Name='Stale'}) end))
local Scope = Scene.new(script.Parent)
Scope.Name = 'NAWitnessScope'
assert(not pcall(function() Scope:New('MeshInstance3D', {Mesh=Saved.Mesh}) end))
assert(not pcall(function() Scope:Configure(Saved.Material, {Roughness=0}) end))
Scope:Destroy()
shared.NativeAuthoring = nil
shared.NativeAuthoringReload = nil
game:SetAttribute('NAStaleChecked', true)
""", Game)
    if not await Runner.Until("NAStaleChecked"):
        return
    Witness.queue_free()
    await Host.process_frame
    await Host.process_frame
    Runner.Check(Game.get_node_or_null("NativeAuthoring") == null and Game.get_node_or_null("NAWitnessScope") == null, "Scene all transient authoring graphs cleaned up")
    Runner.Check(DirAccess.remove_absolute(ProjectSettings.globalize_path(AssetPath)) == OK, "Scene temporary project mesh removed")
    Runner.Check(DirAccess.remove_absolute(ProjectSettings.globalize_path(DeniedAssetPath)) == OK, "Scene temporary denied resource removed")
    if not Runner.Failed:
        print("[Scene:Qualification] PASS")
