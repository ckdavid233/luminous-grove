extends SceneTree

const SOURCE_ROOT := "res://content/source_art/user_pack/game_art/"
const OUTPUT_ROOT := "res://content/materials/"
const SIZE := 2048
const MATERIALS := [
	{
		"name": "foliage",
		"source": "foliage_canopy_albedo.png",
		"normal_strength": 2.4,
		"roughness_min": 0.68,
		"roughness_max": 0.9,
	},
	{
		"name": "bark",
		"source": "mossy_bark_albedo.png",
		"normal_strength": 4.2,
		"roughness_min": 0.74,
		"roughness_max": 0.96,
	},
	{
		"name": "lake_stone",
		"source": "mossy_lake_stone_albedo.png",
		"normal_strength": 3.5,
		"roughness_min": 0.62,
		"roughness_max": 0.92,
	},
	{
		"name": "forest_path",
		"source": "forest_path_albedo.png",
		"normal_strength": 2.8,
		"roughness_min": 0.78,
		"roughness_max": 0.98,
	},
	{
		"name": "shrine_stone",
		"source": "ancient_shrine_stone_albedo.png",
		"normal_strength": 3.0,
		"roughness_min": 0.68,
		"roughness_max": 0.94,
	},
]


func _initialize() -> void:
	for definition in MATERIALS:
		_build_material(definition)
	print("USER_PBR_BUILD_OK materials=", MATERIALS.size(), " size=", Vector2i(SIZE, SIZE))
	quit()


func _build_material(definition: Dictionary) -> void:
	var source := Image.load_from_file(SOURCE_ROOT + definition.source)
	assert(not source.is_empty(), definition.source + " must load")
	source.resize(SIZE / 2, SIZE / 2, Image.INTERPOLATE_LANCZOS)
	source.convert(Image.FORMAT_RGB8)
	var albedo := _make_mirrored_tile(source)
	var normal := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	var roughness := Image.create(SIZE, SIZE, false, Image.FORMAT_L8)
	var strength := float(definition.normal_strength)
	var roughness_min := float(definition.roughness_min)
	var roughness_max := float(definition.roughness_max)

	for y in SIZE:
		for x in SIZE:
			var left := _height(albedo, x - 1, y)
			var right := _height(albedo, x + 1, y)
			var up := _height(albedo, x, y - 1)
			var down := _height(albedo, x, y + 1)
			var surface_normal := Vector3(
				(left - right) * strength,
				(up - down) * strength,
				1.0
			).normalized()
			normal.set_pixel(
				x,
				y,
				Color(
					surface_normal.x * 0.5 + 0.5,
					surface_normal.y * 0.5 + 0.5,
					surface_normal.z * 0.5 + 0.5
				)
			)
			var value := _height(albedo, x, y)
			var surface_roughness := lerpf(roughness_max, roughness_min, value)
			roughness.set_pixel(x, y, Color(surface_roughness, 0.0, 0.0))

	var directory: String = OUTPUT_ROOT + str(definition.name)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	assert(albedo.save_png(directory + "/albedo.png") == OK)
	assert(normal.save_png(directory + "/normal.png") == OK)
	assert(roughness.save_png(directory + "/roughness.png") == OK)
	print("PBR_MATERIAL_OK name=", definition.name)


func _make_mirrored_tile(source: Image) -> Image:
	var output := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	var half := SIZE / 2
	for y in SIZE:
		var source_y := y if y < half else SIZE - 1 - y
		for x in SIZE:
			var source_x := x if x < half else SIZE - 1 - x
			output.set_pixel(x, y, source.get_pixel(source_x, source_y))
	return output


func _height(image: Image, x: int, y: int) -> float:
	var color := image.get_pixel(posmod(x, SIZE), posmod(y, SIZE))
	return color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
