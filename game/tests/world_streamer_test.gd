extends SceneTree

const STREAMER_SCRIPT := preload("res://core/world_streamer/world_streamer.gd")
const LEVEL_A := "res://tests/fixtures/stream_level_a.tscn"
const LEVEL_B := "res://tests/fixtures/stream_level_b.tscn"
const LEVEL_C := "res://tests/fixtures/stream_level_c.tscn"


func _initialize() -> void:
	var host := Node3D.new()
	host.name = "WorldHost"
	root.add_child(host)
	var streamer := STREAMER_SCRIPT.new()
	host.add_child(streamer)
	streamer.configure(host, 2)
	assert(
		streamer.get_stream_cache_mode() == ResourceLoader.CACHE_MODE_IGNORE,
		"Streamed PackedScenes must not remain in the global resource cache",
	)

	assert(streamer.request_level(LEVEL_A, true) == OK)
	assert(await _wait_until_ready(streamer, LEVEL_A), "Level A must load asynchronously")
	var level_a := streamer.get_level(LEVEL_A) as Node3D
	assert(level_a != null and not level_a.visible, "Preloaded level starts inactive")
	assert(streamer.activate_level(LEVEL_A))
	assert(level_a.visible)
	var physics_a := level_a.get_node("Physics") as StaticBody3D
	assert(physics_a.collision_layer == 1 and physics_a.collision_mask == 2)

	assert(streamer.request_level(LEVEL_B, true) == OK)
	assert(await _wait_until_ready(streamer, LEVEL_B))
	assert(streamer.get_resident_paths().size() == 2)
	var first_level_b := streamer.get_level(LEVEL_B) as Node3D
	var first_level_b_reference: WeakRef = weakref(first_level_b)

	assert(streamer.request_level(LEVEL_C, true) == OK)
	assert(await _wait_until_ready(streamer, LEVEL_C))
	assert(streamer.get_resident_paths().size() == 2, "Resident level budget must be enforced")
	assert(not streamer.is_level_ready(LEVEL_B), "Oldest inactive level must be evicted")
	await process_frame
	assert(
		not ResourceLoader.has_cached(LEVEL_B),
		"Evicted streamed scene must be eligible for immediate cache release",
	)
	first_level_b = null
	await process_frame
	assert(
		first_level_b_reference.get_ref() == null,
		"Eviction must free the old scene instance after the deferred frame",
	)
	assert(streamer.activate_level(LEVEL_C))
	assert(not level_a.visible)
	assert(physics_a.collision_layer == 0 and physics_a.collision_mask == 0)

	assert(streamer.clear_inactive_levels() == 1)
	assert(streamer.request_level(LEVEL_B, true) == OK)
	assert(
		await _wait_until_ready(streamer, LEVEL_B),
		"An evicted level must be loadable again on demand",
	)
	assert(streamer.get_level(LEVEL_B) != null)
	assert(streamer.clear_inactive_levels() == 1)
	assert(streamer.get_resident_paths() == PackedStringArray([LEVEL_C]))
	print(
		"WORLD_STREAMER_TEST_OK current=",
		LEVEL_C,
		" resident=",
		streamer.get_resident_paths(),
		" reload_after_evict=true",
	)
	quit()


func _wait_until_ready(streamer: Node, path: String) -> bool:
	for _frame in 300:
		if streamer.is_level_ready(path):
			return true
		await process_frame
	return false
