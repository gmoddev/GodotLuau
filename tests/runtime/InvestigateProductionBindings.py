"""Compare unchanged production unload with diagnostic binding retirement.

This investigation cannot qualify production: the trace library changes binding
dispatch and its retirement mode is deliberately an experimental intervention.
"""
import argparse
import ctypes
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
    for Name in ['godot', 'extension', 'trace', 'output']:
        Parser.add_argument('--' + Name, type=Path, required=True)
    Args = Parser.parse_args()
    for Name in vars(Args): setattr(Args, Name, getattr(Args, Name).resolve())
    Args.output.mkdir(parents=True, exist_ok=False)
    if os.name == 'nt': ctypes.windll.kernel32.SetErrorMode(0x8003)
    Results = []
    def Hash(File): return hashlib.sha256(File.read_bytes()).hexdigest()
    try:
        for Label, Mode in [('registration', None), ('production', None), ('observe', 'observe'), ('retire', 'retire')]:
            Directory = Args.output / Label
            Directory.mkdir()
            (Directory / '.godot').mkdir()
            (Directory / '.godot/global_script_class_cache.cfg').write_text('list=[]\n')
            (Directory / 'project.godot').write_text('config_version=5\n[application]\nconfig/name="ProductionBindingIsolation"\n[threading]\nworker_pool/max_threads=2\n')
            shutil.copy2(Path(__file__).with_name('SanitizerLifecycle.gd'), Directory / 'SanitizerLifecycle.gd')
            Library = Args.trace if Mode else Args.extension
            shutil.copy2(Library, Directory / Library.name)
            Entry = 'NativeBindingTraceInit' if Mode else 'luau_extension_init'
            Platform = 'windows' if os.name == 'nt' else 'linux'
            (Directory / 'godot_luau.gdextension').write_text('[configuration]\nentry_symbol="' + Entry + '"\ncompatibility_minimum="4.3"\n[libraries]\n' + Platform + '.x86_64="res://' + Library.name + '"\n')
            if os.name == 'nt':
                for File in Args.godot.parent.glob('*.dll'): shutil.copy2(File, Directory / File.name)
            Environment = dict(os.environ, GODOT_SILENCE_ROOT_WARNING='1')
            for Name in ['LD_PRELOAD', 'LSAN_OPTIONS', 'GL_NATIVE_SANITIZER_CONTROL', 'GL_NATIVE_TRACE_MODE', 'GL_NATIVE_TRACE_EXTENSION']:
                Environment.pop(Name, None)
            Environment['ASAN_OPTIONS'] = 'halt_on_error=1:' + ('detect_leaks=1:' if os.name != 'nt' else '') + 'log_path="' + (Directory / 'asan-report').as_posix() + '"'
            if Mode:
                Environment.update(GL_NATIVE_TRACE_MODE=Mode, GL_NATIVE_TRACE_EXTENSION=str(Args.extension))
            Command = [str(Args.godot), '--headless', '--disable-crash-handler', '--single-threaded-scene', '--path', str(Directory), '--script', 'res://SanitizerLifecycle.gd', '--', '--mode', 'registration' if Label == 'registration' else 'vm-cycles', '--cycles', '5']
            Started = time.monotonic()
            Code, TimedOut = None, False
            with (Directory / 'stdout.log').open('w') as Out, (Directory / 'stderr.log').open('w') as Err:
                Child = StartProcess(Command, Out, Err, Environment)
                try:
                    try: Code = Child.wait(timeout=90)
                    except subprocess.TimeoutExpired: TimedOut = True
                finally: StopProcess(Child)
            Text = (Directory / 'stdout.log').read_text(errors='replace')
            Results.append({'Label': Label, 'Exit': Code, 'TimedOut': TimedOut, 'ElapsedSeconds': time.monotonic() - Started,
                            'LifecyclePASS': '[Runtime:SanitizerLifecycle] PASS' in Text,
                            'Command': Command, 'ASAN_OPTIONS': Environment['ASAN_OPTIONS'],
                            'TraceMode': Mode, 'Extension': str(Args.extension), 'BindingDiagnostics': [Line for Line in Text.splitlines() if '[Runtime:BindingTrace]' in Line]})
            (Args.output / 'results.json').write_text(json.dumps(Results, indent=2))
            print('[Runtime:ProductionBindings]', Label, 'exit=', Code, 'timeout=', TimedOut, flush=True)
        Files = {str(File.relative_to(Args.output)): Hash(File) for File in sorted(Args.output.rglob('*')) if File.is_file() and (File.suffix in ['.log', '.json', '.gd', '.gdextension', '.godot'] or File.name.startswith('asan-report'))}
        (Args.output / 'investigation.json').write_text(json.dumps({'Scope': 'Diagnostic intervention only; not full-native acceptance or a production fix', 'GodotSHA256': Hash(Args.godot), 'ExtensionSHA256': Hash(Args.extension), 'TraceSHA256': Hash(Args.trace), 'Results': Results, 'Files': Files}, indent=2))
    finally: StopAll()


if __name__ == '__main__': Main()
