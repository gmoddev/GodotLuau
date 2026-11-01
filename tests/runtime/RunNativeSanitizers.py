"""Run existing production fixtures with an instrumented host and detection controls."""
import argparse
import ctypes
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time
from FixtureProcesses import StartProcess, StopProcess, StopAll
from SourceFingerprint import GetFingerprint


def Hash(File):
    return hashlib.sha256(Path(File).read_bytes()).hexdigest()


def Main():
    Parser = argparse.ArgumentParser(description=__doc__)
    for Name in ['godot', 'probe', 'loader', 'output']:
        Parser.add_argument('--' + Name, type=Path, required=True)
    for Name in ['extension', 'build', 'build-identity', 'host-manifest', 'asset-godot', 'asset-provenance']:
        Parser.add_argument('--' + Name, type=Path)
    Parser.add_argument('--revision', required=True)
    Parser.add_argument('--controls-only', action='store_true', help='Investigative profile; never full qualification')
    Args = Parser.parse_args()
    for Name, Value in vars(Args).items():
        if isinstance(Value, Path): setattr(Args, Name, Value.resolve())
    Args.output.mkdir(parents=True, exist_ok=False)
    Source = Path(__file__).resolve().parents[2]
    Runtime = Source / 'tests/runtime'
    if os.name == 'nt': ctypes.windll.kernel32.SetErrorMode(0x8003)
    Environment = dict(os.environ, GODOT_SILENCE_ROOT_WARNING='1')
    # Relative log paths avoid the ASAN_OPTIONS separator in Windows drive names.
    Environment['ASAN_OPTIONS'] = 'halt_on_error=1:log_path=asan-report'
    if os.name != 'nt': Environment['ASAN_OPTIONS'] += ':detect_leaks=1'
    for Name in ['LSAN_OPTIONS', 'GL_NATIVE_SANITIZER_CONTROL', 'LD_PRELOAD']:
        Environment.pop(Name, None)
    Previous = Path.cwd()
    os.chdir(Args.output)
    Results = []

    def Observe(Command, Label, Timeout=45, Extra=None, Expected=None):
        Case = Args.output / Label
        Case.mkdir(exist_ok=True)
        ChildEnvironment = dict(Environment)
        ChildEnvironment['ASAN_OPTIONS'] = Environment['ASAN_OPTIONS'].replace('log_path=asan-report', 'log_path=' + Label + '/asan-report')
        for Name in ['APPDATA', 'LOCALAPPDATA', 'XDG_CONFIG_HOME', 'XDG_DATA_HOME', 'XDG_CACHE_HOME']:
            Profile = Case / 'profile' / Name
            Profile.mkdir(parents=True)
            ChildEnvironment[Name] = str(Profile)
        if Extra: ChildEnvironment.update(Extra)
        Code, TimedOut = None, False
        Started = time.monotonic()
        with (Case / 'stdout.log').open('w') as Out, (Case / 'stderr.log').open('w') as Err:
            Child = StartProcess([str(Value) for Value in Command], Out, Err, ChildEnvironment)
            try:
                try: Code = Child.wait(timeout=Timeout)
                except subprocess.TimeoutExpired: TimedOut = True
            finally: StopProcess(Child)
        Text = '\n'.join(File.read_text(errors='replace') for File in [Case/'stdout.log', Case/'stderr.log', *Case.glob('asan-report*')] if File.is_file())
        Findings = bool(re.search(r'(?:ERROR|SUMMARY): [^\n]*Sanitizer|LeakSanitizer|AddressSanitizer:DEADLYSIGNAL|AddressSanitizer: CHECK failed', Text))
        Passed = not TimedOut and ((Code != 0 and Expected in Text and Findings) if Expected else (Code == 0 and not Findings))
        Record = {'Label': Label, 'Command': [str(Value) for Value in Command], 'Exit': Code,
                  'TimedOut': TimedOut, 'ElapsedSeconds': time.monotonic()-Started,
                  'ExpectedFinding': Expected, 'SanitizerFinding': Findings, 'Passed': Passed,
                  'ASAN_OPTIONS': ChildEnvironment['ASAN_OPTIONS']}
        Results.append(Record)
        (Args.output/'results.json').write_text(json.dumps(Results, indent=2))
        print('[Runtime:NativeSanitizers] ' + Label + ' ' + ('PASS' if Passed else 'FAIL'), flush=True)
        return Passed

    def Lifecycle(Label, Mode, Cycles, Library=None, Entry='luau_extension_init', Extra=None, Expected=None):
        Project = Args.output / Label / 'project'
        Project.mkdir(parents=True)
        (Project/'project.godot').write_text('config_version=5\n[application]\nconfig/name="NativeSanitizerLifecycle"\n[threading]\nworker_pool/max_threads=2\n')
        shutil.copy2(Runtime/'SanitizerLifecycle.gd', Project/'SanitizerLifecycle.gd')
        if Library:
            shutil.copy2(Library, Project/Library.name)
            Platform = 'windows' if os.name == 'nt' else 'linux'
            (Project/'godot_luau.gdextension').write_text('[configuration]\nentry_symbol="'+Entry+'"\ncompatibility_minimum="4.3"\n[libraries]\n'+ '\n'.join(Platform+'.'+Configuration+'.x86_64="res://'+Library.name+'"' for Configuration in ['debug','release'])+'\n')
            # Godot deliberately restricts dependency search on Windows. Keep
            # matching test runtimes adjacent to the DLL; never alter system DLLs.
            if os.name == 'nt':
                for File in Args.godot.parent.glob('*.dll'): shutil.copy2(File, Project/File.name)
        Passed = Observe([Args.godot, '--headless', '--disable-crash-handler', '--single-threaded-scene', '--path', Project, '--script', 'res://SanitizerLifecycle.gd', '--', '--mode', Mode, '--cycles', str(Cycles)], Label, 90, Extra, Expected)
        if Passed and not Expected:
            Record = json.loads((Project/'sanitizer-lifecycle.json').read_text())
            if Record['Result'] != 'PASS' or Record['Mode'] != Mode or Record['Cycles'] != Cycles or not all(Item['Passed'] for Item in Record['Checks']):
                raise ValueError('Lifecycle assertions missing/failed: ' + Label)
        return Passed

    try:
        Identity = {'Revision': Args.revision, 'NativeSource': GetFingerprint(Source),
                    'GodotSHA256': Hash(Args.godot), 'ProbeSHA256': Hash(Args.probe), 'LoaderSHA256': Hash(Args.loader),
                    'Scope': 'controls only' if Args.controls_only else 'headless full-native ASan; Linux LSan enabled; Windows LSan unsupported',
                    'Harness': {str(File.relative_to(Runtime)): Hash(File) for File in sorted(Runtime.rglob('*')) if File.is_file() and (File.suffix in ['.py','.gd','.cpp','.json'] or File.name == 'CMakeLists.txt') and '__pycache__' not in File.parts}}
        if not Args.controls_only:
            if any(Value is None for Value in [Args.extension, Args.build, Args.build_identity, Args.host_manifest, Args.asset_godot, Args.asset_provenance]):
                raise ValueError('Full qualification requires host/build and verified asset-editor identities')
            Host = json.loads(Args.host_manifest.read_text())
            Policy = json.loads((Runtime/'SanitizerHosts.json').read_text())
            if Host['Exit'] != 0 or Host['ExecutableSHA256'] != Hash(Args.godot) or Host['PolicySHA256'] != Hash(Runtime/'SanitizerHosts.json') or Host['EngineRevision'] != Policy['EngineRevision']:
                raise ValueError('Stale or mismatched instrumented host')
            for Name, Digest in Host['RuntimeDLLs'].items():
                if Hash(Args.godot.parent/Name) != Digest: raise ValueError('Sanitizer runtime DLL mismatch')
            Editor = json.loads(Args.asset_provenance.read_text())
            Distribution = json.loads((Runtime/'GodotDistribution.json').read_text())
            if Editor['SourceRevision'] != Host['EngineRevision'] or Editor['ExecutableSHA256'] != Hash(Args.asset_godot) or Editor['Asset'] != Distribution['Windows' if os.name == 'nt' else 'Linux'] or Editor['ArchiveSHA256'] != Editor['Asset']['SHA256'] or Editor['Version'] != Distribution['ExpectedVersionOutput']:
                raise ValueError('Asset editor is not the matching verified official distribution')
            Commands = json.loads((Args.build/'compile_commands.json').read_text())
            if len(Commands) < 100 or any(('fsanitize=address' not in Item.get('command', ' '.join(Item.get('arguments', [])))) for Item in Commands):
                raise ValueError('Entire native build, bindings and Luau must be instrumented')
            Cache = (Args.build/'CMakeCache.txt').read_text()
            Compiler = re.search(r'CMAKE_CXX_COMPILER:[^=]+=(.+)', Cache)
            CompilerPath = shutil.which(Compiler[1].strip()) if Compiler else None
            if not CompilerPath or Hash(CompilerPath) != Host['CompilerSHA256']:
                raise ValueError('Engine and extension compiler identities differ')
            BuildIdentity = json.loads(Args.build_identity.read_text())
            if BuildIdentity['Source'] != GetFingerprint(Source) or BuildIdentity['CompilerSHA256'] != Host['CompilerSHA256'] or BuildIdentity['CompileCommandsSHA256'] != Hash(Args.build/'compile_commands.json'):
                raise ValueError('Native source/compiler/build provenance mismatch')
            for Name, Digest in BuildIdentity['Products'].items():
                if Hash(Args.build/Name) != Digest: raise ValueError('Native product mismatch: ' + Name)
            if BuildIdentity['Products'].get(Args.extension.name) != Hash(Args.extension):
                raise ValueError('Fixture extension differs from qualified native product')
            Identity.update(Host=Host, AssetEditor=Editor, ExtensionSHA256=Hash(Args.extension), CompileCommandsSHA256=Hash(Args.build/'compile_commands.json'), InstrumentedFiles=len(Commands))
        (Args.output/'inputs.json').write_text(json.dumps(Identity, indent=2))
        Observe([Args.loader, Args.probe], 'standalone-clean')
        Observe([Args.loader, Args.probe], 'standalone-uaf', Extra={'GL_NATIVE_SANITIZER_CONTROL':'use-after-free'}, Expected='heap-use-after-free')
        Lifecycle('engine-only', 'engine', 1)
        Lifecycle('minimal-reload', 'minimal', 5, Args.probe, 'SanitizerProbeInit')
        Lifecycle('host-uaf', 'minimal', 1, Args.probe, 'SanitizerProbeInit', {'GL_NATIVE_SANITIZER_CONTROL':'use-after-free'}, 'heap-use-after-free')
        if os.name != 'nt':
            # Keep the library loaded until process exit so leak stacks retain symbols.
            Lifecycle('host-leak', 'minimal-hold', 1, Args.probe, 'SanitizerProbeInit', {'GL_NATIVE_SANITIZER_CONTROL':'leak'}, 'detected memory leaks')
        ControlsPassed = all(Item['Passed'] for Item in Results)
        if not Args.controls_only and ControlsPassed:
            Lifecycle('production-registration', 'registration', 5, Args.extension)
            Lifecycle('production-vm-reload', 'vm-cycles', 5, Args.extension)
            Native = Args.output/'native'
            for Group, Flags in [('regression',['--teardown','--coordinated-close']),('security',['--security']),('animation',['--animation']),('characters',['--characters']),('resources',['--resources']),('filesystem',['--filesystem']),('http',['--http']),('httpservice',['--httpservice']),('callers',['--callers']),('datastore',['--datastore'])]:
                Observe([sys.executable, Runtime/'RunQualification.py', '--godot', Args.godot, '--extension', Args.extension, '--output', Native/Group, '--timeout', '15' if Group=='resources' else '60', *Flags], 'suite-'+Group, 360)
            for Group, Script, Flags in [('presentation','RunCharacterPresentation.py',[]),('performance','RunCharacterPerformance.py',['--trials','1','--samples','120','--counts','1,16'])]:
                Observe([sys.executable, Runtime/Script, '--godot', Args.godot, '--asset-godot', Args.asset_godot, '--extension', Args.extension, '--output', Native/Group, *Flags], 'suite-'+Group, 360)
            Observe([sys.executable, Runtime/'RunCoreQualification.py', '--build', Args.build, '--output', Args.output/'core'], 'suite-core', 150)
            (Args.output/'host-provenance.json').write_text(json.dumps(Identity['Host'], indent=2))
            Observe([sys.executable, Runtime/'CheckNativeCI.py', '--output', Native, '--extension', Args.extension, '--godot-evidence', Args.output/'host-provenance.json', '--revision', Args.revision], 'strict-native-check', 60)
        Passed = all(Item['Passed'] for Item in Results)
        # Detect reports written by any grandchild; expected controls are isolated.
        Unexpected = [str(File.relative_to(Args.output)) for File in Args.output.rglob('asan-report*') if File.is_file() and File.parts[len(Args.output.parts)] not in ['standalone-uaf','host-uaf','host-leak']]
        Passed = Passed and not Unexpected
        (Args.output/'sanitizer-summary.json').write_text(json.dumps({'Result':'PASS' if Passed else 'FAIL', 'FullQualification':not Args.controls_only and Passed, 'ControlsPassed':ControlsPassed, 'UnexpectedReports':Unexpected, 'Results':Results, 'Files':{str(File.relative_to(Args.output)):Hash(File) for File in sorted(Args.output.rglob('*')) if File.is_file() and File.suffix in ['.log','.json','.xml'] or File.is_file() and File.name.startswith('asan-report')}}, indent=2))
        if not Passed: raise RuntimeError('Sanitizer qualification failed; complete attempts retained')
    finally:
        StopAll()
        os.chdir(Previous)


if __name__ == '__main__': Main()
