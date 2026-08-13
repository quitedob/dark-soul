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
		&"npc_soul_forgers":
			return soul_forgers_lines(run_state)
		_:
			return PackedStringArray()


## 分结局尾声：读回 ending_state + 命运旗 → 结局专属标题/叙事 + NPC 见证 + 命运后果。
## 返回 { "title", "subtitle", "paragraphs": PackedStringArray, "witnesses": PackedStringArray }。
## 这是 7 个未消费命运旗（fate_*）在终局的消费点。
static func ending_epilogue(ending_id: StringName, run_state) -> Dictionary:
	var title := ""
	var subtitle := ""
	var paragraphs := PackedStringArray()
	if run_state == null:
		return {"title": title, "subtitle": subtitle, "paragraphs": paragraphs, "witnesses": PackedStringArray()}
	match String(ending_id):
		"kindle":
			title = "薪火相传"
			subtitle = "轮回重启，而你化作第一束薪火。"
			paragraphs = PackedStringArray([
				"你踏入炉心，将一路收集的余烬尽数倾回天之炉。",
				"沉寂五百年的轮回重新转动，灵魂再度往返于生死之间，人间开始有新的生命降生。",
				"作为首份燃料，你消散成纯粹的烬，成为新轮回里第一缕重新燃起的光。",
				"世界重生了。只是——那里没有你的位置。",
			])
		"keeper":
			title = "守炉人"
			subtitle = "你坐上烬座，成为新的守炉者。"
			paragraphs = PackedStringArray([
				"你没有击碎它，也没有重铸它。你选择坐下，替烛阴看守那口永恒的炉。",
				"烬座之上，时间失去意义。诸界在你的守望下缓慢愈合，无人知晓你的名字。",
				"永恒铺展在前——寂静、孤独，却必要。",
			])
		"void":
			title = "大寂灭"
			subtitle = "轮回终结，众生终于自由。"
			paragraphs = PackedStringArray([
				"你击碎了烬座，也击碎了轮回本身。",
				"不再有转世，不再有既定的秩序。每一个灵魂第一次拥有了真正的自由——活着、死去、然后消散。",
				"宇宙化作一片可能性的荒野。这是救赎，还是诅咒？没有人能回答。",
			])
		"forge":
			title = "共铸新炉"
			subtitle = "双律并立，轮回由你们共同裁定。"
			paragraphs = PackedStringArray([
				"你没有击败烛阴，也没有取代他。你把四段炉忆交还给他，说服他一起重铸。",
				"新的轮回以更少的记忆为燃料，灵魂可以拒绝转世，也可以选择继续。",
				"你与烛阴都将独立人格熔入炉中，成为彼此制衡的双重炉律——谁也不能单独左右新炉。",
				"这是最接近希望的一种结局，尽管并不完美：世界得到了同意与监督，却失去了促成它的两个人。",
			])
		_:
			return {"title": title, "subtitle": subtitle, "paragraphs": paragraphs, "witnesses": PackedStringArray()}
	# NPC 见证 + 命运后果（消费 npc_*_met + 7 个 fate_* 旗标）
	var witnesses: Array = []
	if bool(run_state.get_choice_flag("npc_cloud_wanderer_met", false)):
		witnesses.append("云游：……你终究没有盲从任何人。")
	if bool(run_state.get_choice_flag("npc_iron_heart_met", false)):
		witnesses.append("铁心：炉火不会忘记替你敲过的那把剑。")
	if bool(run_state.get_choice_flag("npc_lady_of_memories_met", false)):
		witnesses.append("忆姬：你的名字，将第一次被写进轮回。")
	if bool(run_state.get_choice_flag("npc_xuanxiao_remnant_met", false)):
		witnesses.append("玄霄残识：这一次，天界终于闭上了眼睛。")
	if bool(run_state.get_choice_flag("npc_silence_bringer_met", false)):
		witnesses.append("寂灭：我守候的最后一个答案，你带来了。")
	if bool(run_state.get_choice_flag("fate_remnant_trust", false)):
		witnesses.append("九位残影因你释放巨阙的宽恕，在终局为你让开了路。")
	if bool(run_state.get_choice_flag("fate_guardian_protection", false)):
		witnesses.append("巨阙的核心守在你身后，替你挡下最后一缕倾泻的星火。")
	if bool(run_state.get_choice_flag("fate_heroes_aid", false)):
		witnesses.append("铁啸关的两军英魂，在烬座之上列阵为你送行。")
	if bool(run_state.get_choice_flag("fate_zhu_yin_wrath", false)):
		witnesses.append("你吸收的怒意让烛阴燃得更烈——也让你更早看清了它的破绽。")
	if bool(run_state.get_choice_flag("fate_safe_illusion", false)):
		witnesses.append("九尾的幻身，在魂暴中为你撑起一瞬安全。")
	if bool(run_state.get_choice_flag("fate_dispel_illusion", false)):
		witnesses.append("你亲手驱散的那次幻象，成了炉心前最后的清醒。")
	if bool(run_state.get_choice_flag("fate_gravity_boost", false)):
		witnesses.append("玄霄留下的飞升之力，仍在你体内轻轻托举着这片天穹。")
	# 5-3 轮回歧路的悔（samsara_stance 段旗消费）
	if String(run_state.get_choice_flag("samsara_stance_ch1", "accept")) == "regret":
		witnesses.append("你悔于巨阙的结局——那段过去，终夜不散。")
	if String(run_state.get_choice_flag("samsara_stance_ch2", "accept")) == "regret":
		witnesses.append("你悔于刑天的结局——战歌在耳边，仍未停歇。")
	if String(run_state.get_choice_flag("samsara_stance_ch3", "accept")) == "regret":
		witnesses.append("你悔于九尾的结局——镜中的幻梦，无人点破。")
	if String(run_state.get_choice_flag("samsara_stance_ch4", "accept")) == "regret":
		witnesses.append("你悔于玄霄的结局——坠落的城，再无归期。")
	return {"title": title, "subtitle": subtitle, "paragraphs": paragraphs, "witnesses": PackedStringArray(witnesses)}


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


## 5-4 九铸魂者·证词汇合：九位陨落铸魂者依命运选择留下的证词
static func soul_forgers_lines(run_state) -> PackedStringArray:
	var lines: PackedStringArray = []
	lines.append("九铸魂者：你的每一次选择，都已烧进炉心。")
	if bool(run_state.get_choice_flag("fate_remnant_trust", false)):
		lines.append("残影：你释放巨阙的那份宽恕，我们记下了。")
	if bool(run_state.get_choice_flag("fate_guardian_protection", false)):
		lines.append("残影：你留下守护核心，炉心前它会还你一次。")
	if bool(run_state.get_choice_flag("fate_heroes_aid", false)):
		lines.append("残影：铁啸关的英魂，愿在终局为你列阵。")
	if bool(run_state.get_choice_flag("fate_zhu_yin_wrath", false)):
		lines.append("残影：你吞下的怒意，会让烛阴燃得更烈——也露了破绽。")
	if bool(run_state.get_choice_flag("fate_safe_illusion", false)):
		lines.append("残影：九尾的幻身，会替你挡下魂暴。")
	if bool(run_state.get_choice_flag("fate_dispel_illusion", false)):
		lines.append("残影：你能驱散一次幻象，要留给最关键的一刻。")
	if bool(run_state.get_choice_flag("fate_gravity_boost", false)):
		lines.append("残影：玄霄的飞升之力，是你脚下的浮空根基。")
	lines.append("九铸魂者：去吧，最后的答案在烬座。")
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
