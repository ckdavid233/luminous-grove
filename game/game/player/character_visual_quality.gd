class_name CharacterVisualQuality
extends RefCounted


static func apply_to(character_root: Node) -> Dictionary:
	var result := {
		"materials": 0,
		"skin": 0,
		"eyes": 0,
		"hair": 0,
		"teeth": 0,
	}
	for node in character_root.find_children(
		"*",
		"MeshInstance3D",
		true,
		false,
	):
		var mesh_instance := node as MeshInstance3D
		mesh_instance.cast_shadow = (
			GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		)
		for surface_index in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.get_active_material(
				surface_index
			) as StandardMaterial3D
			if source == null:
				continue
			var material := source.duplicate(true) as StandardMaterial3D
			material.resource_local_to_scene = true
			material.resource_name = source.resource_name + "_RuntimeHQ"
			material.texture_filter = (
				BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			)
			var identity := (
				str(mesh_instance.name) + " " + source.resource_name
			).to_lower()
			if "human.body" in identity or "ji_body_source" in identity:
				_configure_skin(material)
				result.skin += 1
			elif "high-poly" in identity:
				_configure_eyes(material)
				result.eyes += 1
			elif "long01" in identity or "hair" in identity:
				_configure_hair(
					material,
					_mesh_has_tangents(mesh_instance.mesh, surface_index),
				)
				result.hair += 1
			elif "teeth" in identity:
				_configure_teeth(material)
				result.teeth += 1
			elif "tongue" in identity:
				_configure_tongue(material)
			_apply_imported_normal_map(material, identity)
			mesh_instance.set_surface_override_material(
				surface_index,
				material,
			)
			result.materials += 1
	return result


static func apply_profile(character_root: Node, profile: StringName) -> void:
	var reduced := profile == &"performance"
	for node in character_root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		for surface_index in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.get_surface_override_material(
				surface_index
			) as StandardMaterial3D
			if material == null:
				continue
			var identity := (
				str(mesh_instance.name) + " " + material.resource_name
			).to_lower()
			if "human.body" in identity or "ji_body_source" in identity:
				material.subsurf_scatter_enabled = not reduced
				material.subsurf_scatter_transmittance_enabled = not reduced
			elif "high-poly" in identity:
				material.clearcoat_enabled = not reduced
			elif "long01" in identity or "hair" in identity:
				material.anisotropy_enabled = (
					not reduced
					and _mesh_has_tangents(mesh_instance.mesh, surface_index)
				)


static func _configure_skin(material: StandardMaterial3D) -> void:
	material.subsurf_scatter_enabled = true
	material.subsurf_scatter_skin_mode = true
	material.subsurf_scatter_strength = 0.12
	material.subsurf_scatter_transmittance_enabled = true
	material.subsurf_scatter_transmittance_depth = 0.1
	material.subsurf_scatter_transmittance_boost = 0.08
	material.metallic_specular = 0.28
	material.roughness = clampf(material.roughness, 0.5, 0.7)


static func _configure_eyes(material: StandardMaterial3D) -> void:
	material.clearcoat_enabled = true
	material.clearcoat = 0.62
	material.clearcoat_roughness = 0.1
	material.metallic_specular = 0.42
	material.roughness = 0.2


static func _configure_hair(
	material: StandardMaterial3D,
	has_tangents: bool,
) -> void:
	material.anisotropy_enabled = has_tangents
	material.anisotropy = 0.28 if has_tangents else 0.0
	material.metallic_specular = 0.34
	material.roughness = clampf(material.roughness, 0.36, 0.52)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED


static func _configure_teeth(material: StandardMaterial3D) -> void:
	material.clearcoat_enabled = true
	material.clearcoat = 0.28
	material.clearcoat_roughness = 0.18
	material.metallic_specular = 0.48
	material.roughness = 0.3


static func _configure_tongue(material: StandardMaterial3D) -> void:
	material.subsurf_scatter_enabled = true
	material.subsurf_scatter_strength = 0.08
	material.roughness = 0.44


static func _apply_imported_normal_map(
	material: StandardMaterial3D,
	identity: String,
) -> void:
	# The generated character already ships with authored suit/shoe normal
	# maps.  Imported GLB materials do not always preserve those links, so
	# restore them on the runtime HQ copies instead of inventing detail from
	# albedo luminance.  Skin intentionally keeps its subtle SSS-only surface.
	var normal_path := ""
	if "casualsuit" in identity or "clothes" in identity:
		normal_path = "res://content/characters/realistic_player/ji_realistic_female_casualsuit01_normal.png"
	elif "shoes" in identity:
		normal_path = "res://content/characters/realistic_player/ji_realistic_shoes01_normal.png"
	if normal_path.is_empty():
		return
	var texture := load(normal_path) as Texture2D
	if texture == null:
		return
	material.normal_enabled = true
	material.normal_texture = texture
	material.normal_scale = 0.88


static func _mesh_has_tangents(mesh: Mesh, surface_index: int) -> bool:
	return (
		mesh.surface_get_format(surface_index) & Mesh.ARRAY_FORMAT_TANGENT
	) != 0
