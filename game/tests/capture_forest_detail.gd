extends SceneTree

const OUTPUT_PATH := "/home/cenkai/game_dev_plan/previews/forest_tree_detail.png"


func _initialize() -> void:
	DirAccess.remove_absolute(
		ProjectSettings.globalize_path("user://save_slot_1.json")
	)
	root.size = Vector2i(1280, 720)
	var main_scene := load("res://game/main/main.tscn") as PackedScene
	var main := main_scene.instantiate() as Node3D
	root.add_child(main)
	for _frame in 24:
		await process_frame

	var trees := main.get_node("Forest/DetailedTrees_1") as MultiMeshInstance3D
	trees.multimesh.visible_instance_count = 1
	main.get_node("Forest/DetailedTrees_2").visible = false
	main.get_node("Forest/DetailedTrees_3").visible = false
	main.get_node("Forest/NearCanopyFill_2").visible = false
	main.get_node("Forest/NearCanopyFill_3").visible = false
	main.get_node("Forest/NearTreeRoots_2").visible = false
	main.get_node("Forest/NearTreeRoots_3").visible = false
	main.get_node("Forest/MidTreeTrunks").visible = false
	main.get_node("Forest/MidTreeCanopies").visible = false
	main.get_node("Forest/FarTreeTrunks").visible = false
	main.get_node("Forest/FarTreeCanopies").visible = false
	var tree_transform := trees.multimesh.get_instance_transform(0)
	var target := tree_transform.origin + Vector3.UP * 3.6 * tree_transform.basis.get_scale().y
	var camera := Camera3D.new()
	camera.fov = 48.0
	camera.cull_mask = 5
	camera.position = target + Vector3(6.8, 1.15, 6.8)
	main.add_child(camera)
	camera.look_at(target)
	camera.make_current()
	for canvas in main.find_children("*", "CanvasLayer", true, false):
		(canvas as CanvasLayer).visible = false
	for _frame in 120:
		await process_frame
	var image := root.get_texture().get_image()
	var error := image.save_png(OUTPUT_PATH)
	assert(error == OK, "Forest detail screenshot must save")
	print("FOREST_DETAIL_CAPTURE_OK output=", OUTPUT_PATH, " size=", image.get_size())
	quit()
