extends "res://DebuggerPeer.gd"

func AfterVariables() -> void:
    if Finished:
        return
    Check(CurrentSource == "res://DebuggerNetwork.luau" and CurrentLine == Expected[0].Line and CurrentDomain == "Server" and Value("Value") == 41, "Actual network server Luau frame pauses before mutation")
    var Deadline = Time.get_ticks_msec() + 5000
    while not FileAccess.file_exists(Inputs.Coordination + "/client-timeout") and Time.get_ticks_msec() < Deadline and not Finished:
        await process_frame
    Check(FileAccess.file_exists(Inputs.Coordination + "/client-timeout"), "Independent ENet client reports timeout while the server main thread is paused")
    if not Finished:
        Send("continue")
        Stops += 1
