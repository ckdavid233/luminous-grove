extends Node3D

const PRESENT_VISUAL_LAYER := 1 << 0
const ECHO_VISUAL_LAYER := 1 << 1
const CITY_TRACE := preload("res://game/narrative/city_trace.gd")
const CITY_GATE := preload("res://game/narrative/city_gate.gd")
const STORY_RESONATOR := preload("res://game/narrative/story_resonator.gd")
const ENDING_CHOICE_SCENE := preload("res://game/narrative/ending_choice.tscn")

signal city_trace_activated(trace_id: StringName)
signal city_relay_activated(relay_id: StringName)
signal city_testimony_selected(testimony_id: StringName)
signal rain_eye_gate_entered

@export var is_echo := false

var _visual_layer := PRESENT_VISUAL_LAYER
var _rng := RandomNumberGenerator.new()
var _traces: Array[Node] = []
var _relays: Array[Node] = []
var _testimony_choices: Array[Node] = []
var _rain_eye_gate: Node
var _train: AnimatableBody3D
var _train_time := 0.0
var _stone_material: StandardMaterial3D
var _wall_material: StandardMaterial3D
var _metal_material: StandardMaterial3D
var _window_material: StandardMaterial3D


func _exit_tree() -> void:
	_stone_material = null
	_wall_material = null
	_metal_material = null
	_window_material = null
	_traces.clear()
	_relays.clear()
	_testimony_choices.clear()
	_rain_eye_gate = null
	_train = null
	_rng = null


func _ready() -> void:
	_visual_layer = ECHO_VISUAL_LAYER if is_echo else PRESENT_VISUAL_LAYER
	_rng.seed = 0xEC401 if is_echo else 0xC17A
	set_meta("stream_keep_visual_when_inactive", true)
	_create_materials()
	_create_streets()
	_create_canal()
	_create_buildings()
	_create_lantern_avenue()
	_create_market()
	_create_train()
	_create_physics_props()
	_create_rain()
	_create_traces()
	_create_relays()
	_create_testimony_choices()
	_create_rain_eye_gate()
	_set_visual_layer(self, _visual_layer)


func _physics_process(delta: float) -> void:
	if _train == null or not is_echo:
		return
	_train_time += delta
	var travel := fmod(_train_time * 4.5, 48.0)
	_train.position.z = 19.0 - travel


func sync_city_state(
	traces_available: bool,
	activated_trace_ids: Array[StringName],
	relays_available := false,
	activated_relay_ids: Array[StringName] = [],
	next_relay_id: StringName = &"",
	testimony_available := false,
	testimony_id: StringName = &"",
	rain_eye_gate_available := false,
) -> void:
	for trace in _traces:
		trace.set_activated(activated_trace_ids.has(trace.trace_id))
		trace.set_available(traces_available)
	for relay in _relays:
		relay.set_activated(activated_relay_ids.has(relay.resonance_id))
		relay.set_available(
			relays_available and relay.resonance_id == next_relay_id
		)
	for choice in _testimony_choices:
		choice.set_selected(
			not testimony_id.is_empty() and choice.choice_id == testimony_id
		)
		choice.set_available(testimony_available and testimony_id.is_empty())
	if _rain_eye_gate != null:
		_rain_eye_gate.set_available(rain_eye_gate_available)


func get_city_traces() -> Array[Node]:
	return _traces


func get_city_relays() -> Array[Node]:
	return _relays


func get_testimony_choices() -> Array[Node]:
	return _testimony_choices


func get_rain_eye_gate() -> Node:
	return _rain_eye_gate


func get_spawn_transform() -> Transform3D:
	return Transform3D(Basis(), Vector3(0.0, 1.0, 16.0))


func _create_materials() -> void:
	_stone_material = _pbr_material(
		"lake_stone",
		Color("55686b") if not is_echo else Color("746b5b"),
		0.46 if not is_echo else 0.68,
	)
	_stone_material.metallic = 0.08
	_stone_material.roughness = 0.42 if not is_echo else 0.56

	_wall_material = _pbr_material(
		"shrine_stone",
		Color("34464d") if not is_echo else Color("73644f"),
		0.38 if not is_echo else 0.52,
	)
	_wall_material.roughness = 0.72

	_metal_material = StandardMaterial3D.new()
	_metal_material.albedo_color = (
		Color("26373c") if not is_echo else Color("574a38")
	)
	_metal_material.metallic = 0.72
	_metal_material.roughness = 0.3

	_window_material = StandardMaterial3D.new()
	var window_color := Color("55c9d2") if not is_echo else Color("ffc66f")
	_window_material.albedo_color = window_color
	_window_material.emission_enabled = true
	_window_material.emission = window_color
	_window_material.emission_energy_multiplier = 0.8 if not is_echo else 3.4
	_window_material.metallic = 0.18
	_window_material.roughness = 0.2


