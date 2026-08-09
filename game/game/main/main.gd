extends Node3D

const PLAYER_SCENE := preload("res://game/player/player.tscn")
const SHRINE_SCENE := preload("res://game/interaction/shrine.tscn")
const WIND_BELL_SCENE := preload("res://game/interaction/wind_bell.tscn")
const INTERACTIVE_LAKE := preload("res://game/world/interactive_lake.gd")
const FOREST_TERRAIN := preload("res://game/world/forest_terrain.gd")
const SURFACE_LIBRARY := preload("res://game/world/surface_library.gd")
const WETNESS_CONTROLLER := preload("res://game/world/wetness_controller.gd")
const FOOTPRINT_POOL := preload("res://game/world/footprint_pool.gd")
const FOREST_TREE_SCENES := [
	preload("res://content/environments/forest/forest_tree_1.glb"),
	preload("res://content/environments/forest/forest_tree_2.glb"),
	preload("res://content/environments/forest/forest_tree_3.glb"),
]
const WORLD_STREAMER := preload("res://core/world_streamer/world_streamer.gd")
const PHASE_SHIFT_CONTROLLER := preload("res://game/world/phase_shift_controller.gd")
const RAIN_RIFT_PORTAL := preload("res://game/world/rain_rift_portal.gd")
const CINEMATIC_DIRECTOR := preload("res://core/cinematic/cinematic_director.gd")
const NARRATIVE_DIRECTOR := preload("res://game/narrative/narrative_director.gd")
const MEMORY_DROPLET_SCENE := preload("res://game/narrative/memory_droplet.tscn")
const ENDING_CHOICE_SCENE := preload("res://game/narrative/ending_choice.tscn")
const STORY_RESONATOR := preload("res://game/narrative/story_resonator.gd")
const ECHO_LEVEL_PATH := "res://content/levels/echo_ruins/echo_ruins.tscn"
const CITY_PRESENT_PATH := (
	"res://content/levels/lantern_city/lantern_city_present.tscn"
)
const CITY_ECHO_PATH := (
	"res://content/levels/lantern_city/lantern_city_echo.tscn"
)
const RAIN_EYE_PRESENT_PATH := (
	"res://content/levels/rain_eye/rain_eye_present.tscn"
)
const RAIN_EYE_ECHO_PATH := (
	"res://content/levels/rain_eye/rain_eye_echo.tscn"
)
const GROUND_ALBEDO := preload(
	"res://content/environments/ground/forest_ground_albedo.png"
)
const GROUND_ALBEDO_V2 := preload(
	"res://content/environments/ground/forest_ground_albedo_v2.png"
)
const GROUND_NORMAL := preload(
	"res://content/environments/ground/forest_ground_normal.png"
)
const GROUND_ROUGHNESS := preload(
	"res://content/environments/ground/forest_ground_roughness.png"
)
const SETTINGS_PATH := "user://settings.cfg"

var _rng := RandomNumberGenerator.new()
var _player
var _shrine
var _wind_bell
var _water
var _surface_library
var _wetness_controller
var _ground
var _narrative
var _memory_droplets: Array[Node] = []
var _ending_choices: Array[Node] = []
var _archive_present_mechanisms: Array[Node] = []
var _world_environment: WorldEnvironment
var _sun: DirectionalLight3D
var _lake_fill: OmniLight3D
var _grass_instance: MultiMeshInstance3D
var _grass_material: ShaderMaterial
var _footprint_pool
var _forest_tree_instances: Array[MultiMeshInstance3D] = []
var _world_streamer
var _phase_shift
var _phase_portal: Node3D
var _phase_transition_overlay: ColorRect
var _cinematic_director
var _cinematic_ui: Control
var _cinematic_top_bar: ColorRect
var _cinematic_bottom_bar: ColorRect
var _cinematic_subtitle: Label
var _cinematic_skip_hint: Label
var _title_label: Label
var _chapter_label: Label
var _quest_label: Label
var _campaign_progress: ProgressBar
var _toast_label: Label
var _ending_overlay: ColorRect
var _ending_label: Label
var _pause_overlay: Control
var _quality_button: Button
var _quality_profile := &"high"
var _city_present: Node
var _city_echo: Node
var _city_transition_pending := false
var _city_present_activated := false
var _city_pair_ready := false
var _city_enter_from_gate := false
var _city_arrival_cinematic_pending := false
var _rain_eye_present: Node
var _rain_eye_echo: Node
var _rain_eye_transition_pending := false
var _rain_eye_present_activated := false
var _rain_eye_pair_ready := false
var _rain_eye_entry_cinematic_pending := false
var _pending_ending_id: StringName = &""
var _shutdown_requested := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 0xC0D3
	_load_quality_settings()
	_create_narrative()
	_create_environment()
	_create_surface_system()
	_create_ground()
	_create_forest_path()
	_create_water()
	_create_reflection_probes()
	_create_lake_shore()
	_create_footprints()
	_create_forest()
	_create_grass()
	_create_particles()
	_create_wind_bell()
	_create_shrine()
	_create_memory_droplets()
	_create_ending_choices()
	_create_archive_present_mechanisms()
	_create_player()
	_create_game_ui()
	_register_wetness_materials()
	_setup_cinematic()
	_setup_phase_shift()
	_apply_quality_profile()
	var restored := _restore_saved_game()
	if not restored:
		_narrative.begin_journey()
	_sync_world_to_narrative()
	if _has_runtime_argument("--release-smoke"):
		call_deferred("_run_release_smoke")
	elif not restored and not OS.get_cmdline_args().has("--script"):
		call_deferred("_play_intro_cinematic")


func _exit_tree() -> void:
	shutdown()


func shutdown() -> void:
	if _shutdown_requested:
		return
	_shutdown_requested = true
	# Stop any UI/cinematic tweens before child resources are released.  This
	# also covers a toast or transition started immediately before a test exits.
	for tween in get_tree().get_processed_tweens():
		if tween != null and tween.is_valid():
			tween.kill()
	# Detach physics materials before the Jolt server releases static/rigid
	# collision bodies. CharacterBody3D intentionally has no override property,
	# so it is excluded from this explicit release pass.
	for node in find_children("*", "CollisionObject3D", true, false):
		if node is StaticBody3D or node is RigidBody3D:
			var collision_object := node as CollisionObject3D
			if collision_object.physics_material_override != null:
				collision_object.physics_material_override = null
	if _wetness_controller != null and is_instance_valid(_wetness_controller):
		_wetness_controller.set_process(false)
	if _world_streamer != null and is_instance_valid(_world_streamer):
		if _world_streamer.has_method("shutdown"):
			_world_streamer.shutdown()
		else:
			_world_streamer.set_process(false)
	_memory_droplets.clear()
	_ending_choices.clear()
	_archive_present_mechanisms.clear()
	_forest_tree_instances.clear()
	_grass_material = null
	_surface_library = null
	_wetness_controller = null
	if _footprint_pool != null and is_instance_valid(_footprint_pool):
		if _footprint_pool.has_method("shutdown"):
			_footprint_pool.shutdown()
	_footprint_pool = null
	if _water != null and is_instance_valid(_water):
		if _water.has_method("shutdown"):
			_water.shutdown()
	_water = null
	if _phase_portal != null and is_instance_valid(_phase_portal):
		if _phase_portal.has_method("shutdown"):
			_phase_portal.shutdown()
	_phase_portal = null
	_world_streamer = null
	_phase_shift = null
	_surface_library = null
	_world_environment = null
	_sun = null
	_lake_fill = null
	_grass_instance = null
	_shrine = null
	_wind_bell = null
	_narrative = null
	_player = null
	_rng = null


func _process(_delta: float) -> void:
	if _player == null or _grass_material == null:
		return
	_grass_material.set_shader_parameter("actor_position", _player.global_position)
	_grass_material.set_shader_parameter("actor_influence", 1.0)
	var interactions := PackedVector4Array()
	interactions.append(Vector4(_player.global_position.x, _player.global_position.z, 0.0, 1.25))
	for body in get_tree().get_nodes_in_group("vegetation_push_body"):
		if body is RigidBody3D and is_instance_valid(body):
			var body_position: Vector3 = body.global_position
			interactions.append(Vector4(body_position.x, body_position.z, 0.0, 1.05))
			if interactions.size() >= 8:
				break
	_grass_material.set_shader_parameter("interaction_spheres", interactions)
	_grass_material.set_shader_parameter("interaction_count", interactions.size())


func _has_runtime_argument(argument: String) -> bool:
	return (
		OS.get_cmdline_args().has(argument)
		or OS.get_cmdline_user_args().has(argument)
	)


func _run_release_smoke() -> void:
	_quality_profile = &"high"
	_apply_quality_profile()
	# Material profiles and a cold exported PCK can take longer than the normal
	# 15-second smoke window on an integrated GPU. Keep the probe bounded, but
	# allow a full minute of process frames before reporting a real load failure.
	for _frame in 3600:
		if (
			_world_streamer != null
			and _world_streamer.is_level_ready(ECHO_LEVEL_PATH)
		):
			break
		await get_tree().process_frame
	var echo_ready: bool = (
		_world_streamer != null
		and _world_streamer.is_level_ready(ECHO_LEVEL_PATH)
	)
	var success: bool = (
		echo_ready
		and _player != null
		and _narrative != null
		and _narrative.CAMPAIGN_VERSION == 6
		and _quality_profile == &"high"
	)
	if success:
		print(
			"RELEASE_SMOKE_OK build=0.6.2-alpha campaign=6 quality=high "
			+ "echo_async=ready"
		)
		# This is a packaging/startup probe, not a teardown benchmark. Waiting for
		# threaded scene resources to drain here can keep a headless process alive
		# indefinitely on Linux, even after the success marker is printed. Let the
		# engine perform its normal process shutdown after the probe has passed.
		get_tree().quit(0)
	else:
		push_error(
			"RELEASE_SMOKE_FAILED echo=%s player=%s narrative=%s quality=%s"
			% [echo_ready, _player != null, _narrative != null, _quality_profile]
		)
		var scene_tree := get_tree()
		queue_free()
		await scene_tree.process_frame
		await scene_tree.physics_frame
		scene_tree.quit(1)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game"):
		_set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()
	elif get_tree().paused:
		return
	elif event.is_action_pressed("quick_save"):
		_save_current_game()
		_show_toast("进度已保存")
	elif event.is_action_pressed("quick_load"):
		_restore_saved_game()
		_show_toast("已恢复保存的进度")


func _create_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var physical_sky := PhysicalSkyMaterial.new()
	physical_sky.turbidity = 2.45
	physical_sky.rayleigh_coefficient = 1.42
	physical_sky.rayleigh_color = Color("9bc8d0")
	physical_sky.mie_coefficient = 0.006
	physical_sky.mie_color = Color("f0d5b4")
	physical_sky.ground_color = Color("31433b")
	physical_sky.sun_disk_scale = 1.65
	sky.sky_material = physical_sky
	environment.sky = sky
	environment.background_energy_multiplier = 0.52
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.7
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 0.94
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 0.97
	environment.adjustment_contrast = 1.08
	environment.adjustment_saturation = 0.94
	environment.glow_enabled = true
	environment.glow_intensity = 0.55
	environment.fog_enabled = true
	environment.fog_light_color = Color("8fb7ac")
	environment.fog_light_energy = 0.78
	environment.fog_density = 0.0042
	environment.fog_height = 0.0
	environment.fog_height_density = 0.08
	environment.ssr_enabled = true
	environment.ssao_enabled = true
	environment.ssao_radius = 1.7
	environment.ssao_intensity = 2.1
	environment.ssil_enabled = true
	environment.ssil_radius = 4.0
	environment.ssil_intensity = 1.25
	environment.sdfgi_enabled = true
	environment.sdfgi_use_occlusion = true
	environment.volumetric_fog_enabled = true
	environment.volumetric_fog_density = 0.0075
	environment.volumetric_fog_albedo = Color("a9c8bf")
	environment.volumetric_fog_emission = Color("243936")
	environment.volumetric_fog_emission_energy = 0.12
	environment.volumetric_fog_length = 56.0
	world_environment.environment = environment
	add_child(world_environment)
	_world_environment = world_environment

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	sun.light_color = Color("ffd9a3")
	sun.light_energy = 1.32
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.76
	sun.light_angular_distance = 0.34
	sun.directional_shadow_max_distance = 45.0
	add_child(sun)
	_sun = sun
	var sky_fill := DirectionalLight3D.new()
	sky_fill.name = "SkyFill"
	sky_fill.rotation_degrees = Vector3(-28.0, 148.0, 0.0)
	sky_fill.light_color = Color("a9c9d0")
	sky_fill.light_energy = 0.46
	sky_fill.shadow_enabled = false
	add_child(sky_fill)
	_apply_quality_profile()


func _create_surface_system() -> void:
	_surface_library = SURFACE_LIBRARY.new()
	_surface_library.name = "SurfaceLibrary"
	add_child(_surface_library)
	_wetness_controller = WETNESS_CONTROLLER.new()
	_wetness_controller.name = "WetnessController"
	_wetness_controller.set_rain_intensity(0.68)
	add_child(_wetness_controller)


