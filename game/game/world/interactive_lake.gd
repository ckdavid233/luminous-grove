class_name InteractiveLake
extends MeshInstance3D

signal ripple_created(world_position: Vector3, source: StringName)
signal splash_created(world_position: Vector3, strength: float, source: StringName)

const MAX_RIPPLES := 16
const HALF_SIZE := Vector2(7.35, 4.85)

@export var rain_ripple_interval := Vector2(0.5, 1.15)
@export var footstep_distance := 0.34
@export var surface_contact_margin := 0.14
@export var maximum_wading_depth := 1.1
@export var visual_effects_enabled := true
@export var visual_effects_auto_cleanup := true

var _actor: CharacterBody3D
var _material: ShaderMaterial
var _origins := PackedVector2Array()
var _start_times := PackedFloat32Array()
var _next_ripple_slot := 0
var _rain_time_left := 0.25
var _last_actor_position := Vector3.INF
var _actor_distance_accumulator := 0.0
var _rng := RandomNumberGenerator.new()
var _elapsed_time := 0.0
var _was_touching_surface := false
var _splash_count := 0


func _ready() -> void:
	_rng.seed = 0x51A5A
	_material = get_active_material(0).duplicate() as ShaderMaterial
	material_override = _material
	_origins.resize(MAX_RIPPLES)
	_start_times.resize(MAX_RIPPLES)
	for index in MAX_RIPPLES:
		_origins[index] = Vector2.ZERO
		_start_times[index] = -1000.0
	_upload_ripples()


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
		add_ripple(to_global(local_point), &"droplet")
		_rain_time_left = _rng.randf_range(rain_ripple_interval.x, rain_ripple_interval.y)
	_update_actor_ripples()


func set_actor(actor: CharacterBody3D) -> void:
	_actor = actor
	_last_actor_position = actor.global_position
	_actor_distance_accumulator = 0.0
	_was_touching_surface = _is_actor_touching_surface(actor.global_position)


func add_ripple(position: Vector3, source: StringName = &"scripted") -> void:
	if _material == null:
		return
	var local_position := to_local(position)
	if not _is_inside_horizontal(local_position):
		return
	_origins[_next_ripple_slot] = Vector2(position.x, position.z)
	_start_times[_next_ripple_slot] = _elapsed_time
	_next_ripple_slot = (_next_ripple_slot + 1) % MAX_RIPPLES
	_upload_ripples()
	ripple_created.emit(position, source)


func active_ripple_count(current_time: float = -1.0) -> int:
	if current_time < 0.0:
		current_time = _elapsed_time
	var count := 0
	for start_time in _start_times:
		if current_time >= start_time and current_time - start_time <= 3.8:
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
		_create_surface_splash(
			Vector3(actor_position.x, global_position.y, actor_position.z),
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
		add_ripple(surface_position, &"footstep")
		_actor_distance_accumulator = 0.0
	_last_actor_position = actor_position


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
	add_ripple(position, source)
	_splash_count += 1
	splash_created.emit(position, strength, source)
	if not visual_effects_enabled:
		return

	var effect_root := Node3D.new()
	effect_root.name = "WaterSplash"
	get_parent().add_child(effect_root)
	effect_root.global_position = position + Vector3.UP * 0.1

	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.42
	ring_mesh.outer_radius = 0.48
	ring_mesh.rings = 24
	ring_mesh.ring_segments = 8
	var ring_material := StandardMaterial3D.new()
	ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_material.albedo_color = Color(0.63, 0.96, 0.94, 0.72)
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.emission_enabled = true
	ring_material.emission = Color(0.28, 0.82, 0.8)
	ring_material.emission_energy_multiplier = 0.92
	ring_material.roughness = 0.18
	ring_mesh.material = ring_material
	ring.mesh = ring_mesh
	ring.scale = Vector3.ONE * 0.28
	effect_root.add_child(ring)

	var particles := GPUParticles3D.new()
	particles.name = "SplashDroplets"
	particles.one_shot = true
	particles.amount = maxi(18, int(32.0 * strength))
	particles.lifetime = 0.86
	particles.explosiveness = 0.95
	particles.randomness = 0.42
	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_material.emission_sphere_radius = 0.18 * strength
	process_material.direction = Vector3.UP
	process_material.spread = 52.0
	process_material.gravity = Vector3(0.0, -9.8, 0.0)
	process_material.initial_velocity_min = 1.45 * strength
	process_material.initial_velocity_max = 3.35 * strength
	process_material.scale_min = 0.55
	process_material.scale_max = 1.25
	particles.process_material = process_material
	var droplet_mesh := SphereMesh.new()
	droplet_mesh.radius = 0.026
	droplet_mesh.height = 0.12
	droplet_mesh.radial_segments = 5
	droplet_mesh.rings = 3
	var droplet_material := StandardMaterial3D.new()
	droplet_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	droplet_material.albedo_color = Color(0.72, 0.95, 0.96, 0.88)
	droplet_material.emission_enabled = true
	droplet_material.emission = Color(0.35, 0.82, 0.84)
	droplet_material.emission_energy_multiplier = 0.72
	droplet_material.roughness = 0.1
	droplet_mesh.material = droplet_material
	particles.draw_pass_1 = droplet_mesh
	effect_root.add_child(particles)
	particles.emitting = true

	if visual_effects_auto_cleanup:
		var tween := effect_root.create_tween()
		tween.set_parallel(true)
		tween.set_trans(Tween.TRANS_QUAD)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(ring, "scale", Vector3.ONE * (1.25 + strength * 0.45), 0.72)
		tween.tween_property(ring_material, "albedo_color:a", 0.0, 0.72)
		tween.chain().tween_callback(effect_root.queue_free)


func _upload_ripples() -> void:
	_material.set_shader_parameter("ripple_origins", _origins)
	_material.set_shader_parameter("ripple_start_times", _start_times)
