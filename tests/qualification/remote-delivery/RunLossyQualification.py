"""Supplemental real-UDP loss/reorder qualification; does not change the runtime."""
import argparse
import ctypes
import hashlib
import json
import os
from pathlib import Path
import shutil
import sys
import time
from LossyDatagrams import LossyDatagrams


def Main():
    Parser = argparse.ArgumentParser(description=__doc__)
    for Name in ['extension','identity','host-manifest','output']:
        Parser.add_argument('--'+Name, type=Path, required=True)
    Parser.add_argument('--runtime', type=Path, default=Path(__file__).resolve().parents[2]/'runtime')
    Args = Parser.parse_args()
    sys.path.insert(0,str(Args.runtime.resolve()))
    from FixtureProcesses import StartProcess, StopAll, GetProfileFolder
    from RunQualification import Prepare, Check, Port
    from RemoteHostIdentity import VerifyRemoteHost
    if os.name == 'nt': ctypes.windll.kernel32.SetErrorMode(0x8003)
    Args.output = Args.output.resolve(); Args.output.mkdir(parents=True,exist_ok=False)
    Host = VerifyRemoteHost(json.loads(Args.host_manifest.read_text()))
    Godot = Path(Host['Executable']); VerifyRemoteHost(Host, Godot)
    Identity = json.loads(Args.identity.read_text())
    Hash = lambda File: hashlib.sha256(Path(File).read_bytes()).hexdigest()
    if Identity['Products'].get(Args.extension.name) != Hash(Args.extension) or Identity['CompilerSHA256'] != Host['CompilerSHA256']:
        raise ValueError('Actual extension/compiler identity mismatch')
    Prepare(Args.output, Args.extension)
    shutil.copy2(Path(__file__).with_name('RemoteLossy.gd'), Args.output/'RemoteLossy.gd')
    Inputs = {'Identity': Identity, 'Host': Host, 'SourceHashes': {Name: Hash(Path(__file__).with_name(Name)) for Name in ['RunLossyQualification.py','LossyDatagrams.py','RemoteLossy.gd']}}
    (Args.output/'inputs.json').write_text(json.dumps(Inputs,indent=2))
    Environment = dict(os.environ,GODOT_SILENCE_ROOT_WARNING='1',GL_QUALIFICATION_PROFILE_ROOT=str(Args.output/'profiles'))
    Environment['ASAN_OPTIONS'] = 'halt_on_error=1:log_path="'+(Args.output/'asan-report').as_posix()+'"'
    for Variable in ['APPDATA','LOCALAPPDATA','XDG_CONFIG_HOME','XDG_DATA_HOME','XDG_CACHE_HOME']:
        Environment[Variable] = str(GetProfileFolder(Args.output,Variable))
    Entries=[]; Proxies=[]; Results=[]; Failure=None; Started=time.monotonic(); SelectedPort=Port()
    try:
        for Role, Index in [('server',0),('client',1),('client',2)]:
            Target=SelectedPort
            if Role=='client':
                Proxy=LossyDatagrams(SelectedPort);Proxies.append(Proxy);Target=Proxy.Port
            Label=Role+str(Index)
            Command=[str(Godot),'--headless','--disable-crash-handler','--single-threaded-scene','--path',str(Args.output),'--script','res://RemoteLossy.gd','--','--fixture-role',Role,'--fixture-client-index',str(Index),'--fixture-port',str(Target)]
            Command += ['--glserver',str(SelectedPort)] if Role=='server' else ['--glconnect','127.0.0.1:'+str(Target)]
            with (Args.output/(Label+'.stdout.log')).open('w') as Out,(Args.output/(Label+'.stderr.log')).open('w') as Err:
                Child=StartProcess(Command,Out,Err,Environment)
            Entries.append((Child,Label))
            if Role=='server':
                Deadline=time.monotonic()+20
                while not (Args.output/'wire-ready').exists():
                    if Child.poll() is not None or time.monotonic()>Deadline:raise RuntimeError('Wire fixture server startup failed')
                    time.sleep(.02)
        Deadline=time.monotonic()+90
        for Child,Label in Entries:
            Check(Child,Deadline,Args.output,Label,'[Network:WireFaults]')
            Record=json.loads((Args.output/('wire-'+Label+'.json')).read_text())
            if Record['Result']!='PASS' or not Record['Complete'] or not Record['Cases'] or any(not Case['Passed'] for Case in Record['Cases']):
                raise ValueError('Wire actor assertions missing or failed')
            Results.append(Record)
    except Exception as Error:
        Failure=str(Error)
    finally:
        StopAll()
        for Proxy in Proxies:
            try:Proxy.Close()
            except Exception as Error:Failure=str(Error)
        Faults=[dict(Proxy.Stats) for Proxy in Proxies]
        Unexpected=[str(File.relative_to(Args.output)) for File in Args.output.glob('asan-report*')]
        Passed=not Failure and not Unexpected and len(Results)==3 and len(Faults)==2
        for Stats in Faults:
            Passed=Passed and Stats['ReliableDropped']==1 and Stats['ReliableMatchingDatagrams']>=2 and Stats['UnorderedDropped']>=1 and Stats['Delayed']>=2 and Stats['Duplicated']>=1 and Stats['CapacityDrops']==0 and Stats['PeakPending']<=256 and Stats['PeakPendingBytes']<=1024*1024
        Summary={'Result':'PASS' if Passed else 'FAIL','Seconds':time.monotonic()-Started,'Error':Failure,'Actors':Results,'Datagrams':Faults,'UnexpectedReports':Unexpected,'Inputs':Inputs}
        (Args.output/'summary.json').write_text(json.dumps(Summary,indent=2))
    if not Passed:raise RuntimeError('Wire qualification failed; all evidence retained: '+str(Failure))
    print('[Network:WireFaults] PASS actual UDP loss, reorder, duplicate injection and native reliable retransmission',flush=True)


if __name__=='__main__':Main()
