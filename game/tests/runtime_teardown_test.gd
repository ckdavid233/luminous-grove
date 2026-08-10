extends SceneTree


func _initialize() -> void:
	DirAccess.remove_absolute(
		ProjectSettings.globalize_path("user://save_slot_1.json")
	)
	var main_scene := load("res://game/main/main.tscn") as PackedScene
	var main := main_scene.instantiate() as Node3D
	root.add_child(main)
	await process_frame
	await physics_frame

	var streamer = main.get("_world_streamer")
	for _frame in 600:
		if streamer.is_level_ready(
			"res://content/levels/echo_ruins/echo_ruins.tscn"
		):
			break
		await process_frame

	main.shutdown()
	var mesh_count := 0
	var multimesh_count := 0
	var particle_count := 0
	var environment_count := 0
	for node in main.find_children("*", "", true, false):
		if node is MeshInstance3D:
			mesh_count += 1
			assert(
				(node as MeshInstance3D).mesh == null,
				"Shutdown must detach MeshInstance3D.mesh: " + node.name,
			)
		elif node is MultiMeshInstance3D:
			multimesh_count += 1
			assert(
				(node as MultiMeshInstance3D).multimesh == null,
				"Shutdown must detach MultiMeshInstance3D.multimesh: " + node.name,
			)
		elif node is GPUParticles3D:
			particle_count += 1
			var particles := node as GPUParticles3D
			assert(not particles.emitting)
			assert(particles.process_material == null)
			assert(particles.draw_pass_1 == null)
		elif node is AnimationTree:
			var animation_tree := node as AnimationTree
			assert(not animation_tree.active)
			assert(animation_tree.tree_root == null)
			assert(animation_tree.anim_player == NodePath(""))
		elif node is WorldEnvironment:
			environment_count += 1
			assert((node as WorldEnvironment).environment == null)

	print(
		"RUNTIME_TEARDOWN_TEST_OK meshes=%d multimeshes=%d particles=%d environments=%d"
		% [mesh_count, multimesh_count, particle_count, environment_count]
	)
	main.queue_free()
	main = null
	for _frame in 120:
		await process_frame
		await physics_frame
	call_deferred("quit")
