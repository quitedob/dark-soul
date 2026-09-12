extends Node3D
## Playable encounters and finite caches in the authored outer district.
## Geometry, shortcuts and lifts remain owned by the level/module builders.

const Interaction = preload("res://scripts/world/campaign_exit_interact.gd")
const Renderer = preload("res://scripts/world/campaign_environment_renderer.gd")
const Copy = preload("res://scripts/ui/hud_theme.gd")
const CONTENT := [
	preload("res://scripts/data/chapter_1_content.gd"),
	preload("res://scripts/data/chapter_2_content.gd"),
	preload("res://scripts/data/chapter_3_content.gd"),
	preload("res://scripts/data/chapter_4_content.gd"),
	preload("res://scripts/data/chapter_5_content.gd"),
]

var world: Node3D
var level_root: Node3D
var district_id := ""
var level_id := ""
var spawned_enemies: Array[Node3D] = []
var reward_areas: Dictionary = {}
var _rewards: Dictionary = {}
var _configured := false


func setup(owner_world: Node3D, owner_level: Node3D, expansion: Dictionary) -> void:
	# Setup is a level-lifetime operation. A repeated wiring pass cannot summon
	# another roster or replace the callback on a cache being claimed.
	if _configured or expansion.is_empty():
		return
	if not is_instance_valid(owner_world) or not is_instance_valid(owner_level):
		return
	world = owner_world
	level_root = owner_level
	level_id = String(world.campaign_runtime.current_level_id)
	district_id = String(expansion.get("district_id", "outer_district"))
	_configured = true
	set_meta("district_id", district_id)
	set_meta("level_id", level_id)
	for plan: Dictionary in expansion.get("encounters", []):
		_spawn_encounter(plan)
	for reward: Dictionary in expansion.get("rewards", []):
		_build_reward(reward)


func _spawn_encounter(plan: Dictionary) -> void:
	var placement_id := String(plan.get("placement_id", ""))
	if placement_id.is_empty():
		push_error("Expansion encounter requires a stable placement_id")
		return
	# Stable IDs also protect against an accidental second runtime on this root.
	for existing in world.enemies:
		if is_instance_valid(existing) and existing.has_meta("expansion_level") and existing.get_meta("expansion_level") == level_root:
			if String(existing.get_meta("expansion_placement_id", "")) == placement_id:
				return
	var content := _content_for(String(plan.get("content_id", "")))
	if content.is_empty():
		push_error("Expansion encounter content is unavailable: " + String(plan.get("content_id", "")))
		return
	var clearance := maxf(.05, float(content.get("body_height", 1.9)) * .5 - float(content.get("body_y", .95)) + .05)
	var local_position: Vector3 = plan.get("position", Vector3.ZERO)
	var spawn_world := level_root.to_global(local_position + Vector3.UP * clearance)
	var enemy: Node3D = world._spawn_content_enemy(world.to_local(spawn_world), content)
	if not is_instance_valid(enemy):
		return
	# The production factory parents actors to world. Establish global home after
	# its _ready/reset runs; the level's local transform is applied exactly once.
	enemy.global_position = spawn_world
	enemy.spawn_origin = spawn_world
	enemy.velocity = Vector3.ZERO
	enemy.navigation_refresh = 0.0
	var runtime_plan := plan.duplicate(true)
	runtime_plan["encounter_id"] = placement_id
	runtime_plan["position"] = spawn_world
	runtime_plan["district_id"] = district_id
	runtime_plan["guard_radius"] = float(plan.get("guard_radius", 12.0))
	var patrol: Array[Vector3] = []
	for point: Vector3 in plan.get("patrol_points", []):
		patrol.append(level_root.to_global(point))
	runtime_plan["patrol_points"] = patrol
	var facing: Vector3 = plan.get("facing", Vector3.FORWARD)
	var world_facing := level_root.global_basis * facing
	var parent_facing := world.global_basis.inverse() * world_facing
	runtime_plan["facing"] = world_facing.normalized()
	runtime_plan["facing_yaw"] = atan2(-parent_facing.x, -parent_facing.z)
	enemy.assign_campaign_encounter(runtime_plan)
	enemy.set_meta("expansion_level", level_root)
	enemy.set_meta("expansion_placement_id", placement_id)
	spawned_enemies.append(enemy)


func _content_for(content_id: String) -> Dictionary:
	for chapter in CONTENT:
		for content: Dictionary in chapter.enemies():
			if String(content.get("id", "")) == content_id:
				return content
	return {}


func reward_flag(reward_id: String) -> String:
	return "expansion_cache:%s:%s:%s" % [level_id, district_id, reward_id]


