extends "res://DebuggerPeer.gd"

var OldGeneration = 0

func AfterVariables() -> void:
    if Finished:
        return
    Check(CurrentSource == "res://DebuggerReload.luau" and CurrentLine == Expected[Stops].Line and CurrentDomain == "Server", "Reload stop uses the actual selected Server source")
    if Finished:
        return
    if Stops == 0:
        OldGeneration = Variables.get("context: Generation", 0)
        Check(OldGeneration > 0 and Value("Value") == 1, "Old generation is suspended before mutation")
        var File = FileAccess.open(Inputs.TargetSource, FileAccess.WRITE)
        Check(File != null, "Open isolated saved source for controlled replacement")
        if Finished:
            return
        File.store_string("local Value = 41\nValue += 1\ngame:SetAttribute('ReloadDone', Value)\n")
        File.close()
        Command("Breakpoint", {"Domain": "Server", "Source": CurrentSource, "Line": 2, "Enabled": true})
        Command("Reload", {"Domain": "Server", "Source": CurrentSource})
    elif Stops == 1:
        Check(Variables.get("context: Generation", 0) > OldGeneration and Value("Value") == 41, "Reload admits a fresh live owner and remapped breakpoint")
        Send("continue")
    Stops += 1

func Receive(Message: Array) -> void:
    super.Receive(Message)
    if not Finished and Message.size() == 3 and Message[0] == "godotluau:debugger" and Message[2].size() == 1 and Message[2][0] is Dictionary and Message[2][0].get("Event") == "Reloaded":
        Check(true, "Saved-source reload is acknowledged before native Continue")
        Send("continue")
