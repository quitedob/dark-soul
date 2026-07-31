class_name CompatibilityMovesetFactory
extends RefCounted
## 兼容招式工厂：风格 → WeaponData（含 grip Moveset + 三档蓄力）
## L-08：同一构建器按 `weapon_type` 产出逐类动作家族；风格路径（cls 为空）行为保持不变

const WeaponArtsCatalogScript = preload("res://scripts/combat/data/weapon_arts_catalog.gd")


static func create(style: CombatStyleData, grip_mode: StringName = &"one_handed") -> MovesetData:
	## 兼容路径：按 CombatStyleData 标量生成（5 套 loadout 行为保持不变）
	return _build_moveset(style, grip_mode, {})


static func create_for_class(
	weapon_type: StringName,
	grip_mode: StringName = &"one_handed",
	style: CombatStyleData = null
) -> MovesetData:
	## L-08：按武器类别生成差异化动作家族（时序/伤害/精力/距离/标签/命中体）
	var cls := _class_profile(weapon_type)
	if cls.is_empty():
		return create(style, grip_mode)
	var base := style
	if base == null:
		base = _class_to_style(cls)
	var moveset := _build_moveset(base, grip_mode, cls)
	_apply_class_extras(moveset, cls)
	# leap 类兵器诀（colossal / crescent / 反制前冲）挂在 weapon_art_heavy
	if cls.get("leap_kind", &"") != &"":
		var leap := _class_leap(base, cls)
		_set_hitbox(
			leap,
			float(cls.get("leap_hitbox_radius", 1.2)),
			float(cls.get("leap_hitbox_height", 1.55)),
			cls.get("leap_hitbox_offset", Vector3(0.0, 1.05, 0.0)),
			&"weapon_tip"
		)
		moveset.weapon_art_heavy = leap
	return moveset


static func create_weapon_for_type(weapon_type: StringName, weapon_id: StringName = &"") -> WeaponData:
	## L-08/L-13：按武器类别构建完整 WeaponData（grip Moveset + default_weapon_art）
	var cls := _class_profile(weapon_type)
	if cls.is_empty():
		return null
	var weapon := WeaponData.new()
	weapon.weapon_id = weapon_id if not weapon_id.is_empty() else weapon_type
	weapon.weapon_class_id = weapon_type
	weapon.weapon_type = weapon_type
	var flags: Dictionary = cls.get("grips", {})
	weapon.supports_one_handed = bool(flags.get("one", false))
	weapon.supports_two_handed = bool(flags.get("two", false))
	weapon.supports_paired = bool(flags.get("paired", false))
	weapon.default_grip = flags.get("default", &"one_handed")
	weapon.critical_multiplier = float(cls.get("crit", 1.0))
	weapon.supports_backstab = bool(cls.get("backstab", true))
	weapon.supports_riposte = bool(cls.get("riposte", true))
	weapon.display_name = WeaponArtsCatalogScript.class_display_name(weapon_type)
	weapon.mesh_shape = String(cls.get("mesh_shape", "box"))
	weapon.mesh_color_hex = String(cls.get("mesh_color", "9aa3aa"))
	weapon.hand_slot = &"right"
	if weapon.supports_one_handed:
		weapon.one_hand_moveset = create_for_class(weapon_type, &"one_handed")
	if weapon.supports_two_handed:
		weapon.two_hand_moveset = create_for_class(weapon_type, &"two_handed")
	if weapon.supports_paired:
		weapon.paired_moveset = create_for_class(weapon_type, &"paired")
	weapon.default_weapon_art = WeaponArtsCatalogScript.for_type(weapon_type)
	return weapon


static func _build_moveset(style: CombatStyleData, grip_mode: StringName, cls: Dictionary) -> MovesetData:
	var moveset := MovesetData.new()
	moveset.moveset_id = StringName("%s_%s_moveset" % [style.style_id, grip_mode])
	moveset.grip_mode = grip_mode
	var g := _grip_scale(grip_mode)
	moveset.neutral_light = _attack(style, false, g, cls)
	moveset.neutral_heavy = _attack(style, true, g, cls)
	moveset.sprint_attack = _derive(
		style, false, "sprint", g,
		1.12, 1.08, 0.82, 1.0, 0.88, 1.55,
		[&"melee", &"light", &"sprint"],
		0.0, cls
	)
	moveset.roll_attack = _derive(
		style, false, "roll", g,
		1.06, 0.95, 0.68, 0.92, 0.82, 1.25,
		[&"melee", &"light", &"roll"],
		0.0, cls
	)
	moveset.backstep_attack = _derive(
		style, false, "backstep", g,
		1.0, 0.9, 0.72, 0.88, 0.78, 0.85,
		[&"melee", &"light", &"backstep"],
		0.0, cls
	)
	moveset.jump_attack = _derive(
		style, false, "jump", g,
		1.1, 1.0, 0.72, 1.15, 0.9, 0.35,
		[&"melee", &"light", &"jump"],
		0.0, cls
	)
	_set_hitbox(moveset.jump_attack, 0.95, 1.55, Vector3(0.0, 1.05, 0.0), &"weapon_tip")
	moveset.falling_attack = _derive(
		style, true, "falling", g,
		1.35, 1.18, 0.35, 1.0, 0.95, 0.12,
		[&"melee", &"heavy", &"falling", &"plunge"],
		-12.0, cls
	)
	moveset.falling_attack.active_seconds = maxf(moveset.falling_attack.active_seconds, 1.35)
	moveset.falling_attack.hitbox_until_land = true
	_set_hitbox(moveset.falling_attack, 1.05, 2.55, Vector3(0.0, -0.1, -0.3), &"")
	moveset.charged_heavy = _build_charge_profile(style, g, moveset.neutral_heavy)
	if style.leap_active > 0.0 and cls.is_empty():
		moveset.weapon_art_heavy = _leap(style)
		_set_hitbox(moveset.weapon_art_heavy, 1.2, 1.55, Vector3(0.0, 1.05, 0.0), &"weapon_tip")
	_append_grip_tag(moveset, grip_mode)
	return moveset


