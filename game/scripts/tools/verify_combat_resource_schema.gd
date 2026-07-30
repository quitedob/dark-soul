class_name CombatResourceSchemaVerifier
extends RefCounted
## A-05：校验 combat Resource 的 class_name 注册与 schema validate()

## 核心攻击/招式 Resource（必须全局注册）
const REQUIRED_CLASS_PATHS := {
	"AttackData": "res://scripts/combat/data/attack_data.gd",
	"ChargeProfile": "res://scripts/combat/data/charge_profile.gd",
	"MovesetData": "res://scripts/combat/data/moveset_data.gd",
	"WeaponData": "res://scripts/combat/data/weapon_data.gd",
	"WeaponArtData": "res://scripts/combat/data/weapon_art_data.gd",
	"GuardProfile": "res://scripts/combat/data/guard_profile.gd",
	"ExecutionProfile": "res://scripts/combat/data/execution_profile.gd",
	"GrabProfile": "res://scripts/combat/data/grab_profile.gd",
}

## 已落盘的 Reliquary 作者化 .tres
const AUTHORED_WEAPON_PATH := "res://resources/weapons/reliquary_guard_weapon.tres"
const AUTHORED_MOVESET_PATHS := [
	"res://resources/movesets/reliquary_guard_one_handed.tres",
	"res://resources/movesets/reliquary_guard_two_handed.tres",
]


## 运行全部校验；返回错误字符串列表（空 = 通过）
static func run() -> Array[String]:
	var errors: Array[String] = []
	errors.append_array(verify_class_registration())
	errors.append_array(verify_instantiate_and_schema())
	errors.append_array(verify_compatibility_weapons())
	errors.append_array(verify_authored_tres())
	return errors


## 确认 ProjectSettings 全局类表含有目标 class_name
static func verify_class_registration() -> Array[String]:
	var errors: Array[String] = []
	var registered := _global_class_map()
	for class_id in REQUIRED_CLASS_PATHS.keys():
		if not registered.has(class_id):
			errors.append("class_name '%s' is not registered in ProjectSettings." % class_id)
			continue
		var expected_path: String = REQUIRED_CLASS_PATHS[class_id]
		var actual_path: String = String(registered[class_id])
		if actual_path != expected_path:
			errors.append(
				"class_name '%s' path mismatch: got %s expected %s." % [class_id, actual_path, expected_path]
			)
	return errors


## 实例化核心类型并跑 validate()（含故意非法 AttackData）
static func verify_instantiate_and_schema() -> Array[String]:
	var errors: Array[String] = []
	var attack := AttackData.new()
	attack.action_id = &"schema_probe"
	attack.active_seconds = 0.15
	var attack_errs := attack.validate()
	if not attack_errs.is_empty():
		errors.append("Fresh AttackData should validate: %s" % str(attack_errs))

	var bad := AttackData.new()
	bad.action_id = &"bad_unblockable"
	bad.tags = [&"unblockable"]
	bad.blockable = true
	if bad.validate().is_empty():
		errors.append("AttackData must reject unblockable+blockable conflict.")

	var charge := ChargeProfile.new()
	charge.tier_one_attack = attack
	charge.tier_two_attack = attack
	charge.tier_three_attack = attack
	var charge_errs := charge.validate()
	if not charge_errs.is_empty():
		errors.append("ChargeProfile with three tiers should validate: %s" % str(charge_errs))

	var moveset := MovesetData.new()
	moveset.moveset_id = &"schema_probe_moveset"
	moveset.neutral_light = attack
	moveset.neutral_heavy = attack
	var moveset_errs := moveset.validate()
	if not moveset_errs.is_empty():
		errors.append("MovesetData should validate: %s" % str(moveset_errs))

	var weapon := WeaponData.new()
	weapon.weapon_id = &"schema_probe_weapon"
	weapon.one_hand_moveset = moveset
	weapon.supports_one_handed = true
	var weapon_errs := weapon.validate()
	if not weapon_errs.is_empty():
		errors.append("WeaponData should validate: %s" % str(weapon_errs))

	# 其余已注册类型可实例化即可
	var guard := GuardProfile.new()
	if guard == null:
		errors.append("GuardProfile.new() failed.")
	var art := WeaponArtData.new()
	if art == null:
		errors.append("WeaponArtData.new() failed.")
	var execution := ExecutionProfile.new()
	if execution == null:
		errors.append("ExecutionProfile.new() failed.")
	var grab := GrabProfile.new()
	if grab == null:
		errors.append("GrabProfile.new() failed.")
	return errors


## 五套兼容风格经 Factory 生成的 WeaponData 必须通过 validate()
static func verify_compatibility_weapons() -> Array[String]:
	var errors: Array[String] = []
	var player_script = load("res://scripts/player/player.gd")
	var factory = load("res://scripts/combat/data/compatibility_moveset_factory.gd")
	if player_script == null or factory == null:
		errors.append("Cannot load Player or CompatibilityMovesetFactory for schema verify.")
		return errors
	for style_id in player_script.STYLE_RESOURCES:
		var style: CombatStyleData = player_script.STYLE_RESOURCES[style_id]
		var weapon: WeaponData = factory.create_weapon(style)
		if weapon == null:
			errors.append("Factory returned null WeaponData for style %s." % style_id)
			continue
		var weapon_errs := weapon.validate()
		if not weapon_errs.is_empty():
			errors.append("Weapon %s invalid: %s" % [weapon.weapon_id, str(weapon_errs)])
		var grips := weapon.supported_grips()
		if grips.is_empty():
			errors.append("Weapon %s has no supported grips." % weapon.weapon_id)
			continue
		# 每个支持的握持必须有中立轻击
		for grip in grips:
			var moveset := weapon.resolve_moveset(grip)
			if moveset == null or moveset.neutral_light == null:
				errors.append("Weapon %s grip %s missing neutral_light." % [weapon.weapon_id, grip])
	return errors


## 作者化 .tres 必须以 script_class 正确反序列化并通过 validate()
static func verify_authored_tres() -> Array[String]:
	var errors: Array[String] = []
	var weapon_res = ResourceLoader.load(AUTHORED_WEAPON_PATH, "", ResourceLoader.CACHE_MODE_REPLACE)
	if not (weapon_res is WeaponData):
		errors.append("%s did not load as WeaponData." % AUTHORED_WEAPON_PATH)
	else:
		var w: WeaponData = weapon_res
		var w_errs := w.validate()
		if not w_errs.is_empty():
			errors.append("Authored weapon invalid: %s" % str(w_errs))
		if w.one_hand_moveset == null or w.two_hand_moveset == null:
			errors.append("Authored Reliquary weapon missing one/two-hand movesets.")

	for path in AUTHORED_MOVESET_PATHS:
		var moveset_res = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
		if not (moveset_res is MovesetData):
			errors.append("%s did not load as MovesetData." % path)
			continue
		var m: MovesetData = moveset_res
		var m_errs := m.validate()
		if not m_errs.is_empty():
			errors.append("Authored moveset %s invalid: %s" % [path, str(m_errs)])
		if m.neutral_light == null or m.neutral_heavy == null:
			errors.append("Authored moveset %s missing neutral attacks." % path)
		if m.charged_heavy == null:
			errors.append("Authored moveset %s missing ChargeProfile." % path)
	return errors


## 构建 class_name → 脚本路径 映射
static func _global_class_map() -> Dictionary:
	var result := {}
	for info in ProjectSettings.get_global_class_list():
		var class_id := String(info.get("class", ""))
		if class_id.is_empty():
			continue
		result[class_id] = String(info.get("path", ""))
	return result
