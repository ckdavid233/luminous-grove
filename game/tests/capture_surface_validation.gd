extends SceneTree

## Real Vulkan visual validation pass for the forest floor, shore mud, footprints
## and character presentation.  The prefix is selected with CAPTURE_PREFIX so
## the same camera path can be run from the pre-refinement worktree.

const OUTPUT_DIRECTORY := "/home/cenkai/game_dev_plan/previews"
const DEFAULT_FRAME_SIZE := Vector2i(1280, 720)

var _prefix := "after"
var _resolution := DEFAULT_FRAME_SIZE
var _resolution_label := ""
var _only_shot := ""
var _native_window := false
var _main: Node3D
var _camera: Camera3D
var _capture_viewport: Viewport
var _offscreen_viewport: SubViewport


func _initialize() -> void:
	_prefix = OS.get_environment("CAPTURE_PREFIX").strip_edges()
	if _prefix.is_empty():
		_prefix = "after"
	_only_shot = OS.get_environment("CAPTURE_ONLY").strip_edges().to_lower()
	_native_window = OS.get_environment("CAPTURE_NATIVE").strip_edges() == "1"
	var requested_resolution := OS.get_environment("CAPTURE_RESOLUTION").strip_edges().to_lower()
	if requested_resolution == "3840x2160":
		_resolution = Vector2i(3840, 2160)
		_resolution_label = "_4k"
	DirAccess.remove_absolute(
		ProjectSettings.globalize_path("user://save_slot_1.json")
	)
	# The default 4K proof uses a real Vulkan SubViewport. When CAPTURE_NATIVE=1,
	# use the actual X11 window instead; the caller must provide a 3840x2160 mode.
	root.size = _resolution if _native_window else DEFAULT_FRAME_SIZE
	if _native_window and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(_resolution)
	_capture_viewport = root
	var main_scene := load("res://game/main/main.tscn") as PackedScene
	_main = main_scene.instantiate() as Node3D
	if _resolution_label == "_4k" and not _native_window:
		_offscreen_viewport = SubViewport.new()
		_offscreen_viewport.name = "FourKValidationViewport"
		_offscreen_viewport.size = _resolution
		_offscreen_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_offscreen_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
		_offscreen_viewport.own_world_3d = true
		root.add_child(_offscreen_viewport)
		_capture_viewport = _offscreen_viewport
		_offscreen_viewport.add_child(_main)
	else:
		root.add_child(_main)
	for _frame in 36:
		await process_frame
	for canvas in _main.find_children("*", "CanvasLayer", true, false):
		(canvas as CanvasLayer).visible = false
	_camera = Camera3D.new()
	_camera.fov = 52.0
	_camera.cull_mask = 5
	_main.add_child(_camera)
	_camera.make_current()

	if _should_capture("ground"):
		await _capture_view(
			"ground",
			Vector3(3.4, 1.25, 5.9),
			Vector3(-0.8, 0.04, 5.45),
			55.0,
		)
	if _should_capture("wet_mud"):
		await _capture_view(
			"wet_mud",
			Vector3(-13.0, 1.0, -0.9),
			Vector3(-11.0, -0.06, -3.15),
			56.0,
		)
	if _should_capture("footprints"):
		await _capture_footprints()
	if _should_capture("character"):
		await _capture_character()
	if _should_capture("tree"):
		await _capture_tree()
	if _should_capture("lake"):
		await _capture_lake()
	print(
		"SURFACE_VALIDATION_CAPTURE_OK prefix=",
		_prefix,
		" size=",
		_resolution,
		" only=",
		_only_shot if not _only_shot.is_empty() else "all",
	)
	await _shutdown_and_quit()


func _capture_view(
	name: String,
	position: Vector3,
	target: Vector3,
	fov: float,
) -> void:
	_camera.fov = fov
	_camera.global_position = position
	_camera.look_at(target)
	for _frame in 30:
		await process_frame
	await _save_image(_file_name(name))


func _capture_footprints() -> void:
	var grass := _main.get_node_or_null("Grass")
	if grass != null:
		grass.visible = false
	_camera.fov = 48.0
	_camera.global_position = Vector3(1.8, 0.82, 3.0)
	_camera.look_at(Vector3(-0.85, 0.1, 5.7))
	for _frame in 12:
		await process_frame
	await _save_image(_file_name("footprints_before"))
	var footprints := _main.get_node_or_null("Footprints")
	if footprints != null and footprints.has_method("stamp"):
		var positions := [
			Vector3(1.95, 0.0, 6.8),
			Vector3(1.5, 0.0, 5.9),
			Vector3(1.0, 0.0, 5.0),
			Vector3(0.5, 0.0, 4.2),
		]
		for index in positions.size():
			var position: Vector3 = positions[index]
			# The path mesh is intentionally a few centimetres above the terrain;
			# put the decal above that visual layer so it cannot z-fight or hide.
			position.y = _terrain_height(position.x, position.z) + 0.09
			footprints.stamp(
				position,
				_terrain_normal(position.x, position.z),
				&"dry_soil",
				0.96,
			)
		for footprint in footprints.get_children():
			if footprint is MeshInstance3D and footprint.visible:
				footprint.scale = Vector3.ONE * 1.55
	for _frame in 8:
		await process_frame
	await _save_image(_file_name("footprints_after"))