static func create_weapon(style: CombatStyleData) -> WeaponData:
	# 优先加载 authored Reliquary 等武器资源
	var authored_path := "res://resources/weapons/%s_weapon.tres" % String(style.style_id)
	if ResourceLoader.exists(authored_path):
		var authored := load(authored_path)
		if authored is WeaponData and authored.validate().is_empty():
			return authored
	var weapon := WeaponData.new()
	weapon.weapon_id = style.style_id
	weapon.weapon_class_id = style.style_id
	var flags := _style_grip_flags(style.style_id)
	weapon.supports_one_handed = flags["one"]
	weapon.supports_two_handed = flags["two"]
	weapon.supports_paired = flags["paired"]
	weapon.default_grip = flags["default"]
	weapon.critical_multiplier = float(flags["crit"])
	weapon.supports_backstab = true
	weapon.supports_riposte = true
	if weapon.supports_one_handed:
		weapon.one_hand_moveset = create(style, &"one_handed")
	if weapon.supports_two_handed:
		weapon.two_hand_moveset = create(style, &"two_handed")
	if weapon.supports_paired:
		weapon.paired_moveset = create(style, &"paired")
	weapon.default_weapon_art = _style_weapon_art(style)
	return weapon


static func _style_weapon_art(style: CombatStyleData) -> WeaponArtData:
	match style.style_id:
		&"reliquary_guard":
			return WeaponArtData.make(&"pierce_thrust", &"reliquary_pierce")
		&"twin_colossi":
			var art := WeaponArtData.make(&"colossal_leap", &"twin_colossal_leap")
			art.entry_attack = _leap(style)
			return art
		&"crescent_pair":
			var art := WeaponArtData.make(&"crescent_leap", &"crescent_leap")
			art.entry_attack = _leap(style)
			return art
		&"veilcraft":
			return WeaponArtData.make(&"arcane_barrage", &"veil_barrage")
		&"ember_rite":
			return WeaponArtData.make(&"divine_smite", &"ember_smite")
	return null


static func _style_grip_flags(style_id: StringName) -> Dictionary:
	match style_id:
		&"reliquary_guard":
			return {"one": true, "two": true, "paired": false, "default": &"one_handed", "crit": 1.0}
		&"twin_colossi":
			return {"one": true, "two": false, "paired": true, "default": &"paired", "crit": 1.05}
		&"crescent_pair":
			return {"one": true, "two": false, "paired": true, "default": &"paired", "crit": 1.15}
		&"veilcraft":
			return {"one": true, "two": false, "paired": false, "default": &"one_handed", "crit": 1.0}
		&"ember_rite":
			return {"one": true, "two": false, "paired": false, "default": &"one_handed", "crit": 1.0}
	return {"one": true, "two": false, "paired": false, "default": &"one_handed", "crit": 1.0}


static func _grip_scale(grip_mode: StringName) -> Dictionary:
	# 双持：伤害 1.3 / 精力 1.5；不成倍暴击
	match grip_mode:
		&"two_handed":
			return {
				"damage": 1.3, "poise": 1.3, "stamina": 1.5,
				"windup": 1.12, "active": 1.05, "recovery": 1.15, "lunge": 1.18, "wam": 1.35,
			}
		&"paired":
			return {
				"damage": 1.08, "poise": 1.1, "stamina": 1.12,
				"windup": 0.95, "active": 1.08, "recovery": 0.92, "lunge": 1.05, "wam": 1.05,
			}
	return {
		"damage": 1.0, "poise": 1.0, "stamina": 1.0,
		"windup": 1.0, "active": 1.0, "recovery": 1.0, "lunge": 1.0, "wam": 1.0,
	}


static func _append_grip_tag(moveset: MovesetData, grip_mode: StringName) -> void:
	var tag := grip_mode
	for attack in [
		moveset.neutral_light, moveset.neutral_heavy, moveset.sprint_attack,
		moveset.roll_attack, moveset.backstep_attack, moveset.jump_attack, moveset.falling_attack,
	]:
		if attack != null and tag not in attack.tags:
			attack.tags.append(tag)
	if moveset.charged_heavy != null:
		for tier in [
			moveset.charged_heavy.tier_one_attack,
			moveset.charged_heavy.tier_two_attack,
			moveset.charged_heavy.tier_three_attack,
		]:
			if tier != null and tag not in tier.tags:
				tier.tags.append(tag)


