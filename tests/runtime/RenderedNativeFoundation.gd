extends "res://Integration.gd"
## Actual shipped acceptance projects on a renderer-enabled full-featured host.

func Run() -> void:
    if DisplayServer.get_name()=="headless":
        print("[Foundation:Rendered] FAIL requires a real renderer")
        quit(1)
        return
    var Status=GDExtensionManager.load_extension("res://godot_luau.gdextension")
    if Status!=GDExtensionManager.LOAD_STATUS_OK and Status!=GDExtensionManager.LOAD_STATUS_ALREADY_LOADED:
        quit(1)
        return
    Game=Node.new()
    Game.name="Game"
    root.add_child(Game)
    current_scene=Game
    await load("res://NativeFoundationCases.gd").new().Run(self,Game,true)
    Game.queue_free()
    await process_frame
    await process_frame
    print("[Foundation:Rendered] ","FAIL" if Failed else "PASS")
    quit(1 if Failed else 0)
