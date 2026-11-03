"""Isolate engine instance-binding unload with a C ABI probe, without gameplay."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import time
from FixtureProcesses import StartProcess, StopProcess, StopAll


def Main():
    Parser = argparse.ArgumentParser(description=__doc__)
    for Name in ['godot', 'probe', 'output']:
        Parser.add_argument('--' + Name, type=Path, required=True)
    Args = Parser.parse_args()
    for Name in vars(Args): setattr(Args, Name, getattr(Args, Name).resolve())
    Args.output.mkdir(parents=True, exist_ok=False)
    Results = []
    if os.name == 'nt': __import__('ctypes').windll.kernel32.SetErrorMode(0x8003)
    try:
        for Mode in ['clean', 'binding-clean', 'binding']:
            Directory = Args.output / Mode
            Directory.mkdir()
            (Directory/'.godot').mkdir()
            (Directory/'.godot/global_script_class_cache.cfg').write_text('list=[]\n')
            (Directory/'project.godot').write_text('config_version=5\n[application]\nconfig/name="BindingIsolation"\n[threading]\nworker_pool/max_threads=2\n')
            shutil.copy2(Path(__file__).with_name('SanitizerLifecycle.gd'), Directory/'SanitizerLifecycle.gd')
            shutil.copy2(Args.probe, Directory/Args.probe.name)
            Platform = 'windows' if os.name == 'nt' else 'linux'
            (Directory/'godot_luau.gdextension').write_text('[configuration]\nentry_symbol="SanitizerProbeInit"\ncompatibility_minimum="4.3"\n[libraries]\n'+Platform+'.x86_64="res://'+Args.probe.name+'"\n')
            if os.name == 'nt':
                for File in Args.godot.parent.glob('*.dll'): shutil.copy2(File, Directory/File.name)
            Environment = dict(os.environ, GL_NATIVE_SANITIZER_CONTROL=Mode, GODOT_SILENCE_ROOT_WARNING='1')
            for Name in ['LD_PRELOAD', 'LSAN_OPTIONS']: Environment.pop(Name, None)
            Environment['ASAN_OPTIONS'] = 'halt_on_error=1:' + ('detect_leaks=1:' if os.name != 'nt' else '') + 'log_path="' + (Directory/'asan-report').as_posix() + '"'
            Command = [str(Args.godot), '--headless', '--disable-crash-handler', '--single-threaded-scene', '--path', str(Directory), '--script', 'res://SanitizerLifecycle.gd', '--', '--mode', 'minimal', '--cycles', '5']
            TimedOut = False
            Started = time.monotonic()
            with (Directory/'stdout.log').open('w') as Out, (Directory/'stderr.log').open('w') as Err:
                Child = StartProcess(Command, Out, Err, Environment)
                try:
                    try: Code = Child.wait(timeout=45)
                    except subprocess.TimeoutExpired: TimedOut, Code = True, None
                finally: StopProcess(Child)
            Text = (Directory/'stdout.log').read_text()
            Results.append({'Mode': Mode, 'Exit': Code, 'TimedOut': TimedOut, 'ElapsedSeconds': time.monotonic()-Started, 'Command': Command, 'ASAN_OPTIONS': Environment['ASAN_OPTIONS'], 'BindingsInstalled': Text.count('Engine singleton binding installed'), 'BindingsFreed': Text.count('Binding freed before library unload'), 'LifecyclePASS': '[Runtime:SanitizerLifecycle] PASS' in Text})
            print('[Runtime:SanitizerBindings]', Mode, 'exit=', Code, 'timeout=', TimedOut, flush=True)
        def Hash(File): return hashlib.sha256(File.read_bytes()).hexdigest()
        (Args.output/'binding-investigation.json').write_text(json.dumps({'Scope': 'Investigation only; crashes remain qualification failures', 'GodotSHA256': Hash(Args.godot), 'ProbeSHA256': Hash(Args.probe), 'Results': Results, 'Files': {str(File.relative_to(Args.output)): Hash(File) for File in sorted(Args.output.rglob('*')) if File.is_file() and (File.suffix in ['.log', '.json'] or File.name.startswith('asan-report'))}}, indent=2))
    finally: StopAll()


if __name__ == '__main__': Main()
