"""Source-built, non-publishing candidate orchestration around existing checkers."""
import argparse
import ctypes
import hashlib
import importlib.metadata
import json
import os
from pathlib import Path
import platform
import re
import shutil
import stat
import subprocess
import sys
import tarfile
import time
import zipfile

Source = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Source/'tests/runtime'))
from CheckCoreCI import CheckDiscovery, CheckReport
from FixtureProcesses import StartProcess, StopProcess, StopAll
from SourceFingerprint import GetFingerprint
from RunQualification import Start, Check

Policy = json.loads(Path(__file__).with_name('ReleaseCandidatePolicy.json').read_text())
Profiles = [(Platform, Configuration) for Platform in Policy['Platforms'] for Configuration in Policy['Configurations']]


def Hash(File): return hashlib.sha256(Path(File).read_bytes()).hexdigest()
def Load(File): return json.loads(Path(File).read_text(encoding='utf-8-sig'))
def Save(File, Data): Path(File).write_text(json.dumps(Data, indent=2)+'\n', encoding='utf-8')
def Require(Condition, Message):
    if not Condition: raise ValueError('[Release:Candidate] '+Message)


def Git(*Arguments):
    return subprocess.check_output(['git', '-C', str(Source), *Arguments], timeout=30).decode().strip()


def Identity(Revision):
    Require(re.fullmatch('[0-9a-f]{40}', Revision), 'An immutable full source revision is required')
    Require(Git('rev-parse', 'HEAD') == Revision, 'Checkout is not the requested immutable revision')
    # SCons outputs are ignored except its extensionless companion, checked below.
    Dirty = Git('status', '--porcelain', '--untracked-files=all')
    Allowed = {'?? GodotLuau/bin/godot_luau_store_worker', '?? GodotLuau/bin/godot_luau_store_worker.exe'}
    Require(all(Line in Allowed for Line in Dirty.splitlines()), 'Dirty or untracked source inputs')
    Dependencies = {}
    for Name, Expected in Policy['Dependencies'].items():
        Require(Git('rev-parse', Revision+':'+Name) == Expected, 'Changed dependency pin: '+Name)
        Require((Source/Name/'.git').exists(), 'Missing pinned dependency: '+Name)
        Actual = subprocess.check_output(['git', '-C', str(Source/Name), 'rev-parse', 'HEAD'], timeout=15).decode().strip()
        DirtyDependency = subprocess.check_output(['git', '-C', str(Source/Name), 'status', '--porcelain', '--untracked-files=all'], timeout=15).decode().strip()
        Require(Actual == Expected and not DirtyDependency, 'Missing, dirty or mismatched dependency: '+Name)
        Dependencies[Name] = Actual
    Harness = {File.name: hashlib.sha256(File.read_bytes().replace(b'\r\n', b'\n')).hexdigest() for File in sorted((Source/'tests/runtime').iterdir()) if File.suffix in ['.gd', '.py', '.cpp', '.pem'] or File.name in ['CMakeLists.txt', 'GodotDistribution.json']}
    return {'Revision': Revision, 'Tree': Git('rev-parse', Revision+'^{tree}'), 'Dependencies': Dependencies,
            'NativeSource': GetFingerprint(Source), 'HarnessHashes': Harness,
            'PolicySHA256': hashlib.sha256(Path(__file__).with_name('ReleaseCandidatePolicy.json').read_bytes().replace(b'\r\n', b'\n')).hexdigest()}


def Execute(Command, Log, Timeout=300, Environment=None, Cwd=None):
    """Retain failure output and kill only the owned process tree, also on timeout."""
    Log = Path(Log)
    Log.parent.mkdir(parents=True, exist_ok=True)
    Require(not Log.exists(), 'Refuse to overwrite prior command evidence: '+str(Log))
    Command = [str(Item) for Item in Command]
    print('[Release:Candidate] '+Log.stem, flush=True)
    Previous = Path.cwd()
    try:
        if Cwd: os.chdir(Cwd)
        with Log.open('w', encoding='utf-8') as Output:
            Child = StartProcess(Command, Output, subprocess.STDOUT, Environment or dict(os.environ))
            try:
                Code = Child.wait(timeout=Timeout)
            finally:
                StopProcess(Child)
        Require(Code == 0, 'Command failed; retained log: '+str(Log))
    finally:
        os.chdir(Previous)
    return {'Command': Command, 'Exit': Code, 'TimeoutSeconds': Timeout, 'LogSHA256': Hash(Log)}


