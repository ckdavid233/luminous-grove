class_name MaterialProfile
extends Resource

## Runtime material contract shared by visual shaders and surface physics.
##
## The source package may live outside Git, but every profile must point at the
## imported runtime maps used by the game. Cavity and Height are optional for
## broad/midground materials and required for hero close-ups.
@export var material_id: StringName = &""
@export var surface_type: StringName = &"dry_soil"
@export var albedo_texture: Texture2D
@export var normal_texture: Texture2D
@export var roughness_texture: Texture2D
@export var ao_texture: Texture2D
@export var cavity_texture: Texture2D
@export var height_texture: Texture2D
@export var friction := 0.78
@export var bounce := 0.04
@export var roughness := 0.86
@export var wetness_response := 0.72
@export var speed_multiplier := 1.0
@export var footstep_tag: StringName = &"soil"
@export var ripple_tag: StringName = &"none"


func has_required_maps(include_hero_maps := false) -> bool:
	var core_maps_ready := (
		albedo_texture != null
		and normal_texture != null
		and roughness_texture != null
		and ao_texture != null
	)
	if not core_maps_ready:
		return false
	return not include_hero_maps or (cavity_texture != null and height_texture != null)


func create_physics_material() -> PhysicsMaterial:
	var material := PhysicsMaterial.new()
	material.friction = friction
	material.bounce = bounce
	material.rough = roughness
	material.absorbent = surface_type in [&"wet_mud", &"moss"]
	return material
