class_name PlayerController
extends CharacterBody3D

signal interaction_started(target: Node)
signal interaction_target_changed(target: Node)
signal jumped
signal landed(impact_speed: float)

const CHARACTER_VISUAL_QUALITY := preload(
	"res://game/player/character_visual_quality.gd"
)

@export var move_speed := 5.0
@export var sprint_speed := 8.0
@export var acceleration := 16.0
@export var deceleration := 22.0
@export var air_control := 0.38
@export var rotation_speed := 10.0
@export var mouse_sensitivity := 0.0025
@export var gamepad_look_speed := 2.35
@export var interaction_distance := 3.2
@export var jump_velocity := 5.8
@export var maximum_stamina := 100.0
@export var stamina_drain_per_second := 24.0
@export var stamina_recovery_per_second := 19.0
@export var coyote_time := 0.13
@export var jump_buffer_time := 0.14
@export var landing_animation_min_speed := 1.75

@onready var model: Node3D = %Model
@onready var camera_pivot: Node3D = %CameraPivot
@onready var camera: Camera3D = %Camera
@onready var prompt_label: Label = %PromptLabel
@onready var stamina_bar: ProgressBar = %StaminaBar

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _interaction_target: Node = null
var _animation_tree: AnimationTree
var _animation_player: AnimationPlayer
var _animation_playback: AnimationNodeStateMachinePlayback
var _animation_state: StringName = &""
var _interaction_time_left := 0.0
var _control_enabled := true
var _render_quality_stats: Dictionary = {}
var _stamina := 100.0
var _stamina_recovery_delay := 0.0
var _is_sprinting := false
var _checkpoint_transform := Transform3D.IDENTITY
var _has_checkpoint := false
var _camera_bob_time := 0.0
var _camera_base_height := 1.5
var _interaction_requested := false
var _coyote_time_left := 0.0
var _jump_buffer_left := 0.0
var _landing_time_left := 0.0
var _last_vertical_velocity := 0.0


func _ready() -> void:
	_stamina = maximum_stamina
	stamina_bar.max_value = maximum_stamina
	stamina_bar.value = _stamina
	_camera_base_height = camera_pivot.position.y
	_render_quality_stats = CHARACTER_VISUAL_QUALITY.apply_to(model)
	_setup_animation_tree()
	set_checkpoint(global_transform)
	_coyote_time_left = coyote_time
	if not OS.get_cmdline_args().has("--script"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if not _control_enabled:
		return
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
		and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED
	):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera_pivot.rotate_x(-event.relative.y * mouse_sensitivity)
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, -0.85, 0.6)
	elif event.is_action_pressed("toggle_mouse_capture"):
		Input.mouse_mode = (
			Input.MOUSE_MODE_VISIBLE
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
			else Input.MOUSE_MODE_CAPTURED
		)
	elif event.is_action_pressed("interact"):
		_interaction_requested = true


func _physics_process(delta: float) -> void:
	_interaction_time_left = maxf(_interaction_time_left - delta, 0.0)
	_landing_time_left = maxf(_landing_time_left - delta, 0.0)
	_jump_buffer_left = maxf(_jump_buffer_left - delta, 0.0)
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_left = jump_buffer_time
	if Input.is_action_just_pressed("interact"):
		_interaction_requested = true
	_update_interaction_target()
	if _interaction_requested:
		request_interaction()
		_interaction_requested = false
	_update_gamepad_look(delta)
	_update_movement(delta)
	var was_on_floor := is_on_floor()
	_last_vertical_velocity = velocity.y
	move_and_slide()
	if not was_on_floor and is_on_floor():
		var impact_speed := maxf(0.0, -_last_vertical_velocity)
		_landing_time_left = 0.36 if impact_speed >= landing_animation_min_speed else 0.0
		landed.emit(impact_speed)
	_recover_from_fall()
	_update_interaction_target()
	_update_animation()