def GodotIdentity(Directory):
    Distribution = Load(Source/'tests/runtime/GodotDistribution.json')
    Selected = 'Windows' if os.name == 'nt' else 'Linux'
    Evidence = Load(Directory/'provenance.json')
    Require(Evidence['Asset'] == Distribution[Selected] and Evidence['SourceRevision'] == Distribution['SourceRevision'] and Evidence['Version'] == Distribution['ExpectedVersionOutput'], 'Godot pin/provenance mismatch')
    Require(Evidence['ArchiveSHA256'] == Distribution[Selected]['SHA256'] and Hash(Directory/Distribution[Selected]['Executable']) == Evidence['ExecutableSHA256'], 'Godot executable/archive mismatch')
    return Directory/Distribution[Selected]['Executable'], Evidence


def Names(Selected, Configuration):
    Suffix = '.dll' if Selected == 'Windows' else '.so'
    return ('godot_luau.'+Selected.lower()+'.template_'+Configuration.lower()+'.x86_64'+Suffix,
            'godot_luau_store_worker'+('.exe' if Selected == 'Windows' else ''))


def Native(Engine, Library, Output, Revision):
    for Group, Flags in [('regression', ['--teardown', '--coordinated-close']), ('security', ['--security']), ('animation', ['--animation']), ('characters', ['--characters']), ('resources', ['--resources']), ('filesystem', ['--filesystem']), ('http', ['--http']), ('httpservice', ['--httpservice']), ('callers', ['--callers']), ('datastore', ['--datastore'])]:
        Execute([sys.executable, Source/'tests/runtime/RunQualification.py', '--godot', Engine, '--extension', Library, '--output', Output/Group, '--timeout', '15' if Group == 'resources' else '60', *Flags], Output.parent/(Group+'.log'), 300)
    Execute([sys.executable, Source/'tests/runtime/RunCharacterPresentation.py', '--godot', Engine, '--extension', Library, '--output', Output/'presentation'], Output.parent/'presentation.log', 300)
    Execute([sys.executable, Source/'tests/runtime/RunCharacterPerformance.py', '--godot', Engine, '--extension', Library, '--output', Output/'performance', '--trials', '1', '--samples', '120', '--counts', '1,16'], Output.parent/'performance.log', 180)
    Execute([sys.executable, Source/'tests/runtime/CheckNativeCI.py', '--output', Output, '--extension', Library, '--godot-evidence', Output.parent/'godot/provenance.json', '--revision', Revision], Output.parent/'native-check.log', 60)