func _create_streets() -> void:
	var street := Node3D.new()
	street.name = "CityStreets"
	add_child(street)
	_add_static_box(
		street,
		"SouthStreet",
		Vector3(0.0, -0.22, 7.0),
		Vector3(12.0, 0.44, 22.0),
		_stone_material,
	)
	_add_static_box(
		street,
		"NorthStreet",
		Vector3(0.0, -0.22, -20.0),
		Vector3(12.0, 0.44, 20.0),
		_stone_material,
	)
	for side in [-1.0, 1.0]:
		_add_static_box(
			street,
			"SidewalkSouth",
			Vector3(side * 6.7, 0.0, 7.0),
			Vector3(1.4, 0.42, 22.0),
			_wall_material,
		)
		_add_static_box(
			street,
			"SidewalkNorth",
			Vector3(side * 6.7, 0.0, -20.0),
			Vector3(1.4, 0.42, 20.0),
			_wall_material,
		)
	if is_echo:
		_add_static_box(
			street,
			"MemoryBridge",
			Vector3(0.0, 0.0, -7.0),
			Vector3(4.4, 0.38, 6.2),
			_wall_material,
		)
		for index in 7:
			var rail := MeshInstance3D.new()
			var rail_mesh := CylinderMesh.new()
			rail_mesh.top_radius = 0.035
			rail_mesh.bottom_radius = 0.045
			rail_mesh.height = 1.0
			rail_mesh.radial_segments = 6
			rail_mesh.material = _metal_material
			rail.mesh = rail_mesh
			rail.position = Vector3(
				-2.05 if index % 2 == 0 else 2.05,
				0.55,
				-9.6 + (index / 2) * 1.65,
			)
			street.add_child(rail)
	else:
		for side in [-1.0, 1.0]:
			_add_static_box(
				street,
				"BrokenBridge",
				Vector3(side * 1.65, -0.08, -7.0),
				Vector3(1.05, 0.28, 2.15),
				_wall_material,
				Vector3(0.0, side * 9.0, side * 8.0),
			)


func _create_canal() -> void:
	var canal := Node3D.new()
	canal.name = "RainCanal"
	add_child(canal)
	_add_static_box(
		canal,
		"CanalBed",
		Vector3(0.0, -1.55, -7.0),
		Vector3(16.0, 0.3, 6.0),
		_wall_material,
	)
	var water := MeshInstance3D.new()
	water.name = "CanalWater"
	var plane := PlaneMesh.new()
	plane.size = Vector2(16.0, 6.0)
	plane.subdivide_width = 40
	plane.subdivide_depth = 18
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode cull_disabled;

uniform vec3 water_color : source_color = vec3(0.025, 0.16, 0.19);
uniform vec3 light_color : source_color = vec3(0.15, 0.85, 0.82);

void vertex() {
	VERTEX.y += (
		sin(VERTEX.x * 1.8 + TIME * 1.7)
		+ cos(VERTEX.z * 2.4 - TIME * 1.2)
	) * 0.018;
}

