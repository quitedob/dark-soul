# game/scripts/boss/healing_punish_catalog.gd
extends RefCounted
class_name HealingPunishCatalog
## Boss 治疗惩罚变体目录：按 boss_id / 章节字典解析并选招

const ProfileScript = preload("res://scripts/boss/healing_punish_profile.gd")

const VARIANT_GAP_CLOSE := &"gap_close"
const VARIANT_RANGED_SNIPE := &"ranged_snipe"
const VARIANT_AOE_BURST := &"aoe_burst"

# ── 默认招式模板（可被 Profile / chapter_content 覆盖）────────────────

static var DEFAULT_GAP_CLOSE := {
	"windup": 0.42, "active": 0.20, "recovery": 0.48,
	"damage": 28.0, "stagger": 34.0, "lunge": 4.6, "heavy": true,
}

static var DEFAULT_RANGED_SNIPE := {
	"windup": 0.55, "active": 0.28, "recovery": 0.72,
	"damage": 36.0, "stagger": 40.0, "lunge": 5.2, "heavy": true,
}

static var DEFAULT_AOE_BURST := {
	"windup": 0.38, "active": 0.22, "recovery": 0.85,
	"damage": 30.0, "stagger": 36.0, "lunge": 0.0, "heavy": true,
	"aoe_radius": 4.5,
}


## 按 boss_id 取默认 Profile；章节字典可覆盖字段
static func profile_for(boss_id: String, chapter_content: Dictionary = {}) -> Resource:
	var profile: Resource = _make_default_for(boss_id)
	_apply_content_override(profile, chapter_content)
	return profile


## 解析本次治疗惩罚：返回 {variant, windup, ..., aoe_radius, windup_scale}
static func resolve(profile: Resource, distance: float, phase: int) -> Dictionary:
	if profile == null:
		profile = _make_default_for("boss_giant_gate")
	var variant: StringName = _pick_variant(profile, distance, phase)
	var attack: Dictionary = _attack_for_variant(profile, variant)
	var result := attack.duplicate(true)
	result["variant"] = String(variant)
	result["windup_scale"] = float(profile.windup_scale)
	if not result.has("aoe_radius"):
		result["aoe_radius"] = 0.0
	if variant == VARIANT_AOE_BURST and float(result["aoe_radius"]) <= 0.0:
		result["aoe_radius"] = float(DEFAULT_AOE_BURST["aoe_radius"])
	return result


## 列出本仓库权威 Boss 的 punish Profile（合约 / 校验用）
static func all_profiles() -> Array:
	return [
		_make_giant_gate(),
		_make_xing_tian(),
		_make_nine_tails(),
		_make_xuan_xiao(),
		_make_zhu_yin(),
	]


static func _pick_variant(profile: Resource, distance: float, phase: int) -> StringName:
	# 显式优先表：取第一个当前距离/阶段合法的变体
	var prefers: PackedStringArray = profile.prefer_variants
	if prefers != null and prefers.size() > 0:
		for raw in prefers:
			var name := StringName(String(raw))
			if _variant_allowed(profile, name, distance, phase):
				return name
	# 自动：近距高阶 AoE → 中近 gap-close → 远距 snipe
	if _variant_allowed(profile, VARIANT_AOE_BURST, distance, phase):
		return VARIANT_AOE_BURST
	if distance >= float(profile.ranged_snipe_min_dist):
		return VARIANT_RANGED_SNIPE
	return VARIANT_GAP_CLOSE


static func _variant_allowed(profile: Resource, variant: StringName, distance: float, phase: int) -> bool:
	match variant:
		VARIANT_AOE_BURST:
			return phase >= int(profile.aoe_min_phase) and distance <= float(profile.aoe_burst_max_dist)
		VARIANT_GAP_CLOSE:
			return distance <= float(profile.gap_close_max_dist)
		VARIANT_RANGED_SNIPE:
			return distance >= float(profile.ranged_snipe_min_dist)
		_:
			return false


