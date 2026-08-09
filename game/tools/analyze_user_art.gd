extends SceneTree

const ROOT := "res://content/source_art/user_pack/game_art/"
const FILES := [
	"foliage_canopy_albedo.png",
	"mossy_bark_albedo.png",
	"mossy_lake_stone_albedo.png",
	"forest_path_albedo.png",
	"ancient_shrine_stone_albedo.png",
	"forest_plants_atlas.png",
	"leaf_petals_atlas.png",
]


func _initialize() -> void:
	for file_name in FILES:
		var image := Image.load_from_file(ROOT + file_name)
		assert(not image.is_empty(), file_name + " must load")
		var alpha_min := 1.0
		var alpha_max := 0.0
		var alpha_partial := 0
		var sample_step := maxi(image.get_width() / 256, 1)
		for y in range(0, image.get_height(), sample_step):
			for x in range(0, image.get_width(), sample_step):
				var alpha := image.get_pixel(x, y).a
				alpha_min = minf(alpha_min, alpha)
				alpha_max = maxf(alpha_max, alpha)
				if alpha > 0.001 and alpha < 0.999:
					alpha_partial += 1
		var edge_error := _edge_error(image)
		print(
			"ART_ANALYSIS file=", file_name,
			" size=", image.get_size(),
			" format=", image.get_format(),
			" alpha_min=", snappedf(alpha_min, 0.001),
			" alpha_max=", snappedf(alpha_max, 0.001),
			" alpha_partial_samples=", alpha_partial,
			" edge_error=", snappedf(edge_error, 0.0001)
		)
	quit()


func _edge_error(image: Image) -> float:
	var samples := mini(image.get_width(), image.get_height())
	var difference := 0.0
	for index in samples:
		var x := int(float(index) / float(samples - 1) * float(image.get_width() - 1))
		var y := int(float(index) / float(samples - 1) * float(image.get_height() - 1))
		var horizontal := image.get_pixel(0, y) - image.get_pixel(image.get_width() - 1, y)
		var vertical := image.get_pixel(x, 0) - image.get_pixel(x, image.get_height() - 1)
		difference += (
			absf(horizontal.r) + absf(horizontal.g) + absf(horizontal.b)
			+ absf(vertical.r) + absf(vertical.g) + absf(vertical.b)
		) / 6.0
	return difference / samples
