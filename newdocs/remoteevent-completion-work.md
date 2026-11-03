# GL-029 completion work

Date: 2026-11-03. Starting branch `integration/gl-018-gl-029-remoteevents` at
`cda423abae0270e62400be116ba23093dd6265c2`; qualified Phase 1 runtime `eec2397`.
Main remains `83cd0887968d73d61d050650718d8ada6e124579`. The working tree starts
clean and the published development tip matches. Dependency pins remain unchanged.

The user requests completion of GL-029 with the same small-change/no-refactor,
documentation, commit-preservation, unmerged-main and disabled-publication rules.
This authorizes continuing the remaining RemoteEvent work. GL-030 request timeout
semantics, replication batching and Character protocols remain separate issues.

## Acceptance and first gate

The outstanding P2/P3 behavior is bounded Remote-owned admission and queues,
fair peer service, exact accounting/teardown, the third sequenced mode, independent
stream freshness and safe unsent supersession. Actual loss/reorder/slow-peer,
complete-RPC packet-size and comparable performance evidence must accompany the
existing full Windows/Linux regression/sanitizer/product qualification.
Application admission, ENet submission, native retention and remote dispatch must
remain distinct observations. A successful send or application receipt is not
native ACK retirement. No total-backend-memory claim follows from an unsent queue cap.

Before changing production behavior, establish whether the pinned stock host can
support the required native egress admission contract. The pinned extension API
lists only loss, RTT and throttle peer statistics. There is no exposed reliable
queue byte/command count, native ACK-retirement ledger or outgoing queue cap.
`ENetConnection.bandwidth_limit` limits traffic, not retained bytes.

Source references at engine `a13da4feb8d8aefc283c3763d33a2f170a18d541`:

- [ENet peer API](https://github.com/godotengine/godot/blob/a13da4feb8d8aefc283c3763d33a2f170a18d541/modules/enet/enet_packet_peer.cpp): exported send/statistics and method bindings.
- [Native send](https://github.com/godotengine/godot/blob/a13da4feb8d8aefc283c3763d33a2f170a18d541/thirdparty/enet/peer.c): packet/channel/state checks and outgoing command allocation.
- [Native retirement](https://github.com/godotengine/godot/blob/a13da4feb8d8aefc283c3763d33a2f170a18d541/thirdparty/enet/protocol.c): reliable command/packet references retire on native acknowledgments/reset.

These are source-verified API observations, not yet a measured backlog failure.
Run a bounded disposable raw ENet connection probe on the remote worker, with one
endpoint deliberately not polling after connection. Record accepted submissions,
process memory, payload bytes, available statistics and cleanup. This characterizes
the engine boundary; it is not a substitute for production RemoteEvent qualification.
Do not alter the engine, dependency pins or production runtime while this contract
gate is unresolved. Retain the qualified Phase 1 behavior and evidence.

## Characterization outcome

Both bounded Windows probes complete, including the second probe servicing the
sender without receiver polling. All 32 MiB of payload is admitted; approximately
37 MiB of additional private storage remains until host destruction. No exact
native backlog/retirement observation or public outgoing cap is available. This
is finite retention evidence, not a leak or an exhausted-limit claim.

The [native admission decision](remoteevent-native-admission-decision.md) records
the measured evidence, the minimum adapter contract, the patched-host compatibility
impact and the explicitly weaker stock-host alternative. GL-029 remains OPEN;
production Phase 1, main, pins, releases and updater admission remain unchanged.
