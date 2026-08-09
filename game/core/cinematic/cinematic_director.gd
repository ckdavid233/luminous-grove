class_name CinematicDirector
extends Node

signal cinematic_started(sequence_id: StringName)
signal subtitle_requested(text: String)
signal cinematic_finished(sequence_id: StringName, skipped: bool)

var is_playing := false

var _player
var _gameplay_camera: Camera3D
var _camera: Camera3D
var _active_tween: Tween
var _skip_requested := false
var _sequence_generation := 0


func configure(player: Node, gameplay_camera: Camera3D) -> void:
	assert(player != null, "CinematicDirector requires a controllable player")
	assert(gameplay_camera != null, "CinematicDirector requires a gameplay camera")
	_player = player
	_gameplay_camera = gameplay_camera
	_camera = Camera3D.new()
	_camera.name = "CinematicCamera"
	_camera.fov = gameplay_camera.fov
	add_child(_camera)


func play_sequence(sequence_id: StringName, shots: Array[Dictionary]) -> bool:
	if is_playing or shots.is_empty() or _player == null:
		return false
	is_playing = true
	_skip_requested = false
	_sequence_generation += 1
	var generation := _sequence_generation
	_player.call("set_control_enabled", false)
	_camera.global_transform = _gameplay_camera.global_transform
	_camera.fov = _gameplay_camera.fov
	_camera.cull_mask = _gameplay_camera.cull_mask
	_camera.make_current()
	cinematic_started.emit(sequence_id)
	_run_sequence(sequence_id, shots, generation)
	return true


func request_skip() -> bool:
	if not is_playing:
		return false
	_skip_requested = true
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.set_speed_scale(30.0)
	return true


func cancel_sequence() -> bool:
	if not is_playing:
		return false
	_sequence_generation += 1
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = null
	_restore_gameplay_state()
	is_playing = false
	_skip_requested = false
	return true


func _unhandled_input(event: InputEvent) -> void:
	if is_playing and event.is_action_pressed("skip_cinematic"):
		request_skip()


func _run_sequence(
	sequence_id: StringName,
	shots: Array[Dictionary],
	generation: int,
) -> void:
	for shot in shots:
		if _skip_requested or generation != _sequence_generation:
			break
		var target_position: Vector3 = shot.get("position", _camera.global_position)
		var look_at: Vector3 = shot.get("look_at", target_position + Vector3.FORWARD)
		var target_basis := Basis.looking_at(look_at - target_position, Vector3.UP)
		var target_transform := Transform3D(target_basis, target_position)
		var duration := maxf(float(shot.get("duration", 1.0)), 0.05)
		var subtitle := str(shot.get("subtitle", ""))
		if not subtitle.is_empty():
			subtitle_requested.emit(subtitle)
		_active_tween = create_tween()
		_active_tween.set_parallel(true)
		_active_tween.set_trans(Tween.TRANS_SINE)
		_active_tween.set_ease(Tween.EASE_IN_OUT)
		_active_tween.tween_property(_camera, "global_transform", target_transform, duration)
		_active_tween.tween_property(
			_camera,
			"fov",
			float(shot.get("fov", _camera.fov)),
			duration
		)
		await _active_tween.finished
	_active_tween = null
	if generation == _sequence_generation:
		_finish_sequence(sequence_id)


func _finish_sequence(sequence_id: StringName) -> void:
	var skipped := _skip_requested
	_restore_gameplay_state()
	is_playing = false
	_skip_requested = false
	cinematic_finished.emit(sequence_id, skipped)


func _restore_gameplay_state() -> void:
	if is_instance_valid(_gameplay_camera):
		_gameplay_camera.make_current()
	if is_instance_valid(_player):
		_player.call("set_control_enabled", true)


func _exit_tree() -> void:
	if is_playing:
		cancel_sequence()
