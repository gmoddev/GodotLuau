"""Capture bounded Linux child-debugger teardown evidence to durable output.

GDB observation is not leak-clean qualification; LSan is unsupported under ptrace.
The ordinary non-debugger run remains required and retains normal signal handling.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import time
from FixtureProcesses import StartProcess, StopProcess, StopAll


def Main():
    Parser = argparse.ArgumentParser(description=__doc__)
    for Name in ['godot', 'project', 'output']:
        Parser.add_argument('--' + Name, type=Path, required=True)
    Args = Parser.parse_args()
    if os.name == 'nt' or not shutil.which('gdb'): Parser.error('Linux with an existing GDB installation is required')
    for Name in vars(Args): setattr(Args, Name, getattr(Args, Name).resolve())
    Args.output.mkdir(parents=True, exist_ok=False)
    Commands = ['set pagination off', 'set confirm off', 'set print pretty on', 'set breakpoint pending on',
                'break GDExtension::close_library()',
                'commands\nsilent\ninfo sharedlibrary godot_luau\ncontinue\nend',
                'set environment ASAN_OPTIONS halt_on_error=1:detect_leaks=1:handle_segv=0',
                'run', 'info program', 'info threads', 'thread apply all bt full',
                'info sharedlibrary', 'info proc mappings', 'info registers', 'up', 'x/12i $pc-24']
    Command = ['gdb', '--batch']
    for Instruction in Commands: Command += ['-ex', Instruction]
    Command += ['--args', str(Args.godot), '--headless', '--disable-crash-handler', '--single-threaded-scene', '--path', str(Args.project), '--script', 'res://SanitizerLifecycle.gd', '--', '--mode', 'vm-cycles', '--cycles', '5']
    Environment = dict(os.environ, GODOT_SILENCE_ROOT_WARNING='1')
    for Name in ['LD_PRELOAD', 'LSAN_OPTIONS', 'GL_NATIVE_SANITIZER_CONTROL', 'GL_NATIVE_TRACE_MODE', 'GL_NATIVE_TRACE_EXTENSION']:
        Environment.pop(Name, None)
    Started = time.monotonic()
    Code, TimedOut = None, False
    try:
        # Open the durable destination before launching; close/fsync before the
        # result manifest. A disposable container must not own the only log copy.
        with (Args.output / 'gdb.log').open('w') as Log:
            Child = StartProcess(Command, Log, subprocess.STDOUT, Environment)
            try:
                try: Code = Child.wait(timeout=90)
                except subprocess.TimeoutExpired: TimedOut = True
            finally: StopProcess(Child)
            Log.flush()
            os.fsync(Log.fileno())
        def Hash(File): return hashlib.sha256(File.read_bytes()).hexdigest()
        Text = (Args.output / 'gdb.log').read_text(errors='replace')
        Signals = re.findall(r'received signal (SIG[A-Z0-9]+)', Text)
        Libraries = {}
        for Name in sorted(set(re.findall(r'(/[^\s]+\.so(?:\.[0-9]+)*)', Text))):
            File = Path(Name)
            if File.is_file(): Libraries[Name] = Hash(File)
        Record = {'Scope': 'Child debugger diagnosis, not sanitizer acceptance; LSan unsupported under ptrace',
                  'Command': Command, 'GdbExit': Code, 'TimedOut': TimedOut, 'ElapsedSeconds': time.monotonic() - Started,
                  'ObservedInferiorSignals': Signals, 'LoadedLibraryFiles': Libraries,
                  'GodotSHA256': Hash(Args.godot), 'LifecycleSHA256': Hash(Args.project / 'SanitizerLifecycle.gd'),
                  'ProjectLibraries': {File.name: Hash(File) for File in sorted(Args.project.glob('*.so'))},
                  'LogSHA256': Hash(Args.output / 'gdb.log'), 'LogBytes': (Args.output / 'gdb.log').stat().st_size}
        (Args.output / 'diagnostic.json').write_text(json.dumps(Record, indent=2))
        print('[Runtime:SanitizerDiagnosis] Captured', Record['LogBytes'], 'bytes; GDB exit', Code, flush=True)
    finally: StopAll()


if __name__ == '__main__': Main()