static func _build_charge_profile(style: CombatStyleData, g: Dictionary, heavy_base: AttackData) -> ChargeProfile:
	var profile := ChargeProfile.new()
	profile.minimum_hold_seconds = 0.20
	profile.tier_two_seconds = 0.75
	profile.tier_three_seconds = 1.40
	# 一档 ≈ 中立重击；二/三档提高伤害与承诺
	profile.tier_one_attack = _charged_tier(style, g, heavy_base, "charge_1", 1.0, 1.0, 1.0, 1.0, 0.0)
	profile.tier_two_attack = _charged_tier(style, g, heavy_base, "charge_2", 1.28, 1.22, 0.92, 1.15, 0.12)
	profile.tier_three_attack = _charged_tier(style, g, heavy_base, "charge_3", 1.55, 1.45, 0.85, 1.3, 0.22)
	return profile


static func _charged_tier(
	style: CombatStyleData,
	g: Dictionary,
	heavy_base: AttackData,
	suffix: String,
	damage_mul: float,
	stamina_mul: float,
	windup_mul: float,
	lunge_mul: float,
	extra_wam: float
) -> AttackData:
	var attack := heavy_base.duplicate(true) as AttackData
	attack.action_id = StringName("%s_%s" % [style.style_id, suffix])
	attack.display_name_key = attack.action_id
	attack.damage = maxf(heavy_base.damage * damage_mul, 8.0)
	attack.poise_damage = maxf(heavy_base.poise_damage * damage_mul, 6.0)
	attack.stamina_cost = maxf(heavy_base.stamina_cost * stamina_mul, 10.0)
	attack.windup_seconds = maxf(heavy_base.windup_seconds * windup_mul, 0.1)
	attack.authored_displacement = Vector3(0.0, 0.0, heavy_base.authored_displacement.z * lunge_mul)
	attack.guard_power = attack.damage + attack.poise_damage * 0.35
	# 蓄力：late windup + active 有限护甲；recovery 恒为 0
	attack.poise_modifier_active = minf(heavy_base.poise_modifier_active * float(g["wam"]) + extra_wam, 1.5)
	attack.poise_modifier_windup = minf(
		maxf(heavy_base.poise_modifier_windup, attack.poise_modifier_active * 0.28) + extra_wam * 0.5,
		1.2
	)
	attack.poise_modifier_recovery = 0.0
	# 蓄力对 Boss Execution Break 额外贡献
	attack.execution_break_damage = maxf(heavy_base.poise_damage * 0.45 * damage_mul, 8.0)
	if &"charged" not in attack.tags:
		attack.tags.append(&"charged")
	if &"heavy" not in attack.tags:
		attack.tags.append(&"heavy")
	return attack


static func _attack(style: CombatStyleData, heavy: bool, g: Dictionary, cls: Dictionary = {}) -> AttackData:
	var attack := AttackData.new()
	attack.action_id = StringName("%s_%s" % [style.style_id, "heavy" if heavy else "light"])
	attack.display_name_key = attack.action_id
	var n := _class_numbers(style, cls, heavy)
	attack.windup_seconds = n.windup * float(g["windup"])
	# active 必须 >0，施法风格 style 里可为 0，工厂钳到最小窗
	attack.active_seconds = maxf(n.active * float(g["active"]), 0.08)
	attack.recovery_seconds = n.recovery * float(g["recovery"])
	attack.stamina_cost = n.stamina * float(g["stamina"])
	# 法术近战走 Focus；体力可保持 0
	if style.style_id == &"veilcraft" or style.style_id == &"ember_rite":
		attack.focus_cost = 18.0 if heavy else 10.0
	attack.damage = n.damage * float(g["damage"])
	attack.poise_damage = n.poise * float(g["poise"])
	attack.guard_power = attack.damage + attack.poise_damage * 0.35
	var lunge := float(n.lunge) * float(g["lunge"])
	attack.authored_displacement = Vector3(0.0, 0.0, lunge)
	# 分阶段 WAM：轻击仅短 active；重击 late windup+active；recovery 无护甲
	var active_wam := float(n.wam) * float(g["wam"])
	attack.poise_modifier_active = active_wam
	attack.poise_modifier_windup = active_wam * (0.35 if heavy else 0.0)
	attack.poise_modifier_recovery = 0.0
	attack.tags = [&"melee", &"heavy" if heavy else &"light"]
	attack.execution_break_damage = attack.poise_damage * (0.55 if heavy else 0.25)
	if not cls.is_empty():
		# L-08：类别各自定义取消窗比例（-1 = 零闪避取消）
		var ratio := float(cls.get("dodge_cancel", 0.4))
		if ratio < 0.0:
			attack.dodge_cancel_seconds = -1.0
		else:
			attack.dodge_cancel_seconds = attack.recovery_seconds * ratio
	elif style.style_id == &"twin_colossi":
		attack.dodge_cancel_seconds = -1.0
	elif style.style_id == &"crescent_pair":
		attack.dodge_cancel_seconds = attack.recovery_seconds * 0.65
	else:
		attack.dodge_cancel_seconds = attack.recovery_seconds * 0.4
	_set_hitbox(attack, 1.25, 1.45, Vector3(0.0, 1.0, -1.0))
	return attack


