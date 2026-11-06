import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import time

Root = Path('/work')
Source = Root/'source'
Logs = Root/'logs'
Logs.mkdir(exist_ok=True)
Environment = dict(os.environ,GODOT_SILENCE_ROOT_WARNING='1')

def Run(Command, Name, Timeout=1800):
    print('[Character:Worker] '+Name,flush=True)
    Prior = Logs/(Name+'.log')
    if Prior.exists(): Prior.rename(Logs/(Name+'-prior-'+str(time.time_ns())+'.log'))
    with (Logs/(Name+'.log')).open('w') as Log:
        Result = subprocess.run([str(Item) for Item in Command],stdout=Log,stderr=subprocess.STDOUT,env=Environment,timeout=Timeout)
    if Result.returncode: print((Logs/(Name+'.log')).read_text(errors='replace')[-6000:],flush=True)
    assert Result.returncode == 0,Name

def Extract(File, Destination):
    Destination.mkdir()
    with tarfile.open(File) as Tar:
        for Item in Tar:
            Relative = Path(Item.name)
            assert not Relative.is_absolute() and '..' not in Relative.parts and not Item.issym() and not Item.islnk()
            Tar.extract(Item,Destination)

Action = sys.argv[1]
if Action=='performance' and len(sys.argv)>2 and sys.argv[2]=='candidate-v2' and Path('/transfer/stop-v2-measure').exists(): raise RuntimeError('Preserve completed Windows comparison before fade endpoint qualification')
Variant=sys.argv[2] if len(sys.argv)>2 else 'candidate'
Engine = Root/'godot/Godot_v4.7.1-stable_linux.x86_64'
Build = Root/'build-release'
if Action == 'baseline':
    if not Source.exists(): Extract('/transfer/linux-baseline-source.tar',Source)
    if not (Root/'gl007').exists(): Extract('/transfer/gl007-src.tar',Root/'gl007')
    Run([sys.executable,Source/'tests/runtime/SourceFingerprint.py',Source],'baseline-source',30)
    if not Engine.exists(): Run([sys.executable,Source/'tests/runtime/ProvisionGodot.py','--output',Root/'godot'],'godot',180)
    Run(['cmake','-S',Source/'tests/runtime','-B',Build,'-G','Ninja','-DCMAKE_BUILD_TYPE=Release','-DCMAKE_CXX_COMPILER=clang++-19','-DCMAKE_C_COMPILER=clang-19','-DGL_BUILD_GODOT_ADAPTER=ON','-DGL_BASELINE_SOURCE_ROOT=/work/gl007'],'configure')
    Run(['cmake','--build',Build,'--target','GodotLuauAdapter','GodotLuauBaselineAdapter','ExecutionDomainTests','DatastoreBackendProbe','--parallel','2'],'baseline-build',3600)
    Frozen = Root/'baseline-v2'
    Frozen.mkdir()
    for Name in ['godot_luau.so','godot_luau_store_worker']:
        shutil.copy2(Build/Name,Frozen/Name)
    Run(['ctest','--test-dir',Build,'--output-on-failure','--output-junit',Logs/'baseline-core.xml'],'baseline-core',120)
elif Action == 'candidate':
    shutil.copy2('/transfer/'+('rbx_character-v2.h' if Variant in ['candidate-v2','candidate-v3'] else 'rbx_character.h'),Source/'src/characters/rbx_character.h')
    if Variant=='candidate-v3': shutil.copy2('/transfer/roblox_player.h',Source/'src/characters/roblox_player.h')
    Run(['cmake','--build',Build,'--target','GodotLuauAdapter','ExecutionDomainTests','DatastoreBackendProbe','--parallel','2'],'candidate-build',1800)
    Frozen = Root/Variant
    Frozen.mkdir()
    for Name in ['godot_luau.so','godot_luau_store_worker']: shutil.copy2(Build/Name,Frozen/Name)
elif Action == 'history':
    for Trial in range(3):
        Pairs = [('GL007',Build/'godot_luau_baseline.so'),('V2',Root/'baseline-v2/godot_luau.so')]
        if Trial%2: Pairs.reverse()
        for Name, Library in Pairs:
            Run([sys.executable,Source/'tests/runtime/RunCharacterBenchmarks.py','--godot',Engine,'--extension',Library,'--output',Root/('history-'+Name+'-'+str(Trial)),'--r6-assets',Source/'GodotLuau/assets/avatars/r6'],'history-'+Name+'-'+str(Trial),120)
