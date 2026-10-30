"""Compare production character factories without changing source assets."""
import argparse
import ctypes
import json
import os
from pathlib import Path
import shutil
import time
from FixtureProcesses import StartProcess, StopAll
from RunQualification import Prepare, Start, Check


def Main():
    Parser = argparse.ArgumentParser(description=__doc__)
    Parser.add_argument('--godot', type=Path, required=True)
    Parser.add_argument('--extension', type=Path, required=True)
    Parser.add_argument('--output', type=Path, required=True)
    Parser.add_argument('--r6-assets', type=Path)
    Parser.add_argument('--script', choices=['CharacterBenchmarks.gd', 'CharacterV2.gd'], default='CharacterBenchmarks.gd')
    Args = Parser.parse_args()
    if os.name == 'nt':
        ctypes.windll.kernel32.SetErrorMode(0x8003)
    assert not Args.output.exists()
    Prepare(Args.output, Args.extension)
    Environment = dict(os.environ, GODOT_SILENCE_ROOT_WARNING='1')
    for Name in ['APPDATA', 'LOCALAPPDATA', 'XDG_CONFIG_HOME', 'XDG_DATA_HOME', 'XDG_CACHE_HOME']:
        Directory = Args.output / 'profile' / Name
        Directory.mkdir(parents=True)
        Environment[Name] = str(Directory.resolve())
    (Args.output / 'profile/.gdignore').write_text('')
    try:
        if Args.r6_assets:
            # Import unchanged source assets in an asset-only editor project.
            # Runtime factory timing must not include native-editor startup.
            Import = Args.output / 'asset-import'
            Import.mkdir()
            (Import / 'project.godot').write_text('config_version=5\n[application]\nconfig/name="CharacterAssetImport"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
            AssetPath = Path('GodotLuau/assets/avatars/r6')
            shutil.copytree(Args.r6_assets, Import / AssetPath)
            with (Args.output / 'import.stdout.log').open('w') as Stdout, (Args.output / 'import.stderr.log').open('w') as Stderr:
                Process = StartProcess([str(Args.godot.resolve()), '--headless', '--disable-crash-handler', '--editor', '--path', str(Import.resolve()), '--import'], Stdout, Stderr, Environment)
                if Process.wait(timeout=120) != 0:
                    raise RuntimeError('R6 fixture import failed; inspect captured logs')
            shutil.copytree(Import / AssetPath, Args.output / AssetPath)
            shutil.copytree(Import / '.godot/imported', Args.output / '.godot/imported')
            Uids = Import / '.godot/uid_cache.bin'
            if Uids.is_file(): shutil.copyfile(Uids, Args.output / '.godot/uid_cache.bin')
        Process = Start(Args.godot.resolve(), Args.output.resolve(), Args.script, 'benchmark', [], Environment)
        Prefix = '[Character:V2]' if Args.script == 'CharacterV2.gd' else '[Character:Benchmark]'
        Result = Check(Process, time.monotonic() + 60, Args.output, 'benchmark', Prefix + ' PASS')
        Errors = (Args.output / 'benchmark.stderr.log').read_text(errors='replace')
        if Args.script == 'CharacterV2.gd' and 'ERROR:' in Errors:
            raise RuntimeError('Native Character V2 fixture emitted engine errors: ' + Errors[-4000:])
        Text = (Args.output / 'benchmark.stdout.log').read_text(errors='replace')
        Line = next(Line for Line in Text.splitlines() if Line.startswith(Prefix + ' {'))
        Summary = json.loads(Line.removeprefix(Prefix + ' '))
        if Args.r6_assets and Summary['Rig'] != 'R6':
            raise RuntimeError('Requested actual R6 workload fell back to a capsule')
        (Args.output / 'measurements.json').write_text(json.dumps(Summary, indent=2))
        (Args.output / 'results.json').write_text(json.dumps([Result], indent=2))
        print('[Character:Benchmark] PASS', Args.output, Summary)
    finally:
        StopAll()


if __name__ == '__main__':
    Main()
