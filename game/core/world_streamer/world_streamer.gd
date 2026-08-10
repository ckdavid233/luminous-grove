class_name WorldStreamer
extends Node

const STREAM_CACHE_MODE := ResourceLoader.CACHE_MODE_IGNORE

signal load_requested(path: String)
signal load_progress(path: String, progress: float)
signal level_loaded(path: String, instance: Node)
signal level_activated(path: String, previous_path: String)
signal level_unloaded(path: String)
signal load_failed(path: String)

@export_range(1, 4) var max_resident_levels := 2

var _host: Node
var _requests: Dictionary = {}
var _instances: Dictionary = {}
var _last_used: Dictionary = {}
var _current_path := ""
var _clock := 0
var _tearing_down := false


func _ready() -> void:
	_host = get_parent()


func _exit_tree() -> void:
	# Threaded level instances can outlive the current phase when a test or
	# application exits. Explicitly release both active and inactive instances
	# so the streamer never leaves orphaned nodes/resource references behind.
	_tearing_down = true
	shutdown()


func shutdown() -> void:
	set_process(false)
	_disconnect_runtime_signals()
	_drain_threaded_requests()
	_current_path = ""
	var can_free_instances := is_inside_tree() and not _tearing_down
	for path in _instances.keys():
		var instance: Node = _instances[path]
		if is_instance_valid(instance):
			_release_instance_resources(instance)
			# During `_exit_tree` the host is already iterating its children; an
			# immediate free would re-enter remove_child and can crash Godot. An
			# explicit runtime shutdown is safe to free immediately, while parent
			# teardown lets the host reclaim the child normally.
			if can_free_instances:
				instance.free()
	_instances.clear()
	_last_used.clear()
	_requests.clear()
	_host = null


func _drain_threaded_requests() -> void:
	# ResourceLoader has no cancellation API for a threaded PackedScene request.
	# Calling load_threaded_get during shutdown waits for the worker and releases
	# the returned resource, preventing a request from surviving the scene tree
	# that started it. This path only runs during teardown, never per frame.
	for path_variant in _requests.keys():
		var path := str(path_variant)
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			var pending_resource = ResourceLoader.load_threaded_get(path)
			pending_resource = null
		elif status == ResourceLoader.THREAD_LOAD_LOADED:
			var loaded_resource = ResourceLoader.load_threaded_get(path)
			loaded_resource = null


func _disconnect_runtime_signals() -> void:
	# Threaded loading exposes callbacks to both Main and PhaseShiftController.
	# Disconnect them before clearing instances so their Callable wrappers do not
	# survive a streamed-level teardown as zero-reference RefCounted objects.
	for signal_ref in [
		load_requested,
		load_progress,
		level_loaded,
		level_activated,
		level_unloaded,
		load_failed,
	]:
		for connection in signal_ref.get_connections():
			var callback: Callable = connection.get("callable", Callable())
			if callback.is_valid() and signal_ref.is_connected(callback):
				signal_ref.disconnect(callback)


func _release_instance_resources(instance: Node) -> void:
	# A streamed level creates several runtime-only Mesh/Material resources.
	# Detach those references before queue_free so CACHE_MODE_IGNORE loads do not
	# leave a zero-reference RefCounted alive until process shutdown.
	_disconnect_instance_signals(instance)
	if instance.has_method("shutdown"):
		instance.shutdown()
	for geometry in instance.find_children("*", "GeometryInstance3D", true, false):
		var visual := geometry as GeometryInstance3D
		visual.material_override = null
		if visual is MeshInstance3D:
			(visual as MeshInstance3D).mesh = null
		elif visual is MultiMeshInstance3D:
			(visual as MultiMeshInstance3D).multimesh = null
	for node in instance.find_children("*", "CollisionObject3D", true, false):
		if node is StaticBody3D or node is RigidBody3D:
			var collision_object := node as CollisionObject3D
			if collision_object.physics_material_override != null:
				collision_object.physics_material_override = null


func _disconnect_instance_signals(instance: Node) -> void:
	var nodes: Array[Node] = [instance]
	nodes.append_array(instance.find_children("*", "Node", true, false))
	for node in nodes:
		if not is_instance_valid(node):
			continue
		for signal_info in node.get_signal_list():
			var signal_name: StringName = signal_info.get("name", &"")
			if signal_name.is_empty():
				continue
			for connection in node.get_signal_connection_list(signal_name):
				var callback: Callable = connection.get("callable", Callable())
				if not callback.is_valid():
					continue
				# Stream teardown owns scripted level callbacks only.  Native
				# engine connections are released by the scene tree and must not be
				# disconnected here while the parent is unwinding.
				var target: Object = callback.get_object()
				if target == null or target.get_script() == null:
					continue
				if node.is_connected(signal_name, callback):
					node.disconnect(signal_name, callback)


