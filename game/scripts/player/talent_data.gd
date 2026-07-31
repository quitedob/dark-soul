class_name TalentData
extends RefCounted
## L-09：天赋数据权威源。8 职业（4 基础 + 4 混合），每职业 3 阶天赋树。
##
## 职业 → 战斗风格映射：
##   基础：狂战士→刑天斧(1) 神射手→羿弓术(2) 玄法师→五行术(3) 祝祷师→天祝术(4)
##   混合（Ch.3 后双亲各 ≥5 天赋点解锁）：
##     阴阳师(mystic+invoker) 战巫(barbarian+invoker)
##     魔弓手(marksman+mystic) 修罗(barbarian+marksman)
##   混合暂无独立 combat style，style 字段为虚拟 id（5..8），切至基础父风格。
## 守卫者(RELIQUARY_GUARD, style 0) 无职业归属，始终自由切换。

## 支持的效果类型
const EFFECT_TYPES: Array[StringName] = [
	&"max_health", &"max_stamina", &"max_focus", &"damage_mult", &"armor_pdr",
	&"move_speed", &"focus_regen", &"parry_window", &"dodge_i_frames", &"summon_reserve",
]

## 混合职业双亲解锁阈值（各 ≥ N 点）
const HYBRID_PARENT_POINTS := 5

## 虚拟混合 style id（尚无独立 loadout；切至 base_style 落地）
const STYLE_YIN_YANG := 5
const STYLE_WAR_SHAMAN := 6
const STYLE_ARCANE_ARCHER := 7
const STYLE_ASURA := 8

## 与 player.gd CombatStyle 对齐：RELIQUARY_GUARD=0 TWIN_COLOSSI=1 CRESCENT_PAIR=2 VEILCRAFT=3 EMBER_RITE=4
const STYLE_TWIN_COLOSSI := 1
const STYLE_CRESCENT_PAIR := 2
const STYLE_VEILCRAFT := 3
const STYLE_EMBER_RITE := 4


## 8 职业总表（基础映射既有战斗风格；混合带双亲需求）
static func all_classes() -> Array[Dictionary]:
	return [
		{
			"id": &"barbarian", "name": "狂战士", "pinyin": "Kuang Zhan Shi",
			"style": STYLE_TWIN_COLOSSI, "hybrid": false, "parents": [],
			"base_style": STYLE_TWIN_COLOSSI, "parent_styles": [STYLE_TWIN_COLOSSI],
		},
		{
			"id": &"marksman", "name": "神射手", "pinyin": "Shen She Shou",
			"style": STYLE_CRESCENT_PAIR, "hybrid": false, "parents": [],
			"base_style": STYLE_CRESCENT_PAIR, "parent_styles": [STYLE_CRESCENT_PAIR],
		},
		{
			"id": &"mystic", "name": "玄法师", "pinyin": "Xuan Fa Shi",
			"style": STYLE_VEILCRAFT, "hybrid": false, "parents": [],
			"base_style": STYLE_VEILCRAFT, "parent_styles": [STYLE_VEILCRAFT],
		},
		{
			"id": &"invoker", "name": "祝祷师", "pinyin": "Zhu Dao Shi",
			"style": STYLE_EMBER_RITE, "hybrid": false, "parents": [],
			"base_style": STYLE_EMBER_RITE, "parent_styles": [STYLE_EMBER_RITE],
		},
		{
			"id": &"yin_yang", "name": "阴阳师", "pinyin": "Yin Yang Shi",
			"style": STYLE_YIN_YANG, "hybrid": true, "parents": [&"mystic", &"invoker"],
			"base_style": STYLE_VEILCRAFT, "parent_styles": [STYLE_VEILCRAFT, STYLE_EMBER_RITE],
		},
		{
			"id": &"war_shaman", "name": "战巫", "pinyin": "Zhan Wu",
			"style": STYLE_WAR_SHAMAN, "hybrid": true, "parents": [&"barbarian", &"invoker"],
			"base_style": STYLE_EMBER_RITE, "parent_styles": [STYLE_TWIN_COLOSSI, STYLE_EMBER_RITE],
		},
		{
			"id": &"arcane_archer", "name": "魔弓手", "pinyin": "Mo Gong Shou",
			"style": STYLE_ARCANE_ARCHER, "hybrid": true, "parents": [&"marksman", &"mystic"],
			"base_style": STYLE_CRESCENT_PAIR, "parent_styles": [STYLE_CRESCENT_PAIR, STYLE_VEILCRAFT],
		},
		{
			"id": &"asura", "name": "修罗", "pinyin": "Xiu Luo",
			"style": STYLE_ASURA, "hybrid": true, "parents": [&"barbarian", &"marksman"],
			"base_style": STYLE_TWIN_COLOSSI, "parent_styles": [STYLE_TWIN_COLOSSI, STYLE_CRESCENT_PAIR],
		},
	]


## 按职业 id 查职业；未知返回 {}
static func class_for_id(class_id: StringName) -> Dictionary:
	var target := String(class_id)
	for cls in all_classes():
		if String(cls["id"]) == target:
			return cls
	return {}


