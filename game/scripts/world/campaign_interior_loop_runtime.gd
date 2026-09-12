extends Node3D
## Level-owned combat, earned B2 passage and physical atrium descent. Source
## enemies stay in world.enemies so the production death/ember/reset loop owns them.

signal refuge_activated(refuge_id: String, spawn_position_world: Vector3)
signal threat_state_changed(placement_id: String, state: String, position_world: Vector3)
signal player_death_observed(position_world: Vector3)
signal drop_landed(position_world: Vector3, fall_height: float, cushioned: bool, health_lost: float)
signal roof_reached(position_world: Vector3)

const EncounterSource = preload("res://scripts/world/campaign_expansion_runtime.gd")
const Interaction = preload("res://scripts/world/campaign_exit_interact.gd")
const Visuals = preload("res://scripts/levels/procedural_level_modules.gd")
const Copy = preload("res://scripts/ui/hud_theme.gd")
const Enemy = preload("res://scripts/enemy.gd")
const EnvironmentArt = preload("res://scripts/world/campaign_environment_renderer.gd")

var world: Node3D
var level_root: Node3D
var interior: Dictionary = {}
var souls: Dictionary = {}
var encounter_source: Node3D
var b2_door: StaticBody3D
var b2_control: Area3D
var refuge_control: Area3D
var threats: Dictionary = {}
var _configured := false
var _ambush: Node3D
var _top_guard: Node3D
var _ambush_state := "dormant"
var _ambush_delay := 0.0
var _drop_tracking := false
var _drop_peak := 0.0
var _drop_was_airborne := false
var _roof_visited := false
var _roof_target := Vector3.ZERO
var _has_roof := false


func setup(owner_world: Node3D, owner_level: Node3D, plan: Dictionary) -> void:
	if _configured or not is_instance_valid(owner_world) or not is_instance_valid(owner_level):
		return
	if (plan.get("souls", {}) as Dictionary).is_empty():
		return
	world = owner_world
	level_root = owner_level
	interior = plan.duplicate(true)
	souls = interior["souls"]
	_configured = true
	_build_b2_latch()
	_build_refuge()
	_build_threats()
	for point: Vector3 in souls.get("roof_route", []):
		if not _has_roof or point.y > _roof_target.y:
			_roof_target = point
			_has_roof = true
	if world.player.has_signal("died"):
		world.player.died.connect(_on_player_died)
	# Sample after the production player has resolved move_and_slide/landing.
	process_physics_priority = 20


func refuge_is_available() -> bool:
	return _configured and bool(world.run_state.get_choice_flag(String(souls["b2_latch"]["flag"]), false))


func refuge_spawn_world() -> Vector3:
	return level_root.to_global(souls["refuge"]["spawn_position"])


