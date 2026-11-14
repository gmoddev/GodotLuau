extends SceneTree

func _initialize() -> void:
    call_deferred('Run')

func Run() -> void:
    var World=Node3D.new()
    root.add_child(World)
    current_scene=World
    var Entry=ClassDB.instantiate('ServerScript')
    Entry.set('codigo_luau',load('res://DebuggerConditional.luau'))
    World.add_child(Entry)
    var Deadline=Time.get_ticks_msec()+15000
    while World.get_meta('ConditionalDone',0)!=15 and Time.get_ticks_msec()<Deadline:
        await process_frame
    var Passed=World.get_meta('ConditionalDone',0)==15 and not World.has_meta('Bypass')
    print('[Debugger:Target] ', 'PASS' if Passed else 'FAIL', ' conditional stops preserve gameplay and forbid evaluation side effects')
    World.queue_free()
    await process_frame
    await process_frame
    quit(0 if Passed else 1)
