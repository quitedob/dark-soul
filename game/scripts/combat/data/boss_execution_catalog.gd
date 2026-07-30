extends RefCounted
class_name BossExecutionCatalog
## 五主 Boss Execution Break 权威表

const ProfileScript = preload("res://scripts/combat/data/boss_execution_break_profile.gd")


static func all_profiles() -> Array:
	return [
		make_giant_gate(),
		make_xing_tian(),
		make_nine_tails(),
		make_xuan_xiao(),
		make_zhu_yin(),
	]


static func profile_for_boss_id(boss_id: String) -> Resource:
	var key := StringName(boss_id)
	for profile in all_profiles():
		if profile.boss_id == key:
			return profile
	# 兼容别名
	match boss_id:
		"cinder_guardian", "guardian":
			return make_giant_gate()
	return null


static func make_giant_gate() -> Resource:
	var p = ProfileScript.new()
	p.boss_id = &"boss_giant_gate"
	p.display_name_key = &"巨阙"
	p.story_flag = &"ch1_guardian_fate"
	p.max_execution_break = 110.0
	p.expose_seconds = 3.4
	p.story_floor_ratio = 0.10
	p.weak_point_anchor = &"furnace_core"
	p.weak_point_offset = Vector3(0.0, 1.85, 0.55)
	p.interaction_distance = 3.4
	p.critical_multiplier = 2.3
	p.allow_lethal_on_execution = false
	return p


static func make_xing_tian() -> Resource:
	var p = ProfileScript.new()
	p.boss_id = &"boss_xing_tian"
	p.display_name_key = &"刑天"
	p.story_flag = &"ch2_xingtian_fate"
	p.max_execution_break = 130.0
	p.expose_seconds = 3.0
	p.story_floor_ratio = 0.10
	p.weak_point_anchor = &"chest_eye"
	p.weak_point_offset = Vector3(0.0, 2.2, 0.7)
	p.interaction_distance = 3.6
	p.critical_multiplier = 2.4
	p.allow_lethal_on_execution = false
	return p


static func make_nine_tails() -> Resource:
	var p = ProfileScript.new()
	p.boss_id = &"boss_nine_tails"
	p.display_name_key = &"九尾"
	p.story_flag = &"ch3_nine_tails_fate"
	p.max_execution_break = 120.0
	p.expose_seconds = 2.8
	p.story_floor_ratio = 0.30  # 救赎线 30% 停战
	p.weak_point_anchor = &"tail_root"
	p.weak_point_offset = Vector3(0.0, 1.4, -0.9)
	p.interaction_distance = 3.0
	p.critical_multiplier = 2.5
	p.allow_lethal_on_execution = false
	return p


static func make_xuan_xiao() -> Resource:
	var p = ProfileScript.new()
	p.boss_id = &"boss_xuan_xiao"
	p.display_name_key = &"玄霄"
	p.story_flag = &"ch4_xuanxiao_fate"
	p.max_execution_break = 140.0
	p.expose_seconds = 3.1
	p.story_floor_ratio = 0.10
	p.weak_point_anchor = &"fusion_core"
	p.weak_point_offset = Vector3(0.0, 1.7, 0.35)
	p.interaction_distance = 3.2
	p.critical_multiplier = 2.35
	p.allow_lethal_on_execution = false
	return p


static func make_zhu_yin() -> Resource:
	var p = ProfileScript.new()
	p.boss_id = &"boss_zhu_yin"
	p.display_name_key = &"烛阴"
	p.story_flag = &"ending_state"
	p.max_execution_break = 160.0
	p.expose_seconds = 3.6
	p.story_floor_ratio = 0.10
	p.weak_point_anchor = &"star_core"
	p.weak_point_offset = Vector3(0.0, 2.6, 0.8)
	p.interaction_distance = 4.0
	p.critical_multiplier = 2.6
	p.allow_lethal_on_execution = false
	return p
