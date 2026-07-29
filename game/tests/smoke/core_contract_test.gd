extends SceneTree

const RunStateScript = preload("res://scripts/core/run_state.gd")
const SettingsScript = preload("res://scripts/core/game_settings.gd")
const BridgeScript = preload("res://scripts/app/game_host_bridge.gd")

var _failures: Array[String] = []


func _init() -> void:
	_test_run_state_round_trip()
	_test_run_state_rejects_invalid_data()
	_test_settings_sanitize_values()
	_test_bridge_contract()
	if _failures.is_empty():
		print("ASHEN_CORE_CONTRACTS_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_run_state_round_trip() -> void:
	var state = RunStateScript.new()
	state.checkpoint_id = "ember_shrine"
	state.embers = 321
	state.focus = 37.0
	state.combat_style = 3
	state.lost_echo_amount = 44
	state.lost_echo_position = Vector3(1.0, 2.0, 3.0)
	state.activated_shortcuts.append("ancient_gate")
	state.guardian_defeated = true
	state.play_time_ms = 9123
	var restored = RunStateScript.from_json(state.to_json())
	_expect(restored != null, "Run state round trip returned null.")
	if restored == null:
		return
	_expect(restored.embers == 321, "Run state did not preserve embers.")
	_expect(is_equal_approx(restored.focus, 37.0), "Run state did not preserve focus.")
	_expect(restored.combat_style == 3, "Run state did not preserve combat style.")
	_expect(restored.lost_echo_position == Vector3(1.0, 2.0, 3.0), "Run state lost echo position changed.")
	_expect(
		restored.activated_shortcuts.size() == 1
		and restored.activated_shortcuts[0] == "ancient_gate",
		"Run state did not preserve shortcuts."
	)
	_expect(restored.guardian_defeated, "Run state did not preserve guardian state.")


func _test_run_state_rejects_invalid_data() -> void:
	_expect(RunStateScript.from_json("{}") == null, "Incomplete save JSON was accepted.")
	_expect(
		RunStateScript.from_dictionary({"schema_version": 99, "checkpoint_id": "x"}) == null,
		"Unsupported save schema was accepted."
	)
	_expect(
		RunStateScript.from_dictionary({"schema_version": 1, "checkpoint_id": ""}) == null,
		"Save with an empty checkpoint was accepted."
	)


func _test_settings_sanitize_values() -> void:
	var settings = SettingsScript.from_dictionary({
		"schema_version": 1,
		"locale": "",
		"ui_scale": 9.0,
		"text_scale": 0.1,
		"control_opacity": -4.0,
		"camera_sensitivity": 99.0,
		"quality_preset": "impossible",
		"target_fps": 41,
	})
	_expect(settings != null, "Valid settings payload was rejected.")
	if settings == null:
		return
	_expect(is_equal_approx(settings.ui_scale, 2.0), "UI scale was not clamped.")
	_expect(is_equal_approx(settings.text_scale, 0.85), "Text scale was not clamped.")
	_expect(settings.locale == "en", "Empty locale did not fall back to English.")
	_expect(settings.quality_preset == &"medium", "Unknown quality preset was accepted.")
	_expect(settings.target_fps == 60, "Target FPS was not normalized.")


func _test_bridge_contract() -> void:
	var bridge = BridgeScript.new()
	var received := {
		"settings": false,
		"continue": false,
		"initialize": false,
	}
	bridge.settings_received.connect(func(_settings: Dictionary): received["settings"] = true)
	bridge.continue_run_requested.connect(func(_save: Dictionary): received["continue"] = true)
	bridge.initialize_received.connect(
		func(_settings: Dictionary, _save: Dictionary): received["initialize"] = true
	)
	_expect(bridge.handle_message(JSON.stringify({
		"protocolVersion": 1,
		"type": "settings.apply",
		"requestId": "flutter-1",
		"payload": {"settings": {"uiScale": 1.25}},
	})), "Settings bridge message was rejected.")
	_expect(bool(received["settings"]), "Settings bridge signal was not emitted.")
	_expect(bridge.handle_message(JSON.stringify({
		"protocolVersion": 1,
		"type": "host.initialize",
		"requestId": "flutter-2",
		"payload": {
			"settings": {"schemaVersion": 1},
			"save": {"schemaVersion": 1, "checkpointId": "ember_shrine"},
		},
	})), "Initialize bridge message was rejected.")
	_expect(bool(received["initialize"]), "Initialize bridge signal was not emitted.")
	_expect(bridge.handle_message(JSON.stringify({
		"protocolVersion": 1,
		"type": "run.continue",
		"requestId": "flutter-3",
		"payload": {"save": {"schema_version": 1}},
	})), "Continue bridge message was rejected.")
	_expect(bool(received["continue"]), "Continue bridge signal was not emitted.")
	_expect(not bridge.handle_message(JSON.stringify({
		"protocolVersion": 2,
		"type": "settings.apply",
		"requestId": "flutter-4",
		"payload": {},
	})), "Unsupported bridge protocol was accepted.")
	bridge.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
