class_name GuardResolver
extends RefCounted
## 格挡结算：盾角、吸收、精力、Guard Meter、直接击穿


static func resolve(
		payload: Dictionary,
		guard_active: bool,
		defender_forward: Vector3,
		available_stamina: float,
		guard_profile: Dictionary,
		current_guard_meter: float = -1.0
) -> Dictionary:
	var result := {
		"guarded": false,
		"guard_broken": false,
		"guard_broken_reason": "",
		"damage": maxf(float(payload.get("damage", 0.0)), 0.0),
		"stagger": maxf(float(payload.get("stagger", payload.get("poise", 0.0))), 0.0),
		"stamina_cost": 0.0,
		"guard_meter_damage": 0.0,
		"guard_meter_remaining": current_guard_meter,
	}
	if not guard_active or guard_profile.is_empty() or not bool(payload.get("blockable", true)):
		return result

	var direction: Vector3 = payload.get("direction", Vector3.ZERO)
	var toward_source := -direction
	toward_source.y = 0.0
	var flat_forward := defender_forward
	flat_forward.y = 0.0
	if toward_source.length_squared() > 0.001 and flat_forward.length_squared() > 0.001:
		var front_dot := float(guard_profile.get("front_dot", 0.15))
		if flat_forward.normalized().dot(toward_source.normalized()) < front_dot:
			return result

	var absorption := clampf(float(guard_profile.get("absorption", 0.0)), 0.0, 1.0)
	var stability := clampf(float(guard_profile.get("stability", 0.0)), 0.0, 0.95)
	var guard_damage := maxf(
		float(payload.get("guard_damage", payload.get("guard_power", result["damage"]))),
		0.0
	)
	var stamina_mul := maxf(float(guard_profile.get("stamina_damage_multiplier", 1.0)), 0.0)
	var meter_mul := maxf(float(guard_profile.get("guard_meter_damage_multiplier", 1.0)), 0.0)
	var stamina_cost := guard_damage * (1.0 - stability) * stamina_mul
	var meter_damage := guard_damage * meter_mul
	var max_meter := maxf(float(guard_profile.get("max_guard_meter", 100.0)), 1.0)
	var meter := current_guard_meter if current_guard_meter >= 0.0 else max_meter
	var direct_break := maxf(float(guard_profile.get("direct_break_threshold", 75.0)), 0.0)

	result["guarded"] = true
	result["stamina_cost"] = minf(stamina_cost, maxf(available_stamina, 0.0))
	result["guard_meter_damage"] = meter_damage

	# 1) 单次冲击直接击穿
	if direct_break > 0.0 and guard_damage >= direct_break:
		return _break_result(result, absorption, "direct", maxf(meter - meter_damage, 0.0))

	# 2) Guard Meter 归零
	var meter_after := maxf(meter - meter_damage, 0.0)
	result["guard_meter_remaining"] = meter_after
	if meter_after <= 0.001:
		return _break_result(result, absorption, "meter", 0.0)

	# 3) 精力不足无法撑住
	if available_stamina + 0.001 < stamina_cost:
		return _break_result(result, absorption, "stamina", meter_after)

	result["damage"] = float(result["damage"]) * (1.0 - absorption)
	result["stagger"] = 0.0
	return result


static func _break_result(result: Dictionary, absorption: float, reason: String, meter_left: float) -> Dictionary:
	result["guard_broken"] = true
	result["guard_broken_reason"] = reason
	result["guard_meter_remaining"] = meter_left
	result["damage"] = float(result["damage"]) * maxf(1.0 - absorption * 0.35, 0.5)
	result["stagger"] = maxf(float(result["stagger"]), 36.0)
	return result


static func profile_from_resource(profile: Resource) -> Dictionary:
	if profile == null:
		return {}
	# 兼容 GuardProfile Resource 字段
	return {
		"absorption": float(profile.get("physical_absorption")),
		"stability": float(profile.get("stability")),
		"front_dot": cos(deg_to_rad(float(profile.get("guard_angle_degrees")) * 0.5)),
		"max_guard_meter": float(profile.get("max_guard_meter")),
		"direct_break_threshold": float(profile.get("direct_break_threshold")),
		"guard_meter_damage_multiplier": float(profile.get("guard_meter_damage_multiplier")),
		"stamina_damage_multiplier": float(profile.get("stamina_damage_multiplier")),
		"can_parry": bool(profile.get("can_parry")),
		"parry_start_seconds": float(profile.get("parry_start_seconds")),
		"parry_active_seconds": float(profile.get("parry_active_seconds")),
		"parry_recovery_seconds": float(profile.get("parry_recovery_seconds")),
		"parry_miss_multiplier": float(profile.get("parry_miss_multiplier")),
	}