## 数值源：类别（cls 非空）取绝对数值；风格路径取 style 标量（保持 5 套 loadout 行为不变）
static func _class_numbers(style: CombatStyleData, cls: Dictionary, heavy: bool) -> Dictionary:
	if cls.is_empty():
		return {
			"windup": (style.windup_heavy if heavy else style.windup_light),
			"active": (style.active_heavy if heavy else style.active_light),
			"recovery": (style.recovery_heavy if heavy else style.recovery_light),
			"stamina": (style.stamina_heavy if heavy else style.stamina_light),
			"damage": (style.damage_heavy if heavy else style.damage_light),
			"poise": (style.stagger_heavy if heavy else style.stagger_light),
			"lunge": (style.lunge_heavy if heavy else style.lunge_light),
			"wam": (style.wam_heavy if heavy else style.wam_light),
		}
	var prefix := "heavy" if heavy else "light"
	return {
		"windup": float(cls.get("windup_%s" % prefix, 0.3)),
		"active": float(cls.get("active_%s" % prefix, 0.15)),
		"recovery": float(cls.get("recovery_%s" % prefix, 0.35)),
		"stamina": float(cls.get("stamina_%s" % prefix, 20.0)),
		"damage": float(cls.get("damage_%s" % prefix, 20.0)),
		"poise": float(cls.get("stagger_%s" % prefix, 16.0)),
		"lunge": float(cls.get("lunge_%s" % prefix, 2.0)),
		"wam": float(cls.get("wam_%s" % prefix, 0.0)),
	}


## L-08：类别数值 → CombatStyleData（仅作构建载体，真实数值仍读 cls）
static func _class_to_style(cls: Dictionary) -> CombatStyleData:
	var style := CombatStyleData.new()
	style.style_id = cls.get("style_id", &"class_weapon")
	style.display_name = String(cls.get("display_name", "Class Weapon"))
	style.windup_light = float(cls.get("windup_light", 0.3))
	style.active_light = float(cls.get("active_light", 0.15))
	style.recovery_light = float(cls.get("recovery_light", 0.35))
	style.lunge_light = float(cls.get("lunge_light", 2.0))
	style.damage_light = float(cls.get("damage_light", 20.0))
	style.stagger_light = float(cls.get("stagger_light", 16.0))
	style.stamina_light = float(cls.get("stamina_light", 20.0))
	style.windup_heavy = float(cls.get("windup_heavy", 0.6))
	style.active_heavy = float(cls.get("active_heavy", 0.22))
	style.recovery_heavy = float(cls.get("recovery_heavy", 0.65))
	style.lunge_heavy = float(cls.get("lunge_heavy", 2.8))
	style.damage_heavy = float(cls.get("damage_heavy", 38.0))
	style.stagger_heavy = float(cls.get("stagger_heavy", 34.0))
	style.stamina_heavy = float(cls.get("stamina_heavy", 38.0))
	style.wam_light = float(cls.get("wam_light", 0.0))
	style.wam_heavy = float(cls.get("wam_heavy", 0.0))
	style.stamina_dodge = 24.0
	style.move_speed = 5.2
	style.sprint_speed = 7.4
	return style


static func _leap(style: CombatStyleData) -> AttackData:
	var leap := AttackData.new()
	leap.action_id = StringName("%s_leap" % style.style_id)
	leap.display_name_key = leap.action_id
	leap.windup_seconds = style.leap_windup
	leap.active_seconds = style.leap_active
	leap.recovery_seconds = style.leap_recovery
	leap.stamina_cost = style.leap_stamina
	leap.damage = style.leap_damage
	leap.poise_damage = style.leap_stagger
	leap.guard_power = style.leap_damage + style.leap_stagger * 0.35
	leap.authored_displacement = Vector3(0.0, 0.0, style.leap_lunge)
	leap.launch_velocity_y = style.leap_velocity_y
	# leap 与普攻分属不同 AttackData，不可共用布尔霸体
	leap.poise_modifier_active = style.wam_leap
	leap.poise_modifier_windup = style.wam_leap * 0.45
	leap.poise_modifier_recovery = 0.0
	leap.execution_break_damage = style.leap_stagger * 0.7
	leap.tags = [&"melee", &"heavy", &"leap", &"weapon_art"]
	return leap


static func _set_hitbox(
	attack: AttackData,
	radius: float,
	height: float,
	offset: Vector3,
	socket: StringName = &""
) -> void:
	attack.hitbox_radius = radius
	attack.hitbox_height = height
	attack.hitbox_offset = offset
	attack.hitbox_socket = socket


