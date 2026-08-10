extends SceneTree

const ECHO_PATH := "res://content/levels/echo_ruins/echo_ruins.tscn"
const CITY_PRESENT_PATH := (
	"res://content/levels/lantern_city/lantern_city_present.tscn"
)
const CITY_ECHO_PATH := (
	"res://content/levels/lantern_city/lantern_city_echo.tscn"
)
const RAIN_EYE_PRESENT_PATH := (
	"res://content/levels/rain_eye/rain_eye_present.tscn"
)
const RAIN_EYE_ECHO_PATH := (
	"res://content/levels/rain_eye/rain_eye_echo.tscn"
)


func _initialize() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save_slot_1.json"))
	var main_scene := load("res://game/main/main.tscn") as PackedScene
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame

	var player := root.find_child("Player", true, false) as CharacterBody3D
	var shrine := root.find_child("Shrine", true, false)
	var wind_bell := root.find_child("WindBell", true, false)
	var narrative := root.find_child("NarrativeDirector", true, false)
	var memory_droplets: Array = main.get("_memory_droplets")
	await physics_frame
	assert(player != null, "Player must exist")
	assert(shrine != null, "Shrine must exist")
	assert(wind_bell != null, "WindBell must exist")
	assert(narrative != null, "Narrative director must exist")
	assert(memory_droplets.size() == 3, "Three memories must exist")
	assert(not shrine.is_activated, "Shrine starts dormant in a clean test")
	assert(not shrine.can_interact(player), "Shrine remains locked before bell rings")
	_assert_objective_target(main, "find bell")

	player.set_physics_process(false)
	player.global_position = wind_bell.global_position + Vector3(0.0, 1.0, -2.0)
	player.call("_update_interaction_target")
	assert(player.get("_interaction_target") == wind_bell, "Nearby fallback must find the wind bell")
	assert(player.get_node("HUD/PromptLabel").visible, "Interaction prompt must be visible")
	assert(player.request_interaction(), "Real interaction request must reach the wind bell")
	for _frame in 3:
		await process_frame
	assert(wind_bell.is_rung, "First interaction must ring the wind bell")
	assert(not shrine.can_interact(player), "Bell alone must not unlock the shrine")
	_assert_objective_target(main, "gather memories")
	for index in memory_droplets.size():
		var droplet: Node = memory_droplets[index]
		assert(droplet.can_interact(player), "Memories become available after bell")
		droplet.interact(player)
		await process_frame
		if index < memory_droplets.size() - 1:
			assert(not shrine.can_interact(player), "Shrine stays locked until all memories")
	assert(shrine.can_interact(player), "All memories must unlock the shrine")
	_assert_objective_target(main, "awaken shrine")
	player.set("_interaction_time_left", 0.0)
	player.set("_interaction_target", shrine)
	player.call("_begin_interaction")
	for _frame in 3:
		await process_frame
	assert(shrine.is_activated, "Interaction must activate shrine")
	assert(narrative.stage == &"memory_alignment")
	_assert_objective_target(main, "memory alignment")
	var ending_choices: Array = main.get("_ending_choices")
	assert(ending_choices.size() == 2, "Two memory alignments must exist")
	ending_choices[0].interact(player)
	await process_frame
	assert(narrative.stage == &"rift_ready", "The Act I choice must open the longer campaign")
	assert(not narrative.alignment_id.is_empty(), "The branch must have a stable alignment ID")
	_assert_objective_target(main, "rain rift")
	var streamer = main.get("_world_streamer")
	for _frame in 600:
		if streamer.is_level_ready("res://content/levels/echo_ruins/echo_ruins.tscn"):
			break
		await process_frame
	assert(streamer.is_level_ready("res://content/levels/echo_ruins/echo_ruins.tscn"))
	var phase_shift = main.get("_phase_shift")
	assert(phase_shift.request_shift(), "The memory alignment must unlock phase shifting")
	await physics_frame
	await process_frame
	assert(narrative.stage == &"archive_search", "Entering echo starts Act II")
	_assert_objective_target(main, "archive anchors")
	var echo = streamer.get_level("res://content/levels/echo_ruins/echo_ruins.tscn")
	var archive_anchors: Array = echo.get_archive_anchors()
	assert(archive_anchors.size() == 3)
	for anchor in archive_anchors:
		assert(anchor.can_interact(player))
		anchor.interact(player)
		await process_frame
	assert(
		narrative.stage == &"archive_mechanisms",
		"Three archive anchors must unlock the physical archive mechanisms"
	)
	_assert_objective_target(main, "archive reflection mechanism")
	assert(phase_shift.request_shift(), "The reflection mechanism is in the present phase")
	await physics_frame
	await process_frame
	var archive_present_mechanisms: Array = main.get("_archive_present_mechanisms")
	var reflection = archive_present_mechanisms.filter(
		func(node: Node) -> bool:
			return node.resonance_id == &"archive_reflection"
	)[0]
	var name_lens = archive_present_mechanisms.filter(
		func(node: Node) -> bool:
			return node.resonance_id == &"archive_name_lens"
	)[0]
	assert(reflection.can_interact(player))
	reflection.interact(player)
	await process_frame
	assert(phase_shift.request_shift(), "The counterweight is in the echo phase")
	await physics_frame
	await process_frame
	var counterweight = echo.get_counterweight_plate()
	assert(counterweight.is_available)
	_assert_objective_target(main, "archive counterweight")
	counterweight.solve_for_test()
	await process_frame
	assert(phase_shift.request_shift(), "The naming lens returns to the present phase")
	await physics_frame
	await process_frame
	assert(name_lens.can_interact(player))
	_assert_objective_target(main, "archive name lens")
	name_lens.interact(player)
	await process_frame
	assert(narrative.stage == &"archive_restored")
	_assert_objective_target(main, "lantern city gate")
	var city_gate = echo.get_city_gate()
	assert(city_gate != null and city_gate.can_interact(player))
	city_gate.interact(player)
	for _frame in 900:
		if main.get("_city_pair_ready"):
			break
		await process_frame
	assert(main.get("_city_pair_ready"), "Both Lantern City phases must stream in")
	assert(
		narrative.stage == &"lantern_city",
		"Crossing the archive gate must begin Act III",
	)
	assert(streamer.is_level_ready(CITY_PRESENT_PATH))
	assert(streamer.is_level_ready(CITY_ECHO_PATH))
	assert(not streamer.is_level_ready(ECHO_PATH))
	assert(streamer.get_resident_paths().size() == 2)
	assert(streamer.max_resident_levels == 2)
	_assert_objective_target(main, "city traces")

	var city_present = streamer.get_level(CITY_PRESENT_PATH)
	var city_echo = streamer.get_level(CITY_ECHO_PATH)
	var present_traces: Array = city_present.get_city_traces()
	var echo_traces: Array = city_echo.get_city_traces()
	assert(present_traces.size() == 2 and echo_traces.size() == 1)
	present_traces[0].interact(player)
	await process_frame
	assert(phase_shift.request_shift(), "City echo phase must be ready")
	await physics_frame
	await process_frame
	assert(phase_shift.active_phase == &"echo")
	echo_traces[0].interact(player)
	await process_frame
	assert(phase_shift.request_shift())
	await physics_frame
	await process_frame
	assert(phase_shift.active_phase == &"present")
	player.set("_interaction_time_left", 0.0)
	player.set("_interaction_target", present_traces[1])
	player.call("_begin_interaction")
	await process_frame
	assert(
		narrative.stage == &"city_relays",
		"All three city traces must reveal the cross-phase relay puzzle",
	)
	_assert_objective_target(main, "city relays")
	var present_relays: Array = city_present.get_city_relays()
	var echo_relays: Array = city_echo.get_city_relays()
	var relay_by_id := {}
	for relay in present_relays + echo_relays:
		relay_by_id[relay.resonance_id] = relay
	for relay_id in narrative.CITY_RELAY_ORDER:
		var relay = relay_by_id[relay_id]
		var relay_is_echo: bool = relay in echo_relays
		if relay_is_echo != (phase_shift.active_phase == &"echo"):
			assert(phase_shift.request_shift())
			await physics_frame
			await process_frame
		assert(relay.can_interact(player))
		relay.interact(player)
		await process_frame
	assert(narrative.stage == &"city_council")
	_assert_objective_target(main, "city testimony")
	if phase_shift.active_phase == &"echo":
		assert(phase_shift.request_shift())
		await physics_frame
		await process_frame
	var testimony_choices: Array = city_present.get_testimony_choices()
	assert(testimony_choices.size() == 2)
	var trust_choice = testimony_choices.filter(
		func(node: Node) -> bool:
			return node.choice_id == &"trust_shuo"
	)[0]
	assert(trust_choice.can_interact(player))
	trust_choice.interact(player)
	await process_frame
	assert(narrative.stage == &"rain_eye")
	_assert_objective_target(main, "rain eye gate")
	var rain_eye_gate = city_present.get_rain_eye_gate()
	assert(rain_eye_gate != null and rain_eye_gate.can_interact(player))
	rain_eye_gate.interact(player)
	for _frame in 900:
		if main.get("_rain_eye_pair_ready"):
			break
		await process_frame
	assert(main.get("_rain_eye_pair_ready"), "Both Rain Eye phases must stream in")
	assert(narrative.has_entered_rain_eye)
	assert(streamer.is_level_ready(RAIN_EYE_PRESENT_PATH))
	assert(streamer.is_level_ready(RAIN_EYE_ECHO_PATH))
	assert(not streamer.is_level_ready(CITY_PRESENT_PATH))
	assert(not streamer.is_level_ready(CITY_ECHO_PATH))
	assert(streamer.get_resident_paths().size() == 2)
	_assert_objective_target(main, "rain eye seals")

	var rain_present = streamer.get_level(RAIN_EYE_PRESENT_PATH)
	var rain_echo = streamer.get_level(RAIN_EYE_ECHO_PATH)
	var present_seals: Array = rain_present.get_rain_eye_seals()
	var echo_seals: Array = rain_echo.get_rain_eye_seals()
	assert(present_seals.size() == 2 and echo_seals.size() == 1)
	present_seals[0].interact(player)
	await process_frame
	assert(phase_shift.request_shift())
	await physics_frame
	await process_frame
	echo_seals[0].interact(player)
	await process_frame
	assert(phase_shift.request_shift())
	await physics_frame
	await process_frame
	present_seals[1].interact(player)
	await process_frame
	assert(
		narrative.stage == &"rain_eye_trials",
		"Three Rain Eye seals must unlock the traversal trials",
	)
	_assert_objective_target(main, "rain eye trials")
	var present_trials: Array = rain_present.get_rain_eye_trials()
	var echo_trials: Array = rain_echo.get_rain_eye_trials()
	var trial_by_id := {}
	for trial in present_trials + echo_trials:
		trial_by_id[trial.resonance_id] = trial
	for trial_id in narrative.RAIN_EYE_TRIAL_ORDER:
		var trial = trial_by_id[trial_id]
		var trial_is_echo: bool = trial in echo_trials
		if trial_is_echo != (phase_shift.active_phase == &"echo"):
			assert(phase_shift.request_shift())
			await physics_frame
			await process_frame
		assert(trial.can_interact(player))
		trial.interact(player)
		await process_frame
	assert(narrative.stage == &"final_decision")
	_assert_objective_target(main, "final decision")
	if phase_shift.active_phase == &"echo":
		assert(phase_shift.request_shift())
		await physics_frame
		await process_frame
	var final_choices: Array = rain_present.get_final_choices()
	assert(final_choices.size() == 3)
	for final_choice in final_choices:
		assert(final_choice.can_interact(player))
	player.set("_interaction_time_left", 0.0)
	player.set("_interaction_target", final_choices[2])
	player.call("_begin_interaction")
	await process_frame
	assert(narrative.stage == &"complete")
	assert(narrative.ending_id == &"tidal_order")
	assert(main.get("_ending_overlay").visible)
	assert(
		main.call("_resolve_objective_target") == null,
		"Completed campaign must not retain a stale objective target",
	)
	var animation_tree := player.find_child("AnimationTree", true, false) as AnimationTree
	var playback := animation_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	assert(playback.get_current_node() == &"Interact", "Player must enter Interact animation")
	var save_service := root.get_node("SaveService")
	var save_error: Error = save_service.save_game(&"luminous_grove", player)
	assert(save_error == OK, "Save must complete")
	var state: Dictionary = save_service.load_game()
	assert(state.get("schema_version") == 2, "Save schema must be versioned")
	assert(state.get("build_version") == "0.6.2-alpha")
	assert(state.get("player_rotation", []).size() == 3)
	assert(state.get("world_state", {}).get("grove_wind_bell", {}).get("rung") == true)
	assert(state.get("world_state", {}).get("forest_shrine", {}).get("activated") == true)
	assert(
		state.get("world_state", {}).get("narrative_director", {}).get("stage")
		== "complete"
	)
	assert(
		state.get("world_state", {})
			.get("narrative_director", {})
			.get("archive_anchor_ids", [])
			.size()
		== 3
	)
	assert(
		state.get("world_state", {})
			.get("narrative_director", {})
			.get("archive_mechanism_ids", [])
			.size()
		== 3
	)
	assert(
		state.get("world_state", {})
			.get("narrative_director", {})
			.get("rain_eye_seal_ids", [])
			.size()
		== 3
	)
	assert(
		state.get("world_state", {})
			.get("narrative_director", {})
			.get("rain_eye_trial_ids", [])
			.size()
		== 3
	)
	assert(
		state.get("world_state", {})
			.get("narrative_director", {})
			.get("ending_id")
		== "tidal_order"
	)
	assert(
		state.get("world_state", {})
			.get("narrative_director", {})
			.get("city_trace_ids", [])
			.size()
		== 3
	)
	assert(
		state.get("world_state", {})
			.get("narrative_director", {})
			.get("city_relay_ids", [])
			.size()
		== 4
	)
	var first_streamer = main.get("_world_streamer")
	if first_streamer != null and first_streamer.has_method("shutdown"):
		first_streamer.shutdown()
	if main.has_method("shutdown"):
		main.shutdown()
	main.queue_free()
	for _frame in 120:
		await process_frame
		await physics_frame
	var restored_main := main_scene.instantiate()
	root.add_child(restored_main)
	for _frame in 900:
		if restored_main.get("_rain_eye_pair_ready"):
			break
		await process_frame
	assert(
		restored_main.get("_rain_eye_pair_ready"),
		"Completed campaign must restore directly into Rain Eye",
	)
	var restored_narrative = restored_main.get("_narrative")
	assert(restored_narrative.stage == &"complete")
	assert(restored_narrative.ending_id == &"tidal_order")
	assert(restored_main.get("_ending_overlay").visible)
	var restored_streamer = restored_main.get("_world_streamer")
	assert(restored_streamer.get_resident_paths().size() == 2)
	assert(restored_streamer.is_level_ready(RAIN_EYE_PRESENT_PATH))
	assert(restored_streamer.is_level_ready(RAIN_EYE_ECHO_PATH))
	print(
		"GAMEPLAY_TEST_OK stage=complete resident=2 archive_mechanisms=3 "
		+ "city_traces=3 relays=4 rain_eye_seals=3 trials=3 "
		+ "ending=tidal_order restore=rain_eye"
	)
	if restored_streamer.has_method("shutdown"):
		restored_streamer.shutdown()
	if restored_main.has_method("shutdown"):
		restored_main.shutdown()
	restored_main.queue_free()
	for _frame in 120:
		await process_frame
		await physics_frame
	call_deferred("quit")


func _assert_objective_target(main: Node, description: String) -> void:
	var target = main.call("_resolve_objective_target")
	assert(
		target != null and is_instance_valid(target),
		"Objective guide target missing: " + description,
	)
