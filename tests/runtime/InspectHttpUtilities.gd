extends SceneTree

func _initialize() -> void:
    call_deferred("Run")

func Run() -> void:
    assert(GDExtensionManager.load_extension("res://godot_luau.gdextension") == GDExtensionManager.LOAD_STATUS_OK)
    var Game := Node.new()
    Game.name = "Game"
    root.add_child(Game)
    current_scene = Game
    var ScriptNode: Node = ClassDB.instantiate("ServerScript")
    var Code: Script = ClassDB.instantiate("LuauScript")
    Code.source_code = """
local H=game:GetService('HttpService')
local Input=utf8.char(0x96ea)..string.char(0)..' /%?#&=+~._-'
print('[Runtime:HttpUtilities] UTF8=', H:UrlEncode(Input))
for _,Byte in {0,65,126,128,170,233,255} do
 print('[Runtime:HttpUtilities] Byte=', Byte, ' Encoded=', H:UrlEncode(string.char(Byte)))
end
game:SetAttribute('Inspected',true)
"""
    ScriptNode.call("set_codigo_luau", Code)
    Game.add_child(ScriptNode)
    var Deadline := Time.get_ticks_msec() + 5000
    while not Game.get_meta("Inspected", false) and Time.get_ticks_msec() < Deadline:
        await process_frame
    var Passed := bool(Game.get_meta("Inspected", false))
    Game.queue_free()
    await process_frame
    await process_frame
    quit(0 if Passed else 1)
