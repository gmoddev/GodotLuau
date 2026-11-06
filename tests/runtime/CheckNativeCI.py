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
    Parser.add_argument('--remote-host-evidence', type=Path, required=True)
    Parser.add_argument('--remote-host-qualification', type=Path, required=True)
    Parser.add_argument('--revision', required=True)
    Args = Parser.parse_args()
    from RemoteHostIdentity import VerifyRemoteHost
    Host = VerifyRemoteHost(json.loads(Args.remote_host_evidence.read_text()))
    HostQualification = json.loads((Args.remote_host_qualification/'summary.json').read_text())
    if HostQualification.get('Result') != 'PASS' or HostQualification.get('Host') != Host or HostQualification.get('UnexpectedReports') or [Record.get('Name') for Record in HostQualification.get('Records', [])] != ['ownership','rpc'] or any(not Record.get('Passed') for Record in HostQualification['Records']):
        raise ValueError('GL-029 admitted host runtime qualification missing or failed')
    Expected = {
        'input': ['input-actions', 'input-controller', 'input-demo'],
        'regression': ['integration-0', 'Listen-0-listen', *[f'{Mode}-0-{Role}' for Mode in ['Dedicated', 'Editor'] for Role in ['server', 'client1', 'client2']]],
        'security': [f'security-{Mode}-{Role}' for Mode in ['Local', 'Listen', 'Dedicated', 'Handler'] for Role in (['server'] if Mode == 'Local' else ['server', 'client1', 'client2'])],
        'animation': [f'animation-{Mode}-{Role}' for Mode in ['Local', 'Listen', 'Dedicated', 'Editor'] for Role in (['server'] if Mode == 'Local' else ['server', 'client1', 'client2'])],
        'remote': [*[f'{Kind}-{Mode}-{Role}' for Kind in ['remote', 'function'] for Mode in ['Listen', 'Dedicated'] for Role in ['server', 'client1', 'client2']], 'replication-server', 'replication-client', *[f'relevance-{Mode}-{Role}' for Mode in ['Listen', 'Dedicated'] for Role in ['server0', 'client1', 'client2']], 'relevance-rootguard'],
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
    Remote = json.loads((Args.output / 'remote/native-evidence.json').read_text())
    Functions = json.loads((Args.output / 'remote/function-evidence.json').read_text())
    Replication = json.loads((Args.output / 'remote/replication-evidence.json').read_text())
    Relevance = json.loads((Args.output / 'remote/relevance-evidence.json').read_text())
    if Relevance.get('Actors') != 7 or Relevance.get('Transport') != 'ENet' or {(Actor.get('Mode'), Actor.get('Role')) for Actor in Relevance.get('Evidence', [])} != {(Mode, Role) for Mode in ['Listen', 'Dedicated'] for Role in ['server0', 'client1', 'client2']} or any(not Actor.get('Complete') or Actor.get('Result') != 'PASS' or not Actor.get('Cases') or any(not Case.get('Passed') for Case in Actor['Cases']) for Actor in Relevance['Evidence']):
        raise ValueError('Relevance lifecycle/authority qualification incomplete')
    RootGuard = Relevance.get('RootGuard', {})
    RootLabels = {Case['Label'] for Case in RootGuard.get('Cases', []) if Case.get('Passed')}
    if not RootGuard.get('Complete') or RootGuard.get('Result') != 'PASS' or not {'opted-in empty catalog has no Character authority fallback', 'Client cannot destroy structural ancestor of captured scope roots before first publication', 'rejected mutation permits ordinary Client callback completion'} <= RootLabels or any(not Case.get('Passed') for Case in RootGuard['Cases']):
        raise ValueError('Empty-catalog scope-root authority qualification missing or failed')
    if Replication.get('Actors') != 2 or Replication.get('Transport') != 'ENet' or {Item['Role'] for Item in Replication.get('Evidence', [])} != {'server', 'client'}:
        raise ValueError('GL-031 actual ENet replication actors missing')
    for Record in Replication['Evidence']:
        Labels = {Item['Label'] for Item in Record['Cases'] if Item['Passed']}
        Required = {'static parent native identity preserved'}
        if Record['Role'] == 'server': Required.add('runtime parent has a later network identity than its child')
        else: Required |= {'late-join static and runtime parent closure arrives', 'static parent full-width identity matches the server', 'late-join value snapshot decoded', 'reparent preserves native runtime identity', 'descendant identity survives reparent', 'removed subtree identities are forgotten', 'replacement has fresh native and network identities'}
        if not Record['Complete'] or Record['Result'] != 'PASS' or not Required <= Labels or not all(Item['Passed'] for Item in Record['Cases']):
            raise ValueError('GL-031 parent/materialization regression incomplete')
    if Functions.get('Actors') != 6 or Functions.get('Transport') != 'ENet' or len(Functions.get('Evidence', [])) != 6:
        raise ValueError('GL-030 real ENet actor evidence missing')
    if {(Record['Mode'], Record['Role'], Record['ClientIndex']) for Record in Functions['Evidence']} != {(Mode, Role, Index) for Mode in ['Listen', 'Dedicated'] for Role, Index in [('server', 0), ('client', 1), ('client', 2)]}:
        raise ValueError('GL-030 actor identity inventory mismatch')
    for Record in Functions['Evidence']:
        Labels = {Item['Label'] for Item in Record['Cases'] if Item['Passed']}
        Required = {'server yielding handler installed', 'both clients published function endpoints', 'both clients completed success error timeout manual-resume cases', 'InvokeClient preserves yielding success', 'both requests reached handlers before endpoint retirement', 'same path replacement has fresh native identity', 'retirement completes exact pending requests on both peers', 'server retires all serving and pending records'} if Record['Role'] == 'server' else {'function publication acknowledged and activated', 'request identity seeded above exact Lua number range', 'success nil slots nested payload error timeout manual-resume and bounds', 'client terminal outcomes release exact correlation records', 'reflected response cannot establish transport provenance', 'endpoint retirement and retained closure reject replacement', 'request identity exhaustion fails before wrap or reuse'}
        Required |= {'duplicate requests cannot execute a second handler', 'both actual ENet peers submitted adversarial responses', 'wrong sender session and generation cannot settle an invocation', 'expected peer submitted duplicate late responses', 'wrong-peer stale-session generation and duplicate late frames rejected'} if Record['Role'] == 'server' else {'exact pending ceiling admits and one-over rejects', 'per-peer pending accounting retains exactly sixty-four requests', 'task cancellation detaches all pending records'}
        Required |= {'reflection cannot allocate ownerless request slots'}
        if Record['Role'] == 'client': Required |= {'deadline completes under accelerated simulation time', 'native deadline uses wall time instead of scaled frame delta', 'server retirement settles the in-flight call', 'Client replacement has fresh ObjectID and cannot inherit function readiness'}
        if not Record['Complete'] or Record['Result'] != 'PASS' or not Required <= Labels or not all(Item['Passed'] for Item in Record['Cases']):
            raise ValueError('GL-030 terminal-outcome qualification incomplete')
    if Remote['Actors'] != 6 or Remote['Transport'] != 'ENet' or len(Remote['Evidence']) != 6:
        raise ValueError('GL-029 real ENet actors missing')
    if {(Record['Mode'], Record['Role'], Record['Index']) for Record in Remote['Evidence']} != {(Mode, Role, Index) for Mode in ['Listen', 'Dedicated'] for Role, Index in [('server', 0), ('client', 1), ('client', 2)]}:
        raise ValueError('GL-029 actor identity inventory mismatch')
    for Record in Remote['Evidence']:
        Labels = {Item['Label'] for Item in Record['Cases'] if Item['Passed']}
        Required = {'malformed, oversized, stale, mode and role rejection has no dispatch', 'old endpoint packets never target replacement at same path', 'new assigned sessions preserve legitimate delivery'} if Record['Role'] == 'server' else {'Server descriptors and peer readiness acknowledged', 'Client authority, payload bounds, Once, Wait, mixed tables and nil arguments', 'same-path Client replacement cannot inherit publication readiness', 'retained methods and exact Wait cancellation survive native destruction', 'fresh session legitimate delivery and stale-session rejection'}
        Required |= {'private ancestor prevents publication through a nested scope name'} if Record['Role'] == 'server' else {'reliable stream preserves accepted send and callback-start order', 'large reliable payload completes through ENet fragmentation', 'wrong transport sender reaches the other real ENet Client'}
        Required.add('serialized configuration survives a fresh native instance')
        Required.add('functional carrier throttle profile applied to fresh peer')
        Required.add('failed server bind preserves the active publication epoch' if Record['Role'] == 'server' else 'failed native connection attempt preserves current publication and transport')
        Required |= {'native private service type remains private after rename', 'Player identity is reserved before reentrant native child callbacks', 'existing RemoteFunction disconnect outcomes preserved'} if Record['Role'] == 'server' else {'accepted queued Wait cannot resume after service disconnect; sibling callback survives', 'real event admission and invocation execute within the controlled ENet poll', 'real poll admits event without running its pending Wait', 'controlled native drain queues the accepted Wait resume'}
        Required |= {'only sequences three and four from each peer enter the dispatch queue', 'admitted three and four each execute once per independent peer', 'native watermark and unsent replacement preserve stream order'} if Record['Role'] == 'server' else {'sequenced stream retains only newest unsent sample'}
        Required |= {'wrong native carriers and invalid high sequences reject before freshness; duplicates remain stale', 'healthy peer progresses while slow peer retains its exact reliable FIFO', 'exact unordered record ceiling admits and one-over drops without evicting old work', 'publication destruction retires exact queued ownership'} if Record['Role'] == 'server' else {'sequence exhaustion preserves accepted candidate and independent Remote counter', 'failed reliable admission retains old bounded work until explicit peer failure', 'reliable exhaustion terminates its session and releases exact queue ownership'}
        Required |= {'unordered duplicate/reorder injection preserves each peer\'s actual submitted payload order', 'targeted and broadcast egress share each peer stream without sharing ingress freshness'} if Record['Role'] == 'server' else {'client sequenced callback starts match independent targeted/broadcast admission'}
        if Record['Role'] == 'client': Required |= {'expired unreliable work drops with accounting while its session remains healthy', 'aged reliable work ends its session explicitly instead of silently expiring'}
        if Record['Role'] == 'server' and Record['Mode'] == 'Listen': Required |= {'listen Client creation cannot publish a native endpoint', 'listen local FireServer receives the real Player', 'local validation precedes broadcast side effects'}
        if not Record['Complete'] or Record['Result'] != 'PASS' or not Required <= Labels or not all(Item['Passed'] for Item in Record['Cases']):
            raise ValueError('GL-029 required assertions missing or failed')
    Lifecycle = (Args.output / 'regression' / 'integration-0.stdout.log').read_text(errors='replace')
    for Marker in ['[Runtime:ChildRelay] PASS', '[Runtime:ChildRelay] Independent domain destruction and replacement checked', '[Runtime:ChildRelay] Scene generations PASS', '[Runtime:ChildRelay] Dispatch shutdown PASS']:
        if Marker not in Lifecycle:
            raise ValueError('GL-022 native regression was not exercised: ' + Marker)
    for Label in Expected['resources']:
        Text = (Args.output / 'resources' / (Label + '.stdout.log')).read_text(errors='replace')
        if '[Runtime:Resource] PASS ' + Label.removeprefix('resource-') not in Text or '[Runtime:Resource] FAIL' in Text:
            raise ValueError('GL-004 native resource regression missing/failed: ' + Label)
    AnimationAuthority = []
    for Mode in ['Local', 'Listen', 'Dedicated', 'Editor']:
        Roles = [('server', 0)] if Mode == 'Local' else [('server', 0), ('client', 1), ('client', 2)]
        for Role, Index in Roles:
            Record = json.loads((Args.output / 'animation' / Mode / f'animation-authority-{Role}{Index}.json').read_text())
            Required = {'local-role', 'owner', 'callback', 'teardown'} if Mode == 'Local' else {'default-authority', 'relaxed-handler', 'invalid-input', 'server-input', 'post-server-input', 'replay', 'owner', 'life', 'reconnect', 'teardown'}
            if Record['Mode'] != Mode or Record['Role'] != Role or Record['Index'] != Index or not Record['Complete'] or Record['Result'] != 'PASS':
                raise ValueError('GL-020 authority actor incomplete: ' + Mode + '/' + Role)
            if {Item['Phase'] for Item in Record['Cases']} != Required or any(not Item['Passed'] for Item in Record['Cases'] + Record['Assertions']):
                raise ValueError('GL-020 authority phase/assertion missing or failed')
            if Role == 'client':
                OldLife = Record['Observations'].get('OldLife', {})
                Replica = OldLife.get('NativeReplica', {})
                if not OldLife.get('ObservedReplacement') or Replica.get('Removed', True) or Replica.get('Life', 0) <= OldLife.get('RetiredLife', 0):
                    raise ValueError('GL-020 stale-life test did not establish the actual replacement receive life')
                if not any(Item['Label'] == 'replacement life is received before stale-life attack' for Item in Record['Cases']):
                    raise ValueError('GL-020 replacement receive barrier was skipped')
            if Role == 'client' and Index == 1 and len([Name for Name in Record['Sent'] if Name.startswith('invalid-input-')]) != 23:
                raise ValueError('GL-020 original wire Variant/bounds cases were skipped')
            if Role == 'server' and Mode != 'Local' and len([Name for Name in Record['Sent'] if Name.startswith('server-input-')]) != 20:
                raise ValueError('GL-020 actual server-origin receiver cases were skipped')
            AnimationAuthority.append(Record)
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
        if Item['Case'] not in ['r6','custom'] and not (Item['Case'].startswith('dedicated') and Item['Role']=='server0') and 'walking observation starts from grounded owner' not in Labels: raise ValueError('Walking observation skipped physical grounding')
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
        'RemoteEvents': Remote,
        'RemoteHost': Host,
        'RemoteHostQualification': HostQualification,
        'RemoteFunctions': Functions,
        'ReplicationNative': Replication,
        'RelevanceNative': Relevance,
        'AnimationAuthority': AnimationAuthority,
        'PresentationNative': Presentation,
        'PerformanceNative': {'Actors': 1, 'Graphical': False, 'Counts': [1,16], 'Profiles': len(Profiles), 'SpeedGate': False},
        'Godot': json.loads(Args.godot_evidence.read_text()), 'Groups': Groups,
        'HarnessHashes': {File.name: hashlib.sha256(File.read_bytes().replace(b'\r\n', b'\n')).hexdigest() for File in sorted(Path(__file__).parent.iterdir()) if File.suffix in ['.gd', '.py', '.pem', '.cpp'] or File.name in ['CMakeLists.txt', 'GodotDistribution.json']} | {'Controller.luau': hashlib.sha256((Path(__file__).resolve().parents[2]/'examples/input-controller/Controller.luau').read_bytes().replace(b'\r\n', b'\n')).hexdigest()},
        'Processes': sum(len(Results) for Results in Groups.values()),
        'LogHashes': {str(File.relative_to(Args.output)): hashlib.sha256(File.read_bytes()).hexdigest() for File in sorted(Args.output.rglob('*.log'))},
        'Scope': 'Native fixtures including actual GL-020 ENet authority/handler/life cases, GL-023 public HTTP/JSON/native UUID, Model Character V2 and inherited GL-007 authority; sanitizer configuration and remaining qualification limits are recorded by the invoking matrix'
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
