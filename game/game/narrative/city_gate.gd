class_name CityGate
extends StaticBody3D

signal entered

const ECHO_VISUAL_LAYER := 1 << 1

@export var gate_name := "LanternCityGate"
@export var prompt_text := "穿过雨幕，前往行灯之城"
@export_flags_3d_render var visual_layer := ECHO_VISUAL_LAYER

var is_available := false
var is_entered := false
var _surface: MeshInstance3D
var _surface_material: StandardMaterial3D
var _light: OmniLight3D
var _collision: CollisionShape3D
var _time := 0.0


func _ready() -> void:
	name = gate_name
	add_to_group("interactable")
	collision_layer = 1 << 2
	collision_mask = 1
	_create_arch()
	_create_surface()
	_create_collision()
	_apply_state()


func _process(delta: float) -> void:
	_time += delta
	if _surface != null:
		_surface.scale.x = 1.0 + sin(_time * 1.7) * 0.025
		_surface.rotation.z = sin(_time * 0.8) * 0.015


func can_interact(_actor: Node) -> bool:
	return is_available and not is_entered


func get_prompt(_actor: Node) -> String:
	return prompt_text


func interact(_actor: Node) -> void:
	if not can_interact(_actor):
		return
	is_entered = true
	_apply_state()
	entered.emit()


func set_available(value: bool) -> void:
	is_available = value
	_apply_state()


func _create_arch() -> void:
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color("263c43")
	stone.metallic = 0.08
	stone.roughness = 0.74
	for definition in [
		[Vector3(-2.05, 2.5, 0.0), Vector3(0.72, 5.0, 0.9)],
		[Vector3(2.05, 2.5, 0.0), Vector3(0.72, 5.0, 0.9)],
		[Vector3(0.0, 5.0, 0.0), Vector3(4.8, 0.72, 0.9)],
	]:
		var mesh_instance := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = definition[1]
		mesh.material = stone
		mesh_instance.mesh = mesh
		mesh_instance.position = definition[0]
		mesh_instance.layers = visual_layer
		add_child(mesh_instance)


func _create_surface() -> void:
	_surface = MeshInstance3D.new()
	_surface.name = "CityGateRainSurface"
	var plane := QuadMesh.new()
	plane.size = Vector2(3.55, 4.35)
	_surface_material = StandardMaterial3D.new()
	_surface_material.albedo_color = Color(0.12, 0.66, 0.69, 0.72)
	_surface_material.emission_enabled = true
	_surface_material.emission = Color("46f6e5")
	_surface_material.emission_energy_multiplier = 2.2
	_surface_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_surface_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_surface_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	plane.material = _surface_material
	_surface.mesh = plane
	_surface.position = Vector3(0.0, 2.45, 0.02)
	_surface.layers = visual_layer
	add_child(_surface)

	_light = OmniLight3D.new()
	_light.position = Vector3(0.0, 2.6, 0.8)
	_light.light_color = Color("59fff0")
	_light.light_energy = 3.2
	_light.omni_range = 8.5
	_light.shadow_enabled = true
	_light.layers = visual_layer
	add_child(_light)


func _create_collision() -> void:
	_collision = CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.7, 4.5, 0.5)
	_collision.shape = shape
	_collision.position = Vector3(0.0, 2.3, 0.0)
	add_child(_collision)


func _apply_state() -> void:
	if _surface_material == null:
		return
	var active := is_available and not is_entered
	collision_layer = (1 << 2) if active else 0
	_collision.disabled = not active
	_surface_material.emission_energy_multiplier = 3.4 if active else 0.45
	_surface_material.albedo_color = (
		Color(0.15, 0.78, 0.74, 0.82)
		if active
		else Color(0.08, 0.22, 0.24, 0.42)
	)
	_light.light_energy = 4.2 if active else 0.35
