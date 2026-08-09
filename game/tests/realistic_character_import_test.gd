extends SceneTree

const CHARACTER_SCENE := preload(
	"res://content/characters/realistic_player/ji_realistic.glb"
)


func _initialize() -> void:
	var character := CHARACTER_SCENE.instantiate()
	root.add_child(character)
	await process_frame

	var skeletons := character.find_children("*", "Skeleton3D", true, false)
	var meshes := character.find_children("*", "MeshInstance3D", true, false)
	assert(skeletons.size() == 1, "Realistic character must import one shared skeleton")
	assert(meshes.size() >= 14, "Body, clothes and travel accessories must import")
	for accessory_name in [
		"Ji_Travel_Belt",
		"Ji_Crossbody_Sash",
		"Ji_Memory_Pouch",
		"Ji_Belt_Clasp",
		"Ji_Rain_Memory_Seal",
	]:
		assert(
			character.find_child(accessory_name, true, false) is MeshInstance3D,
			"Missing character identity accessory: " + accessory_name,
		)
	var skeleton := skeletons[0] as Skeleton3D
	assert(skeleton.get_bone_count() == 53, "Game-engine rig must keep all 53 bones")
	for bone_name in [
		&"Root",
		&"pelvis",
		&"spine_01",
		&"head",
		&"upperarm_l",
		&"hand_r",
		&"thigh_l",
		&"foot_r",
	]:
		assert(
			skeleton.find_bone(bone_name) >= 0,
			"Missing humanoid bone: " + str(bone_name)
		)

	var animation_player := character.find_child(
		"AnimationPlayer",
		true,
		false
	) as AnimationPlayer
	assert(animation_player != null, "Animated glTF must import an AnimationPlayer")
	var animation_summary: Array[String] = []
	var minimum_animation_lengths := {
		&"Idle": 1.8,
		&"Walk": 0.9,
		&"Run": 0.65,
		&"Jump": 0.72,
		&"Fall": 0.9,
		&"Land": 0.48,
		&"Interact": 1.6,
	}
	for animation_name in [&"Idle", &"Walk", &"Run", &"Jump", &"Fall", &"Land", &"Interact"]:
		assert(
			animation_player.has_animation(animation_name),
			"Missing gameplay animation: " + str(animation_name)
		)
		var animation := animation_player.get_animation(animation_name)
		assert(animation != null)
		assert(
			animation.length >= minimum_animation_lengths[animation_name],
			"Animation is too short to be usable: " + str(animation_name),
		)
		assert(animation.get_track_count() >= 4, "Animation lost its bone tracks")
		animation_summary.append(
			"%s:%.2fs/%d"
			% [animation_name, animation.length, animation.get_track_count()]
		)

	var textured_materials := 0
	var surface_count := 0
	var vertex_count := 0
	var material_names: Array[String] = []
	for node in meshes:
		var mesh_instance := node as MeshInstance3D
		assert(mesh_instance.mesh != null)
		vertex_count += mesh_instance.mesh.get_faces().size()
		for surface in mesh_instance.mesh.get_surface_count():
			surface_count += 1
			var material := mesh_instance.get_active_material(surface)
			if material != null:
				material_names.append(
					"%s:%s" % [mesh_instance.name, material.resource_name]
				)
			if (
				material is StandardMaterial3D
				and (material as StandardMaterial3D).albedo_texture != null
			):
				textured_materials += 1
	assert(surface_count >= 9)
	assert(textured_materials >= 7, "Exported PBR textures must survive glTF import")
	assert(vertex_count > 30000, "Imported meshes must contain detailed render geometry")

	print(
		(
			"REALISTIC_CHARACTER_IMPORT_OK meshes=%d bones=%d surfaces=%d "
			+ "textured=%d faces=%d animations=%s"
		)
		% [
			meshes.size(),
			skeleton.get_bone_count(),
			surface_count,
			textured_materials,
			vertex_count / 3,
			",".join(animation_summary),
		]
	)
	print("REALISTIC_CHARACTER_MATERIALS ", ";".join(material_names))
	character.queue_free()
	await process_frame
	call_deferred("quit")