def Build(Args):
    Selected = 'Windows' if os.name == 'nt' else 'Linux'
    Output = Args.output.resolve(); Output.mkdir(parents=True, exist_ok=False)
    Before = Identity(Args.revision)
    Require(importlib.metadata.version('SCons') == Policy['SCons'], 'Wrong SCons version')
    Engine, EngineEvidence = GodotIdentity(Args.godot.resolve())
    shutil.copytree(Args.godot, Output/'godot', ignore=shutil.ignore_patterns('official.zip', '*.exe', 'Godot_v*'))
    # Preserve only the verified engine evidence, never distribute Godot here.
    Save(Output/'godot/provenance.json', EngineEvidence)
    Products = Output/'products'; Products.mkdir()
    Compiler = shutil.which('cl' if Selected == 'Windows' else 'g++')
    Require(Compiler, 'Compiler is unavailable')
    CompilerResult = subprocess.run([Compiler, '/Bv'] if Selected == 'Windows' else [Compiler, '--version'], capture_output=True, text=True, timeout=30)
    CompilerText = CompilerResult.stdout+CompilerResult.stderr
    Require(CompilerText.strip(), 'Compiler identification is empty')
    Toolchain = {'OS': platform.platform(), 'Machine': platform.machine(), 'Python': sys.version, 'SCons': importlib.metadata.version('SCons'), 'Compiler': Compiler, 'CompilerSHA256': Hash(Compiler), 'CompilerVersion': CompilerText, 'CMake': subprocess.check_output(['cmake', '--version'], text=True, timeout=15), 'CTest': subprocess.check_output(['ctest', '--version'], text=True, timeout=15)}
    Target = 'template_'+Args.configuration.lower()
    Commands = []
    Commands.append(Execute([sys.executable, '-m', 'SCons', 'platform='+Selected.lower(), 'target='+Target, 'arch=x86_64', 'precision=single', '-j2'], Output/'scons.log', 3600, Cwd=Source))
    LibraryName, WorkerName = Names(Selected, Args.configuration)
    for Name in [LibraryName, WorkerName]:
        Require((Source/'GodotLuau/bin'/Name).is_file(), 'Missing source-built product: '+Name)
        shutil.copy2(Source/'GodotLuau/bin'/Name, Products/Name)
    BuildDirectory = Output/'build'
    Generator = 'Visual Studio 17 2022' if Selected == 'Windows' else 'Ninja'
    Commands.append(Execute(['cmake', '-S', Source/'tests/runtime', '-B', BuildDirectory, '-G', Generator, '-DCMAKE_BUILD_TYPE='+Args.configuration, '-DGL_BUILD_GODOT_ADAPTER=ON', '-DGL_BUILD_CORE_TESTS=ON'], Output/'configure.log', 300))
    Commands.append(Execute(['cmake', '--build', BuildDirectory, '--config', Args.configuration, '--target', 'ExecutionDomainTests', 'GodotLuauAdapter', 'DatastoreBackendProbe', '--parallel', '2'], Output/'build.log', 3600))
    AdapterDirectory = BuildDirectory/Args.configuration if Selected == 'Windows' else BuildDirectory
    AdapterName = 'godot_luau'+('.dll' if Selected == 'Windows' else '.so')
    Adapter = Output/'adapter'; Adapter.mkdir()
    for Name in [AdapterName, WorkerName, 'DatastoreBackendProbe'+('.exe' if Selected == 'Windows' else '')]: shutil.copy2(AdapterDirectory/Name, Adapter/Name)
    Commands.append(Execute([sys.executable, Source/'tests/runtime/RunCoreQualification.py', '--build', BuildDirectory, '--config', Args.configuration, '--output', Output/'core'], Output/'core-check.log', 150))
    Native(Engine, Adapter/AdapterName, Output/'native', Args.revision)
    Require(Identity(Args.revision) == Before, 'Source inputs changed during build/qualification')
    Summary = Load(Output/'native/summary.json')
    Require(Summary['Revision'] == Args.revision and Summary['Processes'] == 110 and Summary['HarnessHashes'] == Before['HarnessHashes'], 'Native qualification identity/count mismatch')
    Payload = Output/'evidence.zip'
    with zipfile.ZipFile(Payload, 'w', zipfile.ZIP_DEFLATED) as Archive:
        for Directory in [Output/'core', Output/'native', Output/'godot']:
            for File in sorted(Directory.rglob('*')):
                if File.is_file() and File.suffix in ['.json', '.log', '.xml', '.txt']: Archive.write(File, File.relative_to(Output).as_posix())
        for File in sorted(Output.glob('*.log')): Archive.write(File, File.name)
    Files = {File.relative_to(Output).as_posix(): {'SHA256': Hash(File), 'Bytes': File.stat().st_size} for Directory in [Products, Adapter] for File in sorted(Directory.iterdir())}
    Files['evidence.zip'] = {'SHA256': Hash(Payload), 'Bytes': Payload.stat().st_size}
    Save(Output/'profile.json', {'Schema': 1, 'Platform': Selected, 'Configuration': Args.configuration, 'Source': Before, 'Toolchain': Toolchain, 'Commands': Commands, 'Godot': EngineEvidence, 'Files': Files, 'Gates': {'Core': {'Result': 'PASS', 'Cases': 80}, 'Native': {'Result': 'PASS', 'Actors': 110}}, 'QualificationProduct': 'Existing CMake native test adapter with GL_RUNTIME_TESTS; SCons production products are separately checked after packaging', 'Limitations': Policy['Limitations']})
    print('[Release:Candidate] PASS source-built '+Selected+' '+Args.configuration, flush=True)


def SafePath(Name):
    return bool(Name) and not any(ord(Character) < 32 for Character in Name) and '\\' not in Name and ':' not in Name and not Name.startswith('/') and all(Part not in ['', '.', '..'] for Part in Name.split('/'))


