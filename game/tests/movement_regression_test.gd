extends SceneTree


func _initialize() -> void:
	var ground := StaticBody3D.new()
	ground.collision_layer = 1
	var ground_collision := CollisionShape3D.new()
	var ground_shape := BoxShape3D.new()
	ground_shape.size = Vector3(18.0, 0.5, 18.0)
	ground_collision.shape = ground_shape
	ground_collision.position.y = -0.25
	ground.add_child(ground_collision)
	root.add_child(ground)

	var player_scene := load("res://game/player/player.tscn") as PackedScene
	var player := player_scene.instantiate() as CharacterBody3D
	root.add_child(player)
	for _frame in 10:
		await physics_frame
		await process_frame
	assert(player.is_on_floor())

	Input.action_press("move_forward")
	for _frame in 2:
		await physics_frame
		await process_frame
	var acceleration_speed := Vector2(player.velocity.x, player.velocity.z).length()
	assert(acceleration_speed > 0.1 and acceleration_speed < 2.0)
	for _frame in 28:
		await physics_frame
		await process_frame
	var walk_speed := Vector2(player.velocity.x, player.velocity.z).length()
	assert(walk_speed > 4.65 and walk_speed <= 5.05)
	assert(player.get("_animation_state") == &"Walk")

	Input.action_release("move_forward")
	await physics_frame
	await process_frame
	var first_deceleration_speed := Vector2(player.velocity.x, player.velocity.z).length()
	assert(first_deceleration_speed > 0.1 and first_deceleration_speed < walk_speed)
	for _frame in 18:
		await physics_frame
		await process_frame
	assert(Vector2(player.velocity.x, player.velocity.z).length() < 0.08)

	Input.action_press("move_forward")
	Input.action_press("sprint")
	for _frame in 38:
		await physics_frame
		await process_frame
	var sprint_speed := Vector2(player.velocity.x, player.velocity.z).length()
	assert(sprint_speed > 7.2 and sprint_speed <= 8.05)
	assert(player.get("_animation_state") == &"Run")
	assert(float(player.get("_stamina")) < player.maximum_stamina)
	Input.action_release("move_forward")
	Input.action_release("sprint")
	for _frame in 24:
		await physics_frame
		await process_frame

	var jump_events: Array[bool] = []
	var landing_speeds: Array[float] = []
	player.jumped.connect(func() -> void: jump_events.append(true))
	player.landed.connect(
		func(impact_speed: float) -> void: landing_speeds.append(impact_speed)
	)
	Input.action_press("jump")
	for _frame in 2:
		await physics_frame
		await process_frame
	Input.action_release("jump")
	assert(jump_events.size() == 1)
	assert(player.velocity.y > 4.5)
	assert(player.get("_animation_state") == &"Jump")

	var saw_fall := false
	for _frame in 180:
		await physics_frame
		await process_frame
		if player.get("_animation_state") == &"Fall":
			saw_fall = true
		if not landing_speeds.is_empty():
			break
	assert(saw_fall, "Jump arc must transition through a dedicated Fall state")
	assert(not landing_speeds.is_empty())
	assert(landing_speeds[0] >= player.landing_animation_min_speed)
	assert(player.get("_animation_state") == &"Land")
	for _frame in 28:
		await physics_frame
		await process_frame
	assert(player.get("_animation_state") == &"Idle")

	print(
		"MOVEMENT_REGRESSION_TEST_OK acceleration=", snappedf(acceleration_speed, 0.01),
		" walk=", snappedf(walk_speed, 0.01),
		" sprint=", snappedf(sprint_speed, 0.01),
		" landing=", snappedf(landing_speeds[0], 0.01),
		" states=Walk,Run,Jump,Fall,Land,Idle",
	)
	player.queue_free()
	ground.queue_free()
	for _frame in 3:
		await physics_frame
		await process_frame
	quit()
