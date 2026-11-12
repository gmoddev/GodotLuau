"""Retain complete CTest output and require all production-core cases."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
from CheckCoreCI import CheckDiscovery, CheckReport
from SourceFingerprint import GetFingerprint


def Main():
    Parser = argparse.ArgumentParser(description=__doc__)
    Parser.add_argument('--build', type=Path, required=True)
    Parser.add_argument('--output', type=Path, required=True)
    Parser.add_argument('--ctest', default='ctest')
    Parser.add_argument('--config', default='')
    Args = Parser.parse_args()
    Args.output.mkdir(parents=True, exist_ok=False)
    Prefix = [Args.ctest, '--test-dir', str(Args.build.resolve())]
    if Args.config: Prefix += ['-C', Args.config]
    Flags = {'creationflags': subprocess.CREATE_NO_WINDOW} if os.name == 'nt' else {}
    Discovery = Args.output/'discovery.json'
    with Discovery.open('w') as Log:
        subprocess.run([*Prefix, '--show-only=json-v1'], stdout=Log, check=True, timeout=30, **Flags)
    CheckDiscovery(Discovery)
    Report = (Args.output/'core-results.xml').resolve()
    Command = [*Prefix, '-R', '^ExecutionDomains$', '--no-tests=error', '--timeout', '30',
               '--output-on-failure', '--verbose', '--test-output-size-passed', '65536',
               '--test-output-size-failed', '65536', '--output-junit', str(Report)]
    with (Args.output/'ctest.log').open('w') as Log:
        subprocess.run(Command, stdout=Log, stderr=subprocess.STDOUT, check=True, timeout=120, **Flags)
    CheckReport(Report)
    Evidence = {'Command': Command, 'NativeSource': GetFingerprint(Path(__file__).resolve().parents[2]),
                'Cases': 87, 'Result': 'PASS', 'ASAN_OPTIONS': os.environ.get('ASAN_OPTIONS'),
                'Files': {File.name: hashlib.sha256(File.read_bytes()).hexdigest()
                          for File in [Discovery, Report, Args.output/'ctest.log']}}
    (Args.output/'verified.json').write_text(json.dumps(Evidence, indent=2))
    print('[Runtime:CoreQualification] PASS 87 distinct cases; complete report retained', flush=True)


if __name__ == '__main__': Main()
