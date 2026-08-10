extends SceneTree


func _initialize() -> void:
	DirAccess.remove_absolute(
		ProjectSettings.globalize_path("user://save_slot_1.json")
	)
	var main_scene := load("res://game/main/main.tscn") as PackedScene
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame

	var water = main.get("_water")
	var player := main.get("_player") as CharacterBody3D
	assert(water != null, "Interactive lake must exist")
	assert(player != null, "Player must exist")
	water.visual_effects_enabled = false
	assert(main.find_child("WaterDroplets", true, false) is GPUParticles3D)

	var ripple_sources: Array[StringName] = []
	var splash_sources: Array[StringName] = []
	water.ripple_created.connect(
		func(_position: Vector3, source: StringName) -> void:
			ripple_sources.append(source)
	)
	water.splash_created.connect(
		func(_position: Vector3, _strength: float, source: StringName) -> void:
			splash_sources.append(source)
	)
	water.add_ripple(Vector3(-8.0, water.global_position.y, -8.0), &"test_drop")
	assert(ripple_sources == [&"test_drop"])
	assert(water.active_ripple_count() >= 1)

	water.add_ripple(Vector3(30.0, 0.0, 30.0), &"outside")
	assert(not ripple_sources.has(&"outside"), "Outside ripples must be rejected")

	player.global_position = Vector3(-8.0, 0.8, -8.0)
	water.set_actor(player)
	water.call("_update_actor_ripples")
	player.global_position.x += 0.5
	water.call("_update_actor_ripples")
	assert(
		not ripple_sources.has(&"footstep"),
		"Airborne movement above the lake must not create footstep ripples",
	)

	player.global_position.y = 0.0
	player.velocity.y = -3.0
	water.call("_update_actor_ripples")
	assert(splash_sources == [&"water_entry"], "Entering water must create a splash")
	player.velocity.y = 0.0
	player.global_position.x += 0.5
	water.call("_update_actor_ripples")
	assert(ripple_sources.has(&"footstep"), "Moving through water must create a footstep ripple")

	player.global_position.y = 0.8
	player.velocity.y = 5.0
	water.call("_update_actor_ripples")
	assert(splash_sources.has(&"water_exit"), "Jumping out of water must create a splash")
	player.global_position.y = 0.0
	player.velocity.y = -5.0
	water.call("_update_actor_ripples")
	assert(
		splash_sources.count(&"water_entry") == 2,
		"Landing back in water must create a second entry splash",
	)
	assert(water.splash_count() == 3)
	water.visual_effects_enabled = true
	water.visual_effects_auto_cleanup = false
	water.call(
		"_create_surface_splash",
		Vector3(-8.0, water.global_position.y, -8.0),
		1.0,
		&"visual_probe",
	)
	var splash := main.find_child("WaterSplash", true, false) as Node3D
	assert(splash != null, "Water crossing must instantiate visible splash geometry")
	assert(splash.find_child("SplashDroplets", true, false) is GPUParticles3D)
	assert(splash.find_child("*", true, false) is MeshInstance3D)
	water.call("_release_splash_root", splash)
	water.visual_effects_auto_cleanup = true
	water.visual_effects_enabled = false
	await process_frame

	print(
		"INTERACTIVE_WATER_TEST_OK sources=",
		ripple_sources,
		" splashes=",
		splash_sources,
		" active=",
		water.active_ripple_count(),
	)
	var streamer = main.get("_world_streamer")
	for _frame in 600:
		if streamer.is_level_ready(
			"res://content/levels/echo_ruins/echo_ruins.tscn"
		):
			break
		await process_frame
	streamer.clear_inactive_levels()
	if streamer.has_method("shutdown"):
		streamer.shutdown()
	if main.has_method("shutdown"):
		main.shutdown()
	main.queue_free()
	for _frame in 120:
		await process_frame
		await physics_frame
	main_scene = null
	call_deferred("quit")
