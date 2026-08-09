extends SceneTree

const SOURCE := "res://content/environments/ground/forest_ground_source.png"
const ALBEDO := "res://content/environments/ground/forest_ground_albedo.png"
const NORMAL := "res://content/environments/ground/forest_ground_normal.png"
const ROUGHNESS := "res://content/environments/ground/forest_ground_roughness.png"
const SIZE := 2048


func _initialize() -> void:
	var source := Image.load_from_file(SOURCE)
	assert(not source.is_empty(), "Ground source texture must load")
	source.resize(SIZE / 2, SIZE / 2, Image.INTERPOLATE_LANCZOS)
	source.convert(Image.FORMAT_RGB8)
	source = _make_mirrored_tile(source)
	var edge_error := _edge_error(source)
	assert(source.save_png(ALBEDO) == OK)

	var normal := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	var roughness := Image.create(SIZE, SIZE, false, Image.FORMAT_L8)
	for y in SIZE:
		for x in SIZE:
			var left := _height(source, x - 1, y)
			var right := _height(source, x + 1, y)
			var up := _height(source, x, y - 1)
			var down := _height(source, x, y + 1)
			var surface_normal := Vector3(
				(left - right) * 2.8,
				(up - down) * 2.8,
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
			var value := _height(source, x, y)
			roughness.set_pixel(x, y, Color(clampf(0.9 - value * 0.2, 0.68, 0.92), 0.0, 0.0))

	assert(normal.save_png(NORMAL) == OK)
	assert(roughness.save_png(ROUGHNESS) == OK)
	print(
		"GROUND_PBR_OK size=", source.get_size(),
		" edge_mean_error=", snappedf(edge_error, 0.0001)
	)
	quit()


func _height(image: Image, x: int, y: int) -> float:
	var wrapped_x := posmod(x, SIZE)
	var wrapped_y := posmod(y, SIZE)
	var color := image.get_pixel(wrapped_x, wrapped_y)
	return color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722


func _make_mirrored_tile(source: Image) -> Image:
	var output := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	var half := SIZE / 2
	for y in SIZE:
		var source_y := y if y < half else SIZE - 1 - y
		for x in SIZE:
			var source_x := x if x < half else SIZE - 1 - x
			output.set_pixel(x, y, source.get_pixel(source_x, source_y))
	return output


func _edge_error(image: Image) -> float:
	var difference := 0.0
	for index in SIZE:
		var horizontal := image.get_pixel(0, index) - image.get_pixel(SIZE - 1, index)
		var vertical := image.get_pixel(index, 0) - image.get_pixel(index, SIZE - 1)
		difference += (
			absf(horizontal.r) + absf(horizontal.g) + absf(horizontal.b)
			+ absf(vertical.r) + absf(vertical.g) + absf(vertical.b)
		) / 6.0
	return difference / SIZE
