class_name SurfaceProbe
extends Node3D

signal surface_changed(sample: Dictionary)

var _library
var _last_type: StringName = &""


func configure(library) -> void:
	_library = library


func sample(world_position: Vector3, normal := Vector3.UP) -> Dictionary:
	var result: Dictionary
	if _library != null and _library.has_method("sample"):
		result = _library.sample(world_position, normal)
	else:
		result = {
			"type": &"dry_soil",
			"normal": normal,
			"wetness": 0.0,
			"speed_multiplier": 1.0,
		}
	var next_type: StringName = result.get("type", &"dry_soil")
	if next_type != _last_type:
		_last_type = next_type
		surface_changed.emit(result)
	return result


func raycast_sample(body: CharacterBody3D, height := 0.72, depth := 1.42) -> Dictionary:
	if body == null or body.get_world_3d() == null:
		return sample(global_position)
	var origin := body.global_position + Vector3.UP * height
	var query := PhysicsRayQueryParameters3D.create(
		origin,
		origin + Vector3.DOWN * depth,
	)
	query.exclude = [body.get_rid()]
	query.collision_mask = 1
	var hit := body.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return sample(body.global_position)
	var collider := hit.get("collider") as Node
	if (
		collider != null
		and collider.has_meta("surface_type")
		and _library != null
		and _library.has_method("get_profile")
	):
		var profile: SurfaceProfile = _library.get_profile(collider.get_meta("surface_type"))
		var tagged_sample := profile.to_sample(hit.normal, 0.72)
		if tagged_sample.get("type", &"") != _last_type:
			_last_type = tagged_sample.get("type", &"")
			surface_changed.emit(tagged_sample)
		return tagged_sample
	return sample(hit.position, hit.normal)
