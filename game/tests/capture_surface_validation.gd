extends SceneTree

## Real Vulkan visual validation pass for the forest floor, shore mud, footprints
## and character presentation.  The prefix is selected with CAPTURE_PREFIX so
## the same camera path can be run from the pre-refinement worktree.

const OUTPUT_DIRECTORY := "/home/cenkai/game_dev_plan/previews"
const FRAME_SIZE := Vector2i(1280, 720)

var _prefix := "after"
var _main: Node3D
var _camera: Camera3D


func _initialize() -> void:
	_prefix = OS.get_environment("CAPTURE_PREFIX").strip_edges()
	if _prefix.is_empty():
		_prefix = "after"
	DirAccess.remove_absolute(
		ProjectSettings.globalize_path("user://save_slot_1.json")
	)
	root.size = FRAME_SIZE
	var main_scene := load("res://game/main/main.tscn") as PackedScene
	_main = main_scene.instantiate() as Node3D
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

	await _capture_view(
		"ground",
		Vector3(3.4, 1.25, 5.9),
		Vector3(-0.8, 0.04, 5.45),
		55.0,
	)
	await _capture_view(
		"wet_mud",
		Vector3(-13.0, 1.0, -0.9),
		Vector3(-11.0, -0.06, -3.15),
		56.0,
	)
	await _capture_footprints()
	await _capture_character()
	print(
		"SURFACE_VALIDATION_CAPTURE_OK prefix=",
		_prefix,
		" size=",
		FRAME_SIZE,
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
	await _save_image("%s_%s.png" % [_prefix, name])


func _capture_footprints() -> void:
	var grass := _main.get_node_or_null("Grass")
	if grass != null:
		grass.visible = false
	_camera.fov = 48.0
	_camera.global_position = Vector3(1.8, 0.82, 3.0)
	_camera.look_at(Vector3(-0.85, 0.1, 5.7))
	for _frame in 12:
		await process_frame
	await _save_image("%s_footprints_before.png" % _prefix)
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
	await _save_image("%s_footprints_after.png" % _prefix)


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
	await _save_image("%s_character_clean.png" % _prefix)


func _save_image(file_name: String) -> void:
	var image := root.get_texture().get_image()
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
	if _main != null and is_instance_valid(_main):
		if _main.has_method("_exit_tree"):
			_main.queue_free()
	for _frame in 12:
		await process_frame
		await physics_frame
	quit()
