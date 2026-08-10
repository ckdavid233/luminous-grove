extends Node3D

const ECHO_VISUAL_LAYER := 1 << 1
const ARCHIVE_ANCHOR := preload("res://game/narrative/archive_anchor.gd")
const CITY_GATE := preload("res://game/narrative/city_gate.gd")
const JOLT_COUNTERWEIGHT := preload(
	"res://game/narrative/jolt_counterweight_plate.gd"
)
const PUSHABLE_MEMORY_STONE := preload(
	"res://game/world/pushable_memory_stone.gd"
)

signal archive_anchor_activated(anchor_id: StringName)
signal archive_mechanism_activated(mechanism_id: StringName)
signal city_gate_entered

var _stone_material: StandardMaterial3D
var _floor_material: StandardMaterial3D
var _archive_anchors: Array[Node] = []
var _counterweight_plate: Node
var _counterweight_stone: RigidBody3D
var _city_gate: Node
var _shutdown_requested := false


func _exit_tree() -> void:
	shutdown()


func shutdown() -> void:
	if _shutdown_requested:
		return
	_shutdown_requested = true
	# Echo Ruins is generated at runtime rather than loaded as a mesh scene.
	# Clear the material maps before WorldStreamer detaches the MeshInstances;
	# otherwise the shared imported textures can keep GPU Texture RIDs alive
	# until RenderingDevice finalization.
	for geometry in find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := geometry as MeshInstance3D
		if mesh_instance.mesh != null:
			var surface_override_count := mesh_instance.get_surface_override_material_count()
			for surface_index in surface_override_count:
				mesh_instance.set_surface_override_material(surface_index, null)
		if mesh_instance.mesh is PrimitiveMesh:
			(mesh_instance.mesh as PrimitiveMesh).material = null
		mesh_instance.material_override = null
		mesh_instance.mesh = null
	_clear_material_maps(_stone_material)
	_clear_material_maps(_floor_material)
	_stone_material = null
	_floor_material = null
	_archive_anchors.clear()
	_counterweight_plate = null
	_counterweight_stone = null
	_city_gate = null


func _clear_material_maps(material: StandardMaterial3D) -> void:
	if material == null:
		return
	material.albedo_texture = null
	material.normal_texture = null
	material.roughness_texture = null
	material.metallic_texture = null
	material.emission_texture = null
	material.ao_texture = null
	material.heightmap_texture = null


func _ready() -> void:
	_stone_material = _create_pbr_material("shrine_stone", Color("879b9b"), 0.52)
	_floor_material = _create_pbr_material("lake_stone", Color("637d7d"), 0.3)
	_create_floor()
	_create_ruins()
	_create_physics_stack()
	_create_counterweight_mechanism()
	_create_archive_anchors()
	_create_city_gate()
	_create_memory_pool()
	_create_lighting()
	set_meta("stream_keep_visual_when_inactive", true)
	_set_visual_layer(self, ECHO_VISUAL_LAYER)


func _create_floor() -> void:
	var body := StaticBody3D.new()
	body.name = "EchoFloor"
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(64.0, 0.45, 64.0)
	mesh.material = _floor_material
	mesh_instance.mesh = mesh
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = mesh.size
	collision.shape = shape
	body.add_child(collision)
	body.position.y = -0.24
	add_child(body)


