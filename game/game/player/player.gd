class_name PlayerController
extends CharacterBody3D

signal interaction_started(target: Node)
signal interaction_target_changed(target: Node)
signal jumped
signal landed(impact_speed: float)
signal footstep_surface(world_position: Vector3, speed: float, surface_type: StringName)
signal void_recovered(previous_position: Vector3, checkpoint_position: Vector3)

const CHARACTER_VISUAL_QUALITY := preload(
	"res://game/player/character_visual_quality.gd"
)
const SURFACE_PROBE := preload("res://game/world/surface_probe.gd")

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
@export var visual_breathing_strength := 0.018
@export var visual_sway_strength := 0.045
@export var visual_stride_response := 0.09
@export var void_fall_threshold := -1.75

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
var _visual_time := 0.0
var _visual_previous_speed := 0.0
var _visual_base_position := Vector3.ZERO
var _visual_base_scale := Vector3.ONE
var _interaction_requested := false
var _interaction_refresh_pending := false
var _coyote_time_left := 0.0
var _jump_buffer_left := 0.0
var _landing_time_left := 0.0
var _last_vertical_velocity := 0.0
var _surface_library
var _surface_probe: SurfaceProbe
var _surface_sample: Dictionary = {}
var _footstep_distance_accumulator := 0.0
var _last_footstep_position := Vector3.INF
var _last_animation_name: StringName = &""
var _last_animation_position := -1.0
var _animation_footstep_active := false
var _skeleton: Skeleton3D
var _left_foot_target: Node3D
var _right_foot_target: Node3D
var _left_foot_ik: SkeletonIK3D
var _right_foot_ik: SkeletonIK3D
var _left_foot_query: PhysicsRayQueryParameters3D
var _right_foot_query: PhysicsRayQueryParameters3D
var _procedural_bone_offsets: Dictionary = {}
var _interaction_shape: SphereShape3D
var _interaction_query: PhysicsShapeQueryParameters3D
var _interaction_ray_query: PhysicsRayQueryParameters3D
var _shutdown_requested := false


func _ready() -> void:
	_stamina = maximum_stamina
	stamina_bar.max_value = maximum_stamina
	stamina_bar.value = _stamina
	_camera_base_height = camera_pivot.position.y
	_visual_base_position = model.position
	_visual_base_scale = model.scale
	_render_quality_stats = CHARACTER_VISUAL_QUALITY.apply_to(model)
	_setup_animation_tree()
	_setup_foot_ik()
	_surface_probe = SURFACE_PROBE.new()
	_surface_probe.name = "SurfaceProbe"
	add_child(_surface_probe)
	_surface_probe.configure(_surface_library)
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
	if _interaction_refresh_pending:
		_interaction_refresh_pending = false
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
	_update_foot_ik(delta)
	_update_animation_footsteps()
	_emit_surface_footstep()
	_update_interaction_target()
	_update_animation()
	_update_visual_motion(delta)


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
	_surface_sample = _sample_surface()
	target_speed *= float(_surface_sample.get("speed_multiplier", 1.0))
	var target_velocity := world_direction * target_speed * minf(input_vector.length(), 1.0)
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var response := acceleration if not input_vector.is_zero_approx() else deceleration
	if not is_on_floor():
		response *= air_control
	horizontal_velocity = horizontal_velocity.move_toward(target_velocity, response * delta)
	var surface_type: StringName = _surface_sample.get("type", &"dry_soil")
	var surface_normal: Vector3 = _surface_sample.get("normal", Vector3.UP)
	var surface_friction := float(_surface_sample.get("friction", 0.78))
	if is_on_floor() and surface_type in [&"wet_mud", &"stone"] and surface_normal.y < 0.84:
		var downslope := Vector3.DOWN.slide(surface_normal)
		horizontal_velocity += downslope * (1.0 - surface_friction) * 2.4 * delta
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


func set_surface_library(library) -> void:
	_surface_library = library
	if _surface_probe != null:
		_surface_probe.configure(library)


