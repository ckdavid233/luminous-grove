extends SceneTree

const FOREST_TERRAIN := preload("res://game/world/forest_terrain.gd")


class PhysicsRayProbe:
	extends Node3D

	var samples: Array[Vector2] = []
	var hits: Array[Dictionary] = []
	var completed := false


	func _physics_process(_delta: float) -> void:
		var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
		for sample in samples:
			var ray := PhysicsRayQueryParameters3D.create(
				Vector3(sample.x, 4.0, sample.y),
				Vector3(sample.x, -3.0, sample.y),
			)
			ray.collision_mask = 1
			hits.append(space.intersect_ray(ray))
		completed = true
		set_physics_process(false)


func _initialize() -> void:
	DirAccess.remove_absolute(
		ProjectSettings.globalize_path("user://save_slot_1.json")
	)
	var main_scene := load("res://game/main/main.tscn") as PackedScene
	var main := main_scene.instantiate() as Node3D
	root.add_child(main)
	for _frame in 8:
		await physics_frame
		await process_frame

	var ground := main.get_node("Ground") as StaticBody3D
	assert(ground != null and ground.get_script() == FOREST_TERRAIN)
	var terrain_mesh := ground.get_node("TerrainMesh") as MeshInstance3D
	var terrain_collision := ground.get_node("TerrainCollision") as CollisionShape3D
	assert(terrain_mesh.mesh is ArrayMesh)
	assert(terrain_mesh.mesh.get_faces().size() / 3 == 8192)
	assert(terrain_collision.shape is HeightMapShape3D)
	var height_map := terrain_collision.shape as HeightMapShape3D
	assert(height_map.map_width == 65 and height_map.map_depth == 65)

	var ray_samples: Array[Vector2] = [
		Vector2(0.0, 7.0),
		Vector2(-2.0, 3.0),
		Vector2(-8.0, -8.0),
	]
	var probe := PhysicsRayProbe.new()
	probe.samples = ray_samples
	main.add_child(probe)
	for _frame in 10:
		await physics_frame
		await process_frame
		if probe.completed:
			break
	assert(probe.completed and probe.hits.size() == ray_samples.size())
	for index in ray_samples.size():
		var sample := ray_samples[index]
		var hit: Dictionary = probe.hits[index]
		assert(not hit.is_empty(), "Terrain ray must hit at " + str(sample))
		assert(hit.collider == ground, "Terrain must own the walkable collision")
		var expected_height: float = FOREST_TERRAIN.height_at(sample.x, sample.y)
		assert(
			absf((hit.position as Vector3).y - expected_height) < 0.025,
			"Rendered terrain and collision height diverged at " + str(sample),
		)
	assert(
		FOREST_TERRAIN.height_at(-8.0, -8.0) < -0.31,
		"Lake needs a walkable shallow basin below its visual surface",
	)

	var tree_colliders := main.get_node("Forest/TreeColliders") as StaticBody3D
	var trunk_shapes := tree_colliders.find_children("*", "CollisionShape3D", false, false)
	assert(trunk_shapes.size() == 54, "Every detailed tree needs a trunk collider")
	for trunk in trunk_shapes:
		assert((trunk as CollisionShape3D).shape is CylinderShape3D)
	for variant_index in range(1, 4):
		var trees := main.get_node(
			"Forest/DetailedTrees_%d" % variant_index
		) as MultiMeshInstance3D
		assert(trees.multimesh.instance_count == 18)
		assert(trees.multimesh.mesh.get_surface_count() == 2)
		assert(
			trees.multimesh.mesh.get_faces().size() / 3 >= 4800,
			"Tree mesh must include roots, branch tiers and thousands of curved leaves",
		)

	var shore_colliders := main.get_node("LakeShore/ShoreColliders") as StaticBody3D
	var shore_shapes := shore_colliders.find_children("*", "CollisionShape3D", false, false)
	assert(shore_shapes.size() == 15, "Large shoreline rocks need sparse physical volume")
	for shore_shape in shore_shapes:
		assert((shore_shape as CollisionShape3D).shape is SphereShape3D)
	for batch_index in range(1, 4):
		var rock_batch := main.get_node(
			"LakeShore/ShoreRocks_%d" % batch_index
		) as MultiMeshInstance3D
		assert(rock_batch.multimesh.instance_count == (15 if batch_index < 3 else 14))
	var reeds := main.get_node("LakeShore/ShoreReeds") as MultiMeshInstance3D
	assert(reeds.multimesh.instance_count == 54)

	var grass := main.get_node("Grass") as MultiMeshInstance3D
	assert(grass.multimesh.instance_count == 16000)
	assert(
		grass.multimesh.mesh.get_faces().size() / 3 == 20,
		"Every grass clump must use five curved four-triangle blades",
	)
	var water := main.get_node("Water") as MeshInstance3D
	assert(
		water.mesh.get_faces().size() / 3 > 7000,
		"Water must use a dense elliptical surface instead of a rectangular plane",
	)

	var player := main.get_node("Player") as CharacterBody3D
	var player_collision := player.get_node("CollisionShape3D") as CollisionShape3D
	var player_capsule := player_collision.shape as CapsuleShape3D
	assert(is_equal_approx(player_capsule.radius, 0.34))
	assert(is_equal_approx(player_capsule.height, 1.72))
	assert(is_equal_approx(player.safe_margin, 0.025))
	assert(player.floor_snap_length >= 0.3)

	player.set_physics_process(false)
	var first_trunk := trunk_shapes[0] as CollisionShape3D
	var trunk_world := tree_colliders.to_global(first_trunk.position)
	var trunk_radius := (first_trunk.shape as CylinderShape3D).radius
	var start_clearance := trunk_radius + player_capsule.radius + 0.62
	player.global_position = Vector3(
		trunk_world.x + start_clearance,
		FOREST_TERRAIN.height_at(trunk_world.x + start_clearance, trunk_world.z) + 0.08,
		trunk_world.z,
	)
	var tree_hit: KinematicCollision3D = player.move_and_collide(
		Vector3(-start_clearance, 0.0, 0.0),
		true,
		0.001,
		false,
	)
	assert(tree_hit != null, "Player capsule must be blocked by a tree trunk")
	assert(tree_hit.get_collider() == tree_colliders)
	tree_hit = null

	print(
		"ENVIRONMENT_GEOMETRY_TEST_OK terrain_triangles=8192 trees=54 "
		+ "tree_variants=3 shore_colliders=15 grass_clumps=16000 water=dense_ellipse"
	)
	var streamer = main.get("_world_streamer")
	for _frame in 600:
		if streamer.is_level_ready(
			"res://content/levels/echo_ruins/echo_ruins.tscn"
		):
			break
		await process_frame
	streamer.clear_inactive_levels()
	main.queue_free()
	for _frame in 3:
		await process_frame
		await physics_frame
	call_deferred("quit")
