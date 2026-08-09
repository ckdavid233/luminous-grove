extends SceneTree

const SURFACE_LIBRARY := preload("res://game/world/surface_library.gd")
const FOLDERS := ["foliage", "bark", "lake_stone", "forest_path", "shrine_stone"]
const MAPS := ["albedo", "normal", "roughness", "ao", "cavity", "height"]
const PROFILE_PATHS := {
	&"dry_soil": "res://content/materials/profiles/dry_soil.tres",
	&"wet_mud": "res://content/materials/profiles/wet_mud.tres",
	&"moss": "res://content/materials/profiles/moss.tres",
	&"wood": "res://content/materials/profiles/wood.tres",
	&"stone": "res://content/materials/profiles/stone.tres",
	&"water": "res://content/materials/profiles/water.tres",
}


func _initialize() -> void:
	var manifest_text := FileAccess.get_file_as_string(
		ProjectSettings.globalize_path("res://content/materials/material_library.json")
	)
	var manifest = JSON.parse_string(manifest_text)
	assert(manifest is Dictionary and int(manifest.get("schema", 0)) == 2)
	assert(manifest.get("normal_convention", "") == "opengl")
	for folder in FOLDERS:
		for map_name in MAPS:
			var path := "res://content/materials/%s/%s.png" % [folder, map_name]
			var texture := load(path) as Texture2D
			assert(texture != null, path + " must load")
			assert(texture.get_width() > 0 and texture.get_height() > 0)
	for ground_map in ["forest_ground_albedo.png", "forest_ground_normal.png", "forest_ground_roughness.png", "ao.png", "cavity.png", "height.png"]:
		var ground_path: String = "res://content/environments/ground/" + ground_map
		assert(load(ground_path) is Texture2D, ground_path + " must load")
	for scanned_folder in ["forest_ground", "mud_forest", "forest_leaves", "pine_bark", "lake_stone"]:
		for scanned_map in ["albedo", "normal", "roughness", "ao", "height"]:
			var scanned_path: String = (
				"res://content/materials/scanned/%s/%s.jpg" % [scanned_folder, scanned_map]
			)
			var scanned_texture := load(scanned_path) as Texture2D
			assert(scanned_texture != null, scanned_path + " must load")
			assert(
				scanned_texture.get_width() == 4096 and scanned_texture.get_height() == 4096,
				scanned_path + " must be 4K runtime",
			)

	var library := SURFACE_LIBRARY.new()
	root.add_child(library)
	await process_frame
	for surface_type in PROFILE_PATHS:
		var profile_path: String = PROFILE_PATHS[surface_type]
		assert(ResourceLoader.exists(profile_path, "Resource"), profile_path)
		var resource_profile := load(profile_path) as MaterialProfile
		assert(resource_profile != null, profile_path + " must be a MaterialProfile")
		assert(resource_profile.material_id == surface_type)
		assert(resource_profile.surface_type == surface_type)
	var dry := library.sample(Vector3(0.0, 0.0, 0.0))
	var mud := library.sample(Vector3(-8.0, 0.1, -2.4))
	var stone := library.sample(Vector3(-17.2, 0.1, -8.0), Vector3(0.1, 0.7, 0.0))
	assert(dry.type == &"dry_soil")
	assert(mud.type == &"wet_mud")
	assert(stone.type == &"stone")
	assert(library.get_physics_material(&"wet_mud").friction < library.get_physics_material(&"dry_soil").friction)
	for surface_type in [&"dry_soil", &"wet_mud", &"moss", &"wood", &"stone"]:
		var profile := library.get_profile(surface_type) as MaterialProfile
		assert(profile != null)
		assert(profile.resource_path == PROFILE_PATHS[surface_type])
		assert(profile.has_required_maps(), str(surface_type) + " core maps must be wired")
		assert(profile.cavity_texture != null and profile.height_texture != null)
	var water_profile := library.get_profile(&"water") as MaterialProfile
	assert(water_profile.resource_path == PROFILE_PATHS[&"water"])
	assert(water_profile.ripple_tag == &"water")
	print("MATERIAL_LIBRARY_TEST_OK maps=6 surfaces=dry_soil,wet_mud,stone normal=opengl")
	library.queue_free()
	await process_frame
	call_deferred("quit")
