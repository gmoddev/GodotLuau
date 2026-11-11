"""Stage a runnable qualification game using an existing candidate and engine.

No download, installation, publication, dependency change or updater is involved.
The engine and native candidate remain explicit supplied inputs.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
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
    Parser.add_argument('--asset-editor',type=Path,help='Prepare assets with the existing editor helper instead of --assets')
    Args = Parser.parse_args()
    Source = Path(__file__).resolve().parent
    Repository = Source.parents[1]
    Revision = subprocess.check_output(['git','-C',str(Repository),'rev-parse','HEAD'],text=True).strip()
    if Args.archive and subprocess.check_output(['git','-C',str(Repository),'status','--porcelain','--','examples/e2e-game','examples/player-controller'],text=True).strip():
        Parser.error('Commit game sources before creating an identified archive')
    Output = Args.output.resolve()
    if Args.archive and Output.exists(): Parser.error('Archive packaging requires a fresh staging directory')
    if Output == Source or Source in Output.parents:
        Parser.error('Use a staging directory outside the source game project')
    if Args.assets and Args.asset_editor: Parser.error('Select one asset source')
    if Args.asset_editor:
        sys.path.insert(0,str(Repository/'tests/runtime'))
        from RunCharacterPresentation import Assets
        from FixtureProcesses import StopAll
        import os
        try: Args.assets = Assets(Args.asset_editor.resolve(),Repository,Output.with_name(Output.name+'-asset-inputs'),dict(os.environ),True)
        finally: StopAll()
    if Args.archive and (not Args.host_manifest or not Args.assets): Parser.error('A game archive requires the admitted host manifest and bundled assets')
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
    for Name in ['project.godot','Main.tscn','Game.gd','Arena.luau','Presentation.luau','RelayFactory.luau','Server.luau','Client.luau','README.md']:
        shutil.copy2(Source/Name,Output/Name)
    for Name in ['Scenes','Textures']:
        shutil.copytree(Source/Name,Output/Name,dirs_exist_ok=True)
    if Args.profile:
        if not Args.profile.replace('-','').replace('_','').isalnum(): Parser.error('Profile must be a simple leaf')
        File = Output/'project.godot'
        File.write_text(File.read_text().replace('GodotLuauRelaySiege',Args.profile))
    shutil.copy2(Source.parent/'player-controller/PlayerController.luau',Output/'PlayerController.luau')
    shutil.copy2(Args.engine,Output/'RelaySiege.exe')
    for Name in ['LICENSE.txt','COPYRIGHT.txt']:
        if (Args.engine.parent/Name).exists(): shutil.copy2(Args.engine.parent/Name,Output/('ENGINE-'+Name))
    shutil.copy2(Source/'QUALIFICATION.md',Output/'QUALIFICATION.md')
    shutil.copy2(Repository/'newdocs/native-scene-api.md',Output/'NATIVE-SCENE-API.md')
    Api = Output/'NATIVE-SCENE-API.md'
    RepoURL = 'https://github.com/gmoddev/GodotLuau/blob/'+Revision+'/'
    Docs = RepoURL+'newdocs/'
    Api.write_text(Api.read_text().replace('(native-authoring-development.md)', '('+Docs+'native-authoring-development.md)').replace('(adr-014-native-scene-authoring.md)', '('+Docs+'adr-014-native-scene-authoring.md)').replace('(native-authoring-qualification.md)', '('+Docs+'native-authoring-qualification.md)').replace('(gl-051-native-api.md)', '(NATIVE-BINDINGS-API.md)').replace('(../examples/e2e-game/', '('))
    BindingApi = (Repository/'newdocs/gl-051-native-api.md').read_text()
    for Name in ['adr-015-policy-driven-native-bindings.md','gl-051-development.md']:
        BindingApi = BindingApi.replace('('+Name+')','('+Docs+Name+')')
    BindingApi = BindingApi.replace('(native-scene-api.md)','(NATIVE-SCENE-API.md)').replace('(../bindings/','('+RepoURL+'bindings/').replace('(../GodotLuau/','(GodotLuau/').replace('(../examples/e2e-game/','(')
    (Output/'NATIVE-BINDINGS-API.md').write_text(BindingApi)
    Readme = Output/'README.md'
    Readme.write_text(Readme.read_text().replace('../../newdocs/e2e-game-development.md','QUALIFICATION.md').replace('../../newdocs/gl-044-045-relay-development.md','QUALIFICATION.md').replace('../../newdocs/native-scene-api.md','NATIVE-SCENE-API.md').replace('../../newdocs/gl-051-native-api.md','NATIVE-BINDINGS-API.md').replace('../../newdocs/native-authoring-development.md','QUALIFICATION.md'))
    if Args.host_manifest: shutil.copy2(Args.host_manifest,Output/'remote-host.json')
    (Output/'Play.cmd').write_text('@echo off\r\nsetlocal\r\ncd /d "%~dp0"\r\nset "APPDATA=%~dp0Data"\r\n"%~dp0RelaySiege.exe" --path "%~dp0" %*\r\n')
    (Output/'Server.cmd').write_text('@echo off\r\nsetlocal\r\ncd /d "%~dp0"\r\nset "APPDATA=%~dp0Data"\r\n"%~dp0RelaySiege.exe" --headless --path "%~dp0" -- --mode server --port 24870 --glserver 24870\r\n')
    Manifest = {'Schema':1,'GameRevision':Revision,
                'CandidateSource':Provenance['Source'],'CandidateSHA256':Hash(Args.candidate),'EngineSHA256':Hash(Args.engine),
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
