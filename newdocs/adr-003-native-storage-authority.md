# ADR-003: Native service storage authority

Status: accepted, qualified and integrated by normal merge
`5ba96ad0ca74f63ac92910633ba1c0d4fd6050e2`, retaining both source commits on
`security/gl-003-filesystem-capabilities`. Fresh main Windows/Linux core/native
hosted CI and local integration checks pass in the linked integration record.
GL-003 is resolved within this native-storage authority contract; the trust and
resource limitations below remain unchanged.
Extends ADR-001/002 without changing VM or scheduler
ownership. Executed evidence and unresolved checks live in the
[work record](filesystem-capabilities-validation.md).

## Authority

Raw `_FileAccess.read/write/exists/delete/list` remain discoverable for compatibility
but always raise a native capability denial. Being ServerScript, bootstrap code,
or the owner of a numeric callback ID grants no arbitrary filesystem authority.
Engine startup and editor/GDScript operations remain trusted host operations.

Built-in services capture a separate native bridge during initialization; its
bootstrap global is then removed. Hiding this bridge is not the security boundary.
Every native operation validates the current live execution owner, matching
domain, open admission and absence of a latched allocation rejection. The sole
closing exception is the domain's already admitted synchronous BindToClose
coroutine, identified natively, so legitimate final persistence remains possible
under the existing aggregate close-hook budget. No other closing thread gains
authority, and allocator failure still denies access and skips hooks. Persistent
service authority requires both a Server domain and a native non-client process
role. Lua role globals, `getfenv`/`setfenv`, modified service tables and forged
names cannot authorize another root or operation.

The native record is VM-owned userdata with a domain identity, fixed host-selected
user-data root and native mailbox identity. It contains no retained OS handles or
public numeric grant. Its destructor releases native strings at VM close. Storage
handles exist only within one synchronous operation and are closed before the
operation returns to Lua. GL-004 cancellation, retirement and deferred VM close
are unchanged. A fresh domain receives a new record.

Authority is service/domain scoped, not per-store ACLs or origin-closure ownership.
A live Server owner may use public DataStore/MemoryStore/Messaging services and
delegate those same operations to another live owner in its Server domain. A
retired caller or closing domain cannot operate. This does not isolate mutually
distrusting server scripts' application data from each other.

| Native service operation | Authority |
| --- | --- |
| DataRead / DataWrite / DataDelete | Server; one constructed DataStore leaf |
| MemoryRead / MemoryWrite | Server; one constructed MemoryStore map leaf |
| MessageRead | Server; one topic and native-format sender mailbox |
| MessageWrite | Server; caller domain's own mailbox for that topic |
| MessageList | Server; bounded discovery for that exact topic only |
| Enabled / Mailbox / Topic | Live matching domain; metadata/validation only |
| Raw read/write/exists/delete/list | No gameplay grant |

Client DataStore and MemoryStore persistence is denied. Client Messaging retains
local subscription/publication but does not read or write shared server mailboxes.
Server/listen-host cross-process storage remains supported. No Lua API exposes a
root parameter, host filename or native capability record.

## Physical compatibility and validation

Keep the existing project `user://` root shared by coordinator/world processes:

- `ds_<name[_scope]>_<key>.json`, including `__ord_` ordered-store names;
- `msg_<topic>__<native-job-or-local>_<vm-counter>.json`;
- `mem_<name>.json` for maps; queues remain process-local as before.

The inherited bridge used Godot's Latin-1 `String(const char*)` constructor for
paths and writes. Preserve that physical filename/write encoding rather than
silently moving existing non-ASCII data. Logical names must be valid UTF-8;
native encoding maps their bytes through the legacy Latin-1 conversion before
opening the final leaf. Existing JSON conversion behavior is unchanged; this is
not a Unicode value-codec repair. UTF-8 BOM handling on read remains compatible.

