extends SceneTree

const CINEMATIC_DIRECTOR := preload("res://core/cinematic/cinematic_director.gd")
const CINEMATIC_TEST_PLAYER := preload(
	"res://tests/fixtures/cinematic_test_player.gd"
)

var _started_ids: Array[StringName] = []
var _subtitles: Array[String] = []
var _finished_events: Array[Dictionary] = []


func _initialize() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var player := Node3D.new()
	player.set_script(CINEMATIC_TEST_PLAYER)
	stage.add_child(player)
	var gameplay_camera := Camera3D.new()
	gameplay_camera.name = "GameplayCamera"
	player.add_child(gameplay_camera)
	gameplay_camera.position = Vector3(0.0, 1.6, 4.0)
	gameplay_camera.make_current()
	await process_frame

	var director := CINEMATIC_DIRECTOR.new()
	stage.add_child(director)
	director.configure(player, gameplay_camera)
	director.cinematic_started.connect(
		func(sequence_id: StringName) -> void: _started_ids.append(sequence_id)
	)
	director.subtitle_requested.connect(
		func(subtitle: String) -> void: _subtitles.append(subtitle)
	)
	director.cinematic_finished.connect(
		func(sequence_id: StringName, skipped: bool) -> void:
			_finished_events.append({"id": sequence_id, "skipped": skipped})
	)

	var natural_shots: Array[Dictionary] = [
		{
			"position": Vector3(1.0, 2.0, 4.0),
			"look_at": Vector3(0.0, 1.0, 0.0),
			"fov": 51.0,
			"duration": 0.05,
			"subtitle": "镜头掠过雨后的湖面。",
		},
		{
			"position": Vector3(-2.0, 2.8, 3.0),
			"look_at": Vector3(0.0, 1.3, -2.0),
			"fov": 43.0,
			"duration": 0.05,
			"subtitle": "裂隙在远处睁开。",
		},
	]
	assert(director.play_sequence(&"natural_test", natural_shots))
	assert(director.is_playing)
	assert(player.get("control_enabled") == false)
	assert(not director.play_sequence(&"overlap_rejected", natural_shots))
	assert(await _wait_for_finish(director), "The natural cinematic must finish")
	assert(player.get("control_enabled") == true)
	assert(gameplay_camera.is_current(), "Gameplay camera must be restored")
	assert(_finished_events.size() == 1)
	assert(_finished_events[0].id == &"natural_test")
	assert(_finished_events[0].skipped == false)
	assert(_subtitles.size() == 2)

	var skip_shots: Array[Dictionary] = [
		{
			"position": Vector3(3.0, 3.0, 6.0),
			"look_at": Vector3.ZERO,
			"duration": 1.0,
			"subtitle": "这个长镜头允许即时跳过。",
		},
		{
			"position": Vector3(0.0, 5.0, -4.0),
			"look_at": Vector3.ZERO,
			"duration": 1.0,
		},
	]
	assert(director.play_sequence(&"skip_test", skip_shots))
	await process_frame
	assert(director.request_skip())
	assert(await _wait_for_finish(director), "The skipped cinematic must still cleanly finish")
	assert(_finished_events.size() == 2)
	assert(_finished_events[1].id == &"skip_test")
	assert(_finished_events[1].skipped == true)
	assert(player.get("control_enabled") == true)
	assert(gameplay_camera.is_current())
	assert(not director.request_skip(), "Skip outside a cinematic must be rejected")

	print(
		"CINEMATIC_DIRECTOR_TEST_OK started=%d subtitles=%d finished=%d"
		% [_started_ids.size(), _subtitles.size(), _finished_events.size()]
	)
	stage.queue_free()
	for _frame in 4:
		await process_frame
		await physics_frame
	call_deferred("quit")


func _wait_for_finish(director: Node) -> bool:
	for _frame in 240:
		if not director.is_playing:
			return true
		await process_frame
	return false
