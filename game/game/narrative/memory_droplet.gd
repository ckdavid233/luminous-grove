class_name MemoryDroplet
extends StaticBody3D

signal collected(memory_id: StringName)

@export var memory_id: StringName = &"rain_sound"
@export var persistent_id: StringName = &"memory_rain_sound"
@onready var visual: Node3D = %Visual
@onready var collision: CollisionShape3D = %Collision

var is_available := false
var is_collected := false
var _base_height := 0.0
var _phase := 0.0


func _ready() -> void:
	_base_height = visual.position.y
	_phase = global_position.x * 0.73 + global_position.z * 0.41
	_apply_state()


func _process(_delta: float) -> void:
	if is_available and not is_collected:
		visual.position.y = _base_height + sin(Time.get_ticks_msec() * 0.002 + _phase) * 0.12
		visual.rotation.y += 0.008


func set_available(value: bool) -> void:
	is_available = value
	if is_node_ready():
		_apply_state()


func can_interact(_actor: Node3D) -> bool:
	return is_available and not is_collected


func get_prompt(_actor: Node3D) -> String:
	return "拾起湖中记忆"


func interact(_actor: Node3D) -> void:
	if not can_interact(_actor):
		return
	is_collected = true
	collision.disabled = true
	collision_layer = 0
	var tween := create_tween()
	tween.tween_property(visual, "scale", Vector3.ONE * 1.8, 0.45).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func() -> void: visual.visible = false)
	collected.emit(memory_id)


func capture_state() -> Dictionary:
	return {"collected": is_collected}


func restore_state(state: Dictionary) -> void:
	is_collected = bool(state.get("collected", false))
	if is_node_ready():
		_apply_state()


func _apply_state() -> void:
	visual.visible = is_available and not is_collected
	collision.disabled = not is_available or is_collected
	collision_layer = 5 if is_available and not is_collected else 0
