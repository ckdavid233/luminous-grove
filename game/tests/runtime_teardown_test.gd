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
	var phase_shift = main.get("_phase_shift")
	var cinematic_director = main.get("_cinematic_director")
	for _frame in 600:
		if streamer.is_level_ready(
			"res://content/levels/echo_ruins/echo_ruins.tscn"
		):
			break
		await process_frame
	main.shutdown()
	assert(
		phase_shift.get("_restore_query") == null,
		"PhaseShiftController must release its reusable physics query",
	)
	assert(
		phase_shift.get("_streamer") == null
			and phase_shift.get("_player") == null
			and phase_shift.get("_present_nodes").is_empty(),
		"PhaseShiftController must release scene references",
	)
	assert(
		cinematic_director.get("_active_tween") == null
			and cinematic_director.get("_player") == null
			and cinematic_director.get("_gameplay_camera") == null,
		"CinematicDirector must release Tween and camera references",
	)
	var mesh_count := 0
	var multimesh_count := 0
	var particle_count := 0
	var environment_count := 0
	var camera_count := 0
	for node in main.find_children("*", "", true, false):
		if node is Camera3D:
			camera_count += 1
			assert(
				not (node as Camera3D).current,
				"Shutdown must clear Camera3D.current: " + node.name,
			)
		elif node is MeshInstance3D:
			mesh_count += 1
			var mesh_instance := node as MeshInstance3D
			for surface_index in mesh_instance.get_surface_override_material_count():
				assert(
					mesh_instance.get_surface_override_material(surface_index) == null,
					"Shutdown must clear MeshInstance3D surface overrides: " + node.name,
				)
			assert(
				mesh_instance.mesh == null,
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
		"RUNTIME_TEARDOWN_TEST_OK meshes=%d multimeshes=%d particles=%d cameras=%d environments=%d"
		% [mesh_count, multimesh_count, particle_count, camera_count, environment_count]
	)
	main.queue_free()
	main = null
	for _frame in 120:
		await process_frame
		await physics_frame
	main_scene = null
	call_deferred("quit")
