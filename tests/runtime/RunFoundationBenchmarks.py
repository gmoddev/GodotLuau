"""Interleaved, bounded mixed networking/world workloads; retain negative runs."""
import argparse
import ctypes
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import time
import traceback
import threading
from FixtureProcesses import StartProcess, StopAll, StopProcess, GetProfileFolder
from RunQualification import Prepare, Check, Port


def Hash(File): return hashlib.sha256(Path(File).read_bytes()).hexdigest()


def Resources():
    if os.name != 'nt': return {'Available': False}
    class Memory(ctypes.Structure):
        _fields_ = [('Length', ctypes.c_ulong), ('Load', ctypes.c_ulong), *[(Name, ctypes.c_ulonglong) for Name in ['TotalPhysical', 'AvailablePhysical', 'TotalCommit', 'AvailableCommit', 'TotalVirtual', 'AvailableVirtual', 'Extended']]]
    Value = Memory(); Value.Length = ctypes.sizeof(Value)
    if not ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(Value)): return {'Available': False}
    return {'Available': True, 'PhysicalFree': Value.AvailablePhysical, 'CommitFree': Value.AvailableCommit}


def CPU(Process):
    if os.name != 'nt': return None
    Values = [ctypes.c_ulonglong() for _ in range(4)]
    if not ctypes.windll.kernel32.GetProcessTimes(ctypes.c_void_p(int(Process._handle)), *[ctypes.byref(Value) for Value in Values]): return None
    return {'WholeLifecycleKernelSeconds': Values[2].value / 1e7, 'WholeLifecycleUserSeconds': Values[3].value / 1e7}


class ResourceGuard:
    def __init__(self, Entries):
        self.Entries, self.Stopped = Entries, threading.Event()
        self.MinimumCommit, self.Aborted = None, False
        self.Thread = threading.Thread(target=self.Run, name='OwnedBenchmarkResources', daemon=True)
        self.Thread.start()

    def Run(self):
        while not self.Stopped.wait(.25):
            Value = Resources()
            if not Value['Available']: continue
            Free = Value['CommitFree']
            self.MinimumCommit = Free if self.MinimumCommit is None else min(self.MinimumCommit, Free)
            if Free < 1024 ** 3:
                self.Aborted = True
                for Process, _ in list(self.Entries):
                    if Process.poll() is None:
                        try: Process.terminate()
                        except OSError:
                            if Process.poll() is None: self.Aborted = True
                return

    def Close(self):
        self.Stopped.set(); self.Thread.join(timeout=2)
        if self.Thread.is_alive(): raise RuntimeError('Owned benchmark resource observer did not retire')


