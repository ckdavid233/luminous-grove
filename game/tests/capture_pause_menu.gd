extends SceneTree

const OUTPUT_PATH := "/home/cenkai/game_dev_plan/previews/pause_menu.png"


func _initialize() -> void:
	DirAccess.remove_absolute(
		ProjectSettings.globalize_path("user://save_slot_1.json")
	)
	root.size = Vector2i(1280, 720)
	var main_scene := load("res://game/main/main.tscn") as PackedScene
	var main := main_scene.instantiate()
	root.add_child(main)
	for _frame in 90:
		await process_frame
	main.call("_set_paused", true)
	for _frame in 3:
		await process_frame
	var image := root.get_texture().get_image()
	var error := image.save_png(OUTPUT_PATH)
	assert(error == OK, "Pause menu screenshot must save")
	main.call("_set_paused", false)
	print("PAUSE_MENU_CAPTURE_OK output=", OUTPUT_PATH, " size=", image.get_size())
	quit()
