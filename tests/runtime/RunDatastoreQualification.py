"""Independent Godot writers and controlled native commit interruption; no power-loss claim."""
import argparse
import json
import os
import shutil
from pathlib import Path
import time
from RunQualification import Prepare, Start, Check
from FixtureProcesses import StartProcess, StopProcess, StopAll


def Qualify(Args, Output, Environment):
    Results=[]
    for Case in ['basic','update','set','remove','increment','failures','lifecycle','memory','contention','unavailable','incompatible']:
        Project=Output/Case
        Prepare(Project,Args.extension)
        Worker=Project/('godot_luau_store_worker.exe' if os.name=='nt' else 'godot_luau_store_worker')
        if Case=='unavailable': Worker.unlink()
        if Case=='incompatible': shutil.copy2(Args.probe,Worker)
        Env=dict(Environment)
        for Name in ['APPDATA','LOCALAPPDATA','XDG_CONFIG_HOME','XDG_DATA_HOME','XDG_CACHE_HOME']:
            Directory=Project/'profile'/Name; Directory.mkdir(parents=True,exist_ok=True); Env[Name]=str(Directory)
        def Actor(Mode,Role='single',Expected=2):
            Label='datastore-'+Case+'-'+Mode+'-'+Role
            Script='DatastoreIntegration.gd' if Case=='basic' else 'DatastoreLifecycle.gd' if Case in ['lifecycle','memory'] else 'DatastoreTransactions.gd'
            Extra=[Case] if Case in ['lifecycle','memory'] else ['--mode',Mode,'--role',Role,'--expected',str(Expected)]
            return Start(Args.godot,Project,Script,Label,Extra,Env),Label
        def Finish(Entry,Mode):
            Process,Label=Entry
            Marker='[Persistence:DataStore] PASS prototype' if Case=='basic' else '[Persistence:Lifecycle] PASS '+Case if Case in ['lifecycle','memory'] else '[Persistence:Transactions] PASS '+Mode
            Result=Check(Process,time.monotonic()+Args.timeout,Project,Label,Marker)
            Text=(Project/(Label+'.stdout.log')).read_text(errors='replace')
            if (Case!='memory' and '[Runtime:Script]' in Text) or '[Persistence:Transactions] FAIL' in Text or '[Persistence:Lifecycle] FAIL' in Text: raise RuntimeError('Unexpected script/fixture error: '+Label)
            Results.append(Result)
        if Case=='contention':
            Entry=Actor(Case)
            Deadline=time.monotonic()+10
            while not (Project/'root.txt').is_file():
                if time.monotonic()>Deadline: raise RuntimeError('Storage root barrier failed')
                time.sleep(.01)
            Root=Path((Project/'root.txt').read_text())
            with (Project/'holder.stdout.log').open('w') as Out,(Project/'holder.stderr.log').open('w') as Err:
                Holder=StartProcess([str(Args.probe),str(Root),'pause','2'],Out,Err,Env)
            try:
                while not (Root/'stage.marker').is_file():
                    if Holder.poll() is not None or time.monotonic()>Deadline: raise RuntimeError('Lock holder failed')
                    time.sleep(.005)
                (Project/'locked.marker').write_text('locked')
                Finish(Entry,Case)
            finally: StopProcess(Holder)
            continue
        if Case in ['basic','failures','lifecycle','memory','unavailable','incompatible']:
            Finish(Actor(Case),Case); continue
        Finish(Actor('seed'),'seed')
        Expected=100 if Case=='set' else 1 if Case=='remove' else 40 if Case=='increment' else 2
        Entries=[Actor(Case,Role,Expected) for Role in ['A','B']]
        if Case!='increment':
            Deadline=time.monotonic()+15
            while not all((Project/('observed-'+Role)).is_file() for Role in ['A','B']):
                if time.monotonic()>Deadline or any(P.poll() is not None for P,_ in Entries): raise RuntimeError('DataStore observation barrier failed')
                time.sleep(.01)
            for Entry,Role in zip(Entries,['A','B']):
                (Project/('release-'+Role)).write_text('release')
                Finish(Entry,Case)
        else:
            for Entry in Entries: Finish(Entry,Case)
        Finish(Actor('verify',Expected=Expected),'verify')
    return Results


def Native(Probe,Output,Environment):
    Output.mkdir(parents=True,exist_ok=True)
    def StartProbe(Root,Mode,*Extra):
        Root.mkdir(parents=True,exist_ok=True)
        Label=Root.name+'-'+Mode+('-'+Extra[0] if Extra else '')
        with (Output/(Label+'.stdout.log')).open('w') as Out,(Output/(Label+'.stderr.log')).open('w') as Err:
            return StartProcess([str(Probe),str(Root),Mode,*Extra],Out,Err,Environment)
    def Finish(Process):
        try:
            if Process.wait(timeout=30): raise RuntimeError('Native DataStore probe failed')
        finally: StopProcess(Process)
    Finish(StartProbe(Output/'faults','contract'))
    for Stage in range(1,5):
        Root=Output/('kill-'+str(Stage))
        Finish(StartProbe(Root,'seed'))
        Child=StartProbe(Root,'pause',str(Stage))
        Deadline=time.monotonic()+5
        while not (Root/'stage.marker').is_file():
            if Child.poll() is not None or time.monotonic()>Deadline: raise RuntimeError('Commit stage not reached')
            time.sleep(.005)
        StopProcess(Child)
        Current=(Root/'ds_GL009_probe.json').read_text()
        if Current!=('123' if Stage<3 else '999'): raise RuntimeError('Interrupted commit state mismatch')
        # A fresh process must reacquire the dead holder's lock and recover stage.
        Finish(StartProbe(Root,'contract'))
    Root=Output/'increments'
    Entries=[StartProbe(Root,'increment',Role) for Role in ['A','B']]
    for Child in Entries: Finish(Child)
    Finish(StartProbe(Root,'verify-increments'))
    return {'FaultStages':4,'KillStages':4,'IndependentIncrements':40,'PowerLossTest':False}


def Main():
    Parser=argparse.ArgumentParser(description=__doc__)
    Parser.add_argument('--godot',type=Path,required=True)
    Parser.add_argument('--extension',type=Path,required=True)
    Parser.add_argument('--probe',type=Path,required=True)
    Parser.add_argument('--output',type=Path,required=True)
    Parser.add_argument('--timeout',type=int,default=40)
    Args=Parser.parse_args()
    for Name in ['godot','extension','probe','output']: setattr(Args,Name,getattr(Args,Name).resolve())
    Args.output.mkdir(parents=True,exist_ok=False)
    Env=dict(os.environ,GODOT_SILENCE_ROOT_WARNING='1')
    Results={'Actors':Qualify(Args,Args.output,Env),'Native':Native(Args.probe,Args.output/'native',Env)}
    (Args.output/'results.json').write_text(json.dumps(Results,indent=2))
    print('[Persistence:Qualification] PASS '+str(len(Results['Actors']))+' Godot actors and native interruption/recovery')


if __name__=='__main__':
    try: Main()
    finally: StopAll()
