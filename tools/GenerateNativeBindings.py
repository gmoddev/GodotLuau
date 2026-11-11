"""Generate runtime descriptors and Luau definitions from approved pinned metadata.

Run from any directory. --check is read-only; --emit-json supports review before
writing. Changing policy is a native capability change requiring qualification.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import sys

Root = Path(__file__).resolve().parents[1]
Kinds = {'float': 'Number', 'int': 'Integer', 'bool': 'Boolean', 'String': 'Text',
         'StringName': 'Text', 'Vector3': 'Vector', 'Vector2': 'Vector2Value', 'Color': 'Colour'}
Types = {'Number': 'number', 'Integer': 'number', 'Boolean': 'boolean', 'Text': 'string',
         'Vector': 'NativeVector3', 'Vector2Value': 'NativeVector2', 'Colour': 'NativeColor3', 'Void': '()'}
Adapters = {'@font_size': ('Integer', 'Control'), '@separation': ('Integer', 'BoxContainer'),
            '@full_rect': ('Boolean', 'Control'), '@font': ('ResourceValue', 'Control')}
ForbiddenProperties = {'script', 'owner', 'resource_path', 'resource_scene_unique_id',
                       'process_thread_group', 'process_thread_messages', 'multiplayer'}
ForbiddenMethods = {'call', 'callv', 'call_deferred', 'set', 'get', 'set_deferred', 'set_script',
                    'free', 'queue_free', 'duplicate', 'reparent', 'add_child', 'remove_child',
                    'replace_by', 'set_owner', 'connect', 'emit_signal', 'set_meta', 'set_path'}
ScopeOperations = [
    ('New', 'approved class, properties, parent? -> native handle'),
    ('Configure', 'target, properties -> ()'), ('Get', 'target, property -> typed value'),
    ('Call', 'target, approved method, arguments... -> typed value'),
    ('Connect', 'node, approved signal, callback -> connection'),
    ('Load', 'approved resource type, project path -> immutable resource'),
    ('Instantiate', 'packed scene, parent? -> owned native node'),
    ('Clone', 'owned node, parent? -> owned native node'),
    ('Reparent', 'owned node, owned parent, keep global? -> ()'),
    ('Mesh', 'primitive mesh -> immutable array mesh'), ('Pin', 'soft body, vertex, pinned -> ()'),
    ('Tone', 'frequency, seconds -> immutable audio'), ('Play', 'audio player -> ()'),
    ('Stop', 'audio player -> ()'), ('Impulse', 'rigid body, vector3 -> ()'),
]


def Require(Value, Message):
    if not Value:
        raise ValueError(Message)


def Build(Policy, Api):
    Classes = {C['name']: C for C in Api['classes']}

    def Ancestors(Name):
        Seen = set()
        while Name:
            Require(Name in Classes and Name not in Seen, 'Unknown/cyclic native class: ' + Name)
            Seen.add(Name)
            yield Name
            Name = Classes[Name].get('inherits')

    def Inherits(Name, Base):
        return Base in Ancestors(Name)

    def Member(Name, Key, Native):
        for Parent in Ancestors(Name):
            for Item in Classes[Parent].get(Key, []):
                if Item['name'] == Native:
                    return Item
        raise ValueError(f'Unknown {Key}: {Name}.{Native}')

    def Kind(Type):
        if ',' in Type and all(T in Classes and Inherits(T, 'Resource') for T in Type.split(',')):
            return 'ResourceValue'
        if Type in Kinds:
            return Kinds[Type]
        if Type.startswith(('enum::', 'bitfield::')):
            return 'Integer'
        if Type in Classes and Inherits(Type, 'Resource'):
            return 'ResourceValue'
        raise ValueError('Unsupported native Variant signature: ' + Type)

    def Value(Name, Type, Bounds=None):
        K = Kind(Type)
        Low, High = Bounds if Bounds else ([0, 8192] if K == 'Text' else [-100000, 100000])
        return {'Class': '', 'Name': Name, 'Native': Name, 'Kind': K, 'Min': Low, 'Max': High,
                **({'ResourceClass': Type} if K == 'ResourceValue' else {})}

    Construct = {}
    Selected = set(Policy['LoadTypes'])
    for C in Policy['Classes']:
        N = C['Name']
        Require(N not in Construct, 'Duplicate class policy: ' + N)
        Require(C['Kind'] in ['Node', 'Resource'] and Inherits(N, C['Kind']), 'Invalid class kind: ' + N)
        Require(not C['Construct'] or Classes[N]['is_instantiable'], 'Class is not constructible: ' + N)
        Construct[N] = C
        Selected.add(N)
    Properties, Methods, Signals, Constants, Arguments = [], [], [], [], []
    Keys = set()
    for P in Policy['Properties']:
        P = dict(P)
        C, N, Native = P['Class'], P['Name'], P['Native']
        Require((C, N) not in Keys, f'Duplicate property: {C}.{N}')
        Keys.add((C, N))
        Require(Native not in ForbiddenProperties, 'Structural/capability property denied: ' + Native)
        if Native.startswith('@'):
            Require(Native in Adapters and (P['Kind'], C) == Adapters[Native], 'Unreviewed property adapter: ' + Native)
        else:
            M = Member(C, 'properties', Native)
            Require(Kind(M['type']) == P['Kind'], f'Property type mismatch: {C}.{N}')
            Require(M.get('getter') and M.get('setter'), f'Property must support checked read/write: {C}.{N}')
            if P['Kind'] == 'ResourceValue':
                Require(all(Inherits(T, P['ResourceClass']) or Inherits(P['ResourceClass'], T) for T in M['type'].split(',')), f'Resource type mismatch: {C}.{N}')
        Require(P.get('Min', 0) <= P.get('Max', 0), f'Invalid bounds: {C}.{N}')
        Properties.append(P)
        Selected.add(C)
        if P.get('ResourceClass'):
            Selected.add(P['ResourceClass'])
    for P in Policy['Methods']:
        C, N, Native = P['Class'], P['Name'], P['Native']
        Require(Native not in ForbiddenMethods, 'Structural/arbitrary method denied: ' + Native)
        M = Member(C, 'methods', Native)
        Require(not any(M.get(K) for K in ['is_vararg', 'is_static', 'is_virtual']), f'Unsupported call mode: {C}.{N}')
        Args = M.get('arguments', [])
        Require(len(Args) <= 4, f'Method argument bound: {C}.{N}')
        First = len(Arguments)
        Required = 0
        for A in Args:
            Arguments.append(Value(A['name'], A['type'], P.get('Bounds', {}).get(A['name'])))
            Required += 'default_value' not in A
        Return = M.get('return_value', {}).get('type')
        Methods.append({**P, 'Arguments': len(Args), 'Required': Required, 'FirstArgument': First,
                        'Return': Kind(Return) if Return else 'Void', 'ReturnClass': Return if Return in Classes else None,
                        'Signature': M})
        Selected.add(C)
    for P in Policy['Signals']:
        M = Member(P['Class'], 'signals', P['Native'])
        Args = M.get('arguments', [])
        Require(len(Args) <= 4, 'Signal argument bound')
        First = len(Arguments)
        for A in Args:
            Arguments.append(Value(A['name'], A['type']))
        Signals.append({**P, 'FirstArgument': First, 'Arguments': len(Args)})
        Selected.add(P['Class'])
    for P in Policy['Enums']:
        E = Member(P['Class'], 'enums', P['Name'])
        for V in E['values']:
            Constants.append({'Class': P['Class'], 'Enum': P['Name'], 'Name': V['name'], 'Value': V['value']})
        Selected.add(P['Class'])
    All = set()
    for Name in Selected:
        All.update(Ancestors(Name))
    Records = [{'Name': N, 'Base': Classes[N].get('inherits', ''), 'Construct': Construct.get(N, {}).get('Construct', False),
                'Resource': Inherits(N, 'Resource')} for N in sorted(All)]
    return {'Classes': Records, 'Properties': Properties, 'Methods': Methods, 'Signals': Signals,
            'Constants': Constants, 'Arguments': Arguments, 'LoadTypes': Policy['LoadTypes']}


def Quote(Value):
    return json.dumps(Value, ensure_ascii=True) if Value is not None else 'nullptr'


def PropertyLine(P):
    return '{' + ','.join([Quote(P['Class']), Quote(P['Name']), Quote(P['Native']), P['Kind'],
                          str(P.get('Min', 0)), str(P.get('Max', 0)), Quote(P.get('ResourceClass'))]) + '}'


def Type(P, Mutable=False):
    if P['Kind'] == 'ResourceValue':
        return ('MutableNative' if Mutable else 'Native') + P['ResourceClass'] + '?'
    return Types[P['Kind']]


def Generate(Policy, Api):
    D = Build(Policy, Api)
    PolicyHash = hashlib.sha256(json.dumps(Policy, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
    H = ['// Generated by tools/GenerateNativeBindings.py. Do not edit.', '#pragma once',
         '#include "gl_native_registry.h"', 'namespace GLNative {',
         'inline constexpr const char* PolicySHA256 = ' + Quote(PolicyHash) + ';',
         'inline constexpr const char* ApiSHA256 = ' + Quote(Policy['ApiSHA256']) + ';']
    Tables = [('Class', 'Classes', ['{' + ','.join([Quote(C['Name']), Quote(C['Base']), str(C['Construct']).lower(), str(C['Resource']).lower()]) + '}' for C in D['Classes']]),
              ('Property', 'Properties', [PropertyLine(P) for P in D['Properties']]),
              ('Property', 'Arguments', [PropertyLine(P) for P in D['Arguments']]),
              ('Method', 'Methods', ['{' + ','.join([Quote(M['Class']), Quote(M['Name']), Quote(M['Native']), str(M['Mutates']).lower(), str(M['FirstArgument']), str(M['Arguments']), str(M['Required']), M['Return'], Quote(M['ReturnClass'])]) + '}' for M in D['Methods']]),
              ('Signal', 'Signals', ['{' + ','.join([Quote(S['Class']), Quote(S['Name']), Quote(S['Native']), str(S['FirstArgument']), str(S['Arguments'])]) + '}' for S in D['Signals']]),
              ('Constant', 'Constants', ['{' + ','.join([Quote(C['Class']), Quote(C['Enum']), Quote(C['Name']), str(C['Value'])]) + '}' for C in D['Constants']]),
              ('Operation', 'ScopeOperations', ['{' + Quote(N) + ',' + Quote(S) + '}' for N, S in ScopeOperations])]
    for Cpp, Name, Lines in Tables:
        H += ['inline constexpr ' + Cpp + ' ' + Name + '[] = {', *['    ' + L + ',' for L in Lines], '};']
    H += ['inline constexpr const char* LoadTypes[] = {' + ','.join(map(Quote, D['LoadTypes'])) + '};', '}']
    ByName = {C['Name']: C for C in D['Classes']}

    def Inherits(Name, Base):
        while Name:
            if Name == Base:
                return True
            Name = ByName[Name]['Base']
        return False

    def Effective(Name):
        Values = {}
        for P in D['Properties']:
            if Inherits(Name, P['Class']):
                Values.setdefault(P['Name'], P)
        return list(Values.values())

    T = ['-- Generated approved native definitions. Load as a definitions file, never require it.',
         '-- Policy SHA256: ' + PolicyHash, 'type NativeVector2 = { X: number, Y: number }',
         'declare class NativeVector3', '    X: number', '    Y: number', '    Z: number',
         '    Lerp: (self: NativeVector3, Other: NativeVector3, Alpha: number) -> NativeVector3', 'end',
         'declare class NativeColor3', '    R: number', '    G: number', '    B: number', 'end',
         'declare Vector3: { new: (number, number, number) -> NativeVector3 }',
         'declare Vector2: { new: (number, number) -> NativeVector2 }',
         'declare Color3: { new: (number, number, number) -> NativeColor3 }',
         'type NativeConnection = { Disconnect: (self: NativeConnection) -> (), Connected: boolean }']
    # Base classes precede their derived declarations.
    Ordered = sorted(D['Classes'], key=lambda C: (sum(Inherits(C['Name'], N) for N in ByName), C['Name']))
    for C in Ordered:
        N, Base = C['Name'], C['Base']
        T.append('declare class Native' + N + (' extends Native' + Base if Base else ''))
        if not C['Resource']:
            for P in D['Properties']:
                if P['Class'] == N and P['Name'] != 'FullRect':
                    T.append('    ' + P['Name'] + ': ' + Type(P))
            if N == 'Node':
                T += ['    Parent: NativeNode?', '    ClassName: string', '    Destroy: (self: NativeNode) -> ()',
                      '    IsA: (self: NativeNode, Class: string) -> boolean',
                      '    FindFirstChild: (self: NativeNode, Name: string, Recursive: boolean?) -> NativeNode?',
                      '    GetChildren: (self: NativeNode) -> {NativeNode}', '    GetDescendants: (self: NativeNode) -> {NativeNode}']
        T.append('end')
        if C['Resource']:
            T += ['declare class MutableNative' + N + ' extends Native' + N, 'end']
    for C in D['Classes']:
        T += ['type Native' + C['Name'] + 'Properties = {']
        T += ['    ' + P['Name'] + ': (' + Type(P) + ')?,' for P in Effective(C['Name'])]
        T += ['}']
    T += ['declare class NativeSceneScope extends NativeNode3D']
    New, Configure, Get, Call, Connect, Load = [], [], [], [], [], []
    for C in D['Classes']:
        N = C['Name']
        if C['Construct']:
            Target = ('MutableNative' if C['Resource'] else 'Native') + N
            New.append(f'(self: NativeSceneScope, Class: "{N}", Properties: Native{N}Properties, Parent: NativeNode?) -> {Target}')
            Configure.append(f'(self: NativeSceneScope, Target: {Target}, Properties: Native{N}Properties) -> ()')
    for P in D['Properties']:
        if P['Name'] != 'FullRect':
            Get.append(f'(self: NativeSceneScope, Target: Native{P["Class"]}, Property: "{P["Name"]}") -> {Type(P)}')
    for M in D['Methods']:
        Args = D['Arguments'][M['FirstArgument']:M['FirstArgument'] + M['Arguments']]
        Tail = ''.join(', ' + A['Name'] + ': ' + Type(A) + ('?' if I >= M['Required'] else '') for I, A in enumerate(Args))
        C = ('MutableNative' if ByName[M['Class']]['Resource'] and M['Mutates'] else 'Native') + M['Class']
        Return = Type({'Kind': M['Return'], 'ResourceClass': M['ReturnClass']})
        Call.append(f'(self: NativeSceneScope, Target: {C}, Method: "{M["Name"]}"{Tail}) -> {Return}')
    for S in D['Signals']:
        Args = D['Arguments'][S['FirstArgument']:S['FirstArgument'] + S['Arguments']]
        Connect.append(f'(self: NativeSceneScope, Source: Native{S["Class"]}, Signal: "{S["Name"]}", Callback: ({", ".join(Type(A) for A in Args)}) -> ()) -> NativeConnection')
    for N in D['LoadTypes']:
        Load.append(f'(self: NativeSceneScope, Type: "{N}", Path: string) -> Native{N}')
    for Name, Overloads in [('New', New), ('Configure', Configure), ('Get', Get), ('Call', Call), ('Connect', Connect), ('Load', Load)]:
        T.append('    ' + Name + ': ' + ' &\n        '.join('(' + S + ')' for S in Overloads))
    T += ['    Instantiate: (self: NativeSceneScope, Scene: NativePackedScene, Parent: NativeNode?) -> NativeNode',
          '    Clone: (self: NativeSceneScope, Source: NativeNode, Parent: NativeNode?) -> NativeNode',
          '    Reparent: (self: NativeSceneScope, Target: NativeNode, Parent: NativeNode, KeepGlobal: boolean?) -> ()',
          '    Mesh: (self: NativeSceneScope, Primitive: NativePrimitiveMesh) -> NativeArrayMesh',
          '    Pin: (self: NativeSceneScope, Body: NativeSoftBody3D, Vertex: number, Pinned: boolean) -> ()',
          '    Tone: (self: NativeSceneScope, Frequency: number, Seconds: number) -> NativeAudioStream',
          '    Play: (self: NativeSceneScope, Player: NativeAudioStreamPlayer) -> ()',
          '    Stop: (self: NativeSceneScope, Player: NativeAudioStreamPlayer) -> ()',
          '    Impulse: (self: NativeSceneScope, Body: NativeRigidBody3D, Impulse: NativeVector3) -> ()', 'end']
    Enums = {}
    for C in D['Constants']:
        Enums.setdefault(C['Class'], {}).setdefault(C['Enum'], {})[C['Name']] = C['Value']
    EnumType = '{' + ', '.join(C + ': {' + ', '.join(E + ': {' + ', '.join(N + ': number' for N in V) + '}' for E, V in Es.items()) + '}' for C, Es in Enums.items()) + '}'
    T += ['declare Scene: { new: (Parent: any) -> NativeSceneScope, Classes: () -> {string},',
          '    Describe: (Class: string) -> { [string]: any }?, Enums: ' + EnumType + ' }']
    D['Schema'] = 1
    D['PolicySHA256'] = PolicyHash
    D['ApiSHA256'] = Policy['ApiSHA256']
    return {'src/core/gl_native_registry.gen.h': '\n'.join(H) + '\n',
            'GodotLuau/Types/Native.d.luau': '\n'.join(T) + '\n',
            'bindings/NativeCatalog.json': json.dumps(D, indent=2) + '\n'}


def Main():
    Parser = argparse.ArgumentParser(description=__doc__)
    Parser.add_argument('--api', type=Path, default=Root/'godot-cpp/gdextension/extension_api.json')
    Parser.add_argument('--check', action='store_true')
    Parser.add_argument('--emit-json', action='store_true')
    Args = Parser.parse_args()
    try:
        Policy = json.loads((Root/'bindings/NativePolicy.json').read_text())
        Raw = Args.api.read_bytes().replace(b'\r\n', b'\n')
        Require(hashlib.sha256(Raw).hexdigest() == Policy['ApiSHA256'], 'Pinned API fingerprint mismatch')
        Outputs = Generate(Policy, json.loads(Raw))
        if Args.emit_json:
            print(json.dumps(Outputs))
        elif Args.check:
            Stale = [N for N, V in Outputs.items() if not (Root/N).exists() or (Root/N).read_text(encoding='utf-8') != V]
            Require(not Stale, 'Generated output drift: ' + ', '.join(Stale))
            print('[Bindings:Generation] PASS checked policy, metadata and generated outputs')
        else:
            for Name, Text in Outputs.items():
                (Root/Name).parent.mkdir(parents=True, exist_ok=True)
                (Root/Name).write_text(Text, encoding='utf-8', newline='\n')
            print('[Bindings:Generation] Wrote', len(Outputs), 'approved outputs')
    except (ValueError, KeyError, OSError) as Error:
        print('[Bindings:Generation]', Error, file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(Main())