func _create_reflection_probes() -> void:
	var lake_probe := ReflectionProbe.new()
	lake_probe.name = "LakeReflectionProbe"
	lake_probe.position = Vector3(-8.0, 0.55, -8.0)
	lake_probe.size = Vector3(18.0, 5.5, 14.0)
	lake_probe.origin_offset = Vector3(0.0, 0.7, 0.0)
	lake_probe.box_projection = true
	lake_probe.enable_shadows = true
	lake_probe.intensity = 0.82
	lake_probe.max_distance = 30.0
	lake_probe.update_mode = ReflectionProbe.UPDATE_ONCE
	add_child(lake_probe)

	var shrine_probe := ReflectionProbe.new()
	shrine_probe.name = "ShrineReflectionProbe"
	shrine_probe.position = Vector3(0.0, 1.4, -6.0)
	shrine_probe.size = Vector3(7.0, 4.0, 7.0)
	shrine_probe.box_projection = true
	shrine_probe.intensity = 0.58
	shrine_probe.max_distance = 16.0
	shrine_probe.update_mode = ReflectionProbe.UPDATE_ONCE
	add_child(shrine_probe)


func _create_ground() -> void:
	_ground = FOREST_TERRAIN.new()
	add_child(_ground)
	_ground.configure(
		_ground_material(),
		_surface_library.get_physics_material(&"dry_soil"),
	)


func _create_ground_box(
	parent: Node3D,
	position: Vector3,
	size: Vector3,
	material: Material,
) -> void:
	var body := StaticBody3D.new()
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	mesh_instance.mesh = mesh
	body.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	body.position = position
	parent.add_child(body)


func _create_forest_path() -> void:
	var path := Node3D.new()
	path.name = "ForestPath"
	add_child(path)
	var material := _path_material()
	_create_path_segment(path, Vector3(0.0, 0.015, 7.0), Vector3(-2.0, 0.015, 2.8), 1.75, material)
	_create_path_segment(path, Vector3(-2.0, 0.016, 2.8), Vector3(-4.2, 0.016, 0.5), 1.55, material)
	_create_path_segment(path, Vector3(-4.2, 0.017, 0.5), Vector3(-2.1, 0.017, -2.5), 1.45, material)
	_create_path_segment(path, Vector3(-2.1, 0.018, -2.5), Vector3(0.0, 0.018, -6.0), 1.65, material)


func _create_path_segment(
	parent: Node3D,
	start: Vector3,
	end: Vector3,
	width: float,
	material: Material,
) -> void:
	var segment := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	var direction := end - start
	plane.size = Vector2(width, direction.length())
	plane.material = material
	segment.mesh = plane
	segment.position = (start + end) * 0.5
	segment.position.y = FOREST_TERRAIN.height_at(segment.position.x, segment.position.z) + 0.055
	segment.rotation.y = atan2(direction.x, direction.z)
	parent.add_child(segment)


func _create_water() -> void:
	_water = INTERACTIVE_LAKE.new()
	_water.name = "Water"
	var plane := _create_elliptical_lake_mesh()
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/realistic_lake.gdshader")
	material.set_shader_parameter("wetness", 0.54)
	material.set_shader_parameter("rain_intensity", 0.68)
	plane.surface_set_material(0, material)
	_water.mesh = plane
	_water.position = Vector3(-8.0, 0.04, -8.0)
	add_child(_water)
	_lake_fill = OmniLight3D.new()
	_lake_fill.name = "LakeSurfaceFill"
	_lake_fill.position = Vector3(-8.0, 1.25, -8.0)
	_lake_fill.light_color = Color("72c9c0")
	_lake_fill.light_energy = 0.22
	_lake_fill.omni_range = 11.0
	_lake_fill.shadow_enabled = false
	add_child(_lake_fill)
	_create_water_droplets()


func _create_elliptical_lake_mesh() -> ArrayMesh:
	const RINGS := 34
	const SEGMENTS := 112
	const RADII := Vector2(7.5, 5.0)
	var vertices := PackedVector3Array([Vector3.ZERO])
	var normals := PackedVector3Array([Vector3.UP])
	var uvs := PackedVector2Array([Vector2(0.5, 0.5)])
	var indices := PackedInt32Array()
	for ring_index in range(1, RINGS + 1):
		var radius := float(ring_index) / float(RINGS)
		for segment_index in SEGMENTS:
			var angle := TAU * float(segment_index) / float(SEGMENTS)
			var normalized := Vector2(cos(angle), sin(angle)) * radius
			vertices.append(Vector3(normalized.x * RADII.x, 0.0, normalized.y * RADII.y))
			normals.append(Vector3.UP)
			uvs.append(normalized * 0.5 + Vector2(0.5, 0.5))
	for segment_index in SEGMENTS:
		var current := 1 + segment_index
		var next := 1 + (segment_index + 1) % SEGMENTS
		indices.append_array(PackedInt32Array([0, next, current]))
	for ring_index in range(1, RINGS):
		var inner_start := 1 + (ring_index - 1) * SEGMENTS
		var outer_start := 1 + ring_index * SEGMENTS
		for segment_index in SEGMENTS:
			var next_segment := (segment_index + 1) % SEGMENTS
			var inner_current := inner_start + segment_index
			var inner_next := inner_start + next_segment
			var outer_current := outer_start + segment_index
			var outer_next := outer_start + next_segment
			indices.append_array(
				PackedInt32Array(
					[
						inner_current,
						outer_next,
						outer_current,
						inner_current,
						inner_next,
						outer_next,
					]
				)
			)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _create_shallow_water_floor() -> void:
	var floor := StaticBody3D.new()
	floor.name = "ShallowWaterFloor"
	floor.position = Vector3(-8.0, -0.42, -8.0)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(14.7, 0.42, 9.7)
	collision.shape = shape
	floor.add_child(collision)
	add_child(floor)


func _create_water_droplets() -> void:
	var droplets := GPUParticles3D.new()
	droplets.name = "WaterDroplets"
	droplets.amount = 56
	droplets.lifetime = 1.7
	droplets.preprocess = 1.7
	droplets.position = Vector3(-8.0, 4.2, -8.0)
	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_material.emission_box_extents = Vector3(7.0, 0.15, 4.5)
	process_material.direction = Vector3.DOWN
	process_material.spread = 4.0
	process_material.gravity = Vector3(0.0, -5.5, 0.0)
	process_material.initial_velocity_min = 0.35
	process_material.initial_velocity_max = 0.7
	process_material.scale_min = 0.55
	process_material.scale_max = 1.15
	droplets.process_material = process_material
	var mesh := SphereMesh.new()
	mesh.radius = 0.012
	mesh.height = 0.055
	mesh.radial_segments = 5
	mesh.rings = 3
	var droplet_material := StandardMaterial3D.new()
	droplet_material.albedo_color = Color(0.72, 0.92, 0.96, 0.68)
	droplet_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	droplet_material.roughness = 0.08
	droplet_material.metallic_specular = 0.95
	mesh.material = droplet_material
	droplets.draw_pass_1 = mesh
	add_child(droplets)


func _create_lake_shore() -> void:
	var shore := Node3D.new()
	shore.name = "LakeShore"
	add_child(shore)
	var shore_colliders := StaticBody3D.new()
	shore_colliders.name = "ShoreColliders"
	shore_colliders.collision_layer = 1
	shore_colliders.collision_mask = 0
	shore_colliders.physics_material_override = _surface_library.get_physics_material(&"stone")
	shore_colliders.set_meta("surface_type", &"stone")
	shore.add_child(shore_colliders)

	var stone_materials: Array[StandardMaterial3D] = [
		_pbr_material("lake_stone", Color("83918b"), true, Vector3.ONE * 0.7),
		_pbr_material("lake_stone", Color("9ba59a"), true, Vector3.ONE * 0.82),
		_pbr_material("lake_stone", Color("71837c"), true, Vector3.ONE * 0.62),
	]

	var rock_batches: Array[MultiMesh] = []
	var rock_batch_indices := PackedInt32Array([0, 0, 0])
	for material_index in stone_materials.size():
		var rock_mesh := SphereMesh.new()
		rock_mesh.radius = 0.62
		rock_mesh.height = 1.05
		rock_mesh.radial_segments = 10
		rock_mesh.rings = 6
		rock_mesh.material = stone_materials[material_index]
		var rock_multimesh := MultiMesh.new()
		rock_multimesh.transform_format = MultiMesh.TRANSFORM_3D
		rock_multimesh.instance_count = 15 if material_index < 2 else 14
		rock_multimesh.mesh = rock_mesh
		rock_batches.append(rock_multimesh)
		var rock_instances := MultiMeshInstance3D.new()
		rock_instances.name = "ShoreRocks_%d" % (material_index + 1)
		rock_instances.multimesh = rock_multimesh
		rock_instances.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		shore.add_child(rock_instances)

	var lake_center := Vector3(-8.0, -0.03, -8.0)
	for index in 44:
		var edge := _lake_edge_position(index, 44)
		var outward := Vector3(edge.x / 7.5, 0.0, edge.z / 5.0).normalized()
		var rock_position := lake_center + edge + outward * _rng.randf_range(-0.18, 0.32)
		rock_position.y += _rng.randf_range(-0.12, 0.08)
		var rock_rotation := Vector3(
			_rng.randf_range(-16.0, 16.0),
			_rng.randf_range(0.0, 180.0),
			_rng.randf_range(-14.0, 14.0)
		) * PI / 180.0
		var rock_scale := Vector3(
			_rng.randf_range(0.45, 1.25),
			_rng.randf_range(0.32, 0.82),
			_rng.randf_range(0.55, 1.35)
		)
		var rock_material_index := index % stone_materials.size()
		var rock_basis := Basis.from_euler(rock_rotation).scaled(rock_scale)
		rock_batches[rock_material_index].set_instance_transform(
			rock_batch_indices[rock_material_index],
			Transform3D(rock_basis, rock_position),
		)
		rock_batch_indices[rock_material_index] += 1
		if index % 3 == 0:
			var rock_collision := CollisionShape3D.new()
			rock_collision.name = "ShoreRockCollision_%02d" % index
			var rock_shape := SphereShape3D.new()
			rock_shape.radius = 0.31 * maxf(rock_scale.x, rock_scale.z)
			rock_collision.shape = rock_shape
			rock_collision.position = rock_position
			shore_colliders.add_child(rock_collision)

	var reed_material := _standard_material(Color("78925c"), 0.9)
	var reed_mesh := CylinderMesh.new()
	reed_mesh.top_radius = 0.018
	reed_mesh.bottom_radius = 0.035
	reed_mesh.height = 1.0
	reed_mesh.radial_segments = 5
	reed_mesh.material = reed_material
	var reed_multimesh := MultiMesh.new()
	reed_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	reed_multimesh.instance_count = 54
	reed_multimesh.mesh = reed_mesh
	var reed_instances := MultiMeshInstance3D.new()
	reed_instances.name = "ShoreReeds"
	reed_instances.multimesh = reed_multimesh
	reed_instances.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	shore.add_child(reed_instances)
	for index in 54:
		var edge := _lake_edge_position(index, 54)
		var inward := Vector3(-edge.x / 7.5, 0.0, -edge.z / 5.0).normalized()
		var reed_position := lake_center + edge + inward * _rng.randf_range(0.05, 0.28)
		reed_position.y = 0.25
		var reed_height := _rng.randf_range(0.38, 0.95)
		var reed_basis := Basis.from_euler(
			Vector3(0.0, 0.0, deg_to_rad(_rng.randf_range(-9.0, 9.0)))
		).scaled(Vector3(1.0, reed_height, 1.0))
		reed_multimesh.set_instance_transform(
			index,
			Transform3D(reed_basis, reed_position),
		)


func _create_footprints() -> void:
	_footprint_pool = FOOTPRINT_POOL.new()
	_footprint_pool.name = "Footprints"
	add_child(_footprint_pool)


func _lake_edge_position(index: int, count: int) -> Vector3:
	var angle := TAU * float(index) / float(count)
	return Vector3(cos(angle) * 7.62, 0.0, sin(angle) * 5.12)


func _create_forest() -> void:
	var forest := Node3D.new()
	forest.name = "Forest"
	add_child(forest)
	var bark_material := _pbr_material(
		"bark",
		Color("b8a891"),
		false,
		Vector3.ONE,
	)
	var leaf_material := ShaderMaterial.new()
	leaf_material.shader = load("res://shaders/forest_leaves.gdshader")
	var tree_colliders := StaticBody3D.new()
	tree_colliders.name = "TreeColliders"
	tree_colliders.collision_layer = 1
	tree_colliders.collision_mask = 0
	tree_colliders.physics_material_override = _surface_library.get_physics_material(&"wood")
	tree_colliders.set_meta("surface_type", &"wood")
	forest.add_child(tree_colliders)
	var occupied_positions: Array[Vector3] = []
	const TREES_PER_VARIANT := 18
	for variant_index in FOREST_TREE_SCENES.size():
		var tree_mesh := _extract_tree_mesh(
			FOREST_TREE_SCENES[variant_index],
			bark_material,
			leaf_material,
		)
		var tree_instances := MultiMeshInstance3D.new()
		tree_instances.name = "DetailedTrees_%d" % (variant_index + 1)
		tree_instances.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		tree_instances.visibility_range_end = 72.0
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.instance_count = TREES_PER_VARIANT
		multimesh.mesh = tree_mesh
		tree_instances.multimesh = multimesh
		forest.add_child(tree_instances)
		_forest_tree_instances.append(tree_instances)
		for tree_index in TREES_PER_VARIANT:
			var position_2d := Vector2.ZERO
			var found_position := false
			for _attempt in 160:
				var angle := _rng.randf_range(0.0, TAU)
				var radius := _rng.randf_range(8.2, 31.0)
				position_2d = Vector2(cos(angle), sin(angle)) * radius
				if not _forest_position_is_clear(position_2d, occupied_positions):
					continue
				found_position = true
				break
			assert(found_position, "Detailed forest placement budget exhausted")
			var scale_factor := _rng.randf_range(0.72, 1.18)
			var position := Vector3(
				position_2d.x,
				FOREST_TERRAIN.height_at(position_2d.x, position_2d.y),
				position_2d.y,
			)
			occupied_positions.append(position)
			var basis := Basis.from_euler(
				Vector3(0.0, _rng.randf_range(0.0, TAU), 0.0)
			).scaled(Vector3.ONE * scale_factor)
			multimesh.set_instance_transform(tree_index, Transform3D(basis, position))
			var collision := CollisionShape3D.new()
			var shape := CylinderShape3D.new()
			shape.radius = 0.37 * scale_factor
			shape.height = 4.8 * scale_factor
			collision.shape = shape
			collision.position = position + Vector3.UP * shape.height * 0.5
			tree_colliders.add_child(collision)


