class_name ArchiveCipherConsole
extends StaticBody3D

signal cipher_solved(code: Array[int])
signal cipher_rejected(attempt: Array[int], clue: String)
signal cipher_progress_changed(states: Array[int], active_slot: int)

const SYMBOL_COUNT := 5
const SYMBOL_COLORS := [
	Color("5de5d9"),
	Color("6cb8ff"),
	Color("d2a1ff"),
	Color("ffd37a"),
	Color("ff8f9e"),
]
const DEFAULT_PUZZLE_CLUE := "三枚锚点留下三种印记；每一环只能顺时针校准。"

@export var prompt_text := "校准沉雨档案的三重符文"
@export var solution: Array[int] = [2, 4, 1]
@export var require_final_lock := false
@export_flags_3d_render var visual_layer := 1

var is_available := false
var is_solved := false
var _states: Array[int] = [0, 0, 0]
var _active_slot := 0
var _rings: Array[MeshInstance3D] = []
var _ring_materials: Array[StandardMaterial3D] = []
var _slot_labels: Array[Label3D] = []
var _status_label: Label3D
var _lock_ring: MeshInstance3D
var _lock_label: Label3D
var _light: OmniLight3D
var _collision: CollisionShape3D
var _time := 0.0
var _pulse := 0.0
var _clue_text := DEFAULT_PUZZLE_CLUE
var _focused_actor: Node
var _lock_active := false
var _lock_value := 0
var _lock_target := 2


func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 1 << 2
	collision_mask = 1
	_create_visuals()
	_create_collision()
	_apply_state()


func _process(delta: float) -> void:
	_time += delta
	_pulse = maxf(0.0, _pulse - delta)
	for index in _rings.size():
		var ring := _rings[index]
		if ring == null:
			continue
		var target_angle := float(_states[index]) / float(SYMBOL_COUNT) * TAU
		ring.rotation.y = lerp_angle(ring.rotation.y, target_angle + _time * 0.12, minf(1.0, delta * 8.0))
		ring.position.y = 1.12 + sin(_time * 1.7 + index * 0.7) * 0.035
		if index == _active_slot and is_available and not is_solved:
			ring.scale = Vector3.ONE * (1.0 + sin(_time * 5.0) * 0.035 + _pulse * 0.18)
		else:
			ring.scale = Vector3.ONE
	if _lock_ring != null:
		_lock_ring.rotation.y = lerp_angle(
			_lock_ring.rotation.y,
			float(_lock_value) / float(SYMBOL_COUNT) * TAU + _time * 0.18,
			minf(1.0, delta * 8.0),
		)
		_lock_ring.scale = Vector3.ONE * (1.0 + sin(_time * 4.0) * 0.025) if _lock_active else Vector3.ONE
	if _lock_label != null:
		_lock_label.text = _glyph_text(_lock_value)
		_lock_label.modulate = Color("ffd37a") if _lock_active else Color("6f8f91")
	for index in _slot_labels.size():
		_slot_labels[index].text = _glyph_text(_states[index])
		_slot_labels[index].modulate = SYMBOL_COLORS[_states[index]]
	if _status_label != null:
		_status_label.text = (
			"封印轮  %s / 余数 %d" % [_glyph_text(_lock_value), _lock_target]
			if _lock_active
			else "档案校准  %s" % _state_text()
		)
		_status_label.modulate = Color("ffe4a2") if _pulse > 0.0 else Color("b5fff3")


func _unhandled_input(event: InputEvent) -> void:
	if not is_available or is_solved or _focused_actor == null or not is_instance_valid(_focused_actor):
		return
	if not event.is_action_pressed("puzzle_rotate"):
		return
	if _focused_actor is Node3D and global_position.distance_to((_focused_actor as Node3D).global_position) > 4.5:
		_focused_actor = null
		return
	rotate_puzzle()


func can_interact(_actor: Node) -> bool:
	return is_available and not is_solved