def Extract(ArchivePath, Directory):
    Require(not Directory.exists(), 'Extraction output already exists')
    with zipfile.ZipFile(ArchivePath) as Archive:
        Require(len(Archive.namelist()) == len(set(Archive.namelist())), 'Duplicate archive member')
        Require(sum(Item.file_size for Item in Archive.infolist()) < 1024*1024*1024, 'Oversized archive')
        for Item in Archive.infolist():
            Require(SafePath(Item.orig_filename) and SafePath(Item.filename) and not stat.S_ISLNK(Item.external_attr >> 16), 'Unsafe archive member')
        Directory.mkdir(parents=True)
        Archive.extractall(Directory)
        if os.name != 'nt':
            for Item in Archive.infolist():
                if Item.create_system == 3: (Directory/Item.filename).chmod(stat.S_IMODE(Item.external_attr >> 16))


def CheckProfile(Record, Expected, Selected, Configuration):
    Require(Record['Schema'] == 1 and Record['Platform'] == Selected and Record['Configuration'] == Configuration, 'Missing or mismatched build profile')
    Require(Record['Source'] == Expected, 'Stale or mixed source/fixture/dependency inputs')
    Require(Record['Gates'] == {'Core': {'Result': 'PASS', 'Cases': 80}, 'Native': {'Result': 'PASS', 'Actors': 110}}, 'Failed, skipped or incomplete qualification gate')
    Require(Record['Commands'] and all(Item['Exit'] == 0 for Item in Record['Commands']), 'Failed build/qualification command')
    Require(Record['Toolchain']['SCons'] == Policy['SCons'] and Record['Toolchain']['CompilerVersion'], 'Missing toolchain identity')
    LibraryName, WorkerName = Names(Selected, Configuration)
    Require({'products/'+LibraryName, 'products/'+WorkerName, 'evidence.zip'} <= set(Record['Files']), 'Missing extension or persistence companion')


def ProfilesAt(Inputs, Expected, Output):
    Records = {}
    for Selected, Configuration in Profiles:
        Directory = Inputs/('profile-'+Selected+'-'+Configuration)
        Record = Load(Directory/'profile.json')
        CheckProfile(Record, Expected, Selected, Configuration)
        for Name, Item in Record['Files'].items():
            Require(SafePath(Name), 'Invalid product path')
            File = Directory/Name
            Require(File.is_file() and not File.is_symlink() and Hash(File) == Item['SHA256'] and File.stat().st_size == Item['Bytes'], 'Missing or mismatched build artifact: '+Name)
        Evidence = Output/('evidence-'+Selected+'-'+Configuration)
        Extract(Directory/'evidence.zip', Evidence)
        CheckDiscovery(Evidence/'core/discovery.json'); CheckReport(Evidence/'core/core-results.xml')
        Summary = Load(Evidence/'native/summary.json')
        Require(Summary['Revision'] == Expected['Revision'] and Summary['NativeSource'] == Expected['NativeSource'] and Summary['HarnessHashes'] == Expected['HarnessHashes'], 'Native evidence identity mismatch')
        # Existing Windows evidence uses native separators. Canonicalize only
        # recorded log paths; the strict checker itself is unchanged.
        Summary['LogHashes'] = {Name.replace('\\', '/'): Digest for Name, Digest in Summary['LogHashes'].items()}
        for Name, Digest in Summary['LogHashes'].items(): Require(SafePath(Name) and Hash(Evidence/'native'/Name) == Digest, 'Native log hash mismatch')
        Distribution = Load(Source/'tests/runtime/GodotDistribution.json')
        EngineEvidence = Load(Evidence/'godot/provenance.json')
        Require(Record['Godot'] == EngineEvidence == Summary['Godot'] and EngineEvidence['Asset'] == Distribution[Selected] and EngineEvidence['SourceRevision'] == Distribution['SourceRevision'] and EngineEvidence['ArchiveSHA256'] == Distribution[Selected]['SHA256'] and EngineEvidence['Version'] == Distribution['ExpectedVersionOutput'], 'Native Godot dependency identity mismatch')
        AdapterName = 'godot_luau'+('.dll' if Selected == 'Windows' else '.so')
        Execute([sys.executable, Source/'tests/runtime/CheckNativeCI.py', '--output', Evidence/'native', '--extension', Directory/'adapter'/AdapterName, '--godot-evidence', Evidence/'godot/provenance.json', '--revision', Expected['Revision']], Output/('check-'+Selected+'-'+Configuration+'.log'), 60)
        Rechecked = Load(Evidence/'native/summary.json')
        Rechecked['LogHashes'] = {Name.replace('\\', '/'): Digest for Name, Digest in Rechecked['LogHashes'].items()}
        Require(Rechecked == Summary, 'Strict native verification changed the recorded evidence')
        Records[Selected+'-'+Configuration] = Record
    return Records


