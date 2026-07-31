# game/scripts/story/dialogue_runner.gd
class_name DialogueRunner
extends RefCounted
## 条件对白解析：按 choice_flags / 任务阶段过滤台词行

const QuestStateScript = preload("res://scripts/story/quest_state.gd")
const EndingResolverScript = preload("res://scripts/story/ending_resolver.gd")


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
		&"npc_iron_heart":
			return iron_heart_lines(run_state)
		&"npc_lady_of_memories":
			return lady_of_memories_lines(run_state)
		&"npc_xuanxiao_remnant":
			return xuanxiao_remnant_lines(run_state)
		&"npc_silence_bringer":
			return silence_bringer_lines(run_state)
		&"npc_bridge_tea_soul":
			return bridge_tea_soul_lines(run_state)
		_:
			return PackedStringArray()


## L-05：铁心（魂匠）——锻造服务台词
static func iron_heart_lines(run_state) -> PackedStringArray:
	var lines: PackedStringArray = []
	var met := bool(run_state != null and run_state.get_choice_flag("npc_iron_heart_met", false))
	if not met:
		lines.append("铁心：我叫铁心。炉子跟了我三百年，比你祖上还老。")
		lines.append("铁心：想变强就找一口好兵器。坐下歇息时，我可帮你把它敲打到 +10。")
		return lines
	var level := int(run_state.progression_values.get("weapon_forge_level", 0)) if run_state != null else 0
	lines.append("铁心：你那把家伙现在锻到 +%d。每敲一级，伤害多一分。" % level)
	lines.append("铁心：要想再敲，备好烬再来找我。")
	return lines


## L-05：忆姬（记忆典藏）——记忆证物台词
static func lady_of_memories_lines(run_state) -> PackedStringArray:
	var lines: PackedStringArray = []
	var met := bool(run_state != null and run_state.get_choice_flag("npc_lady_of_memories_met", false))
	if not met:
		lines.append("忆姬：你是第一个没有前世的人。那些红晶里记着别人的轮回。")
		lines.append("忆姬：若你集齐四段炉忆，或许能听懂天炉真正的低语。")
		return lines
	var memories := 0
	if run_state != null:
		for key in ["furnace_memory_1", "furnace_memory_2", "furnace_memory_3", "furnace_memory_4"]:
			if bool(run_state.get_choice_flag(key, false)):
				memories += 1
	lines.append("忆姬：你已找到 %d/4 段红晶记忆。" % memories)
	lines.append("忆姬：最后一段在九铸魂者之墓——那里埋着答案。")
	return lines


## L-05：玄霄残识——第四章命运情报
static func xuanxiao_remnant_lines(run_state) -> PackedStringArray:
	var lines: PackedStringArray = []
	var met := bool(run_state != null and run_state.get_choice_flag("npc_xuanxiao_remnant_met", false))
	if not met:
		lines.append("玄霄残识：我败了，但没碎。记得真身被光与腐纠缠到最后一刻。")
		lines.append("玄霄残识：去找炉心的主。它叫烛阴——不毁星核，终局不会停下。")
		return lines
	if bool(run_state.get_choice_flag("fate_zhu_yin_weakness", false)):
		lines.append("玄霄残识：你记住那弱点就好。星核与颈隙——那两处，能让它真正俯首。")
		return lines
	lines.append("玄霄残识：我只会提醒一次——烛阴的命门是星核。")
	return lines


## L-05：寂灭（最后一位活着的铸魂者）——终章见证
static func silence_bringer_lines(run_state) -> PackedStringArray:
	var lines: PackedStringArray = []
	var met := bool(run_state != null and run_state.get_choice_flag("npc_silence_bringer_met", false))
	if not met:
		lines.append("寂灭：九位已逝，我守在这里，等最后一个答案。")
		lines.append("寂灭：若你集齐三真相与四炉忆，可在烬座前选择重铸——而不是终结。")
		return lines
	if run_state != null and EndingResolverScript.reachable(run_state).has(&"forge"):
		lines.append("寂灭：四段炉忆齐了，三个问题也有了回音。去共铸新炉吧。")
		return lines
	lines.append("寂灭：轮回的笔在你手里。想清楚再落笔。")
	return lines


## 支线·桥头的供茶：茶魂（桥头茶摊守者）——被怨魂归罪的无辜者
static func bridge_tea_soul_lines(run_state) -> PackedStringArray:
	var lines: PackedStringArray = []
	var met := bool(run_state != null and run_state.get_choice_flag("npc_bridge_tea_soul_met", false))
	if not met:
		lines.append("茶魂：那杯茶……还温着。桥头风大，别让它凉了。")
		lines.append("茶魂：他们说是我这茶摊勾走了那孩子。可我不过……递过一盏热茶。")
		return lines
	var quest_stage := QuestStateScript.get_stage(run_state, QuestStateScript.QUEST_BRIDGE_TEA)
	var fate_chosen := String(run_state.get_choice_flag("bridge_tea_fate", "")) != ""
	if quest_stage == QuestStateScript.STAGE_ACTIVE and not fate_chosen:
		lines.append("茶魂：忆姬翻过旧档——真正吸干他的是贪烬鬼。它们以情为饵。")
		lines.append("茶魂：可怨魂只信自己想信的。月圆封魂礼，就快到了。")
		return lines
	if bool(run_state.get_choice_flag("bridge_tea_exposed", false)):
		lines.append("茶魂：真相渡过了桥，他也终于渡了过去。谢谢你。")
		return lines
	if bool(run_state.get_choice_flag("bridge_tea_mob", false)):
		lines.append("茶魂：他们封了我。这就是他们要的公正。……茶还温着，你喝吧。")
		return lines
	lines.append("茶魂：桥头风大。茶还温着。")
	return lines


## 对话结束后推进旗标/任务
static func apply_aftermath(dialogue_id: StringName, run_state) -> void:
	if run_state == null:
		return
	match dialogue_id:
		&"npc_cloud_wanderer":
			if not bool(run_state.get_choice_flag("npc_cloud_wanderer_met", false)):
				run_state.set_choice_flag("npc_cloud_wanderer_met", true)
				QuestStateScript.start(run_state, QuestStateScript.QUEST_CLOUD_WANDERER)
				return
			# 已击败巨阙则完成指引任务
			if run_state.guardian_defeated or ("boss_giant_gate" in run_state.defeated_bosses):
				QuestStateScript.complete(run_state, QuestStateScript.QUEST_CLOUD_WANDERER)
		&"npc_iron_heart":
			# 解锁锻造能力（铁心工坊）
			run_state.set_choice_flag("npc_iron_heart_met", true)
			run_state.set_choice_flag("unlock_weapon_forging", true)
		&"npc_lady_of_memories":
			run_state.set_choice_flag("npc_lady_of_memories_met", true)
		&"npc_xuanxiao_remnant":
			run_state.set_choice_flag("npc_xuanxiao_remnant_met", true)
		&"npc_silence_bringer":
			run_state.set_choice_flag("npc_silence_bringer_met", true)
		&"npc_bridge_tea_soul":
			run_state.set_choice_flag("npc_bridge_tea_soul_met", true)