func _extract_tree_mesh(
	tree_scene: PackedScene,
	bark_material: Material,
	leaf_material: Material,
) -> ArrayMesh:
	var instance := tree_scene.instantiate()
	var source := instance as MeshInstance3D
	if source == null:
		source = instance.find_child("*", true, false) as MeshInstance3D
	assert(source != null and source.mesh != null, "Forest tree GLB needs one mesh")
	var tree_mesh := source.mesh.duplicate(true) as ArrayMesh
	for surface_index in tree_mesh.get_surface_count():
		var imported_material := tree_mesh.surface_get_material(surface_index)
		var material_name := (
			imported_material.resource_name.to_lower() if imported_material != null else ""
		)
		tree_mesh.surface_set_material(
			surface_index,
			bark_material if "bark" in material_name else leaf_material,
		)
	instance.free()
	return tree_mesh


func _forest_position_is_clear(
	point: Vector2,
	occupied_positions: Array[Vector3],
) -> bool:
	var lake_normalized := Vector2((point.x + 8.0) / 8.35, (point.y + 8.0) / 5.85)
	if lake_normalized.length() < 1.18:
		return false
	if _is_near_forest_path(point, 2.25):
		return false
	for occupied in occupied_positions:
		if point.distance_to(Vector2(occupied.x, occupied.z)) < 2.55:
			return false
	return true


func _create_grass() -> void:
	var grass_mesh := _create_grass_clump_mesh()
	var grass_material := ShaderMaterial.new()
	grass_material.shader = load("res://shaders/forest_grass.gdshader")
	grass_material.set_shader_parameter("actor_position", Vector3.ZERO)
	grass_material.set_shader_parameter("actor_influence", 1.0)
	grass_mesh.surface_set_material(0, grass_material)
	_grass_material = grass_material

	var grass_instance := MultiMeshInstance3D.new()
	grass_instance.name = "Grass"
	grass_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	grass_instance.visibility_range_end = 38.0
	grass_instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.instance_count = 16000
	multimesh.mesh = grass_mesh
	grass_instance.multimesh = multimesh
	add_child(grass_instance)
	_grass_instance = grass_instance

	for index in multimesh.instance_count:
		var position_2d := Vector2.ZERO
		for _attempt in 80:
			position_2d = Vector2(
				_rng.randf_range(-31.0, 31.0),
				_rng.randf_range(-31.0, 31.0),
			)
			var lake_normalized := Vector2(
				(position_2d.x + 8.0) / 7.7,
				(position_2d.y + 8.0) / 5.2,
			)
			if lake_normalized.length() <= 1.05 or _is_near_forest_path(position_2d, 0.82):
				continue
			break
		var position := Vector3(
			position_2d.x,
			FOREST_TERRAIN.height_at(position_2d.x, position_2d.y) + 0.015,
			position_2d.y,
		)
		var basis := Basis.from_euler(
			Vector3(0.0, _rng.randf_range(0.0, TAU), 0.0)
		)
		var width_scale := _rng.randf_range(0.68, 1.08)
		var height_scale := _rng.randf_range(0.24, 0.58)
		basis = basis.scaled(Vector3(width_scale, height_scale, width_scale))
		multimesh.set_instance_transform(index, Transform3D(basis, position))
		multimesh.set_instance_custom_data(
			index,
			Color(_rng.randf(), _rng.randf(), 0.0, 1.0),
		)
	_apply_grass_quality()


func _create_grass_clump_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	const BLADE_COUNT := 5
	for blade_index in BLADE_COUNT:
		var angle := float(blade_index) * 2.399963 + float(blade_index % 2) * 0.17
		var blade_width := 0.012 + float(blade_index % 4) * 0.0035
		var right := Vector3(cos(angle), 0.0, sin(angle)) * blade_width
		var normal := Vector3(-sin(angle), 0.0, cos(angle))
		var spread := 0.025 + float(blade_index % 5) * 0.024
		var center := Vector3(cos(angle * 1.37), 0.0, sin(angle * 1.37)) * spread
		var height := 0.62 + float((blade_index * 7) % 6) * 0.052
		var mid_center := center + normal * (0.018 + float(blade_index % 2) * 0.012) + Vector3.UP * height * 0.56
		var tip_center := center + normal * (0.065 + float(blade_index % 3) * 0.018) + Vector3.UP * height
		var base := vertices.size()
		vertices.append_array(
			PackedVector3Array(
				[
					center - right,
					center + right,
					mid_center - right * 0.72,
					mid_center + right * 0.72,
					tip_center - right * 0.08,
					tip_center + right * 0.08,
				]
			)
		)
		for _vertex in 6:
			normals.append(normal)
		uvs.append_array(
			PackedVector2Array(
				[
					Vector2(0.0, 0.0),
					Vector2(1.0, 0.0),
					Vector2(0.0, 0.56),
					Vector2(1.0, 0.56),
					Vector2(0.0, 1.0),
					Vector2(1.0, 1.0),
				]
			)
		)
		indices.append_array(
			PackedInt32Array(
				[
					base,
					base + 2,
					base + 1,
					base + 1,
					base + 2,
					base + 3,
					base + 2,
					base + 4,
					base + 3,
					base + 3,
					base + 4,
					base + 5,
				]
			)
		)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _is_near_forest_path(point: Vector2, margin: float) -> bool:
	var points: Array[Vector2] = [
		Vector2(0.0, 7.0),
		Vector2(-2.0, 2.8),
		Vector2(-4.2, 0.5),
		Vector2(-2.1, -2.5),
		Vector2(0.0, -6.0),
	]
	for index in points.size() - 1:
		if _distance_to_segment_2d(point, points[index], points[index + 1]) <= margin:
			return true
	return false


func _distance_to_segment_2d(point: Vector2, start: Vector2, end: Vector2) -> float:
	var segment := end - start
	var denominator := segment.length_squared()
	if denominator <= 0.0001:
		return point.distance_to(start)
	var t := clampf((point - start).dot(segment) / denominator, 0.0, 1.0)
	return point.distance_to(start + segment * t)


func _create_particles() -> void:
	var effects := Node3D.new()
	effects.name = "AmbientVFX"
	add_child(effects)

	var fireflies := GPUParticles3D.new()
	fireflies.name = "Fireflies"
	fireflies.amount = 42
	fireflies.lifetime = 6.0
	fireflies.preprocess = 6.0
	fireflies.position = Vector3(0.0, 1.8, -4.0)
	var firefly_process := ParticleProcessMaterial.new()
	firefly_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	firefly_process.emission_box_extents = Vector3(10.0, 1.7, 10.0)
	firefly_process.direction = Vector3.UP
	firefly_process.spread = 180.0
	firefly_process.gravity = Vector3(0.0, 0.015, 0.0)
	firefly_process.initial_velocity_min = 0.04
	firefly_process.initial_velocity_max = 0.16
	firefly_process.scale_min = 0.65
	firefly_process.scale_max = 1.35
	fireflies.process_material = firefly_process
	var firefly_mesh := SphereMesh.new()
	firefly_mesh.radius = 0.022
	firefly_mesh.height = 0.044
	firefly_mesh.radial_segments = 6
	firefly_mesh.rings = 3
	var firefly_material := StandardMaterial3D.new()
	firefly_material.albedo_color = Color("b9fff0")
	firefly_material.emission_enabled = true
	firefly_material.emission = Color("84ffe4")
	firefly_material.emission_energy_multiplier = 1.6
	firefly_mesh.material = firefly_material
	fireflies.draw_pass_1 = firefly_mesh
	effects.add_child(fireflies)

	var petals := GPUParticles3D.new()
	petals.name = "Petals"
	petals.amount = 48
	petals.lifetime = 8.0
	petals.preprocess = 8.0
	petals.position = Vector3(0.0, 3.8, -4.0)
	var petal_process := ParticleProcessMaterial.new()
	petal_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	petal_process.emission_box_extents = Vector3(9.0, 0.8, 9.0)
	petal_process.direction = Vector3(0.8, -0.25, 0.2)
	petal_process.spread = 38.0
	petal_process.gravity = Vector3(0.0, -0.055, 0.0)
	petal_process.initial_velocity_min = 0.25
	petal_process.initial_velocity_max = 0.65
	petal_process.scale_min = 0.6
	petal_process.scale_max = 1.25
	petal_process.anim_offset_min = 0.0
	petal_process.anim_offset_max = 1.0
	petal_process.anim_speed_min = 0.0
	petal_process.anim_speed_max = 0.0
	petals.process_material = petal_process
	var petal_mesh := QuadMesh.new()
	petal_mesh.size = Vector2(0.09, 0.045)
	var petal_material := StandardMaterial3D.new()
	petal_material.albedo_texture = load("res://content/vfx/leaf_petals_atlas.png")
	petal_material.albedo_color = Color.WHITE
	petal_material.roughness = 0.8
	petal_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	petal_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	petal_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	petal_material.particles_anim_h_frames = 4
	petal_material.particles_anim_v_frames = 5
	petal_material.particles_anim_loop = true
	petal_mesh.material = petal_material
	petals.draw_pass_1 = petal_mesh
	effects.add_child(petals)


func _create_shrine() -> void:
	_shrine = SHRINE_SCENE.instantiate()
	_shrine.position = Vector3(0.0, 0.0, -6.0)
	_shrine.activated.connect(_on_shrine_activated)
	add_child(_shrine)


func _create_narrative() -> void:
	_narrative = NARRATIVE_DIRECTOR.new()
	_narrative.name = "NarrativeDirector"
	_narrative.objective_changed.connect(_on_objective_changed)
	_narrative.memory_added.connect(_on_memory_added)
	_narrative.all_memories_collected.connect(_on_all_memories_collected)
	_narrative.alignment_chosen.connect(_on_alignment_chosen)
	_narrative.archive_anchor_added.connect(_on_archive_anchor_added)
	_narrative.archive_anchors_completed.connect(_on_archive_anchors_completed)
	_narrative.archive_mechanism_added.connect(_on_archive_mechanism_added)
	_narrative.archive_restored.connect(_on_archive_restored)
	_narrative.city_trace_added.connect(_on_city_trace_added)
	_narrative.city_traces_completed.connect(_on_city_traces_completed)
	_narrative.city_relay_added.connect(_on_city_relay_added)
	_narrative.city_relays_completed.connect(_on_city_relays_completed)
	_narrative.city_testimony_chosen.connect(_on_city_testimony_chosen)
	_narrative.city_route_completed.connect(_on_city_route_completed)
	_narrative.rain_eye_seal_added.connect(_on_rain_eye_seal_added)
	_narrative.rain_eye_seals_completed.connect(_on_rain_eye_seals_completed)
	_narrative.rain_eye_trial_added.connect(_on_rain_eye_trial_added)
	_narrative.final_decision_ready.connect(_on_final_decision_ready)
	_narrative.ending_chosen.connect(_on_final_ending_chosen)
	add_child(_narrative)


func _create_wind_bell() -> void:
	_wind_bell = WIND_BELL_SCENE.instantiate()
	_wind_bell.position = Vector3(-4.2, 0.0, 0.5)
	_wind_bell.rung.connect(_on_wind_bell_rung)
	add_child(_wind_bell)


func _create_memory_droplets() -> void:
	var definitions := [
		[&"rain_sound", &"memory_rain_sound", Vector3(-14.2, 0.72, -7.4)],
		[&"wet_earth", &"memory_wet_earth", Vector3(-8.0, 0.48, -8.0)],
		[&"waiting_light", &"memory_waiting_light", Vector3(2.0, 0.72, -7.4)],
	]
	for definition in definitions:
		var droplet := MEMORY_DROPLET_SCENE.instantiate()
		droplet.memory_id = definition[0]
		droplet.persistent_id = definition[1]
		droplet.position = definition[2]
		droplet.collected.connect(_on_memory_droplet_collected)
		_memory_droplets.append(droplet)
		add_child(droplet)


