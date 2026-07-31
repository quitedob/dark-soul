extends SceneTree
## 第三章–第五章接线合约（L-02/L-03/L-04/L-06）：
## 内容表 / 关卡链 / Boss 相位 / 命运旗标 / 三真相任务 / 炉忆证物 / 召唤物配置

const ContentRegistryScript = preload("res://scripts/core/content_registry.gd")
const Chapter3Content = preload("res://scripts/data/chapter_3_content.gd")
const Chapter4Content = preload("res://scripts/data/chapter_4_content.gd")
const Chapter5Content = preload("res://scripts/data/chapter_5_content.gd")
const EnemyScript = preload("res://scripts/enemy.gd")
const FateCatalog = preload("res://scripts/combat/data/boss_fate_catalog.gd")
const RunStateScript = preload("res://scripts/core/run_state.gd")
const QuestStateScript = preload("res://scripts/story/quest_state.gd")
const EndingResolverScript = preload("res://scripts/story/ending_resolver.gd")
const PlayerCombatData = preload("res://scripts/data/player_combat_data.gd")
const SpiritSummon = preload("res://scripts/combat/spirit_summon.gd")

var _failures: Array[String] = []


func _init() -> void:
	_test_content_tables()
	_test_registry_chain()
	_test_boss_phase_parse()
	_test_fate_catalog()
	_test_hidden_ending_chain()
	_test_summon_config()
	if _failures.is_empty():
		print("ASHEN_CHAPTER3_5_WIRING_CONTRACTS_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_content_tables() -> void:
	var ch3 := Chapter3Content.enemies()
	_expect(ch3.size() >= 9, "Ch.3 enemy roster < 9.")
	var ch3_elites := Chapter3Content.elites()
	_expect(ch3_elites.size() >= 3, "Ch.3 elites < 3.")
	var ch4 := Chapter4Content.enemies()
	_expect(ch4.size() >= 7, "Ch.4 enemy roster < 7.")
	var ch5 := Chapter5Content.enemies()
	_expect(ch5.size() >= 6, "Ch.5 enemy roster < 6.")
	var ch5_elites := Chapter5Content.elites()
	_expect(ch5_elites.size() >= 3, "Ch.5 elites < 3.")

	# Ch.4 为复数 bosses()，其余章节单数 boss()
	var ch4_bosses := Chapter4Content.bosses()
	_expect(ch4_bosses.size() == 3, "Ch.4 should expose 3 sub/main bosses.")
	var ids: Array[String] = []
	for boss in ch4_bosses:
		ids.append(String(boss.get("id", "")))
	_expect("boss_xuan_xiao_wrath" in ids, "Ch.4 missing wrath fragment.")
	_expect("boss_xuan_xiao_obsession" in ids, "Ch.4 missing obsession fragment.")
	_expect("boss_xuan_xiao" in ids, "Ch.4 missing main Xuan Xiao.")

	var ch3_boss := Chapter3Content.boss()
	_expect(String(ch3_boss.get("id", "")) == "boss_nine_tails", "Ch.3 boss id mismatch.")
	var ch5_boss := Chapter5Content.boss()
	_expect(String(ch5_boss.get("id", "")) == "boss_zhu_yin", "Ch.5 boss id mismatch.")
	_expect(ch5_boss.has("phases") and ch5_boss["phases"].size() == 4, "Zhu Yin should have 4 phases.")


func _test_registry_chain() -> void:
	var registry = ContentRegistryScript.new()
	var chain := [
		[&"level_03_01", &"level_03_02"],
		[&"level_03_05", &"level_03_06"],
		[&"level_03_06", &"level_04_01"],
		[&"level_04_03", &"level_04_04"],
		[&"level_04_04", &"level_04_05"],
		[&"level_04_05", &"level_04_06"],
		[&"level_04_06", &"level_05_01"],
		[&"level_05_04", &"level_05_05"],
	]
	for entry in chain:
		var level := registry.get_level(entry[0])
		_expect(not level.is_empty(), "%s missing from registry." % entry[0])
		var next := registry.get_next_level(entry[0])
		_expect(String(next.get("id", "")) == String(entry[1]), "%s next must be %s." % [entry[0], entry[1]])
	# 每关 Boss 注册
	var boss_by_level := {
		"level_03_06": "boss_nine_tails",
		"level_04_04": "boss_xuan_xiao_wrath",
		"level_04_05": "boss_xuan_xiao_obsession",
		"level_04_06": "boss_xuan_xiao",
		"level_05_05": "boss_zhu_yin",
	}
	for level_id in boss_by_level:
		var boss := registry.get_boss_for_level(StringName(level_id))
		_expect(String(boss.get("id", "")) == boss_by_level[level_id], "%s boss mismatch." % level_id)


func _test_boss_phase_parse() -> void:
	var cases := [
		[Chapter3Content.boss(), 0.7, 0.3, 3],
		[Chapter4Content.bosses()[2], 0.6, 0.3, 3],
		[Chapter5Content.boss(), 0.7, 0.4, 4],
	]
	for case_data in cases:
		var enemy = EnemyScript.new()
		enemy._parse_boss_phases(case_data[0])
		_expect(is_equal_approx(enemy._content_phase_two_threshold, case_data[1]), "Phase-2 threshold mismatch.")
		_expect(is_equal_approx(enemy._content_phase_three_threshold, case_data[2]), "Phase-3 threshold mismatch.")
		_expect(enemy._content_phase_attacks.size() >= case_data[3], "Phase attack table size mismatch.")
		enemy.free()


func _test_fate_catalog() -> void:
	var entries := FateCatalog.all_entries()
	for flag in [&"ch1_guardian_fate", &"ch2_xingtian_fate", &"ch3_nine_tails_fate", &"ch4_xuanxiao_fate", &"ending_state"]:
		_expect(entries.has(flag), "Fate catalog missing flag %s." % flag)
		_expect(entries[flag].get("options", []).size() >= 2, "Fate catalog %s options < 2." % flag)
	_expect(FateCatalog.is_valid_choice(&"ch2_xingtian_fate", "absorbed"), "absorbed should be valid.")
	_expect(not FateCatalog.is_valid_choice(&"ch2_xingtian_fate", "bogus"), "bogus choice should be invalid.")


func _test_hidden_ending_chain() -> void:
	# 未齐备时 forge 不可达
	var run_state = RunStateScript.new()
	_expect(not EndingResolverScript.reachable(run_state).has(&"forge"), "Forge reachable without evidence.")
	# 齐备后：三任务 complete + 四段炉忆
	QuestStateScript.start(run_state, &"quest_soul_return")
	QuestStateScript.start(run_state, &"quest_forge_last_question")
	QuestStateScript.start(run_state, &"quest_furnace_whisper")
	QuestStateScript.complete(run_state, &"quest_soul_return")
	QuestStateScript.complete(run_state, &"quest_forge_last_question")
	QuestStateScript.complete(run_state, &"quest_furnace_whisper")
	for key in ["furnace_memory_1", "furnace_memory_2", "furnace_memory_3", "furnace_memory_4"]:
		run_state.set_choice_flag(StringName(key), true)
	_expect(EndingResolverScript.reachable(run_state).has(&"forge"), "Forge should be reachable with all evidence.")
	_expect(EndingResolverScript.resolve(run_state, &"forge") == &"forge", "resolve(forge) should return forge.")
	_expect(EndingResolverScript.resolve(run_state, &"kindle") == &"kindle", "resolve(kindle) should return kindle.")
	_expect(QuestStateScript.is_complete(run_state, &"quest_furnace_whisper"), "quest_furnace_whisper should complete.")


func _test_summon_config() -> void:
	var summons := PlayerCombatData.SUMMON_CONFIG
	_expect(summons.size() == 5, "SUMMON_CONFIG should have 5 spirits.")
	for key in ["summon_dharma_child", "summon_golden_guardian", "summon_rebirth_lotus", "summon_resentful_spirit", "summon_white_crane"]:
		_expect(summons.has(key), "Summon config missing %s." % key)
		_expect(String(summons[key].get("spell_type", "")) == "summon", "%s should be spell_type=summon." % key)
	_expect(SpiritSummon.KIND_DATA.size() == 5, "SpiritSummon KIND_DATA should have 5 kinds.")
	for kind in ["dharma_child", "golden_guardian", "rebirth_lotus", "resentful_spirit", "white_crane"]:
		_expect(SpiritSummon.KIND_DATA.has(kind), "SpiritSummon missing kind %s." % kind)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
