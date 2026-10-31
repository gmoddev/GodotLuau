"""Repeated alternating Character V2 measurements; no source mutation or tuning."""
import argparse
import ctypes
import hashlib
import json
import os
from pathlib import Path
import statistics
import time
from FixtureProcesses import StartProcess, StopAll
from RunQualification import Check
from RunCharacterPresentation import Assets, Project


def Main():
    Parser = argparse.ArgumentParser(description=__doc__)
    for Name in ['godot', 'extension', 'output']: Parser.add_argument('--'+Name, type=Path, required=True)
    Parser.add_argument('--baseline', type=Path)
    Parser.add_argument('--trials', type=int, default=5)
    Parser.add_argument('--samples', type=int, default=240)
    Parser.add_argument('--counts', default='1,16,32,64')
    Parser.add_argument('--graphical', action='store_true')
    Args = Parser.parse_args()
    for Name in ['godot', 'extension', 'output', 'baseline']:
        if getattr(Args, Name): setattr(Args, Name, getattr(Args, Name).resolve())
    if Args.output.exists(): raise ValueError('Use fresh benchmark output')
    if os.name == 'nt': ctypes.windll.kernel32.SetErrorMode(0x8003)
    Args.output.mkdir(parents=True)
    Environment = dict(os.environ)
    Source = Path(__file__).resolve().parents[2]
    Measurements = []
    try:
        Import = Assets(Args.godot, Source, Args.output, Environment)
        for Trial in range(Args.trials):
            Variants = [('Candidate', Args.extension)]
            if Args.baseline: Variants.insert(0, ('Baseline', Args.baseline))
            if Trial % 2: Variants.reverse()
            for Variant, Extension in Variants:
                Label = Variant + '-' + str(Trial)
                Directory = Args.output / Label
                Project(Directory, Extension, Import)
                ActorEnvironment = dict(Environment)
                for Name in ['APPDATA', 'LOCALAPPDATA', 'XDG_CONFIG_HOME', 'XDG_DATA_HOME', 'XDG_CACHE_HOME']:
                    Profile = Directory / 'profile' / Name
                    Profile.mkdir(parents=True)
                    ActorEnvironment[Name] = str(Profile)
                Command = [str(Args.godot), '--disable-crash-handler', '--single-threaded-scene', '--path', str(Directory), '--script', 'res://CharacterPerformance.gd', '--max-fps', '120']
                if Args.graphical: Command += ['--display-driver', 'windows', '--rendering-method', 'gl_compatibility', '--rendering-driver', 'opengl3', '--position', '-32000,-32000', '--resolution', '960x540']
                else: Command += ['--headless']
                with (Directory / (Label + '.stdout.log')).open('w') as Out, (Directory / (Label + '.stderr.log')).open('w') as Err:
                    Actor = StartProcess([*Command, '--', '--counts', Args.counts, '--samples', str(Args.samples), *(['--graphical'] if Args.graphical else [])], Out, Err, ActorEnvironment)
                Check(Actor, time.monotonic()+180, Directory, Label, '[Character:Performance] PASS')
                Data = json.loads((Directory / 'measurements.json').read_text())
                Data.update(Variant=Variant, Trial=Trial, ExtensionSHA256=hashlib.sha256(Extension.read_bytes()).hexdigest(), GodotSHA256=hashlib.sha256(Args.godot.read_bytes()).hexdigest())
                Measurements.append(Data)
                (Directory / 'measurements.json').write_text(json.dumps(Data, indent=2))
                # The selected immutable products and hashes retain binary identity;
                # redundant per-trial loader copies are unnecessary after exit.
                (Directory / ('godot_luau.dll' if os.name == 'nt' else 'godot_luau.so')).unlink()
                print('[Character:Performance] PASS ' + Label, flush=True)
        (Args.output / 'measurements.json').write_text(json.dumps(Measurements, indent=2))
        Summary = []
        for Variant in sorted(set(Item['Variant'] for Item in Measurements)):
            Trials = [Item for Item in Measurements if Item['Variant'] == Variant]
            Groups = sorted(set((Profile['Characters'], Profile['Mode']) for Item in Trials for Profile in Item['Profiles']))
            for Count, Mode in Groups:
                Profiles = [Profile for Item in Trials for Profile in Item['Profiles'] if Profile['Characters'] == Count and Profile['Mode'] == Mode]
                Summary.append({'Variant': Variant, 'Characters': Count, 'Mode': Mode, 'Trials': len(Profiles), **{Metric: {Stat: statistics.median(Profile[Metric][Stat] for Profile in Profiles) for Stat in ['Mean', 'Median', 'P95', 'P99']} for Metric in ['FrameSeconds', 'PhysicsSeconds', 'ProcessSeconds']}})
        (Args.output / 'summary.json').write_text(json.dumps(Summary, indent=2))
        print('[Character:Performance] PASS complete; graphical=' + str(Args.graphical))
    finally: StopAll()


if __name__ == '__main__': Main()
