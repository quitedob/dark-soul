extends SceneTree
## C-05：武器拖尾按重量档 / 风格色变化的 headless 合约

const WeaponTrailProfileScript = preload("res://scripts/fx/weapon_trail_profile.gd")
const TraumaShakeScript = preload("res://scripts/components/trauma_shake.gd")

var _failures: Array[String] = []


func _init() -> void:
	_test_weight_profiles_differ()
	_test_style_color_affects_base()
	_test_weight_resolver_aligns_c03()
	if _failures.is_empty():
		print("ASHEN_WEAPON_TRAIL_CONTRACTS_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


## 三档宽/alpha/emission 必须可区分
func _test_weight_profiles_differ() -> void:
	var light: Dictionary = WeaponTrailProfileScript.resolve(&"light")
	var heavy: Dictionary = WeaponTrailProfileScript.resolve(&"heavy")
	var boom: Dictionary = WeaponTrailProfileScript.resolve(&"explosion")
	_expect(float(heavy["width"]) > float(light["width"]), "Heavy trail should be wider than light.")
	_expect(float(boom["width"]) > float(heavy["width"]), "Explosion trail should be wider than heavy.")
	_expect(float(heavy["alpha"]) > float(light["alpha"]), "Heavy trail alpha should exceed light.")
	_expect(float(boom["emission"]) > float(heavy["emission"]), "Explosion emission should exceed heavy.")
	_expect(not Color(light["color"]).is_equal_approx(Color(heavy["color"])), "Light/heavy trail colors should differ.")


## 风格 trail_color 影响基色（非 WHITE 回退）
func _test_style_color_affects_base() -> void:
	var blue := Color(0.3, 0.55, 1.0, 1.0)
	var orange := Color(0.9, 0.4, 0.1, 1.0)
	var from_blue: Dictionary = WeaponTrailProfileScript.resolve(&"heavy", blue)
	var from_orange: Dictionary = WeaponTrailProfileScript.resolve(&"heavy", orange)
	_expect(not Color(from_blue["color"]).is_equal_approx(Color(from_orange["color"])), "Style trail_color should tint ribbon.")
	# 蓝风格的 R 通道应低于橙风格
	_expect(Color(from_blue["color"]).r < Color(from_orange["color"]).r, "Blue style should keep cooler red channel.")


## 与 C-03 TraumaShake.resolve_weight 对齐
func _test_weight_resolver_aligns_c03() -> void:
	_expect(
		WeaponTrailProfileScript.resolve_weight_from_attack(false, [], "sword_light") == &"light",
		"Light attack should map to light trail weight."
	)
	_expect(
		WeaponTrailProfileScript.resolve_weight_from_attack(true, [&"heavy"], "sword_heavy") == &"heavy",
		"Heavy attack should map to heavy trail weight."
	)
	_expect(
		WeaponTrailProfileScript.resolve_weight_from_attack(true, [&"leap"], "colossal_leap") == &"explosion",
		"Leap tags should map to explosion trail weight."
	)
	_expect(
		TraumaShakeScript.resolve_weight(true, [&"leap"], "colossal_leap")
		== WeaponTrailProfileScript.resolve_weight_from_attack(true, [&"leap"], "colossal_leap"),
		"Trail weight resolver must match TraumaShake C-03."
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
