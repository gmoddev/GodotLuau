# ADR-001: Shared Server and Client Luau execution domains

Status: accepted for implementation by the owner's 2026-10-26 request.
Implementation and qualification status live in
[the work log](shared-domains-work-log.md); acceptance of this decision does not
close GL-014. The implementation is now delivered; the validation report records
functional coverage and remaining qualification gaps.

## Baseline and decision

Starting revision: `8b163269cbe44cf7fcf7a9a0285620878a2345fd` on `main`.
Runtime source is unchanged from `7044a11c`. Each executable ScriptNodeBase
allocates/initializes/closes its own VM. ModuleScript runs in its caller's VM;
its registry cache and loading table are therefore per executable script.

Select one lazily initialized Server VM and one lazily initialized Client VM per
game scene/process. A runtime host under the current scene (root fallback before
a current scene exists) owns domains and ticks their schedulers. Scene replacement
shuts down the old host before creating fresh domains; VM close is deferred until
active native calls return.
Only domains actually needed by the role are created. Processes never share a
VM. Single-player/listen-host configurations can host both logical domains;
dedicated server and remote client configurations select their respective role.

Per-script VMs preserve stronger failure isolation but prevent the requested
module sharing. One universal VM mixes context-dependent privileges. Actor-like
additional VMs may be a future explicit isolation feature, not an implicit escape
hatch in this migration. No performance/memory improvement has been measured.

## Environments and modules

Each script and ModuleScript has an environment with its own `script` and global
assignments, inheriting domain builtins/services. `_G` and `shared` are deliberate
domain-shared tables, separate between Server and Client. Module environments do
not forward global writes into a requiring script's environment.

Luau getfenv/setfenv remain available for compatibility. They can deliberately
inspect/change accessible function environments; this is environment separation,
not a new hostile-script sandbox. Context checks use domain ownership rather than
trusting mutable `__IS_SERVER`/`__IS_CLIENT` flags alone. Existing broad native
filesystem/HTTP exposure remains tracked under GL-003 through GL-005.

Module identity is Godot ObjectID plus the currently loaded source revision, not
Name or path. One domain cache entry owns independent initialization work, result
or sticky error, and waiting callers. Concurrent callers join pending work.
Dependency cycles, including cycles involving concurrent initializers, fail
instead of waiting forever. Exactly one non-nil result is required; false and
other valid scalars are cached. Tables/functions retain reference identity.

Destroying/reloading a module invalidates its entry and owned work; subsequent
require starts the new revision. Old returned Lua values already held by users
remain ordinary values and are not rewritten. Unrelated script destruction does
not invalidate module results or initialization. Failure is sticky until module
invalidation/revision change, so repeated require does not repeatedly run a
failing initializer.

## Scheduler and native callback ownership

Distinguish domain/VM lifetime, script or module owner lifetime, coroutine
lifetime, and callback/reference lifetime. Domain runtime owns scheduled threads,
wait states, owner identities, and registry references. Native callbacks retain
an owner anchor, not the universal VM state. Invalid owner anchors cannot dispatch
even while the shared VM remains live. Thread creation inherits owner identity.

Numeric yields in managed tasks are timed waits; explicit signal/child/remote/module yields wait
for their condition. Spawn starts immediately, defer starts on a subsequent
scheduler tick, and delay starts after its deadline. Resume/cancel use stable
thread identity and re-find records after reentrant Luau calls. Invalid/completed
threads are never resumed. Native resume nesting is capped at eight; deeper
spawn/module chains continue on later ticks. Manually resumed coroutines join
managed scheduling when entering timed/module/native waits, while ordinary
explicit yields remain manual. Coroutine resume/wrap reject retired owners and
cancelled tasks. Shared Lua service callbacks retain subscriber ownership;
trusted service polling belongs to the domain. Destruction invalidates work before releasing refs;
closing one owner never closes the domain VM.

Script disable cancels that run; re-enable starts a fresh environment/run. Reload
cancels the old run and starts the new source when enabled. Pending shared module
initialization is owned by the module rather than the first caller. Domain
shutdown stops admission, cancels work and closes its VM deterministically.
BindToClose is a game/domain-close hook, not a script-destruction hook; any
shutdown callbacks must be a finite snapshot and cannot create persistent work.

## Compatibility and scope

Intentional changes: shared require identity, domain-shared `_G`/`shared`, module
global isolation, sticky module errors, cancellation/restart on disable/reload,
and owner-specific callback cleanup. Preserve public Instance/task/signal/remote
APIs, template rules, RunContext roles, existing wire formats and authority
checks. Do not replace persistence, networking, Instances, updater, or dependency
pins. GL-001/GL-002 require separate regression evidence even if captures are
adjusted as migration prerequisites.

## Acceptance

Executable tests must demonstrate shared and separated caches, yielding and
concurrent initializers, cycles/errors, environment identity/isolation, valid
task/signal/remote behavior, owner cancellation, reentrancy, repeated teardown,
and process roles. Native compile success is not integration qualification.
Record exact commands/results and any unexercised Godot configurations in the
work log. Keep GL-014 open until the implementation acceptance facts are met.
