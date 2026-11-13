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
    Parser.add_argument('--development-host', action='store_true', help='Explicitly opt a debug template host into the existing debugger connection')
    Args = Parser.parse_args()
    Repository = Path(__file__).resolve().parents[2]
    NativeSource = json.loads(Args.source.read_text(encoding='utf-8'))
    assert NativeSource == GetFingerprint(Repository), 'Adapter source fingerprint differs from the current native implementation'
    Output = Args.output.resolve()
    Output.mkdir(parents=True, exist_ok=False)
    if os.name == 'nt':
        ctypes.windll.kernel32.SetErrorMode(0x8003)
    Fixtures = ['DebuggerMain.luau', 'DebuggerModule.luau', 'DebuggerClient.luau', 'DebuggerPeer.gd', 'DebuggerTarget.gd',
                'DebuggerReload.luau', 'DebuggerReloadPeer.gd', 'DebuggerReloadTarget.gd',
                'DebuggerNetwork.luau', 'DebuggerNetworkPeer.gd', 'DebuggerNetworkTarget.gd', 'DebuggerNetworkClient.gd']
    Locations = {}
    for Name in Fixtures[:3]:
        for Line, Text in enumerate(Path(__file__).with_name(Name).read_text(encoding='utf-8').splitlines(), 1):
            if 'GL055:' in Text:
                Locations[Text.split('GL055:', 1)[1].strip()] = {'Source': 'res://' + Name, 'Line': Line, 'Domain': 'Client' if Name == 'DebuggerClient.luau' else 'Server'}
    Expected = [Locations[Name] for Name in ['Entry', 'Into', 'Over', 'Out', 'Module', 'Client', 'Callback', 'Stale']]
    Breakpoints = ','.join(Item['Source'] + ':' + str(Item['Line']) for Name, Item in Locations.items() if Name in ['Entry', 'Module', 'Client', 'Callback', 'Stale'])
    Results = []
    Modes = ['local', 'disconnect', 'running-disconnect', 'reload', 'network'] + (['no-opt-in'] if Args.development_host else [])
    for Mode in Modes:
        Case = Output / Mode
        Target, Peer = Case / 'target', Case / 'peer'
        Prepare(Target, Args.extension.resolve())
        (Target / '.godot/extension_list.cfg').write_text('res://godot_luau.gdextension\n')
        Peer.mkdir(parents=True)
        (Peer / '.godot').mkdir()
        (Peer / '.godot/global_script_class_cache.cfg').write_text('list=[]\n')
        (Peer / 'project.godot').write_text('config_version=5\n[application]\nconfig/name="LuauDebuggerTestPeer"\n[threading]\nworker_pool/max_threads=2\n')
        for Name in [*Fixtures[:3], 'DebuggerReload.luau', 'DebuggerNetwork.luau']:
            shutil.copy2(Path(__file__).with_name(Name), Target / Name)
        shutil.copy2(Path(__file__).with_name('DebuggerPeer.gd'), Peer / 'DebuggerPeer.gd')
        shutil.copy2(Path(__file__).with_name('DebuggerReloadPeer.gd'), Peer / 'DebuggerReloadPeer.gd')
        shutil.copy2(Path(__file__).with_name('DebuggerNetworkPeer.gd'), Peer / 'DebuggerNetworkPeer.gd')
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as Probe:
            Probe.bind(('127.0.0.1', 0))
            Port = Probe.getsockname()[1]
        Stops, Admitted = Expected, Breakpoints
        if Mode == 'no-opt-in': Stops = []
        if Mode == 'reload':
            Line = next(Index for Index, Text in enumerate(Path(__file__).with_name('DebuggerReload.luau').read_text().splitlines(), 1) if 'GL055:ReloadOld' in Text)
            Stops = [{'Source': 'res://DebuggerReload.luau', 'Line': Item, 'Domain': 'Server'} for Item in [Line, 2]]
            Admitted = 'res://DebuggerReload.luau:' + str(Line)
        Inputs = {'Port': Port, 'Expected': Stops, 'Disconnect': Mode == 'disconnect', 'DisconnectRunning': Mode == 'running-disconnect', 'TargetSource': str(Target / 'DebuggerReload.luau')}
        if Mode == 'network':
            Shared = Case / 'coordination'
            Shared.mkdir()
            with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as Probe:
                Probe.bind(('127.0.0.1', 0))
                NetworkPort = Probe.getsockname()[1]
            Line = next(Index for Index, Text in enumerate(Path(__file__).with_name('DebuggerNetwork.luau').read_text().splitlines(), 1) if 'GL055:Network' in Text)
            Inputs.update(Expected=[{'Source': 'res://DebuggerNetwork.luau', 'Line': Line, 'Domain': 'Server'}], Coordination=str(Shared), NetworkPort=NetworkPort)
            Admitted = 'res://DebuggerNetwork.luau:' + str(Line)
            (Target / 'inputs.json').write_text(json.dumps(Inputs))
            Client = Case / 'client'
            Client.mkdir()
            shutil.copy2(Peer / 'project.godot', Client / 'project.godot')
            shutil.copy2(Path(__file__).with_name('DebuggerNetworkClient.gd'), Client / 'DebuggerNetworkClient.gd')
            (Client / '.godot').mkdir()
            (Client / '.godot/global_script_class_cache.cfg').write_text('list=[]\n')
            (Client / 'inputs.json').write_text(json.dumps(Inputs))
        (Peer / 'inputs.json').write_text(json.dumps(Inputs))
        Environment = dict(os.environ, GODOT_SILENCE_ROOT_WARNING='1')
        for Name in ['APPDATA', 'LOCALAPPDATA', 'XDG_CONFIG_HOME', 'XDG_DATA_HOME', 'XDG_CACHE_HOME']:
            Environment[Name] = str(GetProfileFolder(Case, Name))
        Base = [str(Args.godot.resolve()), '--headless', '--disable-crash-handler', '--single-threaded-scene', '--max-fps', '60']
        PeerScript = {'reload': 'DebuggerReloadPeer.gd', 'network': 'DebuggerNetworkPeer.gd'}.get(Mode, 'DebuggerPeer.gd')
        PeerCommand = [*Base, '--path', str(Peer), '--script', 'res://' + PeerScript]
        with (Case / 'peer.stdout.log').open('w') as Stdout, (Case / 'peer.stderr.log').open('w') as Stderr:
            PeerProcess = StartProcess(PeerCommand, Stdout, Stderr, Environment)
        Deadline = time.monotonic() + 10
        while not (Peer / 'ready.json').is_file() and PeerProcess.poll() is None and time.monotonic() < Deadline:
            time.sleep(.05)
        assert (Peer / 'ready.json').is_file(), 'Native peer did not become ready; inspect peer.stderr.log'
        ClientProcess = None
        if Mode == 'network':
            ClientCommand = [*Base, '--path', str(Client), '--script', 'res://DebuggerNetworkClient.gd']
            with (Case / 'client.stdout.log').open('w') as Stdout, (Case / 'client.stderr.log').open('w') as Stderr:
                ClientProcess = StartProcess(ClientCommand, Stdout, Stderr, Environment)
        TargetScript = {'reload': 'DebuggerReloadTarget.gd', 'network': 'DebuggerNetworkTarget.gd'}.get(Mode, 'DebuggerTarget.gd')
        TargetCommand = [*Base, '--path', str(Target), '--debug', '--remote-debug', f'tcp://127.0.0.1:{Port}',
                         '--breakpoints', Admitted, '--script', 'res://' + TargetScript]
        if Args.development_host and Mode != 'no-opt-in': TargetCommand += ['--', '--gl-luau-debugger']
        with (Case / 'target.stdout.log').open('w') as Stdout, (Case / 'target.stderr.log').open('w') as Stderr:
            TargetProcess = StartProcess(TargetCommand, Stdout, Stderr, Environment)
        try:
            TargetResult = Check(TargetProcess, time.monotonic() + 50, Case, 'target', '[Debugger:Target] PASS')
            Pending = Peer / 'target-finished.json.pending'
            Pending.write_text(json.dumps({'Exit': TargetResult['Exit']}))
            Pending.replace(Peer / 'target-finished.json')
            PeerResult = Check(PeerProcess, time.monotonic() + 8, Case, 'peer', '[Debugger:Native] PASS protocol qualification')
            if ClientProcess:
                ClientResult = Check(ClientProcess, time.monotonic() + 8, Case, 'client', '[Debugger:Network] PASS')
                assert 'ERROR:' not in (Case / 'client.stderr.log').read_text(errors='replace'), 'Network client error'
        finally:
            StopProcess(TargetProcess)
            StopProcess(PeerProcess)
            if ClientProcess:
                StopProcess(ClientProcess)
        Detail = json.loads((Peer / 'results.json').read_text(encoding='utf-8'))
        assert Detail['Passed'] and all(Item['Passed'] for Item in Detail['Checks']), Detail
        assert 'ERROR:' not in (Case / 'peer.stderr.log').read_text(errors='replace'), 'Native peer script or protocol error'
        assert 'ERROR:' not in (Case / 'target.stderr.log').read_text(errors='replace'), 'Debuggee script/native error'
        Detail.update(Target=TargetResult, Peer=PeerResult, TargetCommand=TargetCommand, PeerCommand=PeerCommand, Case=Case.name)
        if ClientProcess:
            Detail.update(Client=ClientResult, ClientCommand=ClientCommand)
        Results.append(Detail)
    Evidence = {'Passed': True, 'NativeSource': NativeSource, 'ExtensionSHA256': hashlib.sha256(Args.extension.read_bytes()).hexdigest(),
                'Fixtures': {Name: hashlib.sha256(Path(__file__).with_name(Name).read_bytes().replace(b'\r\n', b'\n')).hexdigest() for Name in Fixtures},
                'Graphical': False, 'DevelopmentHostOptIn': Args.development_host, 'Cases': Results}
    (Output / 'results.json').write_text(json.dumps(Evidence, indent=2))
    print('[Debugger:Qualification] PASS real native protocol and disconnect', flush=True)


if __name__ == '__main__':
    try:
        Main()
    finally:
        StopAll()
