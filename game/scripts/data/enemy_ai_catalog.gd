# game/scripts/data/enemy_ai_catalog.gd
class_name EnemyAiCatalog
extends RefCounted
## G-05：聚合五章敌人 AI 参数（detection / leash / nav / behavior）

const Chapter1Content = preload("res://scripts/data/chapter_1_content.gd")
const Chapter2Content = preload("res://scripts/data/chapter_2_content.gd")
const Chapter3Content = preload("res://scripts/data/chapter_3_content.gd")
const Chapter4Content = preload("res://scripts/data/chapter_4_content.gd")
const Chapter5Content = preload("res://scripts/data/chapter_5_content.gd")
const EnemyTuningData = preload("res://scripts/data/enemy_tuning.gd")


## 设计口径 32 + skirmisher；返回标准化 profile 列表
static func all_enemy_profiles() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry in Chapter1Content.enemies():
		out.append(normalize(entry))
	for entry in Chapter2Content.enemies():
		out.append(normalize(entry))
	for entry in Chapter3Content.enemies():
		out.append(normalize(entry))
	for entry in Chapter4Content.enemies():
		out.append(normalize(entry))
	for entry in Chapter5Content.enemies():
		out.append(normalize(entry))
	return out


## 按 id 查找 profile（含精英补齐字段）
static func profile_for_id(enemy_id: String) -> Dictionary:
	for p in all_enemy_profiles():
		if String(p.get("id", "")) == enemy_id:
			return p
	for elite in _all_elites_raw():
		if String(elite.get("id", "")) == enemy_id:
			return normalize(elite)
	return {}


## 标准化：补 nav / leash 缺省，挂 behavior
static func normalize(raw: Dictionary) -> Dictionary:
	var profile := raw.duplicate(true)
	var fallback := EnemyTuningData.TYPE_TUNING.get("hollow_sentinel", {}) as Dictionary
	profile["aggro_range"] = float(profile.get("aggro_range", fallback.get("aggro_range", 13.0)))
	profile["disengage_range"] = float(profile.get("disengage_range", fallback.get("disengage_range", 20.0)))
	profile["leash_range"] = float(profile.get("leash_range", fallback.get("leash_range", 17.0)))
	profile["attack_range"] = float(profile.get("attack_range", fallback.get("attack_range", 2.15)))
	profile["behavior"] = String(profile.get("behavior", "slow_patrol")).to_lower()
	# 导航体型：按 body_type / 默认
	var body := String(profile.get("body_type", ""))
	var nav := _nav_for_body(body)
	profile["nav_radius"] = float(profile.get("nav_radius", nav["radius"]))
	profile["nav_height"] = float(profile.get("nav_height", nav["height"]))
	profile["path_desired_distance"] = float(profile.get("path_desired_distance", 0.35))
	profile["target_desired_distance"] = float(profile.get("target_desired_distance", nav["target_desired"]))
	profile["body_radius"] = float(profile.get("body_radius", nav["body_r"]))
	profile["body_height"] = float(profile.get("body_height", nav["body_h"]))
	profile["body_y"] = float(profile.get("body_y", nav["body_y"]))
	return profile


static func _nav_for_body(body_type: String) -> Dictionary:
	match body_type:
		"hulking_molten", "massive_golem", "armored_heavy":
			return {"radius": 0.62, "height": 2.3, "target_desired": 1.8, "body_r": 0.58, "body_h": 2.25, "body_y": 1.12}
		"ethereal_flicker", "wraith_thin":
			return {"radius": 0.36, "height": 1.65, "target_desired": 1.2, "body_r": 0.34, "body_h": 1.6, "body_y": 0.8}
		"flying_small", "swarm":
			return {"radius": 0.32, "height": 1.4, "target_desired": 1.1, "body_r": 0.3, "body_h": 1.35, "body_y": 0.7}
		_:
			return {"radius": 0.48, "height": 1.9, "target_desired": 1.5, "body_r": 0.45, "body_h": 1.9, "body_y": 0.95}


static func _all_elites_raw() -> Array:
	var out: Array = []
	out.append_array(Chapter1Content.elites())
	out.append_array(Chapter2Content.elites())
	out.append_array(Chapter3Content.elites())
	out.append_array(Chapter4Content.elites())
	out.append_array(Chapter5Content.elites())
	return out


## 设计口径普通敌人数（含 skirmisher）
static func enemy_count() -> int:
	return all_enemy_profiles().size()
