extends Resource
class_name GrabProfile
## 独立抓投配置：不得走普通 CombatArea 伤害路径

@export var grab_id: StringName = &"boss_grab"
@export_range(0.2, 4.0, 0.05) var telegraph_seconds := 1.25
@export_range(0.2, 4.0, 0.05) var recovery_on_miss_seconds := 1.1
@export_range(0.2, 4.0, 0.05) var hold_seconds := 1.35
@export_range(0.0, 2.0, 0.01) var damage_event_seconds := 0.45
@export_range(1.0, 200.0, 0.5) var grab_damage := 34.0
@export_range(0.5, 4.0, 0.05) var capture_radius := 1.35
@export var capture_socket: StringName = &"hand"
@export var hold_socket_offset := Vector3(0.0, 1.15, -1.05)
@export var camera_shot_id: StringName = &"grab_hold"
@export var initiator_animation: StringName = &"grab_init"
@export var victim_animation: StringName = &"grabbed"
@export var damage_event_name: StringName = &"grab_damage"
@export var escape_rule: StringName = &"dodge_only"
@export var blockable := false
@export var parryable := false


static func make_boss_default() -> Resource:
	var g = load("res://scripts/combat/data/grab_profile.gd").new()
	g.grab_id = &"boss_grab"
	g.telegraph_seconds = 1.35
	g.recovery_on_miss_seconds = 1.2
	g.hold_seconds = 1.4
	g.grab_damage = 36.0
	g.capture_radius = 1.45
	g.hold_socket_offset = Vector3(0.0, 1.15, -1.05)
	g.camera_shot_id = &"grab_hold"
	return g


func validate() -> Array[String]:
	var errors: Array[String] = []
	if grab_id.is_empty():
		errors.append("GrabProfile grab_id empty.")
	if capture_radius <= 0.0 or grab_damage < 0.0:
		errors.append("GrabProfile %s has invalid ranges." % grab_id)
	return errors
