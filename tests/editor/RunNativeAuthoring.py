"""Run the real Godot ScriptEditor native-language path in an isolated editor."""
import argparse
import ctypes
import hashlib
import json
import os
from pathlib import Path
import shutil
import sys
import time

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "runtime"))
from RunQualification import Prepare, Check
from FixtureProcesses import StartProcess, StopAll, GetProfileFolder


def Main():
    Parser = argparse.ArgumentParser()
    Parser.add_argument("--godot", type=Path, required=True)
    Parser.add_argument("--extension", type=Path, required=True)
    Parser.add_argument("--output", type=Path, required=True)
    Parser.add_argument("--timeout", type=float, default=60)
    Args = Parser.parse_args()
    Output = Args.output.resolve()
    Output.mkdir(parents=True, exist_ok=False)
    Prepare(Output, Args.extension.resolve())
    (Output / ".godot/extension_list.cfg").write_text('res://godot_luau.gdextension\n')
    Plugin = Output / "addons/NativeEditor"
    Plugin.mkdir(parents=True)
    shutil.copyfile(Path(__file__).with_name("NativeAuthoring.gd"), Plugin / "plugin.gd")
    (Plugin / "plugin.cfg").write_text('[plugin]\nname="NativeEditorFixture"\ndescription="Bounded GL-051 editor integration"\nauthor="GodotLuau"\nversion="1"\nscript="plugin.gd"\n')
    with (Output / "project.godot").open("a") as File:
        File.write('[editor_plugins]\nenabled=PackedStringArray("res://addons/NativeEditor/plugin.cfg")\n')
    (Output / "NativeEditor.lua").write_text('local Scope = Scene.new(script.Parent)\nlocal Button = Scope:New("Button", {Text="Native editor"})\nerror("[Bindings:Editor] Editor source must never execute")\n')
    Environment = dict(os.environ, GODOT_SILENCE_ROOT_WARNING="1")
    for Name in ["APPDATA", "LOCALAPPDATA", "XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_CACHE_HOME"]:
        Environment[Name] = str(GetProfileFolder(Output, Name))
    GetProfileFolder(Output, "").joinpath(".gdignore").write_text("")
    if os.name == "nt":
        ctypes.windll.kernel32.SetErrorMode(0x8003)
    Command = [str(Args.godot.resolve()), "--headless", "--disable-crash-handler", "--single-threaded-scene", "--editor", "--path", str(Output)]
    with (Output / "editor.stdout.log").open("w") as Stdout, (Output / "editor.stderr.log").open("w") as Stderr:
        Process = StartProcess(Command, Stdout, Stderr, Environment)
    Result = Check(Process, time.monotonic() + Args.timeout, Output, "editor", "[Bindings:EditorIntegration] PASS")
    assert "Required virtual method LuauLanguage::" not in (Output / "editor.stderr.log").read_text(errors="replace"), "Missing required language metadata hook"
    Detail = json.loads((Output / "editor-results.json").read_text())
    assert Detail["Passed"], Detail
    Result.update(Detail, Command=Command, ExtensionSHA256=hashlib.sha256(Args.extension.read_bytes()).hexdigest())
    (Output / "results.json").write_text(json.dumps(Result, indent=2))
    print("[Bindings:EditorQualification] PASS", Output)


if __name__ == "__main__":
    try:
        Main()
    finally:
        StopAll()
