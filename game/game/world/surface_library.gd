class_name SurfaceLibrary
extends Node

const LAKE_CENTER := Vector2(-8.0, -8.0)
const LAKE_RADII := Vector2(7.5, 5.0)

var _profiles: Dictionary = {}

const MATERIAL_ROOTS := {
	&"dry_soil": "res://content/materials/scanned/forest_ground/",
	&"wet_mud": "res://content/materials/scanned/mud_forest/",
	&"moss": "res://content/materials/scanned/forest_leaves/",
	&"wood": "res://content/materials/scanned/pine_bark/",
	&"stone": "res://content/materials/scanned/lake_stone/",
}
const FALLBACK_ROOTS := {
	&"dry_soil": "res://content/environments/ground/",
	&"wet_mud": "res://content/materials/forest_path/",
	&"moss": "res://content/materials/foliage/",
	&"wood": "res://content/materials/bark/",
	&"stone": "res://content/materials/lake_stone/",
}


func _ready() -> void:
	_register_defaults()


func _exit_tree() -> void:
	# Profiles own imported texture references and generated physics materials.
	# Drop the references before Jolt tears down the parent scene so a streamed
	# test scene cannot retain a Resource through the surface registry.
	_profiles.clear()


func _register_defaults() -> void:
	_register_profile(&"dry_soil", 0.78, 0.04, 0.86, 0.42, 1.0, &"soil", &"none")
	_register_profile(&"wet_mud", 0.48, 0.02, 0.68, 0.98, 0.78, &"mud", &"mud")
	_register_profile(&"moss", 0.64, 0.01, 0.91, 0.82, 0.92, &"moss", &"soft")
	_register_profile(&"stone", 0.92, 0.08, 0.72, 0.28, 0.94, &"stone", &"stone")
	_register_profile(&"wood", 0.66, 0.05, 0.78, 0.52, 0.98, &"wood", &"none")
	_register_profile(&"water", 0.12, 0.0, 0.18, 1.0, 0.64, &"water", &"water")


func _register_profile(
	type: StringName,
	friction: float,
	bounce: float,
	roughness: float,
	wetness_response: float,
	speed_multiplier: float,
	footstep_tag: StringName,
	ripple_tag: StringName,
) -> void:
	var profile := SurfaceProfile.new()
	profile.surface_type = type
	profile.friction = friction
	profile.bounce = bounce
	profile.roughness = roughness
	profile.wetness_response = wetness_response
	profile.speed_multiplier = speed_multiplier
	profile.footstep_tag = footstep_tag
	profile.ripple_tag = ripple_tag
	profile.material_id = type
	_load_material_maps(profile, MATERIAL_ROOTS.get(type, ""))
	_profiles[type] = profile


func _load_material_maps(profile: SurfaceProfile, root: String) -> void:
	if root.is_empty():
		return
	profile.albedo_texture = _load_texture(root, "albedo")
	profile.normal_texture = _load_texture(root, "normal")
	profile.roughness_texture = _load_texture(root, "roughness")
	profile.ao_texture = _load_texture(root, "ao")
	profile.cavity_texture = _load_texture(root, "cavity")
	profile.height_texture = _load_texture(root, "height")
	if profile.cavity_texture == null:
		var fallback_root: String = FALLBACK_ROOTS.get(profile.surface_type, "")
		profile.cavity_texture = _load_texture(fallback_root, "cavity")
	if profile.height_texture == null:
		var fallback_root: String = FALLBACK_ROOTS.get(profile.surface_type, "")
		profile.height_texture = _load_texture(fallback_root, "height")


func _load_texture(root: String, stem: String) -> Texture2D:
	for extension in ["png", "jpg", "jpeg", "exr"]:
		var path: String = root + stem + "." + extension
		if FileAccess.file_exists(ProjectSettings.globalize_path(path)):
			var texture := load(path) as Texture2D
			if texture != null:
				return texture
	return null


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
