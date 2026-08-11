class_name InteractiveLake
extends MeshInstance3D

signal ripple_created(world_position: Vector3, source: StringName)
signal splash_created(world_position: Vector3, strength: float, source: StringName)
signal surface_event(world_position: Vector3, velocity: Vector3, radius: float, source: StringName)

const MAX_RIPPLES := 32
const SPLASH_POOL_SIZE := 16
const HALF_SIZE := Vector2(7.35, 4.85)

@export var rain_ripple_interval := Vector2(0.5, 1.15)
@export var footstep_distance := 0.34
@export var surface_contact_margin := 0.14
@export var maximum_wading_depth := 1.1
@export var visual_effects_enabled := true
@export var visual_effects_auto_cleanup := true
@export_range(0.0, 1.0, 0.01) var rain_intensity := 0.68
@export_range(0.0, 2.0, 0.01) var shallow_buoyancy_strength := 1.06
@export_range(0.0, 8.0, 0.1) var shallow_water_drag := 2.8
@export var rigid_body_probe_radius := 0.55

var _actor: CharacterBody3D
var _material: ShaderMaterial
var _origins := PackedVector2Array()
var _start_times := PackedFloat32Array()
var _strengths := PackedFloat32Array()
var _radii := PackedFloat32Array()
var _next_ripple_slot := 0
var _rain_time_left := 0.25
var _last_actor_position := Vector3.INF
var _actor_distance_accumulator := 0.0
var _rng := RandomNumberGenerator.new()
var _elapsed_time := 0.0
var _was_touching_surface := false
var _splash_count := 0
var _splash_pool: Array[Node3D] = []
var _active_splash_roots: Array[Node3D] = []
var _splash_tweens: Array[Tween] = []
var _registered_bodies: Array[RigidBody3D] = []
var _body_water_state: Dictionary = {}
var _shutdown_requested := false
var _tearing_down := false


func _ready() -> void:
	_rng.seed = 0x51A5A
	_material = get_active_material(0).duplicate() as ShaderMaterial
	material_override = _material
	_origins.resize(MAX_RIPPLES)
	_start_times.resize(MAX_RIPPLES)
	_strengths.resize(MAX_RIPPLES)
	_radii.resize(MAX_RIPPLES)
	for index in MAX_RIPPLES:
		_origins[index] = Vector2.ZERO
		_start_times[index] = -1000.0
		_strengths[index] = 0.0
		_radii[index] = 1.0
	_upload_ripples()


func _exit_tree() -> void:
	_tearing_down = true
	shutdown()


func shutdown() -> void:
	if _shutdown_requested:
		return
	_shutdown_requested = true
	set_process(false)
	# Splash roots are owned by this lake. During parent teardown we detach their
	# GPU resources but leave node removal to Godot's normal child traversal;
	# during runtime shutdown it is safe to free the pooled roots immediately.
	for effect_root in _splash_pool + _active_splash_roots:
		if not is_instance_valid(effect_root):
			continue
		_clear_splash_root(effect_root, not _tearing_down)
		if not _tearing_down:
			effect_root.queue_free()
	_splash_pool.clear()
	_active_splash_roots.clear()
	for tween in _splash_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_splash_tweens.clear()
	_registered_bodies.clear()
	_body_water_state.clear()
	_actor = null
	_rng = null
	_material = null
	material_override = null
	mesh = null


func _process(delta: float) -> void:
	_elapsed_time += delta
	_material.set_shader_parameter("interaction_time", _elapsed_time)
	_rain_time_left -= delta
	if _rain_time_left <= 0.0:
		var local_point := Vector3(
			_rng.randf_range(-HALF_SIZE.x, HALF_SIZE.x),
			0.0,
			_rng.randf_range(-HALF_SIZE.y, HALF_SIZE.y)
		)
		emit_surface_event(to_global(local_point), Vector3.DOWN, 0.24, &"droplet")
		var rain_scale := lerpf(1.55, 0.58, rain_intensity)
		_rain_time_left = _rng.randf_range(rain_ripple_interval.x, rain_ripple_interval.y) * rain_scale
	_update_actor_ripples()
	_update_rigid_body_feedback(delta)


