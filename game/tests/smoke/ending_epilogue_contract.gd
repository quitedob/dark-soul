# game/tests/smoke/ending_epilogue_contract.gd
extends SceneTree
## 分结局尾声合约：结局读回 + 子 Boss 执行档案 + 尾声内容消费命运旗

const RunStateScript = preload("res://scripts/core/run_state.gd")
const DialogueRunnerScript = preload("res://scripts/story/dialogue_runner.gd")
const EndingResolverScript = preload("res://scripts/story/ending_resolver.gd")
const BossExecutionCatalog = preload("res://scripts/combat/data/boss_execution_catalog.gd")


func _init() -> void:
	var failed := 0
	failed += _test_ending_readback()
	failed += _test_sub_boss_profiles()
	failed += _test_epilogue_content()
	if failed == 0:
		print("ASHEN_ENDING_EPILOGUE_CONTRACTS_OK")
		quit(0)
	else:
		print("ASHEN_ENDING_EPILOGUE_CONTRACTS_FAIL count=%d" % failed)
		quit(1)


func _expect(cond: bool, msg: String) -> int:
	if cond:
		return 0
	print("FAIL: %s" % msg)
	return 1


## commit 后 resolve 从 ending_state 读回（运行时路径，此前只测试用）
func _test_ending_readback() -> int:
	var failed := 0
	var run := RunStateScript.new()
	EndingResolverScript.commit(run, EndingResolverScript.ENDING_FORGE)
	failed += _expect(EndingResolverScript.resolve(run) == EndingResolverScript.ENDING_FORGE, "forge readback")
	EndingResolverScript.commit(run, EndingResolverScript.ENDING_VOID)
	failed += _expect(EndingResolverScript.resolve(run) == EndingResolverScript.ENDING_VOID, "void readback")
	return failed


## 嗔念/执念不再回退巨阙档案（杜绝 ch1_guardian_fate 泄漏）
func _test_sub_boss_profiles() -> int:
	var failed := 0
	var wrath = BossExecutionCatalog.profile_for_boss_id("boss_xuan_xiao_wrath")
	failed += _expect(wrath != null, "wrath profile exists")
	if wrath != null:
		failed += _expect(String(wrath.story_flag) == "", "wrath has no story flag (no ch1 leak)")
		failed += _expect(wrath.allow_lethal_on_execution == true, "wrath lethal execution")
	var obsession = BossExecutionCatalog.profile_for_boss_id("boss_xuan_xiao_obsession")
	failed += _expect(obsession != null, "obsession profile exists")
	if obsession != null:
		failed += _expect(String(obsession.story_flag) == "", "obsession has no story flag")
		failed += _expect(obsession.allow_lethal_on_execution == true, "obsession lethal execution")
	return failed


## 尾声内容：分结局标题/段落非空；命运旗与 NPC met 旗消费进 witnesses；未知结局返回空
func _test_epilogue_content() -> int:
	var failed := 0
	var run := RunStateScript.new()
	var data := DialogueRunnerScript.ending_epilogue(EndingResolverScript.ENDING_KINDLE, run)
	failed += _expect(String(data.get("title", "")) != "", "kindle has title")
	var paragraphs: PackedStringArray = data.get("paragraphs", PackedStringArray())
	failed += _expect(paragraphs.size() >= 2, "kindle has paragraphs")
	run.set_choice_flag("fate_remnant_trust", true)
	run.set_choice_flag("npc_silence_bringer_met", true)
	var data2 := DialogueRunnerScript.ending_epilogue(EndingResolverScript.ENDING_KEEPER, run)
	var witnesses: PackedStringArray = data2.get("witnesses", PackedStringArray())
	failed += _expect(witnesses.size() >= 2, "witnesses populated from fate + npc met flags")
	var joined := " ".join(witnesses)
	failed += _expect(joined.contains("残影"), "fate_remnant_trust consumed into witnesses")
	failed += _expect(joined.contains("寂灭"), "npc_silence_bringer_met witness present")
	var empty := DialogueRunnerScript.ending_epilogue(&"", run)
	failed += _expect(String(empty.get("title", "")) == "", "unknown ending returns empty")
	return failed
