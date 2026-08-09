class_name WetnessController
extends Node

signal wetness_changed(wetness: float, rain_intensity: float)

@export_range(0.0, 1.0, 0.01) var rain_intensity := 0.62
@export_range(0.0, 1.0, 0.01) var wetness := 0.54

var _target_rain_intensity := 0.62
var _target_wetness := 0.54
var _registered_materials: Array[Material] = []
var _base_material_state: Dictionary = {}
var _last_emitted_wetness := -1.0


func _ready() -> void:
	process_priority = -20
	_target_rain_intensity = rain_intensity
	_target_wetness = wetness


func _exit_tree() -> void:
	# Materials are owned by scene meshes; this controller only observes them.
	# Release the registry explicitly before the scene's GeometryInstances leave
	# the tree to avoid keeping RefCounted material handles alive during teardown.
	_registered_materials.clear()
	_base_material_state.clear()


func _process(delta: float) -> void:
	_target_wetness = clampf(
		0.12 + _target_rain_intensity * 0.78,
		0.0,
		1.0,
	)
	var previous := wetness
	rain_intensity = move_toward(rain_intensity, _target_rain_intensity, delta * 0.6)
	wetness = move_toward(wetness, _target_wetness, delta * 0.22)
	if absf(wetness - previous) < 0.0005 and absf(wetness - _last_emitted_wetness) < 0.01:
		return
	_apply_to_materials()
	_last_emitted_wetness = wetness
	wetness_changed.emit(wetness, rain_intensity)


func set_rain_intensity(value: float) -> void:
	_target_rain_intensity = clampf(value, 0.0, 1.0)


func add_wetness(amount: float) -> void:
	_target_wetness = clampf(_target_wetness + amount, 0.0, 1.0)


func get_wetness() -> float:
	return wetness


func register_material(material: Material) -> void:
	if material == null or _registered_materials.has(material):
		return
	_registered_materials.append(material)
	if material is BaseMaterial3D:
		_base_material_state[material.get_instance_id()] = {
			"roughness": (material as BaseMaterial3D).roughness,
			"albedo_color": (material as BaseMaterial3D).albedo_color,
		}


func register_node(root: Node) -> void:
	if root == null:
		return
	if root is GeometryInstance3D:
		_register_geometry(root as GeometryInstance3D)
	for node in root.find_children("*", "GeometryInstance3D", true, false):
		_register_geometry(node as GeometryInstance3D)


func _register_geometry(geometry: GeometryInstance3D) -> void:
	if geometry.material_override != null:
		register_material(geometry.material_override)
	if geometry is MeshInstance3D:
		var mesh_instance := geometry as MeshInstance3D
		for surface_index in mesh_instance.get_surface_override_material_count():
			register_material(mesh_instance.get_surface_override_material(surface_index))
		if mesh_instance.mesh != null:
			for surface_index in mesh_instance.mesh.get_surface_count():
				register_material(mesh_instance.mesh.surface_get_material(surface_index))
	elif geometry is MultiMeshInstance3D:
		var multimesh_instance := geometry as MultiMeshInstance3D
		if multimesh_instance.multimesh != null and multimesh_instance.multimesh.mesh != null:
			for surface_index in multimesh_instance.multimesh.mesh.get_surface_count():
				register_material(
					multimesh_instance.multimesh.mesh.surface_get_material(surface_index)
				)


func _apply_to_materials() -> void:
	for material in _registered_materials:
		if not is_instance_valid(material):
			continue
		if material is ShaderMaterial:
			var shader_material := material as ShaderMaterial
			shader_material.set_shader_parameter("wetness", wetness)
			shader_material.set_shader_parameter("rain_intensity", rain_intensity)
			continue
		if not material is BaseMaterial3D:
			continue
		var base_material := material as BaseMaterial3D
		var state: Dictionary = _base_material_state.get(material.get_instance_id(), {})
		var base_roughness := float(state.get("roughness", base_material.roughness))
		var base_color: Color = state.get("albedo_color", base_material.albedo_color)
		base_material.roughness = lerpf(base_roughness, maxf(0.24, base_roughness * 0.48), wetness * 0.78)
		base_material.albedo_color = base_color.lerp(Color(0.74, 0.81, 0.79), wetness * 0.1)
