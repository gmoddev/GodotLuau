"""Bounded cross-platform fixture/benchmark runner; writes only the chosen output tree."""
import argparse
import ctypes
import json
import os
from pathlib import Path
import re
import shutil
import signal
import socket
import subprocess
import sys
import time
from FixtureProcesses import StartProcess, StopProcess, StopAll


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
    Worker=Extension.parent/('godot_luau_store_worker.exe' if os.name=='nt' else 'godot_luau_store_worker')
    if Worker.is_file():
        shutil.copy2(Worker,Output/Worker.name)
    (Output / "project.godot").write_text('config_version=5\n[application]\nconfig/name="GodotLuauQualification"\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="GodotLuauRuntimeQualification"\n[threading]\nworker_pool/max_threads=2\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
    Platform = "windows" if os.name == "nt" else "linux"
    (Output / "godot_luau.gdextension").write_text('[configuration]\nentry_symbol="luau_extension_init"\ncompatibility_minimum="4.3"\n[libraries]\n' + "\n".join(f'{Platform}.{Config}.x86_64="res://godot_luau{Suffix}"' for Config in ("debug", "release")))
    for Script in Path(__file__).parent.glob("*.gd"):
        shutil.copyfile(Script, Output / Script.name)


def Start(Godot, Output, Script, Label, Extra, Environment):
    with open(Output / (Label + ".stdout.log"), "w") as Stdout, open(Output / (Label + ".stderr.log"), "w") as Stderr:
        Command = [str(Godot), "--headless", "--disable-crash-handler", "--single-threaded-scene", "--path", str(Output), "--script", "res://" + Script, "--", *Extra]
        if os.name == 'posix' and Label.startswith('resource-'):
            Command = [sys.executable, '-c',
                       'import os,resource,sys; resource.setrlimit(resource.RLIMIT_CPU,(30,30)); resource.setrlimit(resource.RLIMIT_CORE,(0,0)); os.execv(sys.argv[1],sys.argv[1:])', *Command]
        return StartProcess(Command, Stdout, Stderr, Environment)


def Check(Process, Deadline, Output, Label, Marker):
    try:
        Result = Process.wait(timeout=max(0.1, Deadline - time.monotonic()))
    except subprocess.TimeoutExpired:
        StopProcess(Process)
        raise RuntimeError(f"Timeout: {Label}")
    finally:
        StopProcess(Process)
    Text = (Output / (Label + ".stdout.log")).read_text(errors="replace")
    Errors = (Output / (Label + ".stderr.log")).read_text(errors="replace")
    Combined = Text + '\n' + Errors
    Failure = re.search(r'\[(?:Runtime|Network):[^\]]+\][^\n]*\bFAIL\b', Combined)
    Sanitizer = re.search(r'(?:ERROR|SUMMARY): [^\n]*Sanitizer|LeakSanitizer|AddressSanitizer:DEADLYSIGNAL', Combined)
    if Result != 0 or Marker not in Text or Failure or Sanitizer or 'SCRIPT ERROR:' in Errors:
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
                    StopProcess(Process)
    return Results


def Benchmark(Args, Output, Environment):
    Results = []
    Stage = Output / "benchmark-stage.json"
    for Count in Args.counts:
        for Trial in range(Args.repeat):
            Configurations = [("Shared", Args.extension)]
            if Args.baseline:
                Configurations.insert(0, ("Baseline", Args.baseline))
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
                    StopProcess(Process)
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
                StopProcess(Process)
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
                StopProcess(Process)
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


def Resources(Args, Output, Environment):
    Results = []
    for Case in ['execution', 'module', 'callback', 'invoke', 'memory', 'tasks', 'shutdown', 'configuration']:
        Label = 'resource-' + Case
        Process = Start(Args.godot, Output, 'ResourceIntegration.gd', Label, [Case], Environment)
        Results.append(Check(Process, time.monotonic() + Args.timeout, Output, Label, '[Runtime:Resource] PASS ' + Case))
    return Results


def Filesystem(Args, Output, Environment):
    Results = []
    Process = Start(Args.godot, Output, 'FilesystemIntegration.gd', 'filesystem-capabilities', [], Environment)
    Results.append(Check(Process, time.monotonic() + Args.timeout, Output, 'filesystem-capabilities', '[Runtime:FilesystemTest] PASS enforced'))
    Entries = []
    try:
        for Role in ['writer', 'reader']:
            Label = 'filesystem-' + Role
            Process = Start(Args.godot, Output, 'FilesystemServices.gd', Label,
                            ['--filesystem-role', Role, '--glserver', str(Port())], Environment)
            Entries.append((Process, Label, Role))
        Deadline = time.monotonic() + Args.timeout
        for Process, Label, Role in Entries:
            Results.append(Check(Process, Deadline, Output, Label, '[Runtime:FilesystemTest] PASS ' + Role))
    finally:
        for Process, _, _ in Entries:
            StopProcess(Process)
    return Results


def Http(Args, Output, Environment):
    from HttpFixtureServer import Serve
    Results = []
    for Case in ['enabled', 'denied', 'lifecycle', 'tls']:
        Project = Output / Case
        Prepare(Project, Args.extension)
        ActorEnvironment = dict(Environment)
        for Name in ['APPDATA', 'LOCALAPPDATA', 'XDG_CONFIG_HOME', 'XDG_DATA_HOME', 'XDG_CACHE_HOME']:
            Directory = Project / 'profile' / Name
            Directory.mkdir(parents=True)
            ActorEnvironment[Name] = str(Directory)
        if Case == 'tls':
            shutil.copyfile(Path(__file__).with_name('HttpFixtureCA.pem'), Project / 'http-ca.pem')
            with (Project / 'project.godot').open('a') as Config:
                Config.write('\n[network]\ntls/certificate_bundle_override="res://http-ca.pem"\n')
        Label = 'http-' + Case
        State = None
        try:
            with Serve(Tls=Case == 'tls') as (State, Origin):
                Extra = ['--http-case', Case, '--http-origin', Origin]
                for Name, Value in State.Origins.items():
                    if Name != 'Http': Extra += ['--http-' + Name.lower(), Value]
                Process = Start(Args.godot, Project, 'HttpIntegration.gd', Label, Extra, ActorEnvironment)
                Result = Check(Process, time.monotonic() + Args.timeout, Project, Label, '[Runtime:HttpTest] PASS ' + Case)
        finally:
            if State is not None:
                (Project / 'server-results.json').write_text(json.dumps({'Hits': State.Hits, 'Connections': State.Connections}, indent=2))
        # Listener/connection cleanup has completed; observations are settled.
        if any(Hit['Path'].startswith('/forbidden') for Hit in State.Hits):
            raise RuntimeError('[Runtime:HttpTest] Rejected request reached loopback server: ' + Label)
        if Case == 'denied' and State.Hits:
            raise RuntimeError('[Runtime:HttpTest] Default denial performed network I/O')
        if Case == 'tls' and (State.Connections.get('Tls', 0) < 3 or any(State.Connections.get(Name, 0) == 0 for Name in ['Untrusted', 'Stall'])):
            raise RuntimeError('[Runtime:HttpTest] Required TLS path did not reach transport')
        for Kind in ['stdout', 'stderr']:
            Text = (Project / (Label + '.' + Kind + '.log')).read_text(errors='replace')
            if 'PrivateSentinel' in Text:
                raise RuntimeError('[Runtime:HttpTest] HTTP diagnostics leaked a supplied URL')
            ScriptErrors = [Line.strip() for Line in Text.splitlines() if '[Runtime:Script]' in Line]
            ExpectedOom = '[Runtime:Script] Oom: [Runtime:Memory] Domain VM allocation quota exceeded; domain retired'
            if any(Line != ExpectedOom or Case != 'lifecycle' for Line in ScriptErrors):
                raise RuntimeError('[Runtime:HttpTest] Unexpected script error in ' + Label)
        Results.append(Result)
    return Results


def Main():
    Parser = argparse.ArgumentParser()
    Parser.add_argument("--godot", type=Path, required=True)
    Parser.add_argument("--extension", type=Path, required=True)
    Parser.add_argument("--output", type=Path, required=True)
    Parser.add_argument("--baseline", type=Path)
    Parser.add_argument("--benchmark", action="store_true", help="Run candidate population workload without requiring a baseline binary")
    Parser.add_argument("--asan-runtime", type=Path)
    Parser.add_argument("--teardown", action="store_true")
    Parser.add_argument("--security", action="store_true")
    Parser.add_argument("--animation", action="store_true")
    Parser.add_argument("--resources", action="store_true")
    Parser.add_argument("--filesystem", action="store_true")
    Parser.add_argument("--http", action="store_true")
    Parser.add_argument("--datastore", action="store_true")
    Parser.add_argument("--datastore-probe", type=Path)
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
    if Args.repeat < 1 or Args.timeout <= 0:
        Parser.error('repeat and timeout must be positive')
    Args.godot, Args.extension, Args.output = Args.godot.resolve(), Args.extension.resolve(), Args.output.resolve()
    if os.name == "nt":
        ctypes.windll.kernel32.SetErrorMode(0x8003)
    Args.output.mkdir(parents=True, exist_ok=False)
    Prepare(Args.output, Args.extension)
    if Args.runtime_directory:
        for Library in Args.runtime_directory.glob("*.dll"):
            shutil.copyfile(Library, Args.output / Library.name)
    Environment = dict(os.environ, GODOT_SILENCE_ROOT_WARNING="1")
    for Name in ['APPDATA', 'LOCALAPPDATA', 'XDG_CONFIG_HOME', 'XDG_DATA_HOME', 'XDG_CACHE_HOME']:
        Directory = Args.output / 'profile' / Name
        Directory.mkdir(parents=True)
        Environment[Name] = str(Directory)
    (Args.output / 'profile/.gdignore').write_text('')
    if Args.asan_runtime:
        Environment["LD_PRELOAD"] = str(Args.asan_runtime.resolve())
    if Args.load_only:
        Process = Start(Args.godot, Args.output, "SanitizerLoadProbe.gd", "load", [], Environment)
        Results = [Check(Process, time.monotonic() + Args.timeout, Args.output, "load", "[Runtime:LoadProbe] PASS")]
    elif Args.security:
        Results = SecurityFixtures(Args, Args.output, Environment)
    elif Args.animation:
        Results = AnimationFixtures(Args, Args.output, Environment)
    elif Args.resources:
        Results = Resources(Args, Args.output, Environment)
    elif Args.filesystem:
        Results = Filesystem(Args, Args.output, Environment)
    elif Args.http:
        Results = Http(Args, Args.output, Environment)
    elif Args.datastore:
        from RunDatastoreQualification import Qualify, Native
        from types import SimpleNamespace
        Probe=Args.datastore_probe or Args.extension.parent/('DatastoreBackendProbe.exe' if os.name=='nt' else 'DatastoreBackendProbe')
        Results=Qualify(SimpleNamespace(godot=Args.godot,extension=Args.extension,timeout=Args.timeout,probe=Probe),Args.output,Environment)
        NativeResults=Native(Probe,Args.output/'native',Environment)
        (Args.output/'native-evidence.json').write_text(json.dumps(NativeResults,indent=2))
    elif Args.probe:
        Results = Probes(Args, Args.output, Environment)
    elif Args.baseline or Args.benchmark:
        Results = Benchmark(Args, Args.output, Environment)
    else:
        Results = Fixtures(Args, Args.output, Environment)
    (Args.output / "results.json").write_text(json.dumps(Results, indent=2))
    print(f"[Runtime:Qualification] PASS {len(Results)} results at {Args.output}")


if __name__ == "__main__":
    def Interrupt(Signum, Frame):
        raise SystemExit(128 + Signum)
    signal.signal(signal.SIGTERM, Interrupt)
    try:
        Main()
    finally:
        StopAll()
