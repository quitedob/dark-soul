extends SceneTree
## B-05 / B-07：蓄力档位 + grip Moveset 合约

const PlayerScript = preload("res://scripts/player/player.gd")
const Factory = preload("res://scripts/combat/data/compatibility_moveset_factory.gd")

var _failures: Array[String] = []


func _init() -> void:
	_test_weapons_validate()
	_test_charge_tiers()
	_test_grip_cycle_and_stats()
	_test_no_crit_doubling_on_two_hand()
	_test_jump_slash_requires_matched_types()
	if _failures.is_empty():
		print("ASHEN_GRIP_CHARGE_CONTRACTS_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_weapons_validate() -> void:
	for style_id in PlayerScript.STYLE_RESOURCES:
		var weapon: WeaponData = Factory.create_weapon(PlayerScript.STYLE_RESOURCES[style_id])
		_expect(weapon.validate().is_empty(), "Weapon %s invalid: %s" % [weapon.weapon_id, str(weapon.validate())])
		_expect(not weapon.supported_grips().is_empty(), "Weapon %s has no grips." % weapon.weapon_id)
		var moveset := weapon.resolve_moveset(weapon.default_grip)
		_expect(moveset != null and moveset.charged_heavy != null, "Default moveset missing charge for %s" % weapon.weapon_id)


func _test_charge_tiers() -> void:
	var style: CombatStyleData = PlayerScript.STYLE_RESOURCES[PlayerScript.CombatStyle.RELIQUARY_GUARD]
	var moveset := Factory.create(style, &"one_handed")
	var profile: ChargeProfile = moveset.charged_heavy
	_expect(profile != null, "Charge profile missing.")
	var t1 := profile.resolve(0.25)
	var t2 := profile.resolve(0.8)
	var t3 := profile.resolve(1.5)
	_expect(t1 != null and t2 != null and t3 != null, "Charge tiers unresolved.")
	_expect(t2.damage > t1.damage, "Tier2 should hit harder than tier1.")
	_expect(t3.damage > t2.damage, "Tier3 should hit harder than tier2.")
	_expect(&"charged" in t2.tags, "Charged attack missing charged tag.")


func _test_grip_cycle_and_stats() -> void:
	var style: CombatStyleData = PlayerScript.STYLE_RESOURCES[PlayerScript.CombatStyle.RELIQUARY_GUARD]
	var weapon := Factory.create_weapon(style)
	_expect(weapon.supports_two_handed, "Guard must support two-hand.")
	var one := weapon.resolve_moveset(&"one_handed")
	var two := weapon.resolve_moveset(&"two_handed")
	_expect(is_equal_approx(two.neutral_heavy.damage / one.neutral_heavy.damage, 1.3), "Two-hand damage must be 1.3x.")
	_expect(is_equal_approx(two.neutral_heavy.stamina_cost / one.neutral_heavy.stamina_cost, 1.5), "Two-hand stamina must be 1.5x.")
	_expect(weapon.cycle_grip(&"one_handed") == &"two_handed", "Guard grip cycle one→two failed.")
	_expect(weapon.cycle_grip(&"two_handed") == &"one_handed", "Guard grip cycle two→one failed.")
	var twin := Factory.create_weapon(PlayerScript.STYLE_RESOURCES[PlayerScript.CombatStyle.TWIN_COLOSSI])
	_expect(twin.default_grip == &"paired", "Twin default grip should be paired.")
	_expect(twin.supports_paired and twin.supports_one_handed, "Twin should support paired+one.")


func _test_no_crit_doubling_on_two_hand() -> void:
	# 双持不得直接把 critical_multiplier 翻倍
	var weapon := Factory.create_weapon(PlayerScript.STYLE_RESOURCES[PlayerScript.CombatStyle.RELIQUARY_GUARD])
	_expect(is_equal_approx(weapon.critical_multiplier, 1.0), "Two-hand support must not auto-double crit multiplier.")


func _test_jump_slash_requires_matched_types() -> void:
	const HandEq = preload("res://scripts/data/hand_equipment.gd")
	# 剑+盾：不同类型，单持不可跳劈；双持可
	_expect(not HandEq.can_jump_slash("guardian_sword", "reliquary_shield", &"one_handed"), "Sword+shield one-hand must block jump slash.")
	_expect(HandEq.can_jump_slash("guardian_sword", "reliquary_shield", &"two_handed"), "Two-hand sword may jump slash.")
	# 双斧同类型：成对可跳劈；弓+匕不同类不可
	_expect(HandEq.can_jump_slash("xingtian_axe_right", "xingtian_axe_left", &"paired"), "Matched axes may jump slash.")
	_expect(not HandEq.can_jump_slash("marksman_bow", "marksman_dagger", &"one_handed"), "Bow+dagger must block jump slash.")
	_expect(HandEq.get_weapon_type("xingtian_axe_right") == &"axe", "Right axe type missing.")
	_expect(HandEq.get_weapon_type("xingtian_axe_left") == &"axe", "Left axe type missing.")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