func _create_ending_choices() -> void:
	var definitions := [
		[
			&"return_to_lake",
			&"ending_return_to_lake",
			"将记忆归还湖水",
			Vector3(-2.35, 0.0, -3.9),
		],
		[
			&"carry_the_light",
			&"ending_carry_the_light",
			"带着微光离开林地",
			Vector3(2.35, 0.0, -3.9),
		],
	]
	for definition in definitions:
		var choice := ENDING_CHOICE_SCENE.instantiate()
		choice.choice_id = definition[0]
		choice.persistent_id = definition[1]
		choice.prompt_text = definition[2]
		choice.position = definition[3]
		choice.selected.connect(_on_ending_choice_selected)
		_ending_choices.append(choice)
		add_child(choice)


func _create_archive_present_mechanisms() -> void:
	var definitions := [
		[
			&"archive_reflection",
			"校准湖面倒影机关",
			Vector3(-8.0, 0.0, -9.4),
			Color("62f5e8"),
		],
		[
			&"archive_name_lens",
			"聚焦铭名透镜",
			Vector3(3.4, 0.0, -10.8),
			Color("d2a1ff"),
		],
	]
	for definition in definitions:
		var mechanism := STORY_RESONATOR.new()
		mechanism.name = "ArchiveMechanism_" + str(definition[0])
		mechanism.resonance_id = definition[0]
		mechanism.prompt_text = definition[1]
		mechanism.visual_layer = PHASE_SHIFT_CONTROLLER.PRESENT_VISUAL_LAYER
		mechanism.accent_color = definition[3]
		mechanism.position = definition[2]
		mechanism.activated.connect(_on_archive_mechanism_activated)
		_archive_present_mechanisms.append(mechanism)
		add_child(mechanism)


func _create_player() -> void:
	_player = PLAYER_SCENE.instantiate()
	_player.position = Vector3(0.0, 1.0, 6.0)
	add_child(_player)
	_player.set_surface_library(_surface_library)
	_set_visual_layer(_player, PHASE_SHIFT_CONTROLLER.SHARED_VISUAL_LAYER)
	_water.set_actor(_player)
	_player.landed.connect(_on_player_landed)
	_player.footstep_surface.connect(_on_player_footstep)


func _register_wetness_materials() -> void:
	if _wetness_controller == null:
		return
	for node_name in [
		"Ground",
		"ForestPath",
		"Water",
		"LakeShore",
		"Forest",
		"Grass",
		"Shrine",
		"WindBell",
	]:
		var node := get_node_or_null(node_name)
		if node != null:
			_wetness_controller.register_node(node)
	if not _wetness_controller.wetness_changed.is_connected(_on_wetness_changed):
		_wetness_controller.wetness_changed.connect(_on_wetness_changed)


func _on_wetness_changed(value: float, rain_intensity: float) -> void:
	if _world_environment != null and _world_environment.environment != null:
		var environment := _world_environment.environment
		environment.fog_density = lerpf(0.0035, 0.0062, rain_intensity)
		environment.volumetric_fog_density = lerpf(0.0058, 0.0105, rain_intensity)
		environment.volumetric_fog_albedo = Color(0.58, 0.72, 0.7).lerp(
			Color(0.67, 0.78, 0.76),
			value * 0.45,
		)
	var droplets := get_node_or_null("WaterDroplets") as GPUParticles3D
	if droplets != null:
		droplets.amount = maxi(18, int(56.0 * (0.35 + rain_intensity * 0.85)))
	if _water != null and _water.has_method("set_rain_intensity"):
		_water.set_rain_intensity(rain_intensity)
	if _lake_fill != null:
		_lake_fill.light_energy = lerpf(0.16, 0.34, value)


func _on_player_landed(impact_speed: float) -> void:
	if _water == null or _player == null:
		return
	if _water.has_method("emit_surface_event"):
		_water.emit_surface_event(
			Vector3(_player.global_position.x, _water.global_position.y, _player.global_position.z),
			Vector3(0.0, -impact_speed, 0.0),
			clampf(0.42 + impact_speed * 0.08, 0.42, 1.3),
			&"landing",
		)


func _on_player_footstep(position: Vector3, speed: float, surface_type: StringName) -> void:
	if _water == null or not _water.has_method("emit_surface_event"):
		if _footprint_pool != null:
			_footprint_pool.stamp(position, Vector3.UP, surface_type, 0.8)
		return
	if _footprint_pool != null and surface_type != &"water":
		_footprint_pool.stamp(position, Vector3.UP, surface_type, 0.88)
	if surface_type == &"water" or surface_type == &"wet_mud":
		_water.emit_surface_event(
			Vector3(position.x, _water.global_position.y, position.z),
			Vector3(0.0, speed, 0.0),
			clampf(0.16 + speed * 0.035, 0.16, 0.72),
			&"footstep",
		)


func _setup_phase_shift() -> void:
	var alternate_host := Node3D.new()
	alternate_host.name = "AlternateWorldHost"
	add_child(alternate_host)
	_world_streamer = WORLD_STREAMER.new()
	_world_streamer.name = "WorldStreamer"
	add_child(_world_streamer)
	_world_streamer.configure(alternate_host, 2)
	_world_streamer.level_loaded.connect(_on_streamed_level_loaded)

	var present_nodes: Array[Node] = []
	for node_name in [
		"Ground",
		"ForestPath",
		"Water",
		"LakeSurfaceFill",
		"LakeReflectionProbe",
		"ShrineReflectionProbe",
		"ShallowWaterFloor",
		"WaterDroplets",
		"LakeShore",
		"Footprints",
		"Forest",
		"Grass",
		"AmbientVFX",
	]:
		var node := get_node_or_null(node_name)
		if node != null:
			present_nodes.append(node)
	present_nodes.append(_wind_bell)
	present_nodes.append(_shrine)
	present_nodes.append_array(_memory_droplets)
	present_nodes.append_array(_ending_choices)
	present_nodes.append_array(_archive_present_mechanisms)

	_phase_shift = PHASE_SHIFT_CONTROLLER.new()
	_phase_shift.name = "PhaseShiftController"
	_phase_shift.shift_rejected.connect(_on_phase_shift_rejected)
	_phase_shift.shift_started.connect(_on_phase_shift_started)
	_phase_shift.shift_completed.connect(_on_phase_shift_completed)
	add_child(_phase_shift)
	var error: Error = _phase_shift.configure(
		_world_streamer,
		_player,
		present_nodes,
		_world_environment,
		_sun,
		ECHO_LEVEL_PATH,
	)
	if error != OK:
		push_error("Echo realm preload failed to start: %s" % error_string(error))
	_phase_portal = RAIN_RIFT_PORTAL.new()
	_phase_portal.position = Vector3(5.2, 1.78, -2.2)
	_phase_portal.rotation_degrees.y = -24.0
	add_child(_phase_portal)
	var gameplay_camera := _player.find_child("Camera", true, false) as Camera3D
	_phase_portal.configure_preview(
		gameplay_camera,
		PHASE_SHIFT_CONTROLLER.ECHO_VISUAL_LAYER
	)


func _setup_cinematic() -> void:
	_cinematic_director = CINEMATIC_DIRECTOR.new()
	_cinematic_director.name = "CinematicDirector"
	_cinematic_director.cinematic_started.connect(_on_cinematic_started)
	_cinematic_director.subtitle_requested.connect(_on_cinematic_subtitle)
	_cinematic_director.cinematic_finished.connect(_on_cinematic_finished)
	add_child(_cinematic_director)
	var gameplay_camera := _player.find_child("Camera", true, false) as Camera3D
	_cinematic_director.configure(_player, gameplay_camera)


func _create_game_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "GameUI"
	canvas.layer = 20
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas)

	_title_label = Label.new()
	_title_label.position = Vector2(24.0, 94.0)
	_title_label.add_theme_font_size_override("font_size", 26)
	_title_label.add_theme_color_override("font_color", Color("fff0c2"))
	_title_label.text = "微光林地"
	canvas.add_child(_title_label)

	_chapter_label = Label.new()
	_chapter_label.position = Vector2(26.0, 126.0)
	_chapter_label.add_theme_font_size_override("font_size", 15)
	_chapter_label.add_theme_color_override("font_color", Color(0.58, 0.9, 0.83, 0.86))
	canvas.add_child(_chapter_label)

	_quest_label = Label.new()
	_quest_label.position = Vector2(26.0, 153.0)
	_quest_label.add_theme_font_size_override("font_size", 18)
	_quest_label.add_theme_color_override("font_color", Color(0.9, 0.94, 0.82, 0.92))
	canvas.add_child(_quest_label)

	_campaign_progress = ProgressBar.new()
	_campaign_progress.position = Vector2(26.0, 184.0)
	_campaign_progress.size = Vector2(360.0, 8.0)
	_campaign_progress.max_value = 1.0
	_campaign_progress.show_percentage = false
	_campaign_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(_campaign_progress)

	_toast_label = Label.new()
	_toast_label.position = Vector2(510.0, 90.0)
	_toast_label.size = Vector2(260.0, 42.0)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.add_theme_font_size_override("font_size", 18)
	_toast_label.add_theme_color_override("font_color", Color("a5fff3"))
	canvas.add_child(_toast_label)
	_create_phase_transition_ui(canvas)
	_create_cinematic_ui(canvas)
	_create_ending_ui(canvas)
	_create_pause_ui(canvas)
	if not OS.get_cmdline_args().has("--script"):
		_play_opening_fade(canvas)
	_update_quest_ui()


func _create_pause_ui(canvas: CanvasLayer) -> void:
	_pause_overlay = Control.new()
	_pause_overlay.name = "PauseOverlay"
	_pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_overlay.z_index = 80
	_pause_overlay.visible = false
	canvas.add_child(_pause_overlay)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.01, 0.025, 0.035, 0.9)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_overlay.add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(440.0, 430.0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.035, 0.09, 0.105, 0.97)
	panel_style.border_color = Color(0.28, 0.78, 0.72, 0.78)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(14)
	panel_style.set_content_margin_all(28.0)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 15)
	panel.add_child(layout)
	var title := Label.new()
	title.text = "微光林地 · 暂停"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("e9fff4"))
	layout.add_child(title)
	var version := Label.new()
	version.text = "雨之名  v0.6.2-alpha"
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version.add_theme_font_size_override("font_size", 15)
	version.add_theme_color_override("font_color", Color(0.66, 0.84, 0.8, 0.8))
	layout.add_child(version)

	var resume_button := _make_pause_button("继续旅程")
	resume_button.pressed.connect(func() -> void: _set_paused(false))
	layout.add_child(resume_button)
	_quality_button = _make_pause_button("")
	_quality_button.pressed.connect(_cycle_quality_profile)
	layout.add_child(_quality_button)
	_update_quality_button()
	var fullscreen_button := _make_pause_button("切换全屏 / 窗口")
	fullscreen_button.pressed.connect(_toggle_fullscreen)
	layout.add_child(fullscreen_button)
	var save_button := _make_pause_button("保存当前进度  [F5]")
	save_button.pressed.connect(
		func() -> void:
			_save_current_game()
			_show_toast("进度已保存")
	)
	layout.add_child(save_button)
	var hint := Label.new()
	hint.text = "Esc / Start 返回 · F9 快速读取"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.72, 0.82, 0.8, 0.74))
	layout.add_child(hint)


func _make_pause_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, 48.0)
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.add_theme_font_size_override("font_size", 18)
	return button


func _set_paused(value: bool) -> void:
	if _pause_overlay == null:
		return
	_pause_overlay.visible = value
	get_tree().paused = value
	if _player != null:
		var cinematic_playing: bool = (
			_cinematic_director != null and bool(_cinematic_director.is_playing)
		)
		_player.set_control_enabled(not value and not cinematic_playing)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if value else Input.MOUSE_MODE_CAPTURED
	if value:
		_pause_overlay.move_to_front()
		var buttons := _pause_overlay.find_children("*", "Button", true, false)
		if not buttons.is_empty():
			(buttons[0] as Button).grab_focus()
	else:
		var focused := get_viewport().gui_get_focus_owner()
		if focused != null and _pause_overlay.is_ancestor_of(focused):
			focused.release_focus()


func _cycle_quality_profile() -> void:
	match _quality_profile:
		&"high":
			_quality_profile = &"balanced"
		&"balanced":
			_quality_profile = &"performance"
		_:
			_quality_profile = &"high"
	_apply_quality_profile()
	_save_quality_settings()
	_update_quality_button()


func _update_quality_button() -> void:
	if _quality_button == null:
		return
	var profile_text: String = str({
		&"high": "高画质 · 全特效（默认）",
		&"balanced": "均衡画质 · 保留雾与反射",
		&"performance": "性能画质 · 集显优先",
	}.get(_quality_profile, "高画质 · 全特效（默认）"))
	_quality_button.text = "画质：" + profile_text


