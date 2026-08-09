extends SceneTree

const PBR_FOLDERS := [
	"foliage",
	"bark",
	"lake_stone",
	"forest_path",
	"shrine_stone",
]


func _initialize() -> void:
	DirAccess.remove_absolute(
		ProjectSettings.globalize_path("user://save_slot_1.json")
	)
	for folder in PBR_FOLDERS:
		for texture_name in ["albedo", "normal", "roughness"]:
			var path := "res://content/materials/%s/%s.png" % [folder, texture_name]
			var texture := load(path) as Texture2D
			assert(texture != null, path + " must load")
			assert(texture.get_size() == Vector2(2048, 2048), path + " must be 2048 square")
		for texture_name in ["ao", "cavity", "height"]:
			var detail_path := "res://content/materials/%s/%s.png" % [folder, texture_name]
			var detail_texture := load(detail_path) as Texture2D
			assert(detail_texture != null, detail_path + " must load")
			assert(detail_texture.get_size() == Vector2(512, 512), detail_path + " must be 512 square")

	for atlas_path in [
		"res://content/vfx/forest_plants_atlas.png",
		"res://content/vfx/leaf_petals_atlas.png",
	]:
		var atlas_texture := load(atlas_path) as Texture2D
		assert(atlas_texture != null)
		var atlas_image := atlas_texture.get_image()
		assert(atlas_image.detect_alpha() != Image.ALPHA_NONE, atlas_path + " must contain alpha")

	var tone_script := preload("res://core/audio/procedural_tone.gd")
	var tone: AudioStreamWAV = tone_script.create_chime(
		PackedFloat32Array([440.0, 660.0]),
		0.15
	)
	assert(tone.data.size() > 6000, "Procedural tone must contain PCM samples")

	var main_scene := load("res://game/main/main.tscn") as PackedScene
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	var ending_overlay := main.get("_ending_overlay") as ColorRect
	var ending_label := main.get("_ending_label") as Label
	assert(ending_overlay != null and not ending_overlay.visible)
	assert(ending_label != null and ending_label.text.contains("微光重新流淌"))
	main.call("_show_ending")
	assert(ending_overlay.visible, "Ending presentation must become visible")

	print("PRESENTATION_TEST_OK pbr_sets=", PBR_FOLDERS.size(), " atlases=2 audio_bytes=", tone.data.size())
	var streamer = main.get("_world_streamer")
	for _frame in 600:
		if streamer.is_level_ready(
			"res://content/levels/echo_ruins/echo_ruins.tscn"
		):
			break
		await process_frame
	streamer.clear_inactive_levels()
	if streamer.has_method("shutdown"):
		streamer.shutdown()
	main.queue_free()
	for _frame in 30:
		await process_frame
		await physics_frame
	call_deferred("quit")
