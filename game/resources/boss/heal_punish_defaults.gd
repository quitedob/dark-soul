# game/resources/boss/heal_punish_defaults.gd
extends RefCounted
## Boss 治疗惩罚默认表入口（数据驱动；运行时由 HealingPunishCatalog 消费）
## 章节字典可提供 "healing_punish" 覆盖本表字段

const Catalog = preload("res://scripts/boss/healing_punish_catalog.gd")


## 返回全部内置 Profile 资源
static func all() -> Array:
	return Catalog.all_profiles()


## 按 boss_id 取 Profile
static func for_boss(boss_id: String) -> Resource:
	return Catalog.profile_for(boss_id, {})
