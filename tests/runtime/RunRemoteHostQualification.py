"""Bounded actual ENet ownership/RPC qualification of the admitted host."""
import argparse
import ctypes
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import time
from FixtureProcesses import StartProcess, StopAll, GetProfileFolder
from RemoteHostIdentity import VerifyRemoteHost


def Main():
    Parser = argparse.ArgumentParser(description=__doc__)
    Parser.add_argument('--godot', type=Path, required=True)
    Parser.add_argument('--host-manifest', type=Path, required=True)
    Parser.add_argument('--output', type=Path, required=True)
    Args = Parser.parse_args()
    if os.name == 'nt': ctypes.windll.kernel32.SetErrorMode(0x8003)
    Args.output = Args.output.resolve(); Args.output.mkdir(parents=True, exist_ok=False)
    Host = VerifyRemoteHost(json.loads(Args.host_manifest.read_text()), Args.godot)
    Records = []
    try:
        for Name, Fixture, ResultFile, Required in [
            ('ownership', 'NativeAdmission.gd', 'native-admission.json', {
                'actual partial native ACK retires only some commands',
                'partial ACK retains the entire packet buffer charge',
                'complete native ACK retires exact retained ownership',
                'one-over peer admission rejects without ownership',
                'one-over host admission rejects without charging a new peer',
                'one-over native command-count rejection preserves ownership',
                'one-over host command-count rejection does not charge another peer',
                'host destruction invalidates retained peer observations safely'}),
            ('rpc', 'NativeRpcAdmission.gd', 'native-rpc-admission.json', {
                'normal RPC executes on the actual receiver',
                'confirmed-path RPC propagates native WouldBlock',
                'unconfirmed full-path RPC propagates native WouldBlock',
                'queued Remote RPC rejection retains old ownership and live retry session',
                'complete uncached UTF-8-path RPC packet fits negotiated MTU without native fragmentation',
                'complete cached RPC packet fits negotiated MTU without native fragmentation',
                'unbuffered reliable control failure terminates affected session explicitly'})]:
            Output = Args.output/Name; Output.mkdir()
            (Output/'.godot').mkdir()
            (Output/'.godot/global_script_class_cache.cfg').write_text('list=[]\n')
            shutil.copy2(Path(__file__).parent/Fixture, Output/Fixture)
            (Output/'project.godot').write_text('config_version=5\n[threading]\nworker_pool/max_threads=2\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
            Environment = dict(os.environ, GODOT_SILENCE_ROOT_WARNING='1')
            Environment['ASAN_OPTIONS'] = 'halt_on_error=1:log_path="'+(Output/'asan-report').as_posix()+'"'
            Environment['GL_QUALIFICATION_PROFILE_ROOT'] = str(Args.output/'profiles')
            for Variable in ['APPDATA','LOCALAPPDATA','XDG_CONFIG_HOME','XDG_DATA_HOME','XDG_CACHE_HOME']:
                Environment[Variable] = str(GetProfileFolder(Output, Variable))
            Command = [str(Args.godot.resolve()), '--headless', '--disable-crash-handler', '--single-threaded-scene', '--path', str(Output), '--script', 'res://'+Fixture]
            Record = {'Name': Name, 'Command': Command, 'FixtureSHA256': hashlib.sha256((Output/Fixture).read_bytes()).hexdigest()}
            Records.append(Record)
            Started = time.monotonic()
            try:
                with (Output/'stdout.log').open('w') as Out, (Output/'stderr.log').open('w') as Err:
                    Child = StartProcess(Command, Out, Err, Environment)
                    Record['Exit'] = Child.wait(timeout=120)
                Result = json.loads((Output/ResultFile).read_text())
                Record['Evidence'] = Result
                Labels = {Case['Label'] for Case in Result['Cases'] if Case['Passed']}
                Record['Passed'] = Record['Exit'] == 0 and Result['Complete'] and Result['Result'] == 'PASS' and all(Case['Passed'] for Case in Result['Cases']) and Required <= Labels
                for Log in [Output/'stdout.log', Output/'stderr.log']:
                    Text = Log.read_text(errors='replace')
                    if 'SCRIPT ERROR:' in Text or 'ERROR: AddressSanitizer' in Text or 'SUMMARY: AddressSanitizer' in Text or 'LeakSanitizer' in Text:
                        Record['Passed'] = False
            except Exception as Error:
                Record.update(Passed=False, Error=str(Error))
            finally:
                StopAll(); Record['Seconds'] = time.monotonic()-Started
                Record['Logs'] = {File.name: hashlib.sha256(File.read_bytes()).hexdigest() for File in Output.glob('*.log')}
            if not Record['Passed']: raise RuntimeError('GL-029 host fixture failed; retained '+Name)
    finally:
        StopAll()
        Unexpected = [str(File.relative_to(Args.output)) for File in Args.output.rglob('asan-report*') if File.is_file()]
        Result = 'PASS' if len(Records) == 2 and all(Record.get('Passed') for Record in Records) and not Unexpected else 'FAIL'
        (Args.output/'summary.json').write_text(json.dumps({'Result': Result, 'Host': Host, 'Records': Records, 'UnexpectedReports': Unexpected}, indent=2))
    if Result != 'PASS': raise RuntimeError('GL-029 host qualification failed')
    print('[Network:NativeAdmission] PASS ownership and actual RPC error propagation', flush=True)


if __name__ == '__main__': Main()
