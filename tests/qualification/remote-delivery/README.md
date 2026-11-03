# Supplemental RemoteEvent wire qualification

These actors exercise the production extension, public Fire APIs, real ENet and
SceneRPC, independently of the ordinary 116-actor regression inventory. They do
not replace those gates or mock authorization/dispatch. Run after compiling the
matching admitted host and extension; preserve the immutable build identities.

```text
python tests/qualification/remote-delivery/RunLossyQualification.py --extension <library> --identity <native-build-identity.json> --host-manifest <host-manifest.json> --output <fresh-directory>
```

The bounded loopback proxies drop the first marked reliable datagram, drop every
marked unordered datagram, delay selected datagrams by 120 ms and duplicate a
selected datagram. They require actual reliable retransmission and native-order
recovery, observable unordered reordering/loss, and stale rejection after actual
sequenced wire reordering. Native ENet may suppress the duplicated unsequenced
datagram; the test permits that outcome. No application retry is introduced.

The actual NetworkService uses a 256-byte UTF-8 absolute node path. A maximal
768-byte encoded unreliable body passes the production codec and is measured at
native handoff, including the actual native-method RPC identifier and path.
This complements the host-only RPC fixture's cached/uncached encoding checks.
Host last-submission observations remain separate from retained/ACK evidence.

Two client processes have independent proxy sockets and native sessions. Each
proxy caps pending work at 256 datagrams / 1 MiB, captures fault/forwarding counts,
and shuts down with the owned actors. Capacity drops or missing intended faults
fail qualification. Windows crash UI suppression, hidden headless children,
captured logs and bounded deadlines reuse the existing fixture infrastructure.

See the [GL-029 work record](../../../newdocs/remoteevent-completion-work.md) for
actual runs, configurations, failures and remaining qualification scope.
