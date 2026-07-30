class_name ChargeProfile
extends Resource
## 离散蓄力档：按住重击时间映射到三档 AttackData，不做连续伤害插值

@export var minimum_hold_seconds := 0.20
@export var tier_two_seconds := 0.75
@export var tier_three_seconds := 1.40
@export var tier_one_attack: AttackData
@export var tier_two_attack: AttackData
@export var tier_three_attack: AttackData
@export var release_on_stamina_failure := true


func resolve(hold_seconds: float) -> AttackData:
	if hold_seconds >= tier_three_seconds and tier_three_attack != null:
		return tier_three_attack
	if hold_seconds >= tier_two_seconds and tier_two_attack != null:
		return tier_two_attack
	if hold_seconds >= minimum_hold_seconds and tier_one_attack != null:
		return tier_one_attack
	# 短按：仍返回一档，由调用方也可改走 neutral_heavy
	return tier_one_attack


func validate() -> Array[String]:
	var errors: Array[String] = []
	if minimum_hold_seconds < 0.0 or tier_two_seconds < minimum_hold_seconds or tier_three_seconds < tier_two_seconds:
		errors.append("ChargeProfile has invalid tier thresholds.")
	for attack in [tier_one_attack, tier_two_attack, tier_three_attack]:
		if attack != null:
			errors.append_array(attack.validate())
		else:
			errors.append("ChargeProfile is missing a tier AttackData.")
	return errors
