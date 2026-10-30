"""Qualify native archive bytes/modes and both runtime configurations after extraction."""
import argparse
import ctypes
import hashlib
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys
import time
import zipfile


def Hash(File): return hashlib.sha256(File.read_bytes()).hexdigest()


def Main():
    Parser=argparse.ArgumentParser(description=__doc__)
    for Name in ['source','root','output']: Parser.add_argument('--'+Name,type=Path,required=True)
    Parser.add_argument('--revision',required=True)
    Parser.add_argument('--attempt',default='v2')
    Args=Parser.parse_args(); Source=Args.source.resolve(); Root=Args.root.resolve(); Output=Args.output.resolve()
    Win=os.name=='nt'; Platform='windows' if Win else 'linux'; Suffix='.dll' if Win else '.so'
    if Win: ctypes.windll.kernel32.SetErrorMode(0x8003)
    else: assert ctypes.CDLL(None).prctl(36,1,0,0,0)==0
    sys.path.insert(0,str(Source/'tests/runtime'))
    from RunQualification import Start,Check
    from FixtureProcesses import StopAll
    Manifest=json.loads((Source/'newdocs/evidence/gl009-transactional-datastore-2026-10-30.json').read_text())
    Qualified=Manifest['LocalQualification']['Windows' if Win else 'Linux']
    Results=Root/'Artifacts/GodotLuau' if Win else Root/'results'
    Engine=Root/'Tools/Godot_v4.7.1-stable_win64.exe' if Win else Root/'tools/Godot_v4.7.1-stable_linux.x86_64'
    Baseline=json.loads((Output/'compatibility-baseline.json').read_text())
    Stage=Output/('archive-stage-'+Args.attempt);Binaries=Stage/'GodotLuau/bin';Binaries.mkdir(parents=True,exist_ok=False)
    Entries={}
    for Target in ['template_debug','template_release']:
        Original=Results/('gl009-qualified-v4-scons-'+Platform+'-'+Target)/'datastore'
        Library=Original/('godot_luau'+Suffix)
        assert Hash(Library)==Qualified['SCons'][Target]['ExtensionSHA256']
        Name='godot_luau.'+Platform+'.'+Target+'.x86_64'+Suffix
        shutil.copy2(Library,Binaries/Name);Entries['GodotLuau/bin/'+Name]=Hash(Library)
    Worker='godot_luau_store_worker'+('.exe' if Win else '')
    Original=Results/('gl009-qualified-v4-scons-'+Platform+'-template_release')/'datastore'/Worker
    assert Hash(Original)==Qualified['SCons']['template_release']['WorkerSHA256']
    shutil.copy2(Original,Binaries/Worker);Entries['GodotLuau/bin/'+Worker]=Hash(Original)
    shutil.copy2(Source/'godot_luau.gdextension',Stage/'godot_luau.gdextension')
    shutil.copy2(Source/'LICENSE',Stage/'LICENSE')
    Package=Output/(Platform+'-native-source-built-'+Args.attempt+'.zip')
    Options={'creationflags':subprocess.CREATE_NO_WINDOW} if Win else {}
    with (Output/('archive-packager-'+Args.attempt+'.stdout.log')).open('w') as Out,(Output/('archive-packager-'+Args.attempt+'.stderr.log')).open('w') as Err:
        subprocess.run([sys.executable,str(Source/'tools/generar_release.py'),'--only',Platform,'--out',str(Package)],cwd=Stage,stdout=Out,stderr=Err,check=True,timeout=120,**Options)
    Env=dict(os.environ,GODOT_SILENCE_ROOT_WARNING='1')
    for Name in ['APPDATA','LOCALAPPDATA','XDG_CONFIG_HOME','XDG_DATA_HOME','XDG_CACHE_HOME']: Env[Name]=str(Output/'isolated-profile'/Name)
    Actors=[]
    try:
        for Mode in ['debug','release']:
            Project=Output/('archive-'+Mode+'-'+Args.attempt);Project.mkdir()
            with zipfile.ZipFile(Package) as Archive:
                for Name,Digest in Entries.items(): assert hashlib.sha256(Archive.read(Name)).hexdigest()==Digest
                assert all(not Path(Name).is_absolute() and '..' not in Path(Name).parts for Name in Archive.namelist())
                Archive.extractall(Project)
                if not Win:
                    for Info in Archive.infolist():
                        if Info.create_system==3: (Project/Info.filename).chmod(stat.S_IMODE(Info.external_attr>>16))
                    assert os.access(Project/'GodotLuau/bin'/Worker,os.X_OK)
            shutil.copy2(Output/'compatibility/project.godot',Project/'project.godot')
            shutil.copy2(Path(__file__).with_name('Compatibility.gd'),Project/'Compatibility.gd')
            Cache=Project/'.godot';Cache.mkdir();(Cache/'global_script_class_cache.cfg').write_text('list=[]\n')
            if Mode=='release':
                Descriptor=Project/'godot_luau.gdextension'
                Descriptor.write_text(Descriptor.read_text().replace('.template_debug.','.template_release.'))
            Label='archive-'+Mode
            Child=Start(Engine,Project,'Compatibility.gd',Label,['read',Baseline['UnicodeHex']],Env)
            Actors.append(Check(Child,time.monotonic()+40,Project,Label,'[Persistence:Compatibility] PASS read'))
            for Name,Digest in Baseline['OriginalFiles'].items():
                assert Hash(Path(Baseline['Root'])/Name)==Digest and Hash(Path(Baseline['Backup'])/Name)==Digest
        Record={'Revision':Args.revision,'Platform':Platform,'PackageSHA256':Hash(Package),'EntriesSHA256':Entries,'Actors':Actors,'Companion':'One source-matching Release companion serves both Debug/Release libraries','LegacyBytesAndBackupPreserved':True,'Scope':'Native installation subset; extraction respects Unix mode metadata; no production release/updater qualification','PackagerSHA256':hashlib.sha256((Source/'tools/generar_release.py').read_bytes().replace(b'\r\n',b'\n')).hexdigest()}
        (Output/('archive-evidence-'+Args.attempt+'.json')).write_text(json.dumps(Record,indent=2))
        print('[Persistence:Packaging] PASS real native archive, bytes/modes, Debug/Release sibling-helper startup and legacy read')
    finally:
        StopAll()
        if not Win:
            Deadline=time.monotonic()+3
            while time.monotonic()<Deadline:
                try: Pid,_=os.waitpid(-1,os.WNOHANG|0x40000000)
                except ChildProcessError: break
                if not Pid: time.sleep(.01)
            else: raise RuntimeError('Owned descendants remain')


if __name__=='__main__': Main()
