@tool
extends EditorPlugin

var Plugin: EditorPlugin
var Failed := false
var Checks := 0
var Operations: Array[String] = []
var Before: Dictionary

func _enter_tree() -> void:
	call_deferred("Run")

func Check(Value: bool, Description: String) -> void:
	Checks += 1
	if not Value:
		Failed = true
		print("[Editor:UpdaterTest] FAIL ", Description)

func FindUpdater(Root: Node) -> EditorPlugin:
	var Source: Script = Root.get_script()
	if Source and Source.resource_path == "res://addons/GodotLuauUpdater/plugin.gd": return Root as EditorPlugin
	for Child in Root.get_children():
		var Found := FindUpdater(Child)
		if Found: return Found
	return null

func SnapshotFolder(Path: String, Result: Dictionary) -> void:
	var Folder := DirAccess.open(Path)
	if not Folder: return
	for Name in Folder.get_files():
		var File := Path.path_join(Name)
		Result[File] = FileAccess.get_sha256(File)
	for Name in Folder.get_directories(): SnapshotFolder(Path.path_join(Name), Result)

func Snapshot() -> Dictionary:
	var Result := {}
	for Folder in ["res://GodotLuau", "res://bin", "res://icons", "res://DefaultScripts", "res://assets", "res://.luau_backup"]:
		SnapshotFolder(Folder, Result)
	for File in ["res://Version", "res://addons/GodotLuauUpdater/plugin.cfg", "res://addons/GodotLuauUpdater/installed_version.txt", "user://godotluau_update.zip", "user://_godotluau_apply.ps1", "user://candidate.dll"]:
		Result[File] = FileAccess.get_sha256(File) if FileAccess.file_exists(File) else "missing"
	return Result

func Observe(Description: String) -> void:
	Check(Snapshot() == Before, Description + ": installed files/backups/temp download preserved")
	for Property in ["_http_version", "_http_download", "_http_hash", "_http_tags", "_http_tagver", "_outdated_timer"]:
		Check(Plugin.get(Property) == null, Description + ": no runtime request/timer " + Property)
	for Property in ["_ver_btn", "_reinstall_btn", "_versions_btn", "_rollback_btn"]:
		var ControlNode: Button = Plugin.get(Property)
		Check(is_instance_valid(ControlNode) and ControlNode.disabled, Description + ": disabled control " + Property)
	var Status: Label = Plugin.get("_ver_label")
	Check(Status.text == Plugin.call("_t", "bar_fork_disabled") % Plugin.call("_get_local_version"), Description + ": visible policy")
	Check(not bool(Plugin.call("RuntimeUpdatesAllowed")), Description + ": channel stays closed")

