"""Export an already qualified, admitted host for bounded worker benchmarks."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
from RemoteHostIdentity import VerifyRemoteHost


def Main():
    Parser = argparse.ArgumentParser(description=__doc__)
    Parser.add_argument('--manifest', type=Path, required=True)
    Parser.add_argument('--output', type=Path, required=True)
    Args = Parser.parse_args()
    Record = json.loads(Args.manifest.read_text())
    Executable = Path(Record['Executable'])
    VerifyRemoteHost(Record, Executable)
    if Record.get('Configuration') != 'Release': raise ValueError('Benchmark export requires the admitted uninstrumented Release profile')
    Args.output.mkdir(parents=True, exist_ok=False)
    Files = [Executable, Args.manifest, *[Executable.parent / Name for Name in Record['RuntimeDLLs']],
             Args.manifest.parent / 'LICENSE.txt', Args.manifest.parent / 'COPYRIGHT.txt']
    Hashes = {}
    for File in Files:
        Digest = hashlib.sha256(File.read_bytes()).hexdigest()
        if File.name in Record['RuntimeDLLs'] and Digest != Record['RuntimeDLLs'][File.name]: raise ValueError('Host runtime hash mismatch')
        if File.name in Hashes: raise ValueError('Duplicate export member')
        shutil.copy2(File, Args.output / File.name); Hashes[File.name] = Digest
    (Args.output / 'host-export.json').write_text(json.dumps({'Scope': 'Qualification-only admitted Release host; no updater or production publication', 'ManifestSHA256': hashlib.sha256(Args.manifest.read_bytes()).hexdigest(), 'Files': Hashes}, indent=2))
    print('[Network:HostExport] Verified qualification-only Release host')


if __name__ == '__main__': Main()
