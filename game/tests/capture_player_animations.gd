extends SceneTree

const OUTPUT_DIRECTORY := "/home/cenkai/game_dev_plan/previews"


func _initialize() -> void:
	DirAccess.remove_absolute(
		ProjectSettings.globalize_path("user://save_slot_1.json")
	)
	root.size = Vector2i(1280, 720)
	var main_scene := load("res://game/main/main.tscn") as PackedScene
	var main := main_scene.instantiate()
	root.add_child(main)
	for _frame in 12:
		await process_frame

	var player := main.find_child("Player", true, false)
	assert(player != null)
	var spring_arm := player.find_child("SpringArm3D", true, false) as SpringArm3D
	var gameplay_camera := player.find_child("Camera", true, false) as Camera3D
	assert(spring_arm != null and gameplay_camera != null)
	# Use a close validation lens so arm swing, torso weight and the hand reach
	# are visible in the evidence images; this does not alter the shipped camera.
	spring_arm.spring_length = 1.9
	gameplay_camera.fov = 47.0
	if main.has_method("_set_gameplay_hud_visible"):
		main.call("_set_gameplay_hud_visible", false)
	var animation_tree := player.find_child(
		"AnimationTree",
		true,
		false
	) as AnimationTree
	var animation_player := player.find_child(
		"AnimationPlayer",
		true,
		false
	) as AnimationPlayer
	assert(animation_tree != null)
	assert(animation_player != null)
	animation_tree.active = false

	await _capture_pose(
		player,
		animation_player,
		&"Walk",
		0.0,
		OUTPUT_DIRECTORY + "/realistic_walk_contact.png",
	)
	await _capture_pose(
		player,
		animation_player,
		&"Walk",
		0.25,
		OUTPUT_DIRECTORY + "/realistic_walk_passing.png",
	)
	await _capture_pose(
		player,
		animation_player,
		&"Run",
		0.12,
		OUTPUT_DIRECTORY + "/realistic_run.png",
	)
	await _capture_pose(
		player,
		animation_player,
		&"Jump",
		0.3,
		OUTPUT_DIRECTORY + "/realistic_jump.png",
	)
	await _capture_pose(
		player,
		animation_player,
		&"Fall",
		0.45,
		OUTPUT_DIRECTORY + "/realistic_fall.png",
	)
	await _capture_pose(
		player,
		animation_player,
		&"Land",
		0.08,
		OUTPUT_DIRECTORY + "/realistic_land.png",
	)
	await _capture_pose(
		player,
		animation_player,
		&"Interact",
		0.625,
		OUTPUT_DIRECTORY + "/realistic_interact.png",
	)
	print(
		"PLAYER_ANIMATION_CAPTURE_OK outputs=realistic_walk_contact.png,"
		+ "realistic_walk_passing.png,realistic_run.png,realistic_jump.png,"
		+ "realistic_fall.png,realistic_land.png,realistic_interact.png"
	)
	quit()


func _capture_pose(
	player: Node,
	animation_player: AnimationPlayer,
	animation_name: StringName,
	time: float,
	output_path: String,
) -> void:
	player.set("velocity", Vector3(2.4, 0.0, 0.0) if animation_name in [&"Walk", &"Run"] else Vector3.ZERO)
	player.set("_is_sprinting", animation_name == &"Run")
	player.set("_interaction_time_left", 0.82 if animation_name == &"Interact" else 0.0)
	player.set("_animation_state", animation_name)
	# Sample the procedural layer at the same phase as the authored clip.  A
	# single screenshot frame otherwise always lands near gait zero and hides
	# the shoulder/hip counter-swing we need to validate visually.
	player.set("_visual_time", time * TAU * 1.5)
	player.set("_visual_previous_speed", 2.4 if animation_name in [&"Walk", &"Run"] else 0.0)
	animation_player.play(animation_name)
	animation_player.seek(time, true)
	player.call("_update_visual_motion", 0.016)
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	var error := image.save_png(output_path)
	assert(error == OK, "Player animation screenshot must save")