void fragment() {
	float streak = pow(abs(sin(UV.y * 46.0 + TIME * 0.7)), 18.0);
	ALBEDO = mix(water_color, light_color, streak * 0.32);
	EMISSION = light_color * streak * 0.55;
	ROUGHNESS = 0.08;
	SPECULAR = 0.95;
	METALLIC = 0.18;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter(
		"water_color",
		Color("09252d") if not is_echo else Color("2e241d"),
	)
	material.set_shader_parameter(
		"light_color",
		Color("42dfe0") if not is_echo else Color("ffc974"),
	)
	plane.material = material
	water.mesh = plane
	water.position = Vector3(0.0, -0.68, -7.0)
	canal.add_child(water)


func _create_buildings() -> void:
	var buildings := Node3D.new()
	buildings.name = "CityBuildings"
	add_child(buildings)
	var rows := [14.0, 8.0, 2.0, -13.0, -19.0, -25.0]
	for side in [-1.0, 1.0]:
		for index in rows.size():
			var height := _rng.randf_range(5.8, 10.5)
			if is_echo:
				height += 1.2
			var depth := _rng.randf_range(4.4, 6.2)
			var body := _add_static_box(
				buildings,
				"Building_%d" % index,
				Vector3(side * 10.0, height * 0.5, rows[index]),
				Vector3(5.0, height, depth),
				_wall_material,
				Vector3(0.0, _rng.randf_range(-2.0, 2.0), 0.0),
			)
			_add_building_windows(body, side, height, depth)
			if not is_echo and index in [2, 4]:
				body.rotation_degrees.z = side * _rng.randf_range(1.5, 4.0)


func _add_building_windows(
	building: StaticBody3D,
	side: float,
	height: float,
	depth: float,
) -> void:
	for floor_index in maxi(1, int(height / 1.8) - 1):
		for column in 2:
			if not is_echo and (floor_index + column) % 3 != 0:
				continue
			var window := MeshInstance3D.new()
			var pane := QuadMesh.new()
			pane.size = Vector2(0.68, 0.92)
			pane.material = _window_material
			window.mesh = pane
			window.position = Vector3(
				-side * 2.515,
				1.55 + floor_index * 1.65 - height * 0.5,
				-depth * 0.21 + column * depth * 0.42,
			)
			window.rotation_degrees.y = 90.0 * side
			building.add_child(window)


func _create_lantern_avenue() -> void:
	var avenue := Node3D.new()
	avenue.name = "LanternAvenue"
	add_child(avenue)
	var lantern_color := Color("55dce4") if not is_echo else Color("ffc76c")
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.035
	pole_mesh.bottom_radius = 0.055
	pole_mesh.height = 2.8
	pole_mesh.radial_segments = 6
	pole_mesh.material = _metal_material
	var lantern_mesh := SphereMesh.new()
	lantern_mesh.radius = 0.18
	lantern_mesh.height = 0.36
	lantern_mesh.radial_segments = 10
	lantern_mesh.rings = 6
	var lantern_material := StandardMaterial3D.new()
	lantern_material.albedo_color = lantern_color
	lantern_material.emission_enabled = true
	lantern_material.emission = lantern_color
	lantern_material.emission_energy_multiplier = 1.0 if not is_echo else 4.2
	lantern_material.roughness = 0.18
	lantern_mesh.material = lantern_material
	for index in 16:
		var z_position := 16.0 - index * 2.85
		if z_position > -4.2 or z_position < -9.8:
			var side := -1.0 if index % 2 == 0 else 1.0
			var pole := MeshInstance3D.new()
			pole.mesh = pole_mesh
			pole.position = Vector3(side * 5.35, 1.4, z_position)
			avenue.add_child(pole)
			var lantern := MeshInstance3D.new()
			lantern.mesh = lantern_mesh
			lantern.position = Vector3(side * 5.35, 2.75, z_position)
			avenue.add_child(lantern)
			if is_echo or index % 4 == 0:
				var light := OmniLight3D.new()
				light.position = lantern.position
				light.light_color = lantern_color
				light.light_energy = 2.7 if is_echo else 0.85
				light.omni_range = 5.2
				light.shadow_enabled = is_echo and index % 4 == 0
				avenue.add_child(light)


func _create_market() -> void:
	if not is_echo:
		return
	var market := Node3D.new()
	market.name = "LivingMemoryMarket"
	add_child(market)
	var fabric_material := StandardMaterial3D.new()
	fabric_material.albedo_color = Color("6d3040")
	fabric_material.roughness = 0.86
	for index in 6:
		var side := -1.0 if index % 2 == 0 else 1.0
		var stall := _add_static_box(
			market,
			"MarketStall_%d" % index,
			Vector3(side * 4.1, 0.65, 4.0 - (index / 2) * 4.2),
			Vector3(2.1, 1.3, 1.35),
			_wall_material,
		)
		var canopy := MeshInstance3D.new()
		var canopy_mesh := BoxMesh.new()
		canopy_mesh.size = Vector3(2.5, 0.12, 1.8)
		canopy_mesh.material = fabric_material
		canopy.mesh = canopy_mesh
		canopy.position = Vector3(0.0, 1.15, 0.0)
		canopy.rotation_degrees.z = side * 6.0
		stall.add_child(canopy)


func _create_train() -> void:
	var train_root := Node3D.new()
	train_root.name = "RainRail"
	add_child(train_root)
	var train_lane_x := 3.35
	for side in [-1.0, 1.0]:
		var rail := MeshInstance3D.new()
		var rail_mesh := BoxMesh.new()
		rail_mesh.size = Vector3(0.09, 0.08, 52.0)
		rail_mesh.material = _metal_material
		rail.mesh = rail_mesh
		rail.position = Vector3(train_lane_x + side * 1.25, 0.12, -5.0)
		train_root.add_child(rail)
	if is_echo:
		_train = AnimatableBody3D.new()
		_train.name = "RunningRainTrain"
		_train.position = Vector3(train_lane_x, 0.85, 19.0)
		_train.collision_layer = 1
		_train.collision_mask = 2
		train_root.add_child(_train)
		_add_train_car(_train, Vector3(0.0, 0.0, 0.0))
		_add_train_car(_train, Vector3(0.0, 0.0, 4.6))
	else:
		for index in 2:
			var wreck := StaticBody3D.new()
			wreck.name = "CrashedRainCar_%d" % index
			wreck.position = Vector3(
				-2.5 + index * 4.8,
				0.9,
				-18.0 - index * 3.5,
			)
			wreck.rotation_degrees = Vector3(
				0.0,
				-18.0 + index * 31.0,
				-7.0 + index * 11.0,
			)
			train_root.add_child(wreck)
			_add_train_car(wreck, Vector3.ZERO)


func _add_train_car(parent: Node3D, offset: Vector3) -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(2.8, 1.7, 4.1)
	mesh.material = _metal_material
	mesh_instance.mesh = mesh
	mesh_instance.position = offset
	parent.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = mesh.size
	collision.shape = shape
	collision.position = offset
	parent.add_child(collision)
	for side in [-1.0, 1.0]:
		var window := MeshInstance3D.new()
		var pane := QuadMesh.new()
		pane.size = Vector2(2.4, 0.72)
		pane.material = _window_material
		window.mesh = pane
		window.position = offset + Vector3(side * 1.405, 0.2, 0.0)
		window.rotation_degrees.y = side * 90.0
		parent.add_child(window)


func _create_physics_props() -> void:
	var props := Node3D.new()
	props.name = "JoltCityProps"
	add_child(props)
	for index in 8:
		var crate := RigidBody3D.new()
		crate.name = "RainCrate_%d" % index
		crate.mass = 7.0
		crate.position = Vector3(
			-3.7 + (index % 4) * 0.85,
			0.42 + (index / 4) * 0.82,
			6.0 if is_echo else -13.5,
		)
		crate.rotation_degrees.y = index * 11.0
		var mesh_instance := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.72, 0.72, 0.72)
		mesh.material = _wall_material
		mesh_instance.mesh = mesh
		crate.add_child(mesh_instance)
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = mesh.size
		collision.shape = shape
		crate.add_child(collision)
		props.add_child(crate)


