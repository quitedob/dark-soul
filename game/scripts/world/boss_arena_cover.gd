extends StaticBody3D
## Authored chapter architecture with matching physical, destructible cover.
signal broken(source_position: Vector3)
const EnvironmentRenderer = preload("res://scripts/world/campaign_environment_renderer.gd")
const SIZE := Vector3(2., 3., 2.)
var collision: CollisionShape3D
var materials: Array[StandardMaterial3D] = []
var durability := 80.0
var ember_reward := 0
var is_broken := false


func setup(theme: StringName) -> bool:
	var visual := EnvironmentRenderer.instantiate_part(theme, "ArenaCover")
	if visual == null:
		return false
	collision_layer = 1 | 4
	collision_mask = 0
	add_to_group("arena_chunks")
	add_to_group("destructibles")
	add_to_group("campaign_navigation_source")
	add_child(visual)
	set_meta("kit_path", visual.get_meta("kit_path"))
	set_meta("kit_part", "ArenaCover")
	for mesh: MeshInstance3D in visual.find_children("*", "MeshInstance3D", true, false):
		var original := mesh.get_active_material(0) as StandardMaterial3D
		if original != null:
			var material := original.duplicate() as StandardMaterial3D
			mesh.material_override = material
			materials.append(material)
	collision = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = SIZE
	collision.shape = box
	collision.position.y = SIZE.y * .5
	add_child(collision)
	return true


func set_warning(amount: float) -> void:
	for material in materials:
		material.emission_enabled = true
		material.emission = Color("ff5522")
		material.emission_energy_multiplier = amount


func receive_hit_payload(payload: Dictionary) -> void:
	if is_broken:
		return
	durability -= maxf(0., float(payload.get("damage", 0.)))
	if durability <= 0.:
		is_broken = true
		collision.set_deferred("disabled", true)
		broken.emit(payload.get("source_position", global_position))
		queue_free()


func apply_boss_impact(point: Vector3, radius: float) -> void:
	var offset := global_position - point
	offset.y = 0.
	if offset.length() <= radius + SIZE.x * .5:
		receive_hit_payload({"damage": durability, "source_position": point})
