"""Measure the same native ENet/remote-character workload using a selected product."""
import argparse, ctypes, hashlib, json, os, time
from pathlib import Path
from FixtureProcesses import StartProcess, StopAll
from RunQualification import Prepare, Check, Port

def Main():
    Parser = argparse.ArgumentParser(description=__doc__)
    for Name in ['godot', 'extension', 'output']: Parser.add_argument('--'+Name, type=Path, required=True)
    Parser.add_argument('--r6-assets', action='store_true')
    Parser.add_argument('--max-fps', type=int, default=120)
    Args = Parser.parse_args()
    assert not Args.output.exists()
    if os.name == 'nt': ctypes.windll.kernel32.SetErrorMode(0x8003)
    Prepare(Args.output, Args.extension)
    (Args.output/'inputs.json').write_text(json.dumps({'ExtensionSHA256':hashlib.sha256(Args.extension.read_bytes()).hexdigest(),'GodotSHA256':hashlib.sha256(Args.godot.read_bytes()).hexdigest(),'FixtureSHA256':hashlib.sha256(Path(__file__).with_name('CharacterNetworkBenchmarks.gd').read_bytes().replace(b'\r\n',b'\n')).hexdigest(),'MaxFPS':Args.max_fps,'R6Assets':Args.r6_assets},indent=2))
    Environment = dict(os.environ, GODOT_SILENCE_ROOT_WARNING='1')
    for Name in ['APPDATA','LOCALAPPDATA','XDG_CONFIG_HOME','XDG_DATA_HOME','XDG_CACHE_HOME']:
        Directory = Args.output/'profile'/Name
        Directory.mkdir(parents=True)
        Environment[Name] = str(Directory.resolve())
    (Args.output/'profile/.gdignore').write_text('')
    if Args.r6_assets:
        import shutil
        from RunCharacterPresentation import Assets
        Imported = Assets(Args.godot.resolve(),Path(__file__).resolve().parents[2],Args.output,Environment)
        shutil.copytree(Imported/'GodotLuau',Args.output/'GodotLuau')
        shutil.copytree(Imported/'.godot/imported',Args.output/'.godot/imported')
        if (Imported/'.godot/uid_cache.bin').exists(): shutil.copy2(Imported/'.godot/uid_cache.bin',Args.output/'.godot/uid_cache.bin')
    Selected = Port()
    Entries = []
    try:
        for Role, Index in [('server','0'),('client','1'),('client','2')]:
            Label = Role+Index
            Command=[str(Args.godot.resolve()),'--headless','--disable-crash-handler','--single-threaded-scene','--path',str(Args.output.resolve()),'--script','res://CharacterNetworkBenchmarks.gd','--max-fps',str(Args.max_fps),'--','--fixture-role',Role,'--fixture-port',str(Selected),'--fixture-client-index',Index]
            with (Args.output/(Label+'.stdout.log')).open('w') as Out, (Args.output/(Label+'.stderr.log')).open('w') as Err:
                Process=StartProcess(Command,Out,Err,Environment)
            Entries.append((Process,Label))
        Results = []
        Measurements = []
        for Process, Label in Entries:
            Results.append(Check(Process,time.monotonic()+60,Args.output,Label,'[Character:NetworkBenchmark] PASS'))
            Lines=(Args.output/(Label+'.stdout.log')).read_text(errors='replace').splitlines()
            Measurements.append(json.loads(next(Line.removeprefix('[Character:NetworkBenchmark] ') for Line in Lines if Line.startswith('[Character:NetworkBenchmark] {'))))
        (Args.output/'results.json').write_text(json.dumps(Results,indent=2))
        (Args.output/'measurements.json').write_text(json.dumps(Measurements,indent=2))
        print('[Character:NetworkBenchmark] PASS',Args.output,flush=True)
    finally: StopAll()

if __name__=='__main__': Main()
