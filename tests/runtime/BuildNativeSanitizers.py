"""Build all extension, binding, VM, companion and probe inputs with one compiler."""
import argparse
import ctypes
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
from FixtureProcesses import StartProcess, StopProcess, StopAll
from SourceFingerprint import GetFingerprint


def Main():
    Parser = argparse.ArgumentParser(description=__doc__)
    Parser.add_argument('--output', type=Path, required=True)
    Parser.add_argument('--jobs', type=int, default=2)
    Args = Parser.parse_args()
    if not 1 <= Args.jobs <= 4: Parser.error('Use 1–4 jobs')
    Root = Path(__file__).resolve().parents[2]
    Output = Args.output.resolve()
    Output.mkdir(parents=True, exist_ok=True)
    Logs = Output / ('attempt-' + str(__import__('time').time_ns()))
    Logs.mkdir()
    Environment = dict(os.environ)
    if os.name == 'nt': ctypes.windll.kernel32.SetErrorMode(0x8003)
    Compiler = shutil.which('cl' if os.name == 'nt' else 'clang++-19')
    if not Compiler: raise ValueError('Matching host compiler environment is required')
    Identity = {'Source': GetFingerprint(Root), 'Compiler': Compiler,
                'CompilerSHA256': hashlib.sha256(Path(Compiler).read_bytes()).hexdigest(),
                'Dependencies': {}, 'Commands': []}
    for Name in ['godot-cpp', 'luau']:
        Expected = subprocess.check_output(['git', 'rev-parse', 'HEAD:' + Name], cwd=Root, text=True, timeout=15).strip()
        Actual = subprocess.check_output(['git', '-C', str(Root / Name), 'rev-parse', 'HEAD'], text=True, timeout=15).strip()
        Dirty = subprocess.check_output(['git', '-C', str(Root / Name), 'status', '--porcelain', '--untracked-files=no'], text=True, timeout=15)
        if Actual != Expected or Dirty: raise ValueError('Missing, dirty or mismatched pinned dependency: ' + Name)
        Identity['Dependencies'][Name] = Actual
    Common = ['-G', 'Ninja', '-DCMAKE_BUILD_TYPE=Debug', '-DCMAKE_EXPORT_COMPILE_COMMANDS=ON']
    if os.name == 'nt':
        Common += ['-DCMAKE_CXX_FLAGS=/fsanitize=address', '-DCMAKE_C_FLAGS=/fsanitize=address', '-DCMAKE_CXX_FLAGS_DEBUG=/Zi /Od', '-DCMAKE_C_FLAGS_DEBUG=/Zi /Od', '-DCMAKE_EXE_LINKER_FLAGS=/INCREMENTAL:NO', '-DCMAKE_SHARED_LINKER_FLAGS=/INCREMENTAL:NO']
    else:
        Common += ['-DCMAKE_CXX_COMPILER=clang++-19', '-DCMAKE_C_COMPILER=clang-19', '-DCMAKE_CXX_FLAGS=-fsanitize=address -fno-omit-frame-pointer', '-DCMAKE_C_FLAGS=-fsanitize=address -fno-omit-frame-pointer', '-DCMAKE_EXE_LINKER_FLAGS=-fsanitize=address', '-DCMAKE_SHARED_LINKER_FLAGS=-fsanitize=address']

    def Run(Command, Name, Timeout):
        Code = None
        try:
            with (Logs / (Name + '.log')).open('w') as Log:
                Child = StartProcess([str(Value) for Value in Command], Log, subprocess.STDOUT, Environment)
                try: Code = Child.wait(timeout=Timeout)
                finally: StopProcess(Child)
        finally:
            Identity['Commands'].append({'Command':[str(Value) for Value in Command], 'Exit':Code,
                'LogSHA256':hashlib.sha256((Logs/(Name+'.log')).read_bytes()).hexdigest()})
            (Logs / 'identity.json').write_text(json.dumps(Identity, indent=2))
        if Code != 0: raise RuntimeError('Build failed: ' + Name + '; retained at ' + str(Logs))

    try:
        Run(['cmake', '-S', Root/'tests/runtime', '-B', Output/'native', *Common, '-DGL_BUILD_GODOT_ADAPTER=ON'], 'configure-native', 300)
        Run(['cmake', '--build', Output/'native', '--target', 'GodotLuauAdapter', 'ExecutionDomainTests', 'DatastoreBackendProbe', '--parallel', Args.jobs], 'build-native', 3600)
        Run(['cmake', '-S', Root/'tests/runtime/sanitizers', '-B', Output/'probes', *Common], 'configure-probes', 120)
        Run(['cmake', '--build', Output/'probes', '--parallel', Args.jobs], 'build-probes', 180)
        Suffix = '.dll' if os.name == 'nt' else '.so'
        ExecutableSuffix = '.exe' if os.name == 'nt' else ''
        Identity['Products'] = {Name: hashlib.sha256((Output/'native'/Name).read_bytes()).hexdigest()
                                for Name in ['godot_luau'+Suffix, 'godot_luau_store_worker'+ExecutableSuffix,
                                             'ExecutionDomainTests'+ExecutableSuffix, 'DatastoreBackendProbe'+ExecutableSuffix]}
        Identity['CompileCommandsSHA256'] = hashlib.sha256((Output/'native/compile_commands.json').read_bytes()).hexdigest()
        (Output/'build-identity.json').write_text(json.dumps(Identity, indent=2))
    finally: StopAll()


if __name__ == '__main__': Main()