func _sample_surface() -> Dictionary:
	if _surface_probe != null:
		return _surface_probe.raycast_sample(self)
	if _surface_library == null or not _surface_library.has_method("sample"):
		return {
			"type": &"dry_soil",
			"speed_multiplier": 1.0,
			"wetness": 0.0,
		}
	var normal := get_floor_normal() if is_on_floor() else Vector3.UP
	return _surface_library.sample(global_position, normal)


func _emit_surface_footstep() -> void:
	if _animation_footstep_active:
		return
	if not is_on_floor():
		_last_footstep_position = global_position
		_footstep_distance_accumulator = 0.0
		return
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if horizontal_speed < 0.55:
		return
	if _last_footstep_position == Vector3.INF:
		_last_footstep_position = global_position
		return
	_footstep_distance_accumulator += global_position.distance_to(_last_footstep_position)
	if _footstep_distance_accumulator < (0.62 if _is_sprinting else 0.46):
		return
	var surface_type: StringName = _surface_sample.get("type", &"dry_soil")
	footstep_surface.emit(global_position, horizontal_speed, surface_type)
	_footstep_distance_accumulator = 0.0
	_last_footstep_position = global_position


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
	camera.fov = lerpf(camera.fov, 60.0 if _is_sprinting else 53.0, minf(1.0, delta * 5.5))


func _update_visual_motion(delta: float) -> void:
	# The imported locomotion clips provide the primary pose.  This secondary
	# pass adds weight shift, breathing and a small delayed torso response so
	# starts/stops/turns do not read as a rigid mannequin even when the same
	# source animation is used on different terrain.
	_visual_time += delta
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var horizontal_speed := horizontal_velocity.length()
	var speed_ratio := clampf(horizontal_speed / maxf(move_speed, 0.01), 0.0, 1.5)
	var acceleration_ratio := clampf(
		(horizontal_speed - _visual_previous_speed) / maxf(delta, 0.001),
		-2.5,
		2.5,
	) / 2.5
	_visual_previous_speed = lerpf(_visual_previous_speed, horizontal_speed, minf(1.0, delta * 10.0))
	var gait_rate := 5.9 + horizontal_speed * 1.5
	var gait := sin(_visual_time * gait_rate)
	var counter_gait := cos(_visual_time * gait_rate * 0.5)
	var grounded_weight := 1.0 if is_on_floor() else 0.35
	var breath := sin(_visual_time * 2.15) * visual_breathing_strength
	var sway := gait * visual_sway_strength * speed_ratio * grounded_weight
	var step_lift := absf(gait) * visual_stride_response * speed_ratio * grounded_weight
	var target_position := _visual_base_position + Vector3(
		-sway * 0.32,
		breath + step_lift,
		counter_gait * visual_sway_strength * 0.18 * speed_ratio,
	)
	model.position = model.position.lerp(
		target_position,
		minf(1.0, delta * 11.0),
	)
	var locomotion_pitch := clampf(-acceleration_ratio * 0.045, -0.045, 0.045)
	var locomotion_roll := sway * 0.72
	model.rotation.x = lerpf(model.rotation.x, locomotion_pitch, minf(1.0, delta * 8.0))
	# _update_movement owns the intentional turn lean. Add the secondary roll
	# after it rather than replacing that signal.
	var turn_lean := clampf(model.rotation.z, -0.11, 0.11)
	model.rotation.z = lerpf(
		model.rotation.z,
		turn_lean + locomotion_roll,
		minf(1.0, delta * 8.0),
	)
	var compression := clampf(step_lift * 0.24 - acceleration_ratio * 0.018, -0.028, 0.028)
	var target_scale := _visual_base_scale * Vector3(
		1.0 - compression,
		1.0 + compression * 0.72,
		1.0 - compression,
	)
	model.scale = model.scale.lerp(target_scale, minf(1.0, delta * 7.0))
	_update_procedural_bones(
		horizontal_speed,
		speed_ratio,
		grounded_weight,
		gait,
		counter_gait,
		breath,
		acceleration_ratio,
	)