def CheckSanitizer(Directory, Expected):
    Record = Load(Directory/'sanitizer.json')
    Require(Record['Source'] == Expected and Record['Result'] == 'PASS' and Record['Cases'] == 80, 'Missing or failed core sanitizer qualification')
    Require(Record['ASAN_OPTIONS'] == 'detect_leaks=1:halt_on_error=1' and Record['InstrumentedFiles'] >= 2 and Record['ASanSymbolVerified'], 'Sanitizer instrumentation not established')
    for Name, Digest in Record['Files'].items(): Require(SafePath(Name) and Hash(Directory/Name) == Digest, 'Sanitizer evidence hash mismatch')
    CheckDiscovery(Directory/'core/discovery.json'); CheckReport(Directory/'core/core-results.xml')
    return Record


def Sanitize(Args):
    Require(os.name != 'nt', 'This sanitizer profile requires Linux')
    Output = Args.output.resolve(); Output.mkdir(parents=True, exist_ok=False)
    Before = Identity(Args.revision)
    Environment = dict(os.environ, ASAN_OPTIONS='detect_leaks=1:halt_on_error=1')
    BuildDirectory = Output/'build'
    Execute(['cmake', '-S', Source/'tests/runtime', '-B', BuildDirectory, '-G', 'Ninja', '-DCMAKE_BUILD_TYPE=Debug', '-DCMAKE_CXX_COMPILER=clang++', '-DCMAKE_EXPORT_COMPILE_COMMANDS=ON', '-DCMAKE_CXX_FLAGS=-fsanitize=address -fno-omit-frame-pointer', '-DCMAKE_EXE_LINKER_FLAGS=-fsanitize=address', '-DGL_BUILD_GODOT_ADAPTER=OFF'], Output/'configure.log', 300)
    Execute(['cmake', '--build', BuildDirectory, '--target', 'ExecutionDomainTests', '--parallel', '2'], Output/'build.log', 1200)
    Execute([sys.executable, Source/'tests/runtime/RunCoreQualification.py', '--build', BuildDirectory, '--output', Output/'core'], Output/'core-check.log', 150, Environment)
    Commands = [Item for Item in Load(BuildDirectory/'compile_commands.json') if '/ExecutionDomainTests.dir/' in Item['command']]
    Require(len(Commands) >= 2 and all('-fsanitize=address' in Item['command'] for Item in Commands), 'Core was not compiled with ASan')
    Symbols = subprocess.check_output(['nm', str(BuildDirectory/'ExecutionDomainTests')], text=True, timeout=30)
    Require('__asan_init' in Symbols and Identity(Args.revision) == Before, 'ASan symbol/source identity mismatch')
    Files = {str(File.relative_to(Output)): Hash(File) for File in (Output/'core').iterdir() if File.is_file()}
    Save(Output/'sanitizer.json', {'Source': Before, 'Result': 'PASS', 'Cases': 80, 'ASAN_OPTIONS': Environment['ASAN_OPTIONS'], 'InstrumentedFiles': len(Commands), 'ASanSymbolVerified': True, 'Compiler': subprocess.check_output(['clang++', '--version'], text=True, timeout=15), 'Commands': Commands, 'Files': Files})


