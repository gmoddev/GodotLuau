"""Bounded real-rendered or explicitly headless Character V2 gameplay fixtures."""
import argparse
import ctypes
import hashlib
import json
import os
from pathlib import Path
import shutil
import time
from FixtureProcesses import StartProcess, StopAll
from RunQualification import Prepare, Check, Port


def Assets(Godot, Source, Output, Environment):
    Import = Output / 'asset-import'
    Import.mkdir(parents=True)
    (Import / 'project.godot').write_text('config_version=5\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
    Relative = Path('GodotLuau/assets/avatars/r6')
    shutil.copytree(Source / Relative, Import / Relative)
    Shader = Path('GodotLuau/shaders/character_fade.gdshader')
    (Import / Shader.parent).mkdir(parents=True)
    shutil.copyfile(Source / Shader, Import / Shader)
    (Import / 'asset-inputs.json').write_text(json.dumps({File.relative_to(Source).as_posix(): hashlib.sha256(File.read_bytes()).hexdigest() for File in sorted((Source / Relative).rglob('*')) if File.is_file()} | {Shader.as_posix(): hashlib.sha256((Source / Shader).read_bytes()).hexdigest()}, indent=2))
    with (Import / 'stdout.log').open('w') as Out, (Import / 'stderr.log').open('w') as Err:
        Actor = StartProcess([str(Godot), '--headless', '--disable-crash-handler', '--editor', '--path', str(Import), '--import'], Out, Err, Environment)
        if Actor.wait(timeout=120) != 0: raise RuntimeError('Character fixture asset import failed')
    return Import


def Project(Output, Extension, Import):
    Prepare(Output, Extension)
    shutil.copytree(Import / 'GodotLuau', Output / 'GodotLuau')
    shutil.copytree(Import / '.godot/imported', Output / '.godot/imported')
    if (Import / '.godot/uid_cache.bin').exists(): shutil.copy2(Import / '.godot/uid_cache.bin', Output / '.godot/uid_cache.bin')
    with (Output / 'project.godot').open('a') as Config:
        Config.write('\n[display]\nwindow/size/viewport_width=960\nwindow/size/viewport_height=540\n')


def Launch(Args, Directory, Label, Extra, Environment):
    Command = [str(Args.godot), '--disable-crash-handler', '--single-threaded-scene', '--path', str(Directory), '--script', 'res://CharacterPresentation.gd', '--max-fps', '120']
    if Args.graphical:
        Command += ['--display-driver', 'windows', '--rendering-method', 'gl_compatibility', '--rendering-driver', 'opengl3', '--position', '-32000,-32000', '--resolution', '960x540']
    else: Command += ['--headless']
    with (Directory / (Label + '.stdout.log')).open('w') as Out, (Directory / (Label + '.stderr.log')).open('w') as Err:
        return StartProcess([*Command, '--', *Extra, *(['--graphical'] if Args.graphical else [])], Out, Err, Environment)


def Main():
    Parser = argparse.ArgumentParser(description=__doc__)
    for Name in ['godot', 'extension', 'output']: Parser.add_argument('--'+Name, type=Path, required=True)
    Parser.add_argument('--graphical', action='store_true')
    Parser.add_argument('--cases', nargs='+', choices=['r6', 'custom', 'listen', 'dedicated'], default=['r6', 'custom', 'listen', 'dedicated'])
    Args = Parser.parse_args()
    for Name in ['godot', 'extension', 'output']: setattr(Args, Name, getattr(Args, Name).resolve())
    if Args.output.exists(): raise ValueError('Use a fresh evidence output directory')
    if Args.graphical and os.name != 'nt': raise ValueError('This graphical launcher is qualified for Windows only')
    if os.name == 'nt': ctypes.windll.kernel32.SetErrorMode(0x8003)
    Args.output.mkdir(parents=True)
    Environment = dict(os.environ)
    Source = Path(__file__).resolve().parents[2]
    Results, Evidence = [], []
    try:
        Import = Assets(Args.godot, Source, Args.output, Environment)
        for Case in Args.cases:
            Directory = Args.output / Case
            Project(Directory, Args.extension, Import)
            SelectedPort = Port()
            Entries = []
            for Role, Index in ([('single', '0')] if Case in ['r6', 'custom'] else [('server', '0'), ('client', '1'), ('client', '2')]):
                Label = 'presentation-' + Case + '-' + Role + Index
                ActorEnvironment = dict(Environment)
                for Name in ['APPDATA', 'LOCALAPPDATA', 'XDG_CONFIG_HOME', 'XDG_DATA_HOME', 'XDG_CACHE_HOME']:
                    Profile = Directory / ('profile-' + Role + Index) / Name
                    Profile.mkdir(parents=True)
                    ActorEnvironment[Name] = str(Profile)
                Extra = ['--case', Case, '--role', Role, '--index', Index, '--port', str(SelectedPort)]
                if Case == 'dedicated' and Role == 'server': Extra += ['--glserver', str(SelectedPort)]
                Actor = Launch(Args, Directory, Label, Extra, ActorEnvironment)
                Entries.append((Actor, Label, Role+Index))
            Deadline = time.monotonic() + 90
            for Actor, Label, Role in Entries:
                Results.append(Check(Actor, Deadline, Directory, Label, '[Character:Presentation] PASS ' + Case))
                Item = json.loads((Directory / ('evidence-' + Role + '.json')).read_text())
                if Item['Graphical'] != Args.graphical or Item['Result'] != 'PASS' or Item['Checks'] < 5: raise ValueError('Missing actual fixture assertions')
                if Args.graphical:
                    if Item['Display'] == 'headless' or not Item['Adapter']: raise ValueError('Missing real renderer')
                    for Capture in Item['Captures']:
                        File = Directory / Capture['Screenshot']
                        if File.stat().st_size < 1000: raise ValueError('Empty graphical capture')
                        Capture['SHA256'] = hashlib.sha256(File.read_bytes()).hexdigest()
                Evidence.append(Item)
        (Args.output / 'results.json').write_text(json.dumps(Results, indent=2))
        Identity = {'ExtensionSHA256': hashlib.sha256(Args.extension.read_bytes()).hexdigest(), 'GodotSHA256': hashlib.sha256(Args.godot.read_bytes()).hexdigest(), 'FixtureSHA256': hashlib.sha256((Source/'tests/runtime/CharacterPresentation.gd').read_bytes().replace(b'\r\n', b'\n')).hexdigest()}
        (Args.output / 'native-evidence.json').write_text(json.dumps({'Graphical': Args.graphical, 'Actors': len(Results), 'Evidence': Evidence, 'AssetInputs': json.loads((Import/'asset-inputs.json').read_text()), **Identity}, indent=2))
        print('[Character:Presentation] PASS', len(Results), 'actors; graphical=' + str(Args.graphical))
    finally: StopAll()


if __name__ == '__main__': Main()
