# game/tests/smoke/bridge_tea_quest_contract_test.gd
extends SceneTree
## 支线·桥头的供茶：Quest / Dialogue / Elite / Fate 最小竖切合约

const RunStateScript = preload("res://scripts/core/run_state.gd")
const QuestStateScript = preload("res://scripts/story/quest_state.gd")
const DialogueRunnerScript = preload("res://scripts/story/dialogue_runner.gd")
const Chapter3Content = preload("res://scripts/data/chapter_3_content.gd")
const FateCatalog = preload("res://scripts/combat/data/boss_fate_catalog.gd")


func _init() -> void:
	var failed := 0
	failed += _test_quest_and_dialogue()
	failed += _test_elite_entry()
	failed += _test_fate_catalog()
	if failed == 0:
		print("ASHEN_BRIDGE_TEA_QUEST_CONTRACTS_OK")
		quit(0)
	else:
		print("ASHEN_BRIDGE_TEA_QUEST_CONTRACTS_FAIL count=%d" % failed)
		quit(1)


func _expect(cond: bool, msg: String) -> int:
	if cond:
		return 0
	print("FAIL: %s" % msg)
	return 1


func _test_quest_and_dialogue() -> int:
	var failed := 0
	var run := RunStateScript.new()
	# 拾取供茶 → 开启 quest_bridge_tea
	var started := QuestStateScript.start(run, QuestStateScript.QUEST_BRIDGE_TEA)
	failed += _expect(started, "quest_bridge_tea start returns true")
	failed += _expect(
		QuestStateScript.get_stage(run, QuestStateScript.QUEST_BRIDGE_TEA) == QuestStateScript.STAGE_ACTIVE,
		"quest_bridge_tea active"
	)
	# 茶魂台词：初次结识非空；aftermath 置 met 旗标
	var lines := DialogueRunnerScript.resolve_lines(&"npc_bridge_tea_soul", run)
	failed += _expect(lines.size() >= 1, "bridge_tea_soul first meeting lines")
	DialogueRunnerScript.apply_aftermath(&"npc_bridge_tea_soul", run)
	failed += _expect(bool(run.get_choice_flag("npc_bridge_tea_soul_met", false)), "bridge_tea_soul met flag")
	# 完成支线
	var completed := QuestStateScript.complete(run, QuestStateScript.QUEST_BRIDGE_TEA)
	failed += _expect(completed, "quest_bridge_tea complete returns true")
	failed += _expect(QuestStateScript.is_complete(run, QuestStateScript.QUEST_BRIDGE_TEA), "quest_bridge_tea complete")
	return failed


func _test_elite_entry() -> int:
	var failed := 0
	var found := false
	for elite in Chapter3Content.elites():
		if String(elite.get("id", "")) == "elite_ember_greed_ghost":
			found = true
			failed += _expect(String(elite.get("appears_in", "")) == "level_03_04", "ember_greed_ghost appears_in level_03_04")
	failed += _expect(found, "elite_ember_greed_ghost present in elites()")
	return failed


func _test_fate_catalog() -> int:
	var failed := 0
	var entry := FateCatalog.entry_for_flag(&"bridge_tea_fate")
	failed += _expect(entry.get("options", []).size() == 2, "bridge_tea_fate has 2 options")
	failed += _expect(FateCatalog.is_valid_choice(&"bridge_tea_fate", "exposed"), "exposed valid")
	failed += _expect(FateCatalog.is_valid_choice(&"bridge_tea_fate", "mob"), "mob valid")
	failed += _expect(not FateCatalog.is_valid_choice(&"bridge_tea_fate", "bogus"), "bogus invalid")
	return failed