def Stage(Revision, Output):
    sys.path.insert(0, str(Source/'tools'))
    import generar_release as Packager
    Archive = Output/'source.tar'
    with Archive.open('wb') as File:
        subprocess.run(['git', '-C', str(Source), 'archive', '--format=tar', Revision, *Packager.ARCHIVOS_SUELTOS, *Packager.CARPETAS], stdout=File, check=True, timeout=60)
    Directory = Output/'stage'; Directory.mkdir()
    with tarfile.open(Archive) as Tar:
        for Item in Tar.getmembers():
            Require(SafePath(Item.name.rstrip('/')) and (Item.isfile() or Item.isdir()), 'Unsafe source archive member')
        Tar.extractall(Directory, filter='data')
    Binaries = Directory/'GodotLuau/bin'
    # Git archives must never supply production binaries, even if later committed.
    Require(not Binaries.exists() or not any(Binaries.iterdir()), 'Source tree contains prebuilt binaries')
    Binaries.mkdir(parents=True, exist_ok=True)
    Notices = Directory/'GodotLuau/licenses'; Notices.mkdir(exist_ok=True)
    for Name in Policy['Dependencies']:
        Licenses = [File for File in (Source/Name).iterdir() if File.name.lower() in ['license', 'license.md', 'license.txt'] and File.is_file()]
        Require(len(Licenses) == 1, 'Missing or ambiguous dependency license: '+Name)
        shutil.copy2(Licenses[0], Notices/(Name+'.txt'))
    return Directory