func _apply_quality_profile() -> void:
	if _world_environment == null or _world_environment.environment == null:
		return
	var environment := _world_environment.environment
	match _quality_profile:
		&"balanced":
			environment.ssr_enabled = true
			environment.ssao_enabled = true
			environment.ssil_enabled = false
			environment.sdfgi_enabled = false
			environment.volumetric_fog_enabled = true
			_sun.directional_shadow_max_distance = 34.0
		&"performance":
			environment.ssr_enabled = false
			environment.ssao_enabled = false
			environment.ssil_enabled = false
			environment.sdfgi_enabled = false
			environment.volumetric_fog_enabled = false
			_sun.directional_shadow_max_distance = 24.0
		_:
			_quality_profile = &"high"
			environment.ssr_enabled = true
			environment.ssao_enabled = true
			environment.ssil_enabled = true
			environment.sdfgi_enabled = true
			environment.volumetric_fog_enabled = true
			_sun.directional_shadow_max_distance = 45.0
	_apply_grass_quality()
	_apply_forest_quality()
	var ambient_vfx := get_node_or_null("AmbientVFX") as Node3D
	if ambient_vfx != null:
		ambient_vfx.visible = _quality_profile != &"performance"
	var water_droplets := get_node_or_null("WaterDroplets") as GPUParticles3D
	if water_droplets != null:
		water_droplets.visible = _quality_profile != &"performance"
	if _player != null:
		_player.set_visual_quality_profile(_quality_profile)
	if _water != null and _water.has_method("set_visual_quality_profile"):
		_water.set_visual_quality_profile(_quality_profile)


func _apply_grass_quality() -> void:
	if _grass_instance == null or _grass_instance.multimesh == null:
		return
	match _quality_profile:
		&"balanced":
			_grass_instance.multimesh.visible_instance_count = 10000
			_grass_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		&"performance":
			_grass_instance.multimesh.visible_instance_count = 5200
			_grass_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_:
			_grass_instance.multimesh.visible_instance_count = 16000
			_grass_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _apply_forest_quality() -> void:
	for tree_instances in _forest_tree_instances:
		tree_instances.cast_shadow = (
			GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if _quality_profile == &"performance"
			else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		)
		var visibility_end := 72.0
		if _quality_profile == &"balanced":
			visibility_end = 60.0
		elif _quality_profile == &"performance":
			visibility_end = 46.0
		tree_instances.visibility_range_end = visibility_end
		tree_instances.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


func _load_quality_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	var restored := StringName(str(config.get_value("graphics", "profile", "high")))
	if restored in [&"high", &"balanced", &"performance"]:
		_quality_profile = restored


func _save_quality_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("graphics", "profile", str(_quality_profile))
	config.save(SETTINGS_PATH)


func _toggle_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_WINDOWED
		if mode == DisplayServer.WINDOW_MODE_FULLSCREEN
		else DisplayServer.WINDOW_MODE_FULLSCREEN
	)


func get_quality_profile() -> StringName:
	return _quality_profile


func _on_shrine_activated(_shrine_id: StringName) -> void:
	if not _narrative.handle_shrine_activated():
		return
	_update_quest_ui()
	_show_toast("记忆回到神龛。现在，决定它将流向哪里")
	_sync_world_to_narrative()
	_save_current_game()
	if not OS.get_cmdline_args().has("--script"):
		_play_shrine_awaken_cinematic()


func _on_wind_bell_rung(_bell_id: StringName) -> void:
	if not _narrative.handle_bell_rung():
		return
	_update_quest_ui()
	_show_toast("风把遗失的声音送回湖面")
	_sync_world_to_narrative()
	_save_current_game()


func _on_memory_droplet_collected(memory_id: StringName) -> void:
	if _narrative.collect_memory(memory_id):
		_save_current_game()


func _on_memory_added(_memory_id: StringName, text: String, _count: int) -> void:
	_show_toast(text)
	_update_quest_ui()


func _on_all_memories_collected() -> void:
	_shrine.is_unlocked = true
	_water.add_ripple(Vector3(-8.0, _water.global_position.y, -8.0), &"memory_complete")
	_show_toast("三段记忆彼此相认，神龛亮起了微光")
	_sync_world_to_narrative()


func _on_ending_choice_selected(choice_id: StringName) -> void:
	if _narrative.choose_alignment(choice_id):
		_sync_world_to_narrative()
		_save_current_game()


func _on_alignment_chosen(alignment_id: StringName, text: String) -> void:
	if alignment_id == &"return_to_lake":
		_water.add_ripple(Vector3(-8.0, _water.global_position.y, -8.0), &"ending")
	_show_toast(text)


func _on_objective_changed(_text: String) -> void:
	_update_quest_ui()


func _on_phase_shift_rejected(reason: String) -> void:
	_show_toast(reason)


func _on_phase_shift_started(_target_phase: StringName) -> void:
	if OS.get_cmdline_args().has("--script"):
		return
	_phase_transition_overlay.visible = true
	var material := _phase_transition_overlay.material as ShaderMaterial
	material.set_shader_parameter("amount", 0.0)
	var tween := create_tween()
	tween.tween_property(material, "shader_parameter/amount", 1.0, 0.1)
	tween.tween_property(material, "shader_parameter/amount", 0.0, 0.18)
	tween.tween_callback(func() -> void: _phase_transition_overlay.visible = false)


func _on_phase_shift_completed(phase: StringName) -> void:
	if _phase_portal != null:
		_phase_portal.set_preview_layer(
			PHASE_SHIFT_CONTROLLER.PRESENT_VISUAL_LAYER
			if phase == &"echo"
			else PHASE_SHIFT_CONTROLLER.ECHO_VISUAL_LAYER
		)
	if phase == &"echo" and _narrative.handle_rift_entered():
		_sync_world_to_narrative()
		_save_current_game()
		if not OS.get_cmdline_args().has("--script"):
			call_deferred("_play_archive_intro_cinematic")
	if _player != null and _player.has_method("set_checkpoint"):
		_player.set_checkpoint(_player.global_transform)
	_show_toast("雨忆时相" if phase == &"echo" else "此岸时相")


func _on_cinematic_started(_sequence_id: StringName) -> void:
	if _cinematic_ui == null:
		return
	_cinematic_ui.visible = true
	_set_gameplay_hud_visible(false)
	_cinematic_subtitle.text = ""
	_cinematic_skip_hint.text = "Enter  跳过镜头"
	if OS.get_cmdline_args().has("--script"):
		return
	_cinematic_top_bar.modulate.a = 0.0
	_cinematic_bottom_bar.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_cinematic_top_bar, "modulate:a", 1.0, 0.28)
	tween.tween_property(_cinematic_bottom_bar, "modulate:a", 1.0, 0.28)


func _on_cinematic_subtitle(text: String) -> void:
	if _cinematic_subtitle != null:
		_cinematic_subtitle.text = text


func _on_cinematic_finished(sequence_id: StringName, _skipped: bool) -> void:
	_set_gameplay_hud_visible(true)
	if _cinematic_ui != null:
		_cinematic_subtitle.text = ""
		if OS.get_cmdline_args().has("--script"):
			_cinematic_ui.visible = false
		else:
			var tween := create_tween().set_parallel(true)
			tween.tween_property(_cinematic_top_bar, "modulate:a", 0.0, 0.22)
			tween.tween_property(_cinematic_bottom_bar, "modulate:a", 0.0, 0.22)
			tween.chain().tween_callback(
				func() -> void: _cinematic_ui.visible = false
			)
	if sequence_id == &"shrine_awaken":
		_show_toast("神龛正在等待你决定如何携带这段记忆")
	elif sequence_id == &"archive_intro":
		_show_toast("档案馆存在于两段时间之间；三个锚点正在等待")
	elif sequence_id == &"city_arrival":
		_show_toast("城市的桥只在雨忆中完整；从门户观察，再决定何时切换")
	elif sequence_id == &"rain_eye_entry":
		_show_toast("道路在两个时相间交替存在；在每段尽头切换")
	elif sequence_id == &"final_decision":
		_show_toast("靠近三枚光核，选择世界今后如何记住")
	elif str(sequence_id).begins_with("epilogue_"):
		_prepare_ending_overlay(_pending_ending_id)
		_show_ending()


func _set_gameplay_hud_visible(value: bool) -> void:
	if _title_label != null:
		_title_label.visible = value
	if _quest_label != null:
		_quest_label.visible = value
	if _chapter_label != null:
		_chapter_label.visible = value
	if _campaign_progress != null:
		_campaign_progress.visible = value
	if _toast_label != null:
		_toast_label.visible = value
	if _player != null:
		var player_hud := _player.get_node_or_null("HUD") as CanvasLayer
		if player_hud != null:
			player_hud.visible = value


func _on_streamed_level_loaded(path: String, instance: Node) -> void:
	if path == ECHO_LEVEL_PATH:
		if _city_present_activated or _rain_eye_present_activated:
			_world_streamer.unload_level(ECHO_LEVEL_PATH)
			return
		if instance.has_signal("archive_anchor_activated"):
			instance.archive_anchor_activated.connect(_on_archive_anchor_activated)
		if instance.has_signal("archive_mechanism_activated"):
			instance.archive_mechanism_activated.connect(_on_archive_mechanism_activated)
		if instance.has_signal("city_gate_entered"):
			instance.city_gate_entered.connect(_on_city_gate_entered)
		_sync_echo_narrative()
		return
	if path == CITY_PRESENT_PATH:
		if _rain_eye_present_activated:
			_world_streamer.unload_level(CITY_PRESENT_PATH)
			return
		_city_present = instance
	elif path == CITY_ECHO_PATH:
		if _rain_eye_present_activated:
			_world_streamer.unload_level(CITY_ECHO_PATH)
			return
		_city_echo = instance
	if path in [CITY_PRESENT_PATH, CITY_ECHO_PATH]:
		if instance.has_signal("city_trace_activated"):
			instance.city_trace_activated.connect(_on_city_trace_activated)
		if instance.has_signal("city_relay_activated"):
			instance.city_relay_activated.connect(_on_city_relay_activated)
		if instance.has_signal("city_testimony_selected"):
			instance.city_testimony_selected.connect(_on_city_testimony_selected)
		if instance.has_signal("rain_eye_gate_entered"):
			instance.rain_eye_gate_entered.connect(_on_rain_eye_gate_entered)
		_sync_city_narrative()
		if path == CITY_PRESENT_PATH and _city_transition_pending:
			call_deferred("_activate_city_present")
		elif _city_present_activated and _city_present != null and _city_echo != null:
			call_deferred("_finish_city_pair_setup")
		return
	if path == RAIN_EYE_PRESENT_PATH:
		_rain_eye_present = instance
	elif path == RAIN_EYE_ECHO_PATH:
		_rain_eye_echo = instance
	else:
		return
	if instance.has_signal("rain_eye_seal_activated"):
		instance.rain_eye_seal_activated.connect(_on_rain_eye_seal_activated)
	if instance.has_signal("rain_eye_trial_activated"):
		instance.rain_eye_trial_activated.connect(_on_rain_eye_trial_activated)
	if instance.has_signal("final_choice_selected"):
		instance.final_choice_selected.connect(_on_final_choice_selected)
	_sync_rain_eye_narrative()
	if path == RAIN_EYE_PRESENT_PATH and _rain_eye_transition_pending:
		call_deferred("_activate_rain_eye_present")
	elif (
		_rain_eye_present_activated
		and _rain_eye_present != null
		and _rain_eye_echo != null
	):
		call_deferred("_finish_rain_eye_pair_setup")


func _on_archive_anchor_activated(anchor_id: StringName) -> void:
	if _narrative.activate_archive_anchor(anchor_id):
		_sync_world_to_narrative()
		_save_current_game()


func _on_archive_anchor_added(
	_anchor_id: StringName,
	text: String,
	_count: int,
) -> void:
	_show_toast(text)


func _on_archive_anchors_completed() -> void:
	_show_toast("锚点已经复原轮廓；真正的档案机关横跨两个时相")


func _on_archive_mechanism_activated(mechanism_id: StringName) -> void:
	if _narrative.activate_archive_mechanism(mechanism_id):
		_sync_world_to_narrative()
		_save_current_game()


func _on_archive_mechanism_added(
	_mechanism_id: StringName,
	text: String,
	_count: int,
) -> void:
	_show_toast(text)


func _on_archive_restored() -> void:
	_show_toast("三道机关彼此校准，远方城门第一次完整出现在雨中")
	if not OS.get_cmdline_args().has("--script"):
		call_deferred("_play_archive_restored_cinematic")


func _on_city_gate_entered() -> void:
	if not _narrative.handle_city_gate_entered():
		return
	_city_arrival_cinematic_pending = true
	_sync_world_to_narrative()
	_save_current_game()
	_begin_city_transition(true)


func _begin_city_transition(from_gate := false) -> void:
	if _city_pair_ready:
		return
	_city_transition_pending = true
	_city_enter_from_gate = _city_enter_from_gate or from_gate
	_world_streamer.max_resident_levels = 3
	_phase_shift.set_unlocked(false)
	if _phase_portal != null:
		_phase_portal.visible = false
	var error: Error = _world_streamer.request_level(CITY_PRESENT_PATH, true)
	if error != OK:
		push_error("Lantern City preload failed: %s" % error_string(error))
		return
	if _world_streamer.is_level_ready(CITY_PRESENT_PATH):
		_city_present = _world_streamer.get_level(CITY_PRESENT_PATH)
		call_deferred("_activate_city_present")
	_show_toast("正在后台拼合行灯之城的两个时相……")


