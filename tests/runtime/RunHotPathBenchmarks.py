"""Counterbalance bounded production-core microbenchmarks without frame pacing."""
import argparse
import ctypes
import json
import os
from pathlib import Path
import subprocess


def Main():
    Parser = argparse.ArgumentParser()
    Parser.add_argument("--baseline", type=Path, required=True)
    Parser.add_argument("--candidate", type=Path, required=True)
    Parser.add_argument("--output", type=Path, required=True)
    Parser.add_argument("--counts", type=int, nargs="+", default=[10, 100, 1000])
    Parser.add_argument("--repeat", type=int, default=11)
    Args = Parser.parse_args()
    if os.name == "nt":
        ctypes.windll.kernel32.SetErrorMode(0x8003)
    Args.output.parent.mkdir(parents=True, exist_ok=True)
    with Args.output.open("w") as Output:
        for Count in Args.counts:
            for Trial in range(Args.repeat):
                Modes = [("pre", Args.baseline), ("post", Args.candidate)]
                if Trial % 2:
                    Modes.reverse()
                for Mode, Binary in Modes:
                    Flags = {"creationflags": subprocess.CREATE_NO_WINDOW} if os.name == "nt" else {}
                    Run = subprocess.run([str(Binary.resolve()), str(Count)], capture_output=True,
                                         text=True, timeout=30, check=True, **Flags)
                    for Line in Run.stdout.splitlines():
                        Row = dict(json.loads(Line), Count=Count, Trial=Trial, Mode=Mode)
                        Output.write(json.dumps(Row) + "\n")
    print("[Runtime:Benchmark] Core hot-path comparison PASS")


if __name__ == "__main__":
    Main()
