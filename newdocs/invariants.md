# Engineering invariants

These are requirements for new or changed behavior. They are not assertions that
the inherited runtime already satisfies them. Baseline gaps link to
[issues.md](issues.md); implementation evidence is in
[current-architecture.md](current-architecture.md).

## Native identity and lifetime

SceneScope authoring follows [ADR-014](adr-014-native-scene-authoring.md): exact
execution-generation ownership, approved native families/properties, separate typed
resource handles, bounded construction, and owner retirement before reuse.
Resources obtained from project loading/getters remain immutable. Neither a
retained legacy method nor generic subtree replication may bypass scope ownership
or publish its local native objects. Godot ObjectDB and existing owner-aware
dispatch remain the identity and callback authorities.

GL-051's [ADR-015](adr-015-policy-driven-native-bindings.md) extends that boundary:
discovery never grants execution, and runtime/type/editor surfaces must derive
from the same checked policy. Native calls validate ownership, mutability, arity
and bounded arguments; resource targets cannot become Node signal sources.
PackedScenes require preflight before instantiation and ownership before tree
entry. Clone/reparent remain within one live scope and preserve Godot identity.
Stored scripts/connections/groups or unreviewed scene inheritance must not execute
through composition. Analysis/completion must not execute game code.

Local semantic input (ADR-012) must share UserInputService's physical adapter and
post-GUI routing facts. Client execution owns input APIs; mutable Lua properties
cannot grant hardware, Character or network authority. Context/action/binding
configuration is canonical, while device admissions are disposable and bounded.
Commit all action values before callbacks, resolve retained views by ObjectID,
and retire script-owned contexts and callbacks with their execution owner. Focus
loss, GUI-consumed releases, reconfiguration and owner/device removal must leave
neutral state without synthetic reactivation from held input. Keep independent
controller primitives separate from authoritative Character V2 physics.
Local input/motor subtrees must not acquire static network identities, enter
generic replication or become remote reference capabilities. Scene-authored
motors stay inert until Client adoption. Movement commands target only that
independent body, occupy bounded slots and execute at the native physics fence;
observation setters cannot bypass them. Frame and physics readers must not drain
one another's relative input samples.

Optional Player.Character control (ADR-013) supplies local intent to the existing
Character V2 body, never a second motor or arbitrary physics capability. Native
is the default. Scripted commands require the exact live native local Character,
current Client execution owner, private lease generation and existing transport
identity. Consume bounded intent once per physics tick; retain server-owned
configuration and pose admission. Retirement must neutralize intent and owned
capture without falling back to held hardware. New lives/clones default Native.
Retained old commands cannot control a replacement lease or Character life.

- Persistent script-visible references to Godot objects use stable ObjectIDs and
  resolve/check type and liveness immediately before use. A non-null raw pointer
  is not a liveness check. Closure lifetime must not exceed native owner lifetime
  without a safe resolution/cancellation mechanism. GL-001/GL-002 now have
  capture-specific fixes and native sanitizer evidence; other bindings need
  their own verification.
- Bound value-method closures must retain their VM-owned receiver rather than
  borrowing a userdata address across collection. Vector3 colon calls resolve
  their explicit receiver by identity; supported legacy bound dot calls remain
  valid. Native CFrame getters preserve the same shape and orientation convention
  as existing stdlib CFrames, without changing transform write authority.
- VM shutdown invalidates callbacks and pending work before freeing their state.
  Reload, destruction during callback execution, and pending yields require
  explicit ownership and regression coverage. Existing live-VM guards are useful
  implementation evidence, not a complete proof.
- Child subscriptions have independent native Callable identities even when
  Server/Client owners share one native ModuleScript. Caller retirement must not
  retire module-owned callbacks. Disconnect/invalidation affects only the owning
  reference before VM release; native endpoints resolve through ObjectIDs. GL-022.

## Execution domains and capabilities

GL-052 editor authoring follows [ADR-016](adr-016-luau-editor-authoring.md).
Explicit EditorPreview execution must not initialize gameplay services or expose
editor objects/filesystem writes to Luau. Old preview owners, module initializers,
callbacks and resource handles retire before replacement. Preview is transient;
only an explicit native editor save may create an independent native PackedScene,
without overwriting existing targets or serializing live execution capabilities.
Packing expanded snapshot descendants must not retain PackedScene instance paths
that would create those descendants again on reopen. Native resource references
remain, while the saved snapshot and original preview have separate identities.

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

- Opted-in structural replication follows [ADR-011](adr-011-peer-replication-relevance.md):
  native server registrations and validated Character focus own selection.
  Client metadata or camera coordinates cannot grant visibility or ownership.
  Planned, native-accepted Known, and application-reported Materialized state
  remain distinct and session/generation bound. Required dependency groups are
  admitted together; accepted reparent barriers are never coalesced away.
  Leave does not destroy canonical state. Runtime physics and public Remote
  references must respect current materialization; ACKs do not prove an honest
  client or manufacture an ownership decision. Explicit limits/timeout failure
  retire exact state without silently dropping accepted reliable work.
  Incremental source maintenance must not admit partial dependency groups or
  overwrite newer accepted structural barriers. Retire its owned cursor/cache
  work on service reset; bound turns and unresolved source-dependency waits.
  ObjectValue targets are weak Node references: validate the engine Variant
  before asking godot-cpp to convert its pointer or obtain an instance binding.
  Expired targets read as nil through both native and Luau getters (GL-038).
  Control ACKs describe the snapshot's captured revision. Do not label older
  cached data with a newer live control version or let an immediate runtime
  ownership RPC race the ordered structural ownership state.

