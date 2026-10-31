"""Record GL-023 behavior of the unchanged production adapter on owned loopback endpoints."""
import argparse
import json
import os
from pathlib import Path
import time
from HttpFixtureServer import Serve
from RunQualification import Prepare, Start, Check

Parser = argparse.ArgumentParser()
Parser.add_argument('--godot', type=Path, required=True)
Parser.add_argument('--extension', type=Path, required=True)
Parser.add_argument('--output', type=Path, required=True)
Args = Parser.parse_args()
Results = []
for Mode in ['enabled', 'unavailable']:
    Project = Args.output / Mode
    Prepare(Project, Args.extension)
    Environment = dict(os.environ)
    for Name in ['APPDATA', 'LOCALAPPDATA', 'XDG_CONFIG_HOME', 'XDG_DATA_HOME', 'XDG_CACHE_HOME']:
        Directory = Project / 'profile' / Name
        Directory.mkdir(parents=True)
        Environment[Name] = str(Directory.resolve())
    with Serve() as (State, Origin):
        Extra = ['--origin', Origin, '--denied', State.Origins['Denied']]
        if Mode == 'unavailable': Extra += ['--unavailable']
        Label = 'httpservice-baseline-' + Mode
        Process = Start(Args.godot, Project, 'HttpServiceBaseline.gd', Label, Extra, Environment)
        Results.append(Check(Process, time.monotonic() + 30, Project, Label, '[Runtime:HttpServiceBaseline] PASS'))
    assert not any(Hit['Path'].startswith('/forbidden') for Hit in State.Hits)
    (Project / 'server-results.json').write_text(json.dumps({'Hits': State.Hits}, indent=2))
(Args.output / 'results.json').write_text(json.dumps(Results, indent=2))
print('[Runtime:HttpServiceBaseline] PASS both baseline actors; no forbidden hits')
