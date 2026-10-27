# GL-016 fork updater isolation

Date: 2026-10-27. Base/main: `34edaa2adfe698d6527e5c5b9bc0159428b5db64`.
Branch: `maintenance/gl-016-fork-updater`. This implementation is not merged into
main. GL-020 functional integration and its pending security qualification are
unchanged.

## Policy and implementation

There is no qualified fork-owned production update channel. Runtime update
admission therefore fails closed in `plugin.gd.RuntimeUpdatesAllowed()`. This is
not a user setting, URL override or environment switch. Every runtime replacement
entry and asynchronous completion checks that policy before network, filesystem
or process actions. A matching SHA-256 is integrity evidence, not source/build
provenance, and cannot grant admission.

The guard covers automatic/manual checks, version responses, reinstall, archive
download and completion, hash download and completion, extraction, backup writes,
rollback/restore, historical selection and callbacks, staged DLL swaps, restart
countdowns/editor restart/external restart scripts, DLL cleanup, layout migration
and legacy version metadata synchronization. Rejected operations preserve even
partial download/recovery artifacts; there is no approved operation to clean up
on behalf of a new runtime install. Old backups are retained but not automatically
trusted or restored. The legacy implementation/endpoints remain behind the guard
for historical attribution; none is an enabled runtime channel.

The enabled editor plugin remains in `project.godot`. Its settings panel reports
the disabled channel in EN/ES/PT-BR; check/reinstall/history controls are disabled
and rollback is hidden. Missing-runtime warnings direct users to a verified fork
build rather than upstream reinstall instructions. Inspector tools, highlighting,
multiplayer editor controls and explicit JSON model/custom-autocomplete features
remain available. Upstream author attribution, catalog data URLs and licenses are
preserved. Catalog/custom downloads are optional editor data written to user
storage; they do not authorize installing a runtime archive.

## Recovery and future enablement

Keep the editor closed while manually installing or restoring a complete,
reviewed fork build or a previously verified complete fork snapshot. Preserve a
copy of the current working installation first. Verify the exact source revision,
dependency pins, platform build identity and qualification evidence using the
existing source/build instructions. The inherited `GodotLuau.zip`, upstream tags
and `.luau_backup` contents are not automatically accepted as fork-built artifacts.
No qualified production download channel is advertised here.

Future updater enablement needs an explicit reviewed policy for fork ownership,
immutable source/artifact linkage, supported platform identity, authenticity,
integrity, compatibility, interrupted installation and rollback provenance. Do
not toggle admission or substitute URLs as a shortcut. GL-010/011 and production
distribution remain independent unresolved work.

## Executed verification

`tests/editor/RunUpdaterIsolation.py` reuses the existing bounded fixture result
checker and launches the actual enabled plugin plus an observer plugin in a
headless Godot 4.7.1 editor. Each isolated project/profile contains sentinel fork
binaries, `.old`/`.new`/temporary files, legacy directories, version metadata,
backup, staged DLL and a valid but unverified replacement ZIP. Windows children
are hidden with crash UI suppressed; both platforms capture output and enforce
a 60-second deadline. APPDATA/LOCALAPPDATA or XDG profile locations are redirected
only for the child, preserving worker editor preferences.

```text
python tests/editor/RunUpdaterIsolation.py --godot <existing-Godot-4.7.1> --output <new-isolated-directory> --timeout 60
```

Windows and Linux each pass **596 assertions across 42 rejected operations**.
The actual plugin initializes its panel, inspector/highlighter and optional-data
controls. No runtime HTTP request or outdated timer is created. Assertions cover
missing/unavailable/unverified version metadata, upstream source override,
interrupted/failed/completed download callbacks, unavailable/malformed/mismatched
and matching hashes, apply/rollback/swap/cleanup/restart/history paths and a
purported project-setting opt-in. Every rejection preserves protected file hashes
and inventory and keeps the disabled state visible. Delayed migration is also
checked after its original timer interval. This is policy rejection before
metadata/hash interpretation, not qualification of an enabled update channel.

Explicit model and autocomplete requests traverse a localhost-only mock server,
save valid JSON in isolated user storage and leave the runtime unchanged. Those
two paths are the only mock requests. No production metadata/download endpoint,
editor restart or external apply process is invoked. The fixture intentionally
does not load its sentinel native DLL, so the captured missing-runtime warning
is expected; no script/parse errors occur in passing runs.

The first Linux fixture omitted HTTP response length headers, producing empty
bodies in Godot's HTTP client and failing the optional-data assertions. Proper
Content-Length/Content-Type/connection framing corrects the mock; that failed
attempt remains at `/opt/codex/godotluau/artifacts/gl016-updater-linux-1`.
Passing logs/results are under Linux `gl016-updater-linux-2` and Windows worker
`C:\Sandbox\Codex\Builds\GodotLuau\gl016-updater-windows-1`.
The [manifest](evidence/gl016-updater-isolation-2026-10-27.json) records source and
log hashes, commands, operations and results. No native rebuild is needed for
this GDScript/plugin-only change; the integrated native source is unchanged.

Disposition: **IMPLEMENTED AND FUNCTIONALLY VERIFIED ON DEDICATED BRANCH —
NOT MERGED.** Future GL-016 integration and production channel enablement require
separate authorization. The native updater/release/provenance gaps on canonical
main are not silently reclassified by an unmerged branch.
