"""Join approved metadata with optional successful native invocation receipts.

Invocation is evidence of use, not an assertion that its result was correct.
Uninstrumented effects and enum reads are deliberately not inferred from source.
"""
import argparse
import hashlib
import json
from pathlib import Path

Root = Path(__file__).resolve().parents[1]


def Report(Catalog, Coverage, Logs):
    for Key in ('PolicySHA256', 'ApiSHA256'):
        if Catalog[Key] != Coverage[Key]:
            raise ValueError('Inventory identity mismatch: ' + Key)
    Allowed = {
        'Construct': {C['Name'] + '.new' for C in Catalog['Classes'] if C['Construct']},
        **{Category: {C['Class'] + '.' + C['Name'] for C in Catalog[Group]}
           for Category, Group in [('Call', 'Methods'), ('Read', 'Properties'),
                                   ('Write', 'Properties'), ('Signal', 'Signals')]},
        'Value': None,
    }
    Counts, Receipts = {}, []
    for Log in sorted(set(Logs)):
        Found = 0
        for Line in Log.read_text(encoding='utf-8', errors='replace').splitlines():
            Marker = '[Bindings:Coverage] '
            if Marker not in Line:
                continue
            Trace = json.loads(Line.split(Marker, 1)[1])
            if Trace['Schema'] != 1 or Trace['Truncated']:
                raise ValueError('Incomplete/unsupported invocation receipt: ' + str(Log))
            if any(Trace[K] != Catalog[K] for K in ('PolicySHA256', 'ApiSHA256')):
                raise ValueError('Invocation identity mismatch: ' + str(Log))
            for Key, Count in Trace['Counts'].items():
                Domain, Category, Member = Key.split(':', 2)
                if (Domain not in Coverage['Runtime']['Domains'] or Category not in Allowed or
                        (Allowed[Category] is not None and Member not in Allowed[Category]) or
                        type(Count) is not int or Count <= 0):
                    raise ValueError('Unknown invocation: ' + Key)
                Counts[Key] = Counts.get(Key, 0) + Count
            Found += 1
        if Found:
            Receipts.append({'Path': str(Log), 'SHA256': hashlib.sha256(Log.read_bytes()).hexdigest(),
                             'Processes': Found})
    Domains = {}
    for Domain in Coverage['Runtime']['Domains']:
        Domains[Domain] = {Category: sorted(Key.split(':', 2)[2] for Key in Counts
                                          if Key.startswith(Domain + ':' + Category + ':'))
                           for Category in Allowed}
    return {
        'Schema': 1, 'ApiSHA256': Catalog['ApiSHA256'], 'PolicySHA256': Catalog['PolicySHA256'],
        'DenominatorsAndSelections': Coverage['Summary'],
        'GeneratedHandles': len(Catalog['Classes']),
        'GeneratedMemberDeclarations': {K: len(Catalog[K]) for K in ('Properties', 'Methods', 'Signals', 'Constants')},
        'Authorization': Coverage['Runtime'],
        'InvocationsByDomain': Domains, 'Counts': Counts, 'Receipts': Receipts,
        'Interpretation': 'Successful native invocation only; fixture assertions and application outcomes remain separate qualification evidence.',
        'Unmeasured': ['Enum/constant reads', 'Scope operations', 'Fixture assertion coverage',
                       'Application correctness', 'Unavailable host features'],
    }


def Main():
    Parser = argparse.ArgumentParser(description=__doc__)
    Parser.add_argument('--catalog', type=Path, default=Root/'bindings/NativeCatalog.json')
    Parser.add_argument('--inventory', type=Path, default=Root/'bindings/NativeCoverage.json')
    Parser.add_argument('--logs', type=Path)
    Parser.add_argument('--output', type=Path, required=True)
    Args = Parser.parse_args()
    Result = Report(json.loads(Args.catalog.read_text()), json.loads(Args.inventory.read_text()),
                    Args.logs.rglob('*.log') if Args.logs else [])
    Args.output.parent.mkdir(parents=True, exist_ok=True)
    Args.output.write_text(json.dumps(Result, indent=2) + '\n', encoding='utf-8')
    print('[Bindings:Coverage] Recorded', len(Result['Receipts']), 'logs;', len(Result['Counts']), 'domain/member pairs')


if __name__ == '__main__':
    Main()