func set_actor(actor: CharacterBody3D) -> void:
	_actor = actor
	_last_actor_position = actor.global_position
	_actor_distance_accumulator = 0.0
	_was_touching_surface = _is_actor_touching_surface(actor.global_position)


func register_rigid_body(body: RigidBody3D) -> void:
	if body == null or _registered_bodies.has(body):
		return
	_registered_bodies.append(body)
	_body_water_state[body.get_instance_id()] = false


func unregister_rigid_body(body: RigidBody3D) -> void:
	if body == null:
		return
	_registered_bodies.erase(body)
	_body_water_state.erase(body.get_instance_id())


func set_rain_intensity(value: float) -> void:
	rain_intensity = clampf(value, 0.0, 1.0)


func set_visual_quality_profile(profile: StringName) -> void:
	if _material == null:
		return
	match profile:
		&"performance":
			_material.set_shader_parameter("micro_normal_strength", 0.14)
			_material.set_shader_parameter("foam_intensity", 0.78)
			visual_effects_enabled = false
		&"balanced":
			_material.set_shader_parameter("micro_normal_strength", 0.22)
			_material.set_shader_parameter("foam_intensity", 0.98)
			visual_effects_enabled = true
		_:
			_material.set_shader_parameter("micro_normal_strength", 0.24)
			_material.set_shader_parameter("foam_intensity", 1.1)
			_material.set_shader_parameter("reflection_strength", 0.88)
			_material.set_shader_parameter("sparkle_intensity", 0.92)
			_material.set_shader_parameter("caustic_intensity", 0.38)
			visual_effects_enabled = true


func emit_surface_event(
	position: Vector3,
	velocity: Vector3,
	radius: float,
	source: StringName = &"scripted",
) -> void:
	var event_local := to_local(position)
	var event_normalized := Vector2(
		event_local.x / HALF_SIZE.x,
		event_local.z / HALF_SIZE.y,
	)
	if event_normalized.length_squared() > 1.18:
		return
	var strength := clampf(0.42 + velocity.length() * 0.09 + radius * 0.36, 0.18, 1.45)
	add_ripple(position, source, strength, radius)
	surface_event.emit(position, velocity, radius, source)
	if source in [&"water_entry", &"water_exit", &"landing"]:
		_create_surface_splash(position, strength, source)
	elif source == &"rigid_body":
		_create_surface_splash(position, strength * 0.72, source)


func add_ripple(
	position: Vector3,
	source: StringName = &"scripted",
	strength: float = 0.72,
	radius: float = 1.0,
) -> void:
	if _material == null:
		return
	var local_position := to_local(position)
	if not _is_inside_horizontal(local_position):
		return
	_origins[_next_ripple_slot] = Vector2(position.x, position.z)
	_start_times[_next_ripple_slot] = _elapsed_time
	_strengths[_next_ripple_slot] = clampf(strength, 0.0, 1.5)
	_radii[_next_ripple_slot] = clampf(radius, 0.2, 1.8)
	_next_ripple_slot = (_next_ripple_slot + 1) % MAX_RIPPLES
	_upload_ripples()
	ripple_created.emit(position, source)


func active_ripple_count(current_time: float = -1.0) -> int:
	if current_time < 0.0:
		current_time = _elapsed_time
	var count := 0
	for start_time in _start_times:
		if current_time + 0.0001 >= start_time and current_time - start_time <= 4.8:
			count += 1
	return count


func splash_count() -> int:
	return _splash_count