func Run() -> void:
	Plugin = FindUpdater(get_tree().root)
	Check(Plugin != null, "actual enabled EditorPlugin initialized")
	if Plugin == null:
		get_tree().quit(1)
		return
	for Property in ["_settings_panel", "_inspector_plugin", "_luau_hl", "_cac_status", "_aim_status"]:
		Check(is_instance_valid(Plugin.get(Property)), "editor feature initialized " + Property)
	# Even a purported opt-in, source override or already downloaded matching hash
	# cannot grant authority while no qualified fork channel exists.
	ProjectSettings.set_setting("godot_luau/runtime_updates_enabled", true)
	Plugin.set("_zip_url_override", "https://raw.githubusercontent.com/Pimpoli/GodotLuau/main/GodotLuau.zip")
	Plugin.set("_pending_tag", "unverified-history")
	var Versions: Array[Dictionary] = [{"tag": "unverified-history", "ver": "v999", "num": "v999"}]
	Plugin.set("_tag_list", Versions)
	DirAccess.copy_absolute(ProjectSettings.globalize_path("res://candidate.zip"), ProjectSettings.globalize_path("user://godotluau_update.zip"))
	var Candidate := FileAccess.open("user://candidate.dll", FileAccess.WRITE)
	Candidate.store_string("UNVERIFIED REPLACEMENT")
	Candidate.close()
	var Restart := FileAccess.open("user://_godotluau_apply.ps1", FileAccess.WRITE)
	Restart.store_string("preserve existing recovery artifact")
	Restart.close()
	var Staged: Array[Dictionary] = [{"src": ProjectSettings.globalize_path("user://candidate.dll"), "dst": ProjectSettings.globalize_path("res://GodotLuau/bin/fork.dll")}]
	Plugin.set("_windows_staged_dlls", Staged)
	Before = Snapshot()
	Observe("normal initialization")
	var Headers := PackedStringArray()
	var Cases: Array = [
		["normal check/unavailable channel", "_check_for_update", []],
		["reinstall", "_start_reinstall", []],
		["unexpected upstream source", "_start_download", []],
		["hash request", "_start_hash_verify", []],
		["missing metadata", "_on_version_received", [HTTPRequest.RESULT_SUCCESS, 200, Headers, PackedByteArray()]],
		["unverified metadata", "_on_version_received", [HTTPRequest.RESULT_SUCCESS, 200, Headers, "v999".to_utf8_buffer()]],
		["metadata unavailable", "_on_version_received", [HTTPRequest.RESULT_CANT_CONNECT, 0, Headers, PackedByteArray()]],
		["interrupted download", "_on_download_completed", [HTTPRequest.RESULT_CONNECTION_ERROR, 0, Headers, PackedByteArray()]],
		["failed download", "_on_download_completed", [HTTPRequest.RESULT_SUCCESS, 404, Headers, PackedByteArray()]],
		["completed unverified archive", "_on_download_completed", [HTTPRequest.RESULT_SUCCESS, 200, Headers, PackedByteArray()]],
		["hash unavailable", "_on_hash_received", [HTTPRequest.RESULT_CANT_CONNECT, 0, Headers, PackedByteArray()]],
		["malformed hash", "_on_hash_received", [HTTPRequest.RESULT_SUCCESS, 200, Headers, "invalid".to_utf8_buffer()]],
		["mismatched hash", "_on_hash_received", [HTTPRequest.RESULT_SUCCESS, 200, Headers, "0".repeat(64).to_utf8_buffer()]],
		["matching hash is not provenance", "_on_hash_received", [HTTPRequest.RESULT_SUCCESS, 200, Headers, FileAccess.get_sha256("user://godotluau_update.zip").to_utf8_buffer()]],
		["archive apply", "_apply_update", []],
		["failed apply cleanup", "_fail_apply", []],
		["backup replacement", "_backup_current", [PackedStringArray(["GodotLuau/bin/fork.dll"]), "v999"]],
		["unverified rollback", "_on_rollback_pressed", []],
		["direct backup restore", "_restore_from_backup", []],
		["rollback availability", "_can_rollback", []],
		["rollback UI refresh", "_refresh_rollback_btn", []],
		["staged DLL swap", "_try_rename_and_replace", []],
		["automatic restart", "_auto_restart_countdown", []],
		["editor restart", "_do_editor_restart", []],
		["external restart script", "_apply_windows_update_legacy", []],
		["historical versions", "_on_versions_pressed", []],
		["historical metadata fetch", "_fetch_version_page", []],
		["historical metadata callback", "_on_commits_received", [HTTPRequest.RESULT_SUCCESS, 200, Headers, "[]".to_utf8_buffer()]],
		["historical selection", "_on_version_chosen", [0]],
		["historical version callback", "_on_tag_version_received", [HTTPRequest.RESULT_SUCCESS, 200, Headers, "v999".to_utf8_buffer()]],
		["historical archive selection", "_install_pending_tag", ["v999"]],
		["startup DLL cleanup", "_cleanup_old_dlls", []],
		["legacy layout migration", "_migrate_old_layout", []],
		["legacy directory deletion", "_remove_dir_recursive", [ProjectSettings.globalize_path("res://bin")]],
		["backup deletion", "_rmdir_recursive", [ProjectSettings.globalize_path("res://.luau_backup")]],
		["backup collection", "_collect_backup", [ProjectSettings.globalize_path("res://.luau_backup/files"), "", ProjectSettings.globalize_path("res://"), ProjectSettings.globalize_path("user://staging"), []]],
		["version metadata synchronization", "_sync_plugin_cfg", []],
		["outdated timer", "_setup_outdated_warning", ["v1", "v999"]],
		["idle UI reset", "_reset_ver_idle", []]
	]
	for Case: Array in Cases:
		var Result: Variant = Plugin.callv(Case[1], Case[2])
		if Case[1] in ["_restore_from_backup", "_can_rollback", "_try_rename_and_replace"]: Check(Result == false, Case[0] + ": rejected result")
		Operations.append(Case[0])
		Observe(Case[0])
	for Action in ["download", "restart", "apply"]:
		Plugin.set("_bar_action", Action)
		Plugin.call("_on_action_pressed")
		Operations.append("action " + Action)
		Observe("action " + Action)
	await get_tree().create_timer(3.2).timeout
	Observe("no delayed startup migration")
	# Explicit optional data downloads remain usable; only localhost fixture URLs.
	var Port := int(ProjectSettings.get_setting("updater_test/port"))
	ProjectSettings.set_setting("godot_luau/custom_autocomplete_url", "http://127.0.0.1:%d/autocomplete.json" % Port)
	ProjectSettings.set_setting("godot_luau/ai_model_url", "http://127.0.0.1:%d/model.json" % Port)
	ProjectSettings.set_setting("godot_luau/ai_model_selected", "custom")
	Plugin.call("_download_custom_ac")
	Plugin.call("_download_ai_model")
	var Deadline := Time.get_ticks_msec() + 5000
	while Plugin.get("_http_autocomplete") != null or Plugin.get("_http_aimodel") != null:
		if Time.get_ticks_msec() > Deadline: Check(false, "bounded optional data downloads"); break
		await get_tree().process_frame
	Check(JSON.parse_string(FileAccess.get_file_as_string("user://godotluau_custom_autocomplete.json")) is Array, "optional autocomplete download preserved")
	Check(JSON.parse_string(FileAccess.get_file_as_string(Plugin.call("_ai_model_path"))) is Dictionary, "optional model download preserved")
	Observe("optional features do not replace runtime")
	var Evidence := FileAccess.open("res://fixture-results.json", FileAccess.WRITE)
	Evidence.store_string(JSON.stringify({"Checks": Checks, "Operations": Operations, "Passed": not Failed}))
	Evidence.close()
	print("[Editor:UpdaterTest] ", "FAIL" if Failed else "PASS", " checks=", Checks, " rejected_operations=", Operations.size())
	get_tree().quit(1 if Failed else 0)