def Main():
    Parser = argparse.ArgumentParser(description=__doc__)
    for Name in ['candidate', 'baseline', 'candidate-identity', 'baseline-identity', 'host-manifest', 'output']:
        Parser.add_argument('--' + Name, type=Path, required=True)
    Parser.add_argument('--counts', default='1,16,32')
    Parser.add_argument('--worlds', default='64,512')
    Parser.add_argument('--trials', type=int, default=2)
    Parser.add_argument('--samples', type=int, default=64)
    Parser.add_argument('--configuration', choices=['ASanDebug', 'Release'], default='ASanDebug')
    Args = Parser.parse_args()
    Counts, Worlds = [int(Value) for Value in Args.counts.split(',')], [int(Value) for Value in Args.worlds.split(',')]
    if not Counts or any(Value not in [1, 16, 32] for Value in Counts) or not Worlds or any(Value not in [64, 512] for Value in Worlds) or not 1 <= Args.trials <= 2 or Args.samples not in [32, 64]:
        Parser.error('Use bounded peer/world counts, one smoke or two measured trials and 32/64 samples')
    if os.name == 'nt': ctypes.windll.kernel32.SetErrorMode(0x8003)
    Args.output = Args.output.resolve(); Args.output.mkdir(parents=True, exist_ok=False)
    Host = json.loads(Args.host_manifest.read_text())
    assert Hash(Host['Executable']) == Host['ExecutableSHA256']
    Configurations = {}
    for Name in ['Baseline', 'Candidate']:
        Product = getattr(Args, Name.lower()); Identity = json.loads(getattr(Args, Name.lower() + '_identity').read_text())
        assert Identity['Products'][Product.name] == Hash(Product) and Identity['CompilerSHA256'] == Host['CompilerSHA256']
        if Args.configuration == 'Release' and (Host.get('Configuration') != 'Release' or Identity.get('Configuration') != 'Release'): raise ValueError('Release resource profile requires verified uninstrumented Release products/host')
        Configurations[Name] = {'Product': str(Product.resolve()), 'Identity': Identity}
    Runtime = Path(__file__).parent
    Inputs = {'Configurations': Configurations, 'Configuration': Args.configuration, 'Host': Host, 'Hardware': platform.uname()._asdict(), 'Counts': Counts, 'Worlds': Worlds, 'Trials': Args.trials, 'Samples': Args.samples,
              'HarnessHashes': {Name: Hash(Runtime / Name) for Name in ['FoundationBenchmark.gd', 'RemoteDeliveryBenchmark.gd', 'CharacterDispatchProbe.gd', 'RunFoundationBenchmarks.py']},
              'Scope': 'Headless ASan Debug mixed Fire/echo, Functions, anchored world selection, native Characters, approved rig animation, property/reparent/create/destroy and relevance churn; no simulated packet loss or slow-link profile. CPU includes the entire owned actor lifecycle. Native occupancy samples are not exact peaks. ENet pop_statistic counters include protocol/resends; see Godot ENetConnection documentation.'}
    (Args.output / 'inputs.json').write_text(json.dumps(Inputs, indent=2))
    Results = []
    def Save(): (Args.output / 'measurements.json').write_text(json.dumps(Results, indent=2))
    for Count in Counts:
        for World in Worlds:
            for Trial in range(Args.trials):
                for Name in (['Baseline', 'Candidate'] if Trial % 2 == 0 else ['Candidate', 'Baseline']):
                    Resource = Resources()
                    # The prior 33-actor ASan run exhausted this worker. Require
                    # measured headroom; never repeat it as an unbounded probe.
                    RequiredCommit = max(4, Count + 2) * 1024 ** 3 if Args.configuration == 'ASanDebug' else 1024 ** 3 + (Count + 1) * 192 * 1024 ** 2
                    RequiredPhysical = max(2, Count // 2) * 1024 ** 3
                    if Resource['Available'] and (Resource['CommitFree'] < RequiredCommit or Resource['PhysicalFree'] < RequiredPhysical):
                        Results.append({'Configuration': Name, 'Peers': Count, 'World': World, 'Trial': Trial, 'Result': 'BLOCKED_RESOURCE_PREFLIGHT', 'Resources': Resource, 'RequiredCommit': RequiredCommit, 'RequiredPhysical': RequiredPhysical}); Save(); continue
                    Product = Path(Configurations[Name]['Product']); Identity = Configurations[Name]['Identity']
                    assert Hash(Product) == Identity['Products'][Product.name]
                    Output = Args.output / f'{World}-{Count}-{Trial}-{Name}'
                    Prepare(Output, Product)
                    for File in Inputs['HarnessHashes']:
                        if File.endswith('.gd'): shutil.copy2(Runtime / File, Output / File)
                    Environment = dict(os.environ, GODOT_SILENCE_ROOT_WARNING='1', GL_QUALIFICATION_PROFILE_ROOT=str(Args.output / 'profiles'))
                    Environment['ASAN_OPTIONS'] = 'halt_on_error=1:log_path="' + (Output / 'asan-report').as_posix() + '"'
                    for Variable in ['APPDATA', 'LOCALAPPDATA', 'XDG_CONFIG_HOME', 'XDG_DATA_HOME', 'XDG_CACHE_HOME']: Environment[Variable] = str(GetProfileFolder(Output, Variable))
                    Entries, Actors, Commands = [], [], []
                    Guard = ResourceGuard(Entries)
                    Record = {'Configuration': Name, 'Peers': Count, 'World': World, 'Trial': Trial, 'Resources': Resource}
                    Started, Selected = time.monotonic(), Port()
                    try:
                        for Role, Index in [('server', 0), *[('client', Index) for Index in range(1, Count + 1)]]:
                            Label = Role + str(Index)
                            Command = [Host['Executable'], '--headless', '--disable-crash-handler', '--single-threaded-scene', '--path', str(Output), '--script', 'res://FoundationBenchmark.gd', '--max-fps', '120', '--', '--fixture-role', Role, '--fixture-client-index', str(Index), '--fixture-port', str(Selected), '--peers', str(Count), '--samples', str(Args.samples), '--world-count', str(World), '--relevance', 'true' if Name == 'Candidate' else 'false']
                            with (Output / (Label + '.stdout.log')).open('w') as Out, (Output / (Label + '.stderr.log')).open('w') as Err: Child = StartProcess(Command, Out, Err, Environment)
                            Entries.append((Child, Label)); Commands.append(Command)
                            if Role == 'server':
                                Deadline = time.monotonic() + 45
                                while not (Output / 'bench-server-ready').exists():
                                    if Child.poll() is not None or time.monotonic() >= Deadline: raise RuntimeError('World/server readiness failed')
                                    time.sleep(.02)
                        Deadline = time.monotonic() + 180
                        for Child, Label in Entries:
                            Check(Child, Deadline, Output, Label, '[Network:DeliveryBenchmark] PASS')
                            Actor = json.loads((Output / ('bench-' + Label + '.json')).read_text())
                            assert Actor['Peers'] == Count and Actor['SamplesPerPeer'] == Args.samples and not Actor['Graphical']
                            assert Actor['CallbackStarts'] == (16 + Args.samples) * (Count if Actor['Role'] == 'server' else 1)
                            Extra = Actor['Foundation']
                            assert Extra['WorldObjects'] == World and Extra['MaximumObservedCharacters'] > 0 and Extra['FinalCounter'] == 16 + Args.samples
                            if Actor['Role'] == 'client': assert Extra['FunctionCalls'] == Args.samples // 8
                            else: assert Extra['AnimationStarts'] == Count * Args.samples // 16 and Extra['Reparents'] == Count * Args.samples // 8
                            if Name == 'Baseline' and Actor['Role'] == 'client': assert Extra['MinimumObservedParts'] >= World, 'Baseline world did not completely materialize'
                            Actor['OwnedProcessCPU'] = CPU(Child); Actors.append(Actor)
                        assert not Guard.Aborted, 'Owned actor resource guard stopped the workload before commit exhaustion'
                        assert not list(Output.glob('asan-report*')), 'Unexpected ASan report'
                        Record['Result'] = 'PASS'
                    except Exception as Error:
                        Record.update(Result='FAIL', Error=str(Error), Traceback=traceback.format_exc())
                    finally:
                        Guard.Close()
                        StopAll()
                        Record.update(Seconds=time.monotonic() - Started, Actors=Actors, Commands=Commands,
                                      MinimumObservedCommitFree=Guard.MinimumCommit, ResourceGuardAborted=Guard.Aborted,
                                      Reports=[{'Path': str(File.relative_to(Output)), 'SHA256': Hash(File)} for File in Output.glob('asan-report*')],
                                      NonemptyStderr=[{'Path': str(File.relative_to(Output)), 'SHA256': Hash(File)} for File in Output.glob('*.stderr.log') if File.read_bytes().strip()])
                        Results.append(Record); Save()
                    print('[Network:FoundationBenchmark] ' + Name + ' ' + str(Count) + '/' + str(World) + ' ' + Record['Result'], flush=True)
                    if Record['Result'] != 'PASS':
                        (Args.output / 'summary.json').write_text(json.dumps({'Result': 'PARTIAL', 'Reason': 'Retained failed configuration; stopped dependent performance comparison', 'Results': Results}, indent=2))
                        return 1
    Complete = all(Record['Result'] == 'PASS' for Record in Results)
    (Args.output / 'summary.json').write_text(json.dumps({'Result': 'PASS' if Complete else 'PARTIAL', 'Repeated': Args.trials == 2, 'Results': Results}, indent=2))
    return 0 if Complete else 2


if __name__ == '__main__': raise SystemExit(Main())
