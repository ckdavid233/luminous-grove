class_name StoryResonator
extends StaticBody3D

signal activated(resonance_id: StringName)

@export var resonance_id: StringName
@export var prompt_text := "调谐记忆共振"
@export_flags_3d_render var visual_layer := 1
@export var accent_color := Color("55f4e5")

var is_available := false
var is_activated := false
var _core_material: StandardMaterial3D
var _ring: MeshInstance3D
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
	if _ring != null:
		_ring.rotation.y += delta * (1.15 if is_available else 0.24)
		_ring.rotation.z = sin(_time * 0.8) * 0.2


func can_interact(_actor: Node) -> bool:
	return is_available and not is_activated


func get_prompt(_actor: Node) -> String:
	return prompt_text


func interact(_actor: Node) -> void:
	if not can_interact(_actor):
		return
	set_activated(true)
	activated.emit(resonance_id)


func set_available(value: bool) -> void:
	is_available = value
	_apply_state()


func set_activated(value: bool) -> void:
	is_activated = value
	_apply_state()


func _create_visuals() -> void:
	var pedestal := MeshInstance3D.new()
	var pedestal_mesh := CylinderMesh.new()
	pedestal_mesh.top_radius = 0.48
	pedestal_mesh.bottom_radius = 0.68
	pedestal_mesh.height = 1.0
	pedestal_mesh.radial_segments = 16
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color("263d43")
	stone.metallic = 0.18
	stone.roughness = 0.66
	pedestal_mesh.material = stone
	pedestal.mesh = pedestal_mesh
	pedestal.position.y = 0.5
	pedestal.layers = visual_layer
	add_child(pedestal)

	var core := MeshInstance3D.new()
	var core_mesh := PrismMesh.new()
	core_mesh.size = Vector3(0.58, 0.95, 0.58)
	_core_material = StandardMaterial3D.new()
	_core_material.albedo_color = accent_color.darkened(0.45)
	_core_material.emission_enabled = true
	_core_material.emission = accent_color
	_core_material.emission_energy_multiplier = 2.5
	_core_material.metallic = 0.34
	_core_material.roughness = 0.16
	core_mesh.material = _core_material
	core.mesh = core_mesh
	core.position.y = 1.25
	core.layers = visual_layer
	add_child(core)

	_ring = MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.55
	ring_mesh.outer_radius = 0.63
	ring_mesh.rings = 28
	ring_mesh.ring_segments = 8
	ring_mesh.material = _core_material
	_ring.mesh = ring_mesh
	_ring.position.y = 1.3
	_ring.rotation_degrees.x = 90.0
	_ring.layers = visual_layer
	add_child(_ring)

	_light = OmniLight3D.new()
	_light.position.y = 1.35
	_light.light_color = accent_color
	_light.light_energy = 2.4
	_light.omni_range = 5.5
	_light.shadow_enabled = true
	_light.layers = visual_layer
	add_child(_light)


func _create_collision() -> void:
	_collision = CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.7
	shape.height = 1.8
	_collision.shape = shape
	_collision.position.y = 0.9
	add_child(_collision)


func _apply_state() -> void:
	if _core_material == null:
		return
	var active := is_available and not is_activated
	collision_layer = (1 << 2) if active else 0
	_collision.disabled = not active
	if is_activated:
		_core_material.albedo_color = Color("946538")
		_core_material.emission = Color("ffd17b")
		_core_material.emission_energy_multiplier = 3.8
		_light.light_color = Color("ffd17b")
		_light.light_energy = 2.0
	elif active:
		_core_material.albedo_color = accent_color.darkened(0.42)
		_core_material.emission = accent_color
		_core_material.emission_energy_multiplier = 3.2
		_light.light_color = accent_color
		_light.light_energy = 2.6
	else:
		_core_material.albedo_color = Color("26373b")
		_core_material.emission = Color("314b4d")
		_core_material.emission_energy_multiplier = 0.28
		_light.light_color = Color("315459")
		_light.light_energy = 0.18
