extends CharacterBody3D
## Authored animated illusion / summoned fighter, owned by the encounter effect root.
signal despawned(clone)
const Resolver = preload("res://scripts/core/real_model_resolver.gd")
const Actions = preload("res://scripts/core/embedded_model_actions.gd")
var lifetime := 8.
var max_health := 40.
var health := 40.
var _dead := false
var attacker: Node3D
var target: Node3D
var reflect_damage := 0.
var fighter := false
var friendly := false
var blocking := false
var _attack_timer := 1.5
var _warning := false
var visual: Node3D

func setup(metadata: Dictionary = {}) -> void:
	lifetime = maxf(float(metadata.get("lifetime", 8.)), .1)
	max_health = maxf(float(metadata.get("health", 40.)), 1.)
	health = max_health
	attacker = metadata.get("attacker")
	target = metadata.get("target")
	reflect_damage = float(metadata.get("reflect_damage", 0.))
	fighter = bool(metadata.get("fighter", false))
	friendly = bool(metadata.get("friendly", false))
	blocking = bool(metadata.get("blocking", false))
	collision_layer = 4 | (1 if blocking else 0)
	collision_mask = 1
	if blocking: add_to_group("campaign_navigation_source")
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = .42
	capsule.height = 1.8
	collision.shape = capsule
	collision.position.y = .9
	add_child(collision)
	visual = Node3D.new()
	add_child(visual)
	var model := String(metadata.get("model_id", "enemy/body/by_id/boss_nine_tails"))
	if not Resolver.try_instance(model, visual):
		push_error("Boss apparition requires authored model: " + model)
	Actions.play_action(visual, "idle", true)

func _physics_process(delta: float) -> void:
	if _dead: return
	lifetime -= delta
	if lifetime <= 0.:
		_despawn()
		return
	if not fighter or not is_instance_valid(target): return
	if float(target.get("health")) <= 0.: return
	var offset := target.global_position - global_position
	offset.y = 0.
	_attack_timer -= delta
	if offset.length() > 2.1:
		var next := global_position + offset.normalized() * .9
		var ray := PhysicsRayQueryParameters3D.create(next + Vector3.UP, next - Vector3.UP * 1.8, 1)
		ray.exclude = [get_rid()]
		velocity = offset.normalized() * 2.4 if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty() else Vector3.ZERO
		velocity.y = -3.
		move_and_slide()
		Actions.play_action(visual, "walk")
	elif _attack_timer <= 0.:
		_attack_timer = 2.2
		_warning = false
		Actions.play_action(visual, "attack", true, .7)
		if target.has_method("receive_hit_payload"):
			target.receive_hit_payload({"damage": 8., "poise": 10., "stagger": 10., "source": attacker if is_instance_valid(attacker) else self, "direction": offset.normalized(), "tags": ["summoned_guardian"], "blockable": true, "parryable": true})
	elif _attack_timer < .6 and not _warning:
		_warning = true
		Actions.play_action(visual, "cast", true, .6)
	if offset.length_squared() > .01: rotation.y = atan2(-offset.x, -offset.z)

func is_targetable() -> bool:
	return not _dead and not friendly

func get_target_point() -> Vector3:
	return global_position + Vector3.UP * 1.2

func receive_hit(damage, _stagger, _direction, source) -> void:
	if _dead or float(damage) <= 0.: return
	health = maxf(health - float(damage), 0.)
	if reflect_damage > 0. and is_instance_valid(source) and source.has_method("receive_hit_payload"):
		source.receive_hit_payload({"damage": reflect_damage, "poise": 0., "stagger": 0., "source": attacker if is_instance_valid(attacker) else self, "direction": Vector3.ZERO, "tags": ["illusion_reflection"], "blockable": false, "parryable": false})
	if health <= 0.: _despawn()

func receive_hit_payload(payload: Dictionary) -> void:
	receive_hit(float(payload.get("damage", 0.)), 0., Vector3.ZERO, payload.get("source"))

func _expire() -> void:
	_despawn()

func _despawn() -> void:
	if _dead: return
	_dead = true
	despawned.emit(self)
	queue_free()
