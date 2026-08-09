extends SceneTree

const SAVE_PATH := "user://save_slot_1.json"
const BACKUP_PATH := "user://save_slot_1.backup.json"
const TEMP_PATH := "user://save_slot_1.tmp"
const NARRATIVE_DIRECTOR := preload(
	"res://game/narrative/narrative_director.gd"
)


func _initialize() -> void:
	_cleanup()
	var save_service := root.get_node("SaveService")
	var narrative = NARRATIVE_DIRECTOR.new()
	root.add_child(narrative)
	narrative.stage = narrative.ARCHIVE_MECHANISMS
	narrative.activated_archive_anchors.assign(narrative.ARCHIVE_ANCHOR_TEXT.keys())
	var player := Node3D.new()
	player.position = Vector3(2.5, 1.25, -8.0)
	player.rotation = Vector3(0.1, 0.8, -0.05)
	root.add_child(player)
	await process_frame

	assert(save_service.save_game(&"echo_archive", player) == OK)
	var first: Dictionary = save_service.load_game()
	assert(first.schema_version == 2)
	assert(first.build_version == "0.6.2-alpha")
	assert(first.saved_at_unix > 0)
	assert(first.player_position == [2.5, 1.25, -8.0])
	assert(first.player_rotation.size() == 3)

	player.position = Vector3(9.0, 2.0, 3.0)
	assert(save_service.save_game(&"lantern_city", player) == OK)
	assert(FileAccess.file_exists(BACKUP_PATH))
	var corrupt := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	assert(corrupt != null)
	corrupt.store_string("[]")
	corrupt.close()
	var recovered: Dictionary = save_service.load_game()
	assert(save_service.last_load_used_backup)
	assert(recovered.player_position == [2.5, 1.25, -8.0])

	var legacy_payload := {
		"schema_version": 1,
		"current_level_id": "grove",
		"player_position": [0.0, 1.0, 0.0],
		"world_state": {},
	}
	var legacy_file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	assert(legacy_file != null)
	legacy_file.store_string(JSON.stringify(legacy_payload))
	legacy_file.close()
	var migrated: Dictionary = save_service.load_game()
	assert(migrated.schema_version == 2)
	assert(migrated.build_version == "legacy")
	assert(migrated.player_rotation == [0.0, 0.0, 0.0])
	print("SAVE_SERVICE_TEST_OK schema=2 atomic_backup=recovered legacy=migrated")
	player.queue_free()
	narrative.queue_free()
	await process_frame
	_cleanup()
	call_deferred("quit")


func _cleanup() -> void:
	for path in [SAVE_PATH, BACKUP_PATH, TEMP_PATH]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
