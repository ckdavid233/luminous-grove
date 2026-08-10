class_name RainRiftPortal
extends Node3D

const PRESENT_VISUAL_LAYER := 1 << 0
const ECHO_VISUAL_LAYER := 1 << 1
const SHARED_VISUAL_LAYER := 1 << 2
const PREVIEW_SIZE := Vector2i(640, 360)

var _surface_material: ShaderMaterial
var _ring := Node3D.new()
var _preview_viewport: SubViewport
var _preview_camera: Camera3D
var _source_camera: Camera3D
var _preview_layer := ECHO_VISUAL_LAYER
var _frame_index := 0
var _shutdown_requested := false
var _tearing_down := false
var preview_update_count := 0


func _exit_tree() -> void:
	_tearing_down = true
	shutdown()


func shutdown() -> void:
	if _shutdown_requested:
		return
	_shutdown_requested = true
	set_process(false)
	# Drop the ViewportTexture from the surface material before releasing the
	# SubViewport. Releasing the viewport first can leave a zero-reference
	# ViewportTexture in ObjectDB during parent teardown.
	var surface := get_node_or_null("RiftSurface") as MeshInstance3D
	if surface != null:
		surface.visible = false
		surface.material_override = null
		if surface.mesh is PrimitiveMesh:
			(surface.mesh as PrimitiveMesh).material = null
		surface.mesh = null
	if _surface_material != null:
		_surface_material.set_shader_parameter("alternate_texture", null)
		_surface_material.shader = null
		_surface_material = null
	if _preview_viewport != null and is_instance_valid(_preview_viewport):
		_preview_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		if _preview_camera != null and is_instance_valid(_preview_camera):
			_preview_camera.clear_current(false)
			_preview_camera.current = false
		_preview_viewport.world_3d = null
		if not _tearing_down:
			# Main.shutdown() runs while the portal is still in the live tree. Free
			# the preview viewport synchronously after releasing its ViewportTexture
			# so the render target cannot survive parent traversal.
			_preview_viewport.free()
	if _ring != null and is_instance_valid(_ring):
		for shard in _ring.find_children("*", "MeshInstance3D", true, false):
			var shard_mesh := shard as MeshInstance3D
			if shard_mesh.mesh is PrimitiveMesh:
				(shard_mesh.mesh as PrimitiveMesh).material = null
			shard_mesh.mesh = null
		if not _tearing_down:
			# The ring is generated at runtime and owns 28 shard nodes. Free the
			# generated subtree while Main is still live instead of leaving its
			# RefCounted mesh/material handles to parent traversal.
			_ring.free()
	if not _tearing_down:
		# Surface/light are also runtime-only children. Free the remaining portal
		# subtree synchronously after detaching its GPU resources.
		for child in get_children():
			if is_instance_valid(child):
				child.free()
	_preview_camera = null
	_source_camera = null
	_preview_viewport = null
	_ring = null


func _ready() -> void:
	name = "RainRiftPortal"
	_create_preview_viewport()
	_create_ring()
	_create_surface()
	_set_visual_layer(self, SHARED_VISUAL_LAYER)
	visible = false


func _process(delta: float) -> void:
	_ring.rotation.z += delta * 0.08
	_surface_material.set_shader_parameter(
		"pulse",
		sin(Time.get_ticks_msec() * 0.0022) * 0.5 + 0.5
	)
	_update_preview()


func configure_preview(source_camera: Camera3D, preview_layer: int) -> void:
	assert(source_camera != null, "RainRiftPortal requires a source camera")
	_source_camera = source_camera
	set_preview_layer(preview_layer)


func set_preview_layer(preview_layer: int) -> void:
	assert(
		preview_layer in [PRESENT_VISUAL_LAYER, ECHO_VISUAL_LAYER],
		"Portal previews only support the present and echo visual layers"
	)
	_preview_layer = preview_layer
	if _preview_camera != null:
		_preview_camera.cull_mask = _preview_layer


func get_preview_layer() -> int:
	return _preview_layer


func get_preview_viewport() -> SubViewport:
	return _preview_viewport


func _create_preview_viewport() -> void:
	_preview_viewport = SubViewport.new()
	_preview_viewport.name = "AlternatePhaseViewport"
	_preview_viewport.size = PREVIEW_SIZE
	_preview_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_preview_viewport.msaa_3d = Viewport.MSAA_2X
	_preview_viewport.gui_disable_input = true
	_preview_viewport.handle_input_locally = false
	add_child(_preview_viewport)
	_preview_viewport.world_3d = get_viewport().world_3d

	_preview_camera = Camera3D.new()
	_preview_camera.name = "AlternatePhaseCamera"
	_preview_camera.cull_mask = _preview_layer
	_preview_viewport.add_child(_preview_camera)
	_preview_camera.make_current()


