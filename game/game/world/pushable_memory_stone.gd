class_name PushableMemoryStone
extends RigidBody3D

@export var prompt_text := "推动记忆石"
@export var push_impulse := 24.0

var _cooldown := 0.0


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("archive_counterweight")
	collision_layer = 1 | (1 << 2)
	collision_mask = 1 | (1 << 1)
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 4


func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)


func can_interact(_actor: Node) -> bool:
	return _cooldown <= 0.0


func get_prompt(_actor: Node) -> String:
	return prompt_text


func interact(actor: Node3D) -> void:
	if _cooldown > 0.0:
		return
	var direction := global_position - actor.global_position
	direction.y = 0.0
	if direction.length_squared() < 0.01:
		direction = -actor.global_basis.z
	apply_central_impulse(direction.normalized() * push_impulse + Vector3.UP * 1.25)
	_cooldown = 0.35
