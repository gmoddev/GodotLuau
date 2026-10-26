# GodotLuau fork documentation

Public fork: [gmoddev/GodotLuau](https://github.com/gmoddev/GodotLuau).
Upstream: [Pimpoli/GodotLuau](https://github.com/Pimpoli/GodotLuau).

The initial source baseline is
[`7044a11c1bcc2eac2a91155e829a5821d92ab66e`](https://github.com/Pimpoli/GodotLuau/tree/7044a11c1bcc2eac2a91155e829a5821d92ab66e),
whose `Version` begins `v1.16.12`. Upstream `main` resolved to that same commit
when checked on 2026-10-26. The initial fork changes documentation only.

## Start here

| Document | Purpose |
| --- | --- |
| [AI policy](../AGENTS.md) | Contribution workflow, naming, evidence, and non-disruptive tooling |
| [Current architecture](current-architecture.md) | Source-verified baseline and subsystem entry points |
| [Invariants](invariants.md) | Required properties for new/touched behavior, with known baseline gaps |
| [Issue ledger](issues.md) | Stable IDs, evidence, priorities, proof gaps, and closure criteria |
| [Review validation](review-validation.md) | Claim-by-claim assessment of the supplied architecture review |

## Documentation authority

These categories have different purposes; do not silently substitute one for
another:

1. **Executed tests and enforced checks:** evidence for the specific behavior,
   revision, platform, and configuration they exercise, not universal proof.
2. **Current architecture:** descriptions verified against the recorded source
   revision and, where available, runtime evidence. Update affected sections
   together with implementation changes.
3. **Accepted decisions:** intended constraints and tradeoffs, including migration
   status. Add a decision record when a task selects a foundational change.
4. **Versioned API/protocol contracts:** intended external representations and
   compatibility obligations. Disagreement with code is a defect to resolve.
5. **Source:** implementation evidence. An accidental dependency is not an
   architectural decision merely because it exists in code.
6. **Proposals and roadmaps:** future options, not delivered features.
7. **Historical reviews:** evidence about their stated revision and methods.

The supplied review is historical input. Its recommendations do not approve a
shared-VM rewrite, SQLite, a separate network service, or an engine-neutral
Instance system. Those choices require their own design and compatibility work.

## Evidence and issue maintenance

Record the source revision, exact paths/lines, scope, result, counterevidence,
missing acceptance facts, and next verification step. Use immutable source links
for historical evidence; use relative links for maintained documents.

`Verified` means the stated implementation fact is supported by source.
`Needs review` means a material boundary, runtime consequence, or provenance fact
is missing. `Design decision` is a tradeoff to evaluate. None means an exploit or
crash was reproduced. Priorities indicate engineering order, not CVSS scores.

Keep resolved issues with their fix and evidence instead of deleting history.
Recheck affected source anchors after refactors. Keep target invariants distinct
from implemented guarantees.

## Existing AI material

The baseline contains no tracked `AGENTS.md`, `agent.md`, `CLAUDE.md`,
`AICONTEXT.md`, contribution policy, or Copilot instructions. Its README
"Autocomplete and AI" section, `models/`, `corpus/`, and
`tools/entrenar_modelo.py` describe the optional LuauIA autocomplete feature,
not contribution rules. The new root policy governs AI-assisted repository work;
it does not change the editor's autocomplete implementation or data handling.
