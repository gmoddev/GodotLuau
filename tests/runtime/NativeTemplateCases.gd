extends RefCounted

func Run(Runner,Game: Node) -> void:
    for Profile in ["Empty","ThreeD","TwoD","UI"]:
        var Source := FileAccess.get_file_as_string("res://Template"+Profile+".luau")
        var Marker: String = "Template"+Profile+"Ready"
        var Owner = Runner.CreateScript("LocalScript","Template"+Profile,"local function Build()\n"+Source+"\nend\nBuild()\ngame:SetAttribute('"+Marker+"',true)",Game)
        if not await Runner.Until(Marker):
            return
        var Scopes := Game.find_children("*","SceneScope",false,false)
        var Scope: Node = Scopes.back()
        for Frame in range(12):
            await Runner.physics_frame
        if Profile=="UI":
            var Panel := Scope.get_node("UI/Panel") as PanelContainer
            Runner.Check(Panel.offset_left==24 and Panel.offset_right==-24 and Panel.anchor_right==1,"UI template applies layout preset before explicit margins")
            var Settings := Scope.get_node("UI/Panel/Tabs/Settings")
            (Settings.get_node("NameInput") as LineEdit).text="Developer"
            (Settings.get_node("Volume") as HSlider).value=75
            (Settings.get_node("Apply") as Button).pressed.emit()
            Runner.Check((Settings.get_node("Status") as Label).text.contains("Developer") and (Settings.get_node("Status") as Label).text.contains("75"),"UI template signal applies actual native text selection and slider values")
        elif Profile=="TwoD":
            var Body := Scope.get_node("Player") as CharacterBody2D
            Runner.Check(Body.velocity.y>0 and Body.position.y>160,"2D starter executes its real physics-phase controller")
        elif Profile=="ThreeD":
            Runner.Check(Scope.get_node("Cube") is MeshInstance3D,"3D starter preserves the existing native scene")
        Owner.queue_free()
        await Runner.process_frame
        await Runner.process_frame
        Runner.Check(not is_instance_valid(Scope),"Template "+Profile+" retires its owned native scene")
    print("[Authoring:Templates] PASS")
