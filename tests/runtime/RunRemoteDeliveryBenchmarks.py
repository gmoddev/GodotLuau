"""Interleave immutable baseline/candidate production ENet workloads."""
import argparse
import ctypes
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import time
from FixtureProcesses import StartProcess, StopAll, GetProfileFolder
from RunQualification import Prepare, Check, Port


def Hash(File): return hashlib.sha256(Path(File).read_bytes()).hexdigest()


def Main():
    Parser = argparse.ArgumentParser(description=__doc__)
    for Name in ['candidate', 'baseline', 'candidate-identity', 'baseline-identity', 'host-manifest', 'baseline-host-manifest', 'output']:
        Parser.add_argument('--'+Name, type=Path, required=True)
    Parser.add_argument('--counts', default='1,16,32,64')
    Parser.add_argument('--trials', type=int, default=2)
    Parser.add_argument('--samples', type=int, default=64)
    Args = Parser.parse_args()
    Counts = [int(Value) for Value in Args.counts.split(',')]
    if not Counts or len(set(Counts)) != len(Counts) or any(Value not in [1,16,32,64] for Value in Counts) or not 1 <= Args.trials <= 5 or not 32 <= Args.samples <= 256:
        Parser.error('Use distinct 1/16/32/64 peer counts, 1–5 trials and 32–256 measured samples')
    if os.name == 'nt': ctypes.windll.kernel32.SetErrorMode(0x8003)
    Args.output = Args.output.resolve(); Args.output.mkdir(parents=True, exist_ok=False)
    Configurations = {}
    for Name, Library, IdentityFile, HostFile in [
        ('Baseline', Args.baseline, Args.baseline_identity, Args.baseline_host_manifest),
        ('Candidate', Args.candidate, Args.candidate_identity, Args.host_manifest)]:
        Identity = json.loads(IdentityFile.read_text()); Host = json.loads(HostFile.read_text())
        if Identity['Products'].get(Library.name) != Hash(Library) or Host['ExecutableSHA256'] != Hash(Host['Executable']) or Host['CompilerSHA256'] != Identity['CompilerSHA256']:
            raise ValueError('Immutable product/host/compiler identity mismatch: '+Name)
        Configurations[Name] = {'Library': str(Library.resolve()), 'Identity': Identity, 'Host': Host}
    Baseline, Candidate = Configurations['Baseline'], Configurations['Candidate']
    if Baseline['Identity']['CompilerSHA256'] != Candidate['Identity']['CompilerSHA256'] or Baseline['Host']['EngineRevision'] != Candidate['Host']['EngineRevision'] or Baseline['Host']['Command'][1:] != Candidate['Host']['Command'][1:]:
        raise ValueError('Compare the same compiler, pinned engine and build arguments')
    Runtime = Path(__file__).parent
    Inputs = {'Configurations': Configurations, 'Counts': Counts, 'Trials': Args.trials, 'Samples': Args.samples,
              'Hardware': platform.uname()._asdict(), 'MaxFPS': 120,
              'FixtureHashes': {Name: Hash(Runtime/Name) for Name in ['RemoteDeliveryBenchmark.gd','CharacterDispatchProbe.gd']},
              'Scope': 'Repeated real ENet network-only Fire/echo; no graphics or Character work; sampled native high water is not an exact peak; ASan/optimization profile is identified by immutable build records'}
    (Args.output/'inputs.json').write_text(json.dumps(Inputs, indent=2))
    Results = []
    try:
        for Count in Counts:
            for Trial in range(Args.trials):
                Order = ['Baseline','Candidate'] if Trial % 2 == 0 else ['Candidate','Baseline']
                for Name in Order:
                    Configuration = Configurations[Name]
                    Library = Path(Configuration['Library']); Godot = Path(Configuration['Host']['Executable'])
                    if Hash(Library) != Configuration['Identity']['Products'][Library.name] or Hash(Godot) != Configuration['Host']['ExecutableSHA256']:
                        raise ValueError('Product changed during comparison')
                    Output = Args.output/(str(Count)+'-'+str(Trial)+'-'+Name)
                    Prepare(Output, Library)
                    for Fixture in Inputs['FixtureHashes']: shutil.copy2(Runtime/Fixture, Output/Fixture)
                    Environment = dict(os.environ, GODOT_SILENCE_ROOT_WARNING='1', GL_QUALIFICATION_PROFILE_ROOT=str(Args.output/'profiles'))
                    Environment['ASAN_OPTIONS'] = 'halt_on_error=1:log_path="'+(Output/'asan-report').as_posix()+'"'
                    for Variable in ['APPDATA','LOCALAPPDATA','XDG_CONFIG_HOME','XDG_DATA_HOME','XDG_CACHE_HOME']:
                        Environment[Variable] = str(GetProfileFolder(Output, Variable))
                    Entries = []; Actors = []; Started = time.monotonic(); SelectedPort = Port()
                    try:
                        for Role, Index in [('server', 0), *[('client', Index) for Index in range(1, Count+1)]]:
                            Label = Role+str(Index)
                            Command = [str(Godot), '--headless', '--disable-crash-handler', '--single-threaded-scene', '--path', str(Output), '--script', 'res://RemoteDeliveryBenchmark.gd', '--max-fps', '120', '--', '--fixture-role', Role, '--fixture-client-index', str(Index), '--fixture-port', str(SelectedPort), '--peers', str(Count), '--samples', str(Args.samples)]
                            with (Output/(Label+'.stdout.log')).open('w') as Out, (Output/(Label+'.stderr.log')).open('w') as Err:
                                Child = StartProcess(Command, Out, Err, Environment)
                            Entries.append((Child, Label))
                            if Role == 'server':
                                Deadline = time.monotonic()+30
                                while not (Output/'bench-server-ready').exists():
                                    if Child.poll() is not None or time.monotonic() > Deadline: raise RuntimeError('Benchmark server startup failed')
                                    time.sleep(.02)
                        Deadline = time.monotonic()+180
                        for Child, Label in Entries:
                            Check(Child, Deadline, Output, Label, '[Network:DeliveryBenchmark] PASS')
                            Record = json.loads((Output/('bench-'+Label+'.json')).read_text())
                            if Record['Peers'] != Count or Record['SamplesPerPeer'] != Args.samples or Record['Graphical'] or Record['Characters'] != 0:
                                raise ValueError('Benchmark workload mismatch')
                            Expected = (16+Args.samples)*(Count if Record['Role']=='server' else 1)
                            if Record['CallbackStarts'] != Expected: raise ValueError('Benchmark handler count mismatch')
                            Actors.append(Record)
                        Unexpected = list(Output.glob('asan-report*'))
                        if Unexpected: raise RuntimeError('Unexpected benchmark sanitizer reports')
                        Results.append({'Configuration': Name, 'Peers': Count, 'Trial': Trial, 'Seconds': time.monotonic()-Started, 'Actors': Actors})
                        (Args.output/'measurements.json').write_text(json.dumps(Results, indent=2))
                        print('[Network:DeliveryBenchmark] PASS '+Name+' peers='+str(Count)+' trial='+str(Trial), flush=True)
                    finally: StopAll()
        (Args.output/'summary.json').write_text(json.dumps({'Result': 'PASS', 'Runs': len(Results), 'Repeated': Args.trials >= 2, 'Inputs': Inputs, 'Files': {str(File.relative_to(Args.output)): Hash(File) for File in Args.output.rglob('*.json') if File.name != 'summary.json'}}, indent=2))
    finally: StopAll()


if __name__ == '__main__': Main()