static func _derive(
	style: CombatStyleData,
	heavy: bool,
	suffix: String,
	g: Dictionary,
	damage_mul: float,
	stamina_mul: float,
	windup_mul: float,
	active_mul: float,
	recovery_mul: float,
	lunge_mul: float,
	tags: Array[StringName],
	launch_y: float = 0.0,
	cls: Dictionary = {}
) -> AttackData:
	var base := _attack(style, heavy, g, cls)
	var attack := AttackData.new()
	attack.action_id = StringName("%s_%s" % [style.style_id, suffix])
	attack.display_name_key = attack.action_id
	attack.windup_seconds = maxf(base.windup_seconds * windup_mul, 0.08)
	attack.active_seconds = maxf(base.active_seconds * active_mul, 0.08)
	attack.recovery_seconds = maxf(base.recovery_seconds * recovery_mul, 0.1)
	attack.damage = maxf(base.damage * damage_mul, 8.0 if base.damage <= 0.0 else base.damage * damage_mul)
	attack.poise_damage = maxf(base.poise_damage * damage_mul, 6.0 if base.poise_damage <= 0.0 else base.poise_damage * damage_mul)
	attack.stamina_cost = maxf(base.stamina_cost * stamina_mul, 10.0 if base.stamina_cost <= 0.0 else base.stamina_cost * stamina_mul)
	attack.focus_cost = base.focus_cost
	attack.guard_power = attack.damage + attack.poise_damage * 0.35
	attack.authored_displacement = Vector3(0.0, 0.0, base.authored_displacement.z * lunge_mul)
	attack.launch_velocity_y = launch_y
	# 派生招继承三阶段护甲（recovery 仍为 0）
	attack.poise_modifier_active = base.poise_modifier_active
	attack.poise_modifier_windup = base.poise_modifier_windup
	attack.poise_modifier_recovery = 0.0
	attack.tags = tags.duplicate()
	# 派生招继承取消窗比例
	if base.dodge_cancel_seconds >= 0.0:
		attack.dodge_cancel_seconds = attack.recovery_seconds * 0.4
	else:
		attack.dodge_cancel_seconds = -1.0
	attack.hitbox_radius = base.hitbox_radius
	attack.hitbox_height = base.hitbox_height
	attack.hitbox_offset = base.hitbox_offset
	return attack


## L-08：类别 leap（colossal / crescent / 反制前冲）— 挂 weapon_art_heavy，供 player 兜底分发
static func _class_leap(style: CombatStyleData, cls: Dictionary) -> AttackData:
	var leap := AttackData.new()
	leap.action_id = StringName("%s_leap" % style.style_id)
	leap.display_name_key = leap.action_id
	leap.windup_seconds = float(cls.get("leap_windup", 0.3))
	leap.active_seconds = float(cls.get("leap_active", 0.18))
	leap.recovery_seconds = float(cls.get("leap_recovery", 0.6))
	leap.stamina_cost = float(cls.get("leap_stamina", 26.0))
	leap.damage = float(cls.get("leap_damage", 40.0))
	leap.poise_damage = float(cls.get("leap_stagger", 44.0))
	leap.guard_power = leap.damage + leap.poise_damage * 0.35
	leap.authored_displacement = Vector3(0.0, 0.0, float(cls.get("leap_lunge", 3.0)))
	leap.launch_velocity_y = float(cls.get("leap_velocity_y", 0.0))
	var wam := float(cls.get("leap_wam", 0.8))
	leap.poise_modifier_active = wam
	leap.poise_modifier_windup = wam * 0.45
	leap.poise_modifier_recovery = 0.0
	leap.execution_break_damage = leap.poise_damage * 0.7
	leap.tags = [&"melee", &"heavy", &"leap", &"weapon_art"]
	for tag in cls.get("leap_tags", []):
		if tag is StringName and tag not in leap.tags:
			leap.tags.append(tag)
	return leap


## L-08：类别标签 / 地面冲击 / 命中体统一落到整套 moveset
static func _apply_class_extras(moveset: MovesetData, cls: Dictionary) -> void:
	if cls.is_empty():
		return
	var light_tags: Array = cls.get("light_tags", [])
	var heavy_tags: Array = cls.get("heavy_tags", [])
	var shock_heavy := bool(cls.get("shockwave_heavy", false))
	var shock_charge := int(cls.get("shockwave_charge_tier", 0))
	var hb_light: Dictionary = cls.get("hitbox_light", {})
	var hb_heavy: Dictionary = cls.get("hitbox_heavy", {})
	var hb_jump: Dictionary = cls.get("hitbox_jump", hb_light)
	var hb_falling: Dictionary = cls.get("hitbox_falling", hb_heavy)
	_tag_attack(moveset.neutral_light, light_tags)
	_tag_attack(moveset.neutral_heavy, heavy_tags)
	if shock_heavy:
		_tag_attack(moveset.neutral_heavy, [&"ground_shockwave"])
	for attack in [moveset.sprint_attack, moveset.roll_attack, moveset.backstep_attack, moveset.jump_attack]:
		_tag_attack(attack, light_tags)
	_tag_attack(moveset.falling_attack, heavy_tags)
	if shock_heavy:
		_tag_attack(moveset.falling_attack, [&"ground_shockwave"])
	_apply_hitbox(moveset.neutral_light, hb_light)
	_apply_hitbox(moveset.neutral_heavy, hb_heavy)
	for attack in [moveset.sprint_attack, moveset.roll_attack, moveset.backstep_attack]:
		_apply_hitbox(attack, hb_light)
	_apply_hitbox(moveset.jump_attack, hb_jump)
	_apply_hitbox(moveset.falling_attack, hb_falling)
	if moveset.charged_heavy != null:
		var tiers := [
			moveset.charged_heavy.tier_one_attack,
			moveset.charged_heavy.tier_two_attack,
			moveset.charged_heavy.tier_three_attack,
		]
		for i in tiers.size():
			var tier: AttackData = tiers[i]
			if tier == null:
				continue
			_tag_attack(tier, heavy_tags)
			if i + 1 <= shock_charge:
				_tag_attack(tier, [&"ground_shockwave"])
			_apply_hitbox(tier, hb_heavy)


