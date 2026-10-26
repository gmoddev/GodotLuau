extends "res://Benchmark.gd"

# Captured native module removes hierarchy/property lookup from the hot loop.
# Count is calls here; the existing population benchmark remains unchanged.
func Run() -> void:
    var Loaded := GDExtensionManager.load_extension("res://godot_luau.gdextension")
    assert(Loaded == GDExtensionManager.LOAD_STATUS_OK or Loaded == GDExtensionManager.LOAD_STATUS_ALREADY_LOADED)
    Game = Node.new()
    Game.name = "Game"
    root.add_child(Game)
    current_scene = Game
    var Storage := Node.new()
    Storage.name = "ReplicatedStorage"
    Game.add_child(Storage)
    ScriptNode("ModuleScript", "Counter", "local Value = 0; for Index = 1, 100 do Value += Index end; return {Value = Value}", Storage)
    var Source := """
local Module = game.ReplicatedStorage.Counter
local Started = os.clock()
local Counter = require(Module)
assert(Counter.Value == 5050)
game:SetAttribute('ColdMs', (os.clock() - Started) * 1000)
Started = os.clock()
for Index = 1, %d do assert(require(Module) == Counter) end
game:SetAttribute('HotMs', (os.clock() - Started) * 1000)
game:SetAttribute('Done', true)
""" % Count
    ScriptNode("ServerScript", "Caller", Source, Game)
    while not Game.get_meta("Done", false): await process_frame
    var File := FileAccess.open(Output, FileAccess.WRITE)
    File.store_string(JSON.stringify({"Calls": Count, "ColdMs": Game.get_meta("ColdMs"), "HotMs": Game.get_meta("HotMs")}))
    File.close()
    Game.queue_free()
    await process_frame
    print("[Runtime:RequireBenchmark] PASS")
    quit(0)
