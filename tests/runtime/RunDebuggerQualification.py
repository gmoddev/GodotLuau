"""Drive the real Godot/Luau debugger over Godot's loopback Variant protocol."""
import argparse
import ctypes
import hashlib
import json
import os
from pathlib import Path
import shutil
import socket
import time
from FixtureProcesses import GetProfileFolder, StartProcess, StopAll, StopProcess
from RunQualification import Prepare, Check
from SourceFingerprint import GetFingerprint


def Main():
    Parser = argparse.ArgumentParser(description=__doc__)
    Parser.add_argument('--godot', type=Path, required=True)
    Parser.add_argument('--extension', type=Path, required=True)
    Parser.add_argument('--source', type=Path, required=True)
    Parser.add_argument('--output', type=Path, required=True)
    Args = Parser.parse_args()
    Repository = Path(__file__).resolve().parents[2]
    NativeSource = json.loads(Args.source.read_text(encoding='utf-8'))
    assert NativeSource == GetFingerprint(Repository), 'Adapter source fingerprint differs from the current native implementation'
    Output = Args.output.resolve()
    Output.mkdir(parents=True, exist_ok=False)
    if os.name == 'nt':
        ctypes.windll.kernel32.SetErrorMode(0x8003)
    Fixtures = ['DebuggerMain.luau', 'DebuggerModule.luau', 'DebuggerClient.luau', 'DebuggerPeer.gd', 'DebuggerTarget.gd']
    Locations = {}
    for Name in Fixtures[:3]:
        for Line, Text in enumerate(Path(__file__).with_name(Name).read_text(encoding='utf-8').splitlines(), 1):
            if 'GL055:' in Text:
                Locations[Text.split('GL055:', 1)[1].strip()] = {'Source': 'res://' + Name, 'Line': Line, 'Domain': 'Client' if Name == 'DebuggerClient.luau' else 'Server'}
    Expected = [Locations[Name] for Name in ['Entry', 'Into', 'Over', 'Out', 'Module', 'Client', 'Callback', 'Stale']]
    Breakpoints = ','.join(Item['Source'] + ':' + str(Item['Line']) for Name, Item in Locations.items() if Name in ['Entry', 'Module', 'Client', 'Callback', 'Stale'])
    Results = []
    for Disconnect in [False, True]:
        Case = Output / ('disconnect' if Disconnect else 'local')
        Target, Peer = Case / 'target', Case / 'peer'
        Prepare(Target, Args.extension.resolve())
        (Target / '.godot/extension_list.cfg').write_text('res://godot_luau.gdextension\n')
        Peer.mkdir(parents=True)
        (Peer / 'project.godot').write_text('config_version=5\n[application]\nconfig/name="LuauDebuggerTestPeer"\n[threading]\nworker_pool/max_threads=2\n')
        for Name in Fixtures[:3]:
            shutil.copy2(Path(__file__).with_name(Name), Target / Name)
        shutil.copy2(Path(__file__).with_name('DebuggerPeer.gd'), Peer / 'DebuggerPeer.gd')
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as Probe:
            Probe.bind(('127.0.0.1', 0))
            Port = Probe.getsockname()[1]
        (Peer / 'inputs.json').write_text(json.dumps({'Port': Port, 'Expected': Expected, 'Disconnect': Disconnect}))
        Environment = dict(os.environ, GODOT_SILENCE_ROOT_WARNING='1')
        for Name in ['APPDATA', 'LOCALAPPDATA', 'XDG_CONFIG_HOME', 'XDG_DATA_HOME', 'XDG_CACHE_HOME']:
            Environment[Name] = str(GetProfileFolder(Case, Name))
        Base = [str(Args.godot.resolve()), '--headless', '--disable-crash-handler', '--single-threaded-scene', '--max-fps', '60']
        PeerCommand = [*Base, '--path', str(Peer), '--script', 'res://DebuggerPeer.gd']
        with (Case / 'peer.stdout.log').open('w') as Stdout, (Case / 'peer.stderr.log').open('w') as Stderr:
            PeerProcess = StartProcess(PeerCommand, Stdout, Stderr, Environment)
        Deadline = time.monotonic() + 10
        while not (Peer / 'ready.json').is_file() and PeerProcess.poll() is None and time.monotonic() < Deadline:
            time.sleep(.05)
        assert (Peer / 'ready.json').is_file(), 'Native peer did not become ready; inspect peer.stderr.log'
        TargetCommand = [*Base, '--path', str(Target), '--debug', '--remote-debug', f'tcp://127.0.0.1:{Port}',
                         '--breakpoints', Breakpoints, '--script', 'res://DebuggerTarget.gd']
        with (Case / 'target.stdout.log').open('w') as Stdout, (Case / 'target.stderr.log').open('w') as Stderr:
            TargetProcess = StartProcess(TargetCommand, Stdout, Stderr, Environment)
        try:
            TargetResult = Check(TargetProcess, time.monotonic() + 50, Case, 'target', '[Debugger:Target] PASS')
            Pending = Peer / 'target-finished.json.pending'
            Pending.write_text(json.dumps({'Exit': TargetResult['Exit']}))
            Pending.replace(Peer / 'target-finished.json')
            PeerResult = Check(PeerProcess, time.monotonic() + 8, Case, 'peer', '[Debugger:Native] PASS protocol qualification')
        finally:
            StopProcess(TargetProcess)
            StopProcess(PeerProcess)
        Detail = json.loads((Peer / 'results.json').read_text(encoding='utf-8'))
        assert Detail['Passed'] and all(Item['Passed'] for Item in Detail['Checks']), Detail
        assert 'ERROR:' not in (Case / 'peer.stderr.log').read_text(errors='replace'), 'Native peer script or protocol error'
        assert 'ERROR:' not in (Case / 'target.stderr.log').read_text(errors='replace'), 'Debuggee script/native error'
        Detail.update(Target=TargetResult, Peer=PeerResult, TargetCommand=TargetCommand, PeerCommand=PeerCommand, Case=Case.name)
        Results.append(Detail)
    Evidence = {'Passed': True, 'NativeSource': NativeSource, 'ExtensionSHA256': hashlib.sha256(Args.extension.read_bytes()).hexdigest(),
                'Fixtures': {Name: hashlib.sha256(Path(__file__).with_name(Name).read_bytes().replace(b'\r\n', b'\n')).hexdigest() for Name in Fixtures},
                'Graphical': False, 'Cases': Results}
    (Output / 'results.json').write_text(json.dumps(Evidence, indent=2))
    print('[Debugger:Qualification] PASS real native protocol and disconnect', flush=True)


if __name__ == '__main__':
    try:
        Main()
    finally:
        StopAll()
