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
from SourceFingerprint import GetFingerprint


def Cpu(Process, Before):
    if os.name != 'nt':
        import resource
        After = resource.getrusage(resource.RUSAGE_CHILDREN)
        User, Kernel = After.ru_utime-Before.ru_utime, After.ru_stime-Before.ru_stime
    else:
        from ctypes import wintypes
        Times = [wintypes.FILETIME() for Index in range(4)]
        Function = ctypes.windll.kernel32.GetProcessTimes
        Function.argtypes = [wintypes.HANDLE, *[ctypes.POINTER(wintypes.FILETIME)]*4]
        if not Function(int(Process._handle), *[ctypes.byref(Value) for Value in Times]): raise ctypes.WinError()
        Kernel, User = [(Value.dwHighDateTime*4294967296+Value.dwLowDateTime)/10000000.0 for Value in Times[2:]]
    return {'User': User, 'Kernel': Kernel, 'Total': User+Kernel, 'Scope': 'whole owned Godot actor including startup and GDScript harness; rendering/physics/networking are not separately attributed OS CPU'}


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
    Inputs = {'SourceAtInvocation': GetFingerprint(Source), 'HarnessHashes': {File.name: hashlib.sha256(File.read_bytes().replace(b'\r\n',b'\n')).hexdigest() for File in sorted((Source/'tests/runtime').iterdir()) if File.suffix in ['.py','.gd','.cpp','.pem'] or File.name in ['CMakeLists.txt','GodotDistribution.json']}, 'Trials': Args.trials, 'SamplesPerPhysicsWindow': Args.samples, 'Counts': Args.counts, 'Graphical': Args.graphical, 'GodotSHA256': hashlib.sha256(Args.godot.read_bytes()).hexdigest()}
    (Args.output/'inputs.json').write_text(json.dumps(Inputs,indent=2))
    try:
        Import = Assets(Args.godot, Source, Args.output, Environment)
        for Trial in range(Args.trials):
            Variants = [('Candidate', Args.extension)]
            if Args.baseline: Variants.insert(0, ('Baseline', Args.baseline))
            if Trial % 2: Variants.reverse()
            for Variant, Extension in Variants:
                ProductHash = hashlib.sha256(Extension.read_bytes()).hexdigest()
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
                Before = None
                if os.name != 'nt':
                    import resource
                    Before = resource.getrusage(resource.RUSAGE_CHILDREN)
                Started = time.monotonic()
                with (Directory / (Label + '.stdout.log')).open('w') as Out, (Directory / (Label + '.stderr.log')).open('w') as Err:
                    Actor = StartProcess([*Command, '--', '--counts', Args.counts, '--samples', str(Args.samples), *(['--graphical'] if Args.graphical else [])], Out, Err, ActorEnvironment)
                Check(Actor, time.monotonic()+180, Directory, Label, '[Character:Performance] PASS')
                Data = json.loads((Directory / 'measurements.json').read_text())
                Data['ProcessCpuSeconds'] = Cpu(Actor, Before)
                Data['ActorWallSeconds'] = time.monotonic()-Started
                if hashlib.sha256(Extension.read_bytes()).hexdigest() != ProductHash: raise ValueError('Selected product changed during measurement')
                Data.update(Variant=Variant, Trial=Trial, ExtensionSHA256=ProductHash, GodotSHA256=Inputs['GodotSHA256'])
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
        if GetFingerprint(Source) != Inputs['SourceAtInvocation']: raise ValueError('Native source changed during comparison')
        print('[Character:Performance] PASS complete; graphical=' + str(Args.graphical))
    finally: StopAll()


if __name__ == '__main__': Main()
