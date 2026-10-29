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
        'animation': [f'animation-{Mode}-{Role}' for Mode in ['Local', 'Listen', 'Dedicated', 'Editor'] for Role in (['server'] if Mode == 'Local' else ['server', 'client1', 'client2'])]
    }
    Groups = {}
    for Name, Labels in Expected.items():
        Results = json.loads((Args.output / Name / 'results.json').read_text())
        if [Result['Label'] for Result in Results] != Labels or any(Result['Exit'] != 0 for Result in Results):
            raise ValueError('Missing or failed native fixture results: ' + Name)
        Groups[Name] = Results
    Lifecycle = (Args.output / 'regression' / 'integration-0.stdout.log').read_text(errors='replace')
    for Marker in ['[Runtime:ChildRelay] PASS', '[Runtime:ChildRelay] Independent domain destruction and replacement checked', '[Runtime:ChildRelay] Scene generations PASS']:
        if Marker not in Lifecycle:
            raise ValueError('GL-022 native regression was not exercised: ' + Marker)
    Evidence = {
        'Revision': Args.revision, 'NativeSource': GetFingerprint(Path(__file__).resolve().parents[2]),
        'ExtensionSHA256': hashlib.sha256(Args.extension.read_bytes()).hexdigest(),
        'Godot': json.loads(Args.godot_evidence.read_text()), 'Groups': Groups,
        'HarnessHashes': {File.name: hashlib.sha256(File.read_bytes().replace(b'\r\n', b'\n')).hexdigest() for File in sorted(Path(__file__).parent.iterdir()) if File.suffix in ['.gd', '.py'] or File.name in ['CMakeLists.txt', 'GodotDistribution.json']},
        'Processes': sum(len(Results) for Results in Groups.values()),
        'LogHashes': {str(File.relative_to(Args.output)): hashlib.sha256(File.read_bytes()).hexdigest() for File in sorted(Args.output.rglob('*.log'))},
        'Scope': 'Debug native fixtures; functional animation only; no sanitizer configuration or GL-020 adversarial qualification'
    }
    (Args.output / 'summary.json').write_text(json.dumps(Evidence, indent=2))
    print('[Runtime:NativeCI] PASS 28 required process results')


if __name__ == '__main__':
    Main()
