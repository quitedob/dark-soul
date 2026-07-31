# game/scripts/story/quest_state.gd
class_name QuestState
extends RefCounted
## 支线任务阶段机：状态存在 AshenRunState.choice_flags / progression_values

const STAGE_INACTIVE := &"inactive"
const STAGE_ACTIVE := &"active"
const STAGE_COMPLETE := &"complete"
const STAGE_FAILED := &"failed"

## 内置竖切任务：云游道人指引
const QUEST_CLOUD_WANDERER := &"quest_cloud_wanderer"
## 支线·桥头的供茶：桥头供茶（烬茶倌之约）
const QUEST_BRIDGE_TEA := &"quest_bridge_tea"


## 任务阶段键名
static func stage_key(quest_id: StringName) -> String:
	return "quest_stage_%s" % String(quest_id)


## 读取任务阶段（默认 inactive）
static func get_stage(run_state, quest_id: StringName) -> StringName:
	if run_state == null:
		return STAGE_INACTIVE
	var raw: Variant = run_state.get_choice_flag(stage_key(quest_id), String(STAGE_INACTIVE))
	return StringName(String(raw))


## 设置任务阶段并回写 run_state
static func set_stage(run_state, quest_id: StringName, stage: StringName) -> void:
	if run_state == null:
		return
	run_state.set_choice_flag(stage_key(quest_id), String(stage))


## 启动任务（仅 inactive→active）
static func start(run_state, quest_id: StringName) -> bool:
	if get_stage(run_state, quest_id) != STAGE_INACTIVE:
		return false
	set_stage(run_state, quest_id, STAGE_ACTIVE)
	return true


## 完成任务
static func complete(run_state, quest_id: StringName) -> bool:
	if get_stage(run_state, quest_id) != STAGE_ACTIVE:
		return false
	set_stage(run_state, quest_id, STAGE_COMPLETE)
	return true


## 是否已完成
static func is_complete(run_state, quest_id: StringName) -> bool:
	return get_stage(run_state, quest_id) == STAGE_COMPLETE
