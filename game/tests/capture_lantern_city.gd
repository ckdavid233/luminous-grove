extends SceneTree

const PRESENT_OUTPUT := (
	"/home/cenkai/game_dev_plan/previews/lantern_city_present.png"
)
const ECHO_OUTPUT := (
	"/home/cenkai/game_dev_plan/previews/lantern_city_echo.png"
)
const CINEMATIC_OUTPUT := (
	"/home/cenkai/game_dev_plan/previews/lantern_city_cinematic.png"
)


func _initialize() -> void:
	DirAccess.remove_absolute(
		ProjectSettings.globalize_path("user://save_slot_1.json")
	)
	root.size = Vector2i(1280, 720)
	var main_scene := load("res://game/main/main.tscn") as PackedScene
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	var narrative = main.get("_narrative")
	narrative.stage = narrative.ARCHIVE_RESTORED
	main.call("_sync_world_to_narrative")
	main.call("_on_city_gate_entered")
	for _frame in 900:
		if main.get("_city_pair_ready"):
			break
		await process_frame
	assert(main.get("_city_pair_ready"))

	var player := main.get("_player") as CharacterBody3D
	player.global_position = Vector3(0.0, 1.0, 14.0)
	player.rotation = Vector3.ZERO
	player.get_node("Model").rotation = Vector3.ZERO
	for _frame in 24:
		await process_frame
	main.get("_toast_label").text = ""
	await _capture(PRESENT_OUTPUT)

	var phase_shift = main.get("_phase_shift")
	assert(phase_shift.request_shift())
	await physics_frame
	for _frame in 20:
		await process_frame
	await _capture(ECHO_OUTPUT)

	assert(phase_shift.request_shift())
	await physics_frame
	await process_frame
	main.call("_play_city_arrival_cinematic")
	for _frame in 18:
		await process_frame
	await _capture(CINEMATIC_OUTPUT)
	main.get("_cinematic_director").cancel_sequence()
	print(
		"LANTERN_CITY_CAPTURE_OK present=",
		PRESENT_OUTPUT,
		" echo=",
		ECHO_OUTPUT,
		" cinematic=",
		CINEMATIC_OUTPUT,
	)
	quit()


func _capture(output_path: String) -> void:
	await process_frame
	var image := root.get_texture().get_image()
	var error := image.save_png(output_path)
	assert(error == OK, "Lantern City screenshot must save")
