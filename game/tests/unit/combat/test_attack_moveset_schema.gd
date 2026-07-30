extends "res://addons/gut/test.gd"

const PlayerScript = preload("res://scripts/player/player.gd")
const Factory = preload("res://scripts/combat/data/compatibility_moveset_factory.gd")
const Verifier = preload("res://scripts/tools/verify_combat_resource_schema.gd")

## A-05 要求注册的核心 class_name
const REQUIRED_CLASSES := [
	"AttackData",
	"ChargeProfile",
	"MovesetData",
	"WeaponData",
	"WeaponArtData",
	"GuardProfile",
	"ExecutionProfile",
	"GrabProfile",
]


func test_combat_resource_class_names_are_registered() -> void:
	# 全局类表必须含 AttackData / MovesetData 等
	var registered := {}
	for info in ProjectSettings.get_global_class_list():
		registered[String(info.get("class", ""))] = String(info.get("path", ""))
	for class_id in REQUIRED_CLASSES:
		assert_true(registered.has(class_id), "Missing class_name registration: %s" % class_id)
		assert_eq(
			registered[class_id],
			Verifier.REQUIRED_CLASS_PATHS[class_id],
			"Unexpected script path for %s" % class_id
		)


func test_combat_resource_schema_verifier_pipeline() -> void:
	# 复用 A-05 校验工具：注册 + 实例化 + 兼容武器 + 作者化 tres
	var failures: Array[String] = Verifier.run()
	assert_true(failures.is_empty(), "Schema pipeline failures: %s" % str(failures))


func test_authored_reliquary_weapon_roundtrip() -> void:
	# .tres 必须以 WeaponData / MovesetData 反序列化
	var weapon = load(Verifier.AUTHORED_WEAPON_PATH)
	assert_true(weapon is WeaponData, "Authored weapon must be WeaponData.")
	assert_true(weapon.validate().is_empty(), "Authored weapon validate failed.")
	for path in Verifier.AUTHORED_MOVESET_PATHS:
		var moveset = load(path)
		assert_true(moveset is MovesetData, "%s must be MovesetData." % path)
		assert_true(moveset.validate().is_empty(), "%s validate failed." % path)
		assert_ne(moveset.charged_heavy, null, "%s missing ChargeProfile." % path)


func test_all_compatibility_movesets_validate() -> void:
	for style_id in PlayerScript.STYLE_RESOURCES:
		var style: CombatStyleData = PlayerScript.STYLE_RESOURCES[style_id]
		var moveset := Factory.create(style)
		assert_true(moveset.validate().is_empty(), "Moveset %s must validate." % moveset.moveset_id)
		assert_eq(moveset.neutral_light.stamina_cost, style.stamina_light)
		assert_eq(moveset.neutral_heavy.stamina_cost, style.stamina_heavy)
		assert_eq(moveset.neutral_light.damage, style.damage_light)
		assert_eq(moveset.neutral_heavy.damage, style.damage_heavy)


func test_attack_validation_rejects_conflicting_tags() -> void:
	var attack := AttackData.new()
	attack.action_id = &"invalid"
	attack.tags = [&"unblockable"]
	attack.blockable = true
	assert_false(attack.validate().is_empty())


func test_moveset_context_resolution_is_explicit() -> void:
	var style: CombatStyleData = PlayerScript.STYLE_RESOURCES[PlayerScript.CombatStyle.TWIN_COLOSSI]
	var moveset := Factory.create(style)
	assert_eq(moveset.resolve(&"neutral_light"), moveset.neutral_light)
	assert_eq(moveset.resolve(&"neutral_heavy"), moveset.neutral_heavy)
	assert_eq(moveset.resolve(&"jump"), moveset.jump_attack)
	assert_eq(moveset.resolve(&"sprint"), moveset.sprint_attack)
	assert_eq(moveset.resolve(&"roll_recovery"), moveset.roll_attack)
	assert_eq(moveset.resolve(&"backstep_recovery"), moveset.backstep_attack)
	assert_eq(moveset.resolve(&"falling"), moveset.falling_attack)
	assert_eq(moveset.resolve(&"leap"), moveset.weapon_art_heavy)


func test_jump_attack_is_not_leap_weapon_art() -> void:
	var style: CombatStyleData = PlayerScript.STYLE_RESOURCES[PlayerScript.CombatStyle.TWIN_COLOSSI]
	var moveset := Factory.create(style)
	assert_ne(moveset.jump_attack, null)
	assert_false(&"leap" in moveset.jump_attack.tags, "General jump must not carry leap tag.")
	assert_true(&"jump" in moveset.jump_attack.tags)
	assert_ne(moveset.weapon_art_heavy, null)
	assert_true(&"leap" in moveset.weapon_art_heavy.tags)
	assert_ne(moveset.jump_attack.action_id, moveset.weapon_art_heavy.action_id)


