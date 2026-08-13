# game/tests/smoke/samsara_communion_contract.gd
extends SceneTree
## 5-3/5-4 剧情合约：samsara 回放旗 + 九铸魂者证词 + 尾声消费悔

const RunStateScript = preload("res://scripts/core/run_state.gd")
const DialogueRunnerScript = preload("res://scripts/story/dialogue_runner.gd")
const EndingResolverScript = preload("res://scripts/story/ending_resolver.gd")
const FateCatalog = preload("res://scripts/combat/data/boss_fate_catalog.gd")


func _init() -> void:
	var failed := 0
	failed += _test_samsara_catalog()
	failed += _test_soul_forgers()
	failed += _test_samsara_epilogue()
	if failed == 0:
		print("ASHEN_SAMSARA_COMMUNION_CONTRACTS_OK")
		quit(0)
	else:
		print("ASHEN_SAMSARA_COMMUNION_CONTRACTS_FAIL count=%d" % failed)
		quit(1)


func _expect(cond: bool, msg: String) -> int:
	if cond:
		return 0
	print("FAIL: %s" % msg)
	return 1


## 四章回放旗都有 accept/regret 双选项
func _test_samsara_catalog() -> int:
	var failed := 0
	for ch in ["ch1", "ch2", "ch3", "ch4"]:
		var flag := StringName("samsara_stance_%s" % ch)
		var entry := FateCatalog.entry_for_flag(flag)
		failed += _expect(not entry.is_empty(), "samsara_%s entry exists" % ch)
		if entry.is_empty():
			continue
		var options: Array = entry.get("options", [])
		failed += _expect(options.size() == 2, "samsara_%s has 2 options" % ch)
		failed += _expect(FateCatalog.is_valid_choice(flag, "accept"), "samsara_%s accept valid" % ch)
		failed += _expect(FateCatalog.is_valid_choice(flag, "regret"), "samsara_%s regret valid" % ch)
	return failed


## 九铸魂者证词：非空 + 依命运旗追加
func _test_soul_forgers() -> int:
	var failed := 0
	var run := RunStateScript.new()
	var lines := DialogueRunnerScript.resolve_lines(&"npc_soul_forgers", run)
	failed += _expect(lines.size() >= 2, "soul forgers base lines")
	run.set_choice_flag("fate_remnant_trust", true)
	var lines2 := DialogueRunnerScript.resolve_lines(&"npc_soul_forgers", run)
	failed += _expect("\n".join(lines2).contains("巨阙"), "soul forgers reflect fate_remnant_trust")
	return failed


## 尾声消费悔（samsara_stance_ch1 == regret → 悔行）
func _test_samsara_epilogue() -> int:
	var failed := 0
	var run := RunStateScript.new()
	run.set_choice_flag("samsara_stance_ch1", "regret")
	var data := DialogueRunnerScript.ending_epilogue(EndingResolverScript.ENDING_KINDLE, run)
	var witnesses: PackedStringArray = data.get("witnesses", PackedStringArray())
	failed += _expect(" ".join(witnesses).contains("悔于巨阙"), "epilogue reflects samsara regret")
	return failed