func _activate_city_present() -> void:
	if (
		not _city_transition_pending
		or _city_present_activated
		or _city_present == null
	):
		return
	_phase_shift.suspend_current_pair()
	if not _world_streamer.activate_level(CITY_PRESENT_PATH):
		push_error("Lantern City present scene could not be activated")
		return
	_city_present_activated = true
	_apply_city_environment()
	if _title_label != null:
		_title_label.text = "行灯之城"
	var should_use_city_spawn: bool = (
		_city_enter_from_gate or _narrative.stage == _narrative.CITY_GATE
	)
	if should_use_city_spawn and _city_present.has_method("get_spawn_transform"):
		var spawn_transform: Transform3D = _city_present.get_spawn_transform()
		_player.global_transform = spawn_transform
		_player.velocity = Vector3.ZERO
		_player.set_checkpoint(spawn_transform)
	var arrived_now: bool = _narrative.handle_city_arrived()
	if arrived_now:
		_city_arrival_cinematic_pending = (
			_city_arrival_cinematic_pending or _city_enter_from_gate
		)
	_sync_world_to_narrative()
	if _world_streamer.is_level_ready(ECHO_LEVEL_PATH):
		_world_streamer.unload_level(ECHO_LEVEL_PATH)
	var error: Error = _world_streamer.request_level(CITY_ECHO_PATH, true)
	if error != OK:
		push_error("Lantern City echo preload failed: %s" % error_string(error))
		return
	if _world_streamer.is_level_ready(CITY_ECHO_PATH):
		_city_echo = _world_streamer.get_level(CITY_ECHO_PATH)
		call_deferred("_finish_city_pair_setup")


func _finish_city_pair_setup() -> void:
	if (
		_city_pair_ready
		or not _city_present_activated
		or _city_present == null
		or _city_echo == null
	):
		return
	_apply_city_environment()
	var present_nodes: Array[Node] = [_city_present]
	if not _phase_shift.switch_world_pair(
		present_nodes,
		CITY_PRESENT_PATH,
		CITY_ECHO_PATH,
	):
		return
	_city_pair_ready = true
	_city_transition_pending = false
	_world_streamer.max_resident_levels = 2
	if _world_streamer.is_level_ready(ECHO_LEVEL_PATH):
		_world_streamer.unload_level(ECHO_LEVEL_PATH)
	_phase_portal.position = Vector3(4.2, 1.8, 4.8)
	_phase_portal.rotation_degrees.y = -36.0
	_phase_portal.set_preview_layer(
		PHASE_SHIFT_CONTROLLER.ECHO_VISUAL_LAYER
	)
	_sync_world_to_narrative()
	_save_current_game()
	_city_enter_from_gate = false
	if (
		_city_arrival_cinematic_pending
		and not OS.get_cmdline_args().has("--script")
	):
		_city_arrival_cinematic_pending = false
		call_deferred("_play_city_arrival_cinematic")


func _on_city_trace_activated(trace_id: StringName) -> void:
	if _narrative.activate_city_trace(trace_id):
		_sync_world_to_narrative()
		_save_current_game()


func _on_city_trace_added(
	_trace_id: StringName,
	text: String,
	_count: int,
) -> void:
	_show_toast(text)


func _on_city_traces_completed() -> void:
	_show_toast("三段证词仍互相矛盾；沿街道依次接通四盏主灯")


func _on_city_relay_activated(relay_id: StringName) -> void:
	if _narrative.activate_city_relay(relay_id):
		_sync_world_to_narrative()
		_save_current_game()


func _on_city_relay_added(
	_relay_id: StringName,
	text: String,
	_count: int,
) -> void:
	_show_toast(text)


func _on_city_relays_completed() -> void:
	_show_toast("钟楼主灯已经点亮；朔的两个年龄正在等待你的回应")


func _on_city_testimony_selected(testimony_id: StringName) -> void:
	if _narrative.choose_city_testimony(testimony_id):
		_sync_world_to_narrative()
		_save_current_game()


func _on_city_testimony_chosen(
	_testimony_id: StringName,
	text: String,
) -> void:
	_show_toast(text)


func _on_city_route_completed() -> void:
	_show_toast("证词与行灯回路重叠，雨眼坐标在钟楼上空展开")


func _on_rain_eye_gate_entered() -> void:
	if not _narrative.handle_rain_eye_entered():
		return
	_rain_eye_entry_cinematic_pending = true
	_sync_world_to_narrative()
	_begin_rain_eye_transition()


func _begin_rain_eye_transition() -> void:
	if _rain_eye_pair_ready:
		return
	_rain_eye_transition_pending = true
	_world_streamer.max_resident_levels = 3
	_phase_shift.set_unlocked(false)
	if _phase_portal != null:
		_phase_portal.visible = false
	var error: Error = _world_streamer.request_level(
		RAIN_EYE_PRESENT_PATH,
		true,
	)
	if error != OK:
		push_error("Rain Eye preload failed: %s" % error_string(error))
		return
	if _world_streamer.is_level_ready(RAIN_EYE_PRESENT_PATH):
		_rain_eye_present = _world_streamer.get_level(RAIN_EYE_PRESENT_PATH)
		call_deferred("_activate_rain_eye_present")
	_show_toast("雨眼正在把林地、档案馆与城市折叠到同一条路……")


func _activate_rain_eye_present() -> void:
	if (
		not _rain_eye_transition_pending
		or _rain_eye_present_activated
		or _rain_eye_present == null
	):
		return
	_phase_shift.suspend_current_pair()
	if not _world_streamer.activate_level(RAIN_EYE_PRESENT_PATH):
		push_error("Rain Eye present scene could not be activated")
		return
	_rain_eye_present_activated = true
	_city_pair_ready = false
	_apply_rain_eye_environment()
	if _title_label != null:
		_title_label.text = "雨眼"
	if (
		_rain_eye_entry_cinematic_pending
		and _rain_eye_present.has_method("get_spawn_transform")
	):
		var spawn_transform: Transform3D = _rain_eye_present.get_spawn_transform()
		_player.global_transform = spawn_transform
		_player.velocity = Vector3.ZERO
		_player.set_checkpoint(spawn_transform)
	for old_path in [CITY_PRESENT_PATH, CITY_ECHO_PATH, ECHO_LEVEL_PATH]:
		if _world_streamer.is_level_ready(old_path):
			_world_streamer.unload_level(old_path)
	_sync_world_to_narrative()
	var error: Error = _world_streamer.request_level(
		RAIN_EYE_ECHO_PATH,
		true,
	)
	if error != OK:
		push_error("Rain Eye echo preload failed: %s" % error_string(error))
		return
	if _world_streamer.is_level_ready(RAIN_EYE_ECHO_PATH):
		_rain_eye_echo = _world_streamer.get_level(RAIN_EYE_ECHO_PATH)
		call_deferred("_finish_rain_eye_pair_setup")


func _finish_rain_eye_pair_setup() -> void:
	if (
		_rain_eye_pair_ready
		or not _rain_eye_present_activated
		or _rain_eye_present == null
		or _rain_eye_echo == null
	):
		return
	_apply_rain_eye_environment()
	var present_nodes: Array[Node] = [_rain_eye_present]
	if not _phase_shift.switch_world_pair(
		present_nodes,
		RAIN_EYE_PRESENT_PATH,
		RAIN_EYE_ECHO_PATH,
	):
		return
	_rain_eye_pair_ready = true
	_rain_eye_transition_pending = false
	_world_streamer.max_resident_levels = 2
	for old_path in [CITY_PRESENT_PATH, CITY_ECHO_PATH, ECHO_LEVEL_PATH]:
		if _world_streamer.is_level_ready(old_path):
			_world_streamer.unload_level(old_path)
	_phase_portal.position = Vector3(3.7, 1.8, 8.2)
	_phase_portal.rotation_degrees.y = -32.0
	_phase_portal.set_preview_layer(
		PHASE_SHIFT_CONTROLLER.ECHO_VISUAL_LAYER
	)
	_sync_world_to_narrative()
	_save_current_game()
	if (
		_narrative.stage == _narrative.COMPLETE
		and not _narrative.ending_id.is_empty()
		and not _rain_eye_entry_cinematic_pending
	):
		_prepare_ending_overlay(_narrative.ending_id)
		_ending_overlay.visible = true
		_ending_overlay.color.a = 0.82
		_ending_label.modulate.a = 1.0
	if (
		_rain_eye_entry_cinematic_pending
		and not OS.get_cmdline_args().has("--script")
	):
		_rain_eye_entry_cinematic_pending = false
		call_deferred("_play_rain_eye_entry_cinematic")


func _on_rain_eye_seal_activated(seal_id: StringName) -> void:
	if _narrative.activate_rain_eye_seal(seal_id):
		_sync_world_to_narrative()
		_save_current_game()


func _on_rain_eye_seal_added(
	_seal_id: StringName,
	text: String,
	_count: int,
) -> void:
	_show_toast(text)


func _on_rain_eye_seals_completed() -> void:
	_show_toast("归档只保存了过去；沿交替道路证明世界仍能前进")


func _on_rain_eye_trial_activated(trial_id: StringName) -> void:
	if _narrative.activate_rain_eye_trial(trial_id):
		_sync_world_to_narrative()
		_save_current_game()


func _on_rain_eye_trial_added(
	_trial_id: StringName,
	text: String,
	_count: int,
) -> void:
	_show_toast(text)


func _on_final_decision_ready() -> void:
	_show_toast("三次归档完成：世界正在等待一种新的记忆秩序")
	if not OS.get_cmdline_args().has("--script"):
		call_deferred("_play_final_decision_cinematic")


func _on_final_choice_selected(choice_id: StringName) -> void:
	if _narrative.choose_ending(choice_id):
		_sync_world_to_narrative()
		_save_current_game()


func _on_final_ending_chosen(
	ending_id: StringName,
	text: String,
) -> void:
	_pending_ending_id = ending_id
	_show_toast(text)
	if OS.get_cmdline_args().has("--script"):
		_prepare_ending_overlay(ending_id)
		_ending_overlay.visible = true
		_ending_overlay.color.a = 0.82
		_ending_label.modulate.a = 1.0
	else:
		call_deferred("_play_epilogue_cinematic", ending_id)


func _play_intro_cinematic() -> void:
	var shots: Array[Dictionary] = [
		{
			"position": Vector3(-11.0, 6.2, 12.0),
			"look_at": Vector3(-7.5, 0.2, -7.0),
			"fov": 55.0,
			"duration": 3.2,
			"subtitle": "雨记得每一片叶子。",
		},
		{
			"position": Vector3(-3.5, 3.6, 8.5),
			"look_at": Vector3(-2.2, 1.0, -2.0),
			"fov": 59.0,
			"duration": 2.8,
			"subtitle": "但它忘记了如何落下。",
		},
	]
	_cinematic_director.play_sequence(&"intro", shots)


func _play_shrine_awaken_cinematic() -> void:
	var shots: Array[Dictionary] = [
		{
			"position": Vector3(3.8, 2.7, -1.2),
			"look_at": Vector3(0.0, 1.9, -6.0),
			"fov": 48.0,
			"duration": 2.4,
			"subtitle": "被雨忘记的不是名字。",
		},
		{
			"position": Vector3(-7.8, 4.8, -0.4),
			"look_at": Vector3(-8.0, 0.0, -8.0),
			"fov": 52.0,
			"duration": 2.8,
			"subtitle": "是它该流向哪里。",
		},
		{
			"position": Vector3(5.5, 2.2, 1.2),
			"look_at": Vector3(5.2, 1.8, -2.2),
			"fov": 44.0,
			"duration": 2.3,
			"subtitle": "一道雨隙，在两个时相之间睁开。",
		},
	]
	_cinematic_director.play_sequence(&"shrine_awaken", shots)


func _play_archive_intro_cinematic() -> void:
	var shots: Array[Dictionary] = [
		{
			"position": Vector3(0.0, 6.4, 12.0),
			"look_at": Vector3(0.0, 1.8, -4.0),
			"fov": 58.0,
			"duration": 2.8,
			"subtitle": "沉雨档案馆没有保存过去。",
		},
		{
			"position": Vector3(4.8, 2.7, 6.8),
			"look_at": Vector3(-2.8, 1.2, 4.0),
			"fov": 46.0,
			"duration": 2.3,
			"subtitle": "它把每一次遗忘，变成另一条能够行走的路。",
		},
		{
			"position": Vector3(-2.5, 3.6, -0.5),
			"look_at": Vector3(0.0, 1.2, -5.0),
			"fov": 43.0,
			"duration": 2.5,
			"subtitle": "唤醒三个锚点，让断开的时间重新对齐。",
		},
	]
	_cinematic_director.play_sequence(&"archive_intro", shots)


func _play_archive_restored_cinematic() -> void:
	var shots: Array[Dictionary] = [
		{
			"position": Vector3(5.4, 2.8, -9.0),
			"look_at": Vector3(2.8, 1.3, -14.0),
			"fov": 42.0,
			"duration": 2.2,
			"subtitle": "声音、形状与名字重新锚定。",
		},
		{
			"position": Vector3(-1.0, 5.8, -7.0),
			"look_at": Vector3(0.0, 1.4, -17.0),
			"fov": 54.0,
			"duration": 2.9,
			"subtitle": "雨幕背后，行灯之城亮起第一扇门。",
		},
	]
	_cinematic_director.play_sequence(&"archive_restored", shots)


