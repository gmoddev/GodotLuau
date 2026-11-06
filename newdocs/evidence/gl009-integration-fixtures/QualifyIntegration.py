"""Auditable local integration checks; existing application roots are never activated."""
import argparse
import ctypes
import hashlib
import json
import os
from pathlib import Path
import shutil
import sys
import time


def Hash(File):
    return hashlib.sha256(File.read_bytes()).hexdigest()


def Main():
    Parser=argparse.ArgumentParser(description=__doc__)
    Parser.add_argument('--source',type=Path,required=True)
    Parser.add_argument('--root',type=Path,required=True)
    Parser.add_argument('--output',type=Path,required=True)
    Parser.add_argument('--phase',choices=['compatibility','integrated'],required=True)
    Parser.add_argument('--revision',required=True)
    Args=Parser.parse_args()
    Source=Args.source.resolve(); Root=Args.root.resolve(); Output=Args.output.resolve()
    sys.path.insert(0,str(Source/'tests/runtime'))
    from RunQualification import Prepare, Start, Check
    from FixtureProcesses import StopAll
    from SourceFingerprint import GetFingerprint
    Win=os.name=='nt'
    if Win: ctypes.windll.kernel32.SetErrorMode(0x8003)
    else:
        # Scoped to this controller; adopted descendants cannot become zombies
        # under a container's non-reaping PID1. No global signal/host change.
        assert ctypes.CDLL(None).prctl(36,1,0,0,0)==0
    Suffix='.dll' if Win else '.so'
    Worker='godot_luau_store_worker'+('.exe' if Win else '')
    Builds=Root/'Builds/GodotLuau' if Win else Root/'builds'
    Results=Root/'Artifacts/GodotLuau' if Win else Root/'results'
    Engine=Root/'Tools/Godot_v4.7.1-stable_win64.exe' if Win else Root/'tools/Godot_v4.7.1-stable_linux.x86_64'
    Manifest=json.loads((Source/'newdocs/evidence/gl009-transactional-datastore-2026-10-30.json').read_text())
    Qualified=Manifest['LocalQualification']['Windows' if Win else 'Linux']
    assert GetFingerprint(Source)==Manifest['NativeSource']
    assert Hash(Engine)==Qualified['Engines']['official']['SHA256']
    Output.mkdir(parents=True,exist_ok=True)
    Compatibility=Output/'compatibility'
    Env=dict(os.environ,GODOT_SILENCE_ROOT_WARNING='1')
    for Name in ['APPDATA','LOCALAPPDATA','XDG_CONFIG_HOME','XDG_DATA_HOME','XDG_CACHE_HOME']:
        Directory=Output/'isolated-profile'/Name; Directory.mkdir(parents=True,exist_ok=True); Env[Name]=str(Directory)
    NativeRoots=[]
    for Mode in ['debug','release']:
        Build=Builds/(('runtime-msvc-' if Win else 'linux-')+Mode)
        NativeRoots.append(('CMake-'+Mode,Build,Qualified['Native'][Mode]))
    for Target in ['template_debug','template_release']:
        Folder=Results/('gl009-qualified-v4-scons-'+('windows-' if Win else 'linux-')+Target)/'datastore'
        NativeRoots.append(('SCons-'+Target,Folder,Qualified['SCons'][Target]))
    Actors=[]
    def Actor(Project,Mode,Hex=''):
        shutil.copy2(Path(__file__).with_name('Compatibility.gd'),Project/'Compatibility.gd')
        Label='compatibility-'+Mode
        Child=Start(Engine,Project,'Compatibility.gd',Label,[Mode,Hex],Env)
        Answer=Check(Child,time.monotonic()+40,Project,Label,'[Persistence:Compatibility] PASS '+Mode)
        if '[Runtime:Script]' in (Project/(Label+'.stdout.log')).read_text(errors='replace'):
            raise RuntimeError('Compatibility script error')
        assert Child.poll() is not None
        Actors.append(Answer)
    try:
        if Args.phase=='compatibility':
            assert not Compatibility.exists()
            Legacy=Results/'gl009-baseline-v1/writers'/('godot_luau'+Suffix)
            assert Hash(Legacy)==Qualified['Baseline']['ExtensionSHA256']
            Prepare(Compatibility,Legacy)
            Actor(Compatibility,'seed')
            # The legacy process and its owned group have exited before any new
            # runtime is copied/launched against this particular persistence root.
            Seed=json.loads((Compatibility/'seed-identity.json').read_text())
            Storage=Path(Seed['Root']).resolve(); Storage.relative_to(Output)
            Backup=Output/'legacy-backup'
            shutil.copytree(Storage,Backup)
            Files={File.name:Hash(File) for File in Storage.iterdir() if File.is_file()}
            assert len([Name for Name in Files if Name.startswith('ds_')])==8
            Record={'LegacyLibrarySHA256':Hash(Legacy),'LegacyWriterExited':True,'Root':str(Storage),'UnicodeHex':Seed['UnicodeHex'],'OriginalFiles':Files,'Backup':str(Backup),'Actors':Actors}
            (Output/'compatibility-baseline.json').write_text(json.dumps(Record,indent=2))
        Baseline=json.loads((Output/'compatibility-baseline.json').read_text())
        Storage=Path(Baseline['Root']); Backup=Path(Baseline['Backup'])
        Packages=[]
        for Name,Folder,Identity in NativeRoots:
            Library=Folder/('godot_luau'+Suffix)
            assert Hash(Library)==Identity['ExtensionSHA256']
            ExpectedWorker=Identity.get('WorkerSHA256')
            assert Hash(Folder/Worker)==ExpectedWorker
            Package=Output/(Args.phase+'-'+Name)
            Prepare(Package,Library)
            assert Hash(Package/Worker)==ExpectedWorker
            if not Win: assert os.access(Package/Worker,os.X_OK)
            Actor(Package,'read',Baseline['UnicodeHex'])
            for File,Digest in Baseline['OriginalFiles'].items():
                assert Hash(Storage/File)==Digest and Hash(Backup/File)==Digest
            assert {F.name for F in Storage.glob('ds_*.json')}=={N for N in Baseline['OriginalFiles'] if N.startswith('ds_')}
            Packages.append({'Product':Name,'LibrarySHA256':Hash(Library),'WorkerSHA256':ExpectedWorker,'ReadCompatibility':True,'OriginalBytesPreserved':True})
        Evidence={'Revision':Args.revision,'NativeSource':GetFingerprint(Source),'Phase':Args.phase,'Packages':Packages,'Legacy':Baseline,'Actors':Actors,'Scope':'Isolated old-writer seed, stopped writer, backup, then new read-only readers; existing application roots never activated'}
        (Output/(Args.phase+'-evidence.json')).write_text(json.dumps(Evidence,indent=2))
        print('[Persistence:Integration] PASS '+Args.phase+' four packages; legacy bytes/backups preserved')
    finally:
        StopAll()
        if not Win:
            Deadline=time.monotonic()+3
            while time.monotonic()<Deadline:
                try: Pid,_=os.waitpid(-1,os.WNOHANG|0x40000000)
                except ChildProcessError: break
                if not Pid: time.sleep(.01)
            else: raise RuntimeError('Owned descendants remain after bounded reaping')


if __name__=='__main__': Main()
