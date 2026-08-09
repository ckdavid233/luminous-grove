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
		animation_player,
		&"Walk",
		0.0,
		OUTPUT_DIRECTORY + "/realistic_walk_contact.png",
	)
	await _capture_pose(
		animation_player,
		&"Walk",
		0.25,
		OUTPUT_DIRECTORY + "/realistic_walk_passing.png",
	)
	await _capture_pose(
		animation_player,
		&"Run",
		0.12,
		OUTPUT_DIRECTORY + "/realistic_run.png",
	)
	await _capture_pose(
		animation_player,
		&"Jump",
		0.3,
		OUTPUT_DIRECTORY + "/realistic_jump.png",
	)
	await _capture_pose(
		animation_player,
		&"Fall",
		0.45,
		OUTPUT_DIRECTORY + "/realistic_fall.png",
	)
	await _capture_pose(
		animation_player,
		&"Land",
		0.08,
		OUTPUT_DIRECTORY + "/realistic_land.png",
	)
	await _capture_pose(
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
	animation_player: AnimationPlayer,
	animation_name: StringName,
	time: float,
	output_path: String,
) -> void:
	animation_player.play(animation_name)
	animation_player.seek(time, true)
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	var error := image.save_png(output_path)
	assert(error == OK, "Player animation screenshot must save")
