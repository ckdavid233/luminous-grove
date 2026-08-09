extends SceneTree

const OUTPUT := "/home/cenkai/game_dev_plan/previews/archive_cinematic.png"
const ECHO_PATH := "res://content/levels/echo_ruins/echo_ruins.tscn"


func _initialize() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save_slot_1.json"))
	root.size = Vector2i(1280, 720)
	var main_scene := load("res://game/main/main.tscn") as PackedScene
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame

	var streamer = main.get("_world_streamer")
	var controller = main.get("_phase_shift")
	assert(await _wait_until_ready(streamer, ECHO_PATH))
	controller.set_unlocked(true)
	assert(controller.request_shift())
	await physics_frame
	await process_frame
	main.call("_play_archive_intro_cinematic")
	for _frame in 24:
		await process_frame
	assert(main.get("_cinematic_director").is_playing)
	assert(main.get("_cinematic_ui").visible)
	assert(not main.get("_cinematic_subtitle").text.is_empty())
	assert(root.get_texture().get_image().save_png(OUTPUT) == OK)
	main.get("_cinematic_director").request_skip()
	for _frame in 120:
		if not main.get("_cinematic_director").is_playing:
			break
		await process_frame
	print("CINEMATIC_CAPTURE_OK output=", OUTPUT)
	main.queue_free()
	await process_frame
	call_deferred("quit")


func _wait_until_ready(streamer: Node, path: String) -> bool:
	for _frame in 600:
		if streamer.is_level_ready(path):
			return true
		await process_frame
	return false
