"""Stage a runnable qualification game using an existing candidate and engine.

No download, installation, publication, dependency change or updater is involved.
The engine and native candidate remain explicit supplied inputs.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import sys
import zipfile


def Hash(File):
    return hashlib.sha256(File.read_bytes()).hexdigest()


def Main():
    Parser = argparse.ArgumentParser(description=__doc__)
    Parser.add_argument('--candidate', required=True, type=Path)
    Parser.add_argument('--engine', required=True, type=Path)
    Parser.add_argument('--host-manifest', type=Path)
    Parser.add_argument('--output', required=True, type=Path)
    Parser.add_argument('--archive', type=Path)
    Parser.add_argument('--profile', help='Disposable user-data leaf for qualification; omit for normal play')
    Parser.add_argument('--assets',type=Path,help='Existing BundleCharacterAssets/runtime-remaps output')
    Args = Parser.parse_args()
    Source = Path(__file__).resolve().parent
    Repository = Source.parents[1]
    Output = Args.output.resolve()
    if Args.archive and Output.exists(): Parser.error('Archive packaging requires a fresh staging directory')
    if Output == Source or Source in Output.parents:
        Parser.error('Use a staging directory outside the source game project')
    if Args.host_manifest:
        sys.path.insert(0, str(Repository/'tests/runtime'))
        from RemoteHostIdentity import VerifyRemoteHost
        VerifyRemoteHost(json.loads(Args.host_manifest.read_text()), Args.engine)
    Output.mkdir(parents=True, exist_ok=True)
    (Output/'.godot').mkdir(exist_ok=True)
    (Output/'.godot/global_script_class_cache.cfg').write_text('list=[]\n')
    with zipfile.ZipFile(Args.candidate) as Archive:
        Provenance = json.loads(Archive.read('GodotLuau/release-provenance.json'))
        for Name in Archive.namelist():
            Relative = Path(Name)
            if Relative.is_absolute() or '..' in Relative.parts:
                raise ValueError('Unexpected candidate member')
            if Name.startswith('GodotLuau/') or Name in ['godot_luau.gdextension','godot_luau.gdextension.uid','LICENSE']:
                Archive.extract(Name, Output)
    if Args.assets:
        Remaps = json.loads((Args.assets/'runtime-remaps.json').read_text())
        for Name, Record in Remaps.items():
            if not Name.endswith('.obj.remap'): continue
            Product = Args.assets/Record['Path'].removeprefix('res://')
            if Hash(Product) != Record['SHA256']: raise ValueError('Imported Character asset mismatch')
            Target = Path('GameAssets')/Product.name
            (Output/Target.parent).mkdir(parents=True,exist_ok=True)
            shutil.copy2(Product,Output/Target)
            (Output/Name).write_text('[remap]\npath="res://'+Target.as_posix()+'"\n')
    for Name in ['project.godot','Main.tscn','Game.gd','Server.luau','Client.luau','README.md']:
        shutil.copy2(Source/Name,Output/Name)
    if Args.profile:
        if not Args.profile.replace('-','').replace('_','').isalnum(): Parser.error('Profile must be a simple leaf')
        File = Output/'project.godot'
        File.write_text(File.read_text().replace('GodotLuauRelaySiege',Args.profile))
    shutil.copy2(Source.parent/'player-controller/PlayerController.luau',Output/'PlayerController.luau')
    shutil.copy2(Args.engine,Output/'RelaySiege.exe')
    for Name in ['LICENSE.txt','COPYRIGHT.txt']:
        if (Args.engine.parent/Name).exists(): shutil.copy2(Args.engine.parent/Name,Output/('ENGINE-'+Name))
    shutil.copy2(Repository/'newdocs/e2e-game-development.md',Output/'QUALIFICATION.md')
    Readme = Output/'README.md'
    Readme.write_text(Readme.read_text().replace('../../newdocs/e2e-game-development.md','QUALIFICATION.md'))
    if Args.host_manifest: shutil.copy2(Args.host_manifest,Output/'remote-host.json')
    (Output/'Play.cmd').write_text('@echo off\r\nsetlocal\r\ncd /d "%~dp0"\r\nset "APPDATA=%~dp0Data"\r\n"%~dp0RelaySiege.exe" --path "%~dp0" %*\r\n')
    (Output/'Server.cmd').write_text('@echo off\r\nsetlocal\r\ncd /d "%~dp0"\r\nset "APPDATA=%~dp0Data"\r\n"%~dp0RelaySiege.exe" --headless --path "%~dp0" -- --mode server --port 24870 --glserver 24870\r\n')
    Manifest = {'Schema':1,'CandidateSource':Provenance['Source'],'CandidateSHA256':Hash(Args.candidate),'EngineSHA256':Hash(Args.engine),
                'NetworkHostVerified':Args.host_manifest is not None,'Files':{}}
    for File in sorted(Output.rglob('*')):
        if File.is_file() and ('.godot' not in File.parts or File.name=='global_script_class_cache.cfg') and File.name != 'game-package.json':
            Manifest['Files'][str(File.relative_to(Output)).replace('\\','/')] = {'SHA256':Hash(File),'Bytes':File.stat().st_size}
    (Output/'game-package.json').write_text(json.dumps(Manifest,indent=2))
    if Args.archive:
        Args.archive.parent.mkdir(parents=True,exist_ok=True)
        # Fixed entry metadata and sorted paths make identical supplied inputs reproducible.
        with zipfile.ZipFile(Args.archive,'w',zipfile.ZIP_DEFLATED) as Archive:
            for Name in sorted([*Manifest['Files'],'game-package.json']):
                Entry = zipfile.ZipInfo('RelaySiege/'+Name,date_time=(2026,11,9,0,0,0))
                Entry.compress_type = zipfile.ZIP_DEFLATED
                Archive.writestr(Entry,(Output/Name).read_bytes())
    print('[Game:Package] Staged',Output,'network host verified=',Manifest['NetworkHostVerified'])


if __name__ == '__main__': Main()
