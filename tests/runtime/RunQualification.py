"""Bounded cross-platform fixture/benchmark runner; writes only the chosen output tree."""
import argparse
import ctypes
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import time


def Rss(Process):
    if os.name != "nt":
        try:
            for Line in Path(f"/proc/{Process.pid}/status").read_text().splitlines():
                if Line.startswith("VmRSS:"):
                    return int(Line.split()[1]) * 1024
        except FileNotFoundError:
            pass
    return None


def Port():
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as Probe:
        Probe.bind(("127.0.0.1", 0))
        return Probe.getsockname()[1]


def Prepare(Output, Extension):
    Output.mkdir(parents=True, exist_ok=True)
    Cache = Output / ".godot"
    Cache.mkdir(exist_ok=True)
    (Cache / "global_script_class_cache.cfg").write_text("list=[]\n")
    Suffix = ".dll" if os.name == "nt" else ".so"
    shutil.copyfile(Extension, Output / ("godot_luau" + Suffix))
    (Output / "project.godot").write_text('config_version=5\n[application]\nconfig/name="GodotLuauQualification"\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="GodotLuauRuntimeQualification"\n[threading]\nworker_pool/max_threads=2\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
    Platform = "windows" if os.name == "nt" else "linux"
    (Output / "godot_luau.gdextension").write_text('[configuration]\nentry_symbol="luau_extension_init"\ncompatibility_minimum="4.3"\n[libraries]\n' + "\n".join(f'{Platform}.{Config}.x86_64="res://godot_luau{Suffix}"' for Config in ("debug", "release")))
    for Script in Path(__file__).parent.glob("*.gd"):
        shutil.copyfile(Script, Output / Script.name)


def Start(Godot, Output, Script, Label, Extra, Environment):
    Stdout = open(Output / (Label + ".stdout.log"), "w")
    Stderr = open(Output / (Label + ".stderr.log"), "w")
    Flags = {"creationflags": subprocess.CREATE_NO_WINDOW} if os.name == "nt" else {}
    Process = subprocess.Popen([str(Godot), "--headless", "--disable-crash-handler", "--single-threaded-scene", "--path", str(Output), "--script", "res://" + Script, "--", *Extra], stdout=Stdout, stderr=Stderr, env=Environment, **Flags)
    Stdout.close()
    Stderr.close()
    return Process


def Check(Process, Deadline, Output, Label, Marker):
    try:
        Result = Process.wait(timeout=max(0.1, Deadline - time.monotonic()))
    except subprocess.TimeoutExpired:
        Process.kill()
        Process.wait()
        raise RuntimeError(f"Timeout: {Label}")
    Text = (Output / (Label + ".stdout.log")).read_text(errors="replace")
    Errors = (Output / (Label + ".stderr.log")).read_text(errors="replace")
    if Result != 0 or Marker not in Text or "ERROR: AddressSanitizer" in Errors or "LeakSanitizer" in Errors:
        raise RuntimeError(f"{Label} exit={Result}\n{Text[-4000:]}\n{Errors[-6000:]}")
    return {"Label": Label, "Exit": Result, "Diagnostics": Errors.strip()}


def Fixtures(Args, Output, Environment):
    Results = []
    for Index in range(Args.repeat):
        Label = f"integration-{Index}"
        Process = Start(Args.godot, Output, "Integration.gd", Label, [], Environment)
        Results.append(Check(Process, time.monotonic() + Args.timeout, Output, Label, "[Runtime:Integration] PASS"))
    for Mode in ("Listen", "Dedicated", "Editor"):
        for Index in range(Args.repeat):
            Entries = []
            try:
                Ready = Output / "server.ready"
                Ready.unlink(missing_ok=True)
                for Marker in Output.glob("client*.closed"):
                    Marker.unlink()
                SelectedPort = 25575 if Mode == "Editor" else Port()
                if Mode == "Editor":
                    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as Probe:
                        Probe.bind(("127.0.0.1", SelectedPort))
                Roles = ["listen"] if Mode == "Listen" else ["server", "client1", "client2"]
                for Role in Roles:
                    FixtureRole = "client" if Role.startswith("client") else Role
                    Extra = ["--fixture-role", FixtureRole, "--fixture-port", str(SelectedPort)]
                    if Args.teardown and FixtureRole == "client":
                        Extra += ["--fixture-teardown"]
                    if Args.coordinated_close:
                        Extra += ["--coordinated-close"]
                        if FixtureRole == "client":
                            Extra += ["--fixture-client-index", "1" if Role == "client1" else "2"]
                    if Mode == "Editor":
                        Extra += ["--glindex", {"server": "1", "client1": "2", "client2": "3"}[Role], "--glcount", "2", "--gldevice", "PC"]
                    elif Mode == "Dedicated":
                        Extra += ["--glserver", str(SelectedPort)] if Role == "server" else ["--glconnect", f"127.0.0.1:{SelectedPort}"]
                    Label = f"{Mode}-{Index}-{Role}"
                    Process = Start(Args.godot, Output, "NetworkIntegration.gd", Label, Extra, Environment)
                    Entries.append((Process, Label, FixtureRole))
                    if Role == "server":
                        Deadline = time.monotonic() + 10
                        while not Ready.exists():
                            if Process.poll() is not None or time.monotonic() > Deadline:
                                raise RuntimeError(f"Server failed readiness: {Label}")
                            time.sleep(0.02)
                Deadline = time.monotonic() + Args.timeout
                for Process, Label, Role in Entries:
                    Results.append(Check(Process, Deadline, Output, Label, f"[Runtime:NetworkTest] {Role} PASS"))
            finally:
                for Process, _, _ in Entries:
                    if Process.poll() is None:
                        Process.kill()
                        Process.wait()
    return Results


def Benchmark(Args, Output, Environment):
    Results = []
    Stage = Output / "benchmark-stage.json"
    for Count in Args.counts:
        for Trial in range(Args.repeat):
            Configurations = [("Baseline", Args.baseline), ("Shared", Args.extension)]
            if Trial % 2:
                Configurations.reverse()
            for Mode, Extension in Configurations:
                Prepare(Output, Extension)
                Stage.unlink(missing_ok=True)
                Path(str(Stage) + ".ack").unlink(missing_ok=True)
                Label = f"benchmark-{Mode}-{Count}-{Trial}"
                Process = Start(Args.godot, Output, "Benchmark.gd", Label, [str(Count), str(Stage)], Environment)
                Deadline = time.monotonic() + Args.timeout
                Seen = set()
                try:
                    while Process.poll() is None and time.monotonic() < Deadline:
                        if Stage.exists():
                            try:
                                Values = json.loads(Stage.read_text())
                            except (ValueError, OSError):
                                time.sleep(0.005)
                                continue
                            if Values["Phase"] not in Seen:
                                Values.update(Mode=Mode, Trial=Trial, RssBytes=Rss(Process))
                                Results.append(Values)
                                Seen.add(Values["Phase"])
                                Path(str(Stage) + ".ack").touch()
                        time.sleep(0.005)
                    Check(Process, Deadline, Output, Label, "[Runtime:Benchmark] PASS")
                    if len(Seen) != 5:
                        raise RuntimeError(f"Incomplete benchmark: {Label} {Seen}")
                    (Output / "benchmark-results.json").write_text(json.dumps(Results, indent=2))
                finally:
                    if Process.poll() is None:
                        Process.kill()
                        Process.wait()
    return Results


def SecurityFixtures(Args, Output, Environment):
    Results = []
    for Mode in Args.security_modes:
        Project = Output / Mode
        Prepare(Project, Args.extension)
        Entries = []
        try:
            SelectedPort = Port()
            Roles = ["server"] if Mode == "Local" else ["server", "client1", "client2"]
            for Role in Roles:
                FixtureRole = "client" if Role.startswith("client") else "server"
                Extra = ["--fixture-role", FixtureRole, "--fixture-port", str(SelectedPort), "--security-mode", Mode]
                if FixtureRole == "client":
                    Extra += ["--fixture-client-index", Role[-1]]
                elif Mode in ("Dedicated", "Handler"):
                    Extra += ["--glserver", str(SelectedPort)]
                Label = f"security-{Mode}-{Role}"
                Process = Start(Args.godot, Project, "NetworkSecurity.gd", Label, Extra, Environment)
                Entries.append((Process, Label, FixtureRole))
                if Role == "server" and Mode != "Local":
                    Deadline = time.monotonic() + 10
                    while not (Project / "security-ready").exists():
                        if Process.poll() is not None or time.monotonic() > Deadline:
                            raise RuntimeError(f"Security server failed readiness: {Label}")
                        time.sleep(0.02)
            Deadline = time.monotonic() + Args.timeout
            for Process, Label, Role in Entries:
                Result = Check(Process, Deadline, Project, Label, f"[Network:SecurityTest] {Role} PASS")
                if "[Network:SecurityTest] FAIL" in (Project / (Label + ".stdout.log")).read_text(errors="replace"):
                    raise RuntimeError(f"Security assertion failed: {Label}")
                Results.append(Result)
        finally:
            for Process, _, _ in Entries:
                if Process.poll() is None:
                    Process.kill()
                    Process.wait()
    return Results


def AnimationFixtures(Args, Output, Environment):
    Results = []
    for Mode in Args.animation_modes:
        Project = Output / Mode
        Prepare(Project, Args.extension)
        Entries = []
        try:
            SelectedPort = 25575 if Mode == "Editor" else Port()
            if Mode == "Editor":
                with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as Probe:
                    Probe.bind(("127.0.0.1", SelectedPort))
            Roles = ["server"] if Mode == "Local" else ["server", "client1", "client2"]
            for Role in Roles:
                FixtureRole = "client" if Role.startswith("client") else "server"
                Extra = ["--fixture-role", FixtureRole, "--fixture-port", str(SelectedPort), "--animation-mode", Mode]
                if FixtureRole == "client":
                    Extra += ["--fixture-client-index", Role[-1]]
                if Mode == "Editor":
                    Extra += ["--glindex", {"server": "1", "client1": "2", "client2": "3"}[Role], "--glcount", "2", "--gldevice", "PC"]
                elif Mode == "Dedicated" and Role == "server":
                    Extra += ["--glserver", str(SelectedPort)]
                Label = f"animation-{Mode}-{Role}"
                Process = Start(Args.godot, Project, "AnimationIntegration.gd", Label, Extra, Environment)
                Entries.append((Process, Label, FixtureRole))
                if Role in ("server", "client1") and Mode != "Local":
                    Marker = "ready" if Role == "server" else "latejoin"
                    Deadline = time.monotonic() + Args.timeout
                    while not (Project / ("animation-" + Marker)).exists():
                        if Process.poll() is not None or time.monotonic() > Deadline:
                            raise RuntimeError(f"Animation readiness failed: {Label}")
                        time.sleep(0.02)
            Deadline = time.monotonic() + Args.timeout
            for Process, Label, Role in Entries:
                Results.append(Check(Process, Deadline, Project, Label, f"[Network:AnimationTest] {Role} PASS"))
        finally:
            for Process, _, _ in Entries:
                if Process.poll() is None:
                    Process.kill()
                    Process.wait()
    return Results


def Probes(Args, Output, Environment):
    Output = Output / "engine-only"
    Output.mkdir(exist_ok=True)
    (Output / "project.godot").write_text("config_version=5\n[threading]\nworker_pool/max_threads=2\n")
    shutil.copyfile(Path(__file__).parent / "ENetDisconnectProbe.gd", Output / "ENetDisconnectProbe.gd")
    Results = []
    for Trial in range(Args.repeat):
        for Relay, Dispatch, Expected in (("true", "none", True), ("false", "none", False), ("false", "sync", True), ("false", "deferred", False), ("true", "deferred", True)):
            Label = f"probe-{Trial}-{Relay}-{Dispatch}"
            Process = Start(Args.godot, Output, "ENetDisconnectProbe.gd", Label, [str(Port()), Relay, Dispatch], Environment)
            Result = Check(Process, time.monotonic() + Args.timeout, Output, Label, "[Network:Probe] PASS")
            Result["ZeroChannelDiagnostics"] = Result["Diagnostics"].count("max channels: 0")
            if bool(Result["ZeroChannelDiagnostics"]) != Expected:
                raise RuntimeError(f"Unexpected probe outcome: {Result}")
            Results.append(Result)
    return Results


def Main():
    Parser = argparse.ArgumentParser()
    Parser.add_argument("--godot", type=Path, required=True)
    Parser.add_argument("--extension", type=Path, required=True)
    Parser.add_argument("--output", type=Path, required=True)
    Parser.add_argument("--baseline", type=Path)
    Parser.add_argument("--asan-runtime", type=Path)
    Parser.add_argument("--teardown", action="store_true")
    Parser.add_argument("--security", action="store_true")
    Parser.add_argument("--animation", action="store_true")
    Parser.add_argument("--animation-modes", nargs="+", choices=("Local", "Listen", "Dedicated", "Editor"), default=["Local", "Listen", "Dedicated", "Editor"])
    Parser.add_argument("--security-modes", nargs="+", choices=("Local", "Listen", "Dedicated", "Handler"), default=["Local", "Listen", "Dedicated", "Handler"])
    Parser.add_argument("--probe", action="store_true")
    Parser.add_argument("--counts", type=int, nargs="+", default=[10, 100, 1000])
    Parser.add_argument("--runtime-directory", type=Path)
    Parser.add_argument("--load-only", action="store_true")
    Parser.add_argument("--coordinated-close", action="store_true")
    Parser.add_argument("--repeat", type=int, default=1)
    Parser.add_argument("--timeout", type=float, default=45)
    Args = Parser.parse_args()
    Args.godot, Args.extension, Args.output = Args.godot.resolve(), Args.extension.resolve(), Args.output.resolve()
    if os.name == "nt":
        ctypes.windll.kernel32.SetErrorMode(0x8003)
    Prepare(Args.output, Args.extension)
    if Args.runtime_directory:
        for Library in Args.runtime_directory.glob("*.dll"):
            shutil.copyfile(Library, Args.output / Library.name)
    Environment = dict(os.environ, GODOT_SILENCE_ROOT_WARNING="1")
    if Args.asan_runtime:
        Environment["LD_PRELOAD"] = str(Args.asan_runtime.resolve())
    if Args.load_only:
        Process = Start(Args.godot, Args.output, "SanitizerLoadProbe.gd", "load", [], Environment)
        Results = [Check(Process, time.monotonic() + Args.timeout, Args.output, "load", "[Runtime:LoadProbe] PASS")]
    elif Args.security:
        Results = SecurityFixtures(Args, Args.output, Environment)
    elif Args.animation:
        Results = AnimationFixtures(Args, Args.output, Environment)
    elif Args.probe:
        Results = Probes(Args, Args.output, Environment)
    elif Args.baseline:
        Results = Benchmark(Args, Args.output, Environment)
    else:
        Results = Fixtures(Args, Args.output, Environment)
    (Args.output / "results.json").write_text(json.dumps(Results, indent=2))
    print(f"[Runtime:Qualification] PASS {len(Results)} results at {Args.output}")


if __name__ == "__main__":
    Main()
