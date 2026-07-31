# game/scripts/fx/weapon_trail_profile.gd
class_name WeaponTrailProfile
extends RefCounted
## C-05：按攻击重量档解析拖尾色/宽/发光（对齐 TraumaShake 三档）

const DEFAULT_BASE := Color(1.0, 0.85, 0.5, 1.0)

## light / heavy / explosion → 宽度、峰值 alpha、emission
const PROFILE_BY_WEIGHT := {
	&"light": {"width": 0.05, "alpha": 0.35, "emission": 1.0, "tint": Color(0.92, 0.95, 1.0)},
	&"heavy": {"width": 0.09, "alpha": 0.55, "emission": 1.6, "tint": Color(1.0, 0.88, 0.55)},
	&"explosion": {"width": 0.14, "alpha": 0.75, "emission": 2.2, "tint": Color(1.0, 0.55, 0.2)},
}


## 解析档位对应的拖尾参数字典
static func resolve(weight: StringName, style_trail_color: Color = Color.WHITE) -> Dictionary:
	var key := weight if PROFILE_BY_WEIGHT.has(weight) else &"light"
	var row: Dictionary = PROFILE_BY_WEIGHT[key]
	var base := style_trail_color
	# 未配置风格色时回退暖金
	if base.is_equal_approx(Color.WHITE) or base.a <= 0.001:
		base = DEFAULT_BASE
	var tint: Color = row["tint"]
	var mixed := Color(base.r * tint.r, base.g * tint.g, base.b * tint.b, 1.0)
	return {
		"weight": key,
		"width": float(row["width"]),
		"alpha": float(row["alpha"]),
		"emission": float(row["emission"]),
		"color": mixed,
	}


## 从玩家攻击字段解析重量档（供 visuals / 合约复用）
static func resolve_weight_from_attack(is_heavy: bool, tags: Array = [], action_id: String = "") -> StringName:
	return TraumaShake.resolve_weight(is_heavy, tags, action_id)
