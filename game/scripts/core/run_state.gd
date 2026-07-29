class_name AshenRunState
extends RefCounted

const SCHEMA_VERSION := 1
const DEFAULT_CHECKPOINT := "ember_shrine"

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


func to_dictionary() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"checkpoint_id": checkpoint_id,
		"embers": embers,
		"focus": focus,
		"combat_style": combat_style,
		"lost_echo": {
			"amount": lost_echo_amount,
			"position": [
				lost_echo_position.x,
				lost_echo_position.y,
				lost_echo_position.z,
			],
		},
		"activated_shortcuts": activated_shortcuts.duplicate(),
		"guardian_defeated": guardian_defeated,
		"play_time_ms": play_time_ms,
	}


func to_bridge_dictionary() -> Dictionary:
	return {
		"schemaVersion": SCHEMA_VERSION,
		"checkpointId": checkpoint_id,
		"embers": embers,
		"focus": focus,
		"combatStyle": combat_style,
		"lostEcho": {
			"amount": lost_echo_amount,
			"position": [
				lost_echo_position.x,
				lost_echo_position.y,
				lost_echo_position.z,
			],
		},
		"activatedShortcuts": activated_shortcuts.duplicate(),
		"shortcutOpen": "ancient_gate" in activated_shortcuts,
		"guardianDefeated": guardian_defeated,
		"playTimeMs": play_time_ms,
		"updatedAtEpochMs": int(Time.get_unix_time_from_system() * 1000.0),
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
	var schema_version := int(data.get("schema_version", data.get("schemaVersion", -1)))
	if schema_version != SCHEMA_VERSION:
		return null
	var parsed_checkpoint := String(
		data.get("checkpoint_id", data.get("checkpointId", ""))
	).strip_edges()
	if parsed_checkpoint.is_empty():
		return null

	var state = new()
	state.checkpoint_id = parsed_checkpoint
	state.embers = maxi(int(data.get("embers", 0)), 0)
	state.focus = clampf(float(data.get("focus", 80.0)), 0.0, 80.0)
	state.combat_style = clampi(int(data.get("combat_style", data.get("combatStyle", 0))), 0, 4)
	state.guardian_defeated = bool(
		data.get("guardian_defeated", data.get("guardianDefeated", false))
	)
	state.play_time_ms = maxi(int(data.get("play_time_ms", data.get("playTimeMs", 0))), 0)

	var lost_echo = data.get("lost_echo", data.get("lostEcho", {}))
	if lost_echo is Dictionary:
		state.lost_echo_amount = maxi(int(lost_echo.get("amount", 0)), 0)
		state.lost_echo_position = _vector3_from_value(
			lost_echo.get("position", []),
			Vector3.ZERO
		)

	var shortcuts = data.get("activated_shortcuts", data.get("activatedShortcuts", []))
	if shortcuts is Array:
		for value in shortcuts:
			var shortcut_id := String(value).strip_edges()
			if not shortcut_id.is_empty() and shortcut_id not in state.activated_shortcuts:
				state.activated_shortcuts.append(shortcut_id)
	if bool(data.get("shortcutOpen", false)) and "ancient_gate" not in state.activated_shortcuts:
		state.activated_shortcuts.append("ancient_gate")
	return state


static func load_from_path(path: String):
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	return from_json(file.get_as_text())


static func _vector3_from_value(value: Variant, fallback: Vector3) -> Vector3:
	if value is Array and value.size() >= 3:
		return Vector3(
			float(value[0]),
			float(value[1]),
			float(value[2])
		)
	if value is Dictionary:
		return Vector3(
			float(value.get("x", fallback.x)),
			float(value.get("y", fallback.y)),
			float(value.get("z", fallback.z))
		)
	return fallback
