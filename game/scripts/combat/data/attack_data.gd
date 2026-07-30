class_name AttackData
extends Resource

@export var action_id: StringName
@export var display_name_key: StringName
@export var animation_name: StringName
@export var hand: StringName = &"right"
@export var tags: Array[StringName] = []
@export_group("Timeline")
@export_range(0.0, 5.0, 0.01) var windup_seconds := 0.30
@export_range(0.01, 2.0, 0.01) var active_seconds := 0.15
@export_range(0.0, 5.0, 0.01) var recovery_seconds := 0.35
@export_range(-1.0, 5.0, 0.01) var dodge_cancel_seconds := -1.0
@export_group("Costs")
@export_range(0.0, 200.0, 0.5) var stamina_cost := 20.0
@export_range(0.0, 200.0, 0.5) var focus_cost := 0.0
@export_group("Hit Payload")
@export_range(0.0, 1000.0, 0.5) var damage := 20.0
@export_range(0.0, 500.0, 0.5) var poise_damage := 16.0
@export_range(0.0, 500.0, 0.5) var guard_power := 24.0
@export_range(0.0, 500.0, 0.5) var execution_break_damage := 0.0
@export var blockable := true
@export var parryable := true
@export_group("Movement")
@export var authored_displacement := Vector3.ZERO
@export var launch_velocity_y := 0.0
@export_group("Action Armor")
@export_range(0.0, 2.0, 0.01) var poise_modifier_windup := 0.0
@export_range(0.0, 2.0, 0.01) var poise_modifier_active := 0.0
@export_range(0.0, 2.0, 0.01) var poise_modifier_recovery := 0.0
@export_group("Hitbox")
## 胶囊半径 / 高度；无 socket 时 offset 相对玩家，有 socket 时相对挂点本地坐标
@export var hitbox_radius := 1.25
@export var hitbox_height := 1.45
@export var hitbox_offset := Vector3(0.0, 1.0, -1.0)
## 空 = 玩家根；weapon_tip = 跟随武器 tip
@export var hitbox_socket: StringName = &""
@export var maximum_hits_per_target := 1
@export var repeat_hit_interval_seconds := 0.0
## 下落类：主动段可持续到落地（受 active_seconds 上限约束）
@export var hitbox_until_land := false


func validate() -> Array[String]:
	var errors: Array[String] = []
	if action_id.is_empty():
		errors.append("Attack action_id is empty.")
	if active_seconds <= 0.0 or windup_seconds < 0.0 or recovery_seconds < 0.0:
		errors.append("Attack %s has invalid timeline values." % action_id)
	if dodge_cancel_seconds > recovery_seconds:
		errors.append("Attack %s dodge cancel exceeds recovery." % action_id)
	if maximum_hits_per_target < 1:
		errors.append("Attack %s has no valid hit count." % action_id)
	if hitbox_radius <= 0.0 or hitbox_height <= 0.0:
		errors.append("Attack %s has invalid hitbox size." % action_id)
	if &"unblockable" in tags and blockable:
		errors.append("Attack %s is tagged unblockable but blockable is true." % action_id)
	if &"unparryable" in tags and parryable:
		errors.append("Attack %s is tagged unparryable but parryable is true." % action_id)
	return errors


func to_hit_metadata(item_id: String) -> Dictionary:
	return {
		"hand": String(hand),
		"item_id": item_id,
		"action_id": String(action_id),
		"guard_damage": guard_power,
		"execution_break_damage": execution_break_damage,
		"tags": tags.duplicate(),
		"is_heavy": &"heavy" in tags,
		"blockable": blockable,
		"parryable": parryable,
		"hitbox_radius": hitbox_radius,
		"hitbox_height": hitbox_height,
		"hitbox_offset": hitbox_offset,
		"hitbox_socket": String(hitbox_socket),
		"hitbox_until_land": hitbox_until_land,
	}
