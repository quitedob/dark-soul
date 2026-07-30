class_name GuardResolver
extends RefCounted


static func resolve(
		payload: Dictionary,
		guard_active: bool,
		defender_forward: Vector3,
		available_stamina: float,
		guard_profile: Dictionary
) -> Dictionary:
	var result := {
		"guarded": false,
		"guard_broken": false,
		"damage": maxf(float(payload.get("damage", 0.0)), 0.0),
		"stagger": maxf(float(payload.get("stagger", payload.get("poise", 0.0))), 0.0),
		"stamina_cost": 0.0,
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
	var guard_damage := maxf(float(payload.get("guard_damage", result["damage"])), 0.0)
	var stamina_cost := guard_damage * (1.0 - stability)
	result["guarded"] = true
	result["stamina_cost"] = minf(stamina_cost, available_stamina)
	if available_stamina + 0.001 >= stamina_cost:
		result["damage"] = float(result["damage"]) * (1.0 - absorption)
		result["stagger"] = 0.0
	else:
		result["guard_broken"] = true
		result["damage"] = float(result["damage"]) * maxf(1.0 - absorption * 0.35, 0.5)
		result["stagger"] = maxf(float(result["stagger"]), 36.0)
	return result
