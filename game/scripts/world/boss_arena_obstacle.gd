extends StaticBody3D
## Receives the same player melee/projectile payload as other combat bodies.
var effect_owner: Node3D

func receive_hit_payload(payload: Dictionary) -> void:
	if is_instance_valid(effect_owner):
		effect_owner.receive_impact(float(payload.get("damage", 0.)))

func apply_boss_impact(point: Vector3, radius: float) -> void:
	if not is_instance_valid(effect_owner):
		return
	var distance := global_position.distance_to(point)
	if distance <= radius + .4:
		effect_owner.receive_impact(100.)
