extends SceneTree

const NARRATIVE_DIRECTOR := preload(
	"res://game/narrative/narrative_director.gd"
)


func _initialize() -> void:
	var archive_puzzle = NARRATIVE_DIRECTOR.new()
	root.add_child(archive_puzzle)
	archive_puzzle.alignment_id = &"carry_the_light"
	archive_puzzle.stage = archive_puzzle.ARCHIVE_SEARCH
	assert(archive_puzzle.get_next_archive_anchor() == &"archive_voice")
	assert(not archive_puzzle.activate_archive_anchor(&"archive_shape"))
	assert(archive_puzzle.activated_archive_anchors.is_empty())
	for anchor_id in archive_puzzle.get_archive_anchor_order():
		assert(archive_puzzle.activate_archive_anchor(anchor_id))
	assert(archive_puzzle.stage == archive_puzzle.ARCHIVE_MECHANISMS)
	assert(archive_puzzle.get_next_archive_mechanism() == &"archive_counterweight")
	archive_puzzle.queue_free()
	await process_frame
	for ending_id in [&"merge_worlds", &"guard_boundary", &"tidal_order"]:
		var narrative = NARRATIVE_DIRECTOR.new()
		root.add_child(narrative)
		narrative.alignment_id = (
			&"return_to_lake" if ending_id == &"tidal_order" else &"carry_the_light"
		)
		narrative.city_testimony_id = (
			&"trust_shuo" if ending_id == &"tidal_order" else &"challenge_shuo"
		)
		narrative.stage = narrative.RAIN_EYE
		assert(narrative.handle_rain_eye_entered())
		for seal_id in [&"eye_grove", &"eye_archive", &"eye_city"]:
			assert(narrative.activate_rain_eye_seal(seal_id))
		assert(narrative.stage == narrative.RAIN_EYE_TRIALS)
		for trial_id in narrative.RAIN_EYE_TRIAL_ORDER:
			assert(narrative.activate_rain_eye_trial(trial_id))
		assert(narrative.stage == narrative.FINAL_DECISION)
		assert(narrative.choose_ending(ending_id))
		assert(narrative.stage == narrative.COMPLETE)
		assert(narrative.ending_id == ending_id)
		var state: Dictionary = narrative.capture_state()
		assert(state.campaign_version == 8)
		assert(state.rain_eye_seal_ids.size() == 3)
		assert(state.rain_eye_trial_ids.size() == 3)
		var restored = NARRATIVE_DIRECTOR.new()
		root.add_child(restored)
		restored.restore_state(state)
		assert(restored.stage == restored.COMPLETE)
		assert(restored.ending_id == ending_id)
		assert(restored.has_entered_rain_eye)
		narrative.queue_free()
		restored.queue_free()
		await process_frame

	var legacy = NARRATIVE_DIRECTOR.new()
	root.add_child(legacy)
	legacy.restore_state(
		{
			"campaign_version": 3,
			"stage": "lantern_city",
			"alignment_id": "return_to_lake",
			"ending_id": "return_to_lake",
		}
	)
	assert(legacy.alignment_id == &"return_to_lake")
	assert(legacy.ending_id.is_empty(), "Legacy alignment must not lock final choices")
	var locked_tidal = NARRATIVE_DIRECTOR.new()
	root.add_child(locked_tidal)
	locked_tidal.stage = locked_tidal.FINAL_DECISION
	locked_tidal.alignment_id = &"carry_the_light"
	locked_tidal.city_testimony_id = &"challenge_shuo"
	assert(not locked_tidal.get_available_endings().has(&"tidal_order"))
	assert(not locked_tidal.choose_ending(&"tidal_order"))
	print(
		"NARRATIVE_FINALE_TEST_OK endings=merge_worlds,guard_boundary,"
		+ "tidal_order trials=3 branch_lock=ok legacy_migration=clean"
	)
	legacy.queue_free()
	locked_tidal.queue_free()
	await process_frame
	call_deferred("quit")