func _play_city_arrival_cinematic() -> void:
	var shots: Array[Dictionary] = [
		{
			"position": Vector3(-4.6, 6.8, 18.0),
			"look_at": Vector3(0.0, 1.4, 0.0),
			"fov": 55.0,
			"duration": 3.0,
			"subtitle": "行灯之城仍在下雨，只是此岸已经无人记得为何点灯。",
		},
		{
			"position": Vector3(5.8, 3.1, 2.5),
			"look_at": Vector3(-2.0, 1.1, -3.0),
			"fov": 46.0,
			"duration": 2.6,
			"subtitle": "另一段时间里，集市、列车与守灯人从未停下。",
		},
		{
			"position": Vector3(-2.8, 4.6, -2.5),
			"look_at": Vector3(0.0, -0.1, -7.0),
			"fov": 44.0,
			"duration": 2.5,
			"subtitle": "断桥并不存在于每一个时相。先看见，再跨过去。",
		},
	]
	_cinematic_director.play_sequence(&"city_arrival", shots)


func _play_rain_eye_entry_cinematic() -> void:
	var shots: Array[Dictionary] = [
		{
			"position": Vector3(0.0, 6.6, 18.0),
			"look_at": Vector3(0.0, 0.4, 5.0),
			"fov": 52.0,
			"duration": 2.8,
			"subtitle": "雨眼没有重新创造世界，它只把无法共存的部分叠在一起。",
		},
		{
			"position": Vector3(-5.8, 4.2, 3.0),
			"look_at": Vector3(0.0, 7.8, -4.0),
			"fov": 47.0,
			"duration": 2.6,
			"subtitle": "湖泊倒悬在城市上空，档案碎片仍在继续坠落。",
		},
		{
			"position": Vector3(3.6, 2.5, -7.0),
			"look_at": Vector3(0.0, 0.2, -15.0),
			"fov": 43.0,
			"duration": 2.8,
			"subtitle": "完成三次归档，然后决定什么值得被永久记住。",
		},
	]
	_cinematic_director.play_sequence(&"rain_eye_entry", shots)


func _play_final_decision_cinematic() -> void:
	var shots: Array[Dictionary] = [
		{
			"position": Vector3(-4.8, 3.0, -14.5),
			"look_at": Vector3(0.0, 1.2, -20.0),
			"fov": 45.0,
			"duration": 3.0,
			"subtitle": "合流会带回完整记忆，也会让所有失去重新发生。",
		},
		{
			"position": Vector3(4.6, 2.4, -18.0),
			"look_at": Vector3(0.0, 1.15, -20.4),
			"fov": 41.0,
			"duration": 3.2,
			"subtitle": "守界、合流或潮汐——这一次，选择不再由朔替世界做出。",
		},
	]
	_cinematic_director.play_sequence(&"final_decision", shots)


func _play_epilogue_cinematic(ending_id: StringName) -> void:
	var ending_subtitles := {
		&"merge_worlds": [
			"两个时相终于同时迎来清晨。",
			"人们取回失去的名字，也重新学会与失去共同生活。",
		],
		&"guard_boundary": [
			"两场雨继续落在各自的世界。",
			"霁成为边界上唯一的行灯，让记忆不再被迫选择一侧。",
		],
		&"tidal_order": [
			"记住与遗忘开始像潮汐一样往复。",
			"世界不再追求永恒，只保证每段记忆都有回来的一天。",
		],
	}
	var subtitles: Array = ending_subtitles.get(
		ending_id,
		["雨终于继续落下。", "而世界记住了霁的名字。"],
	)
	var shots: Array[Dictionary] = [
		{
			"position": Vector3(0.0, 7.5, -10.0),
			"look_at": Vector3(0.0, 0.6, -19.5),
			"fov": 50.0,
			"duration": 4.0,
			"subtitle": str(subtitles[0]),
		},
		{
			"position": Vector3(-6.0, 4.0, 4.0),
			"look_at": Vector3(0.0, 7.5, -3.0),
			"fov": 48.0,
			"duration": 4.2,
			"subtitle": str(subtitles[1]),
		},
	]
	_cinematic_director.play_sequence(
		StringName("epilogue_" + str(ending_id)),
		shots,
	)


func _apply_city_environment() -> void:
	var environment := _world_environment.environment
	environment.background_energy_multiplier = 0.24
	environment.fog_light_color = Color("586f79")
	environment.fog_density = 0.018
	environment.volumetric_fog_density = 0.025
	environment.volumetric_fog_albedo = Color("587780")
	environment.volumetric_fog_emission = Color("182f36")
	environment.volumetric_fog_emission_energy = 0.18
	environment.glow_intensity = 0.92
	_sun.light_color = Color("91aec2")
	_sun.light_energy = 0.48
	_sun.rotation_degrees = Vector3(-58.0, 24.0, 0.0)
	_apply_quality_profile()


func _apply_rain_eye_environment() -> void:
	var environment := _world_environment.environment
	environment.background_energy_multiplier = 0.12
	environment.fog_light_color = Color("244f5a")
	environment.fog_density = 0.026
	environment.volumetric_fog_density = 0.038
	environment.volumetric_fog_albedo = Color("356b72")
	environment.volumetric_fog_emission = Color("123b42")
	environment.volumetric_fog_emission_energy = 0.34
	environment.glow_intensity = 1.18
	_sun.light_color = Color("70e0dd")
	_sun.light_energy = 0.34
	_sun.rotation_degrees = Vector3(-32.0, -42.0, 18.0)
	_apply_quality_profile()


func _update_quest_ui() -> void:
	if _quest_label == null:
		return
	_quest_label.text = "当前目标：" + _narrative.get_objective()
	if _chapter_label != null:
		_chapter_label.text = _narrative.get_chapter_title()
	if _campaign_progress != null:
		_campaign_progress.value = _narrative.get_campaign_progress()


func _show_toast(message: String) -> void:
	_toast_label.text = message
	if OS.get_cmdline_args().has("--script"):
		return
	var tween := create_tween()
	tween.tween_interval(3.0)
	tween.tween_callback(func() -> void: _toast_label.text = "")


func _create_phase_transition_ui(canvas: CanvasLayer) -> void:
	_phase_transition_overlay = ColorRect.new()
	_phase_transition_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_phase_transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 center = UV - vec2(0.5);
	vec2 direction = normalize(center + vec2(0.0001));
	float rain = sin(UV.y * 110.0 + TIME * 18.0) * 0.5 + 0.5;
	vec2 displaced_uv = clamp(
		SCREEN_UV + direction * amount * 0.035 + vec2(0.0, rain * amount * 0.008),
		vec2(0.001),
		vec2(0.999)
	);
	vec3 scene = texture(screen_texture, displaced_uv).rgb;
	vec3 shifted = mix(scene, vec3(0.05, 0.42, 0.47), amount * 0.58);
	COLOR = vec4(shifted, amount * 0.86);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	_phase_transition_overlay.material = material
	_phase_transition_overlay.visible = false
	canvas.add_child(_phase_transition_overlay)


func _create_cinematic_ui(canvas: CanvasLayer) -> void:
	_cinematic_ui = Control.new()
	_cinematic_ui.name = "CinematicUI"
	_cinematic_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cinematic_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cinematic_ui.z_index = 40
	_cinematic_ui.visible = false
	canvas.add_child(_cinematic_ui)

	_cinematic_top_bar = ColorRect.new()
	_cinematic_top_bar.color = Color(0.005, 0.012, 0.015, 0.98)
	_cinematic_top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_cinematic_top_bar.offset_bottom = 78.0
	_cinematic_top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cinematic_ui.add_child(_cinematic_top_bar)

	_cinematic_bottom_bar = ColorRect.new()
	_cinematic_bottom_bar.color = Color(0.005, 0.012, 0.015, 0.98)
	_cinematic_bottom_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_cinematic_bottom_bar.offset_top = -112.0
	_cinematic_bottom_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cinematic_ui.add_child(_cinematic_bottom_bar)

	_cinematic_subtitle = Label.new()
	_cinematic_subtitle.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_cinematic_subtitle.offset_top = -92.0
	_cinematic_subtitle.offset_bottom = -38.0
	_cinematic_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cinematic_subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cinematic_subtitle.add_theme_font_size_override("font_size", 24)
	_cinematic_subtitle.add_theme_color_override("font_color", Color("eefbf4"))
	_cinematic_subtitle.add_theme_color_override(
		"font_shadow_color",
		Color(0.0, 0.0, 0.0, 0.85)
	)
	_cinematic_subtitle.add_theme_constant_override("shadow_offset_x", 2)
	_cinematic_subtitle.add_theme_constant_override("shadow_offset_y", 2)
	_cinematic_ui.add_child(_cinematic_subtitle)

	_cinematic_skip_hint = Label.new()
	_cinematic_skip_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_cinematic_skip_hint.position = Vector2(-188.0, -34.0)
	_cinematic_skip_hint.size = Vector2(168.0, 24.0)
	_cinematic_skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_cinematic_skip_hint.add_theme_font_size_override("font_size", 14)
	_cinematic_skip_hint.add_theme_color_override(
		"font_color",
		Color(0.7, 0.82, 0.8, 0.82)
	)
	_cinematic_ui.add_child(_cinematic_skip_hint)


func _create_ending_ui(canvas: CanvasLayer) -> void:
	_ending_overlay = ColorRect.new()
	_ending_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ending_overlay.color = Color(0.025, 0.075, 0.07, 0.0)
	_ending_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ending_overlay.visible = false
	canvas.add_child(_ending_overlay)

	_ending_label = Label.new()
	_ending_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_ending_label.position = Vector2(-260.0, -60.0)
	_ending_label.size = Vector2(520.0, 120.0)
	_ending_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ending_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ending_label.add_theme_font_size_override("font_size", 28)
	_ending_label.add_theme_color_override("font_color", Color("e8ffe9"))
	_ending_label.text = "林地回应了你的呼唤\n\n微光重新流淌"
	_ending_label.modulate.a = 0.0
	_ending_overlay.add_child(_ending_label)


func _play_opening_fade(canvas: CanvasLayer) -> void:
	var fade := ColorRect.new()
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0.015, 0.035, 0.032, 1.0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(fade)
	var tween := create_tween()
	tween.tween_interval(0.2)
	tween.tween_property(fade, "color:a", 0.0, 1.4).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(fade.queue_free)


func _show_ending() -> void:
	_ending_overlay.color.a = 0.0
	_ending_label.modulate.a = 0.0
	_ending_overlay.visible = true
	var tween := create_tween()
	tween.tween_interval(1.2)
	tween.tween_property(_ending_overlay, "color:a", 0.82, 1.8).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(_ending_label, "modulate:a", 1.0, 2.1)


func _prepare_ending_overlay(ending_id: StringName) -> void:
	match ending_id:
		&"merge_worlds":
			_ending_label.text = "合流结局\n\n两个时相共同迎来雨后清晨"
			_ending_label.add_theme_color_override("font_color", Color("b9fff1"))
		&"guard_boundary":
			_ending_label.text = "守界结局\n\n霁成为往返两场雨之间的行灯"
			_ending_label.add_theme_color_override("font_color", Color("ffe0a8"))
		&"tidal_order":
			_ending_label.text = "潮汐结局\n\n记住与遗忘从此按季节流动"
			_ending_label.add_theme_color_override("font_color", Color("d9bdff"))
		_:
			_ending_label.text = "旅程完成\n\n雨终于继续落下"


func _save_current_game() -> bool:
	if _player == null:
		return false
	var error: Error = SaveService.save_game(&"luminous_grove", _player)
	if error != OK:
		push_error("Could not save game: %s" % error_string(error))
		if _toast_label != null:
			_show_toast("保存失败：" + error_string(error))
		return false
	return true


func _restore_saved_game() -> bool:
	var state := SaveService.load_game()
	if state.is_empty():
		_update_quest_ui()
		return false
	var coordinates: Array = state.get("player_position", [])
	if coordinates.size() == 3:
		_player.global_position = Vector3(
			float(coordinates[0]),
			float(coordinates[1]),
			float(coordinates[2])
		)
		if _player.has_method("set_checkpoint"):
			_player.set_checkpoint(_player.global_transform)
	var rotation_values: Array = state.get("player_rotation", [])
	if rotation_values.size() == 3:
		_player.global_rotation = Vector3(
			float(rotation_values[0]),
			float(rotation_values[1]),
			float(rotation_values[2]),
		)
	var world_state: Dictionary = state.get("world_state", {})
	for persistent_node in get_tree().get_nodes_in_group("persistent"):
		var persistent_id: String = str(persistent_node.get("persistent_id"))
		if world_state.has(persistent_id) and persistent_node.has_method("restore_state"):
			persistent_node.restore_state(world_state[persistent_id])
	if not world_state.has(str(_narrative.persistent_id)):
		_migrate_legacy_narrative()
	_sync_world_to_narrative()
	_update_quest_ui()
	if SaveService.last_load_used_backup:
		_show_toast("主存档损坏，已从安全备份恢复")
	return true


func _migrate_legacy_narrative() -> void:
	_narrative.stage = _narrative.FIND_BELL
	if _wind_bell.is_rung:
		_narrative.stage = _narrative.GATHER_MEMORIES
	if _shrine.is_activated:
		_narrative.collected_memories.assign(_narrative.MEMORY_TEXT.keys())
		_narrative.stage = _narrative.MEMORY_ALIGNMENT


