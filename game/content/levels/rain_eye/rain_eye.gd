extends Node3D

const PRESENT_VISUAL_LAYER := 1 << 0
const ECHO_VISUAL_LAYER := 1 << 1
const MEMORY_SEAL := preload("res://game/narrative/city_trace.gd")
const ENDING_CHOICE_SCENE := preload("res://game/narrative/ending_choice.tscn")
const STORY_RESONATOR := preload("res://game/narrative/story_resonator.gd")

signal rain_eye_seal_activated(seal_id: StringName)
signal rain_eye_trial_activated(trial_id: StringName)
signal final_choice_selected(choice_id: StringName)

@export var is_echo := false

var _visual_layer := PRESENT_VISUAL_LAYER
var _rng := RandomNumberGenerator.new()
var _seals: Array[Node] = []
var _trials: Array[Node] = []
var _final_choices: Array[Node] = []
var _path_material: StandardMaterial3D
var _fragment_material: StandardMaterial3D
var _accent_material: StandardMaterial3D


func _exit_tree() -> void:
	_path_material = null
	_fragment_material = null
	_accent_material = null
	_seals.clear()
	_trials.clear()
	_final_choices.clear()
	_rng = null


func _ready() -> void:
	_visual_layer = ECHO_VISUAL_LAYER if is_echo else PRESENT_VISUAL_LAYER
	_rng.seed = 0xE7E0 if is_echo else 0xF1A1
	set_meta("stream_keep_visual_when_inactive", true)
	_create_materials()
	_create_alternating_path()
	_create_memory_fragments()
	_create_inverted_lake()
	_create_jolt_fragments()
	_create_storm()
	_create_seals()
	_create_trials()
	_create_final_choices()
	_set_visual_layer(self, _visual_layer)


func sync_rain_eye_state(
	seals_available: bool,
	activated_seal_ids: Array[StringName],
	trials_available := false,
	activated_trial_ids: Array[StringName] = [],
	next_trial_id: StringName = &"",
	choices_available := false,
	ending_id: StringName = &"",
	available_ending_ids: Array[StringName] = [],
) -> void:
	for seal in _seals:
		seal.set_activated(activated_seal_ids.has(seal.trace_id))
		seal.set_available(seals_available)
	for trial in _trials:
		trial.set_activated(activated_trial_ids.has(trial.resonance_id))
		trial.set_available(
			trials_available and trial.resonance_id == next_trial_id
		)
	for choice in _final_choices:
		choice.set_selected(not ending_id.is_empty() and choice.choice_id == ending_id)
		choice.set_available(
			choices_available
			and ending_id.is_empty()
			and available_ending_ids.has(choice.choice_id)
		)


func get_rain_eye_seals() -> Array[Node]:
	return _seals


func get_rain_eye_trials() -> Array[Node]:
	return _trials


func get_final_choices() -> Array[Node]:
	return _final_choices


func get_spawn_transform() -> Transform3D:
	return Transform3D(Basis(), Vector3(0.0, 1.0, 16.0))


func _create_materials() -> void:
	_path_material = StandardMaterial3D.new()
	_path_material.albedo_color = (
		Color("233c42") if not is_echo else Color("66523e")
	)
	_path_material.metallic = 0.22
	_path_material.roughness = 0.34
	_path_material.emission_enabled = true
	_path_material.emission = (
		Color("153f44") if not is_echo else Color("69471e")
	)
	_path_material.emission_energy_multiplier = 0.32

	_fragment_material = StandardMaterial3D.new()
	_fragment_material.albedo_color = (
		Color("354f55") if not is_echo else Color("796852")
	)
	_fragment_material.metallic = 0.08
	_fragment_material.roughness = 0.78

	_accent_material = StandardMaterial3D.new()
	var accent := Color("4df1e5") if not is_echo else Color("ffc46a")
	_accent_material.albedo_color = accent
	_accent_material.emission_enabled = true
	_accent_material.emission = accent
	_accent_material.emission_energy_multiplier = 3.8
	_accent_material.roughness = 0.15


func _create_alternating_path() -> void:
	var path := Node3D.new()
	path.name = "AlternatingMemoryPath"
	add_child(path)
	var centers := [7.0, -5.0, -17.0] if is_echo else [13.0, 1.0, -11.0, -20.0]
	for index in centers.size():
		var width := 5.2 if centers[index] != -20.0 else 7.2
		_add_static_box(
			path,
			"MemoryPath_%d" % index,
			Vector3(0.0, -0.2, centers[index]),
			Vector3(width, 0.4, 6.2),
			_path_material,
		)
		for side in [-1.0, 1.0]:
			var marker := MeshInstance3D.new()
			var marker_mesh := TorusMesh.new()
			marker_mesh.inner_radius = 0.18
			marker_mesh.outer_radius = 0.24
			marker_mesh.rings = 12
			marker_mesh.ring_segments = 6
			marker_mesh.material = _accent_material
			marker.mesh = marker_mesh
			marker.position = Vector3(side * (width * 0.5 - 0.28), 0.12, centers[index])
			marker.rotation_degrees.x = 90.0
			path.add_child(marker)


