class_name CompatibilityMovesetFactory
extends RefCounted
## 兼容招式工厂：风格 → WeaponData（含 grip Moveset + 三档蓄力）


static func create(style: CombatStyleData, grip_mode: StringName = &"one_handed") -> MovesetData:
	var moveset := MovesetData.new()
	moveset.moveset_id = StringName("%s_%s_moveset" % [style.style_id, grip_mode])
	moveset.grip_mode = grip_mode
	var g := _grip_scale(grip_mode)
	moveset.neutral_light = _attack(style, false, g)
	moveset.neutral_heavy = _attack(style, true, g)
	moveset.sprint_attack = _derive(
		style, false, "sprint", g,
		1.12, 1.08, 0.82, 1.0, 0.88, 1.55,
		[&"melee", &"light", &"sprint"]
	)
	moveset.roll_attack = _derive(
		style, false, "roll", g,
		1.06, 0.95, 0.68, 0.92, 0.82, 1.25,
		[&"melee", &"light", &"roll"]
	)
	moveset.backstep_attack = _derive(
		style, false, "backstep", g,
		1.0, 0.9, 0.72, 0.88, 0.78, 0.85,
		[&"melee", &"light", &"backstep"]
	)
	moveset.jump_attack = _derive(
		style, false, "jump", g,
		1.1, 1.0, 0.72, 1.15, 0.9, 0.35,
		[&"melee", &"light", &"jump"]
	)
	_set_hitbox(moveset.jump_attack, 0.95, 1.55, Vector3(0.0, 1.05, 0.0), &"weapon_tip")
	moveset.falling_attack = _derive(
		style, true, "falling", g,
		1.35, 1.18, 0.35, 1.0, 0.95, 0.12,
		[&"melee", &"heavy", &"falling", &"plunge"],
		-12.0
	)
	moveset.falling_attack.active_seconds = maxf(moveset.falling_attack.active_seconds, 1.35)
	moveset.falling_attack.hitbox_until_land = true
	_set_hitbox(moveset.falling_attack, 1.05, 2.55, Vector3(0.0, -0.1, -0.3), &"")
	moveset.charged_heavy = _build_charge_profile(style, g, moveset.neutral_heavy)
	if style.leap_active > 0.0:
		moveset.weapon_art_heavy = _leap(style)
		_set_hitbox(moveset.weapon_art_heavy, 1.2, 1.55, Vector3(0.0, 1.05, 0.0), &"weapon_tip")
	_append_grip_tag(moveset, grip_mode)
	return moveset


static func create_weapon(style: CombatStyleData) -> WeaponData:
	var weapon := WeaponData.new()
	weapon.weapon_id = style.style_id
	weapon.weapon_class_id = style.style_id
	var flags := _style_grip_flags(style.style_id)
	weapon.supports_one_handed = flags["one"]
	weapon.supports_two_handed = flags["two"]
	weapon.supports_paired = flags["paired"]
	weapon.default_grip = flags["default"]
	weapon.critical_multiplier = float(flags["crit"])
	if weapon.supports_one_handed:
		weapon.one_hand_moveset = create(style, &"one_handed")
	if weapon.supports_two_handed:
		weapon.two_hand_moveset = create(style, &"two_handed")
	if weapon.supports_paired:
		weapon.paired_moveset = create(style, &"paired")
	return weapon


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
	attack.poise_modifier_active = minf(heavy_base.poise_modifier_active * float(g["wam"]) + extra_wam, 1.5)
	if &"charged" not in attack.tags:
		attack.tags.append(&"charged")
	if &"heavy" not in attack.tags:
		attack.tags.append(&"heavy")
	return attack


static func _attack(style: CombatStyleData, heavy: bool, g: Dictionary) -> AttackData:
	var attack := AttackData.new()
	attack.action_id = StringName("%s_%s" % [style.style_id, "heavy" if heavy else "light"])
	attack.display_name_key = attack.action_id
	attack.windup_seconds = (style.windup_heavy if heavy else style.windup_light) * float(g["windup"])
	attack.active_seconds = (style.active_heavy if heavy else style.active_light) * float(g["active"])
	attack.recovery_seconds = (style.recovery_heavy if heavy else style.recovery_light) * float(g["recovery"])
	attack.stamina_cost = (style.stamina_heavy if heavy else style.stamina_light) * float(g["stamina"])
	attack.damage = (style.damage_heavy if heavy else style.damage_light) * float(g["damage"])
	attack.poise_damage = (style.stagger_heavy if heavy else style.stagger_light) * float(g["poise"])
	attack.guard_power = attack.damage + attack.poise_damage * 0.35
	var lunge := (style.lunge_heavy if heavy else style.lunge_light) * float(g["lunge"])
	attack.authored_displacement = Vector3(0.0, 0.0, lunge)
	attack.poise_modifier_active = (style.wam_heavy if heavy else style.wam_light) * float(g["wam"])
	attack.tags = [&"melee", &"heavy" if heavy else &"light"]
	_set_hitbox(attack, 1.25, 1.45, Vector3(0.0, 1.0, -1.0))
	return attack


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
	leap.poise_modifier_active = style.wam_leap
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
	launch_y: float = 0.0
) -> AttackData:
	var base := _attack(style, heavy, g)
	var attack := AttackData.new()
	attack.action_id = StringName("%s_%s" % [style.style_id, suffix])
	attack.display_name_key = attack.action_id
	attack.windup_seconds = maxf(base.windup_seconds * windup_mul, 0.08)
	attack.active_seconds = maxf(base.active_seconds * active_mul, 0.08)
	attack.recovery_seconds = maxf(base.recovery_seconds * recovery_mul, 0.1)
	attack.damage = maxf(base.damage * damage_mul, 8.0 if base.damage <= 0.0 else base.damage * damage_mul)
	attack.poise_damage = maxf(base.poise_damage * damage_mul, 6.0 if base.poise_damage <= 0.0 else base.poise_damage * damage_mul)
	attack.stamina_cost = maxf(base.stamina_cost * stamina_mul, 10.0 if base.stamina_cost <= 0.0 else base.stamina_cost * stamina_mul)
	attack.guard_power = attack.damage + attack.poise_damage * 0.35
	attack.authored_displacement = Vector3(0.0, 0.0, base.authored_displacement.z * lunge_mul)
	attack.launch_velocity_y = launch_y
	attack.poise_modifier_active = base.poise_modifier_active
	attack.tags = tags.duplicate()
	attack.hitbox_radius = base.hitbox_radius
	attack.hitbox_height = base.hitbox_height
	attack.hitbox_offset = base.hitbox_offset
	return attack
