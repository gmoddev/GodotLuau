# GodotLuau fork documentation

Public fork: [gmoddev/GodotLuau](https://github.com/gmoddev/GodotLuau).
Upstream: [Pimpoli/GodotLuau](https://github.com/Pimpoli/GodotLuau).

The initial source baseline is
[`7044a11c1bcc2eac2a91155e829a5821d92ab66e`](https://github.com/Pimpoli/GodotLuau/tree/7044a11c1bcc2eac2a91155e829a5821d92ab66e),
whose `Version` begins `v1.16.12`. Upstream `main` resolved to that same commit
when checked on 2026-10-26. The initial fork commit was documentation only;
`main` now contains the source-qualified Server/Client VM migration, GL-019
hot-path optimizations and qualified GL-006/008 state/removal/chat authority
corrections, and is the canonical development baseline.
GL-020's functionally qualified animation/session lifecycle is now integrated by
normal merge `6b140427e8ab39d97e12ee693f7cbda72abc7bba`, preserving source
branch `fix/gl-020-animation-lifecycle` at `8e21d18a5504e0d703efbcf2a71a53d56314058e`.
Its animation security qualification remains pending; see the
[integration record](animation-lifecycle-validation.md#main-integration-2026-10-27).
The preceding security runtime
merge is `2e69d8ac703d3f968e42054871511111ab8471be`, identical to qualified source
`462969bd967bd26fcbeccdca1bd6ae60335347f4`. The retained historical branch is
`security/gl-006-008-rpc-authority`; see the
[security integration record](network-authority-validation.md#main-integration-2026-10-27).
The preceding optimized runtime merge is `6badbae4b467a5544ffd027a1c7d7bd505cd0d46`.
`perf/gl-019-hot-paths` is retained at
`ad200aa468be56edf4812bb3a03daeb31d5bbdd8`; `runtime/shared-domains` remains at
`9423fed4051bec2fba798d9a49eaec7dea6cca3b` as the earlier migration reference.
See the [current integration record](shared-domains-validation.md#gl-019-main-integration-2026-10-26).

## Start here

GL-013's first native Vector3/Color3 implementation extraction is integrated by
normal merge `bdd57fd3097537bb1cf0f8a0b7c08ae7e312d0d7`, preserving both qualified
source commits. See the [integration record](shared-domains-validation.md#first-extraction-main-integration-2026-10-28).
GL-013 stays open for incremental modularization; no broader lifetime or build-speed
guarantee is inferred.

GL-012 release retention is integrated with publication disabled by explicit
workflow admission and read-only permissions. See the
[integration record](release-retention.md#main-integration-2026-10-27).
GL-016 updater isolation is also integrated; fresh Windows/Linux headless editor
checks are recorded in its [integration record](fork-updater-isolation.md#main-integration-2026-10-27).
GL-011A core CI is integrated by normal merge `f0199004d56485ec7a9de14d5454d1907822ba11`.
Both fresh hosted Debug jobs pass 39 cases; see the
[CI milestone](shared-domains-validation.md#gl-011-independent-core-ci-2026-10-27).
GL-011 remains open for sanitizer/release-enforcement and broader coverage gaps.
GL-011B native CI is integrated by normal merge `9029d01a24d904deaa1ecd7a9c30fc483e13757f`.
Its qualified source passes actual hosted Debug
adapter builds and 28 native actors on each platform, including existing network
and functional animation regressions. See the
[native CI milestone](shared-domains-validation.md#gl-011b-native-ci-2026-10-27).
Source-identical hosted qualification is reused; see the bounded
[main integration record](shared-domains-validation.md#gl-011b-main-integration).

| Document | Purpose |
| --- | --- |
| [AI policy](../AGENTS.md) | Contribution workflow, naming, evidence, and non-disruptive tooling |
| [Current architecture](current-architecture.md) | Implemented ownership and subsystem entry points |
| [Invariants](invariants.md) | Required properties for new/touched behavior, with known baseline gaps |
| [Issue ledger](issues.md) | Stable IDs, evidence, priorities, proof gaps, and closure criteria |
| [Review validation](review-validation.md) | Claim-by-claim assessment of the supplied architecture review |
| [Shared-domain decision](adr-001-shared-execution-domains.md) | Accepted GL-014 design and compatibility contract; implementation status is separate |
| [Shared-domain work log](shared-domains-work-log.md) | Baseline, ongoing implementation checkpoints, and executed qualification evidence |
| [Shared-domain validation](shared-domains-validation.md) | Reproduction commands, acceptance coverage and remaining gaps |
| [Network authority validation](network-authority-validation.md) | Integrated GL-006/008 trust boundaries, transport regressions, compatibility and remaining gaps |
| [Animation lifecycle validation](animation-lifecycle-validation.md) | GL-020 development-branch execution/session rules, functional regressions and outstanding security qualification |
| [Release retention](release-retention.md) | Integrated GL-012 retention, disabled publication and integration checks |
| [Fork updater isolation](fork-updater-isolation.md) | GL-016 fail-closed policy, manual recovery and headless editor verification |

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
SQLite, a separate network service, or an engine-neutral Instance system.
The shared-domain migration has its own explicit owner request and ADR-001;
acceptance of the original review alone did not authorize it.

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