func _build_refuge() -> void:
	refuge_control = Interaction.new()
	refuge_control.name = "InteriorAshRefuge"
	refuge_control.collision_layer = 8
	refuge_control.collision_mask = 0
	refuge_control.monitoring = false
	refuge_control.add_to_group("interactable")
	refuge_control.add_to_group("campaign_interior_refuge")
	refuge_control.world_callback = Callable(self, "_use_refuge")
	var shape := SphereShape3D.new()
	shape.radius = .9
	var sensor := CollisionShape3D.new()
	sensor.shape = shape
	sensor.position.y = .8
	refuge_control.add_child(sensor)
	add_child(refuge_control)
	refuge_control.global_position = level_root.to_global(souls["refuge"]["position"])
	var lantern := EnvironmentArt.instantiate_part(StringName(world._current_visual_theme()), "Lantern")
	if lantern != null:
		refuge_control.add_child(lantern)
	# This crown and flame have their own local materials. The imported kit's
	# ordinary lantern material is shared by the rest of the house and untouched.
	var crown := MeshInstance3D.new()
	crown.name = "RefugeBrazierCrown"
	var rim := TorusMesh.new()
	rim.inner_radius = .43
	rim.outer_radius = .61
	rim.rings = 20
	rim.ring_segments = 8
	crown.mesh = rim
	crown.position.y = 1.86
	var bronze := StandardMaterial3D.new()
	bronze.albedo_color = Color("724127")
	bronze.metallic = .65
	bronze.roughness = .5
	crown.material_override = bronze
	refuge_control.add_child(crown)
	var flame := Node3D.new()
	flame.name = "RefugeFlame"
	flame.position.y = 2.14
	refuge_control.add_child(flame)
	for core in 2:
		var ember := MeshInstance3D.new()
		ember.name = "GoldCore" if core == 1 else "AmberFlame"
		var mesh := SphereMesh.new()
		mesh.radius = .12 if core == 1 else .25
		mesh.height = .48 if core == 1 else .94
		mesh.radial_segments = 12
		mesh.rings = 8
		ember.mesh = mesh
		ember.rotation.z = -.14
		ember.position.y = -.10 if core == 1 else 0.0
		var fire := StandardMaterial3D.new()
		fire.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fire.albedo_color = Color("ffe7a3") if core == 1 else Color("ff7429")
		if core == 0:
			fire.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			fire.albedo_color.a = .68
		fire.emission_enabled = true
		fire.emission = fire.albedo_color
		fire.emission_energy_multiplier = 2.4 if core == 1 else 1.7
		ember.material_override = fire
		flame.add_child(ember)
	var light := OmniLight3D.new()
	light.name = "RefugeWarmLight"
	light.position.y = 2.2
	light.light_color = Color("ffb066")
	light.omni_range = 5.0
	light.shadow_enabled = false
	refuge_control.add_child(light)
	_refresh_refuge_visual()


func _refresh_refuge_visual() -> void:
	if not is_instance_valid(refuge_control):
		return
	var lit := refuge_is_available()
	(refuge_control.get_node("RefugeFlame") as Node3D).visible = lit
	var light := refuge_control.get_node("RefugeWarmLight") as OmniLight3D
	light.visible = lit
	light.light_energy = 1.45 if lit else 0.0
	refuge_control.prompt_text = Copy.copy("余灰歇脚处 · 点亮并歇息", "Ash refuge · Kindle and rest") if lit else Copy.copy("余灰未燃 · 先从楼内拉开 B2 门闩", "Ash is cold · Unlatch B2 from inside first")


func _use_refuge(area: Node3D, actor: Node) -> void:
	if area != refuge_control or not _nearby(area, actor):
		return
	if not refuge_is_available():
		_say(Copy.copy("先从二层内侧接通 B2 归路。", "Connect B2 from inside the middle floor first."))
		return
	for enemy: Node3D in world.enemies:
		if is_instance_valid(enemy) and float(enemy.health) > 0 and enemy.global_position.distance_to(area.global_position) < 8.0:
			_say(Copy.copy("敌影仍在近处，暂不能歇息。", "An enemy is too close to rest."))
			return
	refuge_activated.emit(String(souls["refuge"]["id"]), refuge_spawn_world())


func _build_b2_latch() -> void:
	var spec: Dictionary = souls["b2_latch"]
	b2_door = StaticBody3D.new()
	b2_door.name = "InteriorB2LatchDoor"
	b2_door.collision_layer = 1
	b2_door.collision_mask = 0
	b2_door.add_to_group("campaign_navigation_source")
	b2_door.add_to_group("campaign_terrain_navigation_source")
	var size: Vector3 = spec["size"]
	var collision := CollisionShape3D.new()
	collision.name = "GateCollision"
	var box := BoxShape3D.new()
	box.size = size
	collision.shape = box
	collision.position.y = size.y * .5
	b2_door.add_child(collision)
	var leaf := Node3D.new()
	leaf.name = "GateLeaf"
	leaf.position.y = size.y * .5
	b2_door.add_child(leaf)
	Visuals.add_solid_visual(leaf, size, world._current_visual_theme())
	add_child(b2_door)
	b2_door.global_transform = level_root.global_transform * Transform3D(Basis(Vector3.UP, float(spec.get("yaw", 0.0))), spec["position"])
	b2_control = Interaction.new()
	b2_control.name = "InteriorB2FarLatch"
	b2_control.collision_layer = 8
	b2_control.collision_mask = 0
	b2_control.monitoring = false
	b2_control.add_to_group("interactable")
	b2_control.add_to_group("campaign_interior_b2_latch")
	b2_control.world_callback = Callable(self, "_use_b2_latch")
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = .85
	var sensor := CollisionShape3D.new()
	sensor.shape = sphere_shape
	sensor.position.y = .8
	b2_control.add_child(sensor)
	add_child(b2_control)
	b2_control.global_position = level_root.to_global(spec["far_side"])
	var label := Label3D.new()
	label.font = Copy.InterfaceFont
	label.font_size = 30
	label.pixel_size = .009
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = 1.6
	label.text = Copy.copy("B2 · 内侧门闩", "B2 · Inner latch")
	b2_control.add_child(label)
	if refuge_is_available():
		_open_b2(false)
	else:
		b2_control.prompt_text = Copy.copy("拉开 B2 门闩 · 接通余灰歇脚处", "Unlatch B2 · Connect the ash refuge")


