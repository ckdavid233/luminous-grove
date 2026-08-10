class_name JoltCounterweightPlate
extends Area3D

signal activated(mechanism_id: StringName)

@export var mechanism_id: StringName = &"archive_counterweight"
@export_flags_3d_render var visual_layer := 2

var is_available := false
var is_activated := false
var _material: StandardMaterial3D
var _light: OmniLight3D
var _overlap_scan_left := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	monitorable = false
	_create_visuals()
	_create_collision()
	body_entered.connect(_on_body_entered)
	_apply_state()


func _physics_process(delta: float) -> void:
	if not is_available or is_activated:
		return
	_overlap_scan_left -= delta
	if _overlap_scan_left > 0.0:
		return
	_overlap_scan_left = 0.08
	# Jolt can coalesce a body-entered transition when a pushed rigid body
	# leaves and re-enters an Area3D during the same integration island.  A
	# bounded overlap probe makes the return-to-plate action deterministic.
	_check_overlaps()


func set_available(value: bool) -> void:
	is_available = value
	_apply_state()
	if value:
		call_deferred("_check_overlaps")


func set_activated(value: bool) -> void:
	is_activated = value
	_apply_state()


func solve_for_test() -> void:
	if is_available and not is_activated:
		_complete()


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("archive_counterweight"):
		_complete()


func _check_overlaps() -> void:
	for body in get_overlapping_bodies():
		if body.is_in_group("archive_counterweight"):
			_complete()
			return


func _complete() -> void:
	if not is_available or is_activated:
		return
	set_activated(true)
	activated.emit(mechanism_id)


func _create_visuals() -> void:
	var plate := MeshInstance3D.new()
	plate.name = "CounterweightPlateVisual"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.05
	mesh.bottom_radius = 1.2
	mesh.height = 0.18
	mesh.radial_segments = 24
	_material = StandardMaterial3D.new()
	_material.albedo_color = Color("2c4d50")
	_material.metallic = 0.45
	_material.roughness = 0.28
	_material.emission_enabled = true
	_material.emission = Color("3de9dd")
	_material.emission_energy_multiplier = 0.35
	mesh.material = _material
	plate.mesh = mesh
	plate.position.y = 0.09
	plate.layers = visual_layer
	add_child(plate)

	_light = OmniLight3D.new()
	_light.position.y = 0.75
	_light.light_color = Color("4cfff0")
	_light.light_energy = 0.3
	_light.omni_range = 4.5
	_light.layers = visual_layer
	add_child(_light)


func _create_collision() -> void:
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 1.05
	shape.height = 0.9
	collision.shape = shape
	collision.position.y = 0.38
	add_child(collision)


func _apply_state() -> void:
	if _material == null:
		return
	if is_activated:
		_material.emission = Color("ffd17b")
		_material.emission_energy_multiplier = 3.2
		_light.light_color = Color("ffd17b")
		_light.light_energy = 2.2
	elif is_available:
		_material.emission = Color("4cfff0")
		_material.emission_energy_multiplier = 1.8
		_light.light_color = Color("4cfff0")
		_light.light_energy = 1.45
	else:
		_material.emission = Color("31575a")
		_material.emission_energy_multiplier = 0.2
		_light.light_color = Color("31575a")
		_light.light_energy = 0.16
