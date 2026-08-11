class_name NarrativeDirector
extends Node

signal stage_changed(previous: StringName, current: StringName)
signal objective_changed(text: String)
signal memory_added(memory_id: StringName, text: String, count: int)
signal all_memories_collected
signal alignment_chosen(alignment_id: StringName, text: String)
signal archive_anchor_added(anchor_id: StringName, text: String, count: int)
signal archive_anchors_completed
signal archive_sequence_rejected(anchor_id: StringName, expected_id: StringName, clue: String)
signal archive_cipher_completed(code: Array[int])
signal archive_cipher_rejected(attempt: Array[int], clue: String)
signal archive_mechanism_added(mechanism_id: StringName, text: String, count: int)
signal archive_restored
signal city_trace_added(trace_id: StringName, text: String, count: int)
signal city_traces_completed
signal city_relay_added(relay_id: StringName, text: String, count: int)
signal city_relays_completed
signal city_testimony_chosen(testimony_id: StringName, text: String)
signal city_route_completed
signal rain_eye_entered
signal rain_eye_seal_added(seal_id: StringName, text: String, count: int)
signal rain_eye_seals_completed
signal rain_eye_trial_added(trial_id: StringName, text: String, count: int)
signal final_decision_ready
signal ending_chosen(ending_id: StringName, text: String)

const CAMPAIGN_VERSION := 8

const INTRO := &"intro"
const FIND_BELL := &"find_bell"
const GATHER_MEMORIES := &"gather_memories"
const AWAKEN_SHRINE := &"awaken_shrine"
const MEMORY_ALIGNMENT := &"memory_alignment"
const RIFT_READY := &"rift_ready"
const ARCHIVE_SEARCH := &"archive_search"
const ARCHIVE_MECHANISMS := &"archive_mechanisms"
const ARCHIVE_RESTORED := &"archive_restored"
const CITY_GATE := &"city_gate"
const LANTERN_CITY := &"lantern_city"
const CITY_RELAYS := &"city_relays"
const CITY_COUNCIL := &"city_council"
const RAIN_EYE := &"rain_eye"
const RAIN_EYE_TRIALS := &"rain_eye_trials"
const FINAL_DECISION := &"final_decision"
const COMPLETE := &"complete"

