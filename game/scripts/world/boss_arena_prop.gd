extends StaticBody3D
## A modeled encounter object: authoritative hit body, interaction and reset state.
signal broken(source_position: Vector3)
const Interaction = preload("res://scripts/world/samsara_fork_interact.gd")
var arena: Node3D
var role := ""
var part_id := ""
var specification: Dictionary = {}
var durability := 80.0
var ember_reward := 0
var is_broken := false
var hits := 0
var enabled := true
var visual: Node3D
var interaction: Area3D
var materials: Array[StandardMaterial3D] = []
var _shapes: Array[CollisionShape3D] = []
var _base_transform := Transform3D.IDENTITY
var _motion: Tween

func setup(controller: Node3D, data: Dictionary) -> bool:
	arena = controller
	specification = data.duplicate(true)
	role = String(data["role"])
	part_id = String(data["part"])
	name = role
	var renderer = load("res://scripts/world/campaign_story_prop_renderer.gd")
	if renderer == null:
		push_error("Boss story scenery renderer is required")
		return false
	visual = renderer.instantiate_part(part_id)
	if visual == null:
		return false
	add_child(visual)
	var factor := float(data.get("scale", 1.0))
	visual.scale = Vector3.ONE * factor
	var definition: Dictionary = renderer.get_part_definition(part_id)
	collision_layer = 1 | 4
	collision_mask = 0
	add_to_group("boss_story_props")
	add_to_group("destructibles")
	add_to_group("campaign_navigation_source")
	set_meta("kit_part", part_id)
	set_meta("boss_story_role", role)
	for raw: Dictionary in definition.get("navigation_boxes", []):
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		var extent: Array = raw["size"]
		var center: Array = raw["center"]
		box.size = Vector3(float(extent[0]), float(extent[1]), float(extent[2])) * factor
		shape.shape = box
		shape.position = Vector3(float(center[0]), float(center[1]), float(center[2])) * factor
		add_child(shape)
		_shapes.append(shape)
	if _shapes.is_empty():
		var bounds: Dictionary = definition["bounds"]
		var size_values: Array = bounds["size"]
		var min_values: Array = bounds["min"]
		var size := Vector3(float(size_values[0]), float(size_values[1]), float(size_values[2])) * factor
		var minimum := Vector3(float(min_values[0]), float(min_values[1]), float(min_values[2])) * factor
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		shape.position = minimum + size * .5
		add_child(shape)
		_shapes.append(shape)
	for mesh: MeshInstance3D in visual.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var original := mesh.get_active_material(surface) as StandardMaterial3D
			if original != null:
				var material := original.duplicate() as StandardMaterial3D
				mesh.set_surface_override_material(surface, material)
				materials.append(material)
	interaction = Interaction.new()
	interaction.collision_layer = 8
	interaction.collision_mask = 0
	interaction.add_to_group("interactable")
	interaction.world_callback = _interact
	var interact_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.6
	interact_shape.shape = sphere
	interact_shape.position.y = .8
	interaction.add_child(interact_shape)
	add_child(interaction)
	set_prompt(String(data.get("prompt", "")))
	durability = float(data.get("health", 80.))
	_base_transform = visual.transform
	return true

func set_prompt(prompt: String) -> void:
	if not is_instance_valid(interaction):
		return
	interaction.prompt_text = prompt
	interaction.set_deferred("monitorable", not prompt.is_empty() and not is_broken and enabled)

func _interact(_area: Node, actor: Node) -> void:
	if actor is Node3D and is_instance_valid(arena):
		arena.try_interact(self, actor)

func can_reach(actor: Node3D) -> bool:
	return enabled and not is_broken and is_instance_valid(actor) and actor.global_position.distance_to(global_position) <= 4.0

func receive_hit_payload(payload: Dictionary) -> void:
	if is_broken or not enabled or not is_instance_valid(arena):
		return
	if arena.on_prop_hit(self, payload):
		return
	if not bool(specification.get("destructible", false)):
		return
	durability -= maxf(0., float(payload.get("damage", 0.)))
	if durability <= 0.:
		break_apart(payload.get("source_position", global_position))

func receive_hit(damage, stagger, direction, source) -> void:
	receive_hit_payload({"damage": damage, "stagger": stagger, "direction": direction, "source": source})

func apply_boss_impact(point: Vector3, radius: float) -> void:
	var offset := global_position - point
	offset.y = 0.
	if offset.length() <= radius + float(specification.get("impact_radius", 1.0)):
		receive_hit_payload({"damage": 100., "source": arena.boss if is_instance_valid(arena) else null, "source_position": point, "tags": ["boss_impact"]})

func break_apart(point := Vector3.ZERO) -> void:
	if is_broken:
		return
	is_broken = true
	set_prompt("")
	for shape in _shapes:
		shape.set_deferred("disabled", true)
	broken.emit(point)
	if is_instance_valid(arena):
		arena.on_prop_broken(self)
	if part_id == "DecoyBell":
		var renderer = load("res://scripts/world/campaign_story_prop_renderer.gd")
		var cracked: Node3D = renderer.instantiate_part("DecoyBellBroken")
		if cracked != null:
			visual.visible = false
			cracked.name = "BrokenVisual"
			cracked.scale = visual.scale
			add_child(cracked)
	else:
		_motion = create_tween()
		_motion.tween_property(visual, "scale:y", .08, .55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_motion.tween_callback(visual.hide)

func illuminate(color: Color, energy := .7) -> void:
	for material in materials:
		material.emission_enabled = energy > 0.
		material.emission = color
		material.emission_energy_multiplier = energy

func set_enabled(value: bool) -> void:
	enabled = value
	visible = value
	for shape in _shapes:
		shape.set_deferred("disabled", not value or is_broken)
	set_prompt(String(specification.get("prompt", "")) if value else "")

func reset_prop() -> void:
	if _motion != null and _motion.is_valid():
		_motion.kill()
	var broken_visual := get_node_or_null("BrokenVisual")
	if broken_visual != null:
		broken_visual.queue_free()
	is_broken = false
	hits = 0
	durability = float(specification.get("health", 80.))
	visual.transform = _base_transform
	visual.show()
	illuminate(Color.WHITE, 0.)
	set_enabled(true)
