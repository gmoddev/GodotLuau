"""Verify the admitted GL-029 host contract, optionally its local executable."""
import hashlib
import json
from pathlib import Path


def VerifyRemoteHost(Record, Executable=None):
    Runtime = Path(__file__).parent
    Policy = json.loads((Runtime/'SanitizerHosts.json').read_text())
    Admission = json.loads((Runtime/'RemoteAdmissionHost.json').read_text())
    Digest = lambda File: hashlib.sha256(File.read_bytes().replace(b'\r\n', b'\n')).hexdigest()
    if Record.get('Exit') != 0 or Record.get('EngineRevision') != Policy['EngineRevision'] or Record.get('ArchiveSHA256') != Policy['ArchiveSHA256'] or Record.get('SCons') != Policy['SCons']:
        raise ValueError('GL-029 host source/build identity mismatch')
    if Record.get('RemoteAdmission') != Admission or Digest(Runtime/Admission['File']) != Admission['SHA256LF']:
        raise ValueError('GL-029 native admission patch identity mismatch')
    if Record.get('QualificationPatch') != Policy['QualificationPatch'] or Digest(Runtime/Policy['QualificationPatch']['File']) != Policy['QualificationPatch']['SHA256LF']:
        raise ValueError('GL-018 admitted host correction mismatch')
    if Record.get('QualificationPatchSourceSHA256LF') != Policy['QualificationPatch']['PatchedSHA256']:
        raise ValueError('GL-018 admitted host output mismatch')
    if not isinstance(Record.get('ExecutableSHA256'), str) or len(Record['ExecutableSHA256']) != 64:
        raise ValueError('GL-029 host executable identity missing')
    if Executable is not None and hashlib.sha256(Path(Executable).read_bytes()).hexdigest() != Record['ExecutableSHA256']:
        raise ValueError('GL-029 host executable hash mismatch')
    return Record