func _update_procedural_bones(
	horizontal_speed: float,
	speed_ratio: float,
	grounded_weight: float,
	gait: float,
	counter_gait: float,
	breath: float,
	acceleration_ratio: float,
) -> void:
	if _skeleton == null or not is_instance_valid(_skeleton):
		return
	# Keep the authored clip as the base pose and add a small, deterministic
	# layer on top.  Imported clips can be subtle at the normal third-person
	# camera distance; this makes the shoulders, torso and head visibly respond
	# to gait, acceleration and breathing without replacing the mocap data.
	var walking_weight := clampf(speed_ratio, 0.0, 1.18)
	var interaction_weight := 1.0 if _interaction_time_left > 0.0 else 0.0
	var gait_weight := walking_weight * (1.0 - interaction_weight)
	var shoulder_swing := gait * 0.30 * gait_weight
	var opposite_swing := -shoulder_swing
	var torso_roll := gait * 0.085 * gait_weight
	var torso_pitch := clampf(-acceleration_ratio * 0.11, -0.11, 0.11)
	var head_counter := -torso_roll * 0.5
	var idle_breath := breath * 1.6 + sin(_visual_time * 1.05) * 0.012
	if interaction_weight > 0.0:
		# The interact clip supplies the main reach.  A restrained anticipation
		# and recovery layer makes the action read even if the imported clip is
		# viewed between keyframes.
		var interact_phase := 1.0 - clampf(_interaction_time_left / 1.65, 0.0, 1.0)
		var reach := sin(interact_phase * PI) * 0.30
		shoulder_swing = reach
		opposite_swing = -reach * 0.22
		torso_pitch = -reach * 0.10
		torso_roll = reach * 0.045
		idle_breath = 0.0
	_apply_bone_offset(&"spine_01", Vector3(torso_pitch, 0.0, torso_roll))
	_apply_bone_offset(&"spine_02", Vector3(torso_pitch * 0.68, 0.0, torso_roll * 0.78))
	_apply_bone_offset(&"spine_03", Vector3(torso_pitch * 0.42, 0.0, torso_roll * 0.55))
	_apply_bone_offset(&"upperarm_l", Vector3(shoulder_swing, 0.0, -shoulder_swing * 0.24))
	_apply_bone_offset(&"upperarm_r", Vector3(opposite_swing, 0.0, -opposite_swing * 0.24))
	_apply_bone_offset(&"lowerarm_l", Vector3(shoulder_swing * 0.42, 0.0, -shoulder_swing * 0.12))
	_apply_bone_offset(&"lowerarm_r", Vector3(opposite_swing * 0.42, 0.0, -opposite_swing * 0.12))
	_apply_bone_offset(&"thigh_l", Vector3(-shoulder_swing * 0.38, 0.0, 0.0))
	_apply_bone_offset(&"thigh_r", Vector3(shoulder_swing * 0.38, 0.0, 0.0))
	_apply_bone_offset(&"calf_l", Vector3(shoulder_swing * 0.22, 0.0, 0.0))
	_apply_bone_offset(&"calf_r", Vector3(-shoulder_swing * 0.22, 0.0, 0.0))
	_apply_bone_offset(
		&"head",
		Vector3(-torso_pitch * 0.35, head_counter, idle_breath * 0.42),
	)
	_apply_bone_offset(&"neck_01", Vector3(-torso_pitch * 0.18, head_counter * 0.5, 0.0))


