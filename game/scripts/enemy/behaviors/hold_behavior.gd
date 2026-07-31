# game/scripts/enemy/behaviors/hold_behavior.gd
extends RefCounted
## G-05：守点族 — 更紧 leash、更低追击加速度

var behavior_id := ""
var leash_scale := 0.72
var chase_accel_scale := 0.65


func _init(behavior: String = "defensive_hold") -> void:
	behavior_id = behavior
	match behavior:
		"defensive_hold", "shield_wall":
			leash_scale = 0.65
			chase_accel_scale = 0.55
		"formation_fight":
			leash_scale = 0.8
			chase_accel_scale = 0.75
		"slow_berserk":
			leash_scale = 0.9
			chase_accel_scale = 1.15
		_:
			leash_scale = 0.72


func apply_profile_modifiers(enemy: Node) -> void:
	enemy.set("leash_range", float(enemy.get("leash_range")) * leash_scale)
	enemy.set("acceleration", float(enemy.get("acceleration")) * chase_accel_scale)


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