func _update_actor_ripples() -> void:
	if _actor == null or not is_instance_valid(_actor):
		return
	var actor_position := _actor.global_position
	var local_position := to_local(actor_position)
	var inside := _is_inside_horizontal(local_position)
	var touching_surface := _is_actor_touching_surface(actor_position)
	if touching_surface != _was_touching_surface:
		var source := &"water_entry" if touching_surface else &"water_exit"
		var vertical_speed := absf(_actor.velocity.y)
		var strength := clampf(0.55 + vertical_speed * 0.12, 0.55, 1.35)
		emit_surface_event(
			Vector3(actor_position.x, global_position.y, actor_position.z),
			Vector3(0.0, _actor.velocity.y, 0.0),
			strength,
			source,
		)
	_was_touching_surface = touching_surface
	if not inside or not touching_surface or absf(_actor.velocity.y) > 0.8:
		_last_actor_position = actor_position
		_actor_distance_accumulator = 0.0
		return

	if _last_actor_position != Vector3.INF:
		_actor_distance_accumulator += Vector2(
			actor_position.x - _last_actor_position.x,
			actor_position.z - _last_actor_position.z
		).length()
	if _actor_distance_accumulator >= footstep_distance:
		var surface_position := Vector3(actor_position.x, global_position.y, actor_position.z)
		emit_surface_event(surface_position, _actor.velocity, 0.42, &"footstep")
		_actor_distance_accumulator = 0.0
	_last_actor_position = actor_position


func _update_rigid_body_feedback(delta: float) -> void:
	for candidate in get_tree().get_nodes_in_group("water_feedback_body"):
		if candidate is RigidBody3D:
			register_rigid_body(candidate as RigidBody3D)
	for index in range(_registered_bodies.size() - 1, -1, -1):
		var body := _registered_bodies[index]
		if not is_instance_valid(body):
			_registered_bodies.remove_at(index)
			continue
		var local_position := to_local(body.global_position)
		var inside := _is_inside_horizontal(local_position)
		var submerged := clampf(
			(global_position.y + rigid_body_probe_radius - body.global_position.y)
			/ (rigid_body_probe_radius * 2.0),
			0.0,
			1.0,
		)
		var touching := inside and submerged > 0.02
		var body_id := body.get_instance_id()
		var previously_touching: bool = _body_water_state.get(body_id, false)
		if touching:
			body.apply_central_force(
				Vector3.UP
					* body.mass
					* ProjectSettings.get_setting("physics/3d/default_gravity")
					* shallow_buoyancy_strength
					* submerged
			)
			var horizontal_velocity := Vector3(body.linear_velocity.x, 0.0, body.linear_velocity.z)
			var damped_horizontal := horizontal_velocity.move_toward(
				Vector3.ZERO,
				shallow_water_drag * submerged * delta,
			)
			body.linear_velocity.x = damped_horizontal.x
			body.linear_velocity.z = damped_horizontal.z
		if touching != previously_touching:
			var source: StringName = &"rigid_body"
			emit_surface_event(
				_surface_event_position(local_position),
				body.linear_velocity,
				rigid_body_probe_radius,
				source,
			)
		_body_water_state[body_id] = touching


func _surface_event_position(local_position: Vector3) -> Vector3:
	var normalized := Vector2(
		local_position.x / HALF_SIZE.x,
		local_position.z / HALF_SIZE.y,
	)
	if normalized.length_squared() > 1.0:
		normalized = normalized.normalized() * 0.96
	return to_global(
		Vector3(
			normalized.x * HALF_SIZE.x,
			0.0,
			normalized.y * HALF_SIZE.y,
		)
	)


func _is_inside_horizontal(local_position: Vector3) -> bool:
	var normalized := Vector2(
		local_position.x / HALF_SIZE.x,
		local_position.z / HALF_SIZE.y,
	)
	return normalized.length_squared() <= 1.0


func _is_actor_touching_surface(actor_position: Vector3) -> bool:
	var local_position := to_local(actor_position)
	if not _is_inside_horizontal(local_position):
		return false
	var surface_offset := actor_position.y - global_position.y
	return (
		surface_offset <= surface_contact_margin
		and surface_offset >= -maximum_wading_depth
	)


