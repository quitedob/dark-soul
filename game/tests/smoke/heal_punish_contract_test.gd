# game/tests/smoke/heal_punish_contract_test.gd
extends SceneTree
## G-02 合约：治疗惩罚变体选择 + Profile 校验

const Catalog = preload("res://scripts/boss/healing_punish_catalog.gd")
const Defaults = preload("res://resources/boss/heal_punish_defaults.gd")

var _failures: Array[String] = []


func _init() -> void:
	_test_profiles_valid()
	_test_variant_selection()
	_test_content_override()
	_test_boss_preferences()
	if _failures.is_empty():
		print("ASHEN_HEAL_PUNISH_CONTRACTS_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _test_profiles_valid() -> void:
	var profiles: Array = Defaults.all()
	_expect(profiles.size() >= 5, "Expected 5 boss heal-punish profiles.")
	for p in profiles:
		var errs: Array = p.validate()
		_expect(errs.is_empty(), "Invalid profile %s: %s" % [p.boss_id, str(errs)])


func _test_variant_selection() -> void:
	var p = Catalog.profile_for("boss_giant_gate", {})
	# 远距 → ranged_snipe
	var far: Dictionary = Catalog.resolve(p, 8.0, 1)
	_expect(String(far["variant"]) == "ranged_snipe", "Far distance should snipe, got %s" % far.get("variant"))
	_expect(float(far["lunge"]) > 3.0, "Snipe should keep gap-closing lunge.")
	# 中距 phase1 → gap_close（AoE 需 phase>=2）
	var mid: Dictionary = Catalog.resolve(p, 3.5, 1)
	_expect(String(mid["variant"]) == "gap_close", "Mid/P1 should gap_close, got %s" % mid.get("variant"))
	# 近距 phase2 → aoe_burst
	var close: Dictionary = Catalog.resolve(p, 2.5, 2)
	_expect(String(close["variant"]) == "aoe_burst", "Close/P2 should aoe_burst, got %s" % close.get("variant"))
	_expect(float(close["aoe_radius"]) > 0.0, "AoE burst needs aoe_radius.")
	_expect(float(close["lunge"]) == 0.0, "AoE burst should not lunge.")


func _test_content_override() -> void:
	var content := {
		"healing_punish": {
			"cooldown_sec": 1.5,
			"prefer_variants": ["gap_close"],
			"gap_close": {"damage": 99.0, "lunge": 7.0},
		}
	}
	var p = Catalog.profile_for("boss_giant_gate", content)
	_expect(is_equal_approx(float(p.cooldown_sec), 1.5), "Override cooldown_sec failed.")
	var resolved: Dictionary = Catalog.resolve(p, 8.0, 1)
	# prefer gap_close 但远距不允许 → 回退自动选 snipe
	_expect(String(resolved["variant"]) == "ranged_snipe", "Illegal prefer should fall through to auto.")
	var near: Dictionary = Catalog.resolve(p, 3.0, 1)
	_expect(String(near["variant"]) == "gap_close", "Prefer gap_close at mid range.")
	_expect(is_equal_approx(float(near["damage"]), 99.0), "gap_close damage override missing.")


func _test_boss_preferences() -> void:
	# 刑天偏好冲脸
	var xt = Catalog.profile_for("boss_xing_tian", {})
	var xt_r: Dictionary = Catalog.resolve(xt, 4.0, 1)
	_expect(String(xt_r["variant"]) == "gap_close", "Xing Tian should prefer gap_close.")
	# 九尾偏好远击
	var nt = Catalog.profile_for("boss_nine_tails", {})
	var nt_r: Dictionary = Catalog.resolve(nt, 4.5, 1)
	_expect(String(nt_r["variant"]) == "ranged_snipe", "Nine Tails should prefer ranged_snipe.")
	# 玄霄偏好 AoE（phase1 即允许）
	var xx = Catalog.profile_for("boss_xuan_xiao", {})
	var xx_r: Dictionary = Catalog.resolve(xx, 3.0, 1)
	_expect(String(xx_r["variant"]) == "aoe_burst", "Xuan Xiao should prefer aoe_burst at P1.")
