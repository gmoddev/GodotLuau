"""Require complete results from the existing native regression fixture groups."""
import argparse
import hashlib
import json
from pathlib import Path
from SourceFingerprint import GetFingerprint


def Main():
    Parser = argparse.ArgumentParser(description=__doc__)
    Parser.add_argument('--output', type=Path, required=True)
    Parser.add_argument('--extension', type=Path, required=True)
    Parser.add_argument('--godot-evidence', type=Path, required=True)
    Parser.add_argument('--revision', required=True)
    Args = Parser.parse_args()
    Expected = {
        'regression': ['integration-0', 'Listen-0-listen', *[f'{Mode}-0-{Role}' for Mode in ['Dedicated', 'Editor'] for Role in ['server', 'client1', 'client2']]],
        'security': [f'security-{Mode}-{Role}' for Mode in ['Local', 'Listen', 'Dedicated', 'Handler'] for Role in (['server'] if Mode == 'Local' else ['server', 'client1', 'client2'])],
        'animation': [f'animation-{Mode}-{Role}' for Mode in ['Local', 'Listen', 'Dedicated', 'Editor'] for Role in (['server'] if Mode == 'Local' else ['server', 'client1', 'client2'])],
        'characters': [*[f'character-{Mode}-{Role}' for Mode in ['Local', 'Listen', 'Dedicated', 'TwoD', 'Movement', 'Latency'] for Role in (['server'] if Mode == 'Local' else ['server', 'client1', 'client2'])], 'character-model', 'character-manual-server', 'character-manual-client1', 'character-manual-client2'],
        'resources': ['resource-' + Case for Case in ['execution', 'module', 'callback', 'invoke', 'memory', 'tasks', 'shutdown', 'configuration']],
        'filesystem': ['filesystem-capabilities','filesystem-writer','filesystem-reader'],
        'http': ['http-enabled','http-denied','http-lifecycle','http-tls'],
        'httpservice': ['httpservice-' + Case for Case in ['api', 'denied', 'lifecycle', 'tls', 'utilities-A', 'utilities-B']],
        'callers': ['callers-' + Case for Case in ['status', 'empty', 'denied']],
        'presentation': ['presentation-r6-single0', 'presentation-custom-single0', *['presentation-' + Case + '-' + Role for Case in ['listen', 'dedicated', 'listen-custom', 'dedicated-custom'] for Role in ['server0', 'client1', 'client2']]],
        'performance': ['Candidate-0'],
        'datastore': ['datastore-basic-basic-single',
            *[Label for Case in ['update','set','remove','increment'] for Label in ['datastore-'+Case+'-seed-single','datastore-'+Case+'-'+Case+'-A','datastore-'+Case+'-'+Case+'-B','datastore-'+Case+'-verify-single']],
            *['datastore-'+Case+'-'+Case+'-single' for Case in ['failures','lifecycle','memory','contention','unavailable','incompatible']]]
    }
    Groups = {}
    for Name, Labels in Expected.items():
        Results = json.loads((Args.output / Name / 'results.json').read_text())
        if [Result['Label'] for Result in Results] != Labels or any(Result['Exit'] != 0 for Result in Results):
            raise ValueError('Missing or failed native fixture results: ' + Name)
        Groups[Name] = Results
    Lifecycle = (Args.output / 'regression' / 'integration-0.stdout.log').read_text(errors='replace')
    for Marker in ['[Runtime:ChildRelay] PASS', '[Runtime:ChildRelay] Independent domain destruction and replacement checked', '[Runtime:ChildRelay] Scene generations PASS', '[Runtime:ChildRelay] Dispatch shutdown PASS']:
        if Marker not in Lifecycle:
            raise ValueError('GL-022 native regression was not exercised: ' + Marker)
    for Label in Expected['resources']:
        Text = (Args.output / 'resources' / (Label + '.stdout.log')).read_text(errors='replace')
        if '[Runtime:Resource] PASS ' + Label.removeprefix('resource-') not in Text or '[Runtime:Resource] FAIL' in Text:
            raise ValueError('GL-004 native resource regression missing/failed: ' + Label)
    for Label,Marker in [('filesystem-capabilities','enforced'),('filesystem-writer','writer'),('filesystem-reader','reader')]:
        Text=(Args.output/'filesystem'/(Label+'.stdout.log')).read_text(errors='replace')
        if '[Runtime:FilesystemTest] PASS '+Marker not in Text or '[Runtime:FilesystemTest] FAIL' in Text:
            raise ValueError('GL-003 native filesystem regression missing/failed: '+Label)
    for Case in ['enabled', 'denied', 'lifecycle', 'tls']:
        Text = (Args.output / 'http' / Case / ('http-' + Case + '.stdout.log')).read_text(errors='replace')
        Server = json.loads((Args.output / 'http' / Case / 'server-results.json').read_text())
        if '[Runtime:HttpTest] PASS ' + Case not in Text or '[Runtime:HttpTest] FAIL' in Text or any(Hit['Path'].startswith('/forbidden') for Hit in Server['Hits']):
            raise ValueError('GL-005 HTTP regression missing/failed: ' + Case)
    GuidSamples = []
    for Case in ['api', 'denied', 'lifecycle', 'tls', 'utilities-A', 'utilities-B']:
        Project = Args.output / 'httpservice' / Case
        Text = (Project / ('httpservice-' + Case + '.stdout.log')).read_text(errors='replace')
        Server = json.loads((Project / 'server-results.json').read_text())
        if '[Runtime:HttpServiceTest] PASS ' + Case.split('-')[0] not in Text or any(Hit['Path'].startswith('/forbidden') for Hit in Server['Hits']):
            raise ValueError('GL-023 native fixture missing/failed: ' + Case)
        if Case.startswith('utilities'):
            if '[Runtime:HttpServiceTest] JSON PASS; UUID v4 sample=2000' not in Text:
                raise ValueError('GL-023 JSON/native UUID path was not executed: ' + Case)
            Samples = (Project / 'guids.txt').read_text().splitlines()
            if len(Samples) != 2000: raise ValueError('GL-023 UUID sample missing')
            GuidSamples.extend(Samples)
    HttpServiceNative = json.loads((Args.output / 'httpservice/native-evidence.json').read_text())
    if len(set(GuidSamples)) != 4000 or HttpServiceNative != {'Actors': 6, 'GuidProcesses': 2, 'GuidSamples': 4000, 'UniqueGuids': 4000, 'UnauthorizedRequests': 0}:
        raise ValueError('GL-023 native/cross-process evidence incomplete')
    from RunHttpServiceCallers import Snippets
    CallerEvidence = json.loads((Args.output / 'callers/native-evidence.json').read_text())
    SnippetHashes = {Name: hashlib.sha256(Value.encode()).hexdigest() for Name, Value in Snippets(Path(__file__).resolve().parents[2]).items()}
    if CallerEvidence != {'Actors': 3, 'UnauthorizedRequests': 0, 'PublishedSnippetSHA256': SnippetHashes}:
        raise ValueError('Published caller migration evidence incomplete')
    for Case, Paths in [('status', ['/ok', '/status']), ('empty', ['/no-content', '/no-content']), ('denied', [])]:
        Project = Args.output / 'callers' / Case
        Text = (Project / ('callers-' + Case + '.stdout.log')).read_text(errors='replace')
        Hits = json.loads((Project / 'server-results.json').read_text())['Hits']
        if '[Runtime:HttpCallers] PASS ' + Case not in Text or Hits != [{'Method': 'GET', 'Path': Path} for Path in Paths]:
            raise ValueError('Published caller migration fixture missing/failed: ' + Case)
    Presentation = json.loads((Args.output / 'presentation/native-evidence.json').read_text())
    if Presentation['Graphical'] or Presentation['Actors'] != 14 or len(Presentation['Evidence']) != 14:
        raise ValueError('Missing headless presentation assertions or false graphical claim')
    for Item in Presentation['Evidence']:
        if Item['Graphical'] or Item['Result'] != 'PASS' or not Item['Assertions'] or not all(Assertion['Passed'] for Assertion in Item['Assertions']):
            raise ValueError('Presentation assertions did not execute/pass')
        Labels = {Assertion['Label'] for Assertion in Item['Assertions']}
        Required = {'first-person rig transparency and zoom', 'AnimationPlayer advances visual track', 'automatic respawn replaces rendered life', 'touch simulation moves Character', 'Character rotates toward actual movement', 'controller jump reaches real physics', 'mobile simulation GUI jump reaches real physics', 'unchanged root repairs independently changed live body'} if Item['Case'] in ['r6', 'custom'] else {'real ENet remote Characters created', 'remote has real Model identity', 'puppet has no local camera/input', 'owner or replicated Character moves during real transport'}
        if not Required <= Labels: raise ValueError('Presentation case skipped required behavior')
        Additional = {'first-person fade reaches fully invisible endpoint', 'procedural animation enters airborne pose', 'procedural animation returns to grounded pose', 'processed respawns leave no live object growth'} if Item['Case'] in ['r6', 'custom'] else {'remote uses actual custom rig' if Item['Case'].endswith('-custom') else 'remote uses actual R6 rig', 'remote rig animation limbs are present', 'remote procedural animation progresses'}
        if not Additional <= Labels: raise ValueError('Presentation case skipped animation/lifetime assertions')
        if Item['Case'].endswith('-custom') and 'remote custom geometry is not R6 fallback' not in Labels: raise ValueError('Custom multiplayer fixture fell back to the default rig')
    Performance = json.loads((Args.output/'performance/measurements.json').read_text())
    PerformanceInputs = json.loads((Args.output/'performance/inputs.json').read_text())
    if len(Performance) != 1 or Performance[0]['Graphical'] or PerformanceInputs['Trials'] != 1 or PerformanceInputs['SamplesPerPhysicsWindow'] != 120 or PerformanceInputs['Counts'] != '1,16':
        raise ValueError('Performance fixture execution missing or wrong workload')
    Profiles = Performance[0]['Profiles']
    if {(Item['Characters'],Item['Mode']) for Item in Profiles} != {(1,'all'),(16,'all'),(16,'physics-only'),(16,'animation-only'),(16,'inactive')} or any(Item['PhysicsSeconds']['Samples'] < 118 or Item['ProcessSeconds']['Samples'] < 118 for Item in Profiles):
        raise ValueError('Performance fixture skipped independent dispatch windows')
    if Performance[0]['ExtensionSHA256'] != hashlib.sha256(Args.extension.read_bytes()).hexdigest() or PerformanceInputs['SourceAtInvocation'] != GetFingerprint(Path(__file__).resolve().parents[2]):
        raise ValueError('Performance fixture product/source identity mismatch')
    Evidence = {
        'Revision': Args.revision, 'NativeSource': GetFingerprint(Path(__file__).resolve().parents[2]),
        'ExtensionSHA256': hashlib.sha256(Args.extension.read_bytes()).hexdigest(),
        'DataStoreWorkerSHA256': hashlib.sha256((Args.extension.parent/('godot_luau_store_worker.exe' if Args.extension.suffix=='.dll' else 'godot_luau_store_worker')).read_bytes()).hexdigest(),
        'DataStoreNative': json.loads((Args.output/'datastore/native-evidence.json').read_text()),
        'HttpServiceNative': HttpServiceNative,
        'CallerNative': CallerEvidence,
        'PresentationNative': Presentation,
        'PerformanceNative': {'Actors': 1, 'Graphical': False, 'Counts': [1,16], 'Profiles': len(Profiles), 'SpeedGate': False},
        'Godot': json.loads(Args.godot_evidence.read_text()), 'Groups': Groups,
        'HarnessHashes': {File.name: hashlib.sha256(File.read_bytes().replace(b'\r\n', b'\n')).hexdigest() for File in sorted(Path(__file__).parent.iterdir()) if File.suffix in ['.gd', '.py', '.pem', '.cpp'] or File.name in ['CMakeLists.txt', 'GodotDistribution.json']},
        'Processes': sum(len(Results) for Results in Groups.values()),
        'LogHashes': {str(File.relative_to(Args.output)): hashlib.sha256(File.read_bytes()).hexdigest() for File in sorted(Args.output.rglob('*.log'))},
        'Scope': 'Native fixtures including GL-023 public HTTP/JSON/native UUID, Model Character V2 and inherited GL-007 authority; sanitizer configuration is recorded by the invoking matrix, no full GL-020 security audit'
    }
    Latency = json.loads((Args.output / 'characters/Latency/latency-proxy.json').read_text())
    if len(Latency) != 2 or any(Item['Dropped'] or Item['Forwarded'] <= 0 or Item['MinimumObservedSeconds'] < .19 for Item in Latency):
        raise ValueError('GL-007 real ENet delay/reordering evidence missing')
    Evidence['CharacterLatency'] = Latency
    if Evidence['DataStoreNative']!={'FaultStages':4,'KillStages':4,'IndependentIncrements':40,'PowerLossTest':False}:
        raise ValueError('Missing DataStore native interruption/recovery qualification')
    (Args.output / 'summary.json').write_text(json.dumps(Evidence, indent=2))
    print('[Runtime:NativeCI] PASS '+str(Evidence['Processes'])+' required process results')


if __name__ == '__main__':
    Main()
