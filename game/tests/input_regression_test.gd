extends SceneTree


func _initialize() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://settings.cfg"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save_slot_1.json"))
	var main_scene := load("res://game/main/main.tscn") as PackedScene
	var main := main_scene.instantiate()
	root.add_child(main)
	for _frame in 4:
		await process_frame
		await physics_frame

	await _press_key(KEY_ESCAPE)
	var pause_overlay := main.get("_pause_overlay") as Control
	assert(paused and pause_overlay.visible, "Escape must open the real pause overlay")
	assert(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Pause must release the mouse")

	var quality_button := main.get("_quality_button") as Button
	assert(quality_button != null and quality_button.is_visible_in_tree())
	var quality_before: StringName = main.get_quality_profile()
	await _click_control(quality_button)
	assert(
		main.get_quality_profile() != quality_before,
		"A real mouse click must activate pause-menu buttons while the tree is paused",
	)

	var buttons := pause_overlay.find_children("*", "Button", true, false)
	assert(not buttons.is_empty())
	await _click_control(buttons[0] as Button)
	assert(not paused and not pause_overlay.visible, "Resume button must unpause the game")

	var player := main.get("_player") as CharacterBody3D
	var bell := main.get("_wind_bell") as Node
	player.global_position = Vector3(-2.8, 0.0, 2.6)
	player.rotation = Vector3.ZERO
	player.velocity = Vector3.ZERO
	for _frame in 3:
		await physics_frame
		await process_frame
	var prompt := player.get_node("HUD/PromptLabel") as Label
	assert(prompt.visible and "奏响风铃" in prompt.text, "Nearby bell must show a prompt")
	await _press_key(KEY_E)
	assert(bell.is_rung, "Physical E key must activate the nearby interactable")

	print(
		"INPUT_REGRESSION_TEST_OK pause=mouse_click interaction=physical_e profile=",
		main.get_quality_profile(),
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
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://settings.cfg"))
	main_scene = null
	call_deferred("quit")


func _press_key(key: Key) -> void:
	var pressed := InputEventKey.new()
	pressed.keycode = key
	pressed.physical_keycode = key
	pressed.pressed = true
	assert(
		InputMap.event_is_action(pressed, "pause_game")
		or InputMap.event_is_action(pressed, "interact"),
		"Synthetic physical key must match a configured gameplay action: %s" % key,
	)
	Input.parse_input_event(pressed)
	await process_frame
	await physics_frame
	var released := pressed.duplicate() as InputEventKey
	released.pressed = false
	Input.parse_input_event(released)
	await process_frame


func _click_control(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	await process_frame
	var pressed := InputEventMouseButton.new()
	pressed.button_index = MOUSE_BUTTON_LEFT
	pressed.position = point
	pressed.global_position = point
	pressed.pressed = true
	root.push_input(pressed, true)
	var released := pressed.duplicate() as InputEventMouseButton
	released.pressed = false
	root.push_input(released, true)
	await process_frame
	await physics_frame