func _sync_world_to_narrative() -> void:
	var needs_city_world: bool = (
		_narrative.stage in [
			_narrative.CITY_GATE,
			_narrative.LANTERN_CITY,
			_narrative.CITY_RELAYS,
			_narrative.CITY_COUNCIL,
		]
		or (
			_narrative.stage == _narrative.RAIN_EYE
			and not _narrative.has_entered_rain_eye
		)
	)
	var needs_rain_eye_world: bool = (
		_narrative.has_entered_rain_eye
		and _narrative.stage in [
			_narrative.RAIN_EYE,
			_narrative.RAIN_EYE_TRIALS,
			_narrative.FINAL_DECISION,
			_narrative.COMPLETE,
		]
	)
	var memories_available: bool = _narrative.stage == _narrative.GATHER_MEMORIES
	for droplet in _memory_droplets:
		droplet.set_available(memories_available)
	_shrine.is_unlocked = _narrative.stage in [
		_narrative.AWAKEN_SHRINE,
		_narrative.MEMORY_ALIGNMENT,
		_narrative.RIFT_READY,
		_narrative.ARCHIVE_SEARCH,
		_narrative.ARCHIVE_MECHANISMS,
		_narrative.ARCHIVE_RESTORED,
		_narrative.CITY_GATE,
		_narrative.LANTERN_CITY,
		_narrative.CITY_RELAYS,
		_narrative.CITY_COUNCIL,
		_narrative.RAIN_EYE,
		_narrative.RAIN_EYE_TRIALS,
		_narrative.FINAL_DECISION,
		_narrative.COMPLETE,
	]
	var choices_available: bool = _narrative.stage == _narrative.MEMORY_ALIGNMENT
	for choice in _ending_choices:
		choice.set_available(choices_available)
	if _phase_shift != null:
		var shift_unlocked: bool = _narrative.stage in [
			_narrative.RIFT_READY,
			_narrative.ARCHIVE_SEARCH,
			_narrative.ARCHIVE_MECHANISMS,
			_narrative.ARCHIVE_RESTORED,
			_narrative.CITY_GATE,
			_narrative.LANTERN_CITY,
			_narrative.CITY_RELAYS,
			_narrative.CITY_COUNCIL,
			_narrative.RAIN_EYE,
			_narrative.RAIN_EYE_TRIALS,
			_narrative.FINAL_DECISION,
			_narrative.COMPLETE,
		]
		if needs_city_world:
			shift_unlocked = shift_unlocked and _city_pair_ready
		elif needs_rain_eye_world:
			shift_unlocked = shift_unlocked and _rain_eye_pair_ready
		_phase_shift.set_unlocked(shift_unlocked)
		if _phase_portal != null:
			_phase_portal.visible = shift_unlocked
	_sync_echo_narrative()
	_sync_archive_present_mechanisms()
	_sync_city_narrative()
	_sync_rain_eye_narrative()
	if needs_city_world and not _city_pair_ready:
		call_deferred("_begin_city_transition")
	elif needs_rain_eye_world and not _rain_eye_pair_ready:
		call_deferred("_begin_rain_eye_transition")


func _sync_echo_narrative() -> void:
	if _world_streamer == null:
		return
	var echo = _world_streamer.get_level(
		ECHO_LEVEL_PATH
	)
	if echo == null or not echo.has_method("sync_archive_state"):
		return
	echo.sync_archive_state(
		_narrative.stage == _narrative.ARCHIVE_SEARCH,
		_narrative.activated_archive_anchors,
		_narrative.stage == _narrative.ARCHIVE_MECHANISMS,
		_narrative.activated_archive_mechanisms,
		_narrative.get_next_archive_mechanism(),
		_narrative.stage == _narrative.ARCHIVE_RESTORED,
	)


func _sync_archive_present_mechanisms() -> void:
	for mechanism in _archive_present_mechanisms:
		mechanism.set_activated(
			_narrative.activated_archive_mechanisms.has(mechanism.resonance_id)
		)
		mechanism.set_available(
			_narrative.stage == _narrative.ARCHIVE_MECHANISMS
			and mechanism.resonance_id == _narrative.get_next_archive_mechanism()
		)


func _sync_city_narrative() -> void:
	if _world_streamer == null:
		return
	for path in [CITY_PRESENT_PATH, CITY_ECHO_PATH]:
		var city = _world_streamer.get_level(path)
		if city == null or not city.has_method("sync_city_state"):
			continue
		city.sync_city_state(
			_narrative.stage == _narrative.LANTERN_CITY,
			_narrative.activated_city_traces,
			_narrative.stage == _narrative.CITY_RELAYS,
			_narrative.activated_city_relays,
			_narrative.get_next_city_relay(),
			_narrative.stage == _narrative.CITY_COUNCIL,
			_narrative.city_testimony_id,
			(
				_narrative.stage == _narrative.RAIN_EYE
				and not _narrative.has_entered_rain_eye
			),
		)


func _sync_rain_eye_narrative() -> void:
	if _world_streamer == null:
		return
	for path in [RAIN_EYE_PRESENT_PATH, RAIN_EYE_ECHO_PATH]:
		var rain_eye = _world_streamer.get_level(path)
		if rain_eye == null or not rain_eye.has_method("sync_rain_eye_state"):
			continue
		rain_eye.sync_rain_eye_state(
			(
				_narrative.stage == _narrative.RAIN_EYE
				and _narrative.has_entered_rain_eye
			),
			_narrative.activated_rain_eye_seals,
			_narrative.stage == _narrative.RAIN_EYE_TRIALS,
			_narrative.activated_rain_eye_trials,
			_narrative.get_next_rain_eye_trial(),
			_narrative.stage == _narrative.FINAL_DECISION,
			_narrative.ending_id,
			_narrative.get_available_endings(),
		)


func _standard_material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


func _ground_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/forest_terrain.gdshader")
	# The shader consumes the same explicit profiles used by SurfaceProbe and
	# Jolt. This keeps visual maps and surface physics from drifting apart when
	# a scanned material is replaced.
	var ground_albedo := _profile_texture(&"dry_soil", &"albedo_texture")
	var ground_normal := _profile_texture(&"dry_soil", &"normal_texture")
	var ground_roughness := _profile_texture(&"dry_soil", &"roughness_texture")
	var ground_ao := _profile_texture(&"dry_soil", &"ao_texture")
	var ground_cavity := _profile_texture(&"dry_soil", &"cavity_texture")
	var ground_height := _profile_texture(&"dry_soil", &"height_texture")
	var mud_albedo := _profile_texture(&"wet_mud", &"albedo_texture")
	var leaves_albedo := _profile_texture(&"moss", &"albedo_texture")
	if ground_albedo == null:
		ground_albedo = GROUND_ALBEDO_V2
	if ground_normal == null:
		ground_normal = GROUND_NORMAL
	if ground_roughness == null:
		ground_roughness = GROUND_ROUGHNESS
	if ground_ao == null:
		ground_ao = load("res://content/environments/ground/ao.png")
	if ground_cavity == null:
		ground_cavity = load("res://content/environments/ground/cavity.png")
	if ground_height == null:
		ground_height = load("res://content/environments/ground/height.png")
	material.set_shader_parameter("albedo_texture", ground_albedo)
	material.set_shader_parameter("normal_texture", ground_normal)
	material.set_shader_parameter("roughness_texture", ground_roughness)
	material.set_shader_parameter(
		"dry_albedo_texture",
		ground_albedo,
	)
	material.set_shader_parameter(
		"wet_albedo_texture",
		mud_albedo
			if mud_albedo != null
			else load("res://content/environments/ground/forest_ground_albedo.png"),
	)
	material.set_shader_parameter(
		"leaf_albedo_texture",
		leaves_albedo
			if leaves_albedo != null
			else load("res://content/materials/foliage/albedo.png"),
	)
	material.set_shader_parameter("detail_normal_texture", ground_normal)
	material.set_shader_parameter("ao_texture", ground_ao)
	material.set_shader_parameter("cavity_texture", ground_cavity)
	material.set_shader_parameter("height_texture", ground_height)
	material.set_shader_parameter("detail_maps_enabled", true)
	material.set_shader_parameter("wetness", 0.54)
	material.set_shader_parameter("rain_intensity", 0.68)
	return material


func _pbr_material(
	folder: String,
	tint: Color,
	triplanar: bool,
	uv_scale: Vector3,
) -> StandardMaterial3D:
	var root := "res://content/materials/" + folder + "/"
	var surface_type := _surface_type_for_material_folder(folder)
	if folder == "bark" and _load_material_texture(
		"res://content/materials/scanned/pine_bark/",
		"albedo",
	) != null:
		root = "res://content/materials/scanned/pine_bark/"
	if folder == "lake_stone" and _load_material_texture(
		"res://content/materials/scanned/lake_stone/",
		"albedo",
	) != null:
		root = "res://content/materials/scanned/lake_stone/"
	var material := StandardMaterial3D.new()
	material.albedo_texture = _profile_texture(surface_type, &"albedo_texture")
	if material.albedo_texture == null:
		material.albedo_texture = _load_material_texture(root, "albedo")
	material.albedo_color = tint
	material.normal_enabled = true
	material.normal_texture = _profile_texture(surface_type, &"normal_texture")
	if material.normal_texture == null:
		material.normal_texture = _load_material_texture(root, "normal")
	material.normal_scale = 0.78
	var profile := _surface_library.get_profile(surface_type) as MaterialProfile if (
		_surface_library != null and not surface_type.is_empty()
	) else null
	material.roughness = profile.roughness if profile != null else 1.0
	material.roughness_texture = _profile_texture(surface_type, &"roughness_texture")
	if material.roughness_texture == null:
		material.roughness_texture = _load_material_texture(root, "roughness")
	var ao_texture := _profile_texture(surface_type, &"ao_texture")
	if ao_texture == null:
		ao_texture = _load_material_texture(root, "ao")
	if ao_texture != null:
		material.ao_enabled = true
		material.ao_texture = ao_texture
		material.ao_light_affect = 0.72
	var height_texture := _profile_texture(surface_type, &"height_texture")
	if height_texture == null:
		height_texture = _load_material_texture(root, "height")
	if height_texture != null and not triplanar:
		material.heightmap_enabled = true
		material.heightmap_texture = height_texture
		material.heightmap_scale = 0.035
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.uv1_scale = uv_scale
	material.uv1_triplanar = triplanar
	material.uv1_world_triplanar = triplanar
	return material


func _surface_type_for_material_folder(folder: String) -> StringName:
	match folder:
		"bark":
			return &"wood"
		"lake_stone":
			return &"stone"
		"foliage":
			return &"moss"
		"forest_path":
			return &"wet_mud"
		"forest_ground", "ground":
			return &"dry_soil"
	return &""


func _profile_texture(surface_type: StringName, property: StringName) -> Texture2D:
	if _surface_library == null or surface_type.is_empty():
		return null
	var profile := _surface_library.get_profile(surface_type) as MaterialProfile
	if profile == null:
		return null
	return profile.get(property) as Texture2D


func _load_material_texture(root: String, stem: String) -> Texture2D:
	for extension in ["png", "jpg", "jpeg", "exr"]:
		var path: String = root + stem + "." + extension
		if FileAccess.file_exists(ProjectSettings.globalize_path(path)):
			var texture := load(path) as Texture2D
			if texture != null:
				return texture
	return null


func _set_visual_layer(root: Node, visual_layer: int) -> void:
	var visuals: Array[Node] = []
	if root is VisualInstance3D:
		visuals.append(root)
	visuals.append_array(root.find_children("*", "VisualInstance3D", true, false))
	for node in visuals:
		(node as VisualInstance3D).layers = visual_layer


func _path_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roughness_texture : hint_roughness_r, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float wetness : hint_range(0.0, 1.0) = 0.54;
uniform float rain_intensity : hint_range(0.0, 1.0) = 0.62;
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 world_uv = world_position.xz * 0.38;
	vec4 soil = texture(albedo_texture, world_uv);
	float edge = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	float feather = smoothstep(0.0, 0.115, edge);
	vec3 wet_soil = soil.rgb * vec3(0.48, 0.55, 0.52);
	ALBEDO = mix(soil.rgb * vec3(0.86, 0.82, 0.74), wet_soil, wetness * 0.62);
	NORMAL_MAP = texture(normal_texture, world_uv).rgb;
	NORMAL_MAP_DEPTH = 0.58;
	ROUGHNESS = mix(texture(roughness_texture, world_uv).r, 0.26, wetness * 0.7);
	SPECULAR = mix(0.32, 0.72, wetness);
	EMISSION = vec3(0.02, 0.05, 0.045) * rain_intensity * wetness * 0.025;
	ALPHA = feather;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	var mud_root := "res://content/materials/scanned/mud_forest/"
	var fallback_root := "res://content/materials/forest_path/"
	material.set_shader_parameter(
		"albedo_texture",
		_load_material_texture(mud_root, "albedo")
			if _load_material_texture(mud_root, "albedo") != null
			else _load_material_texture(fallback_root, "albedo"),
	)
	material.set_shader_parameter(
		"normal_texture",
		_load_material_texture(mud_root, "normal")
			if _load_material_texture(mud_root, "normal") != null
			else _load_material_texture(fallback_root, "normal"),
	)
	material.set_shader_parameter(
		"roughness_texture",
		_load_material_texture(mud_root, "roughness")
			if _load_material_texture(mud_root, "roughness") != null
			else _load_material_texture(fallback_root, "roughness"),
	)
	return material