func _apply_bone_offset(bone_name: StringName, euler_offset: Vector3) -> void:
	var bone_index := _skeleton.find_bone(bone_name)
	if bone_index < 0:
		return
	var previous: Quaternion = _procedural_bone_offsets.get(
		bone_index,
		Quaternion.IDENTITY,
	)
	var current := _skeleton.get_bone_pose_rotation(bone_index)
	# Remove only the offset written on the previous physics tick; the
	# AnimationPlayer remains the source of the base pose and can transition
	# between Walk/Run/Jump/Interact normally.
	var base_pose := current * previous.inverse()
	var next_offset := Basis.from_euler(euler_offset).get_rotation_quaternion()
	_skeleton.set_bone_pose_rotation(bone_index, base_pose * next_offset)
	_procedural_bone_offsets[bone_index] = next_offset


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
	# Godot 4.7's imported AnimationTree can report a valid state-machine node
	# while never advancing the nested GLB AnimationPlayer when the tree is
	# constructed at runtime.  Keep the graph for tooling/authoring, but drive
	# the imported clips through AnimationPlayer directly so the pose is always
	# evaluated in a Windows build.  Direct playback still supports cross-fades
	# and the same named locomotion states.
	_animation_tree.active = false
	_animation_playback = _animation_tree.get("parameters/playback")
	_animation_state = &"Idle"
	_animation_player.callback_mode_process = AnimationPlayer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	_animation_player.play(&"Idle")
	_animation_player.advance(0.0)
	_interaction_shape = SphereShape3D.new()
	_interaction_shape.radius = interaction_distance
	_interaction_query = PhysicsShapeQueryParameters3D.new()
	_interaction_query.shape = _interaction_shape
	_interaction_query.collision_mask = 1 << 2
	_interaction_query.collide_with_bodies = true
	_interaction_query.collide_with_areas = true
	_interaction_ray_query = PhysicsRayQueryParameters3D.new()


func _setup_foot_ik() -> void:
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return
	_skeleton = skeletons[0] as Skeleton3D
	if _skeleton.find_bone("foot_l") < 0 or _skeleton.find_bone("foot_r") < 0:
		return
	_left_foot_target = Node3D.new()
	_left_foot_target.name = "FootTargetL"
	_left_foot_target.position = Vector3(-0.17, 0.0, 0.12)
	add_child(_left_foot_target)
	_right_foot_target = Node3D.new()
	_right_foot_target.name = "FootTargetR"
	_right_foot_target.position = Vector3(0.17, 0.0, 0.12)
	add_child(_right_foot_target)
	_left_foot_ik = _create_foot_ik("thigh_l", "foot_l", _left_foot_target)
	_right_foot_ik = _create_foot_ik("thigh_r", "foot_r", _right_foot_target)
	_left_foot_query = PhysicsRayQueryParameters3D.new()
	_right_foot_query = PhysicsRayQueryParameters3D.new()


func _create_foot_ik(root_bone: StringName, tip_bone: StringName, target: Node3D) -> SkeletonIK3D:
	var ik := SkeletonIK3D.new()
	ik.name = "IK_" + str(tip_bone)
	ik.root_bone = root_bone
	ik.tip_bone = tip_bone
	ik.override_tip_basis = true
	ik.influence = 0.68
	_skeleton.add_child(ik)
	ik.target_node = ik.get_path_to(target)
	ik.start()
	return ik


func _update_foot_ik(_delta: float) -> void:
	if _skeleton == null or _left_foot_target == null or _right_foot_target == null:
		return
	_update_foot_target(
		_left_foot_target,
		Vector3(-0.17, 0.0, 0.12),
		_left_foot_query,
	)
	_update_foot_target(
		_right_foot_target,
		Vector3(0.17, 0.0, 0.12),
		_right_foot_query,
	)


func _update_foot_target(
	target: Node3D,
	local_offset: Vector3,
	query: PhysicsRayQueryParameters3D,
) -> void:
	if target == null or query == null or get_world_3d() == null:
		return
	var origin := global_position + global_basis * local_offset + Vector3.UP * 0.74
	query.from = origin
	query.to = origin + Vector3.DOWN * 1.42
	query.exclude = [get_rid()]
	query.collision_mask = 1
	# Hold and explicitly release the Jolt direct-space wrapper in the same
	# physics tick.  Chaining the property access leaves a transient
	# JoltPhysicsDirectSpaceState3D alive until world teardown on some builds.
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var hit := space_state.intersect_ray(query)
	space_state = null
	query.exclude.clear()
	var normal := Vector3.UP
	if hit.is_empty():
		target.global_position = global_position + global_basis * local_offset
		target.global_basis = global_basis
		return
	target.global_position = (hit.position as Vector3) + (hit.normal as Vector3) * 0.025
	normal = (hit.normal as Vector3).normalized()
	var forward := (-global_basis.z).slide(normal)
	if forward.length_squared() < 0.001:
		forward = Vector3.FORWARD.slide(normal)
	if forward.length_squared() > 0.001:
		target.global_basis = Basis.looking_at(forward.normalized(), normal)


