class_name PhaseShiftController
extends Node

signal preload_progress(progress: float)
signal alternate_world_ready
signal shift_started(target_phase: StringName)
signal shift_completed(active_phase: StringName)
signal shift_rejected(reason: String)

const PRESENT := &"present"
const ECHO := &"echo"
const PRESENT_VISUAL_LAYER := 1 << 0
const ECHO_VISUAL_LAYER := 1 << 1
const SHARED_VISUAL_LAYER := 1 << 2

var alternate_level_path := ""
var present_level_path := ""
var is_unlocked := false
var active_phase: StringName = PRESENT

var _streamer
var _player: CharacterBody3D
var _present_nodes: Array[Node] = []
var _world_environment: WorldEnvironment
var _sun: DirectionalLight3D
var _gameplay_camera: Camera3D
var _restore_query: PhysicsRayQueryParameters3D
var _pending_shift := false
var _alternate_ready := false
var _present_environment_state: Dictionary = {}


func configure(
	streamer: Node,
	player: CharacterBody3D,
	present_nodes: Array[Node],
	world_environment: WorldEnvironment,
	sun: DirectionalLight3D,
	level_path: String,
) -> Error:
	_streamer = streamer
	_player = player
	_present_nodes = present_nodes
	_world_environment = world_environment
	_sun = sun
	_gameplay_camera = _player.find_child("Camera", true, false) as Camera3D
	assert(_gameplay_camera != null, "Phase shifting requires the gameplay camera")
	alternate_level_path = level_path
	present_level_path = ""
	_capture_environment_state()
	_apply_gameplay_camera_layer(PRESENT)
	_streamer.load_progress.connect(_on_load_progress)
	_streamer.level_loaded.connect(_on_level_loaded)
	_restore_query = PhysicsRayQueryParameters3D.new()
	return _streamer.request_level(level_path, true)


func switch_world_pair(
	present_nodes: Array[Node],
	present_path: String,
	alternate_path: String,
) -> bool:
	if (
		not _streamer.is_level_ready(present_path)
		or not _streamer.is_level_ready(alternate_path)
	):
		return false
	_pending_shift = false
	_present_nodes = present_nodes
	present_level_path = present_path
	alternate_level_path = alternate_path
	_alternate_ready = true
	active_phase = PRESENT
	if not _streamer.activate_level(present_level_path):
		return false
	_set_present_active(true)
	_capture_environment_state()
	_apply_gameplay_camera_layer(PRESENT)
	return true


func suspend_current_pair() -> void:
	_pending_shift = false
	is_unlocked = false
	_set_present_active(false)
	_streamer.deactivate_current()


func set_unlocked(value: bool) -> void:
	is_unlocked = value


func request_shift() -> bool:
	if not is_unlocked:
		shift_rejected.emit("雨隙能力尚未苏醒")
		return false
	if not _alternate_ready:
		shift_rejected.emit("另一时相仍在后台加载")
		return false
	if _pending_shift:
		return false
	_pending_shift = true
	return true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("phase_shift"):
		request_shift()


func _physics_process(_delta: float) -> void:
	if not _pending_shift:
		return
	_pending_shift = false
	_perform_shift()


func _perform_shift() -> void:
	var target := ECHO if active_phase == PRESENT else PRESENT
	shift_started.emit(target)
	var saved_transform := _player.global_transform
	var saved_velocity := _player.velocity
	if target == ECHO:
		if not _streamer.activate_level(alternate_level_path):
			shift_rejected.emit("雨忆场景不可用")
			return
		_set_present_active(false)
		_apply_echo_environment()
	else:
		if present_level_path.is_empty():
			_streamer.deactivate_current()
		elif not _streamer.activate_level(present_level_path):
			shift_rejected.emit("此岸场景不可用")
			return
		_set_present_active(true)
		_restore_present_environment()
	active_phase = target
	_apply_gameplay_camera_layer(active_phase)
	_restore_player_safely(saved_transform, saved_velocity)
	shift_completed.emit(active_phase)


