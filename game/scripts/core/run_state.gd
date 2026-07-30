class_name AshenRunState
extends RefCounted

const SCHEMA_VERSION := 2
const LEGACY_SCHEMA_VERSION := 1
const DEFAULT_CHAPTER_ID := "chapter_01"
const DEFAULT_LEVEL_ID := "level_01_01"
const DEFAULT_CHECKPOINT := "ember_shrine"
const LEGACY_SHORTCUT_ID := "ancient_gate"
const SCOPED_SHORTCUT_ID := "ember_shrine:ancient_gate"
const GUARDIAN_BOSS_ID := "boss_giant_gate"
const STYLE_LOADOUTS := [
	{"right_hand": "guardian_sword", "left_hand": "reliquary_shield"},
	{"right_hand": "xingtian_axe_right", "left_hand": "xingtian_axe_left"},
	{"right_hand": "marksman_bow", "left_hand": "marksman_dagger"},
	{"right_hand": "five_elements_seal", "left_hand": "spirit_stone"},
	{"right_hand": "prayer_beads", "left_hand": "talisman_papers"},
]

var checkpoint_id := DEFAULT_CHECKPOINT
var embers := 0
var focus := 80.0
var combat_style := 0
var lost_echo_amount := 0
var lost_echo_position := Vector3.ZERO
var activated_shortcuts: Array[String] = []
var guardian_defeated := false
var upgrade_tier := 0
var play_time_ms := 0

var chapter_id := DEFAULT_CHAPTER_ID
var level_id := DEFAULT_LEVEL_ID
var location := DEFAULT_CHECKPOINT
var right_hand := String(STYLE_LOADOUTS[0]["right_hand"])
var left_hand := String(STYLE_LOADOUTS[0]["left_hand"])
var inventory: Dictionary = {}
var completed_levels: Array[String] = []
var defeated_bosses: Array[String] = []
var activated_checkpoints: Array[String] = []
var completed_puzzles: Array[String] = []
var collected_loot: Array[String] = []
var choice_flags: Dictionary = {}
var progression_values: Dictionary = {}


func to_dictionary() -> Dictionary:
	_sync_compatibility_fields()
	return {
		"schema_version": SCHEMA_VERSION,
		"checkpoint_id": checkpoint_id,
		"embers": embers,
		"focus": focus,
		"combat_style": combat_style,
		"lost_echo": _lost_echo_dictionary(),
		"activated_shortcuts": activated_shortcuts.duplicate(),
		"guardian_defeated": guardian_defeated,
		"upgrade_tier": upgrade_tier,
		"play_time_ms": play_time_ms,
		"chapter_id": chapter_id,
		"level_id": level_id,
		"location": location,
		"right_hand": right_hand,
		"left_hand": left_hand,
		"inventory": inventory.duplicate(true),
		"completed_levels": completed_levels.duplicate(),
		"defeated_bosses": defeated_bosses.duplicate(),
		"activated_checkpoints": activated_checkpoints.duplicate(),
		"completed_puzzles": completed_puzzles.duplicate(),
		"collected_loot": collected_loot.duplicate(),
		"choice_flags": choice_flags.duplicate(true),
		"progression_values": progression_values.duplicate(true),
	}


func to_bridge_dictionary() -> Dictionary:
	_sync_compatibility_fields()
	return {
		"schemaVersion": SCHEMA_VERSION,
		"location": {
			"chapterId": chapter_id,
			"levelId": level_id,
			"checkpointId": checkpoint_id,
		},
		"player": {
			"embers": embers,
			"focus": focus,
			"upgradeTier": upgrade_tier,
			"rightHand": right_hand,
			"leftHand": left_hand if not left_hand.is_empty() else null,
		},
		"inventory": inventory.duplicate(true),
		"progression": {
			"activatedShortcutIds": activated_shortcuts.duplicate(),
			"defeatedBossIds": defeated_bosses.duplicate(),
			"choiceFlags": choice_flags.duplicate(true),
			"values": progression_values.duplicate(true),
			"completedLevelIds": completed_levels.duplicate(),
			"activatedCheckpointIds": activated_checkpoints.duplicate(),
			"completedPuzzleIds": completed_puzzles.duplicate(),
			"collectedLootIds": collected_loot.duplicate(),
		},
		"lostEcho": {
			"amount": lost_echo_amount,
			"levelId": level_id,
			"position": _vector3_array(lost_echo_position),
		},
		"playTimeMs": play_time_ms,
		"updatedAtEpochMs": int(Time.get_unix_time_from_system() * 1000.0),
		"checkpointId": checkpoint_id,
		"embers": embers,
		"focus": focus,
		"combatStyle": combat_style,
		"activatedShortcuts": activated_shortcuts.duplicate(),
		"shortcutOpen": LEGACY_SHORTCUT_ID in activated_shortcuts,
		"guardianDefeated": guardian_defeated,
		"upgradeTier": upgrade_tier,
		"rightHand": right_hand,
		"leftHand": left_hand,
	}


