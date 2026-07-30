extends SceneTree

const HandEquipmentScript = preload("res://scripts/data/hand_equipment.gd")
const PlayerScript = preload("res://scripts/player/player.gd")
const GuardResolverScript = preload("res://scripts/combat/guard_resolver.gd")
const CombatAreaScript = preload("res://scripts/combat_area.gd")
const ProjectileScript = preload("res://scripts/components/spell_projectile.gd")

var _failures: Array[String] = []


func _init() -> void:
	_test_hand_mappings()
	_test_stamina_matrix()
	_test_parry_profiles()
	_test_guard_resolution()
	_test_payload_builders()
	if _failures.is_empty():
		print("ASHEN_COMBAT_CONTRACTS_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_hand_mappings() -> void:
	var expected := [
		["guardian_sword", "reliquary_shield"],
		["xingtian_axe_right", "xingtian_axe_left"],
		["marksman_bow", "marksman_dagger"],
		["five_elements_seal", "spirit_stone"],
		["prayer_beads", "talisman_papers"],
	]
	for style_id in range(expected.size()):
		var loadout: Dictionary = HandEquipmentScript.get_style_loadout(style_id)
		_expect(loadout["right_hand"] == expected[style_id][0], "Right-hand style mapping changed.")
		_expect(loadout["left_hand"] == expected[style_id][1], "Left-hand style mapping changed.")
	var labels := HandEquipmentScript.get_action_labels("guardian_sword", "reliquary_shield")
	_expect(labels["right_primary"] == "SWORD LIGHT", "Right primary label is not item-driven.")
	_expect(labels["left_secondary"] == "SHIELD PARRY", "Left secondary label is not item-driven.")


func _test_stamina_matrix() -> void:
	var expected := [
		[22.0, 40.0, 24.0],
		[38.0, 65.0, 32.0],
		[16.0, 28.0, 18.0],
		[0.0, 0.0, 22.0],
		[0.0, 0.0, 24.0],
	]
	for style_id in range(expected.size()):
		var profile: CombatStyleData = PlayerScript.STYLE_RESOURCES[style_id]
		_expect(profile != null, "Style %d resource did not load." % style_id)
		_expect(is_equal_approx(profile.stamina_light, expected[style_id][0]), "Style %d light stamina is incorrect." % style_id)
		_expect(is_equal_approx(profile.stamina_heavy, expected[style_id][1]), "Style %d heavy stamina is incorrect." % style_id)
		_expect(is_equal_approx(profile.stamina_dodge, expected[style_id][2]), "Style %d dodge stamina is incorrect." % style_id)


func _test_parry_profiles() -> void:
	var medium: Dictionary = HandEquipmentScript.get_item("reliquary_shield").get("parry", {})
	var buckler: Dictionary = HandEquipmentScript.get_item("jade_buckler").get("parry", {})
	var dagger: Dictionary = HandEquipmentScript.get_item("parry_dagger").get("parry", {})
	var fist: Dictionary = HandEquipmentScript.get_item("fist_guard").get("parry", {})
	_expect(not medium.is_empty() and not buckler.is_empty() and not dagger.is_empty() and not fist.is_empty(), "Parry equipment profiles are incomplete.")
	_expect(float(buckler.get("active", 0.0)) > float(medium.get("active", 0.0)), "Buckler active window is not wider than medium shield.")
	_expect(float(buckler.get("miss_penalty", 0.0)) > float(fist.get("miss_penalty", 0.0)), "Buckler miss penalty is not harsher than fist.")
	_expect(HandEquipmentScript.get_parry_feedback("jade_buckler")["cue"] == "parry_buckler", "Buckler feedback is not equipment-driven.")


func _test_guard_resolution() -> void:
	var profile: Dictionary = HandEquipmentScript.get_item("reliquary_shield")["guard"]
	var frontal := GuardResolverScript.resolve(
		{"damage": 40.0, "stagger": 30.0, "guard_damage": 40.0, "direction": Vector3.FORWARD, "blockable": true},
		true,
		Vector3.BACK,
		100.0,
		profile
	)
	_expect(frontal["guarded"], "Frontal shield hit was not guarded.")
	_expect(float(frontal["damage"]) < 10.0, "Frontal shield absorption was not applied.")
	_expect(is_zero_approx(float(frontal["stagger"])), "Successful guard did not zero stagger.")
	var rear := GuardResolverScript.resolve(
		{"damage": 40.0, "stagger": 30.0, "direction": Vector3.BACK, "blockable": true},
		true,
		Vector3.BACK,
		100.0,
		profile
	)
	_expect(not rear["guarded"] and is_equal_approx(float(rear["damage"]), 40.0), "Rear hit did not bypass guard.")
	var broken := GuardResolverScript.resolve(
		{"damage": 40.0, "stagger": 20.0, "guard_damage": 100.0, "direction": Vector3.FORWARD, "blockable": true},
		true,
		Vector3.BACK,
		1.0,
		profile
	)
	_expect(broken["guard_broken"], "Insufficient stamina did not break guard.")
	_expect(float(broken["stagger"]) >= 36.0, "Guard break did not force stagger.")
	var unblockable := GuardResolverScript.resolve(
		{"damage": 20.0, "direction": Vector3.FORWARD, "blockable": false},
		true,
		Vector3.BACK,
		100.0,
		profile
	)
	_expect(not unblockable["guarded"], "Unblockable payload was guarded.")


func _test_payload_builders() -> void:
	var area = CombatAreaScript.new()
	area.configure(null, 1.25, 1.45)
	area.begin_swing(18.0, 42.0, {
		"hand": "left",
		"item_id": "reliquary_shield",
		"action_id": "shield_bash",
		"guard_damage": 48.0,
		"hitbox_radius": 1.5,
		"hitbox_height": 2.0,
		"hitbox_offset": Vector3(0.0, 0.2, -0.4),
	})
	_expect(area.hit_payload["hand"] == "left", "Melee payload lost origin hand.")
	_expect(area.hit_payload["action_id"] == "shield_bash", "Melee payload lost action ID.")
	_expect(area.hit_payload.has("blockable") and area.hit_payload.has("parryable"), "Melee payload lacks combat flags.")
	_expect(is_equal_approx(area.position.y, 0.2), "CombatArea did not apply hitbox offset.")
	_expect(area.uses_motion_cast, "CombatArea must expose motion ShapeCast sampling.")
	area.end_swing()
	_expect(is_equal_approx(area.position.y, 1.0), "CombatArea did not reset default hitbox.")
	area.free()
	var projectile = ProjectileScript.new()
	projectile.setup(null, Vector3.FORWARD, 20.0, 10.0, {
		"hand": "right",
		"item_id": "marksman_bow",
		"action_id": "bow_quick_shot",
	})
	_expect(projectile.hit_payload["hand"] == "right", "Projectile payload lost origin hand.")
	_expect(projectile.hit_payload["item_id"] == "marksman_bow", "Projectile payload lost item ID.")
	_expect(projectile.hit_payload["tags"].has("projectile"), "Projectile payload lacks projectile tag.")
	projectile.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
