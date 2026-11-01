"""Build a pinned, instrumented headless Godot host without changing engine source."""
import argparse
import ctypes
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import time
import urllib.request
from FixtureProcesses import StartProcess, StopProcess, StopAll


def Hash(File):
    return hashlib.sha256(Path(File).read_bytes()).hexdigest()


def Main():
    Parser = argparse.ArgumentParser(description=__doc__)
    Parser.add_argument('--output', type=Path, required=True)
    Parser.add_argument('--archive', type=Path)
    Parser.add_argument('--jobs', type=int, default=2)
    Parser.add_argument('--timeout', type=int, default=7200)
    Args = Parser.parse_args()
    if not 1 <= Args.jobs <= 4 or not 1 <= Args.timeout <= 10800:
        Parser.error('Use 1–4 jobs and a finite timeout of at most three hours')
    Platform = 'Windows' if os.name == 'nt' else 'Linux'
    PolicyFile = Path(__file__).with_name('SanitizerHosts.json')
    Policy = json.loads(PolicyFile.read_text())
    Output = Args.output.resolve()
    Output.parent.mkdir(parents=True, exist_ok=True)
    Archive = Args.archive.resolve() if Args.archive else Output.parent / 'godot-sanitizer-source.tar.gz'
    URL = 'https://codeload.github.com/godotengine/godot/tar.gz/' + Policy['EngineRevision']
    if not Archive.exists():
        Started = time.monotonic()
        Temporary = Archive.with_suffix('.partial')
        with urllib.request.urlopen(URL, timeout=30) as Response, Temporary.open('xb') as File:
            while Block := Response.read(1024 * 1024):
                File.write(Block)
                if time.monotonic() - Started > 240:
                    raise TimeoutError('Pinned source download exceeded four minutes')
        Temporary.replace(Archive)
    if Hash(Archive) != Policy['ArchiveSHA256']:
        raise ValueError('Godot source archive hash mismatch')
    Prefix = 'godot-' + Policy['EngineRevision'] + '/'
    if not Output.exists():
        Temporary = Output.with_name(Output.name + '-extract')
        Temporary.mkdir(exist_ok=False)
        with tarfile.open(Archive) as Tar:
            for Member in Tar.getmembers():
                if Member.name != Prefix[:-1] and not Member.name.startswith(Prefix):
                    raise ValueError('Unexpected source archive root')
            Tar.extractall(Temporary, filter='data')
        (Temporary / Prefix[:-1]).rename(Output)
        Temporary.rmdir()
    # Reused source/build caches must still match every original archive file.
    SourceHashes = {}
    with tarfile.open(Archive) as Tar:
        for Member in Tar:
            if not Member.isfile():
                continue
            Name = Member.name.removeprefix(Prefix)
            Expected = hashlib.sha256(Tar.extractfile(Member).read()).hexdigest()
            if Hash(Output / Name) != Expected:
                raise ValueError('Modified engine source: ' + Name)
            SourceHashes[Name] = Expected
    Environment = dict(os.environ)
    Version = subprocess.check_output([sys.executable, '-c', 'import SCons; print(SCons.__version__)'], env=Environment, timeout=30).decode().strip()
    if Version != Policy['SCons']:
        raise ValueError('Use the hash-pinned SCons version in tools/ReleaseBuildRequirements.txt')
    Compiler = shutil.which('cl' if Platform == 'Windows' else 'clang++-19')
    if not Compiler:
        raise ValueError('Matching compiler/developer environment is required')
    Arguments = Policy['Common'] + Policy[Platform]
    Command = [sys.executable, '-m', 'SCons', *Arguments, '-j' + str(Args.jobs)]
    Attempts = Output.parent / (Output.name + '-attempts')
    Attempts.mkdir(exist_ok=True)
    Attempt = Attempts / str(time.time_ns())
    Attempt.mkdir(exist_ok=False)
    Identity = {'Platform': Platform, 'EngineRevision': Policy['EngineRevision'],
                'ArchiveSHA256': Hash(Archive), 'PolicySHA256': Hash(PolicyFile),
                'OriginalSourceFiles': len(SourceHashes),
                'OriginalSourceIndexSHA256': hashlib.sha256(json.dumps(SourceHashes, sort_keys=True).encode()).hexdigest(),
                'Compiler': Compiler, 'CompilerSHA256': Hash(Compiler), 'SCons': Version,
                'Command': Command, 'Timeout': Args.timeout, 'Scope': Policy['Scope']}
    (Attempt / 'inputs.json').write_text(json.dumps(Identity, indent=2))
    if os.name == 'nt':
        ctypes.windll.kernel32.SetErrorMode(0x8003)
    Previous = Path.cwd()
    Code = None
    try:
        os.chdir(Output)
        with (Attempt / 'build.log').open('w') as Log:
            Child = StartProcess(Command, Log, subprocess.STDOUT, Environment)
            if os.name == 'nt':
                if not ctypes.windll.kernel32.SetPriorityClass(ctypes.c_void_p(int(Child._handle)), 0x4000):
                    raise ctypes.WinError()
            try:
                Code = Child.wait(timeout=Args.timeout)
            finally:
                StopProcess(Child)
    finally:
        os.chdir(Previous)
        Identity.update(Exit=Code, BuildLogSHA256=Hash(Attempt / 'build.log'))
        (Attempt / 'result.json').write_text(json.dumps(Identity, indent=2))
        StopAll()
    if Code != 0:
        raise RuntimeError('Sanitized Godot build failed; original attempt retained at ' + str(Attempt))
    Products = [File for File in (Output / 'bin').glob('godot*') if File.is_file()
                and (File.suffix == '.exe' if os.name == 'nt' else os.access(File, os.X_OK))
                and '.console.' not in File.name]
    if len(Products) != 1:
        raise ValueError('Expected exactly one native Godot host executable')
    RuntimeHashes = {}
    if os.name == 'nt':
        SanitizerDLLs = list(Path(Compiler).parent.glob('clang_rt.asan*.dll'))
        DebugCRT = sorted((Path(Compiler).parents[6] / 'Redist/MSVC').glob('*/debug_nonredist/x64/Microsoft.VC*.DebugCRT'))
        if not SanitizerDLLs or not DebugCRT:
            raise ValueError('Matching MSVC ASan and Debug CRT runtime DLLs are missing')
        for Runtime in [*SanitizerDLLs, *DebugCRT[-1].glob('*.dll')]:
            shutil.copy2(Runtime, Products[0].parent / Runtime.name)
            RuntimeHashes[Runtime.name] = Hash(Runtime)
    Identity.update(Executable=str(Products[0]), ExecutableSHA256=Hash(Products[0]), RuntimeDLLs=RuntimeHashes)
    (Output / 'sanitizer-host.json').write_text(json.dumps(Identity, indent=2))
    print('[Runtime:SanitizerHost] Built ' + Platform + ' ' + Identity['ExecutableSHA256'])


if __name__ == '__main__':
    Main()