func _build_reward(reward: Dictionary) -> void:
	var id := String(reward.get("id", ""))
	if id.is_empty() or int(reward.get("embers", 0)) <= 0 or _rewards.has(id):
		return
	_rewards[id] = reward.duplicate(true)
	if bool(world.run_state.get_choice_flag(reward_flag(id), false)):
		return
	var area := Interaction.new()
	area.name = "ExpansionCache_" + id.validate_node_name()
	area.prompt_text = Copy.copy("拾取遗留余烬", "Gather the abandoned embers")
	area.world_callback = Callable(self, "_claim_reward")
	area.collision_layer = 8
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = true
	area.set_meta("expansion_reward_id", id)
	area.add_to_group("interactable")
	area.add_to_group("campaign_expansion_cache")
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = .9
	shape.shape = sphere
	shape.position.y = .75
	area.add_child(shape)
	add_child(area)
	area.global_position = level_root.to_global(reward.get("position", Vector3.ZERO))
	_add_reward_visual(area)
	reward_areas[id] = area


func _add_reward_visual(area: Area3D) -> void:
	var theme := StringName(world._current_visual_theme())
	var kit_path := Renderer.KIT_DIRECTORY + String(theme).trim_prefix("theme_") + ".glb"
	# Lantern is supplied by the Three.js kit expansion. Keep old-kit bootstrap
	# safe while generated assets/imports are being installed by the integrator.
	var visual: Node3D
	if Renderer.PARTS.has("Lantern") and ResourceLoader.exists(kit_path):
		visual = Renderer.instantiate_part(theme, "Lantern")
	if visual != null:
		area.add_child(visual)
		area.set_meta("visual_source", "threejs_lantern")
	else:
		var ember := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = .16
		mesh.height = .32
		ember.mesh = mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("e9b268")
		material.emission_enabled = true
		material.emission = Color("d78738")
		material.emission_energy_multiplier = 1.4
		ember.material_override = material
		ember.position.y = .65
		area.add_child(ember)
		area.set_meta("visual_source", "ember_wisp_bootstrap")
	var light := OmniLight3D.new()
	light.position.y = .8
	light.light_color = Color("ffc57d")
	light.light_energy = .7
	light.omni_range = 3.0
	light.shadow_enabled = false
	area.add_child(light)


func _claim_reward(area: Node3D, actor: Node) -> void:
	if not is_instance_valid(world) or not is_instance_valid(level_root) or not is_instance_valid(area):
		return
	if not is_inside_tree() or level_root.is_queued_for_deletion() or area.is_queued_for_deletion():
		return
	if world.campaign_runtime.current_level != level_root or actor != world.player or area.get_parent() != self:
		return
	if not actor is Node3D or float(actor.health) <= 0.0:
		return
	if actor.global_position.distance_to(area.global_position) > 3.0:
		return
	var id := String(area.get_meta("expansion_reward_id", ""))
	if not _rewards.has(id) or reward_areas.get(id) != area:
		return
	var flag := reward_flag(id)
	if bool(world.run_state.get_choice_flag(flag, false)):
		return
	var query := PhysicsRayQueryParameters3D.create(actor.global_position + Vector3.UP * .8, area.global_position + Vector3.UP * .8, 1)
	if not area.get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		return
	var reward: Dictionary = _rewards[id]
	var amount := int(reward["embers"])
	# Write the durable guard before granting currency/signalling. No item or
	# loot-catalog IDs are invented for environmental caches.
	world.run_state.set_choice_flag(flag, true)
	actor.add_embers(amount)
	if not bool(world._save_run("expansion_cache_" + id)):
		actor.add_embers(-amount)
		world.run_state.choice_flags.erase(flag)
		world.run_state.embers = int(actor.embers)
		return
	reward_areas.erase(id)
	area.remove_from_group("interactable")
	area.set_deferred("collision_layer", 0)
	var lore := String(reward.get("lore_text", ""))
	if is_instance_valid(world.hud):
		world.hud.show_message(Copy.copy("获得 %d 余烬", "%d embers recovered") % amount + ("\n" + lore if not lore.is_empty() else ""), 4.5)
	if is_instance_valid(world.audio):
		world.audio.play_cue("rest", -7.0, .9)
	area.queue_free()


func _exit_tree() -> void:
	# Source actors are world children for the production combat factory. The
	# normal _clear_enemies path handles transitions; this also covers a district
	# being unloaded directly, without leaving an active encounter behind.
	for enemy in spawned_enemies:
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		if is_instance_valid(world):
			world.enemies.erase(enemy)
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		# The world may itself be walking its children during destruction. Avoid
		# reentrant remove_child; disable the actor immediately, then let normal
		# tree destruction / queued deletion own the structural removal.
		if enemy is CollisionObject3D:
			enemy.collision_layer = 0
			enemy.collision_mask = 0
		enemy.queue_free()
	spawned_enemies.clear()
