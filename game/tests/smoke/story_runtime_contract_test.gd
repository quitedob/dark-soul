# game/tests/smoke/story_runtime_contract_test.gd
extends SceneTree
## Phase3：Quest / Dialogue / Ending 最小竖切合约

const RunStateScript = preload("res://scripts/core/run_state.gd")
const QuestStateScript = preload("res://scripts/story/quest_state.gd")
const DialogueRunnerScript = preload("res://scripts/story/dialogue_runner.gd")
const EndingResolverScript = preload("res://scripts/story/ending_resolver.gd")


func _init() -> void:
	var failed := 0
	failed += _test_quest_and_dialogue()
	failed += _test_ending_matrix()
	if failed == 0:
		print("ASHEN_STORY_RUNTIME_CONTRACTS_OK")
		quit(0)
	else:
		print("ASHEN_STORY_RUNTIME_CONTRACTS_FAIL count=%d" % failed)
		quit(1)


func _expect(cond: bool, msg: String) -> int:
	if cond:
		return 0
	print("FAIL: %s" % msg)
	return 1


func _test_quest_and_dialogue() -> int:
	var failed := 0
	var run := RunStateScript.new()
	var lines := DialogueRunnerScript.resolve_lines(&"npc_cloud_wanderer", run)
	failed += _expect(lines.size() >= 1, "first meeting lines")
	DialogueRunnerScript.apply_aftermath(&"npc_cloud_wanderer", run)
	failed += _expect(bool(run.get_choice_flag("npc_cloud_wanderer_met", false)), "met flag")
	failed += _expect(
		QuestStateScript.get_stage(run, QuestStateScript.QUEST_CLOUD_WANDERER) == QuestStateScript.STAGE_ACTIVE,
		"quest active"
	)
	run.guardian_defeated = true
	DialogueRunnerScript.apply_aftermath(&"npc_cloud_wanderer", run)
	failed += _expect(QuestStateScript.is_complete(run, QuestStateScript.QUEST_CLOUD_WANDERER), "quest complete")
	return failed


func _test_ending_matrix() -> int:
	var failed := 0
	var run := RunStateScript.new()
	failed += _expect(EndingResolverScript.resolve(run, &"kindle") == EndingResolverScript.ENDING_KINDLE, "kindle")
	failed += _expect(EndingResolverScript.resolve(run, &"keeper") == EndingResolverScript.ENDING_KEEPER, "keeper")
	failed += _expect(EndingResolverScript.resolve(run, &"void") == EndingResolverScript.ENDING_VOID, "void")
	var reachable := EndingResolverScript.reachable(run)
	failed += _expect(reachable.size() == 3, "base three endings")
	# 隐藏结局证物齐备
	QuestStateScript.set_stage(run, &"quest_soul_return", QuestStateScript.STAGE_COMPLETE)
	QuestStateScript.set_stage(run, &"quest_forge_last_question", QuestStateScript.STAGE_COMPLETE)
	QuestStateScript.set_stage(run, &"quest_furnace_whisper", QuestStateScript.STAGE_COMPLETE)
	for i in range(1, 5):
		run.set_choice_flag("furnace_memory_%d" % i, true)
	run.set_choice_flag("ending_prefer_forge", true)
	failed += _expect(EndingResolverScript.resolve(run, &"") == EndingResolverScript.ENDING_FORGE, "forge hidden")
	failed += _expect(EndingResolverScript.reachable(run).size() == 4, "four reachable")
	EndingResolverScript.commit(run, EndingResolverScript.ENDING_KEEPER)
	failed += _expect(String(run.get_choice_flag("ending_state", "")) == "keeper", "commit ending_state")
	return failed