func test_jump_and_falling_use_distinct_hitboxes() -> void:
	var moveset := Factory.create(PlayerScript.STYLE_RESOURCES[PlayerScript.CombatStyle.RELIQUARY_GUARD])
	assert_true(moveset.falling_attack.hitbox_until_land)
	assert_gt(moveset.falling_attack.hitbox_height, moveset.neutral_heavy.hitbox_height)
	assert_eq(moveset.jump_attack.hitbox_socket, &"weapon_tip")
	assert_eq(moveset.falling_attack.hitbox_socket, &"")
	assert_lt(moveset.falling_attack.hitbox_offset.y, moveset.jump_attack.hitbox_offset.y)
	var meta := moveset.jump_attack.to_hit_metadata("guardian_sword")
	assert_true(meta.has("hitbox_radius"))
	assert_eq(String(meta.get("hitbox_socket", "")), "weapon_tip")
	assert_false(meta.get("hitbox_until_land", true))
	var fall_meta := moveset.falling_attack.to_hit_metadata("guardian_sword")
	assert_true(fall_meta.get("hitbox_until_land", false))

	for style_id in PlayerScript.STYLE_RESOURCES:
		var style_moveset := Factory.create(PlayerScript.STYLE_RESOURCES[style_id])
		assert_ne(style_moveset.sprint_attack, null, "Missing sprint for %s" % style_moveset.moveset_id)
		assert_ne(style_moveset.roll_attack, null, "Missing roll for %s" % style_moveset.moveset_id)
		assert_ne(style_moveset.backstep_attack, null, "Missing backstep for %s" % style_moveset.moveset_id)
		assert_ne(style_moveset.jump_attack, null, "Missing jump for %s" % style_moveset.moveset_id)
		assert_ne(style_moveset.falling_attack, null, "Missing falling for %s" % style_moveset.moveset_id)
		assert_true(&"falling" in style_moveset.falling_attack.tags)
		assert_true(style_moveset.falling_attack.launch_velocity_y < 0.0)
		assert_eq(style_moveset.jump_attack.hitbox_socket, &"weapon_tip")


func test_charge_profile_and_weapon_grips() -> void:
	var style: CombatStyleData = PlayerScript.STYLE_RESOURCES[PlayerScript.CombatStyle.RELIQUARY_GUARD]
	var weapon := Factory.create_weapon(style)
	assert_true(weapon.validate().is_empty())
	assert_true(weapon.supports_two_handed)
	var one := weapon.resolve_moveset(&"one_handed")
	var two := weapon.resolve_moveset(&"two_handed")
	assert_almost_eq(two.neutral_heavy.damage / one.neutral_heavy.damage, 1.3, 0.001)
	assert_almost_eq(two.neutral_heavy.stamina_cost / one.neutral_heavy.stamina_cost, 1.5, 0.001)
	assert_ne(one.charged_heavy, null)
	assert_gt(one.charged_heavy.resolve(1.5).damage, one.charged_heavy.resolve(0.3).damage)
	var twin := Factory.create_weapon(PlayerScript.STYLE_RESOURCES[PlayerScript.CombatStyle.TWIN_COLOSSI])
	assert_eq(twin.default_grip, &"paired")
	assert_eq(twin.cycle_grip(&"paired"), &"one_handed")
	const HandEq = preload("res://scripts/data/hand_equipment.gd")
	assert_true(HandEq.can_jump_slash("xingtian_axe_right", "xingtian_axe_left", &"paired"))
	assert_false(HandEq.can_jump_slash("guardian_sword", "reliquary_shield", &"one_handed"))
	assert_true(HandEq.can_jump_slash("guardian_sword", "reliquary_shield", &"two_handed"))


func test_combat_area_supports_motion_cast_sampling() -> void:
	var area = preload("res://scripts/combat_area.gd").new()
	area.configure(null, 1.25, 1.45)
	area._ready()
	assert_true(area.uses_motion_cast, "CombatArea should initialize ShapeCast motion sampling.")
	assert_true(area.has_method("_sample_motion_hits"), "CombatArea should expose motion hit sampling.")
	assert_true(area.has_method("set_socket_follow"), "CombatArea should support weapon tip follow.")
	area.free()
