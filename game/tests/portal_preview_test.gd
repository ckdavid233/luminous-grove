extends SceneTree

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
	var portal = main.get("_phase_portal")
	var player = main.get("_player")
	var gameplay_camera := player.find_child("Camera", true, false) as Camera3D
	var preview_source_camera := Camera3D.new()
	preview_source_camera.name = "PortalPreviewTestCamera"
	main.add_child(preview_source_camera)
	preview_source_camera.make_current()
	assert(await _wait_until_ready(streamer, ECHO_PATH))
	assert(portal.get_preview_layer() == 2)
	var preview_viewport := portal.get_preview_viewport() as SubViewport
	var preview_camera := preview_viewport.find_child(
		"AlternatePhaseCamera",
		true,
		false
	) as Camera3D
	assert(preview_viewport.size == Vector2i(640, 360))
	assert(preview_camera != null and preview_camera.cull_mask == 2)

	controller.set_unlocked(true)
	portal.configure_preview(preview_source_camera, 2)
	portal.visible = true
	preview_source_camera.global_position = Vector3(9.4, 3.15, 3.7)
	preview_source_camera.look_at(portal.global_position)
	var preview_updated := await _wait_for_preview_updates(portal, 2)
	if not preview_updated:
		print(
			"PORTAL_PREVIEW_DIAGNOSTIC visible=",
			portal.visible,
			" processing=",
			portal.is_processing(),
			" camera_current=",
			preview_source_camera.is_current(),
			" distance=",
			preview_source_camera.global_position.distance_to(portal.global_position),
			" behind=",
			preview_source_camera.is_position_behind(portal.global_position),
			" screen=",
			preview_source_camera.unproject_position(portal.global_position),
			" viewport=",
			root.size,
			" updates=",
			portal.preview_update_count,
		)
	assert(
		preview_updated,
		"A visible portal must repeatedly render the opposite phase"
	)

	preview_source_camera.global_position = Vector3(80.0, 4.0, 80.0)
	preview_source_camera.look_at(portal.global_position)
	await process_frame
	assert(
		preview_viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED,
		"A distant portal must stop its SubViewport"
	)

	assert(controller.request_shift())
	await physics_frame
	await process_frame
	assert(controller.active_phase == &"echo")
	assert(
		portal.get_preview_layer() == 1 and preview_camera.cull_mask == 1,
		"In the echo phase the portal must preview the present layer"
	)
	assert(gameplay_camera.cull_mask == 6)

	print(
		"PORTAL_PREVIEW_TEST_OK updates=%d size=%s reverse_layer=%d"
		% [
			portal.preview_update_count,
			preview_viewport.size,
			portal.get_preview_layer(),
		]
	)
	controller.request_shift()
	await physics_frame
	await process_frame
	streamer.clear_inactive_levels()
	main.queue_free()
	await process_frame
	call_deferred("quit")


func _wait_until_ready(streamer: Node, path: String) -> bool:
	for _frame in 600:
		if streamer.is_level_ready(path):
			return true
		await process_frame
	return false


func _wait_for_preview_updates(portal: Node, minimum_updates: int) -> bool:
	for _frame in 120:
		if portal.preview_update_count >= minimum_updates:
			return true
		await process_frame
	return false
