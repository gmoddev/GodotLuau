extends "res://Integration.gd"
## Use the established runner, with a renderer-enabled host and no --headless.
## This verifies renderer-backed native state; it does not establish visual quality.

func Run() -> void:
    var LoadResult := GDExtensionManager.load_extension("res://godot_luau.gdextension")
    Check(LoadResult==GDExtensionManager.LOAD_STATUS_OK or LoadResult==GDExtensionManager.LOAD_STATUS_ALREADY_LOADED,"Rendered extension loads before native actors")
    if Failed:
        quit(1)
        return
    if DisplayServer.get_name()=="headless":
        print("[Runtime:RenderedExpansion] FAIL Renderer is required")
        quit(1)
        return
    Game=Node.new()
    Game.name="Game"
    root.add_child(Game)
    current_scene=Game
    var Service: Node = ClassDB.instantiate("RunService")
    Service.name="RunService"
    Game.add_child(Service)
    await load("res://NativeExpansionCases.gd").new().Run(self,Game,true)
    Game.queue_free()
    await process_frame
    await process_frame
    print("[Runtime:RenderedExpansion] ","FAIL" if Failed else "PASS")
    quit(1 if Failed else 0)
