extends SceneTree

## PBR importer/validator.
##
## This tool deliberately never derives Normal or Roughness from Albedo. A material
## is accepted only when the source pack provides the maps; local runtime maps are
## reported as an explicit fallback until the scanned pack is installed.
const OUTPUT_ROOT := "res://content/materials/"
const SOURCE_ROOT := "res://content/source_art/user_pack/game_art/"
const MATERIALS := [
	{"name": "foliage", "source": "foliage_canopy_albedo.png"},
	{"name": "bark", "source": "mossy_bark_albedo.png"},
	{"name": "lake_stone", "source": "mossy_lake_stone_albedo.png"},
	{"name": "forest_path", "source": "forest_path_albedo.png"},
	{"name": "shrine_stone", "source": "ancient_shrine_stone_albedo.png"},
]
const MAP_NAMES := ["albedo", "normal", "roughness", "ao", "cavity", "height"]


func _initialize() -> void:
	var verified := 0
	var fallback := 0
	for definition in MATERIALS:
		var result := _validate_material(definition)
		if result:
			verified += 1
		else:
			fallback += 1
	print(
		"PBR_LIBRARY_VALIDATE_OK materials=",
		MATERIALS.size(),
		" verified=",
		verified,
		" fallback=",
		fallback,
		" normal_convention=opengl",
	)
	quit()


func _validate_material(definition: Dictionary) -> bool:
	var name := str(definition.name)
	var source_path := SOURCE_ROOT + str(definition.source)
	assert(FileAccess.file_exists(ProjectSettings.globalize_path(source_path)), source_path)
	var complete := true
	for map_name in MAP_NAMES:
		var source_map := _find_source_map(name, map_name)
		if source_map.is_empty():
			complete = false
			continue
		var image := Image.load_from_file(ProjectSettings.globalize_path(source_map))
		assert(not image.is_empty(), source_map + " must load")
		assert(image.get_width() == image.get_height(), source_map + " must be square")
	if complete:
		print("PBR_LIBRARY_VERIFIED name=", name)
	else:
		for map_name in ["albedo", "normal", "roughness"]:
			var runtime_path: String = OUTPUT_ROOT + name + "/" + map_name + ".png"
			assert(
				FileAccess.file_exists(ProjectSettings.globalize_path(runtime_path)),
				runtime_path + " fallback must exist",
			)
		print("PBR_LIBRARY_FALLBACK name=", name, " source=", source_path)
	return complete


func _find_source_map(material_name: String, map_name: String) -> String:
	var candidates := [
		SOURCE_ROOT + material_name + "_" + map_name + ".png",
		SOURCE_ROOT + material_name + "_" + map_name + ".jpg",
		SOURCE_ROOT + material_name + "_" + map_name + ".exr",
	]
	for candidate in candidates:
		if FileAccess.file_exists(ProjectSettings.globalize_path(candidate)):
			return candidate
	return ""