func _update_movement(delta: float) -> void:
	var input_vector := (
		Vector2.ZERO
		if _interaction_time_left > 0.0 or not _control_enabled
		else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	)
	var local_direction := Vector3(input_vector.x, 0.0, input_vector.y)
	var world_direction := (global_basis * local_direction).normalized()
	var wants_sprint := (
		Input.is_action_pressed("sprint")
		and world_direction.length_squared() > 0.01
		and _stamina > 0.0
		and is_on_floor()
		and _interaction_time_left <= 0.0
		and _control_enabled
	)
	_is_sprinting = wants_sprint
	_update_stamina(delta)
	var target_speed := sprint_speed if _is_sprinting else move_speed
	var target_velocity := world_direction * target_speed * minf(input_vector.length(), 1.0)
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var response := acceleration if not input_vector.is_zero_approx() else deceleration
	if not is_on_floor():
		response *= air_control
	horizontal_velocity = horizontal_velocity.move_toward(target_velocity, response * delta)
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z
	if not is_on_floor():
		velocity.y -= _gravity * delta
		_coyote_time_left = maxf(0.0, _coyote_time_left - delta)
	else:
		_coyote_time_left = coyote_time
		velocity.y = -0.2
	if (
		_jump_buffer_left > 0.0
		and _coyote_time_left > 0.0
		and _interaction_time_left <= 0.0
		and _control_enabled
	):
		velocity.y = jump_velocity
		_jump_buffer_left = 0.0
		_coyote_time_left = 0.0
		jumped.emit()

	if world_direction.length_squared() > 0.01:
		var target_angle := atan2(world_direction.x, world_direction.z)
		model.rotation.y = lerp_angle(model.rotation.y, target_angle - rotation.y, rotation_speed * delta)
	var target_lean := clampf(-input_vector.x * 0.055, -0.055, 0.055)
	model.rotation.z = lerpf(model.rotation.z, target_lean, minf(1.0, delta * 7.5))
	_update_camera_motion(delta, Vector2(velocity.x, velocity.z).length())


func _update_gamepad_look(delta: float) -> void:
	if not _control_enabled or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if look.length_squared() < 0.0025:
		return
	rotate_y(-look.x * gamepad_look_speed * delta)
	camera_pivot.rotate_x(-look.y * gamepad_look_speed * delta)
	camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, -0.85, 0.6)


func _update_stamina(delta: float) -> void:
	var previous := _stamina
	if _is_sprinting:
		_stamina = maxf(0.0, _stamina - stamina_drain_per_second * delta)
		_stamina_recovery_delay = 0.72
		if _stamina <= 0.0:
			_is_sprinting = false
	else:
		_stamina_recovery_delay = maxf(0.0, _stamina_recovery_delay - delta)
		if _stamina_recovery_delay <= 0.0:
			_stamina = minf(
				maximum_stamina,
				_stamina + stamina_recovery_per_second * delta,
			)
	if not is_equal_approx(previous, _stamina):
		stamina_bar.value = _stamina
	stamina_bar.modulate.a = 1.0 if _stamina < maximum_stamina - 0.1 else 0.36


func _update_camera_motion(delta: float, horizontal_speed: float) -> void:
	var moving := horizontal_speed > 0.3 and is_on_floor()
	if moving:
		_camera_bob_time += delta * (11.5 if _is_sprinting else 8.2)
	var bob := sin(_camera_bob_time) * (0.045 if _is_sprinting else 0.026) if moving else 0.0
	camera_pivot.position.y = lerpf(
		camera_pivot.position.y,
		_camera_base_height + bob,
		minf(1.0, delta * 9.0),
	)
	camera.fov = lerpf(camera.fov, 64.0 if _is_sprinting else 58.0, minf(1.0, delta * 5.5))


func _setup_animation_tree() -> void:
	_animation_player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	assert(_animation_player != null, "Imported player requires AnimationPlayer")
	for looping_animation in [&"Idle", &"Walk", &"Run", &"Fall"]:
		if _animation_player.has_animation(looping_animation):
			_animation_player.get_animation(looping_animation).loop_mode = Animation.LOOP_LINEAR

	var state_machine := AnimationNodeStateMachine.new()
	for animation_name in [&"Idle", &"Walk", &"Run", &"Jump", &"Fall", &"Land", &"Interact"]:
		var animation_node := AnimationNodeAnimation.new()
		var fallback: StringName = &"Idle"
		if animation_name == &"Run":
			fallback = &"Walk"
		elif animation_name in [&"Jump", &"Fall", &"Land"]:
			fallback = &"Idle"
		animation_node.animation = animation_name if _animation_player.has_animation(animation_name) else fallback
		state_machine.add_node(animation_name, animation_node)

	var animation_states: Array[StringName] = [
		&"Idle", &"Walk", &"Run", &"Jump", &"Fall", &"Land", &"Interact",
	]
	for from_state in animation_states:
		for to_state in animation_states:
			if from_state == to_state:
				continue
			var transition := AnimationNodeStateMachineTransition.new()
			transition.xfade_time = 0.12 if to_state in [&"Jump", &"Land"] else 0.18
			state_machine.add_transition(from_state, to_state, transition)

	_animation_tree = AnimationTree.new()
	_animation_tree.name = "AnimationTree"
	add_child(_animation_tree)
	_animation_tree.tree_root = state_machine
	_animation_tree.anim_player = _animation_tree.get_path_to(_animation_player)
	_animation_tree.active = true
	_animation_playback = _animation_tree.get("parameters/playback")
	_animation_state = &"Idle"
	_animation_playback.start(&"Idle")


