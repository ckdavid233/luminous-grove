extends SceneTree

const PRESENT_OUTPUT := "/home/cenkai/game_dev_plan/previews/rain_eye_present.png"
const ECHO_OUTPUT := "/home/cenkai/game_dev_plan/previews/rain_eye_echo.png"
const FINAL_OUTPUT := "/home/cenkai/game_dev_plan/previews/rain_eye_final_choices.png"
const CINEMATIC_OUTPUT := (
	"/home/cenkai/game_dev_plan/previews/rain_eye_cinematic.png"
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
	narrative.stage = narrative.RAIN_EYE
	narrative.has_entered_rain_eye = true
	main.call("_sync_world_to_narrative")
	main.call("_update_quest_ui")
	for _frame in 900:
		if main.get("_rain_eye_pair_ready"):
			break
		await process_frame
	assert(main.get("_rain_eye_pair_ready"))

	var player := main.get("_player") as CharacterBody3D
	player.global_position = Vector3(0.0, 1.0, 15.0)
	player.rotation = Vector3.ZERO
	player.get_node("Model").rotation = Vector3.ZERO
	main.get("_toast_label").text = ""
	for _frame in 20:
		await process_frame
	await _capture(PRESENT_OUTPUT)

	player.global_position = Vector3(0.0, 1.0, 9.8)
	var phase_shift = main.get("_phase_shift")
	assert(phase_shift.request_shift())
	await physics_frame
	for _frame in 18:
		await process_frame
	await _capture(ECHO_OUTPUT)

	assert(phase_shift.request_shift())
	await physics_frame
	await process_frame
	main.call("_play_rain_eye_entry_cinematic")
	for _frame in 18:
		await process_frame
	await _capture(CINEMATIC_OUTPUT)
	main.get("_cinematic_director").cancel_sequence()
	await process_frame
	for seal_id in [&"eye_grove", &"eye_archive", &"eye_city"]:
		assert(narrative.activate_rain_eye_seal(seal_id))
	main.call("_sync_world_to_narrative")
	player.global_position = Vector3(0.0, 1.0, -15.5)
	for _frame in 12:
		await process_frame
	await _capture(FINAL_OUTPUT)
	print(
		"RAIN_EYE_CAPTURE_OK present=",
		PRESENT_OUTPUT,
		" echo=",
		ECHO_OUTPUT,
		" final=",
		FINAL_OUTPUT,
		" cinematic=",
		CINEMATIC_OUTPUT,
	)
	quit()


func _capture(output_path: String) -> void:
	await process_frame
	var image := root.get_texture().get_image()
	var error := image.save_png(output_path)
	assert(error == OK, "Rain Eye screenshot must save")
