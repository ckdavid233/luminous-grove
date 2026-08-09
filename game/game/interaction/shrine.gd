class_name Shrine
extends StaticBody3D

const PROCEDURAL_TONE := preload("res://core/audio/procedural_tone.gd")

signal activated(shrine_id: StringName)

@export var shrine_id: StringName = &"forest_shrine"
@export var persistent_id: StringName = &"forest_shrine"
@onready var core_mesh := find_child("Shrine_Core", true, false) as MeshInstance3D
@onready var core_light: OmniLight3D = %CoreLight

var is_activated := false
var is_unlocked := false
var core_material: StandardMaterial3D


func _ready() -> void:
	core_material = core_mesh.get_active_material(0).duplicate() as StandardMaterial3D
	core_mesh.material_override = core_material
	var stone_material := _create_stone_material()
	for node in find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance != core_mesh:
			mesh_instance.material_override = stone_material


func can_interact(_actor: Node3D) -> bool:
	return is_unlocked and not is_activated


func get_prompt(_actor: Node3D) -> String:
	return "唤醒林中神龛"


func interact(_actor: Node3D) -> void:
	if is_activated:
		return
	is_activated = true
	core_material.emission_enabled = true
	core_material.emission = Color("a5fff3")
	core_material.emission_energy_multiplier = 3.0
	core_light.light_energy = 2.2
	if not OS.get_cmdline_args().has("--script"):
		_play_awaken_tone()
	activated.emit(shrine_id)


func capture_state() -> Dictionary:
	return {"activated": is_activated}


func restore_state(state: Dictionary) -> void:
	is_activated = state.get("activated", false)
	if is_activated:
		core_material.emission_enabled = true
		core_material.emission = Color("a5fff3")
		core_material.emission_energy_multiplier = 3.0
		core_light.light_energy = 2.2


func _create_stone_material() -> StandardMaterial3D:
	var root := "res://content/materials/shrine_stone/"
	var material := StandardMaterial3D.new()
	material.albedo_texture = load(root + "albedo.png") as Texture2D
	material.albedo_color = Color("d8d0bd")
	material.normal_enabled = true
	material.normal_texture = load(root + "normal.png") as Texture2D
	material.normal_scale = 0.72
	material.roughness = 1.0
	material.roughness_texture = load(root + "roughness.png") as Texture2D
	material.ao_enabled = true
	material.ao_texture = load(root + "ao.png") as Texture2D
	material.ao_light_affect = 0.72
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE * 0.75
	return material


func _play_awaken_tone() -> void:
	var audio := AudioStreamPlayer3D.new()
	audio.stream = PROCEDURAL_TONE.create_chime(
		PackedFloat32Array([261.63, 392.0, 523.25, 659.25]),
		4.2,
		0.4,
		2.7
	)
	audio.max_distance = 36.0
	audio.unit_size = 5.0
	add_child(audio)
	audio.finished.connect(audio.queue_free)
	audio.play()