func to_json() -> String:
	return JSON.stringify(to_dictionary())


func save_to_path(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(to_json())
	return true


static func from_json(text: String):
	var decoded = JSON.parse_string(text)
	if not decoded is Dictionary:
		return null
	return from_dictionary(decoded)


static func from_dictionary(data: Dictionary):
	var raw_schema = _get_value(data, "schema_version", "schemaVersion", null)
	if not _is_integer(raw_schema):
		return null
	var schema_version := int(raw_schema)
	if schema_version != LEGACY_SCHEMA_VERSION and schema_version != SCHEMA_VERSION:
		return null

	var nested_v2 := schema_version == SCHEMA_VERSION and data.get("location") is Dictionary
	var location_data: Dictionary = data.get("location", {}) if nested_v2 else {}
	var player_data: Dictionary = data.get("player", {}) if nested_v2 else data
	var progression_data: Dictionary = data.get("progression", {}) if nested_v2 else data
	var raw_checkpoint = location_data.get("checkpointId") if nested_v2 else _get_value(data, "checkpoint_id", "checkpointId", null)
	if not raw_checkpoint is String:
		return null
	var parsed_checkpoint := String(raw_checkpoint).strip_edges()
	if parsed_checkpoint.is_empty():
		return null

	var state = new()
	state.checkpoint_id = parsed_checkpoint
	if not _read_non_negative_int(player_data, "embers", "embers", state, "embers", 0):
		return null
	if not _read_float_range(player_data, "focus", "focus", state, "focus", 80.0, 0.0, 80.0):
		return null
	if not _read_int_range(data, "combat_style", "combatStyle", state, "combat_style", 0, 0, 4):
		return null
	if not _read_non_negative_int(player_data, "upgrade_tier", "upgradeTier", state, "upgrade_tier", 0):
		return null
	if not _read_non_negative_int(data, "play_time_ms", "playTimeMs", state, "play_time_ms", 0):
		return null

	var raw_flags = progression_data.get(
		"choiceFlags",
		progression_data.get("flags", {})
	) if nested_v2 else {}
	if not raw_flags is Dictionary:
		return null
	var raw_guardian = _get_value(data, "guardian_defeated", "guardianDefeated", raw_flags.get("guardianDefeated", false))
	if not raw_guardian is bool:
		return null
	state.guardian_defeated = raw_guardian

	var lost_echo = _get_value(data, "lost_echo", "lostEcho", {})
	if not lost_echo is Dictionary:
		return null
	var raw_echo_amount = lost_echo.get("amount", 0)
	if not _is_integer(raw_echo_amount) or int(raw_echo_amount) < 0:
		return null
	state.lost_echo_amount = int(raw_echo_amount)
	var raw_echo_position = lost_echo.get("location", lost_echo.get("position", [0.0, 0.0, 0.0]))
	if not _is_vector3_value(raw_echo_position):
		return null
	state.lost_echo_position = _vector3_from_value(raw_echo_position, Vector3.ZERO)

	var shortcuts = progression_data.get("activatedShortcutIds", []) if nested_v2 else _get_value(data, "activated_shortcuts", "activatedShortcuts", [])
	if not _read_string_array(shortcuts, state.activated_shortcuts):
		return null
	var shortcut_open = data.get("shortcutOpen", false)
	if not shortcut_open is bool:
		return null
	if shortcut_open:
		_append_unique(state.activated_shortcuts, LEGACY_SHORTCUT_ID)
	_migrate_shortcut_ids(state.activated_shortcuts)

	if schema_version == LEGACY_SCHEMA_VERSION:
		state.chapter_id = DEFAULT_CHAPTER_ID
		state.level_id = DEFAULT_LEVEL_ID
		state.location = state.checkpoint_id
		state.right_hand = String(STYLE_LOADOUTS[state.combat_style]["right_hand"])
		state.left_hand = String(STYLE_LOADOUTS[state.combat_style]["left_hand"])
		_append_unique(state.activated_checkpoints, state.checkpoint_id)
	elif not _read_v2_fields(data, state, nested_v2):
		return null
	if state.progression_values.has("legacyCombatStyle"):
		var legacy_style = state.progression_values["legacyCombatStyle"]
		if (
			not _is_integer(legacy_style)
			or int(legacy_style) < 0
			or int(legacy_style) >= STYLE_LOADOUTS.size()
		):
			return null
		state.combat_style = int(legacy_style)

	if state.guardian_defeated:
		_append_unique(state.defeated_bosses, GUARDIAN_BOSS_ID)
	if GUARDIAN_BOSS_ID in state.defeated_bosses:
		state.guardian_defeated = true
	return state


static func load_from_path(path: String):
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	return from_json(file.get_as_text())


func _sync_compatibility_fields() -> void:
	if location.strip_edges().is_empty():
		location = checkpoint_id
	_append_unique(activated_checkpoints, checkpoint_id)
	_migrate_shortcut_ids(activated_shortcuts)
	if guardian_defeated:
		_append_unique(defeated_bosses, GUARDIAN_BOSS_ID)
	if GUARDIAN_BOSS_ID in defeated_bosses:
		guardian_defeated = true


func _lost_echo_dictionary() -> Dictionary:
	return {
		"amount": lost_echo_amount,
		"position": _vector3_array(lost_echo_position),
	}


static func _vector3_array(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


static func _read_v2_fields(data: Dictionary, state, nested: bool) -> bool:
	if nested:
		return _read_nested_v2_fields(data, state)

	var raw_location = data.get("location", null)
	if not raw_location is String or String(raw_location).strip_edges().is_empty():
		return false
	state.location = String(raw_location).strip_edges()
	state.chapter_id = String(_get_value(data, "chapter_id", "chapterId", DEFAULT_CHAPTER_ID)).strip_edges()
	state.level_id = String(_get_value(data, "level_id", "levelId", DEFAULT_LEVEL_ID)).strip_edges()
	if state.chapter_id.is_empty() or state.level_id.is_empty():
		return false

	var raw_right_hand = _get_value(data, "right_hand", "rightHand", null)
	var raw_left_hand = _get_value(data, "left_hand", "leftHand", null)
	if not raw_right_hand is String or not raw_left_hand is String:
		return false
	state.right_hand = raw_right_hand
	state.left_hand = raw_left_hand

	var raw_inventory = data.get("inventory", null)
	var raw_choice_flags = _get_value(data, "choice_flags", "choiceFlags", null)
	var raw_progression_values = _get_value(data, "progression_values", "progressionValues", {})
	if not raw_inventory is Dictionary or not raw_choice_flags is Dictionary or not raw_progression_values is Dictionary:
		return false
	state.inventory = raw_inventory.duplicate(true)
	state.choice_flags = raw_choice_flags.duplicate(true)
	state.progression_values = raw_progression_values.duplicate(true)
	if not _is_non_negative_int_map(state.inventory) or not _is_choice_flags_map(state.choice_flags) or not _is_non_negative_int_map(state.progression_values):
		return false

	var fields := [
		["completed_levels", "completedLevels", state.completed_levels],
		["defeated_bosses", "defeatedBosses", state.defeated_bosses],
		["activated_checkpoints", "activatedCheckpoints", state.activated_checkpoints],
		["completed_puzzles", "completedPuzzles", state.completed_puzzles],
		["collected_loot", "collectedLoot", state.collected_loot],
	]
	for field in fields:
		var raw_values = _get_value(data, field[0], field[1], null)
		if not _read_string_array(raw_values, field[2]):
			return false
	return true


static func _read_nested_v2_fields(data: Dictionary, state) -> bool:
	var raw_location = data.get("location")
	var raw_player = data.get("player")
	var raw_inventory = data.get("inventory")
	var raw_progression = data.get("progression")
	if not raw_location is Dictionary or not raw_player is Dictionary or not raw_inventory is Dictionary or not raw_progression is Dictionary:
		return false
	state.chapter_id = String(raw_location.get("chapterId", "")).strip_edges()
	state.level_id = String(raw_location.get("levelId", "")).strip_edges()
	state.location = state.checkpoint_id
	if state.chapter_id.is_empty() or state.level_id.is_empty():
		return false

	var raw_right_hand = raw_player.get("rightHand")
	var raw_left_hand = raw_player.get("leftHand")
	if not raw_right_hand is String or String(raw_right_hand).strip_edges().is_empty():
		return false
	if raw_left_hand != null and (not raw_left_hand is String or String(raw_left_hand).strip_edges().is_empty()):
		return false
	state.right_hand = String(raw_right_hand).strip_edges()
	state.left_hand = "" if raw_left_hand == null else String(raw_left_hand).strip_edges()

	var raw_flags = raw_progression.get(
		"choiceFlags",
		raw_progression.get("flags")
	)
	var raw_values = raw_progression.get("values")
	if not raw_flags is Dictionary or not raw_values is Dictionary:
		return false
	state.inventory = raw_inventory.duplicate(true)
	state.choice_flags = raw_flags.duplicate(true)
	state.progression_values = raw_values.duplicate(true)
	if not _is_non_negative_int_map(state.inventory) or not _is_choice_flags_map(state.choice_flags) or not _is_non_negative_int_map(state.progression_values):
		return false

	var fields := [
		["defeatedBossIds", "", state.defeated_bosses, false],
		["completedLevelIds", "completedLevels", state.completed_levels, true],
		["activatedCheckpointIds", "activatedCheckpoints", state.activated_checkpoints, true],
		["completedPuzzleIds", "completedPuzzles", state.completed_puzzles, true],
		["collectedLootIds", "collectedLoot", state.collected_loot, true],
	]
	for field in fields:
		var fallback = [] if field[3] else null
		var raw_list = raw_progression.get(field[0], raw_progression.get(field[1], fallback) if not String(field[1]).is_empty() else fallback)
		if not _read_string_array(raw_list, field[2]):
			return false
	return true


static func _read_non_negative_int(data: Dictionary, snake_key: String, camel_key: String, state, property: String, default_value: int) -> bool:
	var value = _get_value(data, snake_key, camel_key, default_value)
	if not _is_integer(value) or int(value) < 0:
		return false
	state.set(property, int(value))
	return true


static func _read_int_range(data: Dictionary, snake_key: String, camel_key: String, state, property: String, default_value: int, minimum: int, maximum: int) -> bool:
	var value = _get_value(data, snake_key, camel_key, default_value)
	if not _is_integer(value) or int(value) < minimum or int(value) > maximum:
		return false
	state.set(property, int(value))
	return true


static func _read_float_range(data: Dictionary, snake_key: String, camel_key: String, state, property: String, default_value: float, minimum: float, maximum: float) -> bool:
	var value = _get_value(data, snake_key, camel_key, default_value)
	if not _is_number(value):
		return false
	var parsed := float(value)
	if parsed < minimum or parsed > maximum:
		return false
	state.set(property, parsed)
	return true


static func _read_string_array(value: Variant, target: Array[String]) -> bool:
	if not value is Array:
		return false
	for item in value:
		if not item is String:
			return false
		var parsed := String(item).strip_edges()
		if parsed.is_empty():
			return false
		_append_unique(target, parsed)
	return true


static func _is_non_negative_int_map(value: Dictionary) -> bool:
	for key in value:
		if not key is String or String(key).strip_edges().is_empty():
			return false
		if not _is_integer(value[key]) or int(value[key]) < 0:
			return false
	return true


func set_choice_flag(flag: StringName, value: Variant) -> void:
	# 允许 bool（旧档）或 String（命运旗标）
	var key := String(flag).strip_edges()
	if key.is_empty():
		return
	if value is bool or value is String:
		choice_flags[key] = value
	else:
		choice_flags[key] = str(value)


func get_choice_flag(flag: StringName, default_value: Variant = null) -> Variant:
	return choice_flags.get(String(flag), default_value)


static func _is_bool_map(value: Dictionary) -> bool:
	for key in value:
		if not key is String or String(key).strip_edges().is_empty() or not value[key] is bool:
			return false
	return true


static func _is_choice_flags_map(value: Dictionary) -> bool:
	# 兼容旧 bool 与叙事字符串旗标
	for key in value:
		if not key is String or String(key).strip_edges().is_empty():
			return false
		var v = value[key]
		if not (v is bool or v is String):
			return false
		if v is String and String(v).strip_edges().is_empty():
			return false
	return true


static func _migrate_shortcut_ids(shortcuts: Array[String]) -> void:
	if LEGACY_SHORTCUT_ID in shortcuts:
		_append_unique(shortcuts, SCOPED_SHORTCUT_ID)
	if SCOPED_SHORTCUT_ID in shortcuts:
		_append_unique(shortcuts, LEGACY_SHORTCUT_ID)


static func _append_unique(values: Array[String], value: String) -> void:
	if value not in values:
		values.append(value)


static func _get_value(data: Dictionary, snake_key: String, camel_key: String, fallback: Variant) -> Variant:
	if data.has(snake_key):
		return data[snake_key]
	return data.get(camel_key, fallback)


static func _is_integer(value: Variant) -> bool:
	return value is int or value is float and is_finite(float(value)) and float(value) == floorf(value)


static func _is_number(value: Variant) -> bool:
	return value is int or value is float and is_finite(float(value))


static func _is_vector3_value(value: Variant) -> bool:
	if value is Array:
		return value.size() == 3 and _is_number(value[0]) and _is_number(value[1]) and _is_number(value[2])
	if value is Dictionary:
		return _is_number(value.get("x")) and _is_number(value.get("y")) and _is_number(value.get("z"))
	return false


static func _vector3_from_value(value: Variant, fallback: Vector3) -> Vector3:
	if value is Array:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	if value is Dictionary:
		return Vector3(float(value["x"]), float(value["y"]), float(value["z"]))
	return fallback
