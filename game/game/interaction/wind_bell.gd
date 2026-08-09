class_name WindBell
extends StaticBody3D

const PROCEDURAL_TONE := preload("res://core/audio/procedural_tone.gd")

signal rung(bell_id: StringName)

@export var bell_id: StringName = &"grove_wind_bell"
@export var persistent_id: StringName = &"grove_wind_bell"
@onready var bell_visual: Node3D = %BellVisual
@onready var glow_material: StandardMaterial3D = %Glow.material_override

var is_rung := false


func can_interact(_actor: Node3D) -> bool:
	return not is_rung


func get_prompt(_actor: Node3D) -> String:
	return "奏响风铃"


func interact(_actor: Node3D) -> void:
	if is_rung:
		return
	is_rung = true
	_apply_rung_visual()
	_animate_bell()
	if not OS.get_cmdline_args().has("--script"):
		_play_chime()
	rung.emit(bell_id)


func capture_state() -> Dictionary:
	return {"rung": is_rung}


func restore_state(state: Dictionary) -> void:
	is_rung = state.get("rung", false)
	if is_rung:
		_apply_rung_visual()


func _apply_rung_visual() -> void:
	glow_material.emission_enabled = true
	glow_material.emission = Color("84ffe4")
	glow_material.emission_energy_multiplier = 2.4


func _animate_bell() -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	for angle in [0.22, -0.18, 0.12, -0.07, 0.0]:
		tween.tween_property(bell_visual, "rotation:z", angle, 0.16)


func _play_chime() -> void:
	var audio := AudioStreamPlayer3D.new()
	audio.stream = PROCEDURAL_TONE.create_chime(
		PackedFloat32Array([783.99, 1174.66, 1567.98]),
		2.8,
		0.46,
		5.1
	)
	audio.max_distance = 28.0
	audio.unit_size = 4.0
	add_child(audio)
	audio.finished.connect(audio.queue_free)
	audio.play()
