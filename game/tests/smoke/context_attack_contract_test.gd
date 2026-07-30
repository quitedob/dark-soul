extends SceneTree
## 语境攻击合约：招式工厂填充 + leap/jump 分离 + 低扫标签

const PlayerScript = preload("res://scripts/player/player.gd")
const Factory = preload("res://scripts/combat/data/compatibility_moveset_factory.gd")

var _failures: Array[String] = []


func _init() -> void:
	_test_context_slots_filled()
	_test_leap_separated_from_jump()
	_test_falling_launch()
	_test_hit_metadata_fields()
	if _failures.is_empty():
		print("ASHEN_CONTEXT_ATTACK_CONTRACTS_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_context_slots_filled() -> void:
	for style_id in PlayerScript.STYLE_RESOURCES:
		var moveset := Factory.create(PlayerScript.STYLE_RESOURCES[style_id])
		_expect(moveset.sprint_attack != null, "sprint missing for style %s" % style_id)
		_expect(moveset.roll_attack != null, "roll missing for style %s" % style_id)
		_expect(moveset.backstep_attack != null, "backstep missing for style %s" % style_id)
		_expect(moveset.jump_attack != null, "jump missing for style %s" % style_id)
		_expect(moveset.falling_attack != null, "falling missing for style %s" % style_id)
		_expect(moveset.validate().is_empty(), "moveset invalid for style %s" % style_id)


func _test_leap_separated_from_jump() -> void:
	var twin := Factory.create(PlayerScript.STYLE_RESOURCES[PlayerScript.CombatStyle.TWIN_COLOSSI])
	_expect(twin.jump_attack != null and not (&"leap" in twin.jump_attack.tags), "jump must not be leap.")
	_expect(twin.weapon_art_heavy != null and &"leap" in twin.weapon_art_heavy.tags, "leap must live on weapon_art_heavy.")
	var guard := Factory.create(PlayerScript.STYLE_RESOURCES[PlayerScript.CombatStyle.RELIQUARY_GUARD])
	_expect(guard.weapon_art_heavy == null, "non-leap styles must not invent leap arts.")
	_expect(guard.jump_attack != null and &"jump" in guard.jump_attack.tags, "guard still needs general jump.")


func _test_falling_launch() -> void:
	var moveset := Factory.create(PlayerScript.STYLE_RESOURCES[PlayerScript.CombatStyle.RELIQUARY_GUARD])
	_expect(moveset.falling_attack.launch_velocity_y < -1.0, "falling attack needs downward launch.")
	_expect(&"plunge" in moveset.falling_attack.tags or &"falling" in moveset.falling_attack.tags, "falling tags missing.")
	_expect(moveset.falling_attack.hitbox_until_land, "falling must keep hitbox until land.")
	_expect(moveset.falling_attack.hitbox_height > moveset.jump_attack.hitbox_height, "falling hitbox should be taller than jump.")
	_expect(moveset.jump_attack.hitbox_socket == &"weapon_tip", "jump hitbox must follow weapon tip.")
	_expect(moveset.falling_attack.hitbox_socket == &"", "falling hitbox stays on player root.")
	_expect(moveset.falling_attack.hitbox_offset.y < moveset.jump_attack.hitbox_offset.y, "falling hitbox sits lower than tip.")


func _test_hit_metadata_fields() -> void:
	var moveset := Factory.create(PlayerScript.STYLE_RESOURCES[PlayerScript.CombatStyle.RELIQUARY_GUARD])
	var jump_meta := moveset.jump_attack.to_hit_metadata("guardian_sword")
	var fall_meta := moveset.falling_attack.to_hit_metadata("guardian_sword")
	_expect(jump_meta.has("hitbox_radius") and jump_meta.has("hitbox_height"), "jump metadata missing hitbox size.")
	_expect(jump_meta.get("hitbox_socket", "") == "weapon_tip", "jump metadata missing weapon tip socket.")
	_expect(fall_meta.get("hitbox_until_land", false), "falling metadata must include hitbox_until_land.")
	var area = preload("res://scripts/combat_area.gd").new()
	area.configure(null, 1.25, 1.45)
	area._ready()
	_expect(area.uses_motion_cast, "CombatArea must initialize motion ShapeCast.")
	_expect(area.has_method("set_socket_follow"), "CombatArea must support socket follow.")
	area.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