- Application RemoteEvent delivery configuration is native Server authority.
  Publication/readiness binds the current native transport session, endpoint
  generation, delivery carrier and local ObjectID; neither a payload path nor a
  mutable Lua enum establishes authority. Private or Client-created endpoints
  cannot become public through a listen host's shared native tree. Supported
  Phase 1 bounds and compatibility are defined by [ADR-008](adr-008-remoteevent-publication.md).
  The later-phase contract additionally satisfies [ADR-009](adr-009-bounded-remote-delivery.md):
  actual native RPC context, bounded ownership across queue/native handoff,
  explicit terminal reliable failure, independent checked sequencing and exact
  generation retirement. Its [qualification](remoteevent-completion-qualification.md)
  requires the admitted host. Main preserves the qualified source through
  `6a7fedf`; [fresh integration verification](gl018-gl029-main-integration.md)
  is recorded separately. Native
  data caps do not bound total process RAM or receive/control storage. Neither
  phase supplies general replication relevance or finite RemoteFunction defaults
  (GL-030).

- Every inbound RPC checks allowed receiver role, actual transport sender, and
  target authority before mutating state or relaying. Do not trust a payload's
  `who`, name, role, or owner claim. GL-006/008's endpoint-specific corrections
  are integrated into main and documented in the [authority record](network-authority-validation.md);
  GL-020's integrated implementation applies the same execution/session rules to animation;
  the [dedicated authority follow-up](animation-authority-qualification.md) records
  adversarial transport scope and remaining sanitizer qualification limits.
- Animation state binds the current assigned session before puppet creation.
  Original wire types are checked before coercion; conversion diagnostics must
  not permit malformed animation state to reach cache, playback or relay.
  Stops replace active state; character/session/service departure invalidates old
  state. Legitimate server state can wait for a puppet, but stale state must not
  cross into a replacement session. Animation settings must not restart the same
  playing clip or alter another character's loop configuration.
- Validate finite values, legal ranges/transitions, size, and rate before
  accepting gameplay input. Define which state is authoritative versus visual.
  Rejection has no partial gameplay mutation or broadcast. Integrated GL-007
  supplies native health, bounded prediction and checked presentation; integrated
  Character V2 carries those requirements into ADR-007's protocol 3 and Model root.
  See [ADR-006](adr-006-character-authority.md) and
  [main integration evidence](character-main-integration.md).
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
- Touched RemoteFunction behavior follows [ADR-010](adr-010-remotefunction-terminal-outcomes.md):
  finite snapshotted deadlines, checked full-width identities, expected native
  sender/session/publication, bounded correlation and serving state, and one
  detached terminal delivery through the exact owner wait. Manual resumption
  cannot let an old response resume a newer wait. Cancellation does not roll
  back handler side effects and must not trigger automatic application retries.
  Campaign implementation/qualification status is recorded separately.
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
- HttpService public failures must not masquerade as successful empty responses.
  Response headers retain bounded actual values, including duplicate identity.
  HttpEnabled reflects native availability and cannot be assigned to grant I/O.
  JSON errors, null, container shape, finite numeric values and traversal/byte
  limits follow the [GL-023 contract](httpservice-api.md). Offline helpers expose
  no native authority, and do not replace GL-009's serialization codec.

## Distribution and evidence

- Release binaries must be traceable to the claimed source and pinned
  dependencies, with supported platforms built and checked for that revision.
  A committed archive/hash alone does not establish this. Gaps: GL-010, GL-011.
- Candidate admission binds every supported platform/configuration to one
  immutable revision, pinned dependencies, actual product and fixture hashes,
  complete required qualification and extracted companion startup. Any failed,
  skipped, incomplete or timed-out required gate rejects acceptance. Candidate
  artifacts do not grant release publication or updater distribution authority.
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

The unmerged [native expansion](gl-053-native-api.md) keeps pure value conversion
separate from object/resource admission. Bounded collections cannot transport
native capabilities. Observation properties reject writes; owned node payloads
cannot confer foreign scope authority. Temporal playback/autostart stays outside
EditorPreview. Metadata-based collection checks precede native mutation, and
shader/MultiMesh effects retain their explicit bounded resource contract.

Expected failures return structured results or bounded diagnostic output with a
`[System:SubSystem]` prefix. Automated verification runs headlessly with captured
logs and time limits. Configure Windows child-process error UI suppression for
crash-prone tests. Do not steal focus, open modal error dialogs, attach a debugger,
or restart an editor as incidental automation. Keep heavy native workloads off
the controlling PC when a configured worker is available.
