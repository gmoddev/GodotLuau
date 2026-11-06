# Engineering invariants

These are requirements for new or changed behavior. They are not assertions that
the inherited runtime already satisfies them. Baseline gaps link to
[issues.md](issues.md); implementation evidence is in
[current-architecture.md](current-architecture.md).

## Native identity and lifetime

- Persistent script-visible references to Godot objects use stable ObjectIDs and
  resolve/check type and liveness immediately before use. A non-null raw pointer
  is not a liveness check. Closure lifetime must not exceed native owner lifetime
  without a safe resolution/cancellation mechanism. GL-001/GL-002 now have
  capture-specific fixes and native sanitizer evidence; other bindings need
  their own verification.
- VM shutdown invalidates callbacks and pending work before freeing their state.
  Reload, destruction during callback execution, and pending yields require
  explicit ownership and regression coverage. Existing live-VM guards are useful
  implementation evidence, not a complete proof.
- Child subscriptions have independent native Callable identities even when
  Server/Client owners share one native ModuleScript. Caller retirement must not
  retire module-owned callbacks. Disconnect/invalidation affects only the owning
  reference before VM release; native endpoints resolve through ObjectIDs. GL-022.

## Execution domains and capabilities

- Client/server context describes execution, not a privilege grant. Check native
  operations at the boundary rather than relying on a higher-level wrapper or
  the name/visibility of a global. Gap: GL-003.
- Define supported script trust explicitly before advertising sandboxing.
  Lower-trust script support requires restricted globals, explicit capabilities,
  confined filesystem roots, bounded input/output, cancellation, and accountable
  execution/memory limits. Gaps: GL-003, GL-004, GL-005.
- One VM exists per applicable Server/Client domain in a running game process;
  executable scripts must not allocate individual VMs or mix domain authority.
  Script/module environments retain their own identity and ordinary globals;
  `_G`, `shared`, services and require results share only within their domain.
- Module identity survives names/path changes; pending callers join one
  initializer. Cycles/errors, invalidation and existing returned values follow
  [ADR-001](adr-001-shared-execution-domains.md). Executable destruction must not
  evict unrelated modules or cancel their initialization.
- Every task, callback and wait has a domain and owner. Retired owners cannot
  resume; script disable/reload cancels old work before starting a fresh run.
  Reentrant dispatch cannot invalidate scheduler iteration. Native resume
  nesting is bounded; this does not substitute for execution/memory quotas.
- Domain shutdown closes admission before finite close-hook dispatch and owner
  invalidation. Actual VM close follows active native execution, never from
  within a running callback. GL-014's source-qualification evidence is recorded;
  bounded remaining platform gaps are GL-017/GL-018. GL-019's measured
  optimizations are integrated; retained task-creation costs remain documented.

## Multiplayer authority

- Every inbound RPC checks allowed receiver role, actual transport sender, and
  target authority before mutating state or relaying. Do not trust a payload's
  `who`, name, role, or owner claim. GL-006/008's endpoint-specific corrections
  are integrated into main and documented in the [authority record](network-authority-validation.md);
  GL-020's integrated implementation applies the same execution/session rules to animation;
  full animation security qualification remains pending.
- Animation state binds the current assigned session before puppet creation.
  Stops replace active state; character/session/service departure invalidates old
  state. Legitimate server state can wait for a puppet, but stale state must not
  cross into a replacement session. Animation settings must not restart the same
  playing clip or alter another character's loop configuration.
- Validate finite values, legal ranges/transitions, size, and rate before
  accepting gameplay input. Define which state is authoritative versus visual.
  Rejection has no partial mutation or broadcast. Gap: GL-007.
- Match asynchronous replies to the expected request and peer; keep disconnect,
  timeout, and cancellation semantics explicit. Preserve existing checks when
  refactoring. A coordinator file/key is not connection/account authentication.
- Service destruction resolves outstanding invokes before discarding response
  state. Application peer-disconnect callbacks run after the transport poll;
  a functional PASS never erases engine transport diagnostics or sanitizer leaks.

## Persistence and external operations

- Persistent read/modify/write has one documented authority and cross-process
  concurrency semantics. Atomic file replacement alone does not prevent lost
  updates. Gap: GL-009.
- Report persistence success only after the chosen durability point; propagate
  I/O failures and preserve the previous committed value on failed replacement.
  Test competing writers, process interruption, corruption, and restart.
- Gameplay network I/O must have explicit scheduling, cancellation, deadlines,
  and byte/request bounds. A synchronous helper named `Async` does not establish
  nonblocking behavior. Gap: GL-005.

## Distribution and evidence

- Release binaries must be traceable to the claimed source and pinned
  dependencies, with supported platforms built and checked for that revision.
  A committed archive/hash alone does not establish this. Gaps: GL-010, GL-011.
- Preserve published release provenance and history. Update provenance and
  target/version selection are explicit fork policy. GL-012 now preserves history
  with publication disabled; GL-016 rejects runtime updates before side effects.
  A qualified production distribution channel remains unavailable (GL-010/011).
- Preserve dependency license notices and document asset-specific redistribution
  rights. Repository-level MIT text does not settle asset provenance. GL-015.
- Distinguish static observations, reproduced failures, measured performance,
  accepted designs, and production qualification. Never close a defect because
  documentation was added, and never present a proposed requirement as enforced.

## Non-disruptive failure handling

Expected failures return structured results or bounded diagnostic output with a
`[System:SubSystem]` prefix. Automated verification runs headlessly with captured
logs and time limits. Configure Windows child-process error UI suppression for
crash-prone tests. Do not steal focus, open modal error dialogs, attach a debugger,
or restart an editor as incidental automation. Keep heavy native workloads off
the controlling PC when a configured worker is available.
