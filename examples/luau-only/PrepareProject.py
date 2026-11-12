"""Stage the Luau-only workload from an explicit candidate or qualification adapter.

Creates a fresh directory only. It does not download, install, update, publish or
replace an existing project. Export templates remain explicit supplied inputs.
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
    Inputs = Parser.add_mutually_exclusive_group(required=True)
    Inputs.add_argument('--candidate', type=Path, help='Directory containing candidate.json and its verified platform ZIP')
    Inputs.add_argument('--adapter', type=Path, help='Explicit CMake test adapter: qualification only, never distribution')
    Parser.add_argument('--adapter-source', type=Path)
    Parser.add_argument('--engine', type=Path)
    Parser.add_argument('--host-manifest', type=Path)
    Parser.add_argument('--output', type=Path, required=True)
    Args = Parser.parse_args()
    Source = Path(__file__).resolve().parent
    Repository = Source.parents[1]
    Output = Args.output.resolve()
    if Output.exists(): Parser.error('Use a fresh staging directory; existing projects are preserved')
    if bool(Args.engine) != bool(Args.host_manifest): Parser.error('Engine and admitted manifest must be supplied together')
    if Args.engine:
        sys.path.insert(0,str(Repository/'tests/runtime'))
        from RemoteHostIdentity import VerifyRemoteHost
        VerifyRemoteHost(json.loads(Args.host_manifest.read_text()),Args.engine)
    Record = {'Schema':1,'Revision':subprocess.check_output(['git','-C',str(Repository),'rev-parse','HEAD'],text=True).strip()}
    if Args.candidate:
        sys.path.insert(0,str(Repository/'tools'))
        import ReleaseCandidate as Candidate
        Package = Candidate.Load(Args.candidate/'candidate.json')
        Candidate.CheckPackage(Args.candidate,Package['Source'],Package['Platform'])
        sys.path.insert(0,str(Repository/'tests/runtime'))
        from SourceFingerprint import GetFingerprint
        if Package['Source']['NativeSource'] != GetFingerprint(Repository): Parser.error('Candidate does not match current native sources')
        Record.update(Profile='Qualified candidate',CandidateSource=Package['Source'],CandidateSHA256=Package['Package']['SHA256'])
        Output.mkdir(parents=True)
        with zipfile.ZipFile(Args.candidate/Package['Package']['File']) as Archive:
            # The disabled updater is not an application dependency. Keep the
            # verified fork archive intact; omit that addon from this new game.
            Archive.extractall(Output,[Name for Name in Archive.namelist() if not Name.startswith('addons/GodotLuauUpdater/')])
        Record['OmittedAddon']='Disabled GodotLuauUpdater; not required by the application'
    else:
        if not Args.adapter_source: Parser.error('Adapter staging requires its retained source.json identity')
        Record.update(Profile='Native test adapter with test hooks; qualification only',
                      NativeSource=json.loads(Args.adapter_source.read_text()),AdapterSHA256=Hash(Args.adapter))
        Output.mkdir(parents=True)
        Native = Output/'bin';Native.mkdir()
        Target = Native/Args.adapter.name
        shutil.copy2(Args.adapter,Target)
        Platform = 'windows' if Target.suffix=='.dll' else 'linux'
        WorkerName='godot_luau_store_worker'+('.exe' if Platform=='windows' else '')
        shutil.copy2(Args.adapter.with_name(WorkerName),Native/WorkerName)
        # Map the supplied adapter for either host feature. Its build profile
        # comes from retained provenance, never from the host's feature name.
        (Output/'godot_luau.gdextension').write_text('[configuration]\nentry_symbol="luau_extension_init"\ncompatibility_minimum="4.3"\n\n[libraries]\n'+
            '\n'.join(Platform+'.'+Mode+'.x86_64="res://bin/'+Target.name+'"' for Mode in ('debug','release'))+
            '\n[dependencies]\n'+Platform+'.x86_64={"res://bin/'+WorkerName+'":""}\n')
        Types = Output/'GodotLuau/Types';Types.mkdir(parents=True)
        for File in (Repository/'GodotLuau/Types').iterdir():
            if File.is_file(): shutil.copy2(File,Types/File.name)
    for Name in ('project.godot','Main.tscn','Main.luau','World.luau','Marker.tscn','Pattern.tres','README.md'):
        shutil.copy2(Source/Name,Output/Name)
    if Args.engine:
        shutil.copy2(Args.engine,Output/'Runtime.exe')
        Record['EngineSHA256']=Hash(Args.engine)
        shutil.copy2(Args.host_manifest,Output/'remote-host.json')
        # Existing qualified custom host; neither dependencies nor engine patches change.
        Preset = '''[preset.0]
name="Windows Desktop"
platform="Windows Desktop"
runnable=true
advanced_options=false
export_filter="all_resources"
include_filter="*.lua,*.luau"
exclude_filter="authoring-project.json,Runtime.exe,remote-host.json"
export_path="Build/OrbRun.exe"
script_export_mode=1

[preset.0.options]
custom_template/debug="res://Runtime.exe"
custom_template/release="res://Runtime.exe"
binary_format/embed_pck=true
texture_format/bptc=false
texture_format/s3tc=true
texture_format/etc2=false
'''
        (Output/'export_presets.cfg').write_text(Preset)
    Record['Files'] = {File.relative_to(Output).as_posix():Hash(File) for File in Output.rglob('*') if File.is_file()}
    (Output/'authoring-project.json').write_text(json.dumps(Record,indent=2)+'\n')
    print('[Authoring:Project] Staged',Output,Record['Profile'])


if __name__=='__main__':
    Main()