func _create_rain() -> void:
	var rain := GPUParticles3D.new()
	rain.name = "CityRain" if not is_echo else "SuspendedRain"
	rain.amount = 220 if not is_echo else 110
	rain.lifetime = 2.4 if not is_echo else 4.8
	rain.preprocess = rain.lifetime
	rain.position = Vector3(0.0, 7.5, -7.0)
	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_material.emission_box_extents = Vector3(15.0, 2.0, 28.0)
	process_material.direction = Vector3.DOWN if not is_echo else Vector3.UP
	process_material.spread = 4.0 if not is_echo else 18.0
	process_material.gravity = (
		Vector3(0.0, -9.2, 0.0)
		if not is_echo
		else Vector3(0.0, 0.24, 0.0)
	)
	process_material.initial_velocity_min = 3.0 if not is_echo else 0.08
	process_material.initial_velocity_max = 5.2 if not is_echo else 0.22
	rain.process_material = process_material
	var drop := QuadMesh.new()
	drop.size = Vector2(0.018, 0.28 if not is_echo else 0.06)
	var drop_material := StandardMaterial3D.new()
	drop_material.albedo_color = (
		Color(0.55, 0.86, 0.93, 0.62)
		if not is_echo
		else Color(1.0, 0.76, 0.4, 0.72)
	)
	drop_material.emission_enabled = is_echo
	drop_material.emission = Color("ffc46b")
	drop_material.emission_energy_multiplier = 1.8
	drop_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	drop.material = drop_material
	rain.draw_pass_1 = drop
	add_child(rain)


