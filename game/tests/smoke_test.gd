extends SceneTree


func _initialize() -> void:
	DirAccess.remove_absolute(
		ProjectSettings.globalize_path("user://save_slot_1.json")
	)
	var main_scene := load("res://game/main/main.tscn") as PackedScene
	assert(main_scene != null, "Main scene must load")
	var main := main_scene.instantiate()
	assert(main != null, "Main scene must instantiate")
	root.add_child(main)
	await process_frame
	assert(root.find_child("Player", true, false) != null, "Player must exist")
	assert(root.find_child("Shrine", true, false) != null, "Shrine must exist")
	assert(root.find_child("WindBell", true, false) != null, "WindBell must exist")
	var streamer = main.get("_world_streamer")
	for _frame in 300:
		if streamer.is_level_ready("res://content/levels/echo_ruins/echo_ruins.tscn"):
			break
		await process_frame
	assert(
		streamer.is_level_ready("res://content/levels/echo_ruins/echo_ruins.tscn"),
		"Echo realm background preload must complete"
	)
	print("SMOKE_TEST_OK")
	streamer.clear_inactive_levels()
	if streamer.has_method("shutdown"):
		streamer.shutdown()
	main.queue_free()
	for _frame in 30:
		await process_frame
		await physics_frame
	call_deferred("quit")
