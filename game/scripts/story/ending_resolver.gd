# game/scripts/story/ending_resolver.gd
class_name EndingResolver
extends RefCounted
## 只读结局解析：依据 choice_flags / 任务完成度返回结局 id

const QuestStateScript = preload("res://scripts/story/quest_state.gd")

const ENDING_KINDLE := &"kindle" ## 薪火相传
const ENDING_KEEPER := &"keeper" ## 守炉人
const ENDING_VOID := &"void" ## 大寂灭
const ENDING_FORGE := &"forge" ## 共铸新炉（隐藏）
const ENDING_NONE := &""


## 解析当前可达结局；throne_choice 为玩家在烬座的最终动作
static func resolve(run_state, throne_choice: StringName = &"") -> StringName:
	if run_state == null:
		return ENDING_NONE
	# 隐藏结局：三任务 + 四段炉忆旗标
	if _hidden_forge_ready(run_state) and (throne_choice == &"forge" or throne_choice == &""):
		if throne_choice == &"forge" or bool(run_state.get_choice_flag("ending_prefer_forge", false)):
			return ENDING_FORGE
	match String(throne_choice):
		"kindle", "absorb":
			return ENDING_KINDLE
		"keeper", "sit":
			return ENDING_KEEPER
		"void", "shatter":
			return ENDING_VOID
	# 无显式选择时读已写入的 ending_state
	var stored := String(run_state.get_choice_flag("ending_state", ""))
	if stored in ["kindle", "keeper", "void", "forge"]:
		return StringName(stored)
	return ENDING_NONE


## 列出当前理论上可达的结局（供 UI / 合约）
static func reachable(run_state) -> Array[StringName]:
	var out: Array[StringName] = [ENDING_KINDLE, ENDING_KEEPER, ENDING_VOID]
	if _hidden_forge_ready(run_state):
		out.append(ENDING_FORGE)
	return out


## 隐藏结局证物链是否齐备
static func _hidden_forge_ready(run_state) -> bool:
	if run_state == null:
		return false
	var quests_ok := (
		QuestStateScript.is_complete(run_state, &"quest_soul_return")
		and QuestStateScript.is_complete(run_state, &"quest_forge_last_question")
		and QuestStateScript.is_complete(run_state, &"quest_furnace_whisper")
	)
	var memories := 0
	for key in ["furnace_memory_1", "furnace_memory_2", "furnace_memory_3", "furnace_memory_4"]:
		if bool(run_state.get_choice_flag(key, false)):
			memories += 1
	return quests_ok and memories >= 4


## 写入结局旗（供烬座交互调用）
static func commit(run_state, ending_id: StringName) -> void:
	if run_state == null or ending_id == ENDING_NONE:
		return
	run_state.set_choice_flag("ending_state", String(ending_id))