func _set_foot_ik_influence(value: float) -> void:
	if _left_foot_ik != null:
		_left_foot_ik.influence = value
	if _right_foot_ik != null:
		_right_foot_ik.influence = value


func _update_animation() -> void:
	if _interaction_time_left > 0.0:
		_animation_footstep_active = false
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


func _update_animation_footsteps() -> void:
	_animation_footstep_active = false
	if (
		_animation_player == null
		or not is_on_floor()
		or _animation_state not in [&"Walk", &"Run"]
		or not _animation_player.has_animation(_animation_state)
	):
		_last_animation_name = &""
		_last_animation_position = -1.0
		return
	var animation_name := _animation_player.current_animation
	if animation_name not in [&"Walk", &"Run"]:
		return
	var animation_length := _animation_player.current_animation_length
	if animation_length <= 0.01:
		return
	_animation_footstep_active = true
	var normalized_position := fposmod(
		_animation_player.current_animation_position,
		animation_length,
	) / animation_length
	if _last_animation_name != animation_name or _last_animation_position < 0.0:
		_last_animation_name = animation_name
		_last_animation_position = normalized_position
		return
	var wrapped := normalized_position + 0.02 < _last_animation_position
	var phases := [0.16, 0.66] if _animation_state == &"Walk" else [0.12, 0.58]
	for phase in phases:
		var crossed: bool = (
			(_last_animation_position <= phase and normalized_position >= phase)
			if not wrapped
			else (_last_animation_position <= phase or normalized_position >= phase)
		)
		if crossed:
			_emit_animation_footstep()
	_last_animation_position = normalized_position


func _emit_animation_footstep() -> void:
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if horizontal_speed < 0.55:
		return
	var surface_type: StringName = _surface_sample.get("type", &"dry_soil")
	footstep_surface.emit(global_position, horizontal_speed, surface_type)


func _travel_animation(next_state: StringName) -> void:
	var changed := next_state != _animation_state
	_animation_state = next_state
	if _animation_tree != null and _animation_tree.active and _animation_playback != null:
		if changed:
			_animation_playback.travel(next_state)
		return
	# Direct AnimationPlayer playback is the runtime path.  Re-issue play when
	# an imported clip was stopped by a cinematic or when the state was entered
	# before the player finished importing its animation library.
	if _animation_player == null or not is_instance_valid(_animation_player):
		return
	var animation_name := next_state
	if not _animation_player.has_animation(animation_name):
		animation_name = &"Idle"
	if changed or _animation_player.current_animation != animation_name or not _animation_player.is_playing():
		_animation_player.play(animation_name, 0.16 if changed else 0.0)


func request_interaction() -> bool:
	if not _control_enabled or _interaction_time_left > 0.0:
		return false
	if (
		_interaction_target == null
		or not is_instance_valid(_interaction_target)
		or (
			_interaction_target.has_method("can_interact")
			and not _interaction_target.can_interact(self)
		)
	):
		_interaction_target = null
		_update_interaction_target()
	if _interaction_target == null:
		return false
	_begin_interaction()
	return true


func refresh_interaction_target() -> void:
	# Phase transitions and streamed-level swaps can change collision layers
	# between two physics ticks. Expose an explicit refresh so the next input
	# cannot use a stale, now-disabled interactable.
	_interaction_target = null
	_interaction_refresh_pending = true
	prompt_label.text = ""
	prompt_label.visible = false


