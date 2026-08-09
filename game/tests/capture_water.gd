extends SceneTree

const OUTPUT_PATH := "/home/cenkai/game_dev_plan/previews/realistic_lake.png"
const SPLASH_OUTPUT_PATH := "/home/cenkai/game_dev_plan/previews/realistic_lake_splash.png"


func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	var main_scene := load("res://game/main/main.tscn") as PackedScene
	var main := main_scene.instantiate()
	root.add_child(main)

	for _frame in 12:
		await process_frame

	var camera := Camera3D.new()
	camera.fov = 58.0
	camera.cull_mask = 5
	camera.position = Vector3(-8.0, 3.25, -1.4)
	main.add_child(camera)
	camera.look_at(Vector3(-8.0, 0.0, -8.0))
	camera.make_current()
	main.get_node("Forest").visible = false
	for canvas in main.find_children("*", "CanvasLayer", true, false):
		(canvas as CanvasLayer).visible = false

	for _frame in 120:
		await process_frame
	var image := root.get_texture().get_image()
	var error := image.save_png(OUTPUT_PATH)
	assert(error == OK, "Lake screenshot must save")

	var water = main.get("_water")
	assert(water != null)
	water.set_visual_quality_profile(&"high")
	water.set("visual_effects_enabled", true)
	water.set("visual_effects_auto_cleanup", false)
	# Use a closer, low angle for the event frame so the pooled rings are not
	# lost against the broad lake surface.
	camera.position = Vector3(-8.0, 2.15, -3.75)
	camera.look_at(Vector3(-8.0, 0.06, -6.4))
	water.call(
		"_create_surface_splash",
		Vector3(-8.0, water.global_position.y, -6.4),
		1.3,
		&"water_entry",
	)
	for _frame in 4:
		await physics_frame
		await process_frame
	var splash_image := root.get_texture().get_image()
	error = splash_image.save_png(SPLASH_OUTPUT_PATH)
	assert(error == OK, "Lake splash screenshot must save")
	print(
		"WATER_CAPTURE_OK outputs=", OUTPUT_PATH, ",", SPLASH_OUTPUT_PATH,
		" size=", image.get_size(),
	)
	main.queue_free()
	for _frame in 12:
		await process_frame
		await physics_frame
	quit()
