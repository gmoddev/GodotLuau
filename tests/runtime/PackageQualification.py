"""Create an explicitly supplied, hash-manifested test package without the updater."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import zipfile
from SourceFingerprint import GetFingerprint


def Main():
    Parser = argparse.ArgumentParser()
    Parser.add_argument("--source", type=Path, default=Path(__file__).resolve().parents[2])
    Parser.add_argument("--revision", required=True)
    Parser.add_argument("--windows-debug", type=Path, required=True)
    Parser.add_argument("--windows-release", type=Path, required=True)
    Parser.add_argument("--linux-debug", type=Path, required=True)
    Parser.add_argument("--linux-release", type=Path, required=True)
    Parser.add_argument("--output", type=Path, required=True)
    Args = Parser.parse_args()
    Source = Args.source.resolve()
    Actual = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=Source, text=True).strip()
    if Actual != Args.revision:
        raise RuntimeError("Package source revision does not match HEAD")
    Dirty = subprocess.check_output(["git", "status", "--porcelain", "--", "src", "SConstruct", "godot-cpp", "luau"], cwd=Source, text=True)
    if Dirty:
        raise RuntimeError("Production source/dependencies have uncommitted changes")
    Files = {Name: Source / Name for Name in ("godot_luau.gdextension", "godot_luau.gdextension.uid", "LICENSE", "Version")}
    for File in (Source / "GodotLuau").rglob("*"):
        if File.is_file() and "bin" not in File.relative_to(Source / "GodotLuau").parts:
            Files[File.relative_to(Source).as_posix()] = File
    for Platform in ("windows", "linux"):
        for Config in ("debug", "release"):
            Library = getattr(Args, Platform + "_" + Config).resolve()
            Suffix = ".dll" if Platform == "windows" else ".so"
            Files[f"GodotLuau/bin/godot_luau.{Platform}.template_{Config}.x86_64{Suffix}"] = Library
    for Required in re.findall(r'"res://([^"]+)"', (Source / "godot_luau.gdextension").read_text()):
        if Required not in Files:
            raise RuntimeError("Descriptor resource missing from package: " + Required)
    Manifest = {"Kind": "Local qualification package; not a published release", "SourceRevision": Actual,
        "Dependencies": {"godot-cpp": "d5cc777a89d899665fb61f1650ef0dc0cf6488c4", "luau": "9e2984fd0334414a2ef62ceede0c06dab7574d55"},
        "NativeSourceFingerprint": GetFingerprint(Source), "UpdaterIncluded": False, "Files": {}}
    for Name, Expected in Manifest["Dependencies"].items():
        Dependency = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=Source / Name, text=True).strip()
        if Dependency != Expected:
            raise RuntimeError("Unexpected dependency revision: " + Name)
    Args.output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(Args.output, "w", zipfile.ZIP_DEFLATED) as Archive:
        for Name, File in sorted(Files.items()):
            Data = File.read_bytes()
            Manifest["Files"][Name] = {"SHA256": hashlib.sha256(Data).hexdigest(), "Bytes": len(Data)}
            Archive.writestr(Name, Data)
        Archive.writestr("qualification-manifest.json", json.dumps(Manifest, indent=2))
        Archive.writestr("QUALIFICATION.txt", "LOCAL TEST PACKAGE ONLY\nNo updater is included or enabled. No GitHub Release was published.\nSee newdocs/shared-domains-validation.md at source revision " + Actual + ".\nInherited assets retain their existing provenance limitations (GL-015).\n")
    with zipfile.ZipFile(Args.output) as Archive:
        if Archive.testzip() is not None:
            raise RuntimeError("Package CRC verification failed")
        for Name, Entry in Manifest["Files"].items():
            if hashlib.sha256(Archive.read(Name)).hexdigest() != Entry["SHA256"]:
                raise RuntimeError("Package hash mismatch: " + Name)
    print(json.dumps({"Package": str(Args.output.resolve()), "SHA256": hashlib.sha256(Args.output.read_bytes()).hexdigest(), "Files": len(Files)}, indent=2))


if __name__ == "__main__":
    Main()