const MEMORY_TEXT := {
	&"rain_sound": "第一场雨落下时，林地学会了倾听。",
	&"wet_earth": "潮湿的泥土曾替所有离去的人保存春天。",
	&"waiting_light": "湖边没有等来谁，却一直留着一盏灯。",
}
const ALIGNMENT_TEXT := {
	&"return_to_lake": "你将记忆托付给湖水。雨隙因此记住了归路。",
	&"carry_the_light": "你把微光留在体内。雨隙因此认出了你。",
}
const ARCHIVE_ANCHOR_TEXT := {
	&"archive_voice": "档案记住了雨落下以前的声音。",
	&"archive_shape": "断裂的回廊重新想起自己的形状。",
	&"archive_name": "最后一枚锚点刻下了通往行灯之城的名字。",
}
const ARCHIVE_ANCHOR_ORDER_RETURN: Array[StringName] = [
	&"archive_shape",
	&"archive_voice",
	&"archive_name",
]
const ARCHIVE_ANCHOR_ORDER_CARRY: Array[StringName] = [
	&"archive_voice",
	&"archive_name",
	&"archive_shape",
]
const ARCHIVE_SEQUENCE_CLUE := "无形不能发声，无声不能命名。"
const ARCHIVE_GLYPH_VALUES := {
	&"archive_voice": 2, # △
	&"archive_shape": 4, # ◈
	&"archive_name": 1, # ≈
}
const ARCHIVE_CIPHER_CLUE_RETURN := "残句规定顺序：无声→无形→命名。按五刻度读符号（◒0、≈1、△2、✦3、◈4）；湖面倒影把第一环再向前推三格。最后封印轮取三环步数之和除以五的余数。"
const ARCHIVE_CIPHER_CLUE_CARRY := "携光后顺序被雨隙折返：重量→倒影→命名。仍按五刻度读符号；雨隙把第一环向前推一格。三环完成后，封印轮取步数总和除以五的余数。"
const ARCHIVE_MECHANISM_ORDER: Array[StringName] = [
	&"archive_reflection",
	&"archive_counterweight",
	&"archive_name_lens",
]
const ARCHIVE_MECHANISM_TEXT := {
	&"archive_reflection": "湖面倒影与档案馆对齐，隐藏回廊显出了第一段轮廓。",
	&"archive_counterweight": "记忆石压住潮汐机关，回廊承认了物质的重量。",
	&"archive_name_lens": "铭名透镜聚焦：被抹去的名字重新照亮城门。",
}
const CITY_TRACE_TEXT := {
	&"city_station": "废站记录着年老的朔：他仍每天为无人乘坐的列车点灯。",
	&"city_market": "雨忆集市保存着年轻的朔：他相信停住灾难就能停住失去。",
	&"city_belltower": "钟楼残响将两个年龄重叠在一起：切断时间的人一直是朔。",
}
const CITY_RELAY_ORDER: Array[StringName] = [
	&"relay_dawn",
	&"relay_market",
	&"relay_bridge",
	&"relay_belltower",
]
const CITY_RELAY_TEXT := {
	&"relay_dawn": "晨灯回路重新通电，废站收到一班不存在的列车。",
	&"relay_market": "集市行灯逐盏回应，年轻的城市再次拥有影子。",
	&"relay_bridge": "断桥两端同步闪烁，两个年代短暂共享了重量。",
	&"relay_belltower": "钟楼主灯点亮，朔终于愿意留下完整证词。",
}
const CITY_TESTIMONY_TEXT := {
	&"trust_shuo": "你接受朔的证词：爱不能让时间停下，但可以陪它继续。",
	&"challenge_shuo": "你质问朔的选择：任何人都无权替整座城市拒绝明天。",
}
const RAIN_EYE_SEAL_TEXT := {
	&"eye_grove": "林地归档：遗忘不是空白，而是为新生留下的位置。",
	&"eye_archive": "档案归档：保存一切，也可能让时间再也无法前进。",
	&"eye_city": "城市归档：朔停住灾难，也把所有人困在了同一场雨里。",
}
const RAIN_EYE_TRIAL_ORDER: Array[StringName] = [
	&"trial_accept_loss",
	&"trial_carry_motion",
	&"trial_release_name",
]
const RAIN_EYE_TRIAL_TEXT := {
	&"trial_accept_loss": "失去被承认，雨眼不再把伤痕伪装成永恒。",
	&"trial_carry_motion": "你把前进的惯性带过时相裂缝，停滞开始松动。",
	&"trial_release_name": "霁放开最后一个旧名字，世界终于能替明天命名。",
}
const ENDING_TEXT := {
	&"merge_worlds": "合流：让两个时相重新成为一个完整、也会失去的世界。",
	&"guard_boundary": "守界：保留两个时相，由霁承担往返与守望。",
	&"tidal_order": "潮汐：让记住与遗忘周期流动，不再要求任何一方永恒。",
}

var persistent_id: StringName = &"narrative_director"
var stage: StringName = INTRO
var collected_memories: Array[StringName] = []
var activated_archive_anchors: Array[StringName] = []
var activated_archive_mechanisms: Array[StringName] = []
var archive_cipher_required := false
var archive_cipher_solved := false
var archive_cipher_attempts := 0
var activated_city_traces: Array[StringName] = []
var activated_city_relays: Array[StringName] = []
var city_testimony_id: StringName = &""
var has_entered_rain_eye := false
var activated_rain_eye_seals: Array[StringName] = []
var activated_rain_eye_trials: Array[StringName] = []
var alignment_id: StringName = &""
var ending_id: StringName = &""


func _ready() -> void:
	add_to_group("persistent")


func begin_journey() -> bool:
	if stage != INTRO:
		return false
	_set_stage(FIND_BELL)
	return true


func handle_bell_rung() -> bool:
	if stage != FIND_BELL:
		return false
	_set_stage(GATHER_MEMORIES)
	return true


func collect_memory(memory_id: StringName) -> bool:
	if stage != GATHER_MEMORIES:
		return false
	if not MEMORY_TEXT.has(memory_id) or collected_memories.has(memory_id):
		return false
	collected_memories.append(memory_id)
	memory_added.emit(memory_id, MEMORY_TEXT[memory_id], collected_memories.size())
	if collected_memories.size() == MEMORY_TEXT.size():
		_set_stage(AWAKEN_SHRINE)
		all_memories_collected.emit()
	else:
		objective_changed.emit(get_objective())
	return true


