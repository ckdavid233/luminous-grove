extends SceneTree

const OUTPUT_PATH := "/home/cenkai/game_dev_plan/performance_chapters.json"
const SAMPLE_FRAMES := 240


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
	narrative.stage = narrative.CITY_GATE
	main.call("_sync_world_to_narrative")
	assert(await _wait_for_flag(main, "_city_pair_ready"))
	var player := main.get("_player") as CharacterBody3D
	player.global_position = Vector3(0.0, 1.0, 14.0)
	var results := {}
	results["city_present"] = await _sample_scene("city_present")

	var phase_shift = main.get("_phase_shift")
	assert(phase_shift.request_shift())
	await physics_frame
	results["city_echo"] = await _sample_scene("city_echo")

	narrative.stage = narrative.RAIN_EYE
	narrative.has_entered_rain_eye = true
	main.call("_sync_world_to_narrative")
	assert(await _wait_for_flag(main, "_rain_eye_pair_ready"))
	player.global_position = Vector3(0.0, 1.0, 15.0)
	results["rain_eye_present"] = await _sample_scene("rain_eye_present")
	assert(phase_shift.request_shift())
	await physics_frame
	player.global_position = Vector3(0.0, 1.0, 7.0)
	results["rain_eye_echo"] = await _sample_scene("rain_eye_echo")
	results["resident_levels"] = main.get(
		"_world_streamer"
	).get_resident_paths().size()
	results["resident_limit"] = main.get("_world_streamer").max_resident_levels
	results["renderer"] = RenderingServer.get_current_rendering_method()
	results["resolution"] = [root.size.x, root.size.y]

	var file := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(results, "\t"))
	file.close()
	print("PERFORMANCE_CHAPTERS_TEST_OK ", JSON.stringify(results))
	main.queue_free()
	for _frame in 3:
		await process_frame
	call_deferred("quit")


func _sample_scene(label: String) -> Dictionary:
	for _frame in 45:
		await process_frame
	var frame_times_ms: Array[float] = []
	var last_tick := Time.get_ticks_usec()
	for _frame in SAMPLE_FRAMES:
		await process_frame
		var current_tick := Time.get_ticks_usec()
		frame_times_ms.append((current_tick - last_tick) / 1000.0)
		last_tick = current_tick
	frame_times_ms.sort()
	var total_ms := 0.0
	for value in frame_times_ms:
		total_ms += value
	var average_ms := total_ms / frame_times_ms.size()
	return {
		"label": label,
		"sample_frames": SAMPLE_FRAMES,
		"average_frame_ms": snappedf(average_ms, 0.001),
		"average_fps": snappedf(1000.0 / average_ms, 0.1),
		"p95_frame_ms": snappedf(_percentile(frame_times_ms, 0.95), 0.001),
		"p99_frame_ms": snappedf(_percentile(frame_times_ms, 0.99), 0.001),
		"draw_calls": int(
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		),
		"primitives": int(
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		),
		"video_memory_bytes": int(
			Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)
		),
	}


func _wait_for_flag(main: Node, property_name: String) -> bool:
	for _frame in 900:
		if main.get(property_name):
			return true
		await process_frame
	return false


func _percentile(values: Array[float], fraction: float) -> float:
	var index := mini(int(ceil(values.size() * fraction)) - 1, values.size() - 1)
	return values[index]
