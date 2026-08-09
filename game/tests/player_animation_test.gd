extends SceneTree


func _initialize() -> void:
	var ground := StaticBody3D.new()
	var ground_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(12.0, 0.5, 12.0)
	ground_shape.shape = box
	ground_shape.position.y = -0.25
	ground.add_child(ground_shape)
	root.add_child(ground)
	var scene := load("res://game/player/player.tscn") as PackedScene
	var player := scene.instantiate()
	root.add_child(player)
	for _frame in 8:
		await physics_frame
		await process_frame
	var animation_tree := player.find_child("AnimationTree", true, false) as AnimationTree
	assert(animation_tree != null, "Runtime AnimationTree must exist")
	assert(animation_tree.active, "Runtime AnimationTree must be active")
	var playback := animation_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	var state_machine := animation_tree.tree_root as AnimationNodeStateMachine
	for state in [&"Idle", &"Walk", &"Run", &"Jump", &"Fall", &"Land", &"Interact"]:
		assert(state_machine.has_node(state), "Missing locomotion state: " + str(state))
	print("PLAYER_ANIMATION_CURRENT ", playback.get_current_node())
	assert(playback.get_current_node() == &"Idle", "Player animation starts in Idle")
	var animation_player := player.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for looping_animation in [&"Idle", &"Walk", &"Run", &"Fall"]:
		assert(
			animation_player.get_animation(looping_animation).loop_mode
			== Animation.LOOP_LINEAR,
			str(looping_animation) + " must loop",
		)
	for dedicated_animation in [&"Run", &"Jump", &"Fall", &"Land"]:
		assert(
			animation_player.has_animation(dedicated_animation),
			"Movement must not reuse placeholder animation: " + str(dedicated_animation),
		)
	var animation_footsteps: Array[StringName] = []
	player.footstep_surface.connect(
		func(_position: Vector3, _speed: float, surface_type: StringName) -> void:
			animation_footsteps.append(surface_type)
	)
	player.set_physics_process(false)
	player.velocity = Vector3(2.2, 0.0, 0.0)
	player.set("_surface_sample", {"type": &"dry_soil"})
	player.set("_animation_state", &"Walk")
	animation_player.play(&"Walk")
	var walk_length := animation_player.get_animation(&"Walk").length
	player.set("_last_animation_name", animation_player.current_animation)
	player.set("_last_animation_position", 0.14)
	animation_player.seek(walk_length * 0.19, true)
	player.call("_update_animation_footsteps")
	assert(animation_footsteps == [&"dry_soil"], "Walk phase must emit an animation footstep event")

	player.velocity = Vector3(0.0, 3.0, 0.0)
	player.call("_travel_animation", &"Jump")
	await _wait_for_animation_state(player, playback, &"Jump")
	player.velocity.y = -2.0
	player.call("_travel_animation", &"Fall")
	await _wait_for_animation_state(player, playback, &"Fall")
	player.call("_travel_animation", &"Land")
	await _wait_for_animation_state(player, playback, &"Land")
	player.call("_travel_animation", &"Run")
	await _wait_for_animation_state(player, playback, &"Run")
	player.call("_travel_animation", &"Idle")
	player.set_physics_process(true)
	var quality_stats := player.get("_render_quality_stats") as Dictionary
	assert(quality_stats.materials >= 9, "All character materials need runtime HQ copies")
	assert(quality_stats.skin == 1, "Skin material classification failed")
	assert(quality_stats.eyes == 1, "Eye material classification failed")
	assert(quality_stats.hair == 1, "Hair material classification failed")

	var body := player.find_child(
		"Ji_Body_Source_Game",
		true,
		false,
	) as MeshInstance3D
	var eyes := player.find_child(
		"Human_high-poly_Game",
		true,
		false,
	) as MeshInstance3D
	var hair := player.find_child(
		"Human_long01_Game",
		true,
		false,
	) as MeshInstance3D
	assert(body != null and eyes != null and hair != null)
	var skin_material := body.get_surface_override_material(
		0
	) as StandardMaterial3D
	var eye_material := eyes.get_surface_override_material(
		0
	) as StandardMaterial3D
	var hair_material := hair.get_surface_override_material(
		0
	) as StandardMaterial3D
	assert(skin_material.subsurf_scatter_enabled, "Skin SSS must be enabled")
	assert(skin_material.subsurf_scatter_skin_mode, "Skin SSS mode must be enabled")
	assert(eye_material.clearcoat_enabled, "Eye clearcoat must be enabled")
	assert(hair_material.anisotropy_enabled, "Hair tangents/anisotropy must survive import")
	assert(
		hair_material.texture_filter
		== BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC,
		"Character textures require anisotropic filtering",
	)
	assert(InputMap.has_action("jump") and InputMap.has_action("sprint"))
	assert(InputMap.has_action("look_left") and InputMap.has_action("pause_game"))
	var stamina_bar := player.get_node("HUD/StaminaBar") as ProgressBar
	assert(stamina_bar != null and stamina_bar.value == 100.0)
	var checkpoint: Transform3D = player.global_transform
	player.global_position.y = -8.0
	await physics_frame
	await process_frame
	assert(
		player.global_position.distance_to(checkpoint.origin) < 0.2,
		"Falling out of a streamed level must restore the last safe checkpoint",
	)
	print(
		"PLAYER_ANIMATION_TEST_OK current=",
		playback.get_current_node(),
		" quality=",
		quality_stats,
	)
	quit()


func _wait_for_animation_state(
	player: CharacterBody3D,
	playback: AnimationNodeStateMachinePlayback,
	expected: StringName,
) -> void:
	assert(
		player.get("_animation_state") == expected,
		"Runtime selected the wrong animation state: " + str(expected),
	)
	for _frame in 20:
		await physics_frame
		await process_frame
		if playback.get_current_node() == expected:
			return
	assert(false, "AnimationTree did not reach state: " + str(expected))