func handle_shrine_activated() -> bool:
	if stage != AWAKEN_SHRINE:
		return false
	_set_stage(MEMORY_ALIGNMENT)
	return true


func choose_alignment(choice_id: StringName) -> bool:
	if stage != MEMORY_ALIGNMENT or not ALIGNMENT_TEXT.has(choice_id):
		return false
	alignment_id = choice_id
	ending_id = &""
	alignment_chosen.emit(choice_id, ALIGNMENT_TEXT[choice_id])
	_set_stage(RIFT_READY)
	return true


func handle_rift_entered() -> bool:
	if stage != RIFT_READY:
		return false
	_set_stage(ARCHIVE_SEARCH)
	return true


func activate_archive_anchor(anchor_id: StringName) -> bool:
	if stage != ARCHIVE_SEARCH:
		return false
	if not ARCHIVE_ANCHOR_TEXT.has(anchor_id) or activated_archive_anchors.has(anchor_id):
		return false
	var expected_anchor := get_next_archive_anchor()
	if anchor_id != expected_anchor:
		archive_sequence_rejected.emit(
			anchor_id,
			expected_anchor,
			ARCHIVE_SEQUENCE_CLUE,
		)
		return false
	activated_archive_anchors.append(anchor_id)
	archive_anchor_added.emit(
		anchor_id,
		ARCHIVE_ANCHOR_TEXT[anchor_id],
		activated_archive_anchors.size(),
	)
	if activated_archive_anchors.size() == get_archive_anchor_order().size():
		_set_stage(ARCHIVE_MECHANISMS)
		archive_anchors_completed.emit()
	else:
		objective_changed.emit(get_objective())
	return true


func activate_archive_mechanism(mechanism_id: StringName) -> bool:
	if stage != ARCHIVE_MECHANISMS or mechanism_id != get_next_archive_mechanism():
		return false
	if archive_cipher_required and not archive_cipher_solved:
		return false
	activated_archive_mechanisms.append(mechanism_id)
	archive_mechanism_added.emit(
		mechanism_id,
		ARCHIVE_MECHANISM_TEXT[mechanism_id],
		activated_archive_mechanisms.size(),
	)
	if activated_archive_mechanisms.size() == get_archive_mechanism_order().size():
		_set_stage(ARCHIVE_RESTORED)
		archive_restored.emit()
	else:
		objective_changed.emit(get_objective())
	return true


func get_next_archive_mechanism() -> StringName:
	return _next_ordered_id(get_archive_mechanism_order(), activated_archive_mechanisms)


func configure_archive_cipher(required: bool) -> void:
	archive_cipher_required = required
	if not required:
		archive_cipher_solved = false


func get_archive_cipher_code() -> Array[int]:
	var code: Array[int] = []
	for anchor_id in get_archive_anchor_order():
		code.append(int(ARCHIVE_GLYPH_VALUES.get(anchor_id, 0)))
	# The first ring is deliberately not a direct transcription.  The phase
	# clue makes the extra turn deducible, while wrong-order anchors still reset
	# the sequence before the player ever reaches this console.
	var first_ring_offset := 1 if alignment_id == &"carry_the_light" else 3
	if not code.is_empty():
		code[0] = posmod(code[0] + first_ring_offset, 5)
	return code


func get_archive_cipher_clue() -> String:
	return (
		ARCHIVE_CIPHER_CLUE_CARRY
		if alignment_id == &"carry_the_light"
		else ARCHIVE_CIPHER_CLUE_RETURN
	)


func solve_archive_cipher(code: Array[int]) -> bool:
	if stage != ARCHIVE_MECHANISMS or not archive_cipher_required or archive_cipher_solved:
		return false
	archive_cipher_attempts += 1
	var normalized: Array[int] = []
	for value in code:
		normalized.append(int(value))
	if normalized != get_archive_cipher_code():
		archive_cipher_rejected.emit(normalized, get_archive_cipher_clue())
		return false
	archive_cipher_solved = true
	archive_cipher_completed.emit(normalized)
	objective_changed.emit(get_objective())
	return true