func _create_memory_fragments() -> void:
	var fragments := Node3D.new()
	fragments.name = "OverlappingWorldFragments"
	add_child(fragments)
	for index in 24:
		var side := -1.0 if index % 2 == 0 else 1.0
		var fragment := MeshInstance3D.new()
		if not is_echo and index % 3 == 0:
			var trunk := CylinderMesh.new()
			trunk.top_radius = 0.16
			trunk.bottom_radius = 0.31
			trunk.height = _rng.randf_range(3.0, 6.0)
			trunk.radial_segments = 7
			trunk.material = _fragment_material
			fragment.mesh = trunk
		else:
			var block := BoxMesh.new()
			block.size = Vector3(
				_rng.randf_range(0.8, 3.2),
				_rng.randf_range(1.2, 6.5),
				_rng.randf_range(0.6, 2.4),
			)
			block.material = _fragment_material
			fragment.mesh = block
		fragment.position = Vector3(
			side * _rng.randf_range(4.2, 11.5),
			_rng.randf_range(0.8, 6.5),
			16.0 - index * 1.65,
		)
		fragment.rotation_degrees = Vector3(
			_rng.randf_range(-18.0, 18.0),
			_rng.randf_range(0.0, 180.0),
			_rng.randf_range(-22.0, 22.0),
		)
		fragments.add_child(fragment)
	if is_echo:
		for index in 9:
			var column := MeshInstance3D.new()
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.25
			mesh.bottom_radius = 0.38
			mesh.height = 4.8
			mesh.radial_segments = 10
			mesh.material = _fragment_material
			column.mesh = mesh
			column.position = Vector3(
				-6.0 if index % 2 == 0 else 6.0,
				2.4 + sin(index) * 0.7,
				13.0 - index * 4.0,
			)
			column.rotation_degrees.z = sin(index * 2.1) * 18.0
			fragments.add_child(column)


func _create_inverted_lake() -> void:
	var lake := MeshInstance3D.new()
	lake.name = "InvertedLake"
	var plane := PlaneMesh.new()
	plane.size = Vector2(34.0, 48.0)
	plane.subdivide_width = 72
	plane.subdivide_depth = 96
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode cull_disabled, blend_mix;

uniform vec3 deep_color : source_color = vec3(0.02, 0.14, 0.17);
uniform vec3 glow_color : source_color = vec3(0.2, 0.9, 0.85);

void vertex() {
	VERTEX.y += (
		sin(VERTEX.x * 0.8 + TIME)
		+ cos(VERTEX.z * 0.65 - TIME * 0.7)
	) * 0.12;
}

void fragment() {
	float veins = pow(abs(sin(UV.x * 35.0) * cos(UV.y * 27.0)), 12.0);
	ALBEDO = mix(deep_color, glow_color, veins * 0.45);
	EMISSION = glow_color * veins * 1.4;
	ROUGHNESS = 0.08;
	SPECULAR = 0.95;
	ALPHA = 0.82;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter(
		"deep_color",
		Color("082a34") if not is_echo else Color("302219"),
	)
	material.set_shader_parameter(
		"glow_color",
		Color("3bf1e2") if not is_echo else Color("ffc46a"),
	)
	plane.material = material
	lake.mesh = plane
	lake.position = Vector3(0.0, 8.5, -3.0)
	lake.rotation_degrees.z = 180.0
	add_child(lake)


func _create_jolt_fragments() -> void:
	var props := Node3D.new()
	props.name = "RainEyeJoltFragments"
	add_child(props)
	for index in 7:
		var body := RigidBody3D.new()
		body.name = "CrossPhaseFragment_%d" % index
		body.mass = 3.5 + index * 0.4
		body.position = Vector3(
			-3.8 if index % 2 == 0 else 3.8,
			1.0 + (index % 3) * 0.75,
			12.0 - index * 4.2,
		)
		body.rotation_degrees = Vector3(index * 7.0, index * 19.0, index * 5.0)
		var mesh_instance := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.72, 0.72, 0.72)
		mesh.material = _fragment_material
		mesh_instance.mesh = mesh
		body.add_child(mesh_instance)
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = mesh.size
		collision.shape = shape
		body.add_child(collision)
		props.add_child(body)


