"""Reuse the bounded native runner for a captured-module cached-require loop."""
import argparse
import ctypes
import json
import os
from pathlib import Path
import time
from RunQualification import Prepare, Start, Check


def Main():
    Parser = argparse.ArgumentParser()
    Parser.add_argument("--godot", type=Path, required=True)
    Parser.add_argument("--extension", type=Path, required=True)
    Parser.add_argument("--baseline", type=Path)
    Parser.add_argument("--output", type=Path, required=True)
    Parser.add_argument("--calls", type=int, default=1000000)
    Parser.add_argument("--repeat", type=int, default=7)
    Args = Parser.parse_args()
    Output = Args.output.resolve()
    if os.name == "nt":
        ctypes.windll.kernel32.SetErrorMode(0x8003)
    Results = []
    for Trial in range(Args.repeat):
        Modes = [("Candidate", Args.extension)]
        if Args.baseline:
            Modes.insert(0, ("Before", Args.baseline))
        if Trial % 2:
            Modes.reverse()
        for Mode, Extension in Modes:
            Prepare(Output, Extension.resolve())
            Metrics = Output / "require-metrics.json"
            Metrics.unlink(missing_ok=True)
            Label = f"require-{Mode}-{Trial}"
            Process = Start(Args.godot.resolve(), Output, "RequireBenchmark.gd", Label,
                            [str(Args.calls), str(Metrics)], dict(os.environ, GODOT_SILENCE_ROOT_WARNING="1"))
            Check(Process, time.monotonic() + 90, Output, Label, "[Runtime:RequireBenchmark] PASS")
            Results.append(dict(json.loads(Metrics.read_text()), Mode=Mode, Trial=Trial))
            (Output / "results.json").write_text(json.dumps(Results, indent=2))
    print(f"[Runtime:RequireBenchmark] PASS {len(Results)} results")


if __name__ == "__main__":
    Main()
