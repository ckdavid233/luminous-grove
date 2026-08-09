class_name ForestTerrain
extends StaticBody3D

const RENDER_GRID_SIZE := 129
const COLLISION_GRID_SIZE := 65
const HALF_EXTENT := 32.0
const RENDER_GRID_STEP := (HALF_EXTENT * 2.0) / float(RENDER_GRID_SIZE - 1)
const COLLISION_GRID_STEP := (HALF_EXTENT * 2.0) / float(COLLISION_GRID_SIZE - 1)
const LAKE_CENTER := Vector2(-8.0, -8.0)
const LAKE_RADII := Vector2(7.5, 5.0)


func configure(material: Material, physics_material: PhysicsMaterial = null) -> void:
	name = "Ground"
	collision_layer = 1
	collision_mask = 0
	set_meta("surface_type", &"dry_soil")
	if physics_material != null:
		physics_material_override = physics_material
	_build_mesh(material)
	_build_collision()


static func height_at(world_x: float, world_z: float) -> float:
	var macro_height := (
		sin(world_x * 0.105 + world_z * 0.037) * 0.075
		+ cos(world_z * 0.13 - world_x * 0.021) * 0.052
		+ sin((world_x + world_z) * 0.29) * 0.018
	)
	var lake_offset := Vector2(world_x, world_z) - LAKE_CENTER
	var lake_distance := Vector2(
		lake_offset.x / LAKE_RADII.x,
		lake_offset.y / LAKE_RADII.y,
	).length()
	if lake_distance <= 0.73:
		return -0.34 + sin(world_x * 0.52) * cos(world_z * 0.47) * 0.018
	if lake_distance < 1.11:
		var blend := smoothstep(0.73, 1.11, lake_distance)
		var lake_floor := -0.34 + sin(world_x * 0.52) * cos(world_z * 0.47) * 0.018
		return lerpf(lake_floor, macro_height, blend)
	return macro_height


func _build_mesh(material: Material) -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	vertices.resize(RENDER_GRID_SIZE * RENDER_GRID_SIZE)
	normals.resize(RENDER_GRID_SIZE * RENDER_GRID_SIZE)
	uvs.resize(RENDER_GRID_SIZE * RENDER_GRID_SIZE)
	for z_index in RENDER_GRID_SIZE:
		var world_z := -HALF_EXTENT + float(z_index) * RENDER_GRID_STEP
		for x_index in RENDER_GRID_SIZE:
			var world_x := -HALF_EXTENT + float(x_index) * RENDER_GRID_STEP
			var index := z_index * RENDER_GRID_SIZE + x_index
			var height := height_at(world_x, world_z)
			vertices[index] = Vector3(world_x, height, world_z)
			var height_left := height_at(world_x - RENDER_GRID_STEP, world_z)
			var height_right := height_at(world_x + RENDER_GRID_STEP, world_z)
			var height_back := height_at(world_x, world_z - RENDER_GRID_STEP)
			var height_forward := height_at(world_x, world_z + RENDER_GRID_STEP)
			normals[index] = Vector3(
				height_left - height_right,
				RENDER_GRID_STEP * 2.0,
				height_back - height_forward,
			).normalized()
			uvs[index] = Vector2(world_x, world_z) * 0.125
	for z_index in RENDER_GRID_SIZE - 1:
		for x_index in RENDER_GRID_SIZE - 1:
			var index := z_index * RENDER_GRID_SIZE + x_index
			indices.append_array(
				PackedInt32Array(
					[
						index,
						index + 1,
						index + RENDER_GRID_SIZE,
						index + 1,
						index + RENDER_GRID_SIZE + 1,
						index + RENDER_GRID_SIZE,
					]
				)
			)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "TerrainMesh"
	mesh_instance.mesh = mesh
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mesh_instance)


func _build_collision() -> void:
	var map_data := PackedFloat32Array()
	map_data.resize(COLLISION_GRID_SIZE * COLLISION_GRID_SIZE)
	for z_index in COLLISION_GRID_SIZE:
		var world_z := -HALF_EXTENT + float(z_index) * COLLISION_GRID_STEP
		for x_index in COLLISION_GRID_SIZE:
			var world_x := -HALF_EXTENT + float(x_index) * COLLISION_GRID_STEP
			map_data[z_index * COLLISION_GRID_SIZE + x_index] = height_at(world_x, world_z)
	var height_map := HeightMapShape3D.new()
	height_map.map_width = COLLISION_GRID_SIZE
	height_map.map_depth = COLLISION_GRID_SIZE
	height_map.map_data = map_data
	var collision := CollisionShape3D.new()
	collision.name = "TerrainCollision"
	collision.shape = height_map
	add_child(collision)
