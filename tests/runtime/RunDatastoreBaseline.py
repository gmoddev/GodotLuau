"""Controlled GL-009 baseline only; never treats candidate transaction behavior as a baseline PASS."""
import argparse
import ctypes
import json
import os
from pathlib import Path
import sys
import time
from RunQualification import Prepare, Start, Check
from FixtureProcesses import StartProcess, StopProcess, StopAll
from SourceFingerprint import GetFingerprint


def Main():
    Parser=argparse.ArgumentParser(description=__doc__)
    Parser.add_argument('--godot',type=Path,required=True)
    Parser.add_argument('--extension',type=Path,required=True)
    Parser.add_argument('--probe',type=Path,required=True)
    Parser.add_argument('--output',type=Path,required=True)
    Args=Parser.parse_args()
    Args.output=Args.output.resolve()
    Args.output.mkdir(parents=True,exist_ok=False)
    if os.name=='nt': ctypes.windll.kernel32.SetErrorMode(0x8003)
    Environment=dict(os.environ,GODOT_SILENCE_ROOT_WARNING='1')
    Results=[]
    for Mode in ['writers','failures']:
        Project=Args.output/Mode
        Prepare(Project,Args.extension.resolve())
        ActorEnvironment=dict(Environment)
        for Name in ['APPDATA','LOCALAPPDATA','XDG_CONFIG_HOME','XDG_DATA_HOME','XDG_CACHE_HOME']:
            Directory=Project/'profile'/Name
            Directory.mkdir(parents=True)
            ActorEnvironment[Name]=str(Directory)
        def Actor(Case,Role):
            Label=Case+'-'+Role
            return Start(Args.godot.resolve(),Project,'DatastoreBaseline.gd',Label,['--mode',Case,'--role',Role],ActorEnvironment),Label
        def Finish(Entry,Case):
            Process,Label=Entry
            Result=Check(Process,time.monotonic()+20,Project,Label,'[Persistence:Baseline] PASS '+Case)
            if '[Runtime:Script]' in (Project/(Label+'.stdout.log')).read_text(errors='replace'):
                raise RuntimeError('[Persistence:Baseline] Unexpected script error')
            Results.append(Result)
        if Mode=='failures': Finish(Actor('failures','single'),'failures'); continue
        Finish(Actor('seed','seed'),'seed')
        Entries=[Actor('writers',Role) for Role in ['A','B']]
        Deadline=time.monotonic()+10
        while not all((Project/('observed-'+Role)).exists() for Role in ['A','B']):
            if time.monotonic()>Deadline: raise RuntimeError('[Persistence:Baseline] Observation barrier timed out')
            time.sleep(0.01)
        # Both transforms captured the same committed0. Serialize their releases
        # so this demonstrates a lost update without relying on write timing.
        for Entry,Role in zip(Entries,['A','B']):
            (Project/('release-'+Role)).write_text('release')
            Finish(Entry,'writers')
        Finish(Actor('verify','fresh-reader'),'verify')
    Root=Args.output/'interrupted'
    Root.mkdir()
    Label='interrupted'
    with (Root/'stdout.log').open('w') as Out,(Root/'stderr.log').open('w') as Err:
        Process=StartProcess([str(Args.probe.resolve()),str(Root)],Out,Err,Environment)
    Deadline=time.monotonic()+5
    while not (Root/'truncated.marker').exists():
        if Process.poll() is not None or time.monotonic()>Deadline:
            raise RuntimeError('[Persistence:Baseline] Native truncation hook not reached')
        time.sleep(0.005)
    StopProcess(Process)
    Previous=json.loads((Root/'previous-sentinel.json').read_text())
    Current=(Root/'ds_GL009_interrupted.json').read_bytes()
    assert Previous=={'Sentinel':12345} and Current==b''
    Record={'Source':GetFingerprint(Path(__file__).resolve().parents[2]),'Actors':Results,'Interrupted':{'Exit':Process.returncode,'Prior':Previous,'ResultBytes':len(Current),'Disposition':'Real successful native truncation, controlled pause, then owned process termination; no power-loss claim'}}
    (Args.output/'results.json').write_text(json.dumps(Record,indent=2))
    print('[Persistence:Baseline] PASS deterministic lost update, failure behavior and interrupted native truncation')


if __name__=='__main__':
    try: Main()
    finally: StopAll()