static func _tag_attack(attack: AttackData, tags: Array) -> void:
	if attack == null or tags.is_empty():
		return
	for tag in tags:
		if tag is StringName and tag not in attack.tags:
			attack.tags.append(tag)


static func _apply_hitbox(attack: AttackData, cfg: Dictionary) -> void:
	if attack == null or cfg.is_empty():
		return
	attack.hitbox_radius = float(cfg.get("radius", attack.hitbox_radius))
	attack.hitbox_height = float(cfg.get("height", attack.hitbox_height))
	attack.hitbox_offset = cfg.get("offset", attack.hitbox_offset)
	attack.hitbox_socket = cfg.get("socket", attack.hitbox_socket)


static func _hb(radius: float, height: float, offset: Vector3, socket: StringName = &"") -> Dictionary:
	return {"radius": radius, "height": height, "offset": offset, "socket": socket}


static func _grip(one: bool, two: bool, paired: bool, default: StringName) -> Dictionary:
	return {"one": one, "two": two, "paired": paired, "default": default}


## L-08：9 类武器 → 动作家族数值 / 标签 / 命中体 / 持握 / leap。未知类别返回空（回落风格路径）。
static func _class_profile(weapon_type: StringName) -> Dictionary:
	match weapon_type:
		&"sword":
			# 直剑：短弧快回收，重击踏步直刺（破盾缝/窄通道/精确惩罚）
			return {
				"style_id": &"sword",
				"display_name": "直剑",
				"windup_light": 0.22, "active_light": 0.16, "recovery_light": 0.30,
				"lunge_light": 1.9, "damage_light": 20.0, "stagger_light": 16.0, "stamina_light": 18.0,
				"windup_heavy": 0.50, "active_heavy": 0.20, "recovery_heavy": 0.55,
				"lunge_heavy": 2.7, "damage_heavy": 36.0, "stagger_heavy": 32.0, "stamina_heavy": 32.0,
				"wam_light": 0.0, "wam_heavy": 0.25,
				"dodge_cancel": 0.45, "crit": 1.0,
				"grips": _grip(true, true, false, &"one_handed"),
				"mesh_shape": "sword", "mesh_color": "a9a18c",
				"hitbox_light": _hb(1.25, 1.45, Vector3(0.0, 1.0, -1.0)),
				"hitbox_heavy": _hb(1.35, 1.45, Vector3(0.0, 1.0, -1.1)),
				"leap_kind": &"",
			}
		&"greatsword":
			# 大剑：范围/削韧/读招惩罚，空挥后明显反击窗
			return {
				"style_id": &"greatsword",
				"display_name": "大剑",
				"windup_light": 0.42, "active_light": 0.22, "recovery_light": 0.50,
				"lunge_light": 1.7, "damage_light": 28.0, "stagger_light": 26.0, "stamina_light": 24.0,
				"windup_heavy": 0.72, "active_heavy": 0.26, "recovery_heavy": 0.85,
				"lunge_heavy": 2.5, "damage_heavy": 48.0, "stagger_heavy": 46.0, "stamina_heavy": 42.0,
				"wam_light": 0.1, "wam_heavy": 0.7,
				"dodge_cancel": 0.25, "crit": 1.05,
				"grips": _grip(true, true, false, &"one_handed"),
				"mesh_shape": "greatsword", "mesh_color": "7f6f58",
				"hitbox_light": _hb(1.45, 1.5, Vector3(0.0, 1.0, -1.15)),
				"hitbox_heavy": _hb(1.6, 1.55, Vector3(0.0, 1.0, -1.25)),
				"leap_kind": &"colossal_leap",
				"leap_windup": 0.3, "leap_active": 0.22, "leap_recovery": 0.6,
				"leap_damage": 46.0, "leap_stagger": 48.0, "leap_stamina": 30.0,
				"leap_lunge": 3.4, "leap_velocity_y": 1.8, "leap_wam": 0.8,
			}
		&"ultra":
			# 特大剑/巨锤：双持为主，慢、高削韧、长后摇、霸体；重击/蓄力带短震波
			return {
				"style_id": &"ultra",
				"display_name": "特大剑",
				"windup_light": 0.55, "active_light": 0.28, "recovery_light": 0.70,
				"lunge_light": 1.5, "damage_light": 34.0, "stagger_light": 36.0, "stamina_light": 30.0,
				"windup_heavy": 0.75, "active_heavy": 0.30, "recovery_heavy": 1.10,
				"lunge_heavy": 2.3, "damage_heavy": 56.0, "stagger_heavy": 60.0, "stamina_heavy": 48.0,
				"wam_light": 0.35, "wam_heavy": 1.2,
				"dodge_cancel": 0.12, "crit": 1.0,
				"grips": _grip(false, true, false, &"two_handed"),
				"mesh_shape": "greatsword", "mesh_color": "4a3a28",
				"hitbox_light": _hb(1.6, 1.7, Vector3(0.0, 1.0, -1.3)),
				"hitbox_heavy": _hb(1.8, 1.75, Vector3(0.0, 1.0, -1.45)),
				"heavy_tags": [&"wide_sweep"],
				"shockwave_heavy": true, "shockwave_charge_tier": 3,
				"leap_kind": &"colossal_leap",
				"leap_windup": 0.45, "leap_active": 0.3, "leap_recovery": 0.9,
				"leap_damage": 60.0, "leap_stagger": 64.0, "leap_stamina": 46.0,
				"leap_lunge": 2.8, "leap_velocity_y": 2.4, "leap_wam": 1.3,
				"leap_tags": [&"ground_shockwave"],
			}
		&"spear":
			# 长枪/矛：长突刺位移、贴身死区（point_blank_weak 数据信号）
			return {
				"style_id": &"spear",
				"display_name": "长枪",
				"windup_light": 0.32, "active_light": 0.18, "recovery_light": 0.42,
				"lunge_light": 3.2, "damage_light": 22.0, "stagger_light": 16.0, "stamina_light": 20.0,
				"windup_heavy": 0.60, "active_heavy": 0.22, "recovery_heavy": 0.75,
				"lunge_heavy": 4.4, "damage_heavy": 42.0, "stagger_heavy": 34.0, "stamina_heavy": 38.0,
				"wam_light": 0.0, "wam_heavy": 0.3,
				"dodge_cancel": 0.4, "crit": 1.0,
				"grips": _grip(true, true, false, &"one_handed"),
				"mesh_shape": "spear", "mesh_color": "8d9278",
				"hitbox_light": _hb(0.95, 1.5, Vector3(0.0, 1.0, -2.1), &"weapon_tip"),
				"hitbox_heavy": _hb(1.0, 1.55, Vector3(0.0, 1.0, -2.5), &"weapon_tip"),
				"hitbox_jump": _hb(1.0, 1.55, Vector3(0.0, 1.05, -2.3), &"weapon_tip"),
				"hitbox_falling": _hb(1.05, 2.55, Vector3(0.0, -0.1, -2.2), &""),
				"light_tags": [&"long_thrust", &"point_blank_weak"],
				"heavy_tags": [&"long_thrust", &"point_blank_weak"],
				"leap_kind": &"",
			}
		&"axe":
			# 斧/战锤：短弧斜砍维持近身；重击带地面冲击（实体命中与冲击波分结算）
			return {
				"style_id": &"axe",
				"display_name": "战锤",
				"windup_light": 0.30, "active_light": 0.18, "recovery_light": 0.38,
				"lunge_light": 1.8, "damage_light": 26.0, "stagger_light": 22.0, "stamina_light": 22.0,
				"windup_heavy": 0.62, "active_heavy": 0.24, "recovery_heavy": 0.80,
				"lunge_heavy": 2.1, "damage_heavy": 46.0, "stagger_heavy": 48.0, "stamina_heavy": 40.0,
				"wam_light": 0.0, "wam_heavy": 0.6,
				"dodge_cancel": 0.35, "crit": 1.0,
				"grips": _grip(true, true, false, &"one_handed"),
				"mesh_shape": "axe_right", "mesh_color": "858b91",
				"hitbox_light": _hb(1.25, 1.4, Vector3(0.0, 1.0, -0.9)),
				"hitbox_heavy": _hb(1.4, 1.4, Vector3(0.0, 1.0, -1.0)),
				"heavy_tags": [&"ground_shockwave"],
				"shockwave_heavy": true,
				"leap_kind": &"colossal_leap",
				"leap_windup": 0.4, "leap_active": 0.24, "leap_recovery": 0.8,
				"leap_damage": 50.0, "leap_stagger": 54.0, "leap_stamina": 34.0,
				"leap_lunge": 2.4, "leap_velocity_y": 0.8, "leap_wam": 1.0,
				"leap_tags": [&"ground_shockwave"],
			}
		&"curved":
			# 曲剑/双刀：成对非对称双切，轻快但单次削韧低，可绕侧
			return {
				"style_id": &"curved",
				"display_name": "曲剑",
				"windup_light": 0.20, "active_light": 0.18, "recovery_light": 0.26,
				"lunge_light": 2.2, "damage_light": 16.0, "stagger_light": 12.0, "stamina_light": 16.0,
				"windup_heavy": 0.44, "active_heavy": 0.24, "recovery_heavy": 0.60,
				"lunge_heavy": 2.9, "damage_heavy": 34.0, "stagger_heavy": 28.0, "stamina_heavy": 30.0,
				"wam_light": 0.0, "wam_heavy": 0.2,
				"dodge_cancel": 0.6, "crit": 1.15,
				"grips": _grip(true, false, true, &"paired"),
				"mesh_shape": "curved", "mesh_color": "b1a88d",
				"hitbox_light": _hb(1.3, 1.4, Vector3(0.0, 1.0, -1.1)),
				"hitbox_heavy": _hb(1.45, 1.5, Vector3(0.0, 1.0, -1.3)),
				"heavy_tags": [&"side_rotate"],
				"leap_kind": &"crescent_leap",
				"leap_windup": 0.22, "leap_active": 0.2, "leap_recovery": 0.5,
				"leap_damage": 38.0, "leap_stagger": 30.0, "leap_stamina": 24.0,
				"leap_lunge": 3.6, "leap_velocity_y": 1.4, "leap_wam": 0.5,
			}
		&"fist":
			# 拳套/爪：极短覆盖、短连段、高风险偏转
			return {
				"style_id": &"fist",
				"display_name": "拳套",
				"windup_light": 0.16, "active_light": 0.12, "recovery_light": 0.20,
				"lunge_light": 1.3, "damage_light": 12.0, "stagger_light": 10.0, "stamina_light": 12.0,
				"windup_heavy": 0.40, "active_heavy": 0.16, "recovery_heavy": 0.50,
				"lunge_heavy": 1.6, "damage_heavy": 26.0, "stagger_heavy": 30.0, "stamina_heavy": 26.0,
				"wam_light": 0.0, "wam_heavy": 0.4,
				"dodge_cancel": 0.7, "crit": 1.0,
				"grips": _grip(false, false, true, &"paired"),
				"mesh_shape": "default", "mesh_color": "8b6f5a",
				"hitbox_light": _hb(0.85, 1.3, Vector3(0.0, 0.9, -0.7)),
				"hitbox_heavy": _hb(0.9, 1.35, Vector3(0.0, 0.9, -0.8)),
				"light_tags": [&"short_range"],
				"heavy_tags": [&"short_range"],
				"leap_kind": &"deflect_step",
				"leap_windup": 0.18, "leap_active": 0.12, "leap_recovery": 0.4,
				"leap_damage": 16.0, "leap_stagger": 14.0, "leap_stamina": 14.0,
				"leap_lunge": 1.6, "leap_velocity_y": 0.0, "leap_wam": 0.3,
				"leap_tags": [&"deflect"],
			}
		&"dagger":
			# 匕首：低基础伤害、高致命倍率，弹反处决/背刺/追击
			return {
				"style_id": &"dagger",
				"display_name": "匕首",
				"windup_light": 0.15, "active_light": 0.12, "recovery_light": 0.22,
				"lunge_light": 2.0, "damage_light": 10.0, "stagger_light": 8.0, "stamina_light": 12.0,
				"windup_heavy": 0.34, "active_heavy": 0.14, "recovery_heavy": 0.40,
				"lunge_heavy": 2.5, "damage_heavy": 20.0, "stagger_heavy": 16.0, "stamina_heavy": 20.0,
				"wam_light": 0.0, "wam_heavy": 0.1,
				"dodge_cancel": 0.65, "crit": 1.6,
				"grips": _grip(true, true, false, &"one_handed"),
				"mesh_shape": "dagger", "mesh_color": "b8c2ca",
				"hitbox_light": _hb(0.9, 1.35, Vector3(0.0, 1.0, -0.9)),
				"hitbox_heavy": _hb(1.0, 1.4, Vector3(0.0, 1.0, -1.0)),
				"light_tags": [&"crit_bonus"],
				"heavy_tags": [&"crit_bonus"],
				"leap_kind": &"",
				"backstab": true, "riposte": true,
			}
		&"shield":
			# 盾牌：盾击/推盾反制，高削韧低伤，重击打精力
			return {
				"style_id": &"shield",
				"display_name": "盾牌",
				"windup_light": 0.28, "active_light": 0.16, "recovery_light": 0.36,
				"lunge_light": 1.6, "damage_light": 14.0, "stagger_light": 20.0, "stamina_light": 20.0,
				"windup_heavy": 0.55, "active_heavy": 0.20, "recovery_heavy": 0.70,
				"lunge_heavy": 2.2, "damage_heavy": 24.0, "stagger_heavy": 44.0, "stamina_heavy": 32.0,
				"wam_light": 0.3, "wam_heavy": 0.7,
				"dodge_cancel": 0.3, "crit": 1.0,
				"grips": _grip(true, false, false, &"one_handed"),
				"mesh_shape": "shield", "mesh_color": "614725",
				"hitbox_light": _hb(1.15, 1.4, Vector3(0.0, 1.0, -1.0)),
				"hitbox_heavy": _hb(1.3, 1.45, Vector3(0.0, 1.0, -1.1)),
				"heavy_tags": [&"shield_pressure"],
				"leap_kind": &"shield_shove",
				"leap_windup": 0.35, "leap_active": 0.2, "leap_recovery": 0.7,
				"leap_damage": 28.0, "leap_stagger": 46.0, "leap_stamina": 22.0,
				"leap_lunge": 2.8, "leap_velocity_y": 0.0, "leap_wam": 0.9,
				"leap_tags": [&"shield_pressure"],
				"backstab": false, "riposte": true,
			}
	return {}