func _use_b2_latch(area: Node3D, actor: Node) -> void:
	if area != b2_control or not _nearby(area, actor) or refuge_is_available():
		return
	var local := b2_door.to_local(actor.global_position)
	var side := signf(b2_door.to_local(b2_control.global_position).z)
	if side == 0 or local.z * side < .35:
		_say(Copy.copy("门闩在楼内一侧。", "The latch is on the room side."))
		return
	var key := String(souls["b2_latch"]["flag"])
	world.run_state.set_choice_flag(key, true)
	if not bool(world._save_run("interior_b2_latch")):
		world.run_state.choice_flags.erase(key)
		return
	_open_b2(true)
	_refresh_refuge_visual()
	refuge_activated.emit(String(souls["refuge"]["id"]), refuge_spawn_world())
	_say(Copy.copy("B2 归路已接通。楼下余灰可歇脚；死后门闩仍保持开启。", "B2 return connected. The ash refuge below is available; this latch stays open after death."))


func _nearby(area: Node3D, actor: Node) -> bool:
	if not _configured or not is_inside_tree() or not is_instance_valid(area) or not is_instance_valid(actor):
		return false
	if level_root.is_queued_for_deletion() or world.campaign_runtime.current_level != level_root:
		return false
	if actor != world.player or float(actor.health) <= 0 or actor.global_position.distance_to(area.global_position) > 3.0:
		return false
	var query := PhysicsRayQueryParameters3D.create(actor.global_position + Vector3.UP * .8, area.global_position + Vector3.UP * .8, 1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _open_b2(animate: bool) -> void:
	if bool(b2_door.get_meta("open", false)):
		return
	b2_door.set_meta("open", true)
	b2_control.prompt_text = Copy.copy("B2 归路已开", "B2 return is open")
	var leaf := b2_door.get_node("GateLeaf") as Node3D
	if not animate:
		leaf.scale.y = .02
		leaf.position.y = float(souls["b2_latch"]["size"].y)
		b2_door.collision_layer = 0
		(b2_door.get_node("GateCollision") as CollisionShape3D).disabled = true
		return
	var tween := create_tween().set_parallel(true)
	tween.tween_property(leaf, "scale:y", .02, .7)
	tween.tween_property(leaf, "position:y", float(souls["b2_latch"]["size"].y), .7)
	tween.chain().tween_callback(func() -> void:
		b2_door.collision_layer = 0
		(b2_door.get_node("GateCollision") as CollisionShape3D).set_deferred("disabled", true)
		if is_instance_valid(world) and world.campaign_runtime.current_level == level_root:
			world.request_navigation_refresh(level_root)
	)


func _build_threats() -> void:
	var level_id := String(world.campaign_runtime.current_level_id)
	if level_id == "level_05_01":
		return
	var encounters: Array = interior.get("interior_pressure", [])
	if encounters.is_empty():
		return
	encounter_source = EncounterSource.new()
	encounter_source.name = "InteriorThreatSource"
	add_child(encounter_source)
	encounter_source.setup(world, level_root, {"district_id": String(interior["id"]), "encounters": encounters, "rewards": []})
	for enemy: Node3D in encounter_source.spawned_enemies:
		var id := String(enemy.get_meta("expansion_placement_id", ""))
		threats[id] = enemy
		enemy.engagement_changed.connect(_on_threat_engaged.bind(id))
		enemy.defeated.connect(_on_threat_defeated.bind(id))
		enemy.reset_completed.connect(_on_threat_reset.bind(id))
		if id.ends_with("ground_ambush"):
			_ambush = enemy
			_add_warning_mark(enemy)
		elif id.ends_with("top_shield"):
			_top_guard = enemy
			enemy.set_meta("campaign_hit_filter", Callable(self, "_filter_shield_hit").bind(enemy))
			_add_shield(enemy)
		threat_state_changed.emit(id, "ready", enemy.global_position)


func top_guard_is_alive() -> bool:
	return is_instance_valid(_top_guard) and not _top_guard.is_queued_for_deletion() and float(_top_guard.health) > 0.0


func top_guard() -> Node3D:
	return _top_guard if is_instance_valid(_top_guard) else null


func _door_a_is_solved() -> bool:
	var stages: Array = interior.get("stages", [])
	if stages.is_empty():
		return false
	var key := "interior:%s:solved:%s" % [String(interior["id"]), String(stages[0]["id"])]
	return bool(world.run_state.get_choice_flag(key, false))


func _add_warning_mark(enemy: Node3D) -> void:
	var mark := Label3D.new()
	mark.name = "AmbushWarning"
	mark.text = Copy.copy("拖刃声 · 门后有人", "Dragging steel · Someone waits by the door")
	mark.font = Copy.InterfaceFont
	mark.font_size = 27
	mark.pixel_size = .008
	mark.modulate = Color("ffb467")
	mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	mark.position.y = 2.6
	enemy.add_child(mark)


func _add_shield(enemy: Node3D) -> void:
	var shield := MeshInstance3D.new()
	shield.name = "InteriorGuardShield"
	var mesh := CylinderMesh.new()
	mesh.top_radius = .62
	mesh.bottom_radius = .62
	mesh.height = .14
	shield.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("76654b")
	material.metallic = .7
	material.roughness = .55
	shield.material_override = material
	shield.rotation.x = PI * .5
	shield.position = Vector3(-.38, 1.1, -.53)
	enemy.visual_root.add_child(shield)


func _filter_shield_hit(payload: Dictionary, enemy: Node3D) -> Dictionary:
	if not is_instance_valid(enemy) or enemy.state not in [Enemy.State.IDLE, Enemy.State.CHASE, Enemy.State.RETURN]:
		return payload
	if not bool(payload.get("blockable", true)):
		return payload
	var source: Variant = payload.get("source")
	var toward_source := Vector3.ZERO
	if source is Node3D and is_instance_valid(source):
		toward_source = source.global_position - enemy.global_position
	else:
		toward_source = -(payload.get("direction", Vector3.ZERO) as Vector3)
	toward_source.y = 0.0
	if toward_source.length_squared() < .01 or (-enemy.global_basis.z).dot(toward_source.normalized()) < .35:
		return payload
	var filtered := payload.duplicate(true)
	filtered["damage"] = float(payload.get("damage", 0.0)) * .15
	filtered["stagger"] = float(payload.get("stagger", payload.get("poise", 0.0))) * 1.4
	filtered["poise"] = filtered["stagger"]
	threat_state_changed.emit(String(enemy.get_meta("expansion_placement_id")), "shield_block", enemy.global_position)
	return filtered


func _physics_process(delta: float) -> void:
	if not _configured or not is_instance_valid(world.player) or world.campaign_runtime.current_level != level_root:
		return
	if float(world.player.health) <= 0:
		_drop_tracking = false
		return
	_update_ambush(delta)
	_update_drop()
	if not _roof_visited and _has_roof and world.player.global_position.distance_to(level_root.to_global(_roof_target)) < 2.0:
		_roof_visited = true
		roof_reached.emit(world.player.global_position)


func _update_ambush(delta: float) -> void:
	if not is_instance_valid(_ambush) or float(_ambush.health) <= 0 or _ambush_state == "active":
		return
	if not _door_a_is_solved():
		return
	if _ambush_state == "telegraph":
		_ambush_delay -= delta
		if _ambush_delay <= 0:
			_ambush._encounter_provoked = true
			_ambush_state = "active"
			threat_state_changed.emit(String(_ambush.get_meta("expansion_placement_id")), "ambush_released", _ambush.global_position)
		return
	var offset: Vector3 = world.player.global_position - _ambush.global_position
	if absf(offset.y) > 2.0 or offset.length() > 6.0:
		return
	var ray := PhysicsRayQueryParameters3D.create(_ambush.global_position + Vector3.UP, world.player.global_position + Vector3.UP, 1)
	if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
		return
	_ambush_state = "telegraph"
	_ambush_delay = .85
	_say(Copy.copy("门后拖刃声骤近——留出闪避余地。", "Steel scrapes closer by the door—leave room to evade."))
	if is_instance_valid(world.audio):
		world.audio.play_cue("hurt", -11.0, .65)
	threat_state_changed.emit(String(_ambush.get_meta("expansion_placement_id")), "ambush_telegraph", _ambush.global_position)


func landing_damage(fall_height: float, cushioned: bool) -> float:
	var spec: Dictionary = souls.get("drop", {})
	if fall_height < 4.0:
		return 0.0
	var base := maxf(0.0, fall_height - 3.0) * 4.0
	return maxf(float(spec.get("minimum_damage", 3.0)), base * float(spec.get("damage_scale", .3))) if cushioned else base


func _update_drop() -> void:
	var spec: Dictionary = souls.get("drop", {})
	if spec.is_empty():
		return
	var local := level_root.to_local(world.player.global_position)
	var takeoff: Vector3 = spec["takeoff"]
	var airborne := not bool(world.player.is_on_floor())
	if not _drop_tracking:
		if Vector2(local.x - takeoff.x, local.z - takeoff.z).length() <= 5.0 and local.y >= takeoff.y - 1.0 and local.y <= takeoff.y + 3.0:
			_drop_tracking = true
			_drop_peak = local.y
			_drop_was_airborne = airborne
		return
	_drop_peak = maxf(_drop_peak, local.y)
	_drop_was_airborne = _drop_was_airborne or airborne
	if airborne:
		return
	if not _drop_was_airborne:
		if Vector2(local.x - takeoff.x, local.z - takeoff.z).length() > 5.5:
			_drop_tracking = false
		return
	_drop_tracking = false
	var height := _drop_peak - local.y
	if height < 4.0:
		return
	var center: Vector3 = spec["landing_center"]
	var size: Vector3 = spec["size"]
	var cushioned := absf(local.x - center.x) <= size.x * .5 and absf(local.z - center.z) <= size.z * .5 and absf(local.y - center.y) < 2.0
	var health_before := float(world.player.health)
	world.player.receive_hit_payload({"damage": landing_damage(height, cushioned), "stagger": 0.0, "poise": 0.0, "direction": Vector3.ZERO, "source": self, "blockable": false, "parryable": false, "tags": ["environmental_fall"]})
	var health_lost := maxf(0.0, health_before - float(world.player.health))
	drop_landed.emit(world.player.global_position, height, cushioned, health_lost)
	_say(Copy.copy("散书缓住落势，仍伤及筋骨。", "The loose books cushion the fall, but the landing still hurts.") if cushioned else Copy.copy("硬地承受了全部冲击。", "The hard floor takes the full impact."))


func _on_threat_engaged(enemy: Node3D, _guardian: bool, engaged: bool, id: String) -> void:
	threat_state_changed.emit(id, "engaged" if engaged else "returning", enemy.global_position)


func _on_threat_defeated(enemy: Node3D, _reward: int, _guardian: bool, id: String) -> void:
	threat_state_changed.emit(id, "defeated", enemy.global_position)


func _on_threat_reset(enemy: Node3D, id: String) -> void:
	if enemy == _ambush:
		_ambush_state = "dormant"
		_ambush_delay = 0.0
	threat_state_changed.emit(id, "reset", enemy.global_position)


func _on_player_died(position_world: Vector3) -> void:
	_drop_tracking = false
	_drop_was_airborne = false
	player_death_observed.emit(position_world)


func _say(message: String) -> void:
	if is_instance_valid(world.hud):
		world.hud.show_message(message, 4.0)
