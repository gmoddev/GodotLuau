import ctypes,hashlib,json,os,shutil,sys,time
from pathlib import Path
Windows=os.name=='nt'
Root=Path('C:/Sandbox/Codex/CharacterGraphics') if Windows else Path('/work')
Source=Path('C:/Sandbox/Codex/Workspaces/GodotLuau') if Windows else Root/'source'
sys.path.insert(0,str(Source/'tests/runtime'))
from FixtureProcesses import StartProcess,StopAll
from RunCharacterPresentation import Assets,Project
from RunQualification import Check
if Windows: ctypes.windll.kernel32.SetErrorMode(0x8003)
Engine=Path('C:/Sandbox/Codex/Tools/Godot_v4.7.1-stable_win64.exe') if Windows else Root/'godot/Godot_v4.7.1-stable_linux.x86_64'
Output=Root/'followup/memory-probe'
Output.mkdir(exist_ok=False)
Environment=dict(os.environ,GODOT_SILENCE_ROOT_WARNING='1')
for Name in ['APPDATA','LOCALAPPDATA','XDG_CONFIG_HOME','XDG_DATA_HOME','XDG_CACHE_HOME']:
    Directory=Output/'profile'/Name
    Directory.mkdir(parents=True)
    Environment[Name]=str(Directory.resolve())
Imported=Assets(Engine,Source,Output,Environment)
Fixture=Path('C:/Sandbox/Codex/CharacterGraphics/LifecycleMemoryProbe.gd') if Windows else Path('/transfer/LifecycleMemoryProbe.gd')
Results={}
try:
    for Variant in ['Baseline','Candidate']:
        Library=Root/('baseline/release/godot_luau.dll' if Variant=='Baseline' else 'candidate-v3/release/godot_luau.dll') if Windows else Root/('baseline-v2/godot_luau.so' if Variant=='Baseline' else 'candidate-v3/godot_luau.so')
        Directory=Output/Variant
        Project(Directory,Library,Imported)
        shutil.copy2(Fixture,Directory/Fixture.name)
        with (Directory/(Variant+'.stdout.log')).open('w') as Out,(Directory/(Variant+'.stderr.log')).open('w') as Err:
            Actor=StartProcess([str(Engine),'--headless','--disable-crash-handler','--single-threaded-scene','--path',str(Directory),'--script','res://'+Fixture.name,'--max-fps','120'],Out,Err,Environment)
        Check(Actor,time.monotonic()+120,Directory,Variant,'[Character:MemoryProbe] PASS')
        Text=(Directory/(Variant+'.stdout.log')).read_text()
        Results[Variant]={'LibrarySHA256':hashlib.sha256(Library.read_bytes()).hexdigest(),'Snapshots':[json.loads(Line.removeprefix('[Character:MemoryProbe] ')) for Line in Text.splitlines() if Line.startswith('[Character:MemoryProbe] {')]}
finally: StopAll()
(Output/'memory-evidence.json').write_text(json.dumps(Results,indent=2))
print(json.dumps(Results),flush=True)