func _capture_character() -> void:
	var player := _main.find_child("Player", true, false)
	if player == null:
		return
	var animation_tree := player.find_child(
		"AnimationTree",
		true,
		false,
	) as AnimationTree
	var animation_player := player.find_child(
		"AnimationPlayer",
		true,
		false,
	) as AnimationPlayer
	if animation_tree != null:
		animation_tree.active = false
	if animation_player != null:
		animation_player.play(&"Interact")
		animation_player.seek(0.625, true)
	_camera.fov = 42.0
	_camera.global_position = Vector3(3.2, 1.72, 8.75)
	_camera.look_at(player.global_position + Vector3.UP * 1.05)
	for _frame in 8:
		await process_frame
	await _save_image(_file_name("character_clean"))


func _capture_tree() -> void:
	var trees := _main.get_node_or_null("Forest/DetailedTrees_1") as MultiMeshInstance3D
	if trees == null or trees.multimesh == null or trees.multimesh.visible_instance_count == 0:
		return
	trees.multimesh.visible_instance_count = 1
	var trees_two := _main.get_node_or_null("Forest/DetailedTrees_2")
	var trees_three := _main.get_node_or_null("Forest/DetailedTrees_3")
	if trees_two != null:
		trees_two.visible = false
	if trees_three != null:
		trees_three.visible = false
	var tree_transform := trees.multimesh.get_instance_transform(0)
	var target := tree_transform.origin + Vector3.UP * 3.6 * tree_transform.basis.get_scale().y
	_camera.fov = 48.0
	_camera.global_position = target + Vector3(6.8, 1.15, 6.8)
	_camera.look_at(target)
	for _frame in 60:
		await process_frame
	await _save_image(_file_name("tree_detail"))


func _capture_lake() -> void:
	var forest := _main.get_node_or_null("Forest")
	if forest != null:
		forest.visible = false
	_camera.fov = 58.0
	_camera.cull_mask = 5
	_camera.global_position = Vector3(-8.0, 3.25, -1.4)
	_camera.look_at(Vector3(-8.0, 0.0, -8.0))
	for _frame in 90:
		await process_frame
	await _save_image(_file_name("lake"))
	var water = _main.get("_water")
	if water == null:
		return
	water.set_visual_quality_profile(&"high")
	water.set("visual_effects_enabled", true)
	water.set("visual_effects_auto_cleanup", false)
	_camera.global_position = Vector3(-8.0, 2.15, -3.75)
	_camera.look_at(Vector3(-8.0, 0.06, -6.4))
	water.call(
		"_create_surface_splash",
		Vector3(-8.0, water.global_position.y, -6.4),
		1.3,
		&"water_entry",
	)
	for _frame in 4:
		await physics_frame
		await process_frame
	await _save_image(_file_name("lake_splash"))


func _should_capture(name: String) -> bool:
	return _only_shot.is_empty() or _only_shot == name


func _file_name(name: String) -> String:
	return "%s_%s%s.png" % [_prefix, name, _resolution_label]


func _save_image(file_name: String) -> void:
	var image := _capture_viewport.get_texture().get_image()
	assert(
		image.get_size() == _resolution,
		"Validation viewport size mismatch: %s != %s" % [image.get_size(), _resolution],
	)
	var error := image.save_png(OUTPUT_DIRECTORY + "/" + file_name)
	assert(error == OK, "Validation screenshot must save: " + file_name)


func _terrain_height(world_x: float, world_z: float) -> float:
	var terrain_script := load("res://game/world/forest_terrain.gd")
	return terrain_script.height_at(world_x, world_z)


func _terrain_normal(world_x: float, world_z: float) -> Vector3:
	var epsilon := 0.08
	var height_left := _terrain_height(world_x - epsilon, world_z)
	var height_right := _terrain_height(world_x + epsilon, world_z)
	var height_back := _terrain_height(world_x, world_z - epsilon)
	var height_forward := _terrain_height(world_x, world_z + epsilon)
	return Vector3(
		height_left - height_right,
		epsilon * 2.0,
		height_back - height_forward,
	).normalized()


func _shutdown_and_quit() -> void:
	# A validation camera creates transient render buffers on the active
	# viewport. Release it before Main starts detaching meshes; otherwise
	# Forward+ can report the camera's seven Texture RIDs as leaked at exit.
	# Give the active camera a few submitted frames even when CAPTURE_ONLY skips
	# every shot, so the renderer can retire transient buffers cleanly.
	for _frame in 4:
		await process_frame
	if _camera != null and is_instance_valid(_camera):
		_camera.current = false
		_camera.queue_free()
		_camera = null
		for _frame in 4:
			await process_frame
	if _main != null and is_instance_valid(_main):
		if _main.has_method("shutdown"):
			_main.shutdown()
		if _main.has_method("_exit_tree"):
			_main.queue_free()
	if _offscreen_viewport != null and is_instance_valid(_offscreen_viewport):
		_offscreen_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_offscreen_viewport.world_3d = null
		_offscreen_viewport.queue_free()
	_offscreen_viewport = null
	_capture_viewport = null
	_main = null
	for _frame in 120:
		await process_frame
		await physics_frame
	quit()
