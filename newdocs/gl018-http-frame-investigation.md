# GL-018 Windows frame-progress follow-up

Work in progress, 2026-11-02. Starting fix branch revision `74ca1d1` retains
the passing DataStore correction and the failed hosted Windows sanitizer profile
at runtime/test revision `bf3bb3f`. Main, GL-029, release publication and updater
distribution remain unchanged. No refactor is authorized or planned.

## Reproduced hosted failure

[Full-native run 41441973787](https://github.com/gmoddev/GodotLuau/actions/runs/41441973787)
fails Windows `http-enabled` frame progress (0.332602 seconds) and
`httpservice-utilities-A` public-API frame progress (0.334151 seconds). Linux's
complete profile passes. All 23 DataStore actors pass on both platforms. The
downloaded summaries and all 520 Linux/495 Windows indexed files rehash correctly.
No unexpected sanitizer finding is reported. A timing failure alone does not
identify a blocking network operation or a memory defect.

## Investigation

Use the retained original Windows Debug ASan DLL and corrected matching host on
DockerPC. A separate diagnostic copy instruments script setup and phase timings
without changing production source or acceptance bounds. The offline utility case
must be investigated alongside the network case: it executes JSON rejection,
URL encoding and 2,000 UUID generations without HTTP. Measure before changing
the transport, codec or fixture. Keep the 250 ms assertions and GL-004 limits.

Task driver: `C:/Sandbox/Codex/GL018ConflictFix/DiagnoseHttp.py`; diagnostic source
and outputs live under that same task-owned directory. No tool installation or
native rebuild is needed for this first attribution step. Temporary SSH connection
closures are retried without changing worker/service configuration.

## Attribution and bounded candidate

The diagnostic offline utility actor reproduces a 1.081181-second frame.
Phase timestamps put about 1.016 seconds in its uninterrupted 2,000-UUID loop;
the JSON rejection phases span about 17 ms. Script object setup itself is under
2 ms. A separate HTTP trace records a 1.110207-second first measured frame before
request-phase markers; its first Server and Client domains are created after
the nominal warmup. Repeated smaller trailer-phase gaps and a later timeout are
retained separately; no transport defect is inferred from that failed run.

The candidate changes two fixtures and no production source: bootstrap both
HTTP domains before its existing three-frame warmup; log startup gaps separately;
reset HttpService's peak at the existing measurement boundary; yield every 32
UUID samples. Public UUID helpers remain synchronous. The sample-size workload
no longer assumes 2,000 calls are one indivisible operation. Keep all 2,000 local
and 4,000 cross-process UUID shape/uniqueness checks, every original API assertion,
the 250 ms measured-frame bound, and runtime execution/admission limits unchanged.
Neither per-call performance improvement nor reduced startup cost is claimed.

Require both full HTTP groups on unchanged Windows Debug ASan products, plus a
bounded injected-stall negative control proving the measured-frame assertion
still rejects a real stall. Then rerun the complete hosted sanitizer profile.
This is a qualification workload/measurement correction, not a runtime refactor.

The first candidate now measures HTTP at 0.199815 seconds (below the unchanged
250 ms bound), but fails because the oversized trailer test assumes the byte
limit must beat the five-second request deadline. Under this instrumented host,
the request instead returns the exact bounded deadline failure with empty body
and zero status. Accept either documented bounded rejection, asserting completion
under 6.5 seconds and at least 4.8 seconds when the five-second deadline wins.
The separate streaming deadline assertions remain unchanged. The public denial
case also creates its Client domain after warmup; bootstrap that domain before
measurement, as for the native HTTP case. Original failed attempts are retained.

## Focused results and remaining gate

The second local candidate passes native HTTP enabled/denied and public API/
denial actors before each group stops at its lifecycle actor. Both lifecycle
failures report an indeterminate close-time DataStore SetAsync; the public actor
records a 0.29009-second shutdown gap. Those assertions and the 250 ms close-time
IPC budget remain unchanged. These are failed full-group attempts, not complete
qualification or proof that the hosted profile will fail in the same way.

A separate corrected utility actor completes its 2,000 samples and passes the
unchanged frame bound. A negative control injects one 350 ms synchronous delay
inside the measured utility loop: it exits 1 at the required public frame-progress
assertion with peak 0.441823 seconds, no script/sanitizer failure. Yielding between
batches therefore does not hide a stall inside a batch or individual operation.
The control source SHA-256 is
`dce253fc39a9483ed1c8aa2b4585b8c580be488e68cddcd2cbd197eea767a0e6`.

Full hosted Windows/Linux sanitizer qualification must pass before closure.
No production latency improvement, stock-host unload safety, Windows LSan,
device/editor coverage or guarantee for arbitrary synchronous script loops is
claimed. GL-018 remains OPEN; GL-029 work is not started. No deadline, shutdown
assertion, UUID sample count or runtime policy is weakened by this change.

## Published candidate and retained evidence

Candidate `46427d0e9ec10eb066202742255ef1881394f348` is pushed to
`fix/gl-018-increment-qualification`. Fresh jobs are started, not passing evidence:

- [Core 41505018403](https://github.com/gmoddev/GodotLuau/actions/runs/41505018403).
- [Native 41505018353](https://github.com/gmoddev/GodotLuau/actions/runs/41505018353).
- [Full-native sanitizers 41505018104](https://github.com/gmoddev/GodotLuau/actions/runs/41505018104).

The focused utility peak is **0.084417 seconds**; the injected-stall control peak
is **0.441823 seconds**. Raw diagnostic, positive, negative and failed-group logs
are retained in `C:/Sandbox/Codex/GL018ConflictFix/http-evidence-v1.zip` on DockerPC
and `C:/Users/aiden/.codex/artifacts/godotluau/gl018-conflicts/http-evidence-v1.zip`
on the controller. Archive SHA-256:
`6c2ca1d33571f9ca26003bb16dd229316a7e47dfb742f7dea398af25b24a1683`.
All 64 indexed files rehash correctly after download. The two executed fixture
inputs match this commit after explicit LF normalization. `review.json` retains
the positive/control records, and `hashes.json` indexes original bytes. No
unexpected candidate ASan report is present. This archive is focused evidence,
not a complete sanitizer profile or an independently rebuilt product.

No production files, workflows, dependency pins or updater code differ from the
starting revision. Main and GL-029 branches remain untouched; release publication
and updater distribution remain disabled. There is no native rebuild or refactor.
