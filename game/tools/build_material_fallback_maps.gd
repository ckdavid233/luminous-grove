extends SceneTree

## Creates neutral placeholders for maps that are not present in the legacy local
## asset pack. They are intentionally flat and are replaced by scanned AO/Cavity/
## Height maps when the external material package is installed.
const TARGETS := [
	"res://content/materials/foliage/",
	"res://content/materials/bark/",
	"res://content/materials/lake_stone/",
	"res://content/materials/forest_path/",
	"res://content/materials/shrine_stone/",
	"res://content/environments/ground/",
]
const SIZE := 512


func _initialize() -> void:
	for target in TARGETS:
		_save_map(target + "ao.png", Color(0.96, 0.96, 0.96))
		_save_map(target + "cavity.png", Color(0.92, 0.92, 0.92))
		_save_map(target + "height.png", Color(0.5, 0.5, 0.5))
	print("MATERIAL_FALLBACK_MAPS_OK targets=", TARGETS.size(), " size=", SIZE)
	quit()


func _save_map(path: String, color: Color) -> void:
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_L8)
	image.fill(color)
	assert(image.save_png(ProjectSettings.globalize_path(path)) == OK, path)
