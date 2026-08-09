extends SceneTree

const PRESENT_PATH := (
	"res://content/levels/lantern_city/lantern_city_present.tscn"
)
const ECHO_PATH := "res://content/levels/lantern_city/lantern_city_echo.tscn"


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

	assert(present.get_meta("stream_keep_visual_when_inactive") == true)
	assert(echo.get_meta("stream_keep_visual_when_inactive") == true)
	assert(
		present.find_child("MemoryBridge", true, false) == null,
		"Present city bridge must be broken",
	)
	assert(
		echo.find_child("MemoryBridge", true, false) != null,
		"Echo city must provide the phase-only bridge",
	)
	assert(
		echo.find_child("RunningRainTrain", true, false) is AnimatableBody3D,
		"Echo city needs a moving physical train",
	)
	assert(
		present.find_children("RainCrate_*", "RigidBody3D", true, false).size()
		== 8,
		"Present city needs Jolt props",
	)
	assert(
		echo.find_children("RainCrate_*", "RigidBody3D", true, false).size()
		== 8,
		"Echo city needs Jolt props",
	)

	var present_traces: Array = present.get_city_traces()
	var echo_traces: Array = echo.get_city_traces()
	var present_relays: Array = present.get_city_relays()
	var echo_relays: Array = echo.get_city_relays()
	assert(present_traces.size() == 2)
	assert(echo_traces.size() == 1)
	assert(present_relays.size() == 2)
	assert(echo_relays.size() == 2)
	assert(present.get_testimony_choices().size() == 2)
	assert(echo.get_testimony_choices().is_empty())
	var no_activated_traces: Array[StringName] = []
	present.sync_city_state(true, no_activated_traces)
	echo.sync_city_state(true, no_activated_traces)
	for trace in present_traces + echo_traces:
		assert(trace.can_interact(null))
		var visuals: Array[Node] = trace.find_children(
			"*",
			"VisualInstance3D",
			true,
			false,
		)
		assert(not visuals.is_empty())
		var expected_layer: int = 2 if trace in echo_traces else 1
		for visual in visuals:
			assert((visual as VisualInstance3D).layers == expected_layer)
	var no_relays: Array[StringName] = []
	present.sync_city_state(
		false, no_activated_traces, true, no_relays, &"relay_dawn"
	)
	assert(present_relays[0].can_interact(null))
	for relay in present_relays + echo_relays:
		if relay.resonance_id != &"relay_dawn":
			assert(not relay.can_interact(null))

	var echo_train := echo.find_child(
		"RunningRainTrain",
		true,
		false,
	) as AnimatableBody3D
	var old_train_z := echo_train.position.z
	for _frame in 5:
		await physics_frame
	assert(echo_train.position.z < old_train_z, "Rain train must move while active")
	print(
		(
			"LANTERN_CITY_LEVEL_TEST_OK present_traces=%d echo_traces=%d "
			+ "relays=4 testimony_choices=2 present_crates=8 echo_crates=8"
		)
		% [present_traces.size(), echo_traces.size()]
	)
	present.queue_free()
	echo.queue_free()
	await process_frame
	call_deferred("quit")