func note_archive_cipher_attempt() -> void:
	if stage == ARCHIVE_MECHANISMS and archive_cipher_required and not archive_cipher_solved:
		archive_cipher_attempts += 1


func get_archive_anchor_order() -> Array[StringName]:
	return (
		ARCHIVE_ANCHOR_ORDER_CARRY.duplicate()
		if alignment_id == &"carry_the_light"
		else ARCHIVE_ANCHOR_ORDER_RETURN.duplicate()
	)


func get_next_archive_anchor() -> StringName:
	return _next_ordered_id(get_archive_anchor_order(), activated_archive_anchors)


func get_archive_mechanism_order() -> Array[StringName]:
	# Carrying the light reverses the first two physical operations.  The
	# player must read the alignment consequence and choose the matching phase
	# before the same final name lens can be focused.
	if alignment_id == &"carry_the_light":
		return [&"archive_counterweight", &"archive_reflection", &"archive_name_lens"]
	return ARCHIVE_MECHANISM_ORDER.duplicate()


func handle_city_gate_entered() -> bool:
	if stage != ARCHIVE_RESTORED:
		return false
	_set_stage(CITY_GATE)
	return true


func handle_city_arrived() -> bool:
	if stage != CITY_GATE:
		return false
	_set_stage(LANTERN_CITY)
	return true


func activate_city_trace(trace_id: StringName) -> bool:
	if stage != LANTERN_CITY:
		return false
	if not CITY_TRACE_TEXT.has(trace_id) or activated_city_traces.has(trace_id):
		return false
	activated_city_traces.append(trace_id)
	city_trace_added.emit(trace_id, CITY_TRACE_TEXT[trace_id], activated_city_traces.size())
	if activated_city_traces.size() == CITY_TRACE_TEXT.size():
		_set_stage(CITY_RELAYS)
		city_traces_completed.emit()
	else:
		objective_changed.emit(get_objective())
	return true


func activate_city_relay(relay_id: StringName) -> bool:
	if stage != CITY_RELAYS or relay_id != get_next_city_relay():
		return false
	activated_city_relays.append(relay_id)
	city_relay_added.emit(relay_id, CITY_RELAY_TEXT[relay_id], activated_city_relays.size())
	if activated_city_relays.size() == CITY_RELAY_ORDER.size():
		_set_stage(CITY_COUNCIL)
		city_relays_completed.emit()
	else:
		objective_changed.emit(get_objective())
	return true


func get_next_city_relay() -> StringName:
	return _next_ordered_id(CITY_RELAY_ORDER, activated_city_relays)


func choose_city_testimony(testimony_id: StringName) -> bool:
	if stage != CITY_COUNCIL or not CITY_TESTIMONY_TEXT.has(testimony_id):
		return false
	city_testimony_id = testimony_id
	city_testimony_chosen.emit(testimony_id, CITY_TESTIMONY_TEXT[testimony_id])
	_set_stage(RAIN_EYE)
	city_route_completed.emit()
	return true


func handle_rain_eye_entered() -> bool:
	if stage != RAIN_EYE or has_entered_rain_eye:
		return false
	has_entered_rain_eye = true
	rain_eye_entered.emit()
	objective_changed.emit(get_objective())
	return true


func activate_rain_eye_seal(seal_id: StringName) -> bool:
	if stage != RAIN_EYE or not has_entered_rain_eye:
		return false
	if not RAIN_EYE_SEAL_TEXT.has(seal_id) or activated_rain_eye_seals.has(seal_id):
		return false
	activated_rain_eye_seals.append(seal_id)
	rain_eye_seal_added.emit(
		seal_id,
		RAIN_EYE_SEAL_TEXT[seal_id],
		activated_rain_eye_seals.size(),
	)
	if activated_rain_eye_seals.size() == RAIN_EYE_SEAL_TEXT.size():
		_set_stage(RAIN_EYE_TRIALS)
		rain_eye_seals_completed.emit()
	else:
		objective_changed.emit(get_objective())
	return true


