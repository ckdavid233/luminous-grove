extends SceneTree


func _initialize() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://settings.cfg"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save_slot_1.json"))
	var main_scene := load("res://game/main/main.tscn") as PackedScene
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	var world_environment = main.get("_world_environment") as WorldEnvironment
	var environment: Environment = world_environment.environment
	var grass := main.get_node("Grass") as MultiMeshInstance3D
	var ambient_vfx := main.get_node("AmbientVFX") as Node3D
	var tree_batch := main.get_node("Forest/DetailedTrees_1") as MultiMeshInstance3D
	var body := main.find_child("Ji_Body_Source_Game", true, false) as MeshInstance3D
	var skin_material := body.get_surface_override_material(0) as StandardMaterial3D
	assert(main.get_quality_profile() == &"high")
	assert(environment.ssr_enabled)
	assert(environment.ssao_enabled)
	assert(environment.ssil_enabled)
	assert(environment.sdfgi_enabled)
	assert(environment.volumetric_fog_enabled)
	assert(grass.multimesh.visible_instance_count == 16000)
	assert(grass.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	assert(tree_batch.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	assert(ambient_vfx.visible and skin_material.subsurf_scatter_enabled)
	assert(is_equal_approx(main.get_render_scale(), 1.0))
	main.call("_cycle_quality_profile")
	assert(main.get_quality_profile() == &"balanced")
	assert(environment.ssr_enabled and environment.volumetric_fog_enabled)
	assert(not environment.ssil_enabled and not environment.sdfgi_enabled)
	assert(grass.multimesh.visible_instance_count == 10000)
	assert(grass.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	assert(is_equal_approx(main.get_render_scale(), 0.77))
	main.call("_cycle_quality_profile")
	assert(main.get_quality_profile() == &"performance")
	assert(
		not environment.ssr_enabled
		and not environment.ssao_enabled
		and not environment.volumetric_fog_enabled
	)
	assert(grass.multimesh.visible_instance_count == 5200)
	assert(tree_batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	assert(not ambient_vfx.visible and not skin_material.subsurf_scatter_enabled)
	assert(is_equal_approx(main.get_render_scale(), 0.59))
	main.call("_cycle_quality_profile")
	assert(main.get_quality_profile() == &"high")
	assert(ambient_vfx.visible and skin_material.subsurf_scatter_enabled)
	assert(is_equal_approx(main.get_render_scale(), 1.0))
	var pause_overlay = main.get("_pause_overlay") as Control
	assert(pause_overlay != null and not pause_overlay.visible)
	main.call("_set_paused", true)
	assert(paused and pause_overlay.visible)
	main.call("_set_paused", false)
	assert(not paused and not pause_overlay.visible)
	print("QUALITY_SETTINGS_TEST_OK high=full balanced=hybrid performance=igpu pause=ok")
	var streamer = main.get("_world_streamer")
	for _frame in 300:
		if streamer.is_level_ready(
			"res://content/levels/echo_ruins/echo_ruins.tscn"
		):
			break
		await process_frame
	streamer.clear_inactive_levels()
	if streamer.has_method("shutdown"):
		streamer.shutdown()
	if main.has_method("shutdown"):
		main.shutdown()
	main.queue_free()
	for _frame in 120:
		await process_frame
		await physics_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://settings.cfg"))
	call_deferred("quit")
