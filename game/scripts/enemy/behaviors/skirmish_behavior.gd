# game/scripts/enemy/behaviors/skirmish_behavior.gd
extends RefCounted
## G-05：游走/远程距离带（复用 RangedAmbush 数学）

const RangedAmbushBehavior = preload("res://scripts/enemy/ranged_ambush_behavior.gd")

var behavior_id := ""
var preferred := 5.5
var retreat_at := 3.2
var lateral_bias := 0.35


func _init(behavior: String = "hit_and_run") -> void:
	behavior_id = behavior
	match behavior:
		"aggressive_flank":
			preferred = 3.8
			retreat_at = 2.2
			lateral_bias = 0.7
		"pack_hunter":
			preferred = 4.2
			retreat_at = 2.5
			lateral_bias = 0.5
		"swarm_flutter", "swarm_dive":
			preferred = 4.8
			retreat_at = 2.8
			lateral_bias = 0.9
		"ranged_ambush", "ranged_artillery", "ranged_barrage", "ranged_homing", "petal_barrage":
			preferred = 7.0
			retreat_at = 4.2
			lateral_bias = 0.25
		_:
			preferred = 5.5


func apply_profile_modifiers(enemy: Node) -> void:
	var content: Dictionary = enemy.get("chapter_content")
	if content.has("preferred_distance"):
		preferred = float(content.get("preferred_distance", preferred))
	if content.has("retreat_trigger"):
		retreat_at = float(content.get("retreat_trigger", retreat_at))


func update_idle(enemy: Node, delta: float) -> void:
	var accel: float = float(enemy.get("acceleration"))
	var vel: Vector3 = enemy.get("velocity")
	vel.x = move_toward(vel.x, 0.0, accel * delta)
	vel.z = move_toward(vel.z, 0.0, accel * delta)
	enemy.set("velocity", vel)


func on_engage(_enemy: Node, _target: Node3D) -> void:
	pass


func on_attack_active(_enemy: Node, _target: Node3D) -> void:
	pass


func desired_chase_velocity(from: Vector3, to: Vector3, move_speed: float) -> Vector3:
	var base: Vector3 = RangedAmbushBehavior.desired_horizontal_velocity(from, to, move_speed, preferred, retreat_at)
	var offset: Vector3 = to - from
	offset.y = 0.0
	if offset.length_squared() < 0.001:
		return base
	var side: Vector3 = offset.normalized().cross(Vector3.UP).normalized()
	return base + side * move_speed * lateral_bias
