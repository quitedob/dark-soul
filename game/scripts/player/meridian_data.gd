class_name MeridianData
extends RefCounted
## L-09：奇经八脉静态目录 —— 8 条经脉 × 5 级，每级授予固定效果。
## 升级材料（灵气结晶/纯阳石/龙脉精髓）尚未落入资源掉落系统，先用递增烬价代偿；
## MATERIAL_COSTS 以"当前等级 → 下一级"为键，命名设计材料供提示文案显示风味。

const MAX_LEVEL := 5

## 八脉：id / 名称 / 效果类型 / 每级数值。
## effect_type 取值固定集合：
##   max_health / max_stamina / max_focus / damage_mult /
##   armor_pdr / move_speed / focus_regen / roll_tier
## 乘数类（damage_mult/move_speed/focus_regen）以 1.0 为基逐级累加；flat 类以 0 为基累加。
## 映射：任=HP、督=耐力、冲=灵蕴、带=负重/翻滚、阴跷=增伤（原典为闪避帧）、
##       阳跷=移速、阴维=物理减伤、阳维=灵蕴回复。
const MERIDIANS := [
	{"id": "ren", "name": "REN MAI", "display_name": "任脉 · 气海", "effect_type": "max_health", "per_level": 8.0},
	{"id": "du", "name": "DU MAI", "display_name": "督脉 · 阳脊", "effect_type": "max_stamina", "per_level": 6.0},
	{"id": "chong", "name": "CHONG MAI", "display_name": "冲脉 · 血海", "effect_type": "max_focus", "per_level": 5.0},
	{"id": "dai", "name": "DAI MAI", "display_name": "带脉 · 腰束", "effect_type": "roll_tier", "per_level": 1.0},
	{"id": "yin_qiao", "name": "YIN QIAO", "display_name": "阴跷脉 · 足跟", "effect_type": "damage_mult", "per_level": 0.04},
	{"id": "yang_qiao", "name": "YANG QIAO", "display_name": "阳跷脉 · 足踝", "effect_type": "move_speed", "per_level": 0.03},
	{"id": "yin_wei", "name": "YIN WEI", "display_name": "阴维脉 · 内守", "effect_type": "armor_pdr", "per_level": 0.02},
	{"id": "yang_wei", "name": "YANG WEI", "display_name": "阳维脉 · 外维", "effect_type": "focus_regen", "per_level": 0.05},
]

## 升级材料表（tier = 当前等级，即从 tier 升到 tier+1 的消耗）。
## embers 为当前代偿价；material_name 为设计材料风味名（后续掉落系统可替换）。
const MATERIAL_COSTS := {
	0: {"material_name": "灵气结晶 ×3 (Spirit Crystal)", "embers": 120},
	1: {"material_name": "灵气结晶 ×8 (Spirit Crystal)", "embers": 220},
	2: {"material_name": "纯阳石 ×5 (Pure Yang Stone)", "embers": 380},
	3: {"material_name": "龙脉精髓 ×3 (Dragon Vein Essence)", "embers": 620},
	4: {"material_name": "龙脉精髓 ×5 (Dragon Vein Essence)", "embers": 980},
}


static func all() -> Array:
	return MERIDIANS.duplicate(true)


## 返回所有经脉 id（任督冲带 + 四维），用作轮转顺序
static func all_ids() -> Array:
	var ids: Array = []
	for meridian in MERIDIANS:
		ids.append(String(meridian["id"]))
	return ids


static func get_meridian(meridian_id: String) -> Dictionary:
	for meridian in MERIDIANS:
		if String(meridian["id"]) == meridian_id:
			return (meridian as Dictionary).duplicate(true)
	return {}


static func has_meridian(meridian_id: String) -> bool:
	return not get_meridian(meridian_id).is_empty()


static func effect_label(effect_type: String) -> String:
	match effect_type:
		"max_health": return "HP"
		"max_stamina": return "STA"
		"max_focus": return "FOC"
		"damage_mult": return "DMG"
		"armor_pdr": return "PDR"
		"move_speed": return "SPD"
		"focus_regen": return "FOC REGEN"
		"roll_tier": return "ROLL"
	return effect_type