static func _attack_for_variant(profile: Resource, variant: StringName) -> Dictionary:
	var base: Dictionary
	var override: Dictionary
	match variant:
		VARIANT_AOE_BURST:
			base = DEFAULT_AOE_BURST.duplicate(true)
			override = Dictionary(profile.aoe_burst)
		VARIANT_RANGED_SNIPE:
			base = DEFAULT_RANGED_SNIPE.duplicate(true)
			override = Dictionary(profile.ranged_snipe)
		_:
			base = DEFAULT_GAP_CLOSE.duplicate(true)
			override = Dictionary(profile.gap_close)
	for key in override.keys():
		base[key] = override[key]
	return base


static func _apply_content_override(profile: Resource, content: Dictionary) -> void:
	# 章节 boss 字典可选 healing_punish 块做数据驱动覆盖
	if content.is_empty():
		return
	var block = content.get("healing_punish", {})
	if not block is Dictionary or block.is_empty():
		return
	if block.has("cooldown_sec"):
		profile.cooldown_sec = float(block["cooldown_sec"])
	if block.has("windup_scale"):
		profile.windup_scale = float(block["windup_scale"])
	if block.has("gap_close_max_dist"):
		profile.gap_close_max_dist = float(block["gap_close_max_dist"])
	if block.has("ranged_snipe_min_dist"):
		profile.ranged_snipe_min_dist = float(block["ranged_snipe_min_dist"])
	if block.has("aoe_burst_max_dist"):
		profile.aoe_burst_max_dist = float(block["aoe_burst_max_dist"])
	if block.has("aoe_min_phase"):
		profile.aoe_min_phase = int(block["aoe_min_phase"])
	if block.has("prefer_variants"):
		var arr: PackedStringArray = PackedStringArray()
		for item in block["prefer_variants"]:
			arr.append(String(item))
		profile.prefer_variants = arr
	if block.has("gap_close") and block["gap_close"] is Dictionary:
		profile.gap_close = Dictionary(block["gap_close"])
	if block.has("ranged_snipe") and block["ranged_snipe"] is Dictionary:
		profile.ranged_snipe = Dictionary(block["ranged_snipe"])
	if block.has("aoe_burst") and block["aoe_burst"] is Dictionary:
		profile.aoe_burst = Dictionary(block["aoe_burst"])


static func _make_default_for(boss_id: String) -> Resource:
	match boss_id:
		"boss_xing_tian", "xing_tian":
			return _make_xing_tian()
		"boss_nine_tails", "nine_tails":
			return _make_nine_tails()
		"boss_xuan_xiao", "xuan_xiao":
			return _make_xuan_xiao()
		"boss_zhu_yin", "zhu_yin":
			return _make_zhu_yin()
		"cinder_guardian", "guardian", "boss_giant_gate", "":
			return _make_giant_gate()
		_:
			return _make_giant_gate()


static func _make_giant_gate() -> Resource:
	# 巨阙：三角色齐全，二阶段起近距 AoE
	var p = ProfileScript.new()
	p.boss_id = &"boss_giant_gate"
	p.cooldown_sec = 2.4
	p.windup_scale = 0.68
	p.gap_close_max_dist = 5.5
	p.ranged_snipe_min_dist = 5.0
	p.aoe_burst_max_dist = 4.0
	p.aoe_min_phase = 2
	p.prefer_variants = PackedStringArray()
	p.gap_close = {
		"windup": 0.40, "active": 0.22, "recovery": 0.50,
		"damage": 30.0, "stagger": 36.0, "lunge": 5.0, "heavy": true,
	}
	p.ranged_snipe = {
		"windup": 0.52, "active": 0.30, "recovery": 0.70,
		"damage": 38.0, "stagger": 42.0, "lunge": 5.4, "heavy": true,
	}
	p.aoe_burst = {
		"windup": 0.36, "active": 0.24, "recovery": 0.90,
		"damage": 32.0, "stagger": 38.0, "lunge": 0.0, "heavy": true,
		"aoe_radius": 4.8,
	}
	return p