func activate_rain_eye_trial(trial_id: StringName) -> bool:
	if stage != RAIN_EYE_TRIALS or trial_id != get_next_rain_eye_trial():
		return false
	activated_rain_eye_trials.append(trial_id)
	rain_eye_trial_added.emit(
		trial_id,
		RAIN_EYE_TRIAL_TEXT[trial_id],
		activated_rain_eye_trials.size(),
	)
	if activated_rain_eye_trials.size() == RAIN_EYE_TRIAL_ORDER.size():
		_set_stage(FINAL_DECISION)
		final_decision_ready.emit()
	else:
		objective_changed.emit(get_objective())
	return true


func get_next_rain_eye_trial() -> StringName:
	return _next_ordered_id(RAIN_EYE_TRIAL_ORDER, activated_rain_eye_trials)


func get_available_endings() -> Array[StringName]:
	var result: Array[StringName] = [&"merge_worlds", &"guard_boundary"]
	if alignment_id == &"return_to_lake" and city_testimony_id == &"trust_shuo":
		result.append(&"tidal_order")
	return result


func choose_ending(choice_id: StringName) -> bool:
	if stage == MEMORY_ALIGNMENT:
		return choose_alignment(choice_id)
	if stage != FINAL_DECISION or not get_available_endings().has(choice_id):
		return false
	ending_id = choice_id
	_set_stage(COMPLETE)
	ending_chosen.emit(choice_id, ENDING_TEXT[choice_id])
	return true


func get_objective() -> String:
	match stage:
		INTRO:
			return "雨忘记了如何落下"
		FIND_BELL:
			return "找到林间风铃并奏响它"
		GATHER_MEMORIES:
			return "寻找湖中记忆（%d / %d）" % [collected_memories.size(), MEMORY_TEXT.size()]
		AWAKEN_SHRINE:
			return "带着完整记忆，唤醒林中神龛"
		MEMORY_ALIGNMENT:
			return "决定如何携带林地的记忆"
		RIFT_READY:
			return "走近雨隙，按 Q 跨入另一时相"
		ARCHIVE_SEARCH:
			return "依残句解开沉雨档案锚点（%d / %d）" % [activated_archive_anchors.size(), get_archive_anchor_order().size()]
		ARCHIVE_MECHANISMS:
			if archive_cipher_required and not archive_cipher_solved:
				return "解开沉雨档案三重符文校准（读懂锚点顺序）"
			var next_archive := get_next_archive_mechanism()
			match next_archive:
				&"archive_reflection":
					return "回到此岸，在湖中校准倒影机关"
				&"archive_counterweight":
					return "进入雨忆，用记忆石压住档案配重板"
				&"archive_name_lens":
					return "回到此岸，聚焦神龛后的铭名透镜"
			return "完成档案馆机关（%d / %d）" % [activated_archive_mechanisms.size(), get_archive_mechanism_order().size()]
		ARCHIVE_RESTORED:
			return "档案馆已复原：穿过通往行灯之城的门"
		CITY_GATE:
			return "穿过城门，追随仍在行走的灯"
		LANTERN_CITY:
			return "在两段城市时间中追踪守灯人（%d / %d）" % [activated_city_traces.size(), CITY_TRACE_TEXT.size()]
		CITY_RELAYS:
			return "依次接通跨时相行灯回路（%d / %d）" % [activated_city_relays.size(), CITY_RELAY_ORDER.size()]
		CITY_COUNCIL:
			return "在钟楼前回应朔的完整证词"
		RAIN_EYE:
			if not has_entered_rain_eye:
				return "进入雨眼，阻止两个时相同时崩解"
			return "完成最后的记忆归档（%d / %d）" % [activated_rain_eye_seals.size(), RAIN_EYE_SEAL_TEXT.size()]
		RAIN_EYE_TRIALS:
			return "沿交替道路完成雨眼共振试炼（%d / %d）" % [activated_rain_eye_trials.size(), RAIN_EYE_TRIAL_ORDER.size()]
		FINAL_DECISION:
			return "决定世界最终记住哪一场雨"
		COMPLETE:
			return "旅程完成"
	return ""