func get_prompt(_actor: Node) -> String:
	if is_solved:
		return "三重符文已校准"
	if not is_available:
		return prompt_text
	if _lock_active:
		return "R 转动内层封印 · E 释放\n提示：三环步数之和除以五取余"
	return "R 转动第 %d 环 · E 确认 %s\n线索：%s" % [_active_slot + 1, _state_text(), _clue_text]


func interact(_actor: Node) -> void:
	if not can_interact(_actor):
		return
	_focused_actor = _actor
	if _lock_active:
		_pulse = 0.24
		if _lock_value == _lock_target:
			_lock_active = false
			is_solved = true
			is_available = false
			_active_slot = solution.size()
			_apply_state()
			cipher_solved.emit(_states.duplicate())
		else:
			cipher_rejected.emit([_lock_value], "封印轮拒绝：先求三环步数之和的五进制余数")
			_lock_value = 0
			_apply_state()
		return
	if _active_slot >= solution.size():
		return
	_pulse = 0.22
	if _states[_active_slot] == solution[_active_slot]:
		_active_slot += 1
		if _active_slot >= solution.size():
			if require_final_lock:
				_lock_active = true
				_lock_value = 0
				cipher_progress_changed.emit(_states.duplicate(), -1)
			else:
				is_solved = true
				is_available = false
				_apply_state()
				cipher_solved.emit(_states.duplicate())
		else:
			cipher_progress_changed.emit(_states.duplicate(), _active_slot)
	else:
		var attempt := _states.duplicate()
		_states = [0, 0, 0]
		_active_slot = 0
		_focused_actor = null
		cipher_rejected.emit(attempt, _clue_text)
	_apply_state()


func rotate_puzzle() -> void:
	if not is_available or is_solved:
		return
	if _lock_active:
		_lock_value = (_lock_value + 1) % SYMBOL_COUNT
		_pulse = 0.16
		cipher_progress_changed.emit(_states.duplicate(), -1)
		return
	if _active_slot >= solution.size():
		return
	_states[_active_slot] = (_states[_active_slot] + 1) % SYMBOL_COUNT
	_pulse = 0.16
	cipher_progress_changed.emit(_states.duplicate(), _active_slot)


func set_solution(value: Array[int]) -> void:
	if value.size() >= 3:
		solution = [
			posmod(value[0], SYMBOL_COUNT),
			posmod(value[1], SYMBOL_COUNT),
			posmod(value[2], SYMBOL_COUNT),
		]
		_lock_target = posmod(solution[0] + solution[1] + solution[2], SYMBOL_COUNT)


func set_clue(value: String) -> void:
	_clue_text = value if not value.strip_edges().is_empty() else DEFAULT_PUZZLE_CLUE


func set_available(value: bool) -> void:
	is_available = value and not is_solved
	_apply_state()


func set_solved(value: bool) -> void:
	is_solved = value
	_lock_active = false
	if value:
		_states = solution.duplicate()
		_active_slot = solution.size()
	_apply_state()


func reset_puzzle() -> void:
	is_solved = false
	_lock_active = false
	_lock_value = 0
	_states = [0, 0, 0]
	_active_slot = 0
	_apply_state()


func get_states() -> Array[int]:
	return _states.duplicate()


func get_clue() -> String:
	return _clue_text


func _glyph_text(value: int) -> String:
	return ["◒", "≈", "△", "✦", "◈"][clampi(value, 0, SYMBOL_COUNT - 1)]


func _state_text() -> String:
	var result := ""
	for value in _states:
		result += _glyph_text(value)
	return result


