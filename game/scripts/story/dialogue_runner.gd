# game/scripts/story/dialogue_runner.gd
class_name DialogueRunner
extends RefCounted
## 条件对白解析：按 choice_flags / 任务阶段过滤台词行

const QuestStateScript = preload("res://scripts/story/quest_state.gd")


## 云游道人@烬龛竖切台词表
static func cloud_wanderer_lines(run_state) -> PackedStringArray:
	var lines: PackedStringArray = []
	var met := bool(run_state != null and run_state.get_choice_flag("npc_cloud_wanderer_met", false))
	var quest_stage := QuestStateScript.get_stage(run_state, QuestStateScript.QUEST_CLOUD_WANDERER)
	if not met:
		lines.append("云游：烬还在跳……你听见天之炉碎裂的回声了吗？")
		lines.append("云游：先把这座烬龛点亮。死了就回到这里——别空手走远。")
		return lines
	if quest_stage == QuestStateScript.STAGE_ACTIVE:
		lines.append("云游：前方的守炉灵还在守门。削它的节奏，别贪刀。")
		lines.append("云游：若你愿听，击败巨阙后再来找我。")
		return lines
	if quest_stage == QuestStateScript.STAGE_COMPLETE:
		lines.append("云游：门开了。血铁的风已经吹到灵墟边缘。")
		lines.append("云游：记住——每一次选择都会烧进炉心。")
		return lines
	lines.append("云游：……走你的路。我会在下一座龛等你。")
	return lines


## 解析指定对话 id；未知 id 返回空
static func resolve_lines(dialogue_id: StringName, run_state) -> PackedStringArray:
	match dialogue_id:
		&"npc_cloud_wanderer":
			return cloud_wanderer_lines(run_state)
		_:
			return PackedStringArray()


## 对话结束后推进旗标/任务
static func apply_aftermath(dialogue_id: StringName, run_state) -> void:
	if run_state == null:
		return
	if dialogue_id != &"npc_cloud_wanderer":
		return
	if not bool(run_state.get_choice_flag("npc_cloud_wanderer_met", false)):
		run_state.set_choice_flag("npc_cloud_wanderer_met", true)
		QuestStateScript.start(run_state, QuestStateScript.QUEST_CLOUD_WANDERER)
		return
	# 已击败巨阙则完成指引任务
	if run_state.guardian_defeated or ("boss_giant_gate" in run_state.defeated_bosses):
		QuestStateScript.complete(run_state, QuestStateScript.QUEST_CLOUD_WANDERER)