func get_chapter_title() -> String:
	if stage in [
		INTRO, FIND_BELL, GATHER_MEMORIES, AWAKEN_SHRINE,
		MEMORY_ALIGNMENT, RIFT_READY,
	]:
		return "第一幕 · 微光林地"
	if stage in [ARCHIVE_SEARCH, ARCHIVE_MECHANISMS, ARCHIVE_RESTORED]:
		return "第二幕 · 沉雨档案"
	if stage in [CITY_GATE, LANTERN_CITY, CITY_RELAYS, CITY_COUNCIL]:
		return "第三幕 · 行灯之城"
	if stage in [RAIN_EYE, RAIN_EYE_TRIALS, FINAL_DECISION]:
		return "第四幕 · 雨眼"
	return "尾声 · 雨后的名字"


func get_campaign_progress() -> float:
	var stage_count := float(_campaign_stage_index(COMPLETE))
	var base := float(maxi(0, _campaign_stage_index(stage)))
	var fraction := 0.0
	match stage:
		GATHER_MEMORIES:
			fraction = float(collected_memories.size()) / float(MEMORY_TEXT.size())
		ARCHIVE_SEARCH:
			fraction = float(activated_archive_anchors.size()) / float(get_archive_anchor_order().size())
		ARCHIVE_MECHANISMS:
			fraction = float(activated_archive_mechanisms.size() + (1 if archive_cipher_solved else 0)) / float(get_archive_mechanism_order().size() + (1 if archive_cipher_required else 0))
		LANTERN_CITY:
			fraction = float(activated_city_traces.size()) / float(CITY_TRACE_TEXT.size())
		CITY_RELAYS:
			fraction = float(activated_city_relays.size()) / float(CITY_RELAY_ORDER.size())
		RAIN_EYE:
			fraction = float(activated_rain_eye_seals.size()) / float(RAIN_EYE_SEAL_TEXT.size()) if has_entered_rain_eye else 0.0
		RAIN_EYE_TRIALS:
			fraction = float(activated_rain_eye_trials.size()) / float(RAIN_EYE_TRIAL_ORDER.size())
	return clampf((base + fraction) / stage_count, 0.0, 1.0)


func capture_state() -> Dictionary:
	return {
		"campaign_version": CAMPAIGN_VERSION,
		"stage": str(stage),
		"memory_ids": _string_array(collected_memories),
		"archive_anchor_ids": _string_array(activated_archive_anchors),
		"archive_mechanism_ids": _string_array(activated_archive_mechanisms),
		"archive_cipher_solved": archive_cipher_solved,
		"archive_cipher_attempts": archive_cipher_attempts,
		"city_trace_ids": _string_array(activated_city_traces),
		"city_relay_ids": _string_array(activated_city_relays),
		"city_testimony_id": str(city_testimony_id),
		"has_entered_rain_eye": has_entered_rain_eye,
		"rain_eye_seal_ids": _string_array(activated_rain_eye_seals),
		"rain_eye_trial_ids": _string_array(activated_rain_eye_trials),
		"alignment_id": str(alignment_id),
		"ending_id": str(ending_id),
	}


