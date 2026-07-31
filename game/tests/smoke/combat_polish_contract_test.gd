extends SceneTree
## 取消窗 / WeaponArt / Reliquary authored / root-motion POC 合约

const Factory = preload("res://scripts/combat/data/compatibility_moveset_factory.gd")
const PlayerScript = preload("res://scripts/player/player.gd")
const AnimBridge = preload("res://scripts/combat/player_animation_bridge.gd")

var _failures: Array[String] = []


func _init() -> void:
	_test_dodge_cancel_matrix()
	_test_weapon_arts()
	_test_reliquary_authored()
	_test_root_motion_poc()
	if _failures.is_empty():
		print("ASHEN_COMBAT_POLISH_CONTRACTS_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_dodge_cancel_matrix() -> void:
	var twin := Factory.create(PlayerScript.STYLE_RESOURCES[PlayerScript.CombatStyle.TWIN_COLOSSI], &"paired")
	var crescent := Factory.create(PlayerScript.STYLE_RESOURCES[PlayerScript.CombatStyle.CRESCENT_PAIR], &"paired")
	_expect(twin.neutral_heavy.dodge_cancel_seconds < 0.0, "Twin must disable dodge cancel.")
	_expect(twin.neutral_light.dodge_cancel_seconds < 0.0, "Twin light must also disable dodge cancel.")
	_expect(crescent.neutral_light.dodge_cancel_seconds > 0.0, "Crescent must allow dodge cancel.")
	_expect(
		crescent.neutral_light.dodge_cancel_seconds >= crescent.neutral_light.recovery_seconds * 0.6,
		"Crescent cancel window should be wide."
	)


func _test_weapon_arts() -> void:
	for style_id in PlayerScript.STYLE_RESOURCES:
		var weapon: WeaponData = Factory.create_weapon(PlayerScript.STYLE_RESOURCES[style_id])
		_expect(weapon.default_weapon_art != null, "Weapon art missing for %s" % weapon.weapon_id)
		_expect(not String(weapon.default_weapon_art.art_kind).is_empty(), "art_kind empty for %s" % weapon.weapon_id)


func _test_reliquary_authored() -> void:
	var path := "res://resources/weapons/reliquary_guard_weapon.tres"
	_expect(ResourceLoader.exists(path), "Reliquary authored weapon missing.")
	var weapon := load(path) as WeaponData
	_expect(weapon != null, "Reliquary weapon failed to load.")
	_expect(weapon.validate().is_empty(), "Reliquary weapon invalid: %s" % str(weapon.validate()))
	_expect(weapon.one_hand_moveset != null and weapon.two_hand_moveset != null, "Reliquary grips missing.")
	var via_factory := Factory.create_weapon(PlayerScript.STYLE_RESOURCES[PlayerScript.CombatStyle.RELIQUARY_GUARD])
	_expect(String(via_factory.weapon_id) == "reliquary_guard", "Factory should resolve Reliquary weapon.")


func _test_root_motion_poc() -> void:
	var bridge = AnimBridge.new()
	var body := CharacterBody3D.new()
	root.add_child(body)
	bridge.setup(body)
	_expect(bridge.enabled, "Animation bridge failed to enable.")
	_expect(bridge.skeleton != null and bridge.anim_tree != null, "Skeleton/AnimationTree missing.")
	_expect(bridge.sample_light_root_delta() >= 0.5, "Light attack root track should move ~0.55m.")
	_expect(bridge.is_physics_callback(), "AnimationTree must use Physics callback.")
	_expect(bridge.has_strafe_blendspace(), "Lock-on Strafe BlendSpace2D missing.")
	_expect(bridge.sample_leap_root_delta() >= 2.0, "Twin Colossi leap root track too short.")
	body.queue_free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
