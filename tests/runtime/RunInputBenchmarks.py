"""Interleaved baseline/candidate real-viewport input CPU measurements."""
import argparse
import ctypes
import hashlib
import json
import os
import platform
from pathlib import Path
import statistics
import time
from FixtureProcesses import GetProfileFolder, StopAll
from RunQualification import Prepare, Start, Check

def Distribution(Values):
    Ordered=sorted(Values)
    return {'Mean':statistics.mean(Ordered),'Median':statistics.median(Ordered),
            'P95':Ordered[min(len(Ordered)-1,int((len(Ordered)-1)*.95))],
            'P99':Ordered[min(len(Ordered)-1,int((len(Ordered)-1)*.99))]}

def Main():
    Parser=argparse.ArgumentParser(description=__doc__)
    for Name in ['godot','baseline','candidate','output']: Parser.add_argument('--'+Name,type=Path,required=True)
    Parser.add_argument('--trials',type=int,default=5)
    Parser.add_argument('--compare-candidates',action='store_true',help='Both libraries implement the semantic API; compare a bounded optimization')
    Args=Parser.parse_args()
    if not 3<=Args.trials<=9: Parser.error('trials must be within [3,9]')
    Args.output.mkdir(parents=True,exist_ok=False)
    if os.name=='nt': ctypes.windll.kernel32.SetErrorMode(0x8003)
    Records=[]
    for Trial in range(Args.trials):
        for Kind in (['Baseline','Candidate'] if Trial%2==0 else ['Candidate','Baseline']):
            Output=Args.output/(Kind+'-'+str(Trial))
            Library=Args.baseline if Kind=='Baseline' else Args.candidate
            Prepare(Output,Library.resolve())
            Environment=dict(os.environ,GODOT_SILENCE_ROOT_WARNING='1')
            for Name in ['APPDATA','LOCALAPPDATA','XDG_CONFIG_HOME','XDG_DATA_HOME','XDG_CACHE_HOME']: Environment[Name]=str(GetProfileFolder(Output,Name))
            Child=Start(Args.godot.resolve(),Output,'InputBenchmarks.gd','input-performance',['--baseline'] if Kind=='Baseline' and not Args.compare_candidates else [],Environment)
            Check(Child,time.monotonic()+120,Output,'input-performance','[Input:Performance] PASS')
            Record=json.loads((Output/'input-performance.json').read_text())
            Records.append({'Kind':Kind,'Trial':Trial,**Record})
    Summary=[]
    for Kind in ['Baseline','Candidate']:
        First=next(Record for Record in Records if Record['Kind']==Kind)
        for Case in First['Records']:
            Matches=[Item for Record in Records if Record['Kind']==Kind for Item in Record['Records'] if (Item['Mode'],Item['Count'])==(Case['Mode'],Case['Count'])]
            Summary.append({'Kind':Kind,'Mode':Case['Mode'],'Count':Case['Count'],
                'BurstMicroseconds':Distribution([Value for Item in Matches for Value in Item['CPUMicroseconds']]),
                'TrialMedianMicroseconds':[statistics.median(Item['CPUMicroseconds']) for Item in Matches],
                'FrameProcessMilliseconds':Distribution([Value for Item in Matches for Value in Item['FrameProcessMilliseconds']])})
    Result={'Trials':Args.trials,'Order':[(Record['Kind'],Record['Trial']) for Record in Records],
        'CompareCandidates':Args.compare_candidates,
        'Worker':platform.node(),'Platform':platform.platform(),'Processor':os.environ.get('PROCESSOR_IDENTIFIER',platform.processor()),
        'Units':'CPU microseconds per 32-event burst; frame waiting excluded',
        'Inputs':{Name:{'Path':str(File.resolve()),'SHA256':hashlib.sha256(File.read_bytes()).hexdigest()} for Name,File in [('Godot',Args.godot),('Baseline',Args.baseline),('Candidate',Args.candidate)]},
        'Limitations':['Raw0 includes event routing/harness overhead; no claim of isolated evaluator timings','Main has no semantic predecessor API; compare-candidates explicitly requires two implementations of that API','Performance.TIME_PROCESS is a periodically refreshed monitor and may be stale; its diagnostic samples are not per-frame CPU percentiles','Synthetic headless viewport workload; no physical-device or rendered-frame speed guarantee'],
        'Summary':Summary,'Records':Records}
    (Args.output/'input-performance.json').write_text(json.dumps(Result,indent=2))
    print(json.dumps({'Trials':Args.trials,'Summary':Summary},indent=2))

if __name__=='__main__':
    try: Main()
    finally: StopAll()
