extends SceneTree

const CONSOLE := preload("res://game/narrative/archive_cipher_console.gd")


func _initialize() -> void:
	var console := CONSOLE.new()
	root.add_child(console)
	console.set_solution([2, 4, 1])
	console.set_clue("听声=△，定形=◈，铭名=≈")
	console.set_available(true)
	var rejected: Array = []
	console.cipher_rejected.connect(
		func(attempt: Array[int], clue: String) -> void:
			rejected.append({"attempt": attempt, "clue": clue})
	)
	# Turning the first ring through a full cycle without reading the clue must
	# reset all three rings and leave the console usable.
	console.set_solution([4, 4, 1])
	console.rotate_puzzle()
	console.interact(null)
	assert(rejected.size() == 1, "A wrapped wrong rune must emit recoverable feedback")
	assert(console.get_states() == [0, 0, 0])
	assert(console.can_interact(null))
	console.set_solution([2, 4, 1])
	for slot in [2, 4, 1]:
		for _turn in slot:
			console.rotate_puzzle()
		console.interact(null)
	assert(console.is_solved, "The ordered three-ring code must solve the console")
	assert(not console.can_interact(null), "A solved console must stop accepting input")
	assert(console.get_clue() == "听声=△，定形=◈，铭名=≈")
	print("ARCHIVE_CIPHER_TEST_OK attempts=", rejected.size(), " code=", console.get_states())
	quit()
