"""Bounded actual game playtest; reuses existing owned-process cleanup."""
import argparse
import ctypes
import json
import os
from pathlib import Path
import shutil
import subprocess
from FixtureProcesses import StartProcess, StopProcess, WindowsJob, Processes


def Main():
    Parser = argparse.ArgumentParser(description=__doc__)
    Parser.add_argument('--game',type=Path,required=True)
    Parser.add_argument('--output',type=Path,required=True)
    Parser.add_argument('--scenario',default='local',choices=['local','observer','recovery','combat','coop','server'])
    Parser.add_argument('--mode',choices=['solo','host','join','server'])
    Parser.add_argument('--address',default='127.0.0.1')
    Parser.add_argument('--port',default=24870,type=int)
    Parser.add_argument('--graphical',action='store_true')
    Parser.add_argument('--timeout',type=int,default=240)
    Parser.add_argument('--verbose',action='store_true')
    Args = Parser.parse_args()
    Root = Args.game.resolve()
    Args.output.mkdir(parents=True,exist_ok=False)
    shutil.copy2(Path(__file__).with_name('RelaySiege.gd'),Root/'RelaySiege.gd')
    Command = [str(Root/'RelaySiege.exe'),'--path',str(Root),'--script','res://RelaySiege.gd','--max-fps','30']
    if Args.graphical: Command += ['--position','16000,16000','--resolution','1152x720']
    else: Command += ['--headless']
    if Args.verbose: Command += ['--verbose']
    Command += ['--','--probe','--scenario',Args.scenario,'--port',str(Args.port),'--address',Args.address]
    if Args.mode: Command += ['--mode',Args.mode]
    if Args.mode=='server': Command += ['--glserver',str(Args.port)]
    if Args.graphical: Command += ['--graphical']
    Environment = dict(os.environ,APPDATA=str(Root/'Data'))
    if os.name=='nt': ctypes.windll.kernel32.SetErrorMode(0x8003)
    with (Args.output/'stdout.log').open('w') as Out,(Args.output/'stderr.log').open('w') as Err:
        if os.name=='nt' and Args.graphical:
            Startup = subprocess.STARTUPINFO()
            Startup.dwFlags = subprocess.STARTF_USESHOWWINDOW
            Startup.wShowWindow = 4  # SW_SHOWNOACTIVATE; the game also sets NO_FOCUS.
            Job = WindowsJob()
            Process = subprocess.Popen(Command,stdout=Out,stderr=Err,env=Environment,startupinfo=Startup,creationflags=subprocess.CREATE_NO_WINDOW|subprocess.CREATE_NEW_PROCESS_GROUP)
            if not Job[0].AssignProcessToJobObject(Job[1],int(Process._handle)):
                Process.kill(); Process.wait(); Job[0].CloseHandle(Job[1]); raise ctypes.WinError()
            Process.FixtureJob = Job
            Processes.append(Process)
        else: Process = StartProcess(Command,Out,Err,Environment)
        try: Code = Process.wait(timeout=Args.timeout)
        finally: StopProcess(Process)
    Report = json.loads((Root/'gameplay-result.json').read_text())
    for Name in ['gameplay-result.json',*([Report['Screenshot']] if Report.get('Screenshot') else [])]:
        if (Root/Name).exists(): shutil.copy2(Root/Name,Args.output/Name)
    (Args.output/'command.json').write_text(json.dumps({'Command':Command,'Exit':Code,'Timeout':Args.timeout,'Graphical':Args.graphical},indent=2))
    print('[Game:Playtest] Exit',Code,'evidence',Args.output)
    return Code


if __name__=='__main__': raise SystemExit(Main())
