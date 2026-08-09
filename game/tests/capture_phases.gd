extends SceneTree

const PRESENT_OUTPUT := "/home/cenkai/game_dev_plan/previews/phase_present.png"
const ECHO_OUTPUT := "/home/cenkai/game_dev_plan/previews/phase_echo.png"
const PORTAL_OUTPUT := "/home/cenkai/game_dev_plan/previews/rain_rift_portal.png"
const ECHO_PATH := "res://content/levels/echo_ruins/echo_ruins.tscn"


func _initialize() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save_slot_1.json"))
	root.size = Vector2i(1280, 720)
	var main_scene := load("res://game/main/main.tscn") as PackedScene
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame

	var camera := Camera3D.new()
	camera.fov = 59.0
	camera.cull_mask = 5
	camera.position = Vector3(11.5, 7.4, 13.5)
	main.add_child(camera)
	camera.look_at(Vector3(0.0, 1.25, -4.0))
	camera.make_current()
	for _frame in 80:
		await process_frame
	assert(root.get_texture().get_image().save_png(PRESENT_OUTPUT) == OK)

	var streamer = main.get("_world_streamer")
	var controller = main.get("_phase_shift")
	var portal = main.get("_phase_portal")
	assert(await _wait_until_ready(streamer, ECHO_PATH))
	controller.set_unlocked(true)
	portal.visible = true
	portal.configure_preview(camera, 2)
	camera.position = Vector3(9.4, 3.15, 3.7)
	camera.look_at(portal.global_position + Vector3(0.0, 0.1, 0.0))
	for _frame in 120:
		await process_frame
	assert(portal.preview_update_count > 20, "Visible portal preview must update")
	assert(root.get_texture().get_image().save_png(PORTAL_OUTPUT) == OK)

	assert(controller.request_shift())
	await physics_frame
	await process_frame
	camera.cull_mask = 6
	camera.position = Vector3(11.5, 7.4, 13.5)
	camera.look_at(Vector3(0.0, 1.25, -4.0))
	camera.make_current()
	for _frame in 100:
		await process_frame
	assert(root.get_texture().get_image().save_png(ECHO_OUTPUT) == OK)
	print(
		"PHASE_CAPTURE_OK present=",
		PRESENT_OUTPUT,
		" portal=",
		PORTAL_OUTPUT,
		" echo=",
		ECHO_OUTPUT
	)
	main.queue_free()
	await process_frame
	call_deferred("quit")


func _wait_until_ready(streamer: Node, path: String) -> bool:
	for _frame in 600:
		if streamer.is_level_ready(path):
			return true
		await process_frame
	return false
