"""Download the recorded official Godot distribution and verify before execution."""
import argparse
import ctypes
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import time
import urllib.request
import zipfile


def Provision(Output):
    Manifest = json.loads(Path(__file__).with_name('GodotDistribution.json').read_text())
    Platform = 'Windows' if os.name == 'nt' else 'Linux'
    Spec = Manifest[Platform]
    Output.mkdir(parents=True, exist_ok=False)
    Archive = Output / 'official.zip'
    Digest = hashlib.sha256()
    Size = 0
    Deadline = time.monotonic() + 180
    Request = urllib.request.Request(Spec['URL'], headers={'User-Agent': 'GodotLuau-Native-Qualification'})
    with urllib.request.urlopen(Request, timeout=30) as Response, Archive.open('wb') as Target:
        while True:
            if time.monotonic() > Deadline:
                raise TimeoutError('Official Godot download exceeded its deadline.')
            Chunk = Response.read(1024 * 1024)
            if not Chunk:
                break
            Size += len(Chunk)
            if Size > Spec['Bytes']:
                raise ValueError('Official Godot archive exceeds the pinned size.')
            Digest.update(Chunk)
            Target.write(Chunk)
    if Size != Spec['Bytes'] or Digest.hexdigest() != Spec['SHA256']:
        raise ValueError('Official Godot archive does not match the pinned SHA-256 and size.')
    Executable = Output / Spec['Executable']
    with zipfile.ZipFile(Archive) as Package:
        Info = Package.getinfo(Spec['Executable'])
        if Info.file_size > 300 * 1024 * 1024:
            raise ValueError('Unexpected Godot executable size.')
        with Package.open(Info) as Source, Executable.open('wb') as Target:
            shutil.copyfileobj(Source, Target)
    Executable.chmod(0o755)
    Options = {}
    if os.name == 'nt':
        ctypes.windll.kernel32.SetErrorMode(0x8003)
        Options['creationflags'] = subprocess.CREATE_NO_WINDOW
    Result = subprocess.run([str(Executable), '--headless', '--disable-crash-handler', '--version'], capture_output=True, text=True, timeout=15, **Options)
    if Result.returncode != 0 or Result.stdout.strip() != Manifest['ExpectedVersionOutput']:
        raise ValueError('Official Godot executable version does not match the recorded source revision: ' + Result.stdout.strip())
    Evidence = dict(Version=Result.stdout.strip(), SourceRevision=Manifest['SourceRevision'], ReleaseID=Manifest['ReleaseID'],
                    Asset=Spec, ExecutableSHA256=hashlib.sha256(Executable.read_bytes()).hexdigest(),
                    ArchiveSHA256=Digest.hexdigest(), VersionStderr=Result.stderr.strip())
    (Output / 'provenance.json').write_text(json.dumps(Evidence, indent=2))
    print('[Runtime:Godot] Verified ' + Result.stdout.strip())


def ProvisionTemplates(Output):
    Manifest=json.loads(Path(__file__).with_name('GodotDistribution.json').read_text())
    Spec=Manifest['ExportTemplates']
    Platform='Windows' if os.name=='nt' else 'Linux'
    Output.mkdir(parents=True,exist_ok=False)
    Archive=Output/'templates.tpz'
    Digest=hashlib.sha256();Size=0;Deadline=time.monotonic()+240
    Request=urllib.request.Request(Spec['URL'],headers={'User-Agent':'GodotLuau-Native-Qualification'})
    with urllib.request.urlopen(Request,timeout=30) as Response,Archive.open('xb') as Target:
        while Chunk:=Response.read(1024*1024):
            Size+=len(Chunk)
            if Size>Spec['Bytes'] or time.monotonic()>Deadline:
                raise ValueError('Export template download exceeded its pinned size/deadline')
            Target.write(Chunk);Digest.update(Chunk)
    if Size!=Spec['Bytes'] or Digest.hexdigest()!=Spec['SHA256']:
        raise ValueError('Export templates do not match the pinned archive')
    Members={}
    with zipfile.ZipFile(Archive) as Package:
        for Name,Expected in Spec[Platform].items():
            Info=Package.getinfo('templates/'+Name)
            if Info.file_size>150*1024*1024: raise ValueError('Unexpected template size')
            Target=Output/Name
            with Package.open(Info) as Source,Target.open('xb') as Stream:
                shutil.copyfileobj(Source,Stream)
            Actual=hashlib.sha256(Target.read_bytes()).hexdigest()
            if Actual!=Expected: raise ValueError('Export template member mismatch: '+Name)
            Target.chmod(0o755)
            Members[Name]={'SHA256':Actual,'Bytes':Target.stat().st_size}
    Record={'SourceRevision':Manifest['SourceRevision'],'ReleaseID':Manifest['ReleaseID'],
            'SHA256':Digest.hexdigest(),'Bytes':Size,'Members':Members,
            'Scope':'Matching official solo export templates; not admitted networking/sanitizer hosts'}
    (Output/'provenance.json').write_text(json.dumps(Record,indent=2)+'\n')
    print('[Runtime:Templates] Verified matching official '+Platform+' export templates')


def Main():
    Parser = argparse.ArgumentParser(description=__doc__)
    Parser.add_argument('--output', type=Path, required=True)
    Parser.add_argument('--templates',action='store_true',help='Stage matching official solo export templates, without installation')
    Args = Parser.parse_args()
    (ProvisionTemplates if Args.templates else Provision)(Args.output.resolve())


if __name__ == '__main__':
    Main()
