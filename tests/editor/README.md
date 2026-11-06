# Editor updater isolation

Run a controlled headless editor, not the repository project:

```text
python tests/editor/RunUpdaterIsolation.py --godot <existing-Godot-4.7.1> --output <new-isolated-directory> --timeout 60
```

The output directory must not already exist. The runner copies the actual plugin,
enables it alongside `UpdaterIsolation.gd`, isolates editor/user profiles, seeds
sentinel installation/backup/staging files, and reuses the runtime runner's bounded
result checker. It checks runtime replacement rejection before metadata/download/
hash/apply/history/rollback/cleanup/restart side effects. Explicit optional JSON
downloads use only a localhost mock. It never enables a real release channel,
loads the sentinel binaries, opens a graphical editor or restarts the editor.

Results and stdout/stderr remain in the output tree. The normal missing-runtime
warning is expected because sentinels are not loadable binaries. Script/parse
errors, timeouts, failed assertions or unexpected mock requests fail the gate.
See [policy and evidence](../../newdocs/fork-updater-isolation.md).