Logical components are nonempty, at most 200 UTF-8 bytes, and reject NUL/control
bytes, separators, colon/ADS, wildcard/device-path punctuation and standalone
`.`/`..`. Internal spaces and dots, including trailing logical spaces/dots, remain
allowed because the final physical name has a fixed `.json` suffix. The final
encoded leaf must be at most 240 bytes and have the native namespace prefix and
suffix; it cannot be a drive, UNC, extended-device or relative traversal path.
Windows case behavior remains the filesystem's existing behavior; no normalization
or silent renaming is introduced. Legacy underscore/name-scope collisions remain
an existing format limitation, not a new isolation guarantee.

Bounds are 16 MiB for physical reads/writes (and no more than 16 MiB of supplied
write data), 4,096 bytes for the trusted root, and 65,536 inspected directory
entries. Enumeration returns only matching regular mailbox leaves, rejects
ambiguous `__` sender identities and never reveals unrelated filenames. Bounds
are checked before a mutating open/truncate; an error returns no partial listing.
Workload/limit measurements remain a qualification gate, not assumed from these
chosen finite limits alone.

## Platform operations

On Linux, open the directory chain component by component with directory
descriptors and `openat(O_NOFOLLOW)`. Open one leaf relative to the final descriptor,
without truncation first; require a regular, single-link file and inspect its size.
Use nonblocking opens to reject FIFOs/special files without blocking. Deletion
uses `unlinkat` on the confined entry and never follows a replacement symlink.
It is a namespace-entry deletion, not an inode transaction against another writer.

On Windows, use a trusted local-drive root handle, handle-relative `NtCreateFile`
for each directory/leaf with `OBJ_DONT_REPARSE` and reparse-point open semantics,
and validate the opened objects before truncation. Reject junctions/reparse points,
non-disk/nonregular files and observed hard links. Enumerate through the directory
handle and delete through the validated file handle. Missing native API support
or unsupported roots fail closed; there is no canonicalize-and-absolute-reopen
fallback. Delete-share restrictions alone are not considered confinement.

Pinned handles refer to the authorized directory objects, even if a trusted OS
process renames them. Tests challenge symlink/junction replacement and preserved
outside sentinels. This is not isolation against a malicious same-credential OS
process that can independently modify these files or introduce new hard links
after validation. Native storage remains synchronous; GL-004 cannot preempt
arbitrary blocking filesystem I/O and does not account native buffers as VM bytes.

## Other filesystem routes

Gameplay cannot mint `_gl_bridge` metadata, set the editor structure property or
invoke `UpdateStructure`. The underlying deferred native update also requires
the actual engine editor hint, so changing a property cannot lose the caller
context and acquire editor authority. Real editor operations remain separate.
`_GL_NET.call` permits only its three documented teleport/coordinator metadata
methods; arbitrary host-key and bound-object method dispatch is denied.

Image, Sound and Animation have a separate read-only **trusted project resource**
capability. Direct external/user/drive/UNC paths are rejected. Project `res://`
components and resolved UIDs are checked, existing symlinks/reparse points are
rejected, and Roblox substitutions remain project-local. The engine's typed
ResourceLoader, packed resources and serialized dependencies remain trusted host
content. ResourceLoader can reopen paths and follow serialized dependencies: this
does not establish race-resistant loading of hostile project assets, confinement
against concurrent malicious project writers, a plugin sandbox or process-level
memory isolation. Do not expand GL-003 into such a claim.

## Errors and persistence limits

Errors use bounded `[Runtime:Capabilities]` or `[Runtime:Filesystem]` messages
without supplied paths, file contents or native pointers. Permission, invalid
path, missing file, unavailable root, I/O failure and resource bounds have distinct
dispositions. Missing reads return nil; a closing domain has a distinct bounded
capability diagnostic. DataStore cache updates follow successful native
writes/deletes; I/O failure now raises instead of reporting a successful
in-memory update. MemoryStore writes and Server Messaging publication likewise
propagate storage failure; Server local message delivery follows successful write.
Successful public service return shapes remain unchanged.

This is not GL-009: read/modify/write can race with another authorized process,
I/O failure can leave a partial write, and no atomicity/durability/locking improvement
is claimed. Rejected authorization/path/size operations perform no filesystem
mutation. GL-005, GL-017/018 and GL-020 adversarial qualification remain separate.
