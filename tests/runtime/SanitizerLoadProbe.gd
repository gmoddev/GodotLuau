extends SceneTree

func _initialize() -> void:
    call_deferred("Run")

func Run() -> void:
    var Loaded := GDExtensionManager.load_extension("res://godot_luau.gdextension")
    assert(Loaded == GDExtensionManager.LOAD_STATUS_OK or Loaded == GDExtensionManager.LOAD_STATUS_ALREADY_LOADED)
    print("[Runtime:LoadProbe] Extension registered; no game, scripts, domains or network peer created")
    print("[Runtime:LoadProbe] PASS")
    quit(0)
