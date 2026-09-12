extends StaticBody3D
## Separate physical mouth volume: the main body remains the health receiver.
var arena: Node3D
func setup(owner_arena: Node3D) -> void:
	arena = owner_arena
	name = "BellMouthWeakpoint"
	collision_layer = 4
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = .65
	shape.shape = sphere
	add_child(shape)

func _physics_process(_delta: float) -> void:
	if is_instance_valid(arena) and is_instance_valid(arena.boss):
		global_position = arena.boss.get_execution_anchor(&"bell_mouth")

func receive_hit_payload(payload: Dictionary) -> void:
	if is_instance_valid(arena) and payload.get("source") == arena.player and float(payload.get("damage", 0.)) > 0.:
		arena.register_mouth_hit()

func receive_hit(damage, stagger, direction, source) -> void:
	receive_hit_payload({"damage": damage, "stagger": stagger, "direction": direction, "source": source})
