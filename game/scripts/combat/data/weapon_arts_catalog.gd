class_name WeaponArtsCatalog
extends RefCounted
## 兵器诀静态目录（L-13）：武器类别 → WeaponArtData，数据驱动、供玩家与工厂查找
## 每个兵器诀的 WeaponArtData 均承担 ≥2 项成本（Focus / 精力 / 前摇·后摇 / 可打断 / 冷却·次数 / 位置·格挡前置）。
## 反制类（fist / shield）art_kind=guard_counter：player 兜底仅认 entry_attack 的 &"leap" tag 前冲，
## guard_success_branch 供未来分发消费（requires_guard_success + positional_precondition=guard_success）。

const WEAPON_ART_PATHS := {
	&"sword": "res://resources/weapon_arts/sword_art.tres",
	&"greatsword": "res://resources/weapon_arts/greatsword_art.tres",
	&"ultra": "res://resources/weapon_arts/ultra_art.tres",
	&"spear": "res://resources/weapon_arts/spear_art.tres",
	&"axe": "res://resources/weapon_arts/axe_art.tres",
	&"curved": "res://resources/weapon_arts/curved_art.tres",
	&"fist": "res://resources/weapon_arts/fist_art.tres",
	&"dagger": "res://resources/weapon_arts/dagger_art.tres",
	&"shield": "res://resources/weapon_arts/shield_art.tres",
}

const CLASS_DISPLAY_NAMES := {
	&"sword": "直剑",
	&"greatsword": "大剑",
	&"ultra": "特大剑",
	&"spear": "长枪",
	&"axe": "战锤",
	&"curved": "曲剑",
	&"fist": "拳套",
	&"dagger": "匕首",
	&"shield": "盾牌",
}

## 类别 → 兵器诀（数据信号标签，供 HUD/分发读取）
const CLASS_ART_IDS := {
	&"sword": &"zhenhuo_stance",
	&"greatsword": &"lieyue_step",
	&"ultra": &"lumen_suppress",
	&"spear": &"pozhen_charge",
	&"axe": &"zhenmai_strike",
	&"curved": &"liuyue_spin",
	&"fist": &"fuhuo_deflect",
	&"dagger": &"yingbu_tigu",
	&"shield": &"tuidun_counter",
}


static func for_type(weapon_type: StringName) -> WeaponArtData:
	var path := String(WEAPON_ART_PATHS.get(weapon_type, ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var loaded := load(path)
	return loaded as WeaponArtData


static func for_weapon(weapon: WeaponData) -> WeaponArtData:
	if weapon == null:
		return null
	return for_type(weapon.weapon_type)


static func class_display_name(weapon_type: StringName) -> String:
	return String(CLASS_DISPLAY_NAMES.get(weapon_type, String(weapon_type)))


static func class_art_id(weapon_type: StringName) -> StringName:
	return CLASS_ART_IDS.get(weapon_type, &"")


static func all_arts() -> Array[WeaponArtData]:
	var arts: Array[WeaponArtData] = []
	for weapon_type in WEAPON_ART_PATHS:
		var art := for_type(weapon_type)
		if art != null:
			arts.append(art)
	return arts


## L-13 校验：所有 authored 兵器诀须通过 WeaponArtData.validate（成本 ≥2 信号 + 分支 AttackData 合法）
static func validate_all() -> Array[String]:
	var errors: Array[String] = []
	for weapon_type in WEAPON_ART_PATHS:
		var art := for_type(weapon_type)
		if art == null:
			errors.append("WeaponArtsCatalog missing art for %s (path %s)." % [weapon_type, WEAPON_ART_PATHS[weapon_type]])
			continue
		for error in art.validate():
			errors.append("%s: %s" % [art.art_id, error])
	return errors