func _create_ruins() -> void:
	var ruins := Node3D.new()
	ruins.name = "RainArchiveRuins"
	add_child(ruins)
	var column_mesh := CylinderMesh.new()
	column_mesh.top_radius = 0.42
	column_mesh.bottom_radius = 0.58
	column_mesh.height = 5.8
	column_mesh.radial_segments = 14
	column_mesh.material = _stone_material
	for index in 18:
		var side := -1.0 if index % 2 == 0 else 1.0
		var row := index / 2
		var position := Vector3(side * 5.4, 2.9, 9.0 - row * 3.0)
		var body := StaticBody3D.new()
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = column_mesh
		body.add_child(mesh_instance)
		var collision := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = 0.58
		shape.height = 5.8
		collision.shape = shape
		body.add_child(collision)
		body.position = position
		body.rotation_degrees.z = 0.0 if index % 5 else 7.0 * side
		ruins.add_child(body)

	for row in 8:
		var lintel := StaticBody3D.new()
		var mesh_instance := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(10.6, 0.58, 0.75)
		mesh.material = _stone_material
		mesh_instance.mesh = mesh
		lintel.add_child(mesh_instance)
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = mesh.size
		collision.shape = shape
		lintel.add_child(collision)
		lintel.position = Vector3(0.0, 5.72, 9.0 - row * 3.0)
		if row in [2, 5]:
			lintel.rotation_degrees.z = 8.0
			lintel.position.y -= 0.35
		ruins.add_child(lintel)

	var wall_positions := [
		Vector3(-1.8, 1.3, 2.0),
		Vector3(2.5, 1.3, -4.0),
		Vector3(-3.0, 1.3, -10.0),
	]
	for position in wall_positions:
		var wall := StaticBody3D.new()
		var mesh_instance := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(6.0, 2.6, 0.62)
		mesh.material = _stone_material
		mesh_instance.mesh = mesh
		wall.add_child(mesh_instance)
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = mesh.size
		collision.shape = shape
		wall.add_child(collision)
		wall.position = position
		wall.rotation_degrees.y = 18.0 if position.x < 0.0 else -22.0
		ruins.add_child(wall)


func _create_physics_stack() -> void:
	var stack := Node3D.new()
	stack.name = "JoltPhysicsStack"
	add_child(stack)
	for level in 4:
		for column in range(4 - level):
			var body := RigidBody3D.new()
			body.name = "MemoryStone_%d_%d" % [level, column]
			body.mass = 4.5
			body.position = Vector3(
				2.3 + column * 0.82 + level * 0.41,
				0.48 + level * 0.82,
				3.7
			)
			body.rotation_degrees.y = (column * 13.0 + level * 7.0)
			var mesh_instance := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(0.74, 0.74, 0.74)
			mesh.material = _stone_material
			mesh_instance.mesh = mesh
			body.add_child(mesh_instance)
			var collision := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = mesh.size
			collision.shape = shape
			body.add_child(collision)
			stack.add_child(body)


func _create_counterweight_mechanism() -> void:
	var mechanism := Node3D.new()
	mechanism.name = "ArchiveCounterweightMechanism"
	add_child(mechanism)

	_counterweight_plate = JOLT_COUNTERWEIGHT.new()
	_counterweight_plate.position = Vector3(0.0, 0.0, -9.0)
	_counterweight_plate.activated.connect(
		func(mechanism_id: StringName) -> void:
			archive_mechanism_activated.emit(mechanism_id)
	)
	mechanism.add_child(_counterweight_plate)

	_counterweight_stone = PUSHABLE_MEMORY_STONE.new()
	_counterweight_stone.name = "ArchiveCounterweightStone"
	_counterweight_stone.mass = 5.5
	_counterweight_stone.position = Vector3(2.65, 0.58, -9.0)
	_counterweight_stone.linear_damp = 1.15
	_counterweight_stone.angular_damp = 1.6
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.95, 0.95, 0.95)
	mesh.material = _stone_material
	mesh_instance.mesh = mesh
	_counterweight_stone.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = mesh.size
	collision.shape = shape
	_counterweight_stone.add_child(collision)
	mechanism.add_child(_counterweight_stone)


func _create_archive_anchors() -> void:
	var definitions := [
		[&"archive_voice", "听声锚点", Vector3(-2.8, 0.0, 4.0)],
		[&"archive_shape", "塑形锚点", Vector3(0.0, 0.0, -5.0)],
		[&"archive_name", "铭名锚点", Vector3(2.8, 0.0, -14.0)],
	]
	for definition in definitions:
		var anchor := ARCHIVE_ANCHOR.new()
		anchor.name = "ArchiveAnchor_" + str(definition[0])
		anchor.anchor_id = definition[0]
		anchor.prompt_text = "唤醒" + str(definition[1])
		anchor.position = definition[2]
		anchor.activated.connect(_on_archive_anchor_activated)
		_archive_anchors.append(anchor)
		add_child(anchor)


