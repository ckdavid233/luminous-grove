extends SceneTree


func _initialize() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save_slot_1.json"))
	var main_scene := load("res://game/main/main.tscn") as PackedScene
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	var ground := main.get_node("Ground") as StaticBody3D
	var shore := main.get_node("LakeShore/ShoreColliders") as StaticBody3D
	var trees := main.get_node("Forest/TreeColliders") as StaticBody3D
	assert(ground.physics_material_override != null)
	assert(shore.physics_material_override != null)
	assert(trees.physics_material_override != null)
	assert(ground.physics_material_override.friction > 0.7)
	assert(shore.physics_material_override.friction > ground.physics_material_override.friction)

	var player := main.get("_player") as CharacterBody3D
	assert(player.find_child("SurfaceProbe", true, false) != null)
	assert(player.find_child("IK_foot_l", true, false) is SkeletonIK3D)
	assert(player.find_child("IK_foot_r", true, false) is SkeletonIK3D)
	player.set_physics_process(false)
	var slope := StaticBody3D.new()
	var slope_collision := CollisionShape3D.new()
	var slope_shape := BoxShape3D.new()
	slope_shape.size = Vector3(5.0, 0.2, 5.0)
	slope_collision.shape = slope_shape
	slope.add_child(slope_collision)
	slope.position = Vector3(0.0, 1.6, 6.0)
	slope.rotation.z = deg_to_rad(14.0)
	main.add_child(slope)
	player.global_position = Vector3(0.0, 1.8, 6.0)
	await physics_frame
	player.call("_update_foot_ik", 0.016)
	var slope_normal := slope.global_basis.y.normalized()
	var left_target := player.get_node("FootTargetL") as Node3D
	var right_target := player.get_node("FootTargetR") as Node3D
	assert(
		left_target.global_basis.y.dot(slope_normal) > 0.96
		and right_target.global_basis.y.dot(slope_normal) > 0.96,
		"Foot IK targets must align to the contacted slope normal",
	)
	slope.queue_free()
	slope_collision.shape = null
	slope = null
	slope_collision = null
	slope_shape = null
	await process_frame

	var footprints := main.get_node("Footprints")
	assert(footprints.has_method("active_count"))
	player.footstep_surface.emit(Vector3(0.0, 0.08, 0.0), 2.4, &"dry_soil")
	await process_frame
	assert(footprints.active_count() >= 1)

	var water = main.get("_water")
	assert(water.get("_origins").size() == 32)
	var grass_material := (main.get_node("Grass").multimesh.mesh.surface_get_material(0)) as ShaderMaterial
	assert(grass_material != null)
	await process_frame
	assert(int(grass_material.get_shader_parameter("interaction_count")) >= 1)
	var events: Array[StringName] = []
	water.surface_event.connect(
		func(_position: Vector3, _velocity: Vector3, _radius: float, source: StringName) -> void:
			events.append(source)
	)
	water.emit_surface_event(
		Vector3(-8.0, water.global_position.y, -8.0),
		Vector3(0.0, -3.5, 0.0),
		0.8,
		&"landing",
	)
	assert(events == [&"landing"])
	assert(water.active_ripple_count() >= 1)

	var floating_body := RigidBody3D.new()
	floating_body.name = "WaterFeedbackProbe"
	floating_body.mass = 2.0
	floating_body.add_to_group("water_feedback_body")
	main.add_child(floating_body)
	floating_body.global_position = Vector3(-8.0, 0.3, -8.0)
	water.call("_update_rigid_body_feedback", 0.1)
	assert(events.has(&"rigid_body"), "Rigid bodies must emit bounded water events")
	var body_velocity_before := floating_body.linear_velocity
	water.call("_update_rigid_body_feedback", 0.1)
	assert(
		floating_body.linear_velocity.y >= body_velocity_before.y,
		"Shallow water feedback must apply buoyancy",
	)
	floating_body.global_position = Vector3(30.0, 0.3, 30.0)
	water.call("_update_rigid_body_feedback", 0.1)
	assert(events.count(&"rigid_body") >= 2, "Body exit must emit a water event")
	floating_body.free()

	print(
		"SURFACE_INTERACTION_TEST_OK physics=soil,stone,wood ik=2 footprints=",
		footprints.active_count(),
		" ripples=32 buoyancy=ok vegetation=actor+rigid_body",
	)
	var streamer = main.get("_world_streamer")
	for _frame in 300:
		if streamer.is_level_ready("res://content/levels/echo_ruins/echo_ruins.tscn"):
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
	call_deferred("quit")
