"""Summarize raw phase records; TIME_PROCESS samples are intentionally excluded."""
import json
from pathlib import Path
import statistics
import sys


def Main():
    Records = json.loads(Path(sys.argv[1]).read_text())
    Metrics = ("StartupMs", "ColdMs", "Hot100Ms", "Coroutine32Ms", "FrameMedianMs",
               "FrameP95Ms", "DestroyMs", "ShutdownMs")
    for Count in sorted({Row["Count"] for Row in Records}):
        for Mode in ("Baseline", "Shared"):
            Rows = [Row for Row in Records if Row["Count"] == Count and Row["Mode"] == Mode]
            Summary = {}
            for Metric in Metrics:
                Values = [Row[Metric] for Row in Rows if Metric in Row]
                Summary[Metric] = {"Median": statistics.median(Values), "Min": min(Values), "Max": max(Values)}
            Growth = []
            for Trial in sorted({Row["Trial"] for Row in Rows}):
                Phases = {Row["Phase"]: Row for Row in Rows if Row["Trial"] == Trial}
                if Phases["Startup"]["RssBytes"] is not None:
                    Growth.append((Phases["Startup"]["RssBytes"] - Phases["Before"]["RssBytes"]) / 1048576)
            if Growth:
                Summary["RssGrowthMiB"] = {"Median": statistics.median(Growth), "Min": min(Growth), "Max": max(Growth)}
            print(json.dumps({"Count": Count, "Mode": Mode, "Metrics": Summary}))


if __name__ == "__main__":
    Main()
