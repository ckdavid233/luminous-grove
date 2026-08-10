class_name ObjectiveGuide
extends Control

## Lightweight screen-space navigation hint for the active narrative target.
## It never creates a world marker or physics body, so it remains cheap on the
## 4K path and cannot change interaction/collision behavior.

var _camera: Camera3D
var _target: Node3D
var _enabled := true
var _chip: PanelContainer
var _label: Label
var _pulse := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_chip = PanelContainer.new()
	_chip.name = "TargetChip"
	_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chip.custom_minimum_size = Vector2(116.0, 34.0)
	_chip.visible = false
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.025, 0.09, 0.095, 0.78)
	panel_style.border_color = Color(0.36, 0.95, 0.84, 0.72)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(7.0)
	_chip.add_theme_stylebox_override("panel", panel_style)
	add_child(_chip)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", Color("d7fff1"))
	_label.text = "目标"
	_chip.add_child(_label)


func configure(camera: Camera3D) -> void:
	_camera = camera


func set_enabled(value: bool) -> void:
	_enabled = value
	if not _enabled and _chip != null:
		_chip.visible = false


func set_target(target: Node3D) -> void:
	_target = target if is_instance_valid(target) else null
	if _chip != null and (_target == null or not _enabled):
		_chip.visible = false


func get_target() -> Node3D:
	return _target


func shutdown() -> void:
	_target = null
	_camera = null
	if _chip != null:
		_chip.visible = false


func _exit_tree() -> void:
	shutdown()


func _process(delta: float) -> void:
	if not _enabled or _target == null or not is_instance_valid(_target):
		_chip.visible = false
		return
	if _camera == null or not is_instance_valid(_camera):
		_chip.visible = false
		return
	var viewport_size := size
	if viewport_size.x < 32.0 or viewport_size.y < 32.0:
		viewport_size = get_viewport_rect().size
	var target_position := _target.global_position + Vector3.UP * 1.35
	var screen_position := _camera.unproject_position(target_position)
	var center := viewport_size * 0.5
	var edge_margin := Vector2(48.0, 42.0)
	var usable := Rect2(edge_margin, viewport_size - edge_margin * 2.0)
	var behind := _camera.is_position_behind(target_position)
	var on_screen := not behind and usable.has_point(screen_position)
	var display_position := screen_position
	if not on_screen:
		var direction := screen_position - center
		if behind or direction.length_squared() < 0.0001:
			var to_target := target_position - _camera.global_position
			var camera_right := Vector2(_camera.global_basis.x.x, _camera.global_basis.x.z)
			var camera_forward := Vector2(-_camera.global_basis.z.x, -_camera.global_basis.z.z)
			var horizontal_target := Vector2(to_target.x, to_target.z)
			direction = Vector2(horizontal_target.dot(camera_right), horizontal_target.dot(camera_forward))
		if direction.length_squared() < 0.0001:
			direction = Vector2.UP
		direction = direction.normalized()
		var half_extent := (viewport_size * 0.5) - edge_margin
		var scale_x := half_extent.x / maxf(absf(direction.x), 0.001)
		var scale_y := half_extent.y / maxf(absf(direction.y), 0.001)
		display_position = center + direction * minf(scale_x, scale_y)
	var distance := _camera.global_position.distance_to(_target.global_position)
	_label.text = "目标  %dm" % maxi(1, roundi(distance))
	_chip.size = _chip.get_combined_minimum_size()
	_chip.position = display_position - _chip.size * 0.5
	_chip.position.x = clampf(_chip.position.x, edge_margin.x, viewport_size.x - edge_margin.x - _chip.size.x)
	_chip.position.y = clampf(_chip.position.y, edge_margin.y, viewport_size.y - edge_margin.y - _chip.size.y)
	_chip.modulate.a = 0.82 + sin(_pulse) * 0.12
	_chip.visible = true
	_pulse += delta * 3.0
