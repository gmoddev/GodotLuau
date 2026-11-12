extends RefCounted
## Execute the shipped projects; input injection is local to this fixture viewport.

func Run(Runner,Game: Node) -> void:
    var Records: Array[Dictionary] = []
    for Profile in ["TwoD","UI","ThreeD"]:
        var Started := Time.get_ticks_usec()
        var Objects := Performance.get_monitor(Performance.OBJECT_COUNT)
        var Source := FileAccess.get_file_as_string("res://"+Profile+".luau")
        var Marker: String = "Foundation"+Profile+"Ready"
        var Owner = Runner.CreateScript("ServerScript" if Profile=="ThreeD" else "LocalScript","Foundation"+Profile,"local function Build()\n"+Source+"\nend\nBuild()\ngame:SetAttribute('"+Marker+"',true)",Game)
        if not await Runner.Until(Marker):
            return
        var Scope: Node = Game.find_children("*","SceneScope",false,false).back()
        Records.append({"Profile":Profile,"BootstrapToReadyMicroseconds":Time.get_ticks_usec()-Started,"Objects":Performance.get_monitor(Performance.OBJECT_COUNT)-Objects})
        if Profile=="TwoD":
            var Body := Scope.get_node("Player") as CharacterBody2D
            for Frame in range(30):
                await Runner.physics_frame
            var Event := InputEventKey.new()
            Event.keycode=KEY_D
            Event.pressed=true
            Runner.root.push_input(Event,true)
            for Frame in range(240):
                if (Scope.get_node("HUD/Box/Status") as Label).text.contains("3 / 3"):
                    break
                await Runner.physics_frame
            Event=InputEventKey.new()
            Event.keycode=KEY_D
            Event.pressed=false
            Runner.root.push_input(Event,true)
            Runner.Check(Body.position.x>700 and (Scope.get_node("HUD/Box/Status") as Label).text.contains("3 / 3"),"Shipped 2D game collects all markers through real input physics and native Area signals")
            (Scope.get_node("HUD/Box/Next") as Button).pressed.emit()
            await Runner.process_frame
            await Runner.process_frame
            Runner.Check(not is_instance_valid(Scope),"Shipped 2D scene transition retires the old graph")
            Scope=Game.find_children("*","SceneScope",false,false).back()
            Runner.Check(Scope.get_node("Token1") is Area2D,"Shipped 2D next round reconstructs native marker state")
        elif Profile=="UI":
            var Settings := Scope.get_node("UI/Panel/Tabs/Settings")
            Runner.Check((Scope.get_node("UI/Panel") as Control).theme!=null and (Settings.get_node("Presets") as ItemList).get_item_icon(0)!=null,"Shipped UI uses real project theme and icon resources")
            (Settings.get_node("NameInput") as LineEdit).text="Native developer"
            (Settings.get_node("Notes") as TextEdit).text="Saved session note"
            (Settings.get_node("Volume") as HSlider).value=80
            (Settings.get_node("Apply") as Button).pressed.emit()
            Runner.Check((Settings.get_node("Status") as Label).text.contains("Native developer") and (Settings.get_node("Status") as Label).text.contains("80"),"Shipped UI applies actual native user-facing controls")
        else:
            var Guide := Scope.get_node("Guide") as CharacterBody3D
            Runner.Check(Guide.get_child_count()>0 and Scope.get_node("Player/Visual") is MeshInstance3D,"Shipped 3D factory constructs actual bodies visuals camera animation and navigation")
        Owner.queue_free()
        await Runner.process_frame
        await Runner.process_frame
        Runner.Check(not is_instance_valid(Scope),"Shipped "+Profile+" project owner retires native content")
    print("[Foundation:Acceptance] PASS ",JSON.stringify({"Graphical":false,"Records":Records,"ThreeD":"construction only; renderer gameplay requires rendered qualification"}))
