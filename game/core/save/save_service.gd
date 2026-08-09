extends Node

const SAVE_PATH := "user://save_slot_1.json"
const BACKUP_PATH := "user://save_slot_1.backup.json"
const TEMP_PATH := "user://save_slot_1.tmp"
const SCHEMA_VERSION := 2
const BUILD_VERSION := "0.6.2-alpha"

var last_load_used_backup := false


func save_game(current_level_id: StringName, player: Node3D) -> Error:
	if player == null:
		return ERR_INVALID_PARAMETER
	var world_state := {}
	for node in get_tree().get_nodes_in_group("persistent"):
		if node.has_method("capture_state"):
			var persistent_id: String = str(node.get("persistent_id"))
			if not persistent_id.is_empty():
				world_state[persistent_id] = node.capture_state()

	var payload := {
		"schema_version": SCHEMA_VERSION,
		"build_version": BUILD_VERSION,
		"saved_at_unix": int(Time.get_unix_time_from_system()),
		"current_level_id": str(current_level_id),
		"player_position": _vector3_to_array(player.global_position),
		"player_rotation": _vector3_to_array(player.global_rotation),
		"world_state": world_state,
	}
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(payload, "\t"))
	file.flush()
	file.close()
	if _read_payload(TEMP_PATH).is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_PATH))
		return ERR_FILE_CORRUPT

	var save_absolute := ProjectSettings.globalize_path(SAVE_PATH)
	var backup_absolute := ProjectSettings.globalize_path(BACKUP_PATH)
	var temp_absolute := ProjectSettings.globalize_path(TEMP_PATH)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(backup_absolute)
		var backup_error := DirAccess.copy_absolute(save_absolute, backup_absolute)
		if backup_error != OK:
			DirAccess.remove_absolute(temp_absolute)
			return backup_error
		var remove_error := DirAccess.remove_absolute(save_absolute)
		if remove_error != OK:
			DirAccess.remove_absolute(temp_absolute)
			return remove_error
	var rename_error := DirAccess.rename_absolute(temp_absolute, save_absolute)
	if rename_error != OK and FileAccess.file_exists(BACKUP_PATH):
		DirAccess.copy_absolute(backup_absolute, save_absolute)
	return rename_error


func load_game() -> Dictionary:
	last_load_used_backup = false
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var payload := _read_payload(SAVE_PATH)
	if payload.is_empty() and FileAccess.file_exists(BACKUP_PATH):
		payload = _read_payload(BACKUP_PATH)
		last_load_used_backup = not payload.is_empty()
	if payload.is_empty():
		return {}
	return _migrate_payload(payload)


func _read_payload(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return {}
	var payload := parsed as Dictionary
	if (
		int(payload.get("schema_version", 0)) <= 0
		or not payload.get("world_state", {}) is Dictionary
		or not payload.get("player_position", []) is Array
	):
		return {}
	return payload


func _migrate_payload(payload: Dictionary) -> Dictionary:
	var migrated := payload.duplicate(true)
	var source_schema := int(migrated.get("schema_version", 1))
	if source_schema < 2:
		migrated["build_version"] = "legacy"
		migrated["saved_at_unix"] = 0
		migrated["player_rotation"] = [0.0, 0.0, 0.0]
	migrated["schema_version"] = SCHEMA_VERSION
	return migrated


func _vector3_to_array(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]
