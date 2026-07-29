extends Area3D

signal hit_landed(is_heavy: bool)

var damage := 10.0
var stagger := 10.0
var source: Node
var active := false
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


func begin_swing(new_damage: float, new_stagger: float) -> void:
	damage = new_damage
	stagger = new_stagger
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
	body.receive_hit(damage, stagger, hit_direction, source)
	hit_landed.emit(damage >= 30.0)
