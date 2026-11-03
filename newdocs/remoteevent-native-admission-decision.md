# GL-029 native admission decision

Status: native host adapter APPROVED by the user on 2026-11-03 ("continue,
approved"). Implementation is committed; final independent hosted/package
qualification is tracked in the [completion record](remoteevent-completion-qualification.md).
Date: 2026-11-03. Baseline `cda423a`, qualified Phase 1 runtime `eec2397`.

## Established boundary

The stock pinned Godot host has no extension API for atomically reserving a
per-peer native outgoing byte/command budget or observing its native retirement.
The [completion work record](remoteevent-completion-work.md) links the exact
engine sources and the public API inventory. Source shows native outgoing command
allocation; the runtime characterization below establishes finite retained growth.
It does not establish a crash, leak, vulnerability or infinite-memory observation.

Two bounded disposable probes use official Windows Godot 4.7.1, executable SHA-256
`323f9c4cc5db674e98815cdd8e69da007d5efc779abedc8c0e42883b7fdea12a`.
Each creates an actual loopback ENet connection, then submits 2,048 reliable
16,384-byte packets with no receiver polling after connection. Every submission
returns OK: 33,554,432 payload bytes. No extension, Luau, gameplay queue or
application acknowledgment is involved.

The first probe deliberately leaves the native queue unsent. The second flushes
and services the sender for 500 ms while the receiver cannot generate data ACKs.
The host reports 469,016 sent transport bytes and stays connected. Measurements:

| Stage | Working set | Private bytes |
| --- | ---: | ---: |
| Baseline | 90,112,000 | 41,111,552 |
| After native admission burst | 126,291,968 | 78,360,576 |
| After sender servicing without receiver polling | 126,320,640 | 78,360,576 |
| After destroying both hosts | 89,935,872 | 41,078,784 |

Both processes exit zero with empty stderr. RSS/private bytes are process-level
observations, not an exact per-peer backlog ledger. The native queue limit and
ACK retirement remain unavailable. The experiment does not exhaust a larger
possible engine limit. It disproves treating successful submission or empty
application queues as evidence that retained transport storage is empty.

## Smallest credible full-boundary change

Retain ENet, the existing Godot RPC path and NetworkService ownership. Add a
narrowly scoped pinned Godot/ENet admission adapter, rather than bypassing private
engine memory from a GDExtension. It must provide:

1. Atomic per-peer admission before native packet/command retention, including
   fragments and fanout; exact checked bytes/commands and finite ceilings.
2. Charges that survive send/retransmit and release only on native packet/command
   destruction, acknowledgment retirement or peer reset. Partial fragment ACKs
   cannot release a whole retained packet's charge prematurely.
3. A defined WouldBlock/reject outcome that cannot silently lose accepted reliable
   work. Hard terminal failure affects the exhausted peer, with exact cleanup.
4. Bounded read-only native observations and an immutable trusted admission
   policy; gameplay cannot raise limits or impersonate native retirement.
5. Capability/version detection before activating the stronger Remote contract.
   A stock host cannot silently claim the patched host's guarantees.

This introduces a **patched-host dependency for the stronger contract**. It is
not an ordinary GDExtension-only fix and must be qualified alongside both
Windows/Linux Debug/Release products, packaging and sanitizer hosts. It needs a
focused ADR and explicit project/deployment migration documentation. No host
patch or dependency change had been made at this decision checkpoint. The approved
implementation is described in [ADR-009](adr-009-bounded-remote-delivery.md).
No scheduler, replication or RemoteFunction redesign is part of this option.

## Stock-host alternative

Keep official Godot compatibility and complete application-owned queues and
sequenced delivery with an explicitly weaker boundary: bounded unsent storage,
fair flush, precise handoff counters, and **unqualified native retention**. That
can be useful, but cannot close a requirement for bounded native reliable
backpressure. The issue/acceptance scope would have to retain that proof gate.

Application receipts cannot safely substitute for native ACK retirement. A
never-released lifetime send quota would bound submissions by disconnecting
healthy long-lived sessions at the quota; it is not a transparent substitute.
Process-wide memory killing would violate peer failure isolation.

Requiring a patched production host was treated as wider than a routine fix
under the user's no-refactor instruction. The user has now approved that narrow
compatibility/ownership expansion; do not request that approval again.
The project policy requires a recorded dependency/ownership decision; it does not
independently impose an approval rule. The choices above are a concrete scope
decision, not a claim that an unimplemented adapter is qualified.

## Retained evidence

Remote: `C:/Sandbox/Codex/GL029Completion/retention-characterization.zip`.
Controller: `C:/Users/aiden/.codex/artifacts/godotluau/gl029-completion/retention-characterization.zip`.
Archive SHA-256: `b14c8c8b530bb93e3492f736a2af86a23c38e66a8fac5be6dd7c2a3d5bc25ed1`.
The archive includes both scripts, parent drivers, actual commands, memory samples,
results and log hashes. This is Windows engine-boundary characterization, not
Windows/Linux production RemoteEvent qualification or completion of GL-029.
All 15 indexed evidence files rehash after download to the controller.
