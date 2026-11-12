extends RefCounted
## Execute the shipped projects; input injection is local to this fixture viewport.

func Key(Runner,Code: int,Pressed: bool) -> void:
    var Event := InputEventKey.new()
    Event.keycode=Code
    Event.pressed=Pressed
    Runner.root.push_input(Event,true)

func Run(Runner,Game: Node,Rendered := false) -> void:
    var Records: Array[Dictionary] = []
    for Profile in ["TwoD","UI","ThreeD"]:
        var Started := Time.get_ticks_usec()
        var Objects := Performance.get_monitor(Performance.OBJECT_COUNT)
        var Source := FileAccess.get_file_as_string("res://"+Profile+".luau")
        var Marker: String = "Foundation"+Profile+"Ready"
        var Owner = Runner.CreateScript("ServerScript" if Profile=="ThreeD" and not Rendered else "LocalScript","Foundation"+Profile,"local function Build()\n"+Source+"\nend\nBuild()\ngame:SetAttribute('"+Marker+"',true)",Game)
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
            if Rendered:
                var Body := Scope.get_node("Player") as CharacterBody3D
                var Camera := Body.find_children("*","Camera3D",false,false)[0] as Camera3D
                var CameraOffset := Camera.global_position-Body.global_position
                var GuideStart := Guide.position
                var GuideDistance := 0.0
                for Target in [Vector3(3,0,1),Vector3(-3,0,1),Vector3(0,0,-2)]:
                    for Frame in range(240):
                        var Difference: Vector3 = Target-Body.position
                        GuideDistance=maxf(GuideDistance,Guide.position.distance_to(GuideStart))
                        Key(Runner,KEY_D,Difference.x>0.15)
                        Key(Runner,KEY_A,Difference.x< -0.15)
                        Key(Runner,KEY_S,Difference.z>0.15)
                        Key(Runner,KEY_W,Difference.z< -0.15)
                        if Vector2(Difference.x,Difference.z).length()<0.25:
                            break
                        await Runner.physics_frame
                    for Code in [KEY_D,KEY_A,KEY_S,KEY_W]:
                        Key(Runner,Code,false)
                Runner.Check((Scope.get_node("HUD/Box/Status") as Label).text.contains("3 / 3"),"Shipped rendered 3D gameplay collects all markers through real input and physics")
                Runner.Check(Camera.is_current() and (Camera.global_position-Body.global_position).is_equal_approx(CameraOffset),"Shipped 3D camera follows the actual moving physics body")
                Runner.Check(GuideDistance>0.5,"Shipped navigation guide follows a real native path on the full-featured host")
                Runner.Check((Body.find_children("*","AnimationPlayer",false,false)[0] as AnimationPlayer).is_playing(),"Shipped 3D native animation remains playing during gameplay")
                (Scope.get_node("HUD/Box/Next") as Button).pressed.emit()
                await Runner.process_frame
                await Runner.process_frame
                Runner.Check(not is_instance_valid(Scope),"Shipped 3D next round retires its old native graph")
                Scope=Game.find_children("*","SceneScope",false,false).back()
                Runner.Check(Scope.get_node("Token1") is MeshInstance3D,"Shipped 3D next round constructs fresh marker state")
        Owner.queue_free()
        await Runner.process_frame
        await Runner.process_frame
        Runner.Check(not is_instance_valid(Scope),"Shipped "+Profile+" project owner retires native content")
    print("[Foundation:Acceptance] PASS ",JSON.stringify({"Graphical":Rendered,"Records":Records,"ThreeD":"real input physics navigation and round transition" if Rendered else "construction only; renderer gameplay requires rendered qualification"}))