func _create_surface_splash(
	position: Vector3,
	strength: float,
	source: StringName,
) -> void:
	_splash_count += 1
	splash_created.emit(position, strength, source)
	if not visual_effects_enabled:
		return

	var effect_root := _obtain_splash_root()
	# Keep pooled rings above the animated Gerstner crest. At the old 0.1 m
	# offset the water depth pass could hide the splash completely.
	effect_root.global_position = position + Vector3.UP * 0.16

	# A soft foam sheet sits under the physical rings.  The procedural edge
	# noise prevents the splash from reading as four perfect neon toruses and
	# gives the camera a readable contact patch even when droplets are between
	# frames.
	var foam := MeshInstance3D.new()
	foam.name = "SplashFoam"
	var foam_mesh := QuadMesh.new()
	foam_mesh.size = Vector2(2.0, 2.0)
	var foam_shader := Shader.new()
	foam_shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec3 tint : source_color = vec3(0.52, 0.91, 0.86);
uniform float opacity = 0.7;
uniform float seed = 0.0;

float hash21(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7)) + seed) * 43758.5453);
}

void fragment() {
	vec2 centered = UV * 2.0 - 1.0;
	float radial = length(centered);
	float ring = exp(-pow((radial - 0.56) * 8.0, 2.0));
	float inner = exp(-pow((radial - 0.82) * 12.0, 2.0)) * 0.62;
	float breakup = 0.78 + 0.22 * sin(UV.x * 17.0 + sin(UV.y * 13.0 + seed));
	float outer_fade = 1.0 - smoothstep(0.76, 1.0, radial);
	float mask = (ring + inner) * outer_fade * breakup;
	ALBEDO = tint;
	ALPHA = clamp(mask * opacity, 0.0, 0.82);
}
"""
	var foam_material := ShaderMaterial.new()
	foam_material.shader = foam_shader
	foam_material.set_shader_parameter("opacity", 0.28 * clampf(strength, 0.35, 1.4))
	foam_material.set_shader_parameter("seed", randf() * 20.0)
	foam_mesh.material = foam_material
	foam.mesh = foam_mesh
	foam.rotation.x = -PI * 0.5
	foam.scale = Vector3.ONE * (0.58 + strength * 0.24)
	effect_root.add_child(foam)

	var rings: Array[MeshInstance3D] = []
	var ring_materials: Array[StandardMaterial3D] = []
	for ring_index in 4:
		var ring := MeshInstance3D.new()
		ring.name = "SplashRing_%d" % (ring_index + 1)
		var ring_mesh := TorusMesh.new()
		ring_mesh.inner_radius = 0.32 + ring_index * 0.16
		ring_mesh.outer_radius = 0.375 + ring_index * 0.16
		ring_mesh.rings = 42
		ring_mesh.ring_segments = 14
		var ring_material := StandardMaterial3D.new()
		ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring_material.albedo_color = Color(
			0.43,
			0.86,
			0.83,
			0.48 - ring_index * 0.085,
		)
		ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		ring_material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
		ring_material.roughness = 0.18 + ring_index * 0.06
		ring_material.no_depth_test = false
		ring_material.emission_enabled = true
		ring_material.emission = Color(0.2, 0.72, 0.68)
		ring_material.emission_energy_multiplier = 0.24
		ring_mesh.material = ring_material
		ring.mesh = ring_mesh
		ring.scale = Vector3(0.18 + ring_index * 0.024, 0.18 + ring_index * 0.024, 0.31 + ring_index * 0.055)
		ring.rotation.y = randf_range(-0.18, 0.18)
		effect_root.add_child(ring)
		rings.append(ring)
		ring_materials.append(ring_material)

	var particles := GPUParticles3D.new()
	particles.name = "SplashDroplets"
	particles.one_shot = true
	particles.amount = maxi(28, int(54.0 * strength))
	particles.lifetime = 0.92
	particles.explosiveness = 0.95
	particles.randomness = 0.42
	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_material.emission_sphere_radius = 0.2 * strength
	process_material.direction = Vector3.UP
	process_material.spread = 68.0
	process_material.gravity = Vector3(0.0, -9.8, 0.0)
	process_material.initial_velocity_min = 1.2 * strength
	process_material.initial_velocity_max = 2.8 * strength
	process_material.scale_min = 0.26
	process_material.scale_max = 0.82
	particles.process_material = process_material
	var droplet_mesh := SphereMesh.new()
	droplet_mesh.radius = 0.016
	droplet_mesh.height = 0.072
	droplet_mesh.radial_segments = 5
	droplet_mesh.rings = 3
	var droplet_material := StandardMaterial3D.new()
	droplet_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	droplet_material.albedo_color = Color(0.58, 0.88, 0.9, 0.58)
	droplet_material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	droplet_material.roughness = 0.06
	droplet_material.emission_enabled = true
	droplet_material.emission = Color(0.32, 0.92, 0.88)
	droplet_material.emission_energy_multiplier = 0.42
	droplet_mesh.material = droplet_material
	particles.draw_pass_1 = droplet_mesh
	effect_root.add_child(particles)
	particles.emitting = true

	if visual_effects_auto_cleanup:
		_splash_tweens = _splash_tweens.filter(
			func(active_tween: Tween) -> bool:
				return active_tween != null and active_tween.is_valid() and active_tween.is_running()
		)
		var tween := effect_root.create_tween()
		_splash_tweens.append(tween)
		tween.set_parallel(true)
		tween.set_trans(Tween.TRANS_QUAD)
		tween.set_ease(Tween.EASE_OUT)
		for ring_index in rings.size():
			var ring_scale := 0.78 + strength * 0.3 + ring_index * 0.1
			tween.tween_property(rings[ring_index], "scale", Vector3.ONE * ring_scale, 0.72 + ring_index * 0.08)
			tween.tween_property(ring_materials[ring_index], "albedo_color:a", 0.0, 0.72 + ring_index * 0.08)
		tween.tween_property(foam_material, "shader_parameter/opacity", 0.0, 0.72)
		tween.tween_property(foam, "scale", Vector3.ONE * (1.35 + strength * 0.4), 0.72)
		tween.chain().tween_callback(func() -> void: _release_splash_root(effect_root))


func _obtain_splash_root() -> Node3D:
	var effect_root: Node3D
	if not _splash_pool.is_empty():
		effect_root = _splash_pool.pop_back()
		_clear_splash_root(effect_root)
	else:
		effect_root = Node3D.new()
		effect_root.name = "WaterSplash"
		add_child(effect_root)
	effect_root.visible = true
	_active_splash_roots.append(effect_root)
	return effect_root


func _release_splash_root(effect_root: Node3D) -> void:
	if effect_root == null or not is_instance_valid(effect_root):
		return
	_active_splash_roots.erase(effect_root)
	effect_root.visible = false
	if _splash_pool.size() >= SPLASH_POOL_SIZE:
		_clear_splash_root(effect_root)
		effect_root.queue_free()
		return
	_clear_splash_root(effect_root)
	_splash_pool.append(effect_root)


func _clear_splash_root(effect_root: Node3D, free_children := true) -> void:
	if effect_root == null or not is_instance_valid(effect_root):
		return
	for child in effect_root.get_children():
		if child is MeshInstance3D:
			var mesh_instance := child as MeshInstance3D
			if mesh_instance.mesh is PrimitiveMesh:
				(mesh_instance.mesh as PrimitiveMesh).material = null
			mesh_instance.material_override = null
			mesh_instance.mesh = null
		elif child is GPUParticles3D:
			var particles := child as GPUParticles3D
			particles.emitting = false
			particles.process_material = null
			particles.draw_pass_1 = null
		if free_children:
			child.free()


func _upload_ripples() -> void:
	_material.set_shader_parameter("ripple_origins", _origins)
	_material.set_shader_parameter("ripple_start_times", _start_times)
	_material.set_shader_parameter("ripple_strengths", _strengths)
	_material.set_shader_parameter("ripple_radii", _radii)