func restore_state(state_data: Dictionary) -> void:
	var campaign_version := int(state_data.get("campaign_version", 1))
	var restored_stage := StringName(str(state_data.get("stage", FIND_BELL)))
	if restored_stage == &"final_choice":
		restored_stage = MEMORY_ALIGNMENT
	elif restored_stage == COMPLETE and campaign_version < 2:
		restored_stage = RIFT_READY
	var valid_stages: Array[StringName] = [
		INTRO, FIND_BELL, GATHER_MEMORIES, AWAKEN_SHRINE, MEMORY_ALIGNMENT,
		RIFT_READY, ARCHIVE_SEARCH, ARCHIVE_MECHANISMS, ARCHIVE_RESTORED,
		CITY_GATE, LANTERN_CITY, CITY_RELAYS, CITY_COUNCIL, RAIN_EYE,
		RAIN_EYE_TRIALS, FINAL_DECISION, COMPLETE,
	]
	stage = restored_stage if valid_stages.has(restored_stage) else FIND_BELL
	_restore_ids(collected_memories, state_data.get("memory_ids", []), MEMORY_TEXT.keys())
	_restore_ids(activated_archive_anchors, state_data.get("archive_anchor_ids", []), ARCHIVE_ANCHOR_TEXT.keys())
	_restore_ids(activated_archive_mechanisms, state_data.get("archive_mechanism_ids", []), ARCHIVE_MECHANISM_ORDER)
	archive_cipher_solved = bool(state_data.get("archive_cipher_solved", false))
	archive_cipher_attempts = int(state_data.get("archive_cipher_attempts", 0))
	_restore_ids(activated_city_traces, state_data.get("city_trace_ids", []), CITY_TRACE_TEXT.keys())
	_restore_ids(activated_city_relays, state_data.get("city_relay_ids", []), CITY_RELAY_ORDER)
	city_testimony_id = StringName(str(state_data.get("city_testimony_id", "")))
	if not CITY_TESTIMONY_TEXT.has(city_testimony_id):
		city_testimony_id = &""
	has_entered_rain_eye = bool(state_data.get("has_entered_rain_eye", stage in [RAIN_EYE_TRIALS, FINAL_DECISION, COMPLETE]))
	_restore_ids(activated_rain_eye_seals, state_data.get("rain_eye_seal_ids", []), RAIN_EYE_SEAL_TEXT.keys())
	_restore_ids(activated_rain_eye_trials, state_data.get("rain_eye_trial_ids", []), RAIN_EYE_TRIAL_ORDER)
	alignment_id = StringName(str(state_data.get("alignment_id", state_data.get("ending_id", ""))))
	if not ALIGNMENT_TEXT.has(alignment_id):
		alignment_id = &""
	ending_id = StringName(str(state_data.get("ending_id", "")))
	if stage != COMPLETE or not ENDING_TEXT.has(ending_id):
		ending_id = &""
	_migrate_expanded_campaign(campaign_version)
	objective_changed.emit(get_objective())


func _migrate_expanded_campaign(campaign_version: int) -> void:
	if campaign_version >= CAMPAIGN_VERSION:
		return
	if campaign_version < 7 and stage == ARCHIVE_SEARCH:
		# Anchor progress was previously order-independent.  Do not carry an
		# invalid partial sequence into the stricter cipher puzzle.
		activated_archive_anchors.clear()
	if campaign_version < 7 and stage == ARCHIVE_MECHANISMS:
		# The old build exposed a single mechanism order. Restart a partial
		# mechanism sequence so a carry-the-light save cannot point at a step it
		# already completed under the old order.
		activated_archive_mechanisms.clear()
	if campaign_version < 8 and stage == ARCHIVE_MECHANISMS:
		archive_cipher_solved = false
		archive_cipher_attempts = 0
	var stage_index := _campaign_stage_index(stage)
	if stage_index >= _campaign_stage_index(ARCHIVE_RESTORED):
		activated_archive_mechanisms.assign(get_archive_mechanism_order())
	if stage_index >= _campaign_stage_index(RAIN_EYE):
		activated_city_relays.assign(CITY_RELAY_ORDER)
		if city_testimony_id.is_empty():
			city_testimony_id = &"trust_shuo"
	if stage_index >= _campaign_stage_index(FINAL_DECISION):
		activated_rain_eye_trials.assign(RAIN_EYE_TRIAL_ORDER)


func _campaign_stage_index(value: StringName) -> int:
	var order: Array[StringName] = [
		INTRO, FIND_BELL, GATHER_MEMORIES, AWAKEN_SHRINE, MEMORY_ALIGNMENT,
		RIFT_READY, ARCHIVE_SEARCH, ARCHIVE_MECHANISMS, ARCHIVE_RESTORED,
		CITY_GATE, LANTERN_CITY, CITY_RELAYS, CITY_COUNCIL, RAIN_EYE,
		RAIN_EYE_TRIALS, FINAL_DECISION, COMPLETE,
	]
	return order.find(value)


func _next_ordered_id(order: Array[StringName], completed: Array[StringName]) -> StringName:
	return order[completed.size()] if completed.size() < order.size() else &""


func _string_array(values: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	return result


func _restore_ids(target: Array[StringName], values: Array, valid_values: Array) -> void:
	target.clear()
	for value in values:
		var restored_id := StringName(str(value))
		if valid_values.has(restored_id) and not target.has(restored_id):
			target.append(restored_id)


func _set_stage(next_stage: StringName) -> void:
	if next_stage == stage:
		return
	var previous := stage
	stage = next_stage
	stage_changed.emit(previous, stage)
	objective_changed.emit(get_objective())
