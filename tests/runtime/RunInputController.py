"""Run the Luau controller example using the established isolated native project."""
import argparse
import ctypes
import json
import os
import subprocess
from pathlib import Path
import time
from FixtureProcesses import GetProfileFolder, StartProcess, StopAll
from RunQualification import Prepare, Check

def Main():
    Parser=argparse.ArgumentParser(description=__doc__)
    for Name in ['godot','extension','output']: Parser.add_argument('--'+Name,type=Path,required=True)
    Mode=Parser.add_mutually_exclusive_group()
    Mode.add_argument('--interactive',action='store_true',help='Visible manual play; never used by automated qualification')
    Mode.add_argument('--graphical',action='store_true',help='Offscreen Windows rendering fixture, without physical mouse capture')
    Parser.add_argument('--seconds',type=float,default=60,help='Bounded process lifetime, including manual play')
    Args=Parser.parse_args()
    if not 1<=Args.seconds<=3600: Parser.error('seconds must be within [1,3600]')
    Args.output.mkdir(parents=True,exist_ok=False)
    if os.name=='nt': ctypes.windll.kernel32.SetErrorMode(0x8003)
    Prepare(Args.output,Args.extension.resolve())
    with (Args.output/'project.godot').open('a') as Config:
        Config.write('\n[display]\nwindow/size/viewport_width=960\nwindow/size/viewport_height=540\n')
    Environment=dict(os.environ,GODOT_SILENCE_ROOT_WARNING='1')
    for Name in ['APPDATA','LOCALAPPDATA','XDG_CONFIG_HOME','XDG_DATA_HOME','XDG_CACHE_HOME']:
        Environment[Name]=str(GetProfileFolder(Args.output,Name))
    Command=[str(Args.godot.resolve()),'--disable-crash-handler','--single-threaded-scene','--path',str(Args.output.resolve()),'--script','res://InputControllerDemo.gd','--max-fps','120']
    if Args.graphical:
        Command+=['--display-driver','windows','--rendering-method','gl_compatibility','--rendering-driver','opengl3','--position','-32000,-32000','--resolution','960x540']
    elif not Args.interactive: Command+=['--headless']
    Command+=['--']
    if not Args.interactive: Command+=['--fixture']
    if Args.graphical: Command+=['--graphical']
    (Args.output/'command.json').write_text(json.dumps(Command,indent=2))
    with (Args.output/'demo.stdout.log').open('w') as Out, (Args.output/'demo.stderr.log').open('w') as Err:
        Child=StartProcess(Command,Out,Err,Environment)
    if Args.interactive:
        try: Code=Child.wait(timeout=Args.seconds)
        except subprocess.TimeoutExpired: Code='TIMEOUT'
        print('[Input:Demo] Manual session exit',Code)
    else:
        print(Check(Child,time.monotonic()+Args.seconds,Args.output,'demo','[Input:Demo] PASS'))

if __name__=='__main__':
    try: Main()
    finally: StopAll()