def Smoke(Engine, Package, Directory, Selected):
    Actors = []
    WorkerName = Names(Selected, 'Release')[1]
    try:
        for Configuration in Policy['Configurations']:
            Project = Directory/Configuration
            Extract(Package, Project)
            Worker = Project/'GodotLuau/bin'/WorkerName
            if os.name != 'nt': Require(os.access(Worker, os.X_OK), 'Extracted companion is not executable')
            (Project/'project.godot').write_text('config_version=5\n[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="GodotLuauCandidate"\n[threading]\nworker_pool/max_threads=2\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
            (Project/'.godot').mkdir(); (Project/'.godot/global_script_class_cache.cfg').write_text('list=[]\n')
            shutil.copy2(Source/'tests/runtime/DatastoreIntegration.gd', Project/'DatastoreIntegration.gd')
            if Configuration == 'Release':
                # The official test host has debug features. Redirect its debug
                # selection to the packaged Release library in this copy only.
                Descriptor = Project/'godot_luau.gdextension'
                Descriptor.write_text(Descriptor.read_text().replace('.template_debug.', '.template_release.'))
            Environment = dict(os.environ, GODOT_SILENCE_ROOT_WARNING='1')
            for Name in ['APPDATA', 'LOCALAPPDATA', 'XDG_CONFIG_HOME', 'XDG_DATA_HOME', 'XDG_CACHE_HOME']:
                Profile = Directory/('profile-'+Configuration)/Name; Profile.mkdir(parents=True); Environment[Name] = str(Profile)
            Label = 'package-'+Configuration
            Child = Start(Engine, Project, 'DatastoreIntegration.gd', Label, [], Environment)
            Result = Check(Child, time.monotonic()+60, Project, Label, '[Persistence:DataStore] PASS prototype')
            LibraryName = Names(Selected, Configuration)[0]
            Actors.append({'Configuration': Configuration, **Result, 'ExtensionSHA256': Hash(Project/'GodotLuau/bin'/LibraryName), 'CompanionSHA256': Hash(Worker), 'Logs': {Name: Hash(Project/(Label+'.'+Name+'.log')) for Name in ['stdout', 'stderr']}})
    finally: StopAll()
    return Actors


def Package(Args):
    Output = Args.output.resolve(); Output.mkdir(parents=True, exist_ok=False)
    Expected = Identity(Args.revision)
    Records = ProfilesAt(Args.inputs.resolve(), Expected, Output)
    Sanitizer = CheckSanitizer(Args.inputs.resolve()/'sanitizer', Expected)
    Selected = 'Windows' if os.name == 'nt' else 'Linux'
    Engine, EngineEvidence = GodotIdentity(Args.godot.resolve())
    StageDirectory = Stage(Args.revision, Output)
    Binaries = StageDirectory/'GodotLuau/bin'
    for Configuration in Policy['Configurations']:
        LibraryName, _ = Names(Selected, Configuration)
        shutil.copy2(Args.inputs/('profile-'+Selected+'-'+Configuration)/'products'/LibraryName, Binaries/LibraryName)
    WorkerName = Names(Selected, 'Release')[1]
    shutil.copy2(Args.inputs/('profile-'+Selected+'-Release')/'products'/WorkerName, Binaries/WorkerName)
    Provenance = {'Schema': 1, 'Source': Expected, 'Platform': Selected, 'Profiles': Records, 'Sanitizer': Sanitizer, 'CompanionPolicy': 'One source-built Release companion serves both extension configurations; both are tested after extraction', 'Godot': EngineEvidence, 'Limitations': Policy['Limitations']}
    Save(StageDirectory/'GodotLuau/release-provenance.json', Provenance)
    Archive = Output/('GodotLuau-'+Selected+'.zip')
    Execute([sys.executable, Source/'tools/generar_release.py', '--only', Selected.lower(), '--out', Archive], Output/'package.log', 180, Cwd=StageDirectory)
    ExpectedFiles = {str(File.relative_to(StageDirectory)).replace('\\', '/'): Hash(File) for File in StageDirectory.rglob('*') if File.is_file()}
    with zipfile.ZipFile(Archive) as Zip:
        Require(set(Zip.namelist()) == set(ExpectedFiles), 'Package layout contains missing or unexpected files')
        Members = {Item.filename: {'SHA256': hashlib.sha256(Zip.read(Item)).hexdigest(), 'Bytes': Item.file_size, 'Mode': stat.S_IMODE(Item.external_attr >> 16)} for Item in Zip.infolist()}
        Require(all(Item['SHA256'] == ExpectedFiles[Name] for Name, Item in Members.items()), 'Package bytes differ from staged source/products')
        if Selected == 'Linux': Require(Members['GodotLuau/bin/'+WorkerName]['Mode'] == 0o755, 'Companion ZIP executable mode missing')
    Actors = Smoke(Engine, Archive, Output/'startup', Selected)
    Require(Identity(Args.revision) == Expected, 'Source changed during packaging')
    Save(Output/'candidate.json', {'Schema': 1, 'Result': 'PASS', 'Platform': Selected, 'Source': Expected, 'Package': {'File': Archive.name, 'SHA256': Hash(Archive), 'Bytes': Archive.stat().st_size, 'Members': Members}, 'ProvenanceSHA256': Members['GodotLuau/release-provenance.json']['SHA256'], 'Startup': Actors, 'Limitations': Policy['Limitations']})
    print('[Release:Candidate] PASS extracted '+Selected+' Debug/Release companion startup', flush=True)


def CheckPackage(Directory, Expected, Selected):
    Record = Load(Directory/'candidate.json')
    Require(Record['Schema'] == 1 and Record['Result'] == 'PASS' and Record['Platform'] == Selected and Record['Source'] == Expected, 'Missing or mismatched candidate qualification')
    Package = Record['Package']; Require(SafePath(Package['File']), 'Invalid candidate archive name')
    File = Directory/Package['File']
    Require(Hash(File) == Package['SHA256'] and File.stat().st_size == Package['Bytes'], 'Candidate ZIP hash mismatch')
    with zipfile.ZipFile(File) as Archive:
        Require(set(Archive.namelist()) == set(Package['Members']) and len(Archive.namelist()) == len(set(Archive.namelist())), 'Candidate members mismatch')
        for Name, Item in Package['Members'].items():
            Require(SafePath(Name) and hashlib.sha256(Archive.read(Name)).hexdigest() == Item['SHA256'], 'Candidate member mismatch')
            Entry = Archive.getinfo(Name)
            Require(SafePath(Entry.orig_filename) and Entry.file_size == Item['Bytes'] and stat.S_IMODE(Entry.external_attr >> 16) == Item['Mode'] and not stat.S_ISLNK(Entry.external_attr >> 16), 'Candidate member size/mode mismatch')
        Provenance = json.loads(Archive.read('GodotLuau/release-provenance.json'))
        Require(Provenance['Platform'] == Selected and Provenance['Source'] == Expected and hashlib.sha256(Archive.read('GodotLuau/release-provenance.json')).hexdigest() == Record['ProvenanceSHA256'], 'Embedded provenance mismatch')
        for PlatformName, Configuration in Profiles: CheckProfile(Provenance['Profiles'][PlatformName+'-'+Configuration], Expected, PlatformName, Configuration)
        Require(Provenance['Sanitizer']['Source'] == Expected and Provenance['Sanitizer']['Result'] == 'PASS' and Provenance['Sanitizer']['Cases'] == 80 and Provenance['Sanitizer']['ASanSymbolVerified'], 'Missing sanitizer gate in candidate')
        for Configuration in Policy['Configurations']:
            LibraryName, WorkerName = Names(Selected, Configuration)
            Build = Provenance['Profiles'][Selected+'-'+Configuration]
            Require(Package['Members']['GodotLuau/bin/'+LibraryName]['SHA256'] == Build['Files']['products/'+LibraryName]['SHA256'], 'Packaged library is not the qualified source-built product')
        Worker = Provenance['Profiles'][Selected+'-Release']['Files']['products/'+WorkerName]
        Require(Package['Members']['GodotLuau/bin/'+WorkerName]['SHA256'] == Worker['SHA256'], 'Packaged companion is not the qualified Release product')
        Require({Name for Name in Package['Members'] if Name.startswith('GodotLuau/bin/')} == {'GodotLuau/bin/'+Names(Selected, Configuration)[0] for Configuration in Policy['Configurations']} | {'GodotLuau/bin/'+WorkerName}, 'Unexpected native package payload')
        if Selected == 'Linux': Require(Package['Members']['GodotLuau/bin/'+WorkerName]['Mode'] == 0o755, 'Companion executable mode missing')
    Require([Item['Configuration'] for Item in Record['Startup']] == Policy['Configurations'] and all(Item['Exit'] == 0 for Item in Record['Startup']), 'Missing or failed extracted-package startup')
    for Actor in Record['Startup']:
        LibraryName, WorkerName = Names(Selected, Actor['Configuration'])
        Require(Actor['ExtensionSHA256'] == Package['Members']['GodotLuau/bin/'+LibraryName]['SHA256'] and Actor['CompanionSHA256'] == Package['Members']['GodotLuau/bin/'+WorkerName]['SHA256'], 'Startup product identity mismatch')
        for Name, Digest in Actor['Logs'].items():
            Log = Directory/'startup'/Actor['Configuration']/(Actor['Label']+'.'+Name+'.log')
            Require(Name in ['stdout', 'stderr'] and Hash(Log) == Digest, 'Startup log mismatch')
        Text = (Directory/'startup'/Actor['Configuration']/(Actor['Label']+'.stdout.log')).read_text(errors='replace')
        Require('[Persistence:DataStore] PASS prototype' in Text and '[Persistence:DataStore] FAIL' not in Text, 'Packaged companion did not execute the persistence fixture')
    Require(Record['Limitations'] == Provenance['Limitations'] == Policy['Limitations'], 'Candidate scope/limitations mismatch')
    return Record


def CheckJobs(Results):
    Require(set(Results) == set(Policy['RequiredJobs']) and all(Item['result'] == 'success' for Item in Results.values()), 'Failed, skipped, cancelled, timed-out or incomplete required job')


def Accept(Args):
    CheckJobs(json.loads(os.environ['RC_GATE_RESULTS']))
    Expected = Identity(Args.revision)
    Records = [CheckPackage(Args.inputs/('candidate-'+Selected), Expected, Selected) for Selected in Policy['Platforms']]
    Args.output.mkdir(parents=True, exist_ok=False)
    Save(Args.output/'accepted.json', {'Schema': 1, 'Result': 'ACCEPTED_NONPUBLISHING_CANDIDATE', 'Source': Expected, 'Packages': Records, 'Jobs': json.loads(os.environ['RC_GATE_RESULTS']), 'Limitations': Policy['Limitations']})
    print('[Release:Candidate] PASS all required profiles/gates; candidate artifacts only', flush=True)


def Main():
    if os.name == 'nt': ctypes.windll.kernel32.SetErrorMode(0x8003)
    Parser = argparse.ArgumentParser(description=__doc__)
    Parser.add_argument('mode', choices=['build', 'package', 'sanitize', 'accept'])
    Parser.add_argument('--revision', required=True)
    Parser.add_argument('--output', type=Path, required=True)
    Parser.add_argument('--inputs', type=Path)
    Parser.add_argument('--godot', type=Path)
    Parser.add_argument('--configuration', choices=Policy['Configurations'])
    Args = Parser.parse_args()
    try:
        {'build': Build, 'package': Package, 'sanitize': Sanitize, 'accept': Accept}[Args.mode](Args)
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as Error:
        print('[Release:Candidate] REJECTED: '+str(Error), file=sys.stderr)
        return 1
    finally: StopAll()


if __name__ == '__main__': raise SystemExit(Main())
