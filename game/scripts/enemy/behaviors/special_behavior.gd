# game/scripts/enemy/behaviors/special_behavior.gd
extends RefCounted
## G-05：特殊钩子 — 俯冲、分身占位、光环 tick

var behavior_id := ""
var dive_speed_scale := 1.6
var clone_spawned := false
var aura_ticks := 0
var last_special_hook := ""


func _init(behavior: String = "dive_bomb") -> void:
	behavior_id = behavior


func apply_profile_modifiers(enemy: Node) -> void:
	if behavior_id == "dive_bomb":
		enemy.set("move_speed", float(enemy.get("move_speed")) * 1.15)


func update_idle(enemy: Node, delta: float) -> void:
	var accel: float = float(enemy.get("acceleration"))
	var vel: Vector3 = enemy.get("velocity")
	vel.x = move_toward(vel.x, 0.0, accel * delta)
	vel.z = move_toward(vel.z, 0.0, accel * delta)
	enemy.set("velocity", vel)


func on_engage(enemy: Node, _target: Node3D) -> void:
	match behavior_id:
		"split_clone", "mirror_self":
			clone_spawned = true
			last_special_hook = "clone"
			enemy.set_meta("g05_clone_hook", true)
		"random_form":
			last_special_hook = "random_form"
			enemy.set_meta("g05_form_shift", true)
		_:
			pass


func on_attack_active(enemy: Node, target: Node3D) -> void:
	match behavior_id:
		"dive_bomb":
			last_special_hook = "dive"
			var body := enemy as Node3D
			if body == null or target == null or not is_instance_valid(target):
				return
			var offset: Vector3 = target.global_position - body.global_position
			offset.y = 0.0
			if offset.length_squared() > 0.01:
				var dir: Vector3 = offset.normalized()
				var speed: float = float(enemy.get("move_speed")) * dive_speed_scale
				var vel: Vector3 = enemy.get("velocity")
				vel.x = dir.x * speed
				vel.z = dir.z * speed
				enemy.set("velocity", vel)
		"soul_drain_aura":
			aura_ticks += 1
			last_special_hook = "aura"
			enemy.set_meta("g05_aura_ticks", aura_ticks)
		_:
			pass
