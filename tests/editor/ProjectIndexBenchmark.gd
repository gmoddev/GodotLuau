@tool
extends EditorPlugin

func _enter_tree() -> void:
    call_deferred("Run")

func Run() -> void:
    await get_tree().process_frame
    while EditorInterface.get_resource_filesystem().is_scanning():
        await get_tree().process_frame
    var Plugins = get_tree().root.find_children("*", "GLNativeEditorPlugin", true, false)
    var Passed = Plugins.size() == 1
    var Measurements: Dictionary = {"GeneratedModules": 256}
    if Passed:
        DirAccess.make_dir_recursive_absolute("res://IndexWorkload")
        var Source = "export type Result = {Value: number}\n"
        for Index in range(128):
            Source += "local Value%d = %d\n" % [Index, Index]
        Source += "local function Build(): Result return {Value=Value127} end\nreturn {Build=Build}\n"
        for Index in range(256):
            var File = FileAccess.open("res://IndexWorkload/Module%03d.luau" % Index, FileAccess.WRITE)
            if not File:
                Passed = false
                break
            File.store_string(Source)
            File.close()
        Measurements.GeneratedBytes = Source.to_utf8_buffer().size() * 256
        for Mode in ["Cold", "Warming", "Warm", "Cached"]:
            var Before = OS.get_static_memory_usage()
            var Started = Time.get_ticks_usec()
            var Report: Dictionary = Plugins[0].call("IndexProject", "", "")
            var Elapsed = Time.get_ticks_usec() - Started
            var Entries = 0
            for Document in Report.get("Documents", []):
                Entries += Document.get("Entries", []).size()
            Measurements[Mode] = {"ElapsedMicroseconds": Elapsed, "NativeMicroseconds": Report.get("Microseconds", 0), "ScannedFiles": Report.get("ScannedFiles", 0), "ParsedFiles": Report.get("ParsedFiles", 0), "CachedFiles": Report.get("CachedFiles", 0), "Entries": Entries, "Truncated": Report.get("Truncated", false), "StaticMemoryBefore": Before, "StaticMemoryAfter": OS.get_static_memory_usage()}
            Passed = Passed and Report.get("result", ERR_UNAVAILABLE) == OK and Report.get("ScannedFiles", 0) <= 256 and Entries <= 4096 and Report.get("Truncated", false)
    var File = FileAccess.open("res://editor-results.json", FileAccess.WRITE)
    File.store_string(JSON.stringify({"Passed": Passed, "Checks": [{"Passed": Passed, "Message": "Actual bounded native index returns explicit truncation for the generated large-project workload"}], "Measurements": Measurements}, "  "))
    File.close()
    print("[Bindings:EditorIntegration] %s large-project native index measurement" % ("PASS" if Passed else "FAIL"))
    get_tree().quit(0 if Passed else 1)
