extends SceneTree

const RunStateScript = preload("res://scripts/core/run_state.gd")
const SettingsScript = preload("res://scripts/core/game_settings.gd")
const BridgeScript = preload("res://scripts/app/game_host_bridge.gd")

# I-09：磁盘往返使用独立 user:// 临时目录，避免污染正式存档路径
const DISK_FIXTURE_ROOT := "user://i09_save_persistence_contract"
const DISK_RUN_PATH := "user://i09_save_persistence_contract/run_v2_round_trip.json"
const DISK_SETTINGS_PATH := "user://i09_save_persistence_contract/settings_v1_round_trip.json"

var _failures: Array[String] = []


func _init() -> void:
	_test_run_state_v1_migration()
	_test_run_state_v2_round_trip()
	_test_run_state_disk_persistence_round_trip()
	_test_settings_disk_persistence_round_trip()
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


# I-09：user:// 磁盘写读往返，断言字段后清理临时文件
func _test_run_state_disk_persistence_round_trip() -> void:
	_cleanup_disk_fixture()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DISK_FIXTURE_ROOT))
	var state = RunStateScript.new()
	state.checkpoint_id = "ash_courtyard"
	state.embers = 654
	state.focus = 41.5
	state.combat_style = 2
	state.lost_echo_amount = 88
	state.lost_echo_position = Vector3(4.0, 5.0, 6.0)
	state.activated_shortcuts.append("ancient_gate")
	state.guardian_defeated = true
	state.upgrade_tier = 2
	state.play_time_ms = 445566
	state.chapter_id = "chapter_03"
	state.level_id = "level_03_01"
	state.location = "jade_gate:south"
	state.right_hand = "disk_bow"
	state.left_hand = "disk_dagger"
	state.inventory = {"ember_flask": 3, "soul_shard": 1}
	state.completed_levels.append("level_02_03")
	state.defeated_bosses.append("boss_giant_gate")
	state.activated_checkpoints.append("ash_courtyard")
	state.completed_puzzles.append("mirror_seal")
	state.collected_loot.append("jade_key")
	state.choice_flags = {"spared_warden": true}
	state.progression_values = {"legacyCombatStyle": 2}
	_expect(state.save_to_path(DISK_RUN_PATH), "Run state failed to write user:// path.")
	_expect(FileAccess.file_exists(DISK_RUN_PATH), "Run state file missing after save_to_path.")
	var restored = RunStateScript.load_from_path(DISK_RUN_PATH)
	_expect(restored != null, "Disk load_from_path returned null.")
	if restored == null:
		_cleanup_disk_fixture()
		return
	_expect(restored.checkpoint_id == "ash_courtyard", "Disk round-trip lost checkpoint_id.")
	_expect(restored.embers == 654, "Disk round-trip lost embers.")
	_expect(is_equal_approx(restored.focus, 41.5), "Disk round-trip lost focus.")
	_expect(restored.combat_style == 2, "Disk round-trip lost combat_style.")
	_expect(restored.lost_echo_amount == 88, "Disk round-trip lost lost_echo_amount.")
	_expect(restored.lost_echo_position == Vector3(4.0, 5.0, 6.0), "Disk round-trip lost lost_echo_position.")
	_expect("ancient_gate" in restored.activated_shortcuts, "Disk round-trip lost legacy shortcut.")
	_expect("ember_shrine:ancient_gate" in restored.activated_shortcuts, "Disk round-trip lost scoped shortcut.")
	_expect(restored.guardian_defeated, "Disk round-trip lost guardian_defeated.")
	_expect(restored.upgrade_tier == 2, "Disk round-trip lost upgrade_tier.")
	_expect(restored.play_time_ms == 445566, "Disk round-trip lost play_time_ms.")
	_expect(restored.chapter_id == "chapter_03", "Disk round-trip lost chapter_id.")
	_expect(restored.level_id == "level_03_01", "Disk round-trip lost level_id.")
	_expect(restored.location == "jade_gate:south", "Disk round-trip lost location.")
	_expect(restored.right_hand == "disk_bow", "Disk round-trip lost right_hand.")
	_expect(restored.left_hand == "disk_dagger", "Disk round-trip lost left_hand.")
	_expect(int(restored.inventory.get("ember_flask", 0)) == 3, "Disk round-trip lost inventory.")
	_expect("level_02_03" in restored.completed_levels, "Disk round-trip lost completed_levels.")
	_expect("boss_giant_gate" in restored.defeated_bosses, "Disk round-trip lost defeated_bosses.")
	_expect("ash_courtyard" in restored.activated_checkpoints, "Disk round-trip lost activated_checkpoints.")
	_expect("mirror_seal" in restored.completed_puzzles, "Disk round-trip lost completed_puzzles.")
	_expect("jade_key" in restored.collected_loot, "Disk round-trip lost collected_loot.")
	_expect(bool(restored.choice_flags.get("spared_warden", false)), "Disk round-trip lost choice_flags.")
	_expect(int(restored.progression_values.get("legacyCombatStyle", -1)) == 2, "Disk round-trip lost progression_values.")
	_expect(restored.to_dictionary()["schema_version"] == 2, "Disk round-trip did not persist schema v2.")
	_cleanup_disk_fixture()
	_expect(not FileAccess.file_exists(DISK_RUN_PATH), "Disk fixture run file was not cleaned up.")


# I-09：settings 同步覆盖 user:// 写读清理路径
func _test_settings_disk_persistence_round_trip() -> void:
	_cleanup_disk_fixture()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DISK_FIXTURE_ROOT))
	var settings = SettingsScript.new()
	settings.locale = "zh_CN"
	settings.master_volume = 0.42
	settings.music_volume = 0.33
	settings.effects_volume = 0.55
	settings.target_fps = 30
	settings.combat_tip_mode = true
	settings.quality_preset = &"low"
	settings.ui_scale = 1.25
	_expect(settings.save_to_path(DISK_SETTINGS_PATH), "Settings failed to write user:// path.")
	_expect(FileAccess.file_exists(DISK_SETTINGS_PATH), "Settings file missing after save_to_path.")
	var restored = SettingsScript.load_from_path(DISK_SETTINGS_PATH)
	_expect(restored != null, "Settings disk load_from_path returned null.")
	if restored == null:
		_cleanup_disk_fixture()
		return
	_expect(restored.locale == "zh_CN", "Settings disk round-trip lost locale.")
	_expect(is_equal_approx(restored.master_volume, 0.42), "Settings disk round-trip lost master_volume.")
	_expect(is_equal_approx(restored.music_volume, 0.33), "Settings disk round-trip lost music_volume.")
	_expect(is_equal_approx(restored.effects_volume, 0.55), "Settings disk round-trip lost effects_volume.")
	_expect(restored.target_fps == 30, "Settings disk round-trip lost target_fps.")
	_expect(restored.combat_tip_mode, "Settings disk round-trip lost combat_tip_mode.")
	_expect(restored.quality_preset == &"low", "Settings disk round-trip lost quality_preset.")
	_expect(is_equal_approx(restored.ui_scale, 1.25), "Settings disk round-trip lost ui_scale.")
	_cleanup_disk_fixture()
	_expect(not FileAccess.file_exists(DISK_SETTINGS_PATH), "Disk fixture settings file was not cleaned up.")


func _cleanup_disk_fixture() -> void:
	_remove_tree(DISK_FIXTURE_ROOT)


func _remove_tree(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		var child := path.path_join(entry)
		if directory.current_is_dir():
			_remove_tree(child)
		else:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(child))
		entry = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


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