func _create_ring() -> void:
	_ring.name = "RiftRing"
	add_child(_ring)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("62cfc7")
	material.emission_enabled = true
	material.emission = Color("3ffff0")
	material.emission_energy_multiplier = 3.6
	material.roughness = 0.18
	var shard_mesh := BoxMesh.new()
	shard_mesh.size = Vector3(0.18, 0.54, 0.16)
	shard_mesh.material = material
	for index in 28:
		var angle := TAU * float(index) / 28.0
		var shard := MeshInstance3D.new()
		shard.mesh = shard_mesh
		shard.position = Vector3(cos(angle) * 1.62, sin(angle) * 1.62, 0.0)
		shard.rotation.z = angle - PI * 0.5
		shard.rotation.y = sin(angle * 3.0) * 0.18
		shard.scale.y = 0.72 + sin(angle * 5.0) * 0.18
		_ring.add_child(shard)


func _create_surface() -> void:
	var surface := MeshInstance3D.new()
	surface.name = "RiftSurface"
	var quad := QuadMesh.new()
	quad.size = Vector2(3.0, 3.0)
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D alternate_texture : source_color, repeat_disable, filter_linear_mipmap;
uniform float pulse = 0.5;

void fragment() {
	vec2 center = UV - vec2(0.5);
	float radius = length(center);
	if (radius > 0.49) {
		discard;
	}
	float angle = atan(center.y, center.x);
	float spiral = sin(radius * 42.0 - TIME * 3.2 + angle * 4.0);
	vec2 direction = normalize(center + vec2(0.0001));
	vec2 distorted_uv = clamp(
		SCREEN_UV + direction * spiral * 0.012 * smoothstep(0.49, 0.05, radius),
		vec2(0.002),
		vec2(0.998)
	);
	vec3 behind = texture(screen_texture, distorted_uv).rgb;
	vec3 alternate = texture(alternate_texture, SCREEN_UV).rgb;
	float rim = smoothstep(0.4, 0.49, radius);
	float rain_lines = pow(abs(sin(UV.y * 92.0 + TIME * 4.0)), 18.0);
	vec3 rift_color = vec3(0.055, 0.48, 0.52) * (0.45 + pulse * 0.3);
	vec3 window_view = mix(alternate, behind * vec3(0.36, 0.68, 0.72), 0.12);
	ALBEDO = mix(window_view, rift_color, 0.12 + rim * 0.72);
	EMISSION = rift_color * (rim * 2.4 + rain_lines * 0.55);
	ALPHA = 0.96;
}
"""
	_surface_material = ShaderMaterial.new()
	_surface_material.shader = shader
	_surface_material.set_shader_parameter(
		"alternate_texture",
		_preview_viewport.get_texture()
	)
	quad.material = _surface_material
	surface.mesh = quad
	add_child(surface)

	var light := OmniLight3D.new()
	light.name = "RiftLight"
	light.light_color = Color("4ffff0")
	light.light_energy = 2.2
	light.omni_range = 7.0
	light.shadow_enabled = true
	add_child(light)


func _update_preview() -> void:
	if _preview_viewport == null:
		return
	if not visible or not is_instance_valid(_source_camera):
		_preview_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	_preview_camera.global_transform = _source_camera.global_transform
	_preview_camera.fov = _source_camera.fov

	var distance := _source_camera.global_position.distance_to(global_position)
	if distance > 28.0 or _source_camera.is_position_behind(global_position):
		_preview_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	var screen_position := _source_camera.unproject_position(global_position)
	var viewport_size := get_viewport().get_visible_rect().size
	var margin := Vector2(220.0, 220.0)
	if (
		screen_position.x < -margin.x
		or screen_position.y < -margin.y
		or screen_position.x > viewport_size.x + margin.x
		or screen_position.y > viewport_size.y + margin.y
	):
		_preview_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return

	_frame_index += 1
	var center_distance := screen_position.distance_to(viewport_size * 0.5)
	var update_interval := 1 if distance < 11.0 and center_distance < 440.0 else 4
	if _frame_index % update_interval == 0:
		_preview_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		preview_update_count += 1
	else:
		_preview_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


func _set_visual_layer(root: Node, visual_layer: int) -> void:
	var visuals: Array[Node] = []
	if root is VisualInstance3D:
		visuals.append(root)
	visuals.append_array(root.find_children("*", "VisualInstance3D", true, false))
	for node in visuals:
		(node as VisualInstance3D).layers = visual_layer
