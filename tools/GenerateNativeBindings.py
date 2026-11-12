"""Generate runtime descriptors and Luau definitions from approved pinned metadata.

Run from any directory. --check is read-only; --emit-json supports review before
writing. Changing policy is a native capability change requiring qualification.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import re
import sys

Root = Path(__file__).resolve().parents[1]
Kinds = {'float': 'Number', 'int': 'Integer', 'bool': 'Boolean', 'String': 'Text',
         'StringName': 'Text', 'Vector3': 'Vector', 'Vector2': 'Vector2Value', 'Color': 'Colour',
         'Vector2i':'Vector2Integer','Vector3i':'Vector3Integer','Vector4':'Vector4Value','Vector4i':'Vector4Integer',
         'Rect2':'Rectangle','Rect2i':'RectangleInteger','Quaternion':'Rotation','Basis':'BasisValue',
         'Transform2D':'Transform2Value','Transform3D':'Transform3Value','Plane':'PlaneValue','AABB':'BoundsValue',
         'Variant':'VariantValue','Array':'ArrayValue','Dictionary':'DictionaryValue',
         'PackedByteArray':'BytesValue','PackedInt32Array':'IntegersValue','PackedInt64Array':'LongsValue',
         'PackedFloat32Array':'FloatsValue','PackedFloat64Array':'DoublesValue','PackedStringArray':'StringsValue',
         'PackedVector2Array':'Vectors2Value','PackedVector3Array':'Vectors3Value','PackedColorArray':'ColoursValue','PackedVector4Array':'Vectors4Value'}
Types = {'Number': 'number', 'Integer': 'number', 'Boolean': 'boolean', 'Text': 'string',
         'Vector': 'NativeVector3', 'Vector2Value': 'NativeVector2', 'Colour': 'NativeColor3', 'Void': '()',
         'Vector2Integer':'NativeVector2i','Vector3Integer':'NativeVector3i','Vector4Value':'NativeVector4','Vector4Integer':'NativeVector4i',
         'Rectangle':'NativeRect2','RectangleInteger':'NativeRect2i','Rotation':'NativeQuaternion','BasisValue':'NativeBasis',
         'Transform2Value':'NativeTransform2D','Transform3Value':'NativeTransform3D','PlaneValue':'NativePlane','BoundsValue':'NativeAABB',
         'Colour4':'NativeColor4','VariantValue':'NativeVariant','ArrayValue':'{NativeVariant}','DictionaryValue':'{[string]: NativeVariant}',
         'BytesValue':'{number}','IntegersValue':'{number}','LongsValue':'{number}','FloatsValue':'{number}','DoublesValue':'{number}',
         'StringsValue':'{string}','Vectors2Value':'{NativeVector2}','Vectors3Value':'{NativeVector3}','ColoursValue':'{NativeColor4}','Vectors4Value':'{NativeVector4}'}
Adapters = {'@font_size': ('Integer', 'Control'), '@separation': ('Integer', 'BoxContainer'),
            '@full_rect': ('Boolean', 'Control'), '@font': ('ResourceValue', 'Control')}
ForbiddenProperties = {'script', 'owner', 'resource_path', 'resource_scene_unique_id',
                       'process_thread_group', 'process_thread_messages', 'multiplayer'}
ForbiddenMethods = {'call', 'callv', 'call_deferred', 'set', 'get', 'set_deferred', 'set_script',
                    'free', 'queue_free', 'duplicate', 'reparent', 'add_child', 'remove_child',
                    'replace_by', 'set_owner', 'connect', 'emit_signal', 'set_meta', 'set_path',
                    'get_tree','get_viewport','get_window','get_multiplayer','set_indexed','get_indexed',
                    'take_over_path','set_deferred_thread_group','call_deferred_thread_group','call_thread_safe'}
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
    for Group in ('Classes','Properties','Methods','Signals'):
        for Entry in Policy[Group]:
            Require(Entry.get('Authority')=='OwnedScene', 'Explicit OwnedScene authorization required: '+Entry.get('Class',Entry.get('Name',''))+'.'+Entry.get('Name',''))

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
        if Type in Classes and Inherits(Type, 'Node'):
            return 'NodeValue'
        raise ValueError('Unsupported native Variant signature: ' + Type)

    def Value(Name, Type, Bounds=None, Default=None, Override=None):
        K = Kind(Type)
        if Override:
            Require((K,Override)==('Colour','Colour4'), 'Unreviewed argument conversion override: '+Name)
            K=Override
        Low, High = Bounds if Bounds else ([0, 8192] if K == 'Text' else [-100000, 100000])
        Require(math.isfinite(Low) and math.isfinite(High) and Low<=High, 'Invalid argument bounds: ' + Name)
        if Default is not None:
            if K=='Text':
                Default=json.loads(Default[1:] if Default.startswith('&') else Default)
                Require(isinstance(Default,str) and Low<=len(Default.encode())<=High and '\0' not in Default, 'Invalid text default: '+Name)
            elif K in ('ResourceValue','NodeValue'):
                Require(Default=='null', 'Unsupported object default: '+Name)
            elif K=='Vector2Value':
                Match=re.fullmatch(r'Vector2\(\s*(-?[0-9.]+)\s*,\s*(-?[0-9.]+)\s*\)',Default)
                Require(Match and all(Low<=float(N)<=High for N in Match.groups()),'Unsupported Vector2 default: '+Name)
            else:
                Require(K in ['Number','Integer','Boolean'] and re.fullmatch(r'-?[0-9]+(?:\.[0-9]+)?|true|false',Default), 'Unsupported native default: ' + Name)
            if K in ['Number','Integer']:
                Require(Low<=float(Default)<=High, 'Default outside policy bounds: ' + Name)
        return {'Class': '', 'Name': Name, 'Native': Name, 'Kind': K, 'Min': Low, 'Max': High,
                **({'ResourceClass': Type} if K in ('ResourceValue','NodeValue') else {}), **({'Default':Default} if Default is not None else {})}

    Construct = {}
    Selected = set(Policy['LoadTypes'])
    for C in Policy['Classes']:
        N = C['Name']
        Require(N not in Construct, 'Duplicate class policy: ' + N)
        Require(C['Kind'] in ['Node', 'Resource'] and Inherits(N, C['Kind']), 'Invalid class kind: ' + N)
        Require(not any(Inherits(N, Base) for Base in ('Window','Viewport','Script')), 'Privileged native class denied: '+N)
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
            Require(Kind(M['type']) == P['Kind'] or (Kind(M['type']),P['Kind'])==('Colour','Colour4'), f'Property type mismatch: {C}.{N}')
            Require(M.get('getter') and (M.get('setter') or P.get('ReadOnly')), f'Property must support checked read/write or observation: {C}.{N}')
            if P['Kind'] == 'ResourceValue':
                Require(all(Inherits(T, P['ResourceClass']) or Inherits(P['ResourceClass'], T) for T in M['type'].split(',')), f'Resource type mismatch: {C}.{N}')
        Require(all(math.isfinite(P.get(K,0)) for K in ['Min','Max']) and P.get('Min', 0) <= P.get('Max', 0), f'Invalid bounds: {C}.{N}')
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
        Require(len(Args) <= 8, f'Method argument bound: {C}.{N}')
        First = len(Arguments)
        Required = 0
        for A in Args:
            Arguments.append(Value(A['name'], A['type'], P.get('Bounds', {}).get(A['name']), A.get('default_value'), P.get('ArgumentKinds',{}).get(A['name'])))
            Arguments[-1]['Class']=C+'.'+N
            if Arguments[-1].get('ResourceClass'): Selected.add(A['type'])
            Required += 'default_value' not in A
        Return = M.get('return_value', {}).get('type')
        ReturnKind=Kind(Return) if Return else 'Void'
        if P.get('ReturnKind'):
            Require((ReturnKind,P['ReturnKind'])==('Colour','Colour4'),'Unreviewed return conversion override')
            ReturnKind=P['ReturnKind']
        if Return in Classes: Selected.add(Return)
        Validation=P.get('Validation',{})
        Rule={'CountQuery':None,'IndexArgument':-1,'AllowEnd':False,'AllowNegativeOne':False,'KeyQuery':None,'KeyArgument':-1,'KeyAbsent':False,'CountArgument':-1,'CountLimit':-1}
        for Role in ('Key','Index'):
            if Role not in Validation: continue
            V=Validation[Role]
            Index=next((I for I,A in enumerate(Args) if A['name']==V['Argument']),-1)
            Require(Index>=0,'Unknown validation argument: '+C+'.'+N)
            Query=V['Query']
            Q=Member(C,'methods',Query)
            Require(Q.get('is_const') and not Q.get('is_vararg') and not Q.get('is_static') and not Q.get('is_virtual'),'Validation query must be native observation')
            Require(Q.get('return_value',{}).get('type') in (('bool','int') if Role=='Key' else ('int',)),'Validation query return type mismatch')
            QA=Q.get('arguments',[])
            if Role=='Key':
                Require(len(QA)==1 and QA[0]['type']==Args[Index]['type'],'Key query signature mismatch')
                Rule.update(KeyQuery=Query,KeyArgument=Index,KeyAbsent=V.get('Absent',False))
            else:
                Require(Args[Index]['type']=='int' and (not QA or (len(QA)==1 and Rule['KeyArgument']>=0 and QA[0]['type']==Args[Rule['KeyArgument']]['type'])),'Index query signature mismatch')
                Rule.update(CountQuery=Query,IndexArgument=Index,AllowEnd=V.get('AllowEnd',False),AllowNegativeOne=V.get('AllowNegativeOne',False),CountArgument=Rule['KeyArgument'] if QA else -1)
        if 'Capacity' in Validation:
            V=Validation['Capacity'];Q=Member(C,'methods',V['Query']);QA=Q.get('arguments',[])
            CountArgument=next((I for I,A in enumerate(Args) if A['name']==V.get('Argument')),-1)
            Require(Q.get('is_const') and not Q.get('is_static') and not Q.get('is_virtual') and not Q.get('is_vararg') and Q.get('return_value',{}).get('type') in ('int','PackedStringArray','Array'),'Invalid capacity observation')
            Require(not QA or (len(QA)==1 and CountArgument>=0 and QA[0]['type']==Args[CountArgument]['type']),'Capacity query signature mismatch')
            Require(0<V['Maximum']<=1024 and Rule['CountQuery'] in (None,V['Query']),'Invalid bounded capacity rule')
            Rule.update(CountQuery=V['Query'],CountLimit=V['Maximum'],CountArgument=CountArgument if QA else -1)
        Methods.append({**P, **Rule, 'Arguments': len(Args), 'Required': Required, 'FirstArgument': First,
                        'Return': ReturnKind, 'ReturnClass': Return if Return in Classes else None,
                        'Signature': M})
        Selected.add(C)
    for P in Policy['Signals']:
        Require(Inherits(P['Class'],'Node'),'Resource handles cannot become Node signal sources')
        M = Member(P['Class'], 'signals', P['Native'])
        Args = M.get('arguments', [])
        Require(len(Args) <= 4, 'Signal argument bound')
        First = len(Arguments)
        for A in Args:
            Arguments.append(Value(A['name'], A['type']))
            Arguments[-1]['Class']=P['Class']+'.'+P['Name']
            if Arguments[-1].get('ResourceClass'): Selected.add(A['type'])
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
                          str(P.get('Min', 0)), str(P.get('Max', 0)), Quote(P.get('ResourceClass')), Quote(P.get('Default')),str(bool(P.get('ReadOnly'))).lower()]) + '}'


def Type(P, Mutable=False):
    if P['Kind'] == 'NodeValue':
        return 'Native'+P['ResourceClass']+'?'
    if P['Kind'] == 'ResourceValue':
        return ('MutableNative' if Mutable else 'Native') + P['ResourceClass'] + '?'
    return Types[P['Kind']]


def Coverage(Policy, Api, Catalog):
    """Inventory metadata, never grant execution from discovery.

    Members are declared on their metadata class; Catalog retains the exact
    approved receiver/alias/bounds. Inherited availability follows Base.
    """
    Classes = {C['name']: C for C in Api['classes']}
    Admitted = {C['Name']: C for C in Catalog['Classes']}
    Singletons = {C['name'] for C in Api['singletons']}
    Restricted = Singletons | {'SceneTree', 'Window', 'Viewport', 'SubViewport',
        'FileAccess', 'DirAccess', 'Script', 'GDScript', 'CSharpScript',
        'Thread', 'Mutex', 'Semaphore', 'TCPServer', 'PacketPeer', 'StreamPeer'}
    def Inherits(Name, Base):
        while Name in Classes:
            if Name == Base: return True
            Name = Classes[Name].get('inherits')
        return False

    def Convertible(Name):
        return not Name or Name in Kinds or Name.startswith(('enum::', 'bitfield::')) or all(Inherits(T, 'Resource') for T in Name.split(','))

    Selections = {K: {} for K in ('methods', 'properties', 'signals', 'enums')}
    for Key, Entries in [('methods', Policy['Methods']), ('properties', Policy['Properties']),
                         ('signals', Policy['Signals']), ('enums', Policy['Enums'])]:
        for Entry in Entries:
            Native = Entry.get('Native', Entry['Name'])
            Name = Entry['Class']
            while Name:
                if any(M['name'] == Native for M in Classes[Name].get(Key, [])):
                    Selections[Key].setdefault((Name, Native), []).append(Entry['Class'])
                    break
                Name = Classes[Name].get('inherits')
    Records = []
    for Name, C in sorted(Classes.items()):
        Selected = Admitted.get(Name)
        Denied = any(Inherits(Name, Base) for Base in Restricted)
        State = 'Partial' if Selected else ('Restricted' if Denied else 'Unsupported')
        if not Selected and not Denied and not Inherits(Name, 'Node') and not Inherits(Name, 'Resource'):
            State = 'Blocked'
        Members = {}
        for Key in ('methods', 'properties', 'signals', 'enums', 'constants'):
            Groups = {S: [] for S in ('Supported', 'Partial', 'Restricted', 'Unsupported', 'Blocked')}
            for Member in C.get(Key, []):
                Native = Member['name']
                Receivers = Selections.get(Key, {}).get((Name, Native), [])
                Status = 'Unsupported'
                if Receivers: Status = 'Supported' if Name in Receivers else 'Partial'
                elif State == 'Restricted' or (Key == 'methods' and Native in ForbiddenMethods) or (Key == 'properties' and Native in ForbiddenProperties):
                    Status = 'Restricted'
                elif Key == 'methods' and (Member.get('is_static') or Member.get('is_virtual') or Member.get('is_vararg') or not Convertible(Member.get('return_value', {}).get('type')) or any(not Convertible(A['type']) for A in Member.get('arguments', []))):
                    Status = 'Blocked'
                elif Key == 'properties' and (not Member.get('getter') or not Member.get('setter') or not Convertible(Member['type'])):
                    Status = 'Blocked'
                Groups[Status].append(Native)
            Members[Key] = {K: V for K, V in Groups.items() if V}
        Records.append({'Name': Name, 'Base': C.get('inherits', ''), 'Status': State,
            'Constructible': bool(Selected and Selected['Construct']),
            'ConstructionStatus': 'Supported' if Selected and Selected['Construct'] else 'Not admitted',
            'Loadable': Name in Policy['LoadTypes'], 'GeneratedHandle': bool(Selected),
            'Permission': 'Exact live SceneScope owner' if Selected else 'Not admitted',
            'Editor': 'Policy analysis and restricted explicit preview' if Selected else 'Metadata only',
            'Members': Members})
    Values = []
    for Value in Api['builtin_classes']:
        Name = Value['name']
        Status = 'Supported' if Name in Kinds else 'Unsupported'
        if Name in ('RID', 'Callable', 'Signal'): Status = 'Restricted'
        if Name in ('StringName', 'Color'): Status = 'Partial'
        Values.append({'Name': Name, 'Status': Status, 'Representation': Types.get(Kinds.get(Name), 'No approved general conversion')})
    return {'Schema': 1, 'Scope': 'Approved Scene API against pinned metadata; legacy Roblox facades are separate',
        'Metadata': Api['header'], 'ApiSHA256': Policy['ApiSHA256'],
        'PolicySHA256': Catalog['PolicySHA256'],
        'Interpretation': 'Declared members; inheritance follows Base. Catalog specifies exact receivers, aliases, bounds and runtime permissions. Metadata existence is not host availability or qualification.',
        'Runtime': {'Domains': ['Server', 'Client', 'EditorPreview'],
            'Authority': 'Owned scene nodes and scoped resource handles; no global engine/OS capability',
            'AdditionalPreviewRestrictions': ['Audio playback', 'Gameplay bootstrap', 'Network, persistence, HTTP and filesystem services'],
            'HostAvailability': 'Checked by ClassDB at runtime, not inferred from metadata'},
        'Summary': {'MetadataClasses': len(Classes), 'ConstructibleClasses': sum(C['Constructible'] for C in Records),
            'SelectedProperties': len(Catalog['Properties']), 'SelectedMethods': len(Catalog['Methods']),
            'SelectedSignals': len(Catalog['Signals']), 'SelectedConstants': len(Catalog['Constants']),
            'DeclaredMembers': {K: sum(len(C.get(K, [])) for C in Classes.values()) for K in ('methods','properties','signals','enums','constants')}},
        'Variants': Values, 'Singletons': sorted(Singletons),
        'GlobalEnums': [E['name'] for E in Api['global_enums']], 'Classes': Records}


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
              ('Method', 'Methods', ['{' + ','.join([Quote(M['Class']), Quote(M['Name']), Quote(M['Native']), str(M['Mutates']).lower(), str(M['FirstArgument']), str(M['Arguments']), str(M['Required']), M['Return'], Quote(M['ReturnClass']),Quote(M['CountQuery']),str(M['IndexArgument']),str(M['AllowEnd']).lower(),str(M['AllowNegativeOne']).lower(),Quote(M['KeyQuery']),str(M['KeyArgument']),str(M['KeyAbsent']).lower(),str(M['CountArgument']),str(M['CountLimit'])]) + '}' for M in D['Methods']]),
              ('Signal', 'Signals', ['{' + ','.join([Quote(S['Class']), Quote(S['Name']), Quote(S['Native']), str(S['FirstArgument']), str(S['Arguments'])]) + '}' for S in D['Signals']]),
              ('Constant', 'Constants', ['{' + ','.join([Quote(C['Class']), Quote(C['Enum']), Quote(C['Name']), str(C['Value'])]) + '}' for C in D['Constants']]),
              ('Operation', 'ScopeOperations', ['{' + Quote(N) + ',' + Quote(S) + '}' for N, S in ScopeOperations])]
    for Cpp, Name, Lines in Tables:
        H += ['inline constexpr ' + Cpp + ' ' + Name + '[] = {', *['    ' + L + ',' for L in Lines], '};']
    H += ['inline constexpr const char* LoadTypes[] = {' + ','.join(map(Quote, D['LoadTypes'])) + '};', '}']
    H += ['#define GL_NATIVE_SCOPE_OPERATIONS(X) \\']
    for Index,(Name,_) in enumerate(ScopeOperations):
        Function='BuildMesh' if Name=='Mesh' else Name
        H.append('    X('+Name+','+Function+')'+(' \\' if Index+1<len(ScopeOperations) else ''))
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
                Previous=Values.get(P['Name'])
                if not Previous or Inherits(P['Class'],Previous['Class']): Values[P['Name']]=P
        return list(Values.values())

    T = ['-- Generated approved native definitions. Load as a definitions file, never require it.',
         '-- Policy SHA256: ' + PolicyHash, 'export type NativeVector2 = { X: number, Y: number }',
         'declare class NativeVector3', '    X: number', '    Y: number', '    Z: number',
         '    Lerp: (self: NativeVector3, Other: NativeVector3, Alpha: number) -> NativeVector3', 'end',
         'declare class NativeColor3', '    R: number', '    G: number', '    B: number', 'end',
         'declare Vector3: { new: (number, number, number) -> NativeVector3 }',
         'declare Vector2: { new: (number, number) -> NativeVector2 }',
         'declare Color3: { new: (number, number, number) -> NativeColor3 }',
         'export type NativeConnection = { Disconnect: (self: NativeConnection) -> (), Connected: boolean }']
    T += ['export type NativeVector2i = {X: number, Y: number}',
          'export type NativeVector3i = {X: number, Y: number, Z: number}',
          'export type NativeVector4 = {X: number, Y: number, Z: number, W: number}',
          'export type NativeVector4i = NativeVector4', 'export type NativeQuaternion = NativeVector4',
          'export type NativeColor4 = {R: number, G: number, B: number, A: number}',
          'export type NativeRect2 = {Position: NativeVector2, Size: NativeVector2}',
          'export type NativeRect2i = {Position: NativeVector2i, Size: NativeVector2i}',
          'export type NativeAABB = {Position: NativeVector3, Size: NativeVector3}',
          'export type NativePlane = {Normal: NativeVector3, D: number}',
          'export type NativeBasis = {X: NativeVector3, Y: NativeVector3, Z: NativeVector3}',
          'export type NativeTransform2D = {X: NativeVector2, Y: NativeVector2, Origin: NativeVector2}',
          'export type NativeTransform3D = {Basis: NativeBasis, Origin: NativeVector3}',
          'export type NativeVariant = nil | boolean | number | string | NativeVector3 | NativeColor3 | NativeVector2 | NativeVector4 | NativeColor4 | NativeRect2 | NativeAABB | NativePlane | NativeBasis | NativeTransform2D | NativeTransform3D | {NativeVariant} | {[string]: NativeVariant}']
    # Base classes precede their derived declarations.
    Ordered = sorted(D['Classes'], key=lambda C: (sum(Inherits(C['Name'], N) for N in ByName), C['Name']))
    for C in Ordered:
        N, Base = C['Name'], C['Base']
        T.append('declare class Native' + N + (' extends Native' + Base if Base else ''))
        if not C['Resource']:
            Inherited={P['Name']:Type(P) for P in Effective(Base)} if Base else {}
            for P in D['Properties']:
                if P['Class'] == N and P['Name'] != 'FullRect' and Inherited.get(P['Name'])!=Type(P):
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
        T += ['export type Native' + C['Name'] + 'Properties = {']
        T += ['    ' + P['Name'] + ': (' + Type(P) + ')?,' for P in Effective(C['Name']) if not P.get('ReadOnly')]
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
        if ByName[M['Class']]['Resource'] and M['Mutates']:
            Receivers=['MutableNative'+C['Name'] for C in D['Classes'] if C['Construct'] and C['Resource'] and Inherits(C['Name'],M['Class'])]
            Require(bool(Receivers),'No approved mutable receiver for '+M['Name'])
            C='('+' | '.join(Receivers)+')'
        else:
            C='Native'+M['Class']
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
    ValueNames={Native:Types[K] for Native,K in Kinds.items() if K not in ('Number','Integer','Boolean','Text','Colour','VariantValue')}
    ValueNames['Color']='NativeColor4'
    ValueType=' & '.join('((Type: "'+Name+'", Value: '+Type+') -> '+Type+')' for Name,Type in ValueNames.items())
    T += ['declare Scene: { new: (Parent: NativeNode) -> NativeSceneScope, Classes: () -> {string}, Value: '+ValueType+',',
          '    PolicySHA256: string, ApiSHA256: string, Describe: (Class: string) -> { [string]: any }?, Enums: ' + EnumType + ' }']
    D['Schema'] = 1
    D['PolicySHA256'] = PolicyHash
    D['ApiSHA256'] = Policy['ApiSHA256']
    D['ScopeOperations'] = [{'Name':N,'Signature':S} for N,S in ScopeOperations]
    return {'src/core/gl_native_registry.gen.h': '\n'.join(H) + '\n',
            'GodotLuau/Types/Native.d.luau': '\n'.join(T) + '\n',
            'bindings/NativeCatalog.json': json.dumps(D, indent=2) + '\n',
            'bindings/NativeCoverage.json': json.dumps(Coverage(Policy, Api, D), indent=2) + '\n'}


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
