class_name ArchiveAnchor
extends StaticBody3D

signal activated(anchor_id: StringName)

const ECHO_VISUAL_LAYER := 1 << 1

@export var anchor_id: StringName
@export var prompt_text := "唤醒档案锚点"

var is_available := false
var is_activated := false
var _ring: MeshInstance3D
var _glyph_label: Label3D
var _core_material: StandardMaterial3D
var _light: OmniLight3D
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
		_ring.rotation.y += delta * (0.65 if is_activated else 0.35)
		_ring.position.y = 1.22 + sin(_time * 1.7) * 0.06
	if _glyph_label != null:
		_glyph_label.modulate = Color("ffd083") if is_activated else Color("62f5e8")


func can_interact(_actor: Node) -> bool:
	return is_available and not is_activated


func get_prompt(_actor: Node) -> String:
	return prompt_text


func interact(_actor: Node) -> void:
	if not is_available or is_activated:
		return
	# NarrativeDirector validates the cross-anchor cipher synchronously.  Do not
	# mark the visual as solved before that validation, otherwise a wrong-order
	# attempt would permanently disable the anchor and soft-lock the sequence.
	activated.emit(anchor_id)


func set_available(value: bool) -> void:
	is_available = value
	_apply_state()


func set_activated(value: bool) -> void:
	is_activated = value
	_apply_state()


func _create_visuals() -> void:
	var pedestal := MeshInstance3D.new()
	var pedestal_mesh := CylinderMesh.new()
	pedestal_mesh.top_radius = 0.34
	pedestal_mesh.bottom_radius = 0.52
	pedestal_mesh.height = 1.65
	pedestal_mesh.radial_segments = 12
	var stone_material := StandardMaterial3D.new()
	stone_material.albedo_color = Color("354d52")
	stone_material.roughness = 0.82
	pedestal_mesh.material = stone_material
	pedestal.mesh = pedestal_mesh
	pedestal.position.y = 0.82
	pedestal.layers = ECHO_VISUAL_LAYER
	add_child(pedestal)

	var core := MeshInstance3D.new()
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.24
	core_mesh.height = 0.48
	core_mesh.radial_segments = 16
	core_mesh.rings = 8
	_core_material = StandardMaterial3D.new()
	_core_material.albedo_color = Color("226d70")
	_core_material.emission_enabled = true
	_core_material.emission = Color("39dfdc")
	_core_material.emission_energy_multiplier = 2.0
	_core_material.roughness = 0.18
	core_mesh.material = _core_material
	core.mesh = core_mesh
	core.position.y = 1.34
	core.layers = ECHO_VISUAL_LAYER
	add_child(core)

	_ring = MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.38
	ring_mesh.outer_radius = 0.46
	ring_mesh.rings = 20
	ring_mesh.ring_segments = 8
	var ring_material := StandardMaterial3D.new()
	ring_material.albedo_color = Color("4dece3")
	ring_material.emission_enabled = true
	ring_material.emission = Color("31fff1")
	ring_material.emission_energy_multiplier = 2.8
	ring_material.roughness = 0.12
	ring_mesh.material = ring_material
	_ring.mesh = ring_mesh
	_ring.position.y = 1.22
	_ring.rotation_degrees.x = 90.0
	_ring.layers = ECHO_VISUAL_LAYER
	add_child(_ring)

	_glyph_label = Label3D.new()
	_glyph_label.name = "ArchiveGlyph"
	_glyph_label.text = _glyph_for_anchor()
	_glyph_label.font_size = 42
	_glyph_label.outline_size = 8
	_glyph_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_glyph_label.position = Vector3(0.0, 1.37, 0.0)
	_glyph_label.modulate = Color("62f5e8")
	_glyph_label.layers = ECHO_VISUAL_LAYER
	add_child(_glyph_label)

	_light = OmniLight3D.new()
	_light.light_color = Color("55fff1")
	_light.light_energy = 1.6
	_light.omni_range = 4.5
	_light.shadow_enabled = true
	_light.layers = ECHO_VISUAL_LAYER
	_light.position.y = 1.25
	add_child(_light)


func _create_collision() -> void:
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.5
	shape.height = 1.8
	collision.shape = shape
	collision.position.y = 0.9
	add_child(collision)


func _apply_state() -> void:
	if _core_material == null:
		return
	if is_activated:
		_core_material.emission = Color("ffc86a")
		_core_material.albedo_color = Color("8b6434")
		_core_material.emission_energy_multiplier = 3.4
		_light.light_color = Color("ffd083")
		_light.light_energy = 2.2
	elif is_available:
		_core_material.emission = Color("39dfdc")
		_core_material.albedo_color = Color("226d70")
		_core_material.emission_energy_multiplier = 2.4
		_light.light_color = Color("55fff1")
		_light.light_energy = 1.6
	else:
		_core_material.emission = Color("244b50")
		_core_material.albedo_color = Color("293f43")
		_core_material.emission_energy_multiplier = 0.45
		_light.light_color = Color("427f80")
		_light.light_energy = 0.28
	if _glyph_label != null:
		_glyph_label.modulate = Color("ffd083") if is_activated else Color("62f5e8")


func _glyph_for_anchor() -> String:
	match anchor_id:
		&"archive_voice":
			return "△"
		&"archive_shape":
			return "◈"
		&"archive_name":
			return "≈"
	return "◒"
