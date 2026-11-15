extends SceneTree

func _initialize() -> void:
    call_deferred('Run')

func Run() -> void:
    var Inputs: Dictionary=JSON.parse_string(FileAccess.get_file_as_string('res://inputs.json'))
    var World=Node3D.new()
    root.add_child(World)
    current_scene=World
    var Old=ClassDB.instantiate('ServerScript')
    Old.set('codigo_luau',load('res://DebuggerReattachOld.luau'))
    World.add_child(Old)
    var Deadline=Time.get_ticks_msec()+20000
    while (not World.get_meta('ReattachOldContinued',false) or not FileAccess.file_exists(Inputs.Coordination+'/new-generation.json')) and Time.get_ticks_msec()<Deadline:
        await process_frame
    var Box=World.find_child('OldBox',true,false)
    var BoxId=Box.get_instance_id() if Box else 0
    var Fresh=ClassDB.instantiate('ServerScript')
    Fresh.set('codigo_luau',load('res://DebuggerReattachNew.luau'))
    World.add_child(Fresh)
    while World.get_meta('ReattachDone',0)!=43 and Time.get_ticks_msec()<Deadline:
        await process_frame
    var Passed=World.get_meta('ReattachDone',0)==43 and BoxId!=0 and is_instance_id_valid(BoxId)
    Old.queue_free()
    await process_frame
    await process_frame
    Passed=Passed and not is_instance_id_valid(BoxId)
    print('[Debugger:Target] ', 'PASS' if Passed else 'FAIL', ' same-transport reattachment admits a fresh generation and preserves owner cleanup')
    World.queue_free()
    await process_frame
    await process_frame
    quit(0 if Passed else 1)
