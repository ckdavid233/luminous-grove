extends SceneTree


func _initialize() -> void:
	var scene := load(
		"res://content/characters/realistic_player/ji_realistic.glb"
	) as PackedScene
	assert(scene != null, "Player glTF must import as PackedScene")
	var character := scene.instantiate()
	root.add_child(character)
	var skeletons := character.find_children("*", "Skeleton3D", true, false)
	var animation_players := character.find_children("*", "AnimationPlayer", true, false)
	assert(skeletons.size() == 1, "Exactly one skeleton is expected")
	assert(animation_players.size() == 1, "Exactly one AnimationPlayer is expected")
	assert(
		(skeletons[0] as Skeleton3D).get_bone_count() == 53,
		"Runtime player must use the realistic game-engine rig",
	)
	var animation_player := animation_players[0] as AnimationPlayer
	var animation_names := animation_player.get_animation_list()
	for required_name in [&"Idle", &"Walk", &"Run", &"Jump", &"Fall", &"Land", &"Interact"]:
		assert(required_name in animation_names, "Missing animation: " + required_name)
	print(
		"PLAYER_IMPORT_TEST_OK skeletons=",
		skeletons.size(),
		" animations=",
		animation_names,
	)
	quit()
