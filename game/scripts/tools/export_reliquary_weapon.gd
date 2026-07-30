extends SceneTree
## 写出 Reliquary Guard 权威 WeaponData .tres（工厂生成后落盘）

const Factory = preload("res://scripts/combat/data/compatibility_moveset_factory.gd")
const PlayerScript = preload("res://scripts/player/player.gd")


func _init() -> void:
	var style: CombatStyleData = PlayerScript.STYLE_RESOURCES[PlayerScript.CombatStyle.RELIQUARY_GUARD]
	var weapon: WeaponData = _build_weapon_without_authored(style)
	DirAccess.make_dir_recursive_absolute("res://resources/weapons")
	DirAccess.make_dir_recursive_absolute("res://resources/movesets")
	var weapon_path := "res://resources/weapons/reliquary_guard_weapon.tres"
	var one_path := "res://resources/movesets/reliquary_guard_one_handed.tres"
	var two_path := "res://resources/movesets/reliquary_guard_two_handed.tres"
	var err1 := ResourceSaver.save(weapon.one_hand_moveset, one_path)
	var err2 := ResourceSaver.save(weapon.two_hand_moveset, two_path)
	# 重新挂载路径引用后保存武器
	weapon.one_hand_moveset = load(one_path) as MovesetData if err1 == OK else weapon.one_hand_moveset
	weapon.two_hand_moveset = load(two_path) as MovesetData if err2 == OK else weapon.two_hand_moveset
	var err3 := ResourceSaver.save(weapon, weapon_path)
	if err1 != OK or err2 != OK or err3 != OK:
		push_error("Failed saving Reliquary resources: %s %s %s" % [err1, err2, err3])
		quit(1)
		return
	print("ASHEN_RELIQUARY_AUTHORED_OK")
	quit(0)


func _build_weapon_without_authored(style: CombatStyleData) -> WeaponData:
	# 绕过 create_weapon 的 authored 加载，直接工厂拼装
	var weapon := WeaponData.new()
	weapon.weapon_id = style.style_id
	weapon.weapon_class_id = style.style_id
	weapon.supports_one_handed = true
	weapon.supports_two_handed = true
	weapon.supports_paired = false
	weapon.default_grip = &"one_handed"
	weapon.critical_multiplier = 1.0
	weapon.supports_backstab = true
	weapon.supports_riposte = true
	weapon.one_hand_moveset = Factory.create(style, &"one_handed")
	weapon.two_hand_moveset = Factory.create(style, &"two_handed")
	weapon.default_weapon_art = WeaponArtData.make(&"pierce_thrust", &"reliquary_pierce")
	return weapon