elif Action == 'performance':
    Run([sys.executable,Source/'tests/runtime/RunCharacterPerformance.py','--godot',Engine,'--extension',Root/Variant/'godot_luau.so','--baseline',Root/'baseline-v2/godot_luau.so','--output',Root/('comparison-v3' if Variant=='candidate-v3' else 'comparison-v2' if Variant=='candidate-v2' else 'comparison'),'--trials','5'],'performance-'+Variant,900)
elif Action == 'regression':
    Output=Root/('regression-v3' if Variant=='candidate-v3' else 'regression-v2' if Variant=='candidate-v2' else 'regression')
    Output.mkdir(exist_ok=True)
    for Name in ['DatastoreBackendProbe','DatastoreProcessProbe']:
        if (Build/Name).exists(): shutil.copy2(Build/Name,Root/Variant/Name)
    Run(['ctest','--test-dir',Build,'--output-on-failure','--verbose','--test-output-size-passed','65536','--test-output-size-failed','65536','--output-junit',Logs/'candidate-core.xml'],'candidate-core',120)
    Run([sys.executable,Source/'tests/runtime/CheckCoreCI.py','report',Logs/'candidate-core.xml'],'candidate-core-check',30)
    for Group in ['regression','security','animation','characters','resources','filesystem','http','httpservice','callers','presentation','performance','datastore']:
        if (Output/Group/'results.json').exists(): continue
        if Group=='performance':
            Run([sys.executable,Source/'tests/runtime/RunCharacterPerformance.py','--godot',Engine,'--extension',Root/Variant/'godot_luau.so','--output',Output/Group,'--trials','1','--samples','120','--counts','1,16'],'regression-'+Group,240)
        elif Group=='presentation':
            Run([sys.executable,Source/'tests/runtime/RunCharacterPresentation.py','--godot',Engine,'--extension',Root/Variant/'godot_luau.so','--output',Output/Group],'regression-'+Group,240)
        else:
            Extra=['--teardown','--coordinated-close'] if Group=='regression' else ['--'+Group]
            Run([sys.executable,Source/'tests/runtime/RunQualification.py','--godot',Engine,'--extension',Root/Variant/'godot_luau.so','--output',Output/Group,*Extra,'--timeout','15' if Group=='resources' else '60'],'regression-'+Group,600)
    Run([sys.executable,Source/'tests/runtime/CheckNativeCI.py','--output',Output,'--extension',Root/Variant/'godot_luau.so','--godot-evidence',Root/'godot/provenance.json','--revision','character-qualification-overlay-based-on-c562ba8'],'regression-check',60)
elif Action == 'network':
    for Trial in range(5):
        Pairs=[('Baseline',Root/'baseline-v2/godot_luau.so'),('Candidate',Root/Variant/'godot_luau.so')]
        if Trial%2: Pairs.reverse()
        for Name,Library in Pairs:
            Label='v3-network-'+Name+'-'+str(Trial)
            Run([sys.executable,Source/'tests/runtime/RunCharacterNetworkBenchmarks.py','--godot',Engine,'--extension',Library,'--output',Root/Label,'--r6-assets'],Label,120)
    for Trial in range(3):
        Pairs=[('GL007',Build/'godot_luau_baseline.so'),('V2',Root/'baseline-v2/godot_luau.so')]
        if Trial%2: Pairs.reverse()
        for Name,Library in Pairs:
            Label='history-network-'+Name+'-'+str(Trial)
            Run([sys.executable,Source/'tests/runtime/RunCharacterNetworkBenchmarks.py','--godot',Engine,'--extension',Library,'--output',Root/Label,'--r6-assets'],Label,120)
elif Action == 'asan':
    Sanitizer=Root/'build-asan'
    Run(['cmake','-S',Source/'tests/runtime','-B',Sanitizer,'-G','Ninja','-DCMAKE_BUILD_TYPE=Debug','-DCMAKE_CXX_COMPILER=clang++-19','-DCMAKE_C_COMPILER=clang-19','-DGL_BUILD_GODOT_ADAPTER=OFF','-DCMAKE_CXX_FLAGS=-fsanitize=address -fno-omit-frame-pointer','-DCMAKE_EXE_LINKER_FLAGS=-fsanitize=address'],'asan-configure')
    Run(['cmake','--build',Sanitizer,'--target','ExecutionDomainTests','DataStoreWorker','--parallel','2'],'asan-build',900)
    Environment['ASAN_OPTIONS']='detect_leaks=1:halt_on_error=1'
    Run(['ctest','--test-dir',Sanitizer,'--output-on-failure','--verbose','--test-output-size-passed','65536','--test-output-size-failed','65536','--output-junit',Logs/'asan-core.xml'],'asan-core',120)
    Run([sys.executable,Source/'tests/runtime/CheckCoreCI.py','report',Logs/'asan-core.xml'],'asan-core-check',30)
else: raise ValueError(Action)
