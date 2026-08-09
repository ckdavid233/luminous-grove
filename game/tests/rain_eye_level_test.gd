extends SceneTree

const PRESENT_PATH := "res://content/levels/rain_eye/rain_eye_present.tscn"
const ECHO_PATH := "res://content/levels/rain_eye/rain_eye_echo.tscn"


func _initialize() -> void:
	var present_scene := load(PRESENT_PATH) as PackedScene
	var echo_scene := load(ECHO_PATH) as PackedScene
	assert(present_scene != null and echo_scene != null)
	var present := present_scene.instantiate()
	var echo := echo_scene.instantiate()
	root.add_child(present)
	root.add_child(echo)
	await process_frame
	await physics_frame

	assert(
		present.find_children("MemoryPath_*", "StaticBody3D", true, false).size()
		== 4,
	)
	assert(
		echo.find_children("MemoryPath_*", "StaticBody3D", true, false).size()
		== 3,
	)
	assert(
		present.find_children(
			"CrossPhaseFragment_*",
			"RigidBody3D",
			true,
			false,
		).size()
		== 7,
	)
	assert(
		echo.find_children(
			"CrossPhaseFragment_*",
			"RigidBody3D",
			true,
			false,
		).size()
		== 7,
	)
	var present_seals: Array = present.get_rain_eye_seals()
	var echo_seals: Array = echo.get_rain_eye_seals()
	var present_trials: Array = present.get_rain_eye_trials()
	var echo_trials: Array = echo.get_rain_eye_trials()
	var choices: Array = present.get_final_choices()
	assert(present_seals.size() == 2)
	assert(echo_seals.size() == 1)
	assert(choices.size() == 3)
	assert(present_trials.size() == 2)
	assert(echo_trials.size() == 1)
	assert(echo.get_final_choices().is_empty())

	var no_ids: Array[StringName] = []
	present.sync_rain_eye_state(true, no_ids)
	echo.sync_rain_eye_state(true, no_ids)
	for seal in present_seals + echo_seals:
		assert(seal.can_interact(null))
	var no_trials: Array[StringName] = []
	var all_endings: Array[StringName] = [
		&"merge_worlds", &"guard_boundary", &"tidal_order"
	]
	present.sync_rain_eye_state(
		false,
		no_ids,
		true,
		no_trials,
		&"trial_accept_loss",
	)
	assert(present_trials[0].can_interact(null))
	present.sync_rain_eye_state(
		false,
		no_ids,
		false,
		no_trials,
		&"",
		true,
		&"",
		all_endings,
	)
	for choice in choices:
		assert(choice.can_interact(null))
	assert(
		present.find_child("InvertedLake", true, false) is MeshInstance3D,
	)
	assert(
		echo.find_child("InvertedLake", true, false) is MeshInstance3D,
	)
	print(
		"RAIN_EYE_LEVEL_TEST_OK present_paths=4 echo_paths=3 "
		+ "seals=3 trials=3 endings=3 jolt_fragments=14"
	)
	present.queue_free()
	echo.queue_free()
	await process_frame
	call_deferred("quit")
