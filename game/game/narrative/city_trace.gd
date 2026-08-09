class_name CityTrace
extends StaticBody3D

signal activated(trace_id: StringName)

@export var trace_id: StringName
@export var prompt_text := "读取守灯人的时间残响"
@export_flags_3d_render var visual_layer := 1

var is_available := false
var is_activated := false
var _core: MeshInstance3D
var _ring: MeshInstance3D
var _core_material: StandardMaterial3D
var _light: OmniLight3D
var _collision: CollisionShape3D
var _time := 0.0


func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 1 << 2
	collision_mask = 1
	_create_visuals()
	_create_collision()
	_apply_state()


func _process(delta: float) -> void:
	_time += delta
	_core.position.y = 1.35 + sin(_time * 1.9) * 0.08
	_ring.rotation.y += delta * 0.82
	_ring.rotation.x = sin(_time * 0.7) * 0.22


func can_interact(_actor: Node) -> bool:
	return is_available and not is_activated


func get_prompt(_actor: Node) -> String:
	return prompt_text


func interact(_actor: Node) -> void:
	if not can_interact(_actor):
		return
	set_activated(true)
	activated.emit(trace_id)


func set_available(value: bool) -> void:
	is_available = value
	_apply_state()


func set_activated(value: bool) -> void:
	is_activated = value
	_apply_state()


func _create_visuals() -> void:
	var pedestal := MeshInstance3D.new()
	var pedestal_mesh := CylinderMesh.new()
	pedestal_mesh.top_radius = 0.42
	pedestal_mesh.bottom_radius = 0.58
	pedestal_mesh.height = 1.1
	pedestal_mesh.radial_segments = 12
	var pedestal_material := StandardMaterial3D.new()
	pedestal_material.albedo_color = Color("273b43")
	pedestal_material.metallic = 0.22
	pedestal_material.roughness = 0.58
	pedestal_mesh.material = pedestal_material
	pedestal.mesh = pedestal_mesh
	pedestal.position.y = 0.55
	pedestal.layers = visual_layer
	add_child(pedestal)

	_core = MeshInstance3D.new()
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.27
	core_mesh.height = 0.54
	core_mesh.radial_segments = 18
	core_mesh.rings = 10
	_core_material = StandardMaterial3D.new()
	_core_material.albedo_color = Color("1f767c")
	_core_material.emission_enabled = true
	_core_material.emission = Color("55f7e8")
	_core_material.emission_energy_multiplier = 2.8
	_core_material.roughness = 0.14
	_core_material.clearcoat_enabled = true
	_core_material.clearcoat = 0.65
	_core_material.clearcoat_roughness = 0.08
	core_mesh.material = _core_material
	_core.mesh = core_mesh
	_core.position.y = 1.35
	_core.layers = visual_layer
	add_child(_core)

	_ring = MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.4
	ring_mesh.outer_radius = 0.48
	ring_mesh.rings = 24
	ring_mesh.ring_segments = 8
	var ring_material := StandardMaterial3D.new()
	ring_material.albedo_color = Color("62fff1")
	ring_material.emission_enabled = true
	ring_material.emission = Color("62fff1")
	ring_material.emission_energy_multiplier = 3.0
	ring_material.roughness = 0.12
	ring_mesh.material = ring_material
	_ring.mesh = ring_mesh
	_ring.position.y = 1.35
	_ring.layers = visual_layer
	add_child(_ring)

	_light = OmniLight3D.new()
	_light.position.y = 1.45
	_light.light_color = Color("65fff0")
	_light.light_energy = 2.0
	_light.omni_range = 5.0
	_light.shadow_enabled = true
	_light.layers = visual_layer
	add_child(_light)


func _create_collision() -> void:
	_collision = CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.58
	shape.height = 1.65
	_collision.shape = shape
	_collision.position.y = 0.82
	add_child(_collision)


func _apply_state() -> void:
	if _core_material == null:
		return
	var active := is_available and not is_activated
	collision_layer = (1 << 2) if active else 0
	_collision.disabled = not active
	if is_activated:
		_core_material.albedo_color = Color("8a6334")
		_core_material.emission = Color("ffc96f")
		_core_material.emission_energy_multiplier = 3.3
		_light.light_color = Color("ffd18b")
		_light.light_energy = 1.7
	elif active:
		_core_material.albedo_color = Color("1f767c")
		_core_material.emission = Color("55f7e8")
		_core_material.emission_energy_multiplier = 2.8
		_light.light_color = Color("65fff0")
		_light.light_energy = 2.0
	else:
		_core_material.albedo_color = Color("263e43")
		_core_material.emission = Color("31575a")
		_core_material.emission_energy_multiplier = 0.35
		_light.light_color = Color("31575a")
		_light.light_energy = 0.2
