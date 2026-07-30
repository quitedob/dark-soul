extends SceneTree

const RunStateScript = preload("res://scripts/core/run_state.gd")
const SettingsScript = preload("res://scripts/core/game_settings.gd")
const BridgeScript = preload("res://scripts/app/game_host_bridge.gd")

var _failures: Array[String] = []


func _init() -> void:
	_test_run_state_v1_migration()
	_test_run_state_v2_round_trip()
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


func _test_run_state_v1_migration() -> void:
	var restored = RunStateScript.from_dictionary({
		"schemaVersion": 1,
		"checkpointId": "ember_shrine",
		"combatStyle": 2,
		"activatedShortcuts": ["ancient_gate"],
		"guardianDefeated": true,
		"upgradeTier": 3,
	})
	_expect(restored != null, "Schema v1 save did not migrate.")
	if restored == null:
		return
	_expect(restored.chapter_id == "chapter_01", "V1 chapter migration default changed.")
	_expect(restored.level_id == "level_01_01", "V1 level migration default changed.")
	_expect(restored.location == "ember_shrine", "V1 checkpoint did not migrate to location.")
	_expect(restored.right_hand == "marksman_bow", "V1 style did not derive right hand.")
	_expect(restored.left_hand == "marksman_dagger", "V1 style did not derive left hand.")
	var expected_hands := [
		["guardian_sword", "reliquary_shield"],
		["xingtian_axe_right", "xingtian_axe_left"],
		["marksman_bow", "marksman_dagger"],
		["five_elements_seal", "spirit_stone"],
		["prayer_beads", "talisman_papers"],
	]
	for style in range(expected_hands.size()):
		var style_state = RunStateScript.from_dictionary({
			"schema_version": 1,
			"checkpoint_id": "ember_shrine",
			"combat_style": style,
		})
		_expect(style_state.right_hand == expected_hands[style][0], "V1 right hand mapping changed.")
		_expect(style_state.left_hand == expected_hands[style][1], "V1 left hand mapping changed.")
	_expect("boss_giant_gate" in restored.defeated_bosses, "Guardian did not migrate to the content boss ID.")
	_expect("ember_shrine:ancient_gate" in restored.activated_shortcuts, "Shortcut was not scoped.")
	_expect("ancient_gate" in restored.activated_shortcuts, "Legacy shortcut compatibility was lost.")
	_expect(restored.upgrade_tier == 3, "V1 upgrade tier did not migrate.")
	_expect(restored.to_dictionary()["schema_version"] == 2, "Migrated save did not write v2.")


