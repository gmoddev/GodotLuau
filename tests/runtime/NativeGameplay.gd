extends "res://Integration.gd"
## Reuse the actual gameplay cases on the provisioned full-featured official host.

func Run() -> void:
    var Status=GDExtensionManager.load_extension("res://godot_luau.gdextension")
    if Status!=GDExtensionManager.LOAD_STATUS_OK and Status!=GDExtensionManager.LOAD_STATUS_ALREADY_LOADED:
        quit(1)
        return
    Game=Node.new()
    Game.name="Game"
    root.add_child(Game)
    current_scene=Game
    await load("res://NativeGameplayCases.gd").new().Run(self,Game,true)
    Game.queue_free()
    await process_frame
    await process_frame
    quit(1 if Failed else 0)
