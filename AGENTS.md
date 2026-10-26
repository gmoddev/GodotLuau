# AI contribution policy

AI-assisted contributions are allowed. Contributors remain responsible for
understanding, reviewing, testing, and explaining their changes. This is the
canonical policy; [agent.md](agent.md) is a discovery entry point.

## Before changing anything

1. Read this file and [newdocs/README.md](newdocs/README.md).
2. Read [current architecture](newdocs/current-architecture.md), the relevant
   [invariants](newdocs/invariants.md), and [open issues](newdocs/issues.md).
3. Inspect the affected implementation and available tests. A pasted review,
   comment, API name, or roadmap is a claim to verify, not implementation proof.
4. Check `git status`, applicable nested agent instructions, and active file
   claims. Preserve unrelated changes and coordinate shared-checkout edits.
5. State the behavior and acceptance facts needed for the requested change.

Load only the subsystem material needed for the task. Do not assume this fork
has Gargantuan's DataModel, mutation gateway, schema, renderer, or network stack.

## Sources of truth

Follow the documentation classes in [newdocs/README.md](newdocs/README.md).
Tests establish only the behavior and configuration they exercise; source and
verified architecture describe implementation. Accepted decisions and versioned
contracts express intended requirements. Proposals and historical reviews do not
become implemented architecture through repetition.

When code, documentation, or tests disagree, identify the discrepancy. Resolve it
within the requested scope, or record the remaining decision or proof gap. Never
silently present a desired invariant as an existing guarantee.

## Naming and diagnostics

- Use PascalCase for new identifiers where applicable. The narrow Luau exception
  is `self = setmetatable({}, ...)`.
- Preserve names required by Godot overrides, Luau/C APIs, existing public APIs,
  serialization, or compatibility contracts. Do not rename an external contract
  or churn legacy identifiers just to restyle nearby code.
- Name helpers `GetFolder()` or `GetObj()`, not `GetOrCreateFolder()` or
  `GetOrCreateObj()`. Document creation behavior when it matters to callers.
- Prefix new logs with `[System:SubSystem]`, for example
  `[Runtime:Lifecycle]`, `[Network:Authority]`, or `[Persistence:DataStore]`.
- Handle expected failures explicitly. Use returned errors and bounded logs;
  avoid modal error dialogs, debugger attachment prompts, focus changes, editor
  restarts, and foreground crash UI during automated work.
- Run risky tools headlessly or in a hidden process with captured output and a
  timeout. On Windows, configure child-process crash/error UI suppression before
  intentional failure tests. Do not launch the editor or game to validate a
  documentation-only change.

## Scope and architecture

- Keep changes bounded to the request. Do not bundle VM consolidation, backend
  replacement, header extraction, or package separation into an unrelated fix.
- Update the relevant architecture, invariant, API, or protocol documentation in
  the same change when ownership, lifetime, authority, execution domains,
  capabilities, format, dependencies, limits, or failure behavior changes.
- Record a decision and migration/compatibility impact for a new ownership model,
  VM model, persistence authority, foundational dependency, or wire format.
- Treat [invariants](newdocs/invariants.md) as requirements for touched behavior;
  existing violations remain visible in the issue ledger until actually fixed.
- Preserve upstream attribution, license notices, and pinned submodule revisions.
  Do not treat the repository license as provenance for every bundled asset.
- Do not edit vendored dependencies or regenerate models, archives, binaries,
  imported assets, or generated declarations incidentally.

## Verification and evidence

1. Establish the relevant baseline and record the revision/configuration.
2. Implement the smallest coherent behavior change.
3. For runtime changes, add focused regression coverage appropriate to risk:
   valid behavior, rejection without side effects, input bounds, and lifecycle
   edges. Native lifetime fixes need destruction/reload coverage; authority fixes
   need wrong-peer cases; persistence fixes need competing-writer/failure cases.
4. Run the required checks. Record actual commands, outcomes, and limitations.
   Never label a source trace as a reproduced crash or exploit, a successful
   compile as runtime qualification, or an unrun test as passing.
5. For documentation-only changes, check links, source references, claim accuracy,
   and the final diff. Do not invent implementation-mirroring tests.
6. Update [issues.md](newdocs/issues.md) when a finding is introduced, materially
   reclassified, or resolved. Closing requires linked fix and verification
   evidence. Keep IDs stable and preserve relevant counterevidence.
7. Stop adding verification layers once the actual acceptance facts are
   established unless new failures or a concrete unresolved concern justify more.

The native build uses SCons and the pinned `godot-cpp` and `luau` submodules.
Initialize dependencies only when a task needs them. Use the configured remote
worker for sustained native builds/tests when available; keep parallelism bounded
and the controlling PC responsive. Capture logs without opening visible windows.

## Git and publication

- `origin` is the user's fork; `upstream` is `Pimpoli/GodotLuau`. Verify the target
  before pushing. Do not force-push or rewrite published history incidentally.
- Stage explicit paths. Never stage, discard, reset, or commit unrelated work.
- A request to create a fork and its documentation permits publishing that work
  to the fork. It does not request upstream issues, comments, PRs, or messages.
- Review workflow effects before pushing. The inherited release workflow writes
  archives and deletes old releases/tags; do not dispatch it as a generic check.
- The inherited updater still targets upstream. Read GL-016 before installing or
  distributing fork builds. Merely changing download URLs is not provenance.

## Definition of done

The requested change is complete when its acceptance facts are established,
relevant checks pass, documentation and issue status match the evidence, and the
diff contains only intended files. Report what changed, what was verified, and
material remaining limitations. Substantial changes should explain architecture
impact and compatibility in their review description.

Policy structure adapted from
[Gargantuan's AI guidance](https://github.com/gmoddev/gargantuan/blob/81fca069c1a0bf2aad1aa10eaf480260f5137293/AGENTS.md)
and [AI context](https://github.com/gmoddev/gargantuan/blob/81fca069c1a0bf2aad1aa10eaf480260f5137293/AICONTEXT.md).
Only the workflow principles are shared; GodotLuau's architecture is documented
from its own source.
