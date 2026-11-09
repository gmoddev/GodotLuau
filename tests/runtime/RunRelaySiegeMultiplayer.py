"""Run the actual game as a four-player listen or dedicated ENet session."""
import argparse
import ctypes
import json
import os
from pathlib import Path
import subprocess
import sys
import time
from FixtureProcesses import StartProcess, StopAll
from RunQualification import Port


def Main():
    Parser = argparse.ArgumentParser(description=__doc__)
    for Name in ['candidate','engine','host-manifest','assets','output']:
        Parser.add_argument('--'+Name,required=True,type=Path)
    Parser.add_argument('--dedicated',action='store_true')
    Parser.add_argument('--graphical',action='store_true')
    Args = Parser.parse_args()
    Args.output.mkdir(parents=True,exist_ok=False)
    Repository = Path(__file__).resolve().parents[2]
    SelectedPort = Port()
    if os.name=='nt': ctypes.windll.kernel32.SetErrorMode(0x8003)
    Actors = []
    Logs = []
    def Stage(Name):
        Game = Args.output/Name/'game'
        subprocess.run([sys.executable,str(Repository/'examples/e2e-game/PrepareGame.py'),'--candidate',str(Args.candidate),'--engine',str(Args.engine),'--host-manifest',str(Args.host_manifest),'--assets',str(Args.assets),'--output',str(Game),'--profile','RelaySiegeMP'],check=True,timeout=30,capture_output=True)
        return Game
    def Launch(Name, Scenario, Mode):
        Game = Stage(Name)
        Output = Args.output/Name/'evidence'
        Command = [sys.executable,str(Path(__file__).with_name('RunRelaySiege.py')),'--game',str(Game),'--output',str(Output),'--scenario',Scenario,'--mode',Mode,'--port',str(SelectedPort),'--timeout','220']
        if Args.graphical and Mode!='server': Command += ['--graphical']
        Out=(Args.output/(Name+'.stdout.log')).open('w'); Err=(Args.output/(Name+'.stderr.log')).open('w'); Logs.extend([Out,Err])
        Process = StartProcess(Command,Out,Err,dict(os.environ))
        Actors.append((Name,Process,Game,Output))
        return Game,Output
    if Args.dedicated:
        _,Ready=Launch('server','server','server')
    else:
        _,Ready=Launch('leader','coop','host')
    Deadline=time.monotonic()+20
    while not (Ready/'stdout.log').exists() or '[Game:Session] Started' not in (Ready/'stdout.log').read_text(errors='replace'):
        if time.monotonic()>Deadline: raise RuntimeError('Actual game server startup failed')
        time.sleep(.05)
    if Args.dedicated: Launch('leader','coop','join')
    Launch('observer1','observer','join')
    Launch('observer2','observer','join')
    time.sleep(2)  # Bounded deliberate late join, not a substitute for game readiness.
    Launch('latejoin','observer','join')
    Deadline=time.monotonic()+225
    Leader=next(P for Name,P,_,_ in Actors if Name=='leader')
    while Leader.poll() is None and time.monotonic()<Deadline: time.sleep(.1)
    if Leader.poll() is None: raise TimeoutError('Game session deadline')
    if Args.dedicated:
        Server=next(Game for Name,_,Game,_ in Actors if Name=='server')
        (Server/'stop-game').write_text('normal fixture shutdown')
    Results=[]
    for Name,Process,_,Output in Actors:
        Exit=Process.wait(timeout=15)
        Report=json.loads((Output/'gameplay-result.json').read_text())
        Results.append({'Actor':Name,'Exit':Exit,'Report':Report})
    (Args.output/'session.json').write_text(json.dumps({'Dedicated':Args.dedicated,'Graphical':Args.graphical,'Port':SelectedPort,'Results':Results},indent=2))
    Failed=any(R['Exit'] or R['Report']['Failed'] for R in Results)
    print('[Game:Multiplayer]', 'FAIL' if Failed else 'PASS','four players','Dedicated' if Args.dedicated else 'Listen')
    return int(Failed)


if __name__=='__main__':
    try: raise SystemExit(Main())
    finally: StopAll()