static func _make_xing_tian() -> Resource:
	# 刑天：偏好冲脸 gap-close
	var p = ProfileScript.new()
	p.boss_id = &"boss_xing_tian"
	p.cooldown_sec = 2.0
	p.windup_scale = 0.62
	p.gap_close_max_dist = 7.0
	p.ranged_snipe_min_dist = 6.5
	p.aoe_burst_max_dist = 3.5
	p.aoe_min_phase = 2
	p.prefer_variants = PackedStringArray(["gap_close", "aoe_burst", "ranged_snipe"])
	p.gap_close = {
		"windup": 0.34, "active": 0.24, "recovery": 0.55,
		"damage": 34.0, "stagger": 40.0, "lunge": 6.2, "heavy": true,
	}
	p.ranged_snipe = DEFAULT_RANGED_SNIPE.duplicate(true)
	p.aoe_burst = {
		"windup": 0.40, "active": 0.20, "recovery": 0.80,
		"damage": 28.0, "stagger": 34.0, "lunge": 0.0, "heavy": true,
		"aoe_radius": 4.0,
	}
	return p


static func _make_nine_tails() -> Resource:
	# 九尾：偏好远距 snipe（为后续投射铺垫）
	var p = ProfileScript.new()
	p.boss_id = &"boss_nine_tails"
	p.cooldown_sec = 2.2
	p.windup_scale = 0.70
	p.gap_close_max_dist = 4.5
	p.ranged_snipe_min_dist = 3.8
	p.aoe_burst_max_dist = 3.8
	p.aoe_min_phase = 2
	p.prefer_variants = PackedStringArray(["ranged_snipe", "aoe_burst", "gap_close"])
	p.gap_close = DEFAULT_GAP_CLOSE.duplicate(true)
	p.ranged_snipe = {
		"windup": 0.48, "active": 0.26, "recovery": 0.65,
		"damage": 34.0, "stagger": 38.0, "lunge": 4.8, "heavy": true,
	}
	p.aoe_burst = {
		"windup": 0.42, "active": 0.22, "recovery": 0.88,
		"damage": 26.0, "stagger": 30.0, "lunge": 0.0, "heavy": true,
		"aoe_radius": 4.2,
	}
	return p


static func _make_xuan_xiao() -> Resource:
	# 玄霄：偏好 AoE burst
	var p = ProfileScript.new()
	p.boss_id = &"boss_xuan_xiao"
	p.cooldown_sec = 2.6
	p.windup_scale = 0.72
	p.gap_close_max_dist = 5.0
	p.ranged_snipe_min_dist = 5.5
	p.aoe_burst_max_dist = 5.5
	p.aoe_min_phase = 1
	p.prefer_variants = PackedStringArray(["aoe_burst", "gap_close", "ranged_snipe"])
	p.gap_close = DEFAULT_GAP_CLOSE.duplicate(true)
	p.ranged_snipe = DEFAULT_RANGED_SNIPE.duplicate(true)
	p.aoe_burst = {
		"windup": 0.44, "active": 0.28, "recovery": 1.0,
		"damage": 36.0, "stagger": 42.0, "lunge": 0.0, "heavy": true,
		"aoe_radius": 5.5,
	}
	return p


static func _make_zhu_yin() -> Resource:
	# 烛阴：均衡三角色
	var p = ProfileScript.new()
	p.boss_id = &"boss_zhu_yin"
	p.cooldown_sec = 2.5
	p.windup_scale = 0.66
	p.gap_close_max_dist = 5.2
	p.ranged_snipe_min_dist = 4.8
	p.aoe_burst_max_dist = 4.2
	p.aoe_min_phase = 2
	p.prefer_variants = PackedStringArray()
	p.gap_close = DEFAULT_GAP_CLOSE.duplicate(true)
	p.ranged_snipe = DEFAULT_RANGED_SNIPE.duplicate(true)
	p.aoe_burst = DEFAULT_AOE_BURST.duplicate(true)
	return p
