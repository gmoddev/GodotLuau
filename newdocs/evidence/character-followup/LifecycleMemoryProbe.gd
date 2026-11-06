extends "res://CharacterPresentation.gd"

func FreezeLife() -> void:
    var Character := World.get_node("LocalPlayer")
    Character.set_process(false)
    Character.set_physics_process(false)
    Character.call("GetPhysicsBody").set_process(false)

func Snapshot(Label: String) -> void:
    var Bytes := Performance.get_monitor(Performance.MEMORY_STATIC)
    var Objects := Performance.get_monitor(Performance.OBJECT_COUNT)
    var Nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
    print("[Character:MemoryProbe] ", JSON.stringify({"Label":Label,"Bytes":Bytes,"Objects":Objects,"Nodes":Nodes}))

func Run() -> void:
    Check(GDExtensionManager.load_extension("res://godot_luau.gdextension") in [GDExtensionManager.LOAD_STATUS_OK,GDExtensionManager.LOAD_STATUS_ALREADY_LOADED], "load")
    Game = Node.new()
    Game.name = "Game"
    root.add_child(Game)
    current_scene = Game
    Players = Create("Players", "Players")
    Create("Node", "SettingsMenu")
    World = Create("RobloxWorkspace", "Workspace")
    World.set_process(false)
    await Ticks(5)
    FreezeLife()
    Check(World.get_node("LocalPlayer").has_node("Torso"), "memory probe uses actual R6")
    for Attempt in range(100):
        Players.call("load_local_character")
        FreezeLife()
        await process_frame
    Snapshot("warm")
    var InitialObjects := Performance.get_monitor(Performance.OBJECT_COUNT)
    for Block in range(3):
        for Attempt in range(500):
            Players.call("load_local_character")
            FreezeLife()
            await process_frame
        await process_frame
        Snapshot("respawns-"+str((Block+1)*500))
        Check(Performance.get_monitor(Performance.OBJECT_COUNT)==InitialObjects, "no live object growth in separate 500-respawn block")
    var Samples := []
    Snapshot("before-retaining-samples")
    for Index in range(5):
        Samples.append({"Respawns":Index*25,"StaticMemoryBytes":Performance.get_monitor(Performance.MEMORY_STATIC),"Objects":Performance.get_monitor(Performance.OBJECT_COUNT),"Nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"Resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)})
    Snapshot("retained-five-samples")
    print("[Character:MemoryProbe] ", JSON.stringify({"Label":"original-sampler-delta","Bytes":Samples[4]["StaticMemoryBytes"]-Samples[0]["StaticMemoryBytes"],"Objects":Samples[4]["Objects"]-Samples[0]["Objects"]}))
    Samples.clear()
    await process_frame
    Snapshot("released-samples")
    Game.free()
    await process_frame
    print("[Character:MemoryProbe] ","FAIL" if Failed else "PASS")
    quit(1 if Failed else 0)
