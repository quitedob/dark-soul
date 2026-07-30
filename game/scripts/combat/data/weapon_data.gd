class_name WeaponData
extends Resource
## 武器数据：按 grip 选择 Moveset；双持不直接翻倍致命伤害

@export var weapon_id: StringName
@export var weapon_class_id: StringName
@export var one_hand_moveset: MovesetData
@export var two_hand_moveset: MovesetData
@export var paired_moveset: MovesetData
@export var default_weapon_art: WeaponArtData
@export_range(0.5, 5.0, 0.05) var critical_multiplier := 1.0
@export var supports_backstab := true
@export var supports_riposte := true
@export var supports_one_handed := true
@export var supports_two_handed := false
@export var supports_paired := false
@export var default_grip: StringName = &"one_handed"


func resolve_moveset(grip_mode: StringName) -> MovesetData:
	match grip_mode:
		&"two_handed":
			if two_hand_moveset != null:
				return two_hand_moveset
		&"paired":
			if paired_moveset != null:
				return paired_moveset
	if one_hand_moveset != null:
		return one_hand_moveset
	if paired_moveset != null:
		return paired_moveset
	return two_hand_moveset


func supported_grips() -> Array[StringName]:
	var grips: Array[StringName] = []
	if supports_one_handed and one_hand_moveset != null:
		grips.append(&"one_handed")
	if supports_two_handed and two_hand_moveset != null:
		grips.append(&"two_handed")
	if supports_paired and paired_moveset != null:
		grips.append(&"paired")
	return grips


func cycle_grip(current: StringName) -> StringName:
	var grips := supported_grips()
	if grips.is_empty():
		return current
	var idx := grips.find(current)
	if idx < 0:
		return grips[0]
	return grips[(idx + 1) % grips.size()]


func validate() -> Array[String]:
	var errors: Array[String] = []
	if weapon_id.is_empty():
		errors.append("WeaponData weapon_id is empty.")
	if supported_grips().is_empty():
		errors.append("WeaponData %s has no supported grips." % weapon_id)
	for moveset in [one_hand_moveset, two_hand_moveset, paired_moveset]:
		if moveset != null:
			errors.append_array(moveset.validate())
	return errors