func _test_run_state_v2_round_trip() -> void:
	var state = RunStateScript.new()
	state.checkpoint_id = "ash_courtyard"
	state.embers = 321
	state.focus = 37.0
	state.combat_style = 3
	state.lost_echo_amount = 44
	state.lost_echo_position = Vector3(1.0, 2.0, 3.0)
	state.activated_shortcuts.append("ancient_gate")
	state.guardian_defeated = true
	state.upgrade_tier = 4
	state.play_time_ms = 9123
	state.chapter_id = "chapter_02"
	state.level_id = "level_02_03"
	state.location = "ash_courtyard:north"
	state.right_hand = "custom_staff"
	state.left_hand = "ward_charm"
	state.inventory = {"ember_flask": 2}
	state.completed_levels.append("level_1")
	state.defeated_bosses.append("taotie")
	state.activated_checkpoints.append("ash_courtyard")
	state.completed_puzzles.append("bell_order")
	state.collected_loot.append("first_ember_fragment")
	state.choice_flags = {"freed_spirit_smith": true}
	state.progression_values = {"legacyCombatStyle": 3}
	var restored = RunStateScript.from_json(state.to_json())
	_expect(restored != null, "Run state round trip returned null.")
	if restored == null:
		return
	_expect(restored.embers == 321, "Run state did not preserve embers.")
	_expect(is_equal_approx(restored.focus, 37.0), "Run state did not preserve focus.")
	_expect(restored.combat_style == 3, "Run state did not preserve combat style.")
	_expect(restored.lost_echo_position == Vector3(1.0, 2.0, 3.0), "Run state lost echo position changed.")
	_expect("ancient_gate" in restored.activated_shortcuts, "Legacy shortcut compatibility was lost.")
	_expect("ember_shrine:ancient_gate" in restored.activated_shortcuts, "Scoped shortcut was not saved.")
	_expect(restored.guardian_defeated, "Run state did not preserve guardian state.")
	_expect(restored.upgrade_tier == 4, "Run state did not preserve upgrade tier.")
	_expect(restored.right_hand == "custom_staff", "Run state did not preserve right hand.")
	_expect(restored.left_hand == "ward_charm", "Run state did not preserve left hand.")
	_expect(restored.inventory.get("ember_flask", 0) == 2, "Run state did not preserve inventory.")
	_expect("level_1" in restored.completed_levels, "Completed levels were not preserved.")
	_expect("taotie" in restored.defeated_bosses, "Defeated bosses were not preserved.")
	_expect("ash_courtyard" in restored.activated_checkpoints, "Activated checkpoints were not preserved.")
	_expect("bell_order" in restored.completed_puzzles, "Completed puzzles were not preserved.")
	_expect("first_ember_fragment" in restored.collected_loot, "Collected loot was not preserved.")
	_expect(bool(restored.choice_flags["freed_spirit_smith"]), "Choice flags were not preserved.")
	var bridge: Dictionary = restored.to_bridge_dictionary()
	_expect(bridge["schemaVersion"] == 2, "Bridge save did not write schema v2.")
	_expect(bridge["player"]["upgradeTier"] == 4, "Bridge save omitted upgrade tier.")
	_expect(bridge["player"]["rightHand"] == "custom_staff", "Bridge save omitted right hand.")
	_expect(bridge["progression"]["completedLevelIds"] == ["level_1"], "Bridge save omitted world progression.")
	_expect(bridge["progression"]["choiceFlags"] == {"freed_spirit_smith": true}, "Bridge save omitted choice flags.")
	_expect(bridge["lostEcho"]["levelId"] == "level_02_03", "Bridge save omitted lost-echo level.")
	var bridge_restored = RunStateScript.from_dictionary(bridge)
	_expect(bridge_restored != null, "Nested bridge v2 did not parse.")
	if bridge_restored != null:
		_expect(bridge_restored.chapter_id == "chapter_02", "Nested bridge chapter changed.")
		_expect(bridge_restored.level_id == "level_02_03", "Nested bridge level changed.")
		_expect(bridge_restored.right_hand == "custom_staff", "Nested bridge right hand changed.")
		_expect(int(bridge_restored.progression_values.get("legacyCombatStyle", -1)) == 3, "Nested bridge values changed.")


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
	_expect(
		RunStateScript.from_dictionary({
			"schema_version": 2,
			"checkpoint_id": "x",
			"location": "x",
			"right_hand": "blade",
			"left_hand": "",
			"inventory": {},
			"completed_levels": [7],
			"defeated_bosses": [],
			"activated_checkpoints": [],
			"completed_puzzles": [],
			"collected_loot": [],
			"choice_flags": {},
		}) == null,
		"Malformed v2 progression was accepted."
	)


func _test_settings_sanitize_values() -> void:
	var settings = SettingsScript.from_dictionary({
		"schema_version": 1,
		"locale": "",
		"ui_scale": 9.0,
		"text_scale": 0.1,
		"control_opacity": -4.0,
		"camera_sensitivity": 99.0,
		"screen_shake_enabled": false,
		"screen_shake_intensity": 9.0,
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
	_expect(not settings.screen_shake_enabled, "Screen-shake toggle was not restored.")
	_expect(is_equal_approx(settings.screen_shake_intensity, 2.0), "Screen-shake intensity was not clamped.")
	_expect(settings.target_fps == 60, "Target FPS was not normalized.")
	_expect(settings.combat_tip_mode == false, "Combat tip mode must default off when omitted.")
	var tip_on = SettingsScript.from_dictionary({
		"schema_version": 1,
		"locale": "en",
		"combat_tip_mode": true,
	})
	_expect(tip_on != null and tip_on.combat_tip_mode, "combat_tip_mode true was not restored.")


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