## 按战斗 style（含虚拟混合 id 5..8）查职业；守卫者/未知返回 {}
static func class_for_style(style_id: int) -> Dictionary:
	for cls in all_classes():
		if int(cls["style"]) == style_id:
			return cls
	return {}


## 按 style 查基础职业（混合虚拟 id 回落到 base_style）
static func base_class_for_style(style_id: int) -> Dictionary:
	var normalized := style_id
	if normalized > STYLE_ASURA:
		return {}
	for cls in all_classes():
		if not cls["hybrid"] and int(cls["style"]) == normalized:
			return cls
	return {}


## 某职业的天赋树（3 阶）
static func tree_for(class_id: StringName) -> Array[Dictionary]:
	match class_id:
		&"marksman":
			return [
				_talent(&"marksman_eagle_eye", "鹰眼", 1, 3, 0, "damage_mult", 0.03),
				_talent(&"marksman_swift_step", "疾步", 1, 3, 0, "move_speed", 0.12),
				_talent(&"marksman_draw_mastery", "蓄力专精", 1, 3, 0, "damage_mult", 0.04),
				_talent(&"marksman_cloud_piercer", "穿云", 2, 3, 3, "damage_mult", 0.05),
				_talent(&"marksman_fire_blood", "火神之血", 2, 3, 3, "max_focus", 8.0),
				_talent(&"marksman_ice_heart", "寒冰之心", 2, 3, 3, "focus_regen", 0.25),
				_talent(&"marksman_hou_yi_soul", "后羿之魂", 3, 1, 5, "damage_mult", 0.08),
				_talent(&"marksman_nine_suns", "九日连珠", 3, 1, 5, "damage_mult", 0.06),
				_talent(&"marksman_heaven_unity", "天人合一", 3, 1, 5, "focus_regen", 0.5),
			]
		&"barbarian":
			return [
				_talent(&"barbarian_bloodlust", "嗜血", 1, 3, 0, "damage_mult", 0.03),
				_talent(&"barbarian_iron_bones", "钢筋铁骨", 1, 3, 0, "armor_pdr", 0.02),
				_talent(&"barbarian_unyielding", "不屈", 1, 3, 0, "max_health", 15.0),
				_talent(&"barbarian_fierce_gaze", "刑天怒目", 2, 3, 3, "damage_mult", 0.06),
				_talent(&"barbarian_blood_battle", "浴血奋战", 2, 3, 3, "damage_mult", 0.04),
				_talent(&"barbarian_rage_storm", "狂怒风暴", 2, 3, 3, "armor_pdr", 0.03),
				_talent(&"barbarian_xingtian_will", "刑天之志", 3, 1, 5, "max_health", 30.0),
				_talent(&"barbarian_eyes_on_chest", "以乳为目", 3, 1, 5, "armor_pdr", 0.06),
				_talent(&"barbarian_mouth_on_belly", "脐为口", 3, 1, 5, "damage_mult", 0.10),
			]
		&"mystic":
			return [
				_talent(&"mystic_vital_qi", "灵力充沛", 1, 3, 0, "max_focus", 10.0),
				_talent(&"mystic_elemental_affinity", "元素亲和", 1, 3, 0, "damage_mult", 0.03),
				_talent(&"mystic_swift_seals", "快速结印", 1, 3, 0, "focus_regen", 0.25),
				_talent(&"mystic_generative_force", "相生之力", 2, 3, 3, "focus_regen", 0.3),
				_talent(&"mystic_overcoming_force", "相克之威", 2, 3, 3, "damage_mult", 0.06),
				_talent(&"mystic_formation_boost", "法阵强化", 2, 3, 3, "max_focus", 12.0),
				_talent(&"mystic_five_unity", "五行归一", 3, 1, 5, "damage_mult", 0.08),
				_talent(&"mystic_dao_nature", "道法自然", 3, 1, 5, "focus_regen", 0.5),
				_talent(&"mystic_laojun_furnace", "太上老君之炉", 3, 1, 5, "max_focus", 25.0),
			]
		&"invoker":
			return [
				_talent(&"invoker_great_compassion", "大慈大悲", 1, 3, 0, "max_health", 12.0),
				_talent(&"invoker_karma_mastery", "业力掌控", 1, 3, 0, "focus_regen", 0.25),
				_talent(&"invoker_spirit_affinity", "灵体亲和", 1, 3, 0, "summon_reserve", 1.0),
				_talent(&"invoker_save_all", "普度众生", 2, 3, 3, "max_health", 15.0),
				_talent(&"invoker_samsara_eye", "轮回之眼", 2, 3, 3, "focus_regen", 0.3),
				_talent(&"invoker_vajra_body", "金刚不坏", 2, 3, 3, "armor_pdr", 0.03),
				_talent(&"invoker_dizang_vow", "地藏王愿", 3, 1, 5, "max_health", 35.0),
				_talent(&"invoker_thousand_hands", "千手观音", 3, 1, 5, "summon_reserve", 2.0),
				_talent(&"invoker_nirvana", "涅槃寂静", 3, 1, 5, "armor_pdr", 0.06),
			]
		&"yin_yang":
			return [
				_talent(&"yin_yang_balance", "阴阳调和", 1, 3, 0, "max_focus", 10.0),
				_talent(&"yin_yang_coexistence", "五行共生", 1, 3, 0, "max_health", 10.0),
				_talent(&"yin_yang_qi_cycle", "灵力循环", 1, 3, 0, "focus_regen", 0.2),
				_talent(&"yin_yang_mutual_generation", "相生相克", 2, 3, 3, "damage_mult", 0.05),
				_talent(&"yin_yang_compassion_form", "慈悲法阵", 2, 3, 3, "armor_pdr", 0.03),
				_talent(&"yin_yang_dual_path", "双修之道", 2, 3, 3, "focus_regen", 0.3),
				_talent(&"yin_yang_taiji_unity", "太极归一", 3, 1, 5, "damage_mult", 0.08),
				_talent(&"yin_yang_enlightenment", "明心见性", 3, 1, 5, "max_focus", 20.0),
				_talent(&"yin_yang_primordial_qi", "混元一气", 3, 1, 5, "armor_pdr", 0.05),
			]
		&"war_shaman":
			return [
				_talent(&"war_shaman_war_prayer", "战祷", 1, 3, 0, "damage_mult", 0.03),
				_talent(&"war_shaman_stalwart_body", "坚躯", 1, 3, 0, "max_health", 12.0),
				_talent(&"war_shaman_spirit_guard", "灵护", 1, 3, 0, "armor_pdr", 0.02),
				_talent(&"war_shaman_frenzy_hymn", "狂怒圣咏", 2, 3, 3, "damage_mult", 0.06),
				_talent(&"war_shaman_vajra_war", "金刚战体", 2, 3, 3, "armor_pdr", 0.03),
				_talent(&"war_shaman_blood_blessing", "浴血祈福", 2, 3, 3, "max_health", 15.0),
				_talent(&"war_shaman_war_god", "战神附体", 3, 1, 5, "damage_mult", 0.09),
				_talent(&"war_shaman_undying_spirit", "不灭战魂", 3, 1, 5, "max_health", 30.0),
				_talent(&"war_shaman_holy_shield", "圣战之盾", 3, 1, 5, "armor_pdr", 0.06),
			]
		&"arcane_archer":
			return [
				_talent(&"arcane_archer_spirit_arrow", "灵矢", 1, 3, 0, "damage_mult", 0.03),
				_talent(&"arcane_archer_swift_shadow", "迅影", 1, 3, 0, "move_speed", 0.12),
				_talent(&"arcane_archer_elemental_charge", "元素蓄能", 1, 3, 0, "max_focus", 10.0),
				_talent(&"arcane_archer_enchanted_arrow", "附魔之箭", 2, 3, 3, "damage_mult", 0.06),
				_talent(&"arcane_archer_elemental_rain", "五行箭雨", 2, 3, 3, "damage_mult", 0.04),
				_talent(&"arcane_archer_arcane_step", "玄机步", 2, 3, 3, "move_speed", 0.12),
				_talent(&"arcane_archer_divine_archer", "羿神魔弓", 3, 1, 5, "damage_mult", 0.10),
				_talent(&"arcane_archer_nine_arrows", "九箭连珠", 3, 1, 5, "focus_regen", 0.4),
				_talent(&"arcane_archer_heaven_earth", "天人合一", 3, 1, 5, "move_speed", 0.2),
			]
		&"asura":
			return [
				_talent(&"asura_will", "修罗战意", 1, 3, 0, "damage_mult", 0.03),
				_talent(&"asura_gale_blade", "疾风刃", 1, 3, 0, "move_speed", 0.12),
				_talent(&"asura_frenzied_bones", "狂骨", 1, 3, 0, "armor_pdr", 0.02),
				_talent(&"asura_fight_to_death", "血战到底", 2, 3, 3, "damage_mult", 0.06),
				_talent(&"asura_soul_chasing", "追魂箭", 2, 3, 3, "damage_mult", 0.04),
				_talent(&"asura_vajra_body", "金刚身", 2, 3, 3, "armor_pdr", 0.03),
				_talent(&"asura_king", "修罗王", 3, 1, 5, "damage_mult", 0.10),
				_talent(&"asura_ten_thousand_arrows", "万箭归宗", 3, 1, 5, "move_speed", 0.2),
				_talent(&"asura_immortal", "不灭修罗", 3, 1, 5, "max_health", 30.0),
			]
	return []


## 单条天赋
static func talent(class_id: StringName, talent_id: StringName) -> Dictionary:
	var target := String(talent_id)
	for t in tree_for(class_id):
		if String(t["id"]) == target:
			return t
	return {}


## 校验效果类型合法
static func is_valid_effect(effect_type: String) -> bool:
	return StringName(effect_type) in EFFECT_TYPES


static func _talent(
	id: StringName,
	name: String,
	tier: int,
	max_level: int,
	points_required: int,
	effect_type: String,
	value: float
) -> Dictionary:
	return {
		"id": id, "name": name, "tier": tier, "max_level": max_level,
		"points_required": points_required, "effect_type": effect_type, "value": value,
	}
