"""Measure the same native ENet/remote-character workload using a selected product."""
import argparse, ctypes, json, os, time
from pathlib import Path
from FixtureProcesses import StopAll
from RunQualification import Prepare, Start, Check, Port

def Main():
    Parser = argparse.ArgumentParser(description=__doc__)
    for Name in ['godot', 'extension', 'output']: Parser.add_argument('--'+Name, type=Path, required=True)
    Args = Parser.parse_args()
    assert not Args.output.exists()
    if os.name == 'nt': ctypes.windll.kernel32.SetErrorMode(0x8003)
    Prepare(Args.output, Args.extension)
    Environment = dict(os.environ, GODOT_SILENCE_ROOT_WARNING='1')
    for Name in ['APPDATA','LOCALAPPDATA','XDG_CONFIG_HOME','XDG_DATA_HOME','XDG_CACHE_HOME']:
        Directory = Args.output/'profile'/Name
        Directory.mkdir(parents=True)
        Environment[Name] = str(Directory.resolve())
    (Args.output/'profile/.gdignore').write_text('')
    Selected = Port()
    Entries = []
    try:
        for Role, Index in [('server','0'),('client','1'),('client','2')]:
            Label = Role+Index
            Process = Start(Args.godot.resolve(),Args.output.resolve(),'CharacterNetworkBenchmarks.gd',Label,['--fixture-role',Role,'--fixture-port',str(Selected),'--fixture-client-index',Index],Environment)
            Entries.append((Process,Label))
        Results = []
        Measurements = []
        for Process, Label in Entries:
            Results.append(Check(Process,time.monotonic()+60,Args.output,Label,'[Character:NetworkBenchmark] PASS'))
            Lines=(Args.output/(Label+'.stdout.log')).read_text(errors='replace').splitlines()
            Measurements.append(json.loads(next(Line.removeprefix('[Character:NetworkBenchmark] ') for Line in Lines if Line.startswith('[Character:NetworkBenchmark] {'))))
        (Args.output/'results.json').write_text(json.dumps(Results,indent=2))
        (Args.output/'measurements.json').write_text(json.dumps(Measurements,indent=2))
        print('[Character:NetworkBenchmark] PASS',Args.output,flush=True)
    finally: StopAll()

if __name__=='__main__': Main()
