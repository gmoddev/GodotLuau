# GL-034 bounded catalog maintenance proposal

**Status: bounded implementation candidate; qualification pending.**
The campaign attachment explicitly authorizes bounded refactoring necessary for
implementation and continuation without routine approval. The earlier approval
question was unnecessary; no additional approval is assumed. ADR-011 remains
the accepted authority/delivery contract.

## Evidence and scope

`bd18580` passes both platforms' core/native/full-native sanitizer checks. Its
three narrow refresh corrections pass eight paired ASan mixed-world trials,
but the 512-object candidate still has 98–101 ms server frame p95 versus
14–16 ms on main. Catalog refresh takes 10.77–11.41 seconds over 145–146 calls;
individual maxima reach 111–137 ms. See the
[receipt](evidence/networking2-bd18580-asandebug-benchmark.json).

`RefreshReplication()` currently validates every native registration, constructs
a fresh bounded catalog/index and swaps them together. `TickReplication()` calls
it periodically; a published `QueueReplicationReparent()` calls it synchronously
to preserve accepted structural transitions. Merely increasing the refresh
interval, queue bounds or ten-second failure deadline would not fix this cost.

## Proposed bounded change

1. Reuse the private catalog/index in place, marking records with a checked sweep
   generation. Suspend new peer selection while a sweep is unfinished; already
   accepted immutable frames continue draining. This avoids rebuilding unchanged
   map nodes and retains native ObjectIDs rather than raw retained Node pointers.
   Existing source/object/snapshot/catalog bounds continue to apply.
2. Bound each sweep turn by 64 items and a two-ms elapsed-work quantum. A
   quantum is cooperative: it cannot preempt a single Godot call. Measure actual
   maximum turn time and record any per-record overrun instead of claiming a
   hard whole-frame deadline.
3. Preserve record validation, native scope/identity, current revisions and
   dependency closure. Mutation across turns can temporarily leave a missing
   source prerequisite; retry the source projection within the existing
   ten-second failure bound, without admitting an incomplete frame. Do not
   restart the cursor on every write.
4. Preserve every accepted published reparent transition by refreshing its
   affected source dependency closure, bounded to the existing 64-operation
   group. Every refresh reads current native state; a sweep holds no older
   staged record that could overwrite a newer barrier. No coalescing may erase the
   qualified A-minus/B-plus/B-minus/A-plus transition sequence.
5. Retire builder work on service replacement, disconnect/reset, scope loss and
   destruction using the established owner-aware lifecycle. Keep the existing
   scheduler, native authority, delivery queues, wire format and dependencies.

This candidate extracts the existing record-validation path and adds a small
owned sweep cursor/generation/stage. It is larger than the already
published 14-line runtime patch. No unrelated header extraction, VM change,
transport replacement or public API migration is proposed.

## Acceptance facts

- Repeat current Windows/Linux Debug/Release, core/native sanitizer and extracted
  package qualification at the resulting immutable source revision.
- Preserve existing relevance, wrong-domain/root protection, same-turn reparent,
  cyclic reference closure, WouldBlock/healthy-peer, cancellation and teardown
  assertions. Add mutation/destroy/reparent during an unfinished scan and service
  replacement with unfinished work.
- Compare repeated main/candidate 1/16/32-peer small/large workloads using the
  same admitted host/compiler per configuration. Preserve failing/resource-blocked
  attempts and distinguish instrumented Debug from production Release evidence.
- Measure catalog turn cost, frame p95/p99, convergence latency, queue age,
  wire/admission behavior and retained staged memory. Large-world admission must
  succeed within the existing limits or remain explicitly unqualified.
- Keep the branch unmerged and releases/updater distribution disabled.
