extends Node3D
## A level-owned escape, independent of the defeated boss and its AI lifetime.
const Renderer = preload("res://scripts/world/campaign_environment_renderer.gd")
signal completed
signal failed
signal navigation_changed
var platforms: Array[StaticBody3D] = []
var checkpoint := Vector3.ZERO
var goal := Vector3.ZERO
var actor: Node3D
var active := false
var remaining := 90.
var warned: Dictionary = {}
var collapsed: Dictionary = {}
var visited: Dictionary = {}
var retries := 0
var _origin := Vector3.ZERO
var _generation := 0
var _motions: Array[Tween] = []

func setup(player: Node3D, arena_center: Vector3, arena_radius: float) -> void:
	actor = player
	# Beyond the eastern arena wall and above all authored ground. Falling off
	# the course is judged before any unrelated lower level can catch the actor.
	_origin = arena_center + Vector3(arena_radius + 24., 22., 0.)
	var world: Node = get_parent().world
	# Physics resource bounds are available before the first renderer frame and
	# include the persistent world's collision as well as the current level.
	for collision: CollisionShape3D in world.find_children("*", "CollisionShape3D", true, false):
		if is_ancestor_of(collision) or not collision.get_parent() is StaticBody3D: continue
		if collision.shape == null or collision.get_parent().collision_layer & 1 == 0: continue
		var bounds: AABB = collision.global_transform * collision.shape.get_debug_mesh().get_aabb()
		_origin.x = maxf(_origin.x, bounds.end.x + 12.)
	name = "FallingCelestialCauseway"
	for index in 13:
		var at := _origin + Vector3(sin(float(index) * PI * .5) * 1.3, float(index % 4) * .7, -8. * index)
		var pad := _platform("Court%02d" % index, at, Vector3(5.4, .4, 6.))
		pad.set_meta("course_index", index)
		if index > 0 and index % 3 != 0:
			var previous := platforms[index - 1].position
			var delta := at - previous
			var length := Vector2(delta.x, delta.z).length()
			# Join the platform edges at their exact top heights. A slope between
			# their centers meets the upper platform's vertical side, trapping feet.
			var gap_length := length - 6.
			var pitch := atan2(delta.y, gap_length)
			var bridge_center := (at + previous) * .5 - Vector3.UP * (.14 * cos(pitch))
			var bridge := _platform("Ramp%02d" % index, bridge_center, Vector3(3.4, .28, Vector2(gap_length, delta.y).length() + .45), false)
			bridge.rotation = Vector3(pitch, atan2(-delta.x, -delta.z), 0.)
			bridge.set_meta("original_transform", bridge.transform)
			pad.set_meta("bridge", bridge)
		platforms.append(pad)
	checkpoint = platforms.front().position + Vector3.UP * .3
	goal = platforms.back().position
	set_visible(false)
	_set_collisions(false)

func _platform(label: String, at: Vector3, size: Vector3, floor_part := true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	body.position = at
	body.collision_layer = 1
	body.add_to_group("campaign_navigation_source")
	add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position.y = -size.y * .5 if floor_part else 0.
	body.add_child(shape)
	var visual := Renderer.instantiate_part(&"theme_celestial_fall", "Floor" if floor_part else "Bridge")
	if visual == null:
		push_error("The escape requires the authored celestial architecture kit.")
		return body
	body.add_child(visual)
	visual.scale = Vector3(size.x / 6., 1. if floor_part else size.y / .28, size.z / 6.)
	body.set_meta("original_transform", body.transform)
	return body

func begin() -> void:
	_generation += 1
	for motion in _motions:
		if motion != null and motion.is_valid(): motion.kill()
	_motions.clear()
	warned.clear()
	collapsed.clear()
	visited.clear()
	remaining = 90.
	active = true
	show()
	for body: Node in get_children():
		if body is StaticBody3D:
			body.transform = body.get_meta("original_transform", body.transform)
			body.show()
	_set_collisions(true)
	actor.global_position = checkpoint
	actor.velocity = Vector3.ZERO
	navigation_changed.emit()

func retry() -> void:
	retries += 1
	actor.respawn_at(checkpoint)
	begin()

func _set_collisions(enabled: bool) -> void:
	for body: Node in get_children():
		if body is StaticBody3D:
			for child: Node in body.get_children():
				if child is CollisionShape3D: child.set_deferred("disabled", not enabled)

func _physics_process(delta: float) -> void:
	if not active or not is_instance_valid(actor): return
	remaining -= delta
	for index in platforms.size():
		var pad := platforms[index]
		if actor.global_position.distance_to(pad.global_position) < 3.6:
			visited[index] = true
		var collapse_time := 12. + float(index) * 5.7
		if 90. - remaining >= collapse_time - 1.6 and not warned.has(index):
			warned[index] = true
			_warn(index)
		if 90. - remaining >= collapse_time and not collapsed.has(index):
			collapse(index)
	if actor.global_position.y < _origin.y - 4. or remaining <= 0.:
		active = false
		failed.emit()
		return
	# Reaching a distant point alone does not complete the escape: its intermediate
	# courts are route checkpoints, requiring both ramp and jump sections.
	if actor.global_position.distance_to(goal) < 3. and visited.size() >= 11:
		active = false
		completed.emit()

func _warn(index: int) -> void:
	var pad := platforms[index]
	var tween := create_tween().set_loops(4)
	_motions.append(tween)
	var base := pad.position
	tween.tween_property(pad, "position", base + Vector3(.06, .04, 0), .18)
	tween.tween_property(pad, "position", base, .18)

func collapse(index: int) -> void:
	if collapsed.has(index): return
	collapsed[index] = true
	var bodies: Array = [platforms[index]]
	if platforms[index].has_meta("bridge"): bodies.append(platforms[index].get_meta("bridge"))
	if index + 1 < platforms.size() and platforms[index + 1].has_meta("bridge"):
		bodies.append(platforms[index + 1].get_meta("bridge"))
	for body: StaticBody3D in bodies:
		for child in body.get_children():
			if child is CollisionShape3D: child.set_deferred("disabled", true)
		var tween := create_tween()
		_motions.append(tween)
		tween.tween_property(body, "position:y", body.position.y - 12., 1.7).set_trans(Tween.TRANS_QUAD)
		tween.tween_callback(body.hide)
	navigation_changed.emit()

func _exit_tree() -> void:
	_generation += 1
	for motion in _motions:
		if motion != null and motion.is_valid(): motion.kill()