func _restore_player_safely(saved_transform: Transform3D, saved_velocity: Vector3) -> void:
	_player.global_transform = saved_transform
	if OS.get_cmdline_args().has("--script"):
		_player.velocity = saved_velocity
		return
	if _restore_query == null:
		_restore_query = PhysicsRayQueryParameters3D.new()
	_restore_query.from = saved_transform.origin + Vector3.UP * 3.0
	_restore_query.to = saved_transform.origin + Vector3.DOWN * 8.0
	_restore_query.exclude = [_player.get_rid()]
	_restore_query.collision_mask = 1
	var hit := _player.get_world_3d().direct_space_state.intersect_ray(_restore_query)
	_restore_query.exclude.clear()
	if not hit.is_empty():
		var floor_position: Vector3 = hit.position
		_player.global_position.y = floor_position.y + 1.0
	_player.velocity = saved_velocity


func _exit_tree() -> void:
	if _restore_query != null:
		_restore_query.exclude.clear()
		_restore_query = null


func _set_present_active(active: bool) -> void:
	for node in _present_nodes:
		if not is_instance_valid(node):
			continue
		node.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
		if node is Node3D:
			(node as Node3D).visible = active
		_set_collision_active(node, active)


func _set_collision_active(root: Node, active: bool) -> void:
	var collision_nodes: Array[Node] = []
	if root is CollisionObject3D:
		collision_nodes.append(root)
	collision_nodes.append_array(root.find_children("*", "CollisionObject3D", true, false))
	for node in collision_nodes:
		var collision_object := node as CollisionObject3D
		if not collision_object.has_meta("phase_collision_layer"):
			collision_object.set_meta("phase_collision_layer", collision_object.collision_layer)
			collision_object.set_meta("phase_collision_mask", collision_object.collision_mask)
		collision_object.collision_layer = (
			int(collision_object.get_meta("phase_collision_layer")) if active else 0
		)
		collision_object.collision_mask = (
			int(collision_object.get_meta("phase_collision_mask")) if active else 0
		)


func _capture_environment_state() -> void:
	var environment := _world_environment.environment
	_present_environment_state = {
		"background_energy": environment.background_energy_multiplier,
		"fog_color": environment.fog_light_color,
		"fog_density": environment.fog_density,
		"volumetric_density": environment.volumetric_fog_density,
		"volumetric_albedo": environment.volumetric_fog_albedo,
		"glow_intensity": environment.glow_intensity,
		"sun_color": _sun.light_color,
		"sun_energy": _sun.light_energy,
	}


func _apply_echo_environment() -> void:
	var environment := _world_environment.environment
	environment.background_energy_multiplier = 0.32
	environment.fog_light_color = Color("426f79")
	environment.fog_density = 0.014
	environment.volumetric_fog_density = 0.028
	environment.volumetric_fog_albedo = Color("4b8790")
	environment.glow_intensity = 0.86
	_sun.light_color = Color("83bdcc")
	_sun.light_energy = 0.52


func _restore_present_environment() -> void:
	var environment := _world_environment.environment
	environment.background_energy_multiplier = _present_environment_state.background_energy
	environment.fog_light_color = _present_environment_state.fog_color
	environment.fog_density = _present_environment_state.fog_density
	environment.volumetric_fog_density = _present_environment_state.volumetric_density
	environment.volumetric_fog_albedo = _present_environment_state.volumetric_albedo
	environment.glow_intensity = _present_environment_state.glow_intensity
	_sun.light_color = _present_environment_state.sun_color
	_sun.light_energy = _present_environment_state.sun_energy


func _apply_gameplay_camera_layer(phase: StringName) -> void:
	var world_layer := (
		ECHO_VISUAL_LAYER if phase == ECHO else PRESENT_VISUAL_LAYER
	)
	_gameplay_camera.cull_mask = world_layer | SHARED_VISUAL_LAYER


func _on_load_progress(path: String, progress: float) -> void:
	if path == alternate_level_path:
		preload_progress.emit(progress)


func _on_level_loaded(path: String, _instance: Node) -> void:
	if path == alternate_level_path:
		_alternate_ready = true
		alternate_world_ready.emit()
