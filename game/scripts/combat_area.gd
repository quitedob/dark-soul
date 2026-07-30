extends Area3D

signal hit_landed(is_heavy: bool)

var damage := 10.0
var stagger := 10.0
var source: Node
var active := false
var hit_payload: Dictionary = {}
var already_hit: Dictionary = {}


func _ready() -> void:
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)


func configure(new_source: Node, radius: float, height: float = 1.2) -> void:
	source = new_source
	collision_layer = 0
	if source != null and source.is_in_group("player"):
		collision_mask = 4
	else:
		collision_mask = 2
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = radius
	capsule.height = maxf(height, radius * 2.0)
	shape.shape = capsule
	add_child(shape)
	monitoring = false


func begin_swing(new_damage: float, new_stagger: float, metadata: Dictionary = {}) -> void:
	damage = new_damage
	stagger = new_stagger
	hit_payload = {
		"damage": damage,
		"stagger": stagger,
		"poise": stagger,
		"guard_damage": metadata.get("guard_damage", damage + stagger * 0.25),
		"direction": Vector3.ZERO,
		"source": source,
		"hand": String(metadata.get("hand", "right")),
		"item_id": String(metadata.get("item_id", "")),
		"action_id": String(metadata.get("action_id", "legacy_swing")),
		"tags": metadata.get("tags", []).duplicate(),
		"blockable": bool(metadata.get("blockable", true)),
		"parryable": bool(metadata.get("parryable", true)),
	}
	already_hit.clear()
	active = true
	monitoring = true


func end_swing() -> void:
	active = false
	monitoring = false
	already_hit.clear()


func _on_body_entered(body: Node3D) -> void:
	if not active or body == source or already_hit.has(body):
		return
	if not body.has_method("receive_hit"):
		return
	already_hit[body] = true
	var hit_direction := Vector3.ZERO
	if source is Node3D:
		hit_direction = (body.global_position - source.global_position).normalized()
	var payload := hit_payload.duplicate(true)
	payload["direction"] = hit_direction
	payload["source"] = source
	if body.has_method("receive_hit_payload"):
		body.receive_hit_payload(payload)
	else:
		body.receive_hit(
			float(payload["damage"]),
			float(payload["stagger"]),
			hit_direction,
			source
		)
	hit_landed.emit(float(payload["damage"]) >= 30.0)
