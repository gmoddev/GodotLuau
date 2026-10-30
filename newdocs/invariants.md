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
  the name/visibility of a global. Integrated GL-003 implements the bounded native
  storage contract in [ADR-003](adr-003-native-storage-authority.md); qualification
  and integration status remain in the issue ledger.
- Define supported script trust explicitly before advertising sandboxing.
  Lower-trust script support requires restricted globals, explicit capabilities,
  confined filesystem roots, bounded input/output, cancellation, and accountable
  execution/memory limits. Integrated resource controls follow ADR-002;
  native storage authority follows ADR-003 on main; HTTP capability
  and scheduling follow integrated ADR-004 on main.
  Trusted project assets are not hostile-package
  isolation or a race-resistant ResourceLoader sandbox.
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
- Gameplay entry, marshalling and resumed execution use same-state protected VM
  boundaries. Nested Server/Client calls inherit active ancestor time/count
  constraints; catching an inner error must not reset an active attempt.
- Allocator accounting/quota applies to requested VM bytes, including bootstrap,
  shared modules and registry roots. Its context remains valid through lua_close;
  it performs no Lua calls, throwing operations or reentrant container allocation.
- Memory rejection remains latched through caught errors and disabled timers.
  Resource exhaustion retires that domain at a protected boundary, invalidates
  future work and does not close a currently executing VM or restart it.
- Nonterminal admission rejection does not retain excess work or cancel a valid
  previous owner before a replacement is admitted. Cancelled records and dead tokens
  remain bounded until safe reaping/GC. Error reporting does not allocate Lua
  strings outside protection. See [ADR-002](adr-002-domain-resource-policy.md).

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
  Rejection has no partial gameplay mutation or broadcast. GL-007's protocol 2
  grants, native health and checked presentation contract are qualified on the
  retained, unmerged branch; main remains affected until an authorized merge.
  See [ADR-006](adr-006-character-authority.md) and
  [qualification](character-authority-validation.md).
- Character V2 has one real Model-derived Character identity and one authoritative
  world pose. Its internal top-level physics body, direct root proxy, visual rig,
  camera and replicated world pose must stay synchronized. No Humanoid wrapper,
  second active rig collider or independent visual-authority transform is allowed.
  2D's separate native contract is preserved.
- Character health/configuration are Server-owned. Movement requests cannot claim
  arbitrary observed states. Native death latches once; respawn creates fresh
  ObjectIDs and playback ownership. Reentrant LoadCharacter cannot duplicate a life.
- Protocol-3 removal tombstones reject same/older-life pose and animation before
  cache/presentation mutation. Connected Player identity survives Character absence.
  Same-scene reparenting preserves identity; stale deferred removal cannot erase a
  replacement. Animator/track cleanup acts only on its exact owned playback clip.
- Match asynchronous replies to the expected request and peer; keep disconnect,
  timeout, and cancellation semantics explicit. Preserve existing checks when
  refactoring. A coordinator file/key is not connection/account authentication.
- Service destruction resolves outstanding invokes before discarding response
  state. Application peer-disconnect callbacks run after the transport poll;
  a functional PASS never erases engine transport diagnostics or sanitizer leaks.

## Persistence and external operations

- Persistent read/modify/write has one documented authority and cross-process
  concurrency semantics. Atomic file replacement alone does not prevent lost
  updates. Integrated GL-009 implements the per-record cooperating-local-
  writer protocol in [ADR-005](adr-005-transactional-datastore.md); qualification
  and main integration status remain explicit in the issue ledger.
- Report persistence success only after the chosen durability point; propagate
  I/O failures and preserve the previous committed value on failed replacement.
  Test competing writers, process interruption, corruption, and restart.
- DataStore transforms execute on the owning Lua coroutine outside the native
  lock. A conflict may repeat the transform, at most eight attempts; nil/error
  never commits a candidate. Do not promise exactly-once callback side effects.
  Set/Remove/Increment participate in the same commit protocol. Cancellation
  prevents stale delivery but cannot undo publication; indeterminate mutation
  outcomes require application reconciliation against latest committed state.
- Package the matching native DataStore companion beside the extension. Native
  storage paths/handles/locks stay private; helper admission/completion revalidates
  owner/domain authority. Missing/incompatible helper fails closed. Stage recovery
  occurs only under the stable lock. Stop old writers before upgrade; network
  filesystems, independent replicas and noncooperating writers are unsupported.
- Gameplay network I/O must have explicit scheduling, cancellation, deadlines,
  and byte/request bounds. A synchronous helper named `Async` does not establish
  nonblocking behavior. Integrated GL-005 implements ADR-004: live native Server
  authority and explicit exact-origin grants before I/O; finite input, body,
  wire, concurrency and per-tick allowances; cancellation before VM reclamation;
  protected completion for the current wait only; and failure without a partial
  successful body. Qualification and main integration are distinct ledger states.

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
