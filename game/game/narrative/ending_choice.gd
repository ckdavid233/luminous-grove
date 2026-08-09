class_name EndingChoice
extends StaticBody3D

signal selected(choice_id: StringName)

@export var choice_id: StringName = &"return_to_lake"
@export var prompt_text := "将记忆归还湖水"
@export var persistent_id: StringName = &"ending_return_to_lake"
@onready var visual: Node3D = %Visual
@onready var orb: MeshInstance3D = %Orb
@onready var light: OmniLight3D = %Light
@onready var collision: CollisionShape3D = %Collision

var is_available := false
var is_selected := false
var _base_height := 0.0


func _ready() -> void:
	_base_height = orb.position.y
	var orb_material := orb.get_active_material(0).duplicate() as StandardMaterial3D
	var color := Color("ffd9a3")
	match choice_id:
		&"return_to_lake", &"merge_worlds":
			color = Color("84ffe4")
		&"tidal_order":
			color = Color("c79dff")
	orb_material.albedo_color = color
	orb_material.emission = color
	orb.material_override = orb_material
	light.light_color = color
	_apply_state()


func _process(_delta: float) -> void:
	if is_available and not is_selected:
		orb.position.y = _base_height + sin(Time.get_ticks_msec() * 0.0017) * 0.1
		visual.rotation.y += 0.004


func set_available(value: bool) -> void:
	is_available = value
	if is_node_ready():
		_apply_state()


func set_selected(value: bool) -> void:
	is_selected = value
	if is_node_ready():
		_apply_state()


func can_interact(_actor: Node3D) -> bool:
	return is_available and not is_selected


func get_prompt(_actor: Node3D) -> String:
	return prompt_text


func interact(_actor: Node3D) -> void:
	if not can_interact(_actor):
		return
	is_selected = true
	_apply_state()
	selected.emit(choice_id)


func capture_state() -> Dictionary:
	return {"selected": is_selected}


func restore_state(state: Dictionary) -> void:
	is_selected = bool(state.get("selected", false))
	if is_node_ready():
		_apply_state()


func _apply_state() -> void:
	visual.visible = is_available and not is_selected
	collision.disabled = not is_available or is_selected
	collision_layer = 5 if is_available and not is_selected else 0
