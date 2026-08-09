class_name SurfaceLibrary
extends Node

const LAKE_CENTER := Vector2(-8.0, -8.0)
const LAKE_RADII := Vector2(7.5, 5.0)

var _profiles: Dictionary = {}

const PROFILE_PATHS := {
	&"dry_soil": "res://content/materials/profiles/dry_soil.tres",
	&"wet_mud": "res://content/materials/profiles/wet_mud.tres",
	&"moss": "res://content/materials/profiles/moss.tres",
	&"wood": "res://content/materials/profiles/wood.tres",
	&"stone": "res://content/materials/profiles/stone.tres",
	&"water": "res://content/materials/profiles/water.tres",
}


func _ready() -> void:
	_register_defaults()


func _exit_tree() -> void:
	# Profiles own imported texture references and generated physics materials.
	# Drop the references before Jolt tears down the parent scene so a streamed
	# test scene cannot retain a Resource through the surface registry.
	for profile in _profiles.values():
		if profile != null and profile.has_method("release_runtime_resources"):
			profile.release_runtime_resources()
	_profiles.clear()


func _register_defaults() -> void:
	# Keep material/physics data in inspectable resources rather than hiding the
	# mapping in code. A missing profile is a packaging error, not a reason to
	# silently run with a different material contract.
	for surface_type in PROFILE_PATHS:
		var path: String = PROFILE_PATHS[surface_type]
		assert(ResourceLoader.exists(path, "Resource"), "Missing MaterialProfile: " + path)
		var profile := load(path) as SurfaceProfile
		assert(profile != null, "Invalid MaterialProfile resource: " + path)
		assert(profile.surface_type == surface_type, "Surface type mismatch: " + path)
		_profiles[surface_type] = profile


func get_profile(type: StringName) -> SurfaceProfile:
	if _profiles.is_empty():
		_register_defaults()
	return _profiles.get(type, _profiles[&"dry_soil"]) as SurfaceProfile


func get_physics_material(type: StringName) -> PhysicsMaterial:
	return get_profile(type).create_physics_material()


func sample(world_position: Vector3, normal := Vector3.UP) -> Dictionary:
	var offset := Vector2(world_position.x, world_position.z) - LAKE_CENTER
	var lake_distance := Vector2(
		offset.x / LAKE_RADII.x,
		offset.y / LAKE_RADII.y,
	).length()
	if lake_distance <= 1.0 and world_position.y <= 0.24:
		return get_profile(&"water").to_sample(normal, 1.0)
	if lake_distance <= 1.16:
		return get_profile(&"wet_mud").to_sample(normal, 0.78)
	if normal.y < 0.76:
		return get_profile(&"stone").to_sample(normal, 0.35)
	var moss_noise := sin(world_position.x * 0.29 + world_position.z * 0.17)
	if moss_noise > 0.63:
		return get_profile(&"moss").to_sample(normal, 0.48)
	return get_profile(&"dry_soil").to_sample(normal, 0.18)
