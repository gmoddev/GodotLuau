"""Qualify the actual new Luau-only project with an external native-game observer."""
import argparse
import ctypes
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

from FixtureProcesses import StartProcess, StopAll, GetProfileFolder
from RunQualification import Check


def Main():
    Parser=argparse.ArgumentParser(description=__doc__)
    Parser.add_argument('--godot',type=Path,required=True)
    Parser.add_argument('--extension',type=Path,required=True)
    Parser.add_argument('--source',type=Path,required=True)
    Parser.add_argument('--output',type=Path,required=True)
    Args=Parser.parse_args()
    Output=Args.output.resolve();Output.mkdir(parents=True,exist_ok=False)
    Project=Output/'project'
    Repository=Path(__file__).resolve().parents[2]
    subprocess.run([sys.executable,str(Repository/'examples/luau-only/PrepareProject.py'),
        '--adapter',str(Args.extension.resolve()),'--adapter-source',str(Args.source.resolve()),
        '--output',str(Project)],check=True)
    shutil.copy2(Path(__file__).with_name('LuauOnlyGame.gd'),Project/'LuauOnlyGame.gd')
    (Project/'ProbeModule.luau').write_text('return {Value=1}\n')
    (Project/'.godot').mkdir(exist_ok=True)
    (Project/'.godot/global_script_class_cache.cfg').write_text('list=[]\n')
    # Same explicit extension admission as the existing native fixtures. A normal
    # user project obtains this cache through its first editor import/scan.
    (Project/'.godot/extension_list.cfg').write_text('res://godot_luau.gdextension\n')
    Environment=dict(os.environ,GODOT_SILENCE_ROOT_WARNING='1')
    for Name in ('APPDATA','LOCALAPPDATA','XDG_CONFIG_HOME','XDG_DATA_HOME','XDG_CACHE_HOME'):
        Environment[Name]=str(GetProfileFolder(Output,Name))
    if os.name=='nt':ctypes.windll.kernel32.SetErrorMode(0x8003)
    Command=[str(Args.godot.resolve()),'--disable-crash-handler','--headless','--single-threaded-scene',
             '--path',str(Project),'--max-fps','30','--script','res://LuauOnlyGame.gd']
    with (Output/'game.stdout.log').open('w') as Stdout,(Output/'game.stderr.log').open('w') as Stderr:
        Process=StartProcess(Command,Stdout,Stderr,Environment)
    Result=Check(Process,time.monotonic()+40,Output,'game','[Authoring:GameQualification] PASS')
    Detail=json.loads((Project/'luau-only-results.json').read_text());assert Detail['Passed'],Detail
    Stdout=(Output/'game.stdout.log').read_text(errors='replace')
    Stderr=(Output/'game.stderr.log').read_text(errors='replace')
    assert '[Runtime:Script]' not in Stdout and 'SCRIPT ERROR' not in Stderr and 'ERROR:' not in Stderr
    Result.update(Detail,Command=Command,NativeSource=json.loads(Args.source.read_text()),
                  ExtensionSHA256=hashlib.sha256(Args.extension.read_bytes()).hexdigest(),Graphical=False)
    (Output/'results.json').write_text(json.dumps(Result,indent=2)+'\n')
    print('[Authoring:GameQualification] PASS',Output)


if __name__=='__main__':
    try:Main()
    finally:StopAll()
