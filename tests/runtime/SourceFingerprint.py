"""Fingerprint native build inputs with compiler-equivalent normalized newlines."""
import hashlib
import json
from pathlib import Path
import sys


def GetFingerprint(Source):
    Files = [Source / "SConstruct"]
    Files += [File for File in (Source / "src").rglob("*") if File.suffix in (".h", ".cpp")]
    # GL-051's generated API and its checked policy are distribution/build inputs.
    # Historical baseline trees without that feature retain their old identity.
    Files += [Source / Name for Name in ("bindings/NativePolicy.json", "bindings/NativeCatalog.json",
              "tools/GenerateNativeBindings.py", "GodotLuau/Types/Native.d.luau") if (Source / Name).is_file()]
    Digest = hashlib.sha256()
    for File in sorted(Files, key=lambda Item: Item.relative_to(Source).as_posix()):
        Digest.update(File.relative_to(Source).as_posix().encode() + b"\0")
        Digest.update(File.read_bytes().replace(b"\r\n", b"\n") + b"\0")
    return {"SHA256": Digest.hexdigest(), "Files": len(Files), "Newlines": "LF normalized"}


if __name__ == "__main__":
    print(json.dumps(GetFingerprint(Path(sys.argv[1]).resolve())))