func _create_city_gate() -> void:
	_city_gate = CITY_GATE.new()
	_city_gate.position = Vector3(0.0, 0.0, -19.0)
	_city_gate.entered.connect(
		func() -> void: city_gate_entered.emit()
	)
	add_child(_city_gate)


func sync_archive_state(
	available: bool,
	activated_ids: Array[StringName],
	mechanisms_available := false,
	activated_mechanism_ids: Array[StringName] = [],
	next_mechanism_id: StringName = &"",
	gate_available := false,
) -> void:
	for anchor in _archive_anchors:
		anchor.set_activated(activated_ids.has(anchor.anchor_id))
		anchor.set_available(available)
	if _counterweight_plate != null:
		_counterweight_plate.set_activated(
			activated_mechanism_ids.has(&"archive_counterweight")
		)
		_counterweight_plate.set_available(
			mechanisms_available
			and next_mechanism_id == &"archive_counterweight"
		)
	if _city_gate != null:
		_city_gate.set_available(gate_available)


func get_archive_anchors() -> Array[Node]:
	return _archive_anchors


func get_city_gate() -> Node:
	return _city_gate


func get_counterweight_plate() -> Node:
	return _counterweight_plate


func get_counterweight_stone() -> RigidBody3D:
	return _counterweight_stone


func _on_archive_anchor_activated(anchor_id: StringName) -> void:
	archive_anchor_activated.emit(anchor_id)


func _create_memory_pool() -> void:
	var pool := MeshInstance3D.new()
	pool.name = "SuspendedRainPool"
	var plane := PlaneMesh.new()
	plane.size = Vector2(15.0, 10.0)
	plane.subdivide_width = 48
	plane.subdivide_depth = 32
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode cull_disabled;

varying vec3 world_position;

float rings(vec2 point) {
	float first = sin(length(point - vec2(-2.3, 0.7)) * 8.0 - TIME * 2.4);
	float second = sin(length(point - vec2(2.1, -1.6)) * 10.0 - TIME * 1.8);
	return (first + second) * 0.5;
}

void vertex() {
	float ripple = rings(VERTEX.xz);
	VERTEX.y += ripple * 0.025;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float grid = pow(abs(sin(world_position.x * 2.2) * sin(world_position.z * 2.2)), 7.0);
	ALBEDO = mix(vec3(0.025, 0.09, 0.12), vec3(0.13, 0.72, 0.75), grid);
	EMISSION = vec3(0.04, 0.65, 0.68) * grid * 1.8;
	ROUGHNESS = 0.1;
	SPECULAR = 0.95;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	plane.material = material
	pool.mesh = plane
	pool.position = Vector3(-8.0, 0.035, -8.0)
	add_child(pool)


func _create_lighting() -> void:
	for position in [
		Vector3(-4.8, 2.4, 5.0),
		Vector3(4.8, 2.4, -2.0),
		Vector3(-4.8, 2.4, -10.0),
	]:
		var light := OmniLight3D.new()
		light.position = position
		light.light_color = Color("5ffff2")
		light.light_energy = 2.4
		light.omni_range = 8.0
		light.shadow_enabled = true
		add_child(light)


func _create_pbr_material(
	folder: String,
	tint: Color,
	scale: float,
) -> StandardMaterial3D:
	var root := "res://content/materials/" + folder + "/"
	var material := StandardMaterial3D.new()
	material.albedo_texture = load(root + "albedo.png") as Texture2D
	material.albedo_color = tint
	material.normal_enabled = true
	material.normal_texture = load(root + "normal.png") as Texture2D
	material.normal_scale = 0.85
	material.roughness = 1.0
	material.roughness_texture = load(root + "roughness.png") as Texture2D
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE * scale
	return material


func _set_visual_layer(root: Node, visual_layer: int) -> void:
	var visuals: Array[Node] = []
	if root is VisualInstance3D:
		visuals.append(root)
	visuals.append_array(root.find_children("*", "VisualInstance3D", true, false))
	for node in visuals:
		(node as VisualInstance3D).layers = visual_layer
