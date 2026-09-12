extends Node3D
## Scene-owned warning → physical obstacle / floor hazard. No global time changes.
signal activated(effect: Node3D)
signal broken(effect: Node3D)
signal navigation_changed

var source: Node3D
var specification: Dictionary = {}
var active := false
var impact_applied := false
var hit_count := 0
var broken_by_impact := false
var _elapsed := 0.0
var _active_elapsed := 0.0
var _next_tick := 0.0
var _area: Area3D
var _blocker: StaticBody3D
var _block_shape: CollisionShape3D
var _marker: MeshInstance3D
var _obstacle: MeshInstance3D
var _material: StandardMaterial3D
var _durability := 45.0
var _slowed: Dictionary = {}
var _collision_enabled := false


func setup(owner_boss: Node3D, data: Dictionary) -> void:
	source = owner_boss
	specification = data.duplicate(true)
	name = "ArenaEffect_" + String(data.get("id", data.get("kind", "ember")))
	add_to_group("boss_arena_effects")
	_area = Area3D.new()
	_area.collision_layer = 0
	_area.collision_mask = 2
	_area.monitorable = false
	_area.monitoring = false
	add_child(_area)
	var area_shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = float(data.get("radius", 1.5))
	cylinder.height = 2.8
	area_shape.shape = cylinder
	area_shape.position.y = 1.0
	_area.add_child(area_shape)
	_material = StandardMaterial3D.new()
	_material.albedo_color = Color(.28, .16, .035, .78)
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.emission_enabled = true
	_material.emission = Color(1., .55, .12)
	_material.emission_energy_multiplier = .65
	_material.roughness = .85
	_marker = MeshInstance3D.new()
	var disk := CylinderMesh.new()
	disk.top_radius = cylinder.radius
	disk.bottom_radius = cylinder.radius
	disk.height = .055
	disk.radial_segments = 32
	_marker.mesh = disk
	_marker.position.y = .035
	_marker.material_override = _material
	add_child(_marker)
	if bool(data.get("blocker", false)):
		_build_blocker(data)
	set_physics_process(true)


func _build_blocker(data: Dictionary) -> void:
	_blocker = StaticBody3D.new()
	_blocker.collision_layer = 1 | 4 # World collision + player weapon/projectile query.
	_blocker.collision_mask = 0
	_blocker.set_meta("arena_effect", self)
	_blocker.set_script(preload("res://scripts/world/boss_arena_obstacle.gd"))
	_blocker.set("effect_owner", self)
	_blocker.add_to_group("destructibles")
	_blocker.add_to_group("campaign_navigation_source")
	add_child(_blocker)
	_block_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(float(data.get("width", 3.0)), 1.8, .7)
	_block_shape.shape = box
	_block_shape.position.y = .9
	_block_shape.disabled = true
	_blocker.add_child(_block_shape)
	_obstacle = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = box.size
	_obstacle.mesh = mesh
	_obstacle.position.y = .9
	_obstacle.material_override = _material
	_obstacle.visible = false
	_blocker.add_child(_obstacle)


func _physics_process(delta: float) -> void:
	if broken_by_impact or is_queued_for_deletion():
		return
	_elapsed += delta
	if not active:
		_material.emission_energy_multiplier = .65 + .4 * sin(_elapsed * 13.)
		if _elapsed >= maxf(.15, float(specification.get("warning", 1.2))):
			_activate()
		return
	_active_elapsed += delta
	var lifetime := float(specification.get("lifetime", 12.))
	if lifetime > 0. and _active_elapsed >= lifetime:
		queue_free()
		return
	if _block_shape != null and _block_shape.disabled:
		_enable_unoccupied_blocker()
	if _active_elapsed >= _next_tick:
		_next_tick = _active_elapsed + maxf(.2, float(specification.get("interval", 1.)))
		for body in _area.get_overlapping_bodies():
			_apply_to_body(body)


func _activate() -> void:
	active = true
	_area.set_deferred("monitoring", true)
	var color := Color(String(specification.get("color", "ce612e")))
	_material.albedo_color = Color(color, .76)
	_material.emission = color
	_material.emission_energy_multiplier = .8
	if _obstacle != null:
		_obstacle.visible = true
		_enable_unoccupied_blocker()
	# Area monitoring publishes on a later physics frame. Sweep the authored
	# volume once now so a slow-ticking field cannot miss its activation hit.
	var shape := _area.get_child(0) as CollisionShape3D
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape.shape
	query.transform = shape.global_transform
	query.collision_mask = 2
	for hit: Dictionary in get_world_3d().direct_space_state.intersect_shape(query, 32):
		_apply_to_body(hit["collider"])
	_next_tick = maxf(.2, float(specification.get("interval", 1.)))
	activated.emit(self)


func _enable_unoccupied_blocker() -> void:
	# Never materialize collision through an actor standing in the warning.
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _block_shape.shape
	query.transform = _block_shape.global_transform
	query.collision_mask = 2 | 4
	query.exclude = [_blocker.get_rid()]
	if get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
		_block_shape.set_deferred("disabled", false)
		if not _collision_enabled:
			_collision_enabled = true
			call_deferred("_notify_navigation_changed")


func _apply_to_body(body: Node3D) -> void:
	if not is_instance_valid(body) or body == source:
		return
	var amount := maxf(0., float(specification.get("damage", 0.)))
	if amount > 0. and body.has_method("receive_hit_payload"):
		body.receive_hit_payload({"damage": amount, "stagger": 0., "poise": 0.,
			"direction": (body.global_position - global_position).normalized(),
			"source": source if is_instance_valid(source) else null,
			"action_id": String(specification.get("id", "arena_floor")),
			"tags": ["boss", "hazard", "arena"], "blockable": false, "parryable": false})
		hit_count += 1
	var slow := float(specification.get("slow", 1.))
	if slow < 1.:
		body.set_meta("arena_slow_owner", get_instance_id())
		body.set_meta("g06_time_dilation", slow)
		body.set_meta("g06_time_dilation_ttl", maxf(.25, float(specification.get("interval", 1.)) + .1))
		_slowed[body.get_instance_id()] = weakref(body)
	var pull := float(specification.get("pull", 0.))
	if pull > 0. and body is CharacterBody3D:
		var direction := global_position - body.global_position
		direction.y = 0.
		if direction.length() > .2:
			body.velocity += direction.normalized() * pull
	if int(specification.get("drain_embers", 0)) > 0 and body.has_method("add_embers"):
		body.add_embers(-int(specification["drain_embers"]))
	if float(specification.get("drain_focus", 0.)) > 0. and body.has_method("set_focus"):
		body.set_focus(maxf(0., float(body.get("focus")) - float(specification["drain_focus"])))


func receive_impact(amount: float) -> void:
	if broken_by_impact or not active:
		return
	_durability -= maxf(amount, 0.)
	if _durability <= 0.:
		broken_by_impact = true
		if _block_shape != null:
			_block_shape.set_deferred("disabled", true)
		broken.emit(self)
		queue_free()


func _exit_tree() -> void:
	if _collision_enabled:
		navigation_changed.emit()
	# Do not leave a scene-owned slow behind after death, reset, or a transition.
	for reference: WeakRef in _slowed.values():
		var body = reference.get_ref()
		if is_instance_valid(body) and int(body.get_meta("arena_slow_owner", 0)) == get_instance_id():
			for key in ["arena_slow_owner", "g06_time_dilation", "g06_time_dilation_ttl"]:
				if body.has_meta(key):
					body.remove_meta(key)


func _notify_navigation_changed() -> void:
	if is_inside_tree() and not is_queued_for_deletion():
		navigation_changed.emit()