func _create_storm() -> void:
	var storm := GPUParticles3D.new()
	storm.name = "RainEyeStorm"
	storm.amount = 260
	storm.lifetime = 4.2
	storm.preprocess = 4.2
	storm.position = Vector3(0.0, 4.5, -3.0)
	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_material.emission_box_extents = Vector3(14.0, 5.0, 24.0)
	process_material.direction = Vector3(0.4, -0.4, -0.2)
	process_material.spread = 180.0
	process_material.gravity = Vector3(0.0, 0.0, 0.0)
	process_material.initial_velocity_min = 0.25
	process_material.initial_velocity_max = 1.1
	storm.process_material = process_material
	var particle_mesh := SphereMesh.new()
	particle_mesh.radius = 0.025
	particle_mesh.height = 0.06
	particle_mesh.radial_segments = 5
	particle_mesh.rings = 3
	particle_mesh.material = _accent_material
	storm.draw_pass_1 = particle_mesh
	add_child(storm)


func _create_seals() -> void:
	var definitions := (
		[
			[&"eye_archive", "归档沉雨档案", Vector3(0.0, 0.0, -5.0)],
		]
		if is_echo
		else [
			[&"eye_grove", "归档微光林地", Vector3(0.0, 0.0, 13.0)],
			[&"eye_city", "归档行灯之城", Vector3(0.0, 0.0, -11.0)],
		]
	)
	for definition in definitions:
		var seal := MEMORY_SEAL.new()
		seal.name = "RainEyeSeal_" + str(definition[0])
		seal.trace_id = definition[0]
		seal.prompt_text = definition[1]
		seal.visual_layer = _visual_layer
		seal.position = definition[2]
		seal.activated.connect(_on_seal_activated)
		_seals.append(seal)
		add_child(seal)


func _create_trials() -> void:
	var definitions := (
		[
			[
				&"trial_carry_motion",
				"把前进的惯性带过时相裂缝",
				Vector3(0.0, 0.0, -17.0),
			],
		]
		if is_echo
		else [
			[
				&"trial_accept_loss",
				"承认无法被归档的失去",
				Vector3(0.0, 0.0, -14.0),
			],
			[
				&"trial_release_name",
				"放开最后一个旧名字",
				Vector3(0.0, 0.0, -18.7),
			],
		]
	)
	for definition in definitions:
		var trial := STORY_RESONATOR.new()
		trial.name = "RainEyeTrial_" + str(definition[0])
		trial.resonance_id = definition[0]
		trial.prompt_text = definition[1]
		trial.visual_layer = _visual_layer
		trial.accent_color = Color("ffc46a") if is_echo else Color("55f4e5")
		trial.position = definition[2]
		trial.activated.connect(
			func(trial_id: StringName) -> void:
				rain_eye_trial_activated.emit(trial_id)
		)
		_trials.append(trial)
		add_child(trial)


func _create_final_choices() -> void:
	if is_echo:
		return
	var definitions := [
		[
			&"merge_worlds",
			"合流两个时相",
			Vector3(-2.3, 0.0, -20.0),
		],
		[
			&"guard_boundary",
			"守住两个世界的边界",
			Vector3(0.0, 0.0, -21.2),
		],
		[
			&"tidal_order",
			"让记忆如潮汐往复",
			Vector3(2.3, 0.0, -20.0),
		],
	]
	for definition in definitions:
		var choice := ENDING_CHOICE_SCENE.instantiate()
		choice.name = "FinalChoice_" + str(definition[0])
		choice.choice_id = definition[0]
		choice.persistent_id = StringName("final_" + str(definition[0]))
		choice.prompt_text = definition[1]
		choice.position = definition[2]
		choice.selected.connect(_on_final_choice_selected)
		_final_choices.append(choice)
		add_child(choice)


func _on_seal_activated(seal_id: StringName) -> void:
	rain_eye_seal_activated.emit(seal_id)


func _on_final_choice_selected(choice_id: StringName) -> void:
	final_choice_selected.emit(choice_id)


func _add_static_box(
	parent: Node,
	node_name: String,
	position: Vector3,
	size: Vector3,
	material: Material,
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
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


func _set_visual_layer(root: Node, visual_layer: int) -> void:
	var visuals: Array[Node] = []
	if root is VisualInstance3D:
		visuals.append(root)
	visuals.append_array(
		root.find_children("*", "VisualInstance3D", true, false)
	)
	for node in visuals:
		(node as VisualInstance3D).layers = visual_layer
