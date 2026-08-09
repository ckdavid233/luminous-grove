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


func _ready() -> void:
	_host = get_parent()


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