func _create_visuals() -> void:
	var pedestal := MeshInstance3D.new()
	var pedestal_mesh := CylinderMesh.new()
	pedestal_mesh.top_radius = 0.72
	pedestal_mesh.bottom_radius = 0.96
	pedestal_mesh.height = 0.72
	pedestal_mesh.radial_segments = 32
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color("142f35")
	stone.metallic = 0.48
	stone.roughness = 0.3
	pedestal_mesh.material = stone
	pedestal.mesh = pedestal_mesh
	pedestal.position.y = 0.36
	pedestal.layers = visual_layer
	add_child(pedestal)

	for index in 3:
		var ring := MeshInstance3D.new()
		ring.name = "CipherRing_%d" % (index + 1)
		var ring_mesh := TorusMesh.new()
		ring_mesh.inner_radius = 0.47 + index * 0.1
		ring_mesh.outer_radius = 0.55 + index * 0.1
		ring_mesh.rings = 40
		ring_mesh.ring_segments = 12
		var ring_material := StandardMaterial3D.new()
		ring_material.albedo_color = SYMBOL_COLORS[index]
		ring_material.emission_enabled = true
		ring_material.emission = SYMBOL_COLORS[index]
		ring_material.emission_energy_multiplier = 2.8
		ring_material.metallic = 0.58
		ring_material.roughness = 0.12
		ring_mesh.material = ring_material
		ring.mesh = ring_mesh
		ring.position = Vector3(0.0, 1.12, 0.0)
		ring.rotation_degrees.x = 90.0
		ring.layers = visual_layer
		add_child(ring)
		_rings.append(ring)
		_ring_materials.append(ring_material)

		var label := Label3D.new()
		label.name = "CipherGlyph_%d" % (index + 1)
		label.text = _glyph_text(0)
		label.font_size = 48
		label.outline_size = 10
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = Vector3(0.0, 1.12 + index * 0.012, 0.0)
		label.modulate = SYMBOL_COLORS[index]
		label.layers = visual_layer
		add_child(label)
		_slot_labels.append(label)

	_status_label = Label3D.new()
	_status_label.name = "CipherStatus"
	_status_label.text = "档案校准  ◒◒◒"
	_status_label.font_size = 22
	_status_label.outline_size = 8
	_status_label.position = Vector3(0.0, 2.1, 0.0)
	_status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_status_label.layers = visual_layer
	add_child(_status_label)

	_lock_ring = MeshInstance3D.new()
	_lock_ring.name = "CipherLockRing"
	var lock_mesh := TorusMesh.new()
	lock_mesh.inner_radius = 0.18
	lock_mesh.outer_radius = 0.25
	lock_mesh.rings = 32
	lock_mesh.ring_segments = 10
	var lock_material := StandardMaterial3D.new()
	lock_material.albedo_color = Color("ffd37a")
	lock_material.emission_enabled = true
	lock_material.emission = Color("ffc66e")
	lock_material.emission_energy_multiplier = 1.8
	lock_material.roughness = 0.16
	lock_mesh.material = lock_material
	_lock_ring.mesh = lock_mesh
	_lock_ring.position = Vector3(0.0, 1.12, 0.0)
	_lock_ring.rotation_degrees.x = 90.0
	_lock_ring.layers = visual_layer
	add_child(_lock_ring)
	_lock_label = Label3D.new()
	_lock_label.name = "CipherLockGlyph"
	_lock_label.text = _glyph_text(0)
	_lock_label.font_size = 28
	_lock_label.outline_size = 6
	_lock_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_lock_label.position = Vector3(0.0, 1.12, 0.0)
	_lock_label.modulate = Color("6f8f91")
	_lock_label.layers = visual_layer
	add_child(_lock_label)

	_light = OmniLight3D.new()
	_light.name = "CipherLight"
	_light.position.y = 1.3
	_light.light_color = Color("5de5d9")
	_light.light_energy = 3.2
	_light.omni_range = 6.5
	_light.shadow_enabled = true
	_light.layers = visual_layer
	add_child(_light)


func _create_collision() -> void:
	_collision = CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.92
	shape.height = 2.2
	_collision.shape = shape
	_collision.position.y = 1.05
	add_child(_collision)


func _apply_state() -> void:
	if _collision == null:
		return
	_collision.disabled = not is_available or is_solved
	collision_layer = (1 << 2) if is_available and not is_solved else 0
	var color := Color("ffd17b") if is_solved else Color("5de5d9")
	if _light != null:
		_light.light_color = color
		_light.light_energy = 4.8 if is_solved else (3.8 if is_available else 0.26)
	for material in _ring_materials:
		material.emission = color
		material.emission_energy_multiplier = 4.8 if is_solved else (3.3 if is_available else 0.35)
