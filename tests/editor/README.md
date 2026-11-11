# Editor updater isolation

GL-051 native authoring uses the actual registered Luau ScriptEditor path:

```text
python tests/editor/RunNativeAuthoring.py --godot <existing-official-Godot-4.7.1-editor> --extension <matching-GodotLuau-library> --output <fresh-directory> --timeout 60
```

This runs a hidden headless editor with an isolated profile and one fixture plugin.
It reuses production metadata/diagnostic cases, opens a real `.lua` resource and
requests completion through Godot's CodeEdit/ScriptLanguage route. No game source
executes; no updater plugin is enabled. Logs/results retain the library hash.
This does not establish a runtime debugger or graphical game correctness.

The separate updater isolation check follows.

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
