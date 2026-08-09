extends SceneTree

const OUTPUT_DIRECTORY := "/home/cenkai/game_dev_plan"
const WARMUP_FRAMES := 60
const SAMPLE_FRAMES := 600


func _initialize() -> void:
	DirAccess.remove_absolute(
		ProjectSettings.globalize_path("user://save_slot_1.json")
	)
	root.size = Vector2i(1280, 720)
	var main_scene := load("res://game/main/main.tscn") as PackedScene
	var main := main_scene.instantiate()
	root.add_child(main)
	var quality_profile := _requested_quality_profile()
	main.set("_quality_profile", quality_profile)
	main.call("_apply_quality_profile")
	for _frame in WARMUP_FRAMES:
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
	var result := {
		"quality_profile": str(quality_profile),
		"resolution": [root.size.x, root.size.y],
		"renderer": RenderingServer.get_current_rendering_method(),
		"sample_frames": SAMPLE_FRAMES,
		"average_frame_ms": snappedf(average_ms, 0.001),
		"average_fps": snappedf(1000.0 / average_ms, 0.1),
		"p95_frame_ms": snappedf(_percentile(frame_times_ms, 0.95), 0.001),
		"p99_frame_ms": snappedf(_percentile(frame_times_ms, 0.99), 0.001),
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"primitives": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		"video_memory_bytes": int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)),
	}
	var output_path := (
		OUTPUT_DIRECTORY + "/performance_runtime.json"
		if quality_profile == &"high"
		else OUTPUT_DIRECTORY + "/performance_runtime_%s.json" % quality_profile
	)
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	print("PERFORMANCE_TEST_OK ", JSON.stringify(result))
	quit()


func _requested_quality_profile() -> StringName:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--quality="):
			var value := StringName(argument.trim_prefix("--quality="))
			if value in [&"high", &"balanced", &"performance"]:
				return value
	return &"high"


func _percentile(values: Array[float], fraction: float) -> float:
	var index := mini(int(ceil(values.size() * fraction)) - 1, values.size() - 1)
	return values[index]