func _update_animation() -> void:
	if _interaction_time_left > 0.0:
		return
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var next_state: StringName = &"Idle"
	if not is_on_floor():
		next_state = &"Jump" if velocity.y > 0.15 else &"Fall"
	elif _landing_time_left > 0.0:
		next_state = &"Land"
	elif horizontal_speed > 0.25:
		next_state = &"Run" if _is_sprinting else &"Walk"
	match next_state:
		&"Walk":
			_animation_player.speed_scale = clampf(horizontal_speed / move_speed, 0.72, 1.18)
		&"Run":
			_animation_player.speed_scale = clampf(horizontal_speed / sprint_speed, 0.82, 1.2)
		_:
			_animation_player.speed_scale = 1.0
	_travel_animation(next_state)


func _travel_animation(next_state: StringName) -> void:
	if next_state == _animation_state:
		return
	_animation_state = next_state
	_animation_playback.travel(next_state)


func request_interaction() -> bool:
	if not _control_enabled or _interaction_time_left > 0.0:
		return false
	if _interaction_target == null or not is_instance_valid(_interaction_target):
		_update_interaction_target()
	if _interaction_target == null:
		return false
	_begin_interaction()
	return true


func set_visual_quality_profile(profile: StringName) -> void:
	CHARACTER_VISUAL_QUALITY.apply_profile(model, profile)


func _begin_interaction() -> void:
	var target := _interaction_target
	if target == null or not is_instance_valid(target):
		return
	_interaction_time_left = 1.65
	_animation_player.speed_scale = 1.0
	_travel_animation(&"Interact")
	set_checkpoint(global_transform)
	target.interact(self)
	interaction_started.emit(target)


func _update_interaction_target() -> void:
	var viewport_center := get_viewport().get_visible_rect().size * 0.5
	var from := camera.project_ray_origin(viewport_center)
	var to := from + camera.project_ray_normal(viewport_center) * interaction_distance
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	query.collision_mask = 0b101
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var candidate: Node = hit.get("collider") if not hit.is_empty() else null
	var next_target := _find_interactable(candidate)
	if next_target == null:
		next_target = _find_best_nearby_interactable()
	if next_target != _interaction_target:
		_interaction_target = next_target
		interaction_target_changed.emit(_interaction_target)

	if _interaction_target == null:
		prompt_label.text = ""
		prompt_label.visible = false
	else:
		prompt_label.text = "[E / X] " + _interaction_target.get_prompt(self)
		prompt_label.visible = true


func _find_best_nearby_interactable() -> Node:
	var sphere := SphereShape3D.new()
	sphere.radius = interaction_distance
	var parameters := PhysicsShapeQueryParameters3D.new()
	parameters.shape = sphere
	parameters.transform = Transform3D(Basis.IDENTITY, global_position + Vector3.UP * 1.0)
	parameters.exclude = [get_rid()]
	parameters.collision_mask = 1 << 2
	parameters.collide_with_bodies = true
	parameters.collide_with_areas = true
	var hits := get_world_3d().direct_space_state.intersect_shape(parameters, 32)
	var camera_forward := -camera.global_basis.z.normalized()
	var best_target: Node = null
	var best_score := INF
	var seen: Dictionary = {}
	for result in hits:
		var collider := result.get("collider") as Node
		var target := _find_interactable(collider)
		if target == null or seen.has(target.get_instance_id()):
			continue
		seen[target.get_instance_id()] = true
		var target_node := target as Node3D
		if target_node == null:
			continue
		var offset := target_node.global_position + Vector3.UP - camera.global_position
		var distance := global_position.distance_to(target_node.global_position)
		var facing := camera_forward.dot(offset.normalized())
		if facing < 0.05 and distance > 1.35:
			continue
		var score := distance - facing * 0.85
		if score < best_score:
			best_score = score
			best_target = target
	return best_target


func _find_interactable(candidate: Node) -> Node:
	var current := candidate
	while current != null:
		if current.is_in_group("interactable") and current.has_method("interact"):
			if not current.has_method("can_interact") or current.can_interact(self):
				return current
		current = current.get_parent()
	return null


func set_control_enabled(value: bool) -> void:
	_control_enabled = value
	if not value:
		velocity.x = 0.0
		velocity.z = 0.0
		prompt_label.visible = false
		_interaction_target = null
		_interaction_requested = false


func set_checkpoint(checkpoint: Transform3D) -> void:
	_checkpoint_transform = checkpoint
	_has_checkpoint = true


func get_stamina() -> float:
	return _stamina


func is_sprinting() -> bool:
	return _is_sprinting


func _recover_from_fall() -> void:
	if global_position.y >= -6.5 or not _has_checkpoint:
		return
	global_transform = _checkpoint_transform
	velocity = Vector3.ZERO
	_stamina = maxf(_stamina, maximum_stamina * 0.35)
	stamina_bar.value = _stamina
