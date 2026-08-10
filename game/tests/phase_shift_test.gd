extends SceneTree

const ECHO_PATH := "res://content/levels/echo_ruins/echo_ruins.tscn"


func _initialize() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save_slot_1.json"))
	var main_scene := load("res://game/main/main.tscn") as PackedScene
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	var streamer = main.get("_world_streamer")
	var controller = main.get("_phase_shift")
	var water = main.get("_water")
	assert(streamer != null and controller != null)
	assert(await _wait_until_ready(streamer, ECHO_PATH), "Echo realm must preload asynchronously")
	var echo := streamer.get_level(ECHO_PATH) as Node3D
	assert(echo != null and echo.visible, "Inactive echo visuals stay available to the portal")
	assert(echo.process_mode == Node.PROCESS_MODE_DISABLED)
	assert(water.visible, "Present world starts visible")
	var echo_floor := echo.find_child("EchoFloor", true, false) as StaticBody3D
	assert(echo_floor != null and echo_floor.collision_layer == 0)
	var echo_mesh := echo.find_child("SuspendedRainPool", true, false) as VisualInstance3D
	assert(echo_mesh != null and echo_mesh.layers == 2)

	controller.set_unlocked(true)
	assert(controller.request_shift())
	await physics_frame
	await process_frame
	assert(controller.active_phase == &"echo")
	assert(echo.visible and not water.visible)
	assert(echo_floor != null and echo_floor.collision_layer == 1)
	var gameplay_camera := main.get("_player").find_child("Camera", true, false) as Camera3D
	assert(gameplay_camera.cull_mask == 6)
	assert(echo.find_children("MemoryStone_*", "RigidBody3D", true, false).size() == 10)

	assert(controller.request_shift())
	await physics_frame
	await process_frame
	assert(controller.active_phase == &"present")
	assert(echo.visible and water.visible)
	assert(echo_floor.collision_layer == 0)
	assert(gameplay_camera.cull_mask == 5)

	for _iteration in 98:
		assert(controller.request_shift())
		await physics_frame
		await process_frame
	assert(controller.active_phase == &"present")
	assert(streamer.get_resident_paths().size() == 1)
	assert(main.find_children("EchoRuins", "", true, false).size() == 1)
	print("PHASE_SHIFT_TEST_OK shifts=100 resident=", streamer.get_resident_paths())
	assert(streamer.clear_inactive_levels() == 1)
	if streamer.has_method("shutdown"):
		streamer.shutdown()
	if main.has_method("shutdown"):
		main.shutdown()
	main.queue_free()
	for _frame in 120:
		await process_frame
		await physics_frame
	main_scene = null
	call_deferred("quit")


func _wait_until_ready(streamer: Node, path: String) -> bool:
	for _frame in 600:
		if streamer.is_level_ready(path):
			return true
		await process_frame
	return false
