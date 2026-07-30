class_name MovesetData
extends Resource

@export var moveset_id: StringName
@export var grip_mode: StringName = &"one_handed"
@export var neutral_light: AttackData
@export var neutral_heavy: AttackData
@export var charged_heavy: ChargeProfile
@export var sprint_attack: AttackData
@export var roll_attack: AttackData
@export var backstep_attack: AttackData
@export var jump_attack: AttackData
@export var falling_attack: AttackData
@export var guard_counter: AttackData
@export var weapon_art_light: AttackData
@export var weapon_art_heavy: AttackData


func resolve(context: StringName) -> AttackData:
	match context:
		&"neutral_light": return neutral_light
		&"neutral_heavy": return neutral_heavy
		&"sprint": return sprint_attack
		&"roll_recovery": return roll_attack
		&"backstep_recovery": return backstep_attack
		&"jump": return jump_attack
		&"falling": return falling_attack
		&"guard_counter": return guard_counter
		&"weapon_art_light": return weapon_art_light
		&"weapon_art_heavy": return weapon_art_heavy
		&"leap": return weapon_art_heavy  # leap 兵器诀挂在 weapon_art_heavy
	return null


func resolve_charged(hold_seconds: float) -> AttackData:
	# 蓄力档位解析；无配置时回退中立重击
	if charged_heavy != null:
		var tier := charged_heavy.resolve(hold_seconds)
		if tier != null:
			return tier
	return neutral_heavy


func validate() -> Array[String]:
	var errors: Array[String] = []
	if moveset_id.is_empty():
		errors.append("Moveset ID is empty.")
	for attack in [neutral_light, neutral_heavy, sprint_attack, roll_attack, backstep_attack, jump_attack, falling_attack, guard_counter, weapon_art_light, weapon_art_heavy]:
		if attack != null:
			errors.append_array(attack.validate())
	if charged_heavy != null:
		errors.append_array(charged_heavy.validate())
	return errors
