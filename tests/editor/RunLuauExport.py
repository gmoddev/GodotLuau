"""Export the real Luau-only game through Godot and launch outside its project.

Uses the existing verified candidate, host and process infrastructure. This is
headless editor/export evidence, never interactive UI or rendered qualification.
"""
import argparse
import ctypes
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

Repository=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(Repository/'tools'))
from ReleaseCandidate import Execute
sys.path.insert(0,str(Repository/'tests/runtime'))
from FixtureProcesses import StopAll


def Hash(File):
    Digest=hashlib.sha256()
    with File.open('rb') as Stream:
        for Block in iter(lambda:Stream.read(1024*1024),b''): Digest.update(Block)
    return Digest.hexdigest()


def Main():
    Parser=argparse.ArgumentParser(description=__doc__)
    for Name in ('editor','output'):
        Parser.add_argument('--'+Name,type=Path,required=True)
    Inputs=Parser.add_mutually_exclusive_group(required=True)
    Inputs.add_argument('--candidate',type=Path)
    Inputs.add_argument('--adapter',type=Path,help='Qualification-only adapter, never a distribution product')
    Parser.add_argument('--adapter-source',type=Path)
    Parser.add_argument('--engine',type=Path)
    Parser.add_argument('--host-manifest',type=Path)
    Parser.add_argument('--templates',type=Path,help='Matching official templates staged by ProvisionGodot --templates')
    Parser.add_argument('--configuration',choices=['Debug','Release'],default='Release')
    Parser.add_argument('--profile',choices=['OrbRun','Native2D','Native3D','UI','Foundry'],default='OrbRun')
    Args=Parser.parse_args()
    if bool(Args.engine)!=bool(Args.host_manifest): Parser.error('Engine and admitted manifest must be supplied together')
    if bool(Args.templates)==bool(Args.engine): Parser.error('Supply either official solo templates or an admitted Windows host')
    if Args.engine and os.name!='nt': Parser.error('The inherited admitted-host export profile is Windows only')
    if Args.profile=='Foundry' and not Args.templates: Parser.error('Foundry requires full-featured official solo templates')
    if Args.adapter and not Args.adapter_source: Parser.error('Adapter staging requires retained source identity')
    Platform='Windows' if os.name=='nt' else 'Linux'
    Mode=Args.configuration.lower()
    TemplateRecord=None
    if Args.templates:
        Manifest=json.loads((Repository/'tests/runtime/GodotDistribution.json').read_text())
        Spec=Manifest['ExportTemplates']
        TemplateRecord=json.loads((Args.templates/'provenance.json').read_text())
        assert TemplateRecord['SourceRevision']==Manifest['SourceRevision'] and TemplateRecord['SHA256']==Spec['SHA256']
        Templates={}
        for Configuration in ('debug','release'):
            Name=('windows_'+Configuration+'_x86_64.exe') if os.name=='nt' else ('linux_'+Configuration+'.x86_64')
            File=(Args.templates/Name).resolve()
            assert Hash(File)==Spec[Platform][Name], 'Wrong official export template: '+Name
            Templates[Configuration]=File
    Output=Args.output.resolve();Output.mkdir(parents=True,exist_ok=False)
    Project=Output/'project';Standalone=Output/'standalone';Standalone.mkdir()
    Environment=dict(os.environ,GODOT_SILENCE_ROOT_WARNING='1')
    for Name in ('APPDATA','LOCALAPPDATA','XDG_CONFIG_HOME','XDG_DATA_HOME','XDG_CACHE_HOME'):
        Folder=Output/'profile'/Name;Folder.mkdir(parents=True);Environment[Name]=str(Folder)
    if os.name=='nt': ctypes.windll.kernel32.SetErrorMode(0x8003)
    Commands=[]
    Stage=[sys.executable,Repository/'examples/luau-only/PrepareProject.py','--profile',Args.profile,'--output',Project]
    Stage+=['--candidate',Args.candidate.resolve()] if Args.candidate else ['--adapter',Args.adapter.resolve(),'--adapter-source',Args.adapter_source.resolve()]
    if Args.engine: Stage+=['--engine',Args.engine.resolve(),'--host-manifest',Args.host_manifest.resolve()]
    Commands.append(Execute(Stage,Output/'stage.log',60,Environment))
    Preset=Platform+' Desktop' if os.name=='nt' else 'Linux'
    if Args.templates:
        # Explicit paths avoid installing templates or changing global editor settings.
        (Project/'export_presets.cfg').write_text('[preset.0]\nname="'+Preset+'"\nplatform="'+Preset+'"\nrunnable=true\nexport_filter="all_resources"\ninclude_filter="*.lua,*.luau"\nexclude_filter="authoring-project.json,README.md"\nscript_export_mode=1\n\n[preset.0.options]\ncustom_template/debug="'+Templates['debug'].as_posix()+'"\ncustom_template/release="'+Templates['release'].as_posix()+'"\nbinary_format/embed_pck=true\ntexture_format/s3tc_bptc=true\ntexture_format/etc2_astc=false\n')
    # Normal bounded editor open completes initialization. The stock editor's
    # fast --import exit is a separately retained failing baseline profile.
    Base=[Args.editor.resolve(),'--headless','--disable-crash-handler','--single-threaded-scene','--path',Project]
    Commands.append(Execute(Base+['--editor','--max-fps','60','--quit-after','120'],Output/'open.log',60,Environment))
    Executable=Standalone/(Args.profile+('.exe' if os.name=='nt' else '.x86_64'))
    Commands.append(Execute(Base+['--export-'+Mode,Preset,Executable],Output/'export.log',90,Environment))
    if os.name!='nt': Executable.chmod(0o755)
    Library=Project/('GodotLuau/bin/godot_luau.'+Platform.lower()+'.template_'+Mode+'.x86_64'+('.dll' if os.name=='nt' else '.so')) if Args.candidate else Project/'bin'/Args.adapter.name
    Worker=Library.with_name('godot_luau_store_worker'+('.exe' if os.name=='nt' else ''))
    for File in (Library,Worker):
        assert (Standalone/File.name).is_file() and Hash(Standalone/File.name)==Hash(File), 'Export omitted or changed native product: '+File.name
    for Name in ('startup','restart'):
        Commands.append(Execute([Executable,'--headless','--disable-crash-handler',
            '--max-fps','30','--quit-after','90'],Output/(Name+'.log'),20,Environment,Standalone))
    for Name in ('open','export','startup','restart'):
        Text=(Output/(Name+'.log')).read_text(errors='replace')
        assert 'ERROR:' not in Text and 'SCRIPT ERROR' not in Text and '[Runtime:Script]' not in Text, 'Native workflow error: '+Name
    Markers={'OrbRun':['[OrbRun:Lifecycle] Ready'],'Native2D':['[Foundation:2D] Ready'],'Native3D':['[Foundation:3D] Ready'],'UI':['[Foundation:UI] Ready'],'Foundry':['[Foundry:Server] Ready','[Foundry:Client] Ready','[Foundry:Progress] Ready']}[Args.profile]
    for Name in ('startup','restart'):
        assert all(Marker in (Output/(Name+'.log')).read_text(errors='replace') for Marker in Markers), 'Exported Luau entrypoint did not initialize: '+Name
    assert not list(Project.rglob('*.gd')), 'Application package contains developer GDScript'
    Record={'Passed':True,'Commands':Commands,'Candidate':json.loads((Args.candidate/'candidate.json').read_text()) if Args.candidate else None,
            'QualificationOnlyAdapter':bool(Args.adapter),'Templates':TemplateRecord,'Configuration':Args.configuration,
            'Project':json.loads((Project/'authoring-project.json').read_text()),
            'StandaloneFiles':{File.name:Hash(File) for File in Standalone.iterdir() if File.is_file()},
            'Interactive':False,'Graphical':False,'Scope':'Standalone entrypoint, native library/companion packaging and clean restart; not exported interactive gameplay'}
    (Output/'results.json').write_text(json.dumps(Record,indent=2)+'\n')
    print('[Authoring:Export] PASS',Output)


if __name__=='__main__':
    try:Main()
    finally:StopAll()
