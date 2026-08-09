extends SceneTree

const ECHO_SCENE := preload("res://content/levels/echo_ruins/echo_ruins.tscn")


func _initialize() -> void:
	PhysicsServer3D.set_active(true)
	assert(
		ProjectSettings.get_setting("physics/3d/physics_engine") == "Jolt Physics",
		"The project must use the Jolt Physics backend"
	)
	assert(
		ProjectSettings.get_setting("physics/3d/run_on_separate_thread") == true,
		"3D physics must run on its dedicated thread"
	)
	assert(
		ProjectSettings.get_setting("physics/common/enable_physics_interpolation") == true,
		"Physics interpolation must remain enabled"
	)

	var echo := ECHO_SCENE.instantiate()
	root.add_child(echo)
	await physics_frame
	await process_frame

	var floor := echo.find_child("EchoFloor", true, false) as StaticBody3D
	var bodies := echo.find_children("MemoryStone_*", "RigidBody3D", true, false)
	assert(floor != null, "The physics arena requires a static Jolt floor")
	assert(bodies.size() == 10, "The echo ruin must contain ten dynamic memory stones")
	var counterweight = echo.get_counterweight_plate()
	var counterweight_stone: RigidBody3D = echo.get_counterweight_stone()
	assert(counterweight != null and counterweight_stone != null)
	assert(counterweight_stone.is_in_group("archive_counterweight"))
	counterweight.set_available(true)
	var pusher := Node3D.new()
	pusher.position = Vector3(4.5, 0.5, -9.0)
	echo.add_child(pusher)
	for _attempt in 3:
		counterweight_stone.interact(pusher)
		for _frame in 120:
			if counterweight.is_activated:
				break
			await physics_frame
			await process_frame
		if counterweight.is_activated:
			break
	assert(
		counterweight.is_activated,
		"Pushing the Jolt memory stone onto the plate must solve the archive mechanism",
	)

	var target := RigidBody3D.new()
	target.name = "JoltImpulseProbe"
	target.mass = 2.0
	target.position = Vector3(-8.0, 4.0, 2.0)
	target.contact_monitor = true
	target.max_contacts_reported = 8
	target.continuous_cd = true
	var probe_collision := CollisionShape3D.new()
	var probe_shape := SphereShape3D.new()
	probe_shape.radius = 0.45
	probe_collision.shape = probe_shape
	target.add_child(probe_collision)
	echo.add_child(target)

	for _frame in 4:
		await physics_frame
		await process_frame
	var initial_positions: Dictionary = {}
	for node in bodies:
		var body := node as RigidBody3D
		initial_positions[body] = body.global_position
	var stack_target := echo.find_child("MemoryStone_3_0", true, false) as RigidBody3D
	assert(stack_target != null, "The test requires the top stone in the stack")
	target.sleeping = false
	stack_target.sleeping = false
	var start_position := target.global_position
	target.apply_central_impulse(Vector3(10.0, 5.0, -3.0))
	stack_target.apply_central_impulse(Vector3(18.0, 5.0, -4.0))

	var maximum_displacement := 0.0
	var maximum_stack_displacement := 0.0
	var reported_contact := false
	for _frame in 360:
		await physics_frame
		await process_frame
		maximum_displacement = maxf(
			maximum_displacement,
			target.global_position.distance_to(start_position)
		)
		maximum_stack_displacement = maxf(
			maximum_stack_displacement,
			stack_target.global_position.distance_to(initial_positions[stack_target]),
		)
		if not target.get_colliding_bodies().is_empty():
			reported_contact = true
	assert(
		maximum_displacement > 1.5,
		"Jolt must integrate the applied impulse into visible rigid-body motion"
	)
	assert(
		target.global_position.y > -0.1,
		"The dynamic body must collide with the static floor instead of tunnelling through it"
	)
	assert(
		reported_contact or target.linear_velocity.length() < 0.6,
		"The body must either report a contact or settle after physical collision"
	)

	var displaced_bodies := 0
	for node in bodies:
		var body := node as RigidBody3D
		var initial_position: Vector3 = initial_positions[body]
		if body.global_position.distance_to(initial_position) > 0.08:
			displaced_bodies += 1
	assert(
		displaced_bodies >= 1 or maximum_stack_displacement > 0.08,
		"The physical stack must react to an applied force"
	)

	print(
		"JOLT_PHYSICS_TEST_OK displacement=%.3f affected=%d stack_peak=%.3f final_speed=%.3f counterweight=solved"
		% [
			maximum_displacement,
			displaced_bodies,
			maximum_stack_displacement,
			target.linear_velocity.length(),
		]
	)
	echo.queue_free()
	await process_frame
	call_deferred("quit")