func _create_traces() -> void:
	var definitions := (
		[
			[&"city_market", "读取集市留下的脚步", Vector3(-3.4, 0.0, -1.8)],
		]
		if is_echo
		else [
			[&"city_station", "读取废站的守灯记录", Vector3(0.0, 0.0, 10.5)],
			[&"city_belltower", "读取钟楼前的最后记录", Vector3(0.0, 0.0, -26.0)],
		]
	)
	for definition in definitions:
		var trace := CITY_TRACE.new()
		trace.name = "CityTrace_" + str(definition[0])
		trace.trace_id = definition[0]
		trace.prompt_text = definition[1]
		trace.visual_layer = _visual_layer
		trace.position = definition[2]
		trace.activated.connect(_on_trace_activated)
		_traces.append(trace)
		add_child(trace)


func _create_relays() -> void:
	var definitions := (
		[
			[&"relay_market", "接通集市行灯", Vector3(-3.8, 0.0, 1.8)],
			[&"relay_belltower", "接通钟楼主灯", Vector3(0.0, 0.0, -24.0)],
		]
		if is_echo
		else [
			[&"relay_dawn", "接通废站晨灯", Vector3(3.8, 0.0, 8.5)],
			[&"relay_bridge", "接通断桥回路", Vector3(-3.8, 0.0, -11.5)],
		]
	)
	for definition in definitions:
		var relay := STORY_RESONATOR.new()
		relay.name = "CityRelay_" + str(definition[0])
		relay.resonance_id = definition[0]
		relay.prompt_text = definition[1]
		relay.visual_layer = _visual_layer
		relay.accent_color = Color("ffc76c") if is_echo else Color("55e4e8")
		relay.position = definition[2]
		relay.activated.connect(
			func(relay_id: StringName) -> void:
				city_relay_activated.emit(relay_id)
		)
		_relays.append(relay)
		add_child(relay)


func _create_testimony_choices() -> void:
	if is_echo:
		return
	var definitions := [
		[&"trust_shuo", "接受朔的完整证词", Vector3(-1.65, 0.0, -26.0)],
		[&"challenge_shuo", "质问朔为何替城市停住时间", Vector3(1.65, 0.0, -26.0)],
	]
	for definition in definitions:
		var choice := ENDING_CHOICE_SCENE.instantiate()
		choice.name = "CityTestimony_" + str(definition[0])
		choice.choice_id = definition[0]
		choice.persistent_id = StringName("city_" + str(definition[0]))
		choice.prompt_text = definition[1]
		choice.position = definition[2]
		choice.selected.connect(
			func(testimony_id: StringName) -> void:
				city_testimony_selected.emit(testimony_id)
		)
		_testimony_choices.append(choice)
		add_child(choice)


func _create_rain_eye_gate() -> void:
	if is_echo:
		return
	_rain_eye_gate = CITY_GATE.new()
	_rain_eye_gate.gate_name = "RainEyeGate"
	_rain_eye_gate.prompt_text = "进入雨眼，开始最后一次归档"
	_rain_eye_gate.visual_layer = PRESENT_VISUAL_LAYER
	_rain_eye_gate.position = Vector3(0.0, 0.0, -29.0)
	_rain_eye_gate.rotation_degrees.y = 180.0
	_rain_eye_gate.entered.connect(
		func() -> void: rain_eye_gate_entered.emit()
	)
	add_child(_rain_eye_gate)


func _on_trace_activated(trace_id: StringName) -> void:
	city_trace_activated.emit(trace_id)


func _add_static_box(
	parent: Node,
	node_name: String,
	position: Vector3,
	size: Vector3,
	material: Material,
	rotation_degrees := Vector3.ZERO,
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	body.rotation_degrees = rotation_degrees
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
	parent.add_child(body)
	return body


func _pbr_material(
	folder: String,
	tint: Color,
	scale: float,
) -> StandardMaterial3D:
	var root := "res://content/materials/" + folder + "/"
	var material := StandardMaterial3D.new()
	material.albedo_texture = load(root + "albedo.png") as Texture2D
	material.albedo_color = tint
	material.normal_enabled = true
	material.normal_texture = load(root + "normal.png") as Texture2D
	material.normal_scale = 0.82
	material.roughness = 1.0
	material.roughness_texture = load(root + "roughness.png") as Texture2D
	material.texture_filter = (
		BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	)
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE * scale
	return material


func _set_visual_layer(root: Node, visual_layer: int) -> void:
	var visuals: Array[Node] = []
	if root is VisualInstance3D:
		visuals.append(root)
	visuals.append_array(
		root.find_children("*", "VisualInstance3D", true, false)
	)
	for node in visuals:
		(node as VisualInstance3D).layers = visual_layer