func set_visual_quality_profile(profile: StringName) -> void:
	CHARACTER_VISUAL_QUALITY.apply_profile(model, profile)
	_set_foot_ik_influence(0.0 if profile == &"performance" else 0.68)


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
	if _interaction_ray_query == null:
		_interaction_ray_query = PhysicsRayQueryParameters3D.new()
	_interaction_ray_query.from = from
	_interaction_ray_query.to = to
	_interaction_ray_query.exclude = [get_rid()]
	_interaction_ray_query.collision_mask = 0b101
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var hit := space_state.intersect_ray(_interaction_ray_query)
	space_state = null
	_interaction_ray_query.exclude.clear()
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
	if _interaction_query == null or _interaction_shape == null:
		return null
	_interaction_shape.radius = interaction_distance
	_interaction_query.transform = Transform3D(
		Basis.IDENTITY,
		global_position + Vector3.UP * 1.0,
	)
	_interaction_query.exclude = [get_rid()]
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var hits := space_state.intersect_shape(_interaction_query, 32)
	space_state = null
	_interaction_query.exclude.clear()
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


func _exit_tree() -> void:
	shutdown()


func shutdown() -> void:
	if _shutdown_requested:
		return
	_shutdown_requested = true
	_control_enabled = false
	set_process(false)
	set_physics_process(false)
	set_process_input(false)
	set_process_unhandled_input(false)
	_interaction_target = null
	_surface_library = null
	if _surface_probe != null and is_instance_valid(_surface_probe):
		if _surface_probe.has_method("shutdown"):
			_surface_probe.shutdown()
	_surface_probe = null
	_surface_sample.clear()
	_animation_footstep_active = false
	_animation_playback = null
	if _animation_tree != null and is_instance_valid(_animation_tree):
		_animation_tree.active = false
		_animation_tree.tree_root = null
		_animation_tree.anim_player = NodePath("")
	if _animation_player != null and is_instance_valid(_animation_player):
		_animation_player.stop()
		# AnimationLibrary and its Animation resources are built-in
		# RefCounted properties rather than script fields. Remove the instance
		# libraries after disabling AnimationTree so they do not survive the
		# player's final scene-tree teardown.
		for library_name in _animation_player.get_animation_library_list():
			_animation_player.remove_animation_library(library_name)
	_animation_tree = null
	_animation_player = null
	_skeleton = null
	if _left_foot_ik != null and is_instance_valid(_left_foot_ik):
		_left_foot_ik.stop()
	if _right_foot_ik != null and is_instance_valid(_right_foot_ik):
		_right_foot_ik.stop()
	_left_foot_ik = null
	_right_foot_ik = null
	_left_foot_target = null
	_right_foot_target = null
	if _interaction_query != null:
		_interaction_query.exclude.clear()
		_interaction_query = null
	_interaction_shape = null
	if _interaction_ray_query != null:
		_interaction_ray_query.exclude.clear()
		_interaction_ray_query = null
	if _left_foot_query != null:
		_left_foot_query.exclude.clear()
		_left_foot_query = null
	if _right_foot_query != null:
		_right_foot_query.exclude.clear()
		_right_foot_query = null


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
	if not checkpoint.origin.is_finite() or checkpoint.origin.y < -2.5:
		return
	_checkpoint_transform = checkpoint
	_has_checkpoint = true


func get_stamina() -> float:
	return _stamina


func is_sprinting() -> bool:
	return _is_sprinting


func _recover_from_fall() -> void:
	if global_position.is_finite() and global_position.y >= void_fall_threshold:
		return
	var previous_position := global_position
	var recovery_transform := _checkpoint_transform
	if not _has_checkpoint or not recovery_transform.origin.is_finite() or recovery_transform.origin.y < -2.5:
		recovery_transform = Transform3D(Basis.IDENTITY, Vector3(0.0, 1.0, 6.0))
	global_transform = recovery_transform
	velocity = Vector3.ZERO
	_control_enabled = true
	_interaction_time_left = 0.0
	_interaction_requested = false
	_landing_time_left = 0.0
	_coyote_time_left = coyote_time
	_surface_sample.clear()
	_stamina = maxf(_stamina, maximum_stamina * 0.35)
	stamina_bar.value = _stamina
	void_recovered.emit(previous_position, recovery_transform.origin)
