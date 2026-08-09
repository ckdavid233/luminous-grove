class_name FootprintPool
extends Node3D

const MAX_FOOTPRINTS := 24
const FOOTPRINT_SIZE := Vector2(0.22, 0.42)

var _decals: Array[MeshInstance3D] = []
var _materials: Array[StandardMaterial3D] = []
var _tweens: Array[Tween] = []
var _cursor := 0
var _footprint_texture: ImageTexture
var _shutdown_requested := false
var _tearing_down := false


func _ready() -> void:
	_footprint_texture = _create_footprint_texture()
	for index in MAX_FOOTPRINTS:
		var footprint := MeshInstance3D.new()
		footprint.name = "Footprint_%02d" % index
		var mesh := QuadMesh.new()
		mesh.size = FOOTPRINT_SIZE
		var material := StandardMaterial3D.new()
		# Alpha blend keeps the procedural sole edge smooth on wet ground. The
		# previous alpha-hash mode produced visible Bayer stippling in close-ups.
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		material.albedo_texture = _footprint_texture
		material.albedo_color = Color(0.18, 0.12, 0.08, 0.0)
		material.roughness = 0.72
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh.material = material
		footprint.mesh = mesh
		footprint.visible = false
		footprint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(footprint)
		_decals.append(footprint)
		_materials.append(material)


func _exit_tree() -> void:
	_tearing_down = true
	shutdown()


func shutdown() -> void:
	if _shutdown_requested:
		return
	_shutdown_requested = true
	set_process(false)
	for tween in _tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_tweens.clear()
	if _tearing_down:
		_decals.clear()
		_materials.clear()
		_footprint_texture = null
		return
	for footprint in _decals:
		if is_instance_valid(footprint):
			footprint.visible = false
			footprint.mesh = null
			footprint.free()
	_decals.clear()
	_materials.clear()
	_cursor = 0
	_footprint_texture = null


func stamp(world_position: Vector3, normal: Vector3, surface_type: StringName, strength := 1.0) -> void:
	if _decals.is_empty():
		return
	var footprint := _decals[_cursor]
	var material := _materials[_cursor]
	_cursor = (_cursor + 1) % _decals.size()
	# Keep the imprint readable against the scanned forest floor while still
	# letting the albedo/normal detail show through the alpha texture.
	var color := Color(0.24, 0.14, 0.065, 0.82)
	if surface_type == &"wet_mud":
		color = Color(0.075, 0.052, 0.03, 0.9)
	elif surface_type == &"moss":
		color = Color(0.14, 0.2, 0.1, 0.62)
	material.albedo_color = Color(color.r, color.g, color.b, color.a * clampf(strength, 0.35, 1.0))
	footprint.global_position = world_position + normal.normalized() * 0.018
	var up_axis := Vector3.FORWARD if absf(normal.normalized().dot(Vector3.UP)) > 0.96 else Vector3.UP
	footprint.global_basis = Basis.looking_at(-normal.normalized(), up_axis)
	footprint.visible = true
	var tween := footprint.create_tween()
	_tweens.append(tween)
	tween.tween_interval(3.0)
	tween.tween_property(material, "albedo_color:a", 0.0, 2.4)
	tween.tween_callback(_on_footprint_tween_finished.bind(footprint))


func _on_footprint_tween_finished(footprint: MeshInstance3D) -> void:
	if is_instance_valid(footprint):
		footprint.visible = false


func active_count() -> int:
	var count := 0
	for footprint in _decals:
		if footprint.visible:
			count += 1
	return count


func _create_footprint_texture() -> ImageTexture:
	var image := Image.create(96, 160, false, Image.FORMAT_RGBA8)
	for y in image.get_height():
		for x in image.get_width():
			var normalized := Vector2(
				(float(x) + 0.5) / float(image.get_width()) * 2.0 - 1.0,
				(float(y) + 0.5) / float(image.get_height()) * 2.0 - 1.0,
			)
			# A small union of toe, bridge and heel lobes reads as a shoe sole
			# instead of a generic oval, while remaining inexpensive to generate.
			var toe := _footprint_lobe(normalized, Vector2(0.0, 0.42), Vector2(0.7, 0.52))
			var bridge := _footprint_lobe(normalized, Vector2(0.0, -0.02), Vector2(0.32, 0.5))
			var heel := _footprint_lobe(normalized, Vector2(0.0, -0.55), Vector2(0.48, 0.35))
			var alpha := maxf(maxf(toe, bridge), heel)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(image)


func _footprint_lobe(point: Vector2, center: Vector2, radius: Vector2) -> float:
	var distance := (point - center) / radius
	var ellipse := distance.x * distance.x + distance.y * distance.y
	return clampf(1.0 - smoothstep(0.68, 1.0, ellipse), 0.0, 1.0)
