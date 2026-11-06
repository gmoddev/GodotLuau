extends SceneTree

func _initialize() -> void:
    call_deferred("Run")

func Run() -> void:
    var Baseline := "--baseline" in OS.get_cmdline_user_args()
    if GDExtensionManager.load_extension("res://godot_luau.gdextension") not in [GDExtensionManager.LOAD_STATUS_OK,GDExtensionManager.LOAD_STATUS_ALREADY_LOADED]:
        quit(1)
        return
    var Records := []
    var Cases := [{"Mode":"Raw","Count":0},{"Mode":"Raw","Count":1},{"Mode":"Raw","Count":16},{"Mode":"Raw","Count":64}]
    if not Baseline:
        for Count in [1,16,64,256]: Cases.append({"Mode":"Semantic","Count":Count})
        for Count in [16,64,256]: Cases.append({"Mode":"Sparse","Count":Count})
    for Case in Cases:
        var Game := Node.new()
        Game.name = "Game"
        root.add_child(Game)
        current_scene = Game
        var Raw: Node = ClassDB.instantiate("UserInputService")
        Raw.name = "UserInputService"
        Game.add_child(Raw)
        var Owner: Node = ClassDB.instantiate("LocalScript")
        var Source: Script = ClassDB.instantiate("LuauScript")
        var Setup := "local Count=0\nlocal function OnPress() Count+=1 end\n"
        if Case.Mode=="Raw":
            Setup += "local S=game:GetService('UserInputService'); for I=1,"+str(Case.Count)+" do S.InputBegan:Connect(OnPress) end\n"
        else:
            var Code := "(I==1 and Enum.KeyCode.W or Enum.KeyCode.Q)" if Case.Mode=="Sparse" else "Enum.KeyCode.W"
            Setup += "local C=game:GetService('InputService'):AddContext('Benchmark'); for I=1,"+str(Case.Count)+" do local A=C:AddAction('Action'..I); A:AddBinding("+Code+"); A.Pressed:Connect(OnPress) end\n"
        Source.source_code = Setup+"shared.ReadInputCount=function() return Count end; game:SetAttribute('Ready',true)"
        Owner.call("set_codigo_luau",Source)
        Game.add_child(Owner)
        await create_timer(0.08).timeout
        if not Game.get_meta("Ready",false): quit(1); return
        var Down := InputEventKey.new()
        Down.keycode = KEY_W
        Down.pressed = true
        var Up := InputEventKey.new()
        Up.keycode = KEY_W
        Up.pressed = false
        var Flush := Raw.has_method("_CommitInput")
        var Samples := []
        var FrameCPU := []
        # 32 immutable events/burst, 8 warm bursts, 64 measured bursts. Explicit
        # post-GUI flush includes candidate admission/dispatch in the same CPU
        # measurement as baseline immediate dispatch. Frame waiting is excluded.
        for Sample in range(72):
            var Begin := Time.get_ticks_usec()
            for Pair in range(16): root.push_input(Down,true); root.push_input(Up,true)
            if Flush: Raw.call("_CommitInput")
            var Elapsed := Time.get_ticks_usec()-Begin
            if Sample>=8: Samples.append(Elapsed)
            await process_frame
            if Sample>=8: FrameCPU.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000)
        var Snapshot: Node = ClassDB.instantiate("LocalScript")
        var SnapshotSource: Script = ClassDB.instantiate("LuauScript")
        SnapshotSource.source_code = "game:SetAttribute('Observed',shared.ReadInputCount())"
        Snapshot.call("set_codigo_luau",SnapshotSource)
        Game.add_child(Snapshot)
        await create_timer(0.04).timeout
        var Expected: int = (1 if Case.Mode=="Sparse" else int(Case.Count))*72*16
        if int(Game.get_meta("Observed",-1))!=Expected:
            print("[Input:Performance] FAIL callback count ",Case," expected=",Expected," actual=",Game.get_meta("Observed",-1))
            quit(1)
            return
        Records.append({"Mode":Case.Mode,"Count":Case.Count,"EventsPerBurst":32,"WarmBursts":8,"MeasuredBursts":64,"Callbacks":Expected,"CPUMicroseconds":Samples,"FrameProcessMilliseconds":FrameCPU})
        Game.free()
        await process_frame
        await process_frame
    FileAccess.open("res://input-performance.json",FileAccess.WRITE).store_string(JSON.stringify({"Baseline":Baseline,"Records":Records}))
    print("[Input:Performance] PASS")
    quit(0)
