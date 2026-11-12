"""Export the real Luau-only game through Godot and launch outside its project.

Uses the existing verified candidate, host and process infrastructure. This is
headless editor/export evidence, never interactive UI or rendered qualification.
"""
import argparse
import ctypes
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

Repository=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(Repository/'tools'))
from ReleaseCandidate import Execute
sys.path.insert(0,str(Repository/'tests/runtime'))
from FixtureProcesses import StopAll


def Hash(File):
    Digest=hashlib.sha256()
    with File.open('rb') as Stream:
        for Block in iter(lambda:Stream.read(1024*1024),b''): Digest.update(Block)
    return Digest.hexdigest()


def Main():
    Parser=argparse.ArgumentParser(description=__doc__)
    for Name in ('candidate','engine','host-manifest','editor','output'):
        Parser.add_argument('--'+Name,type=Path,required=True)
    Parser.add_argument('--profile',choices=['OrbRun','Native2D','Native3D','UI'],default='OrbRun')
    Args=Parser.parse_args()
    if os.name!='nt': Parser.error('This explicit Windows export profile requires Windows')
    Output=Args.output.resolve();Output.mkdir(parents=True,exist_ok=False)
    Project=Output/'project';Standalone=Output/'standalone';Standalone.mkdir()
    Environment=dict(os.environ,GODOT_SILENCE_ROOT_WARNING='1')
    for Name in ('APPDATA','LOCALAPPDATA','XDG_CONFIG_HOME','XDG_DATA_HOME','XDG_CACHE_HOME'):
        Folder=Output/'profile'/Name;Folder.mkdir(parents=True);Environment[Name]=str(Folder)
    ctypes.windll.kernel32.SetErrorMode(0x8003)
    Commands=[]
    Commands.append(Execute([sys.executable,Repository/'examples/luau-only/PrepareProject.py',
        '--candidate',Args.candidate.resolve(),'--engine',Args.engine.resolve(),
        '--host-manifest',Args.host_manifest.resolve(),'--profile',Args.profile,'--output',Project],Output/'stage.log',60,Environment))
    # Normal bounded editor open completes initialization. The stock editor's
    # fast --import exit is a separately retained failing baseline profile.
    Base=[Args.editor.resolve(),'--headless','--disable-crash-handler','--single-threaded-scene','--path',Project]
    Commands.append(Execute(Base+['--editor','--max-fps','60','--quit-after','120'],Output/'open.log',60,Environment))
    Commands.append(Execute(Base+['--export-release','Windows Desktop',Standalone/'OrbRun.exe'],Output/'export.log',60,Environment))
    Library=Project/'GodotLuau/bin/godot_luau.windows.template_release.x86_64.dll'
    Worker=Project/'GodotLuau/bin/godot_luau_store_worker.exe'
    for File in (Library,Worker):
        assert (Standalone/File.name).is_file() and Hash(Standalone/File.name)==Hash(File), 'Export omitted or changed native product: '+File.name
    Commands.append(Execute([Standalone/'OrbRun.exe','--headless','--disable-crash-handler',
        '--max-fps','30','--quit-after','90'],Output/'startup.log',20,Environment,Standalone))
    for Name in ('open','export','startup'):
        Text=(Output/(Name+'.log')).read_text(errors='replace')
        assert 'ERROR:' not in Text and 'SCRIPT ERROR' not in Text and '[Runtime:Script]' not in Text, 'Native workflow error: '+Name
    Marker={'OrbRun':'[OrbRun:Lifecycle] Ready','Native2D':'[Foundation:2D] Ready','Native3D':'[Foundation:3D] Ready','UI':'[Foundation:UI] Ready'}[Args.profile]
    assert Marker in (Output/'startup.log').read_text(errors='replace'), 'Exported Luau entrypoint did not initialize'
    assert not list(Project.rglob('*.gd')), 'Application package contains developer GDScript'
    Record={'Passed':True,'Commands':Commands,'Candidate':json.loads((Args.candidate/'candidate.json').read_text()),
            'Project':json.loads((Project/'authoring-project.json').read_text()),
            'StandaloneFiles':{File.name:Hash(File) for File in Standalone.iterdir() if File.is_file()},
            'Interactive':False,'Graphical':False}
    (Output/'results.json').write_text(json.dumps(Record,indent=2)+'\n')
    print('[Authoring:Export] PASS',Output)


if __name__=='__main__':
    try:Main()
    finally:StopAll()
