# GL-018 bounded-conflict fixture correction

Work in progress, 2026-11-02. Branch `fix/gl-018-increment-qualification` starts
at GL-018 tip `0e61db4a418c606deff50fad27f9831dc6204981`, independently of the
unqualified GL-029 integration. No production source or retry policy changes.

## Diagnosis and smallest correction

ADR-005 permits `IncrementAsync` to exhaust eight optimistic compare attempts
without committing. The existing two-process fixture instead assumes all forty
calls must succeed. Retained Windows diagnostic evidence shows a writer reading
12 through 19 on consecutive attempts while the other writer commits, then
raising the documented conflict error. This does not demonstrate lost updates,
memory corruption or an incorrect successful acknowledgment.

The fixture now invokes exactly twenty calls per writer without caller retries.
Each call must return a valid committed integer or the exact conflict-exhaustion
error. Timeouts, lock contention, indeterminate outcomes and all other failures
remain failures. Each actor records receipts and conflict count. The controller
requires forty accounted outcomes, unique contiguous receipts from one through
the acknowledged total, some committed progress and a fresh independent read
equal to that total. Thus silent loss, duplicate acknowledgments and unacknowledged
mutation still fail. Zero successes for an individual writer is permitted by
the existing non-fair contract; zero aggregate progress is rejected.

This deliberately corrects the qualification requirement from guaranteed fair
completion to exact accounting under bounded conflicts. It does not add a retry
loop, increase the eight-attempt limit, change backoff, suppress errors generally,
or promise writer fairness. The existing deterministic forced-conflict fixture
still requires exactly eight transform attempts and unchanged noncommitted
candidates. The independent native forty-increment probe remains unchanged.

## Acceptance and ongoing verification

Require the complete actual Windows ASan DataStore group, including recovery,
concurrency, legacy data, BindToClose, cancellation and native fault/kill controls.
Run the full matching Windows sanitizer profile afterward; GL-018 stays open
until its required complete profile passes. Preserve failed attempts, original
evidence and all existing sanitizer detection/assertion gates. Releases/updater
remain disabled and main is not modified. No refactor is included.

### Focused Windows result

The complete production Windows ASan DataStore suite passes **23 actors**, plus
the unchanged native four-fault/four-kill/forty-increment controls. Both writer
receipt files contain twenty successful acknowledgments in this run, with zero
exhausted calls; their union is exactly 1 through 40. The basic actor also passes
the deterministic eight-attempt forced-conflict assertion. These outcomes do not
claim natural contention must exhaust on every run.

Command on DockerPC: repository `RunQualification.py --datastore --timeout 60`,
with the matching corrected host and original production Debug ASan DLL. Captured
runner: `C:/Sandbox/Codex/GL018ConflictFix/Qualify.py`; outputs:
`C:/Sandbox/Codex/GL018ConflictFix/datastore`, `qualification.log`, `identity.json`.
No new tool installation, native compilation, retry-policy or host modification.

| Retained binary | SHA-256 |
| --- | --- |
| Corrected Windows host | `96a64e425ae1aac600014e6fbe8489b3178c8d09b210c47fd4a03f18edcafdb0` |
| Original production Debug ASan DLL | `82aded0415266a64dc93918e0a586e7edef8619c7c36742d6b47110ee1116f34` |
| Companion | `d5df19fa8bcc0d6c17a2004e9ef7bdaedb783bb230854c360c7994f835838460` |

These match the retained GL-018 production profile. Full-profile rerun remains
required; the focused suite alone does not close GL-018.

### Retention and hosted rerun

Fix commit: `bf3bb3fe6322204d22f7842c30bc4432fd58fcd2`.
The focused archive is retained at
`C:/Users/aiden/.codex/artifacts/godotluau/gl018-conflicts/focused-evidence.zip`
and on DockerPC under `C:/Sandbox/Codex/GL018ConflictFix`. SHA-256:
`9ed67fe4aa12a6348c390e741cf8373ba2ada53faed82318c5fd92c0eb3da7db`.
All 87 indexed entries were independently rehashed after download. The results
contain all 23 successful actors and native controls, with no power-loss claim.

Fresh exact-fix hosted jobs are started, not reported passing:

- [Core 41441971998](https://github.com/gmoddev/GodotLuau/actions/runs/41441971998).
- [Native 41441972046](https://github.com/gmoddev/GodotLuau/actions/runs/41441972046).
- [Full-native sanitizers 41441973787](https://github.com/gmoddev/GodotLuau/actions/runs/41441973787).

The sanitizer run is manually dispatched on the fix branch; its Windows/Linux
matching instrumented hosts are building at this observation. No release
workflow is dispatched. DockerPC C: has only about 3 GiB free after the focused
run, so a further full local matrix is not started there. No caches are removed
and no unrelated work is stopped. Local task test processes completed.