func configure(host: Node, resident_limit: int = 2) -> void:
	assert(host != null, "WorldStreamer requires a host")
	_host = host
	max_resident_levels = clampi(resident_limit, 1, 4)


func request_level(path: String, use_sub_threads := true) -> Error:
	if not ResourceLoader.exists(path, "PackedScene"):
		load_failed.emit(path)
		return ERR_FILE_NOT_FOUND
	if _instances.has(path) or _requests.has(path):
		return OK
	var error := ResourceLoader.load_threaded_request(
		path,
		"PackedScene",
		use_sub_threads,
		STREAM_CACHE_MODE
	)
	if error != OK:
		load_failed.emit(path)
		return error
	_requests[path] = 0.0
	load_requested.emit(path)
	set_process(true)
	return OK


func activate_level(path: String) -> bool:
	if not _instances.has(path):
		return false
	var previous_path := _current_path
	if not previous_path.is_empty() and _instances.has(previous_path):
		_set_level_active(_instances[previous_path], false)
	_current_path = path
	_set_level_active(_instances[path], true)
	_touch(path)
	level_activated.emit(path, previous_path)
	_evict_over_budget()
	return true


func deactivate_current() -> bool:
	if _current_path.is_empty() or not _instances.has(_current_path):
		return false
	_set_level_active(_instances[_current_path], false)
	_current_path = ""
	return true


func unload_level(path: String) -> bool:
	if path == _current_path or not _instances.has(path):
		return false
	var instance: Node = _instances[path]
	_set_level_active(instance, false)
	_instances.erase(path)
	_last_used.erase(path)
	_release_instance_resources(instance)
	instance.queue_free()
	level_unloaded.emit(path)
	return true


func clear_inactive_levels() -> int:
	var paths := _instances.keys()
	var removed := 0
	for path in paths:
		if path != _current_path and unload_level(path):
			removed += 1
	return removed


func is_level_ready(path: String) -> bool:
	return _instances.has(path)


func get_level(path: String) -> Node:
	return _instances.get(path)


func get_load_progress(path: String) -> float:
	if _instances.has(path):
		return 1.0
	return float(_requests.get(path, 0.0))


func get_resident_paths() -> PackedStringArray:
	var paths := PackedStringArray()
	for path in _instances:
		paths.append(path)
	return paths


func get_stream_cache_mode() -> int:
	return STREAM_CACHE_MODE


func _process(_delta: float) -> void:
	for path in _requests.keys():
		var progress: Array = []
		var status := ResourceLoader.load_threaded_get_status(path, progress)
		var ratio := float(progress[0]) if not progress.is_empty() else 0.0
		_requests[path] = ratio
		load_progress.emit(path, ratio)
		match status:
			ResourceLoader.THREAD_LOAD_LOADED:
				_finish_load(path)
			ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				_requests.erase(path)
				load_failed.emit(path)
	if _requests.is_empty():
		set_process(false)


func _finish_load(path: String) -> void:
	var packed_scene := ResourceLoader.load_threaded_get(path) as PackedScene
	_requests.erase(path)
	if packed_scene == null:
		load_failed.emit(path)
		return
	var instance := packed_scene.instantiate()
	_instances[path] = instance
	_touch(path)
	_host.add_child(instance)
	_set_level_active(instance, false)
	level_loaded.emit(path, instance)
	_evict_over_budget()


func _set_level_active(instance: Node, active: bool) -> void:
	instance.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	if instance is Node3D:
		var keep_visual_when_inactive := bool(
			instance.get_meta("stream_keep_visual_when_inactive", false)
		)
		(instance as Node3D).visible = active or keep_visual_when_inactive
	elif instance is CanvasItem:
		(instance as CanvasItem).visible = active
	for child in instance.find_children("*", "CollisionObject3D", true, false):
		var collision_object := child as CollisionObject3D
		if not collision_object.has_meta("stream_collision_layer"):
			collision_object.set_meta("stream_collision_layer", collision_object.collision_layer)
			collision_object.set_meta("stream_collision_mask", collision_object.collision_mask)
		collision_object.collision_layer = (
			int(collision_object.get_meta("stream_collision_layer")) if active else 0
		)
		collision_object.collision_mask = (
			int(collision_object.get_meta("stream_collision_mask")) if active else 0
		)


func _touch(path: String) -> void:
	_clock += 1
	_last_used[path] = _clock


func _evict_over_budget() -> void:
	while _instances.size() > max_resident_levels:
		var candidate := ""
		var oldest := 0x7FFFFFFF
		for path in _instances:
			if path == _current_path:
				continue
			var last_used := int(_last_used.get(path, 0))
			if last_used < oldest:
				oldest = last_used
				candidate = path
		if candidate.is_empty() or not unload_level(candidate):
			return
