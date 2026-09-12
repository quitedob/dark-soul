extends SceneTree
## Actual campaign build and keyed roster checks, with no disk-save I/O.
const Dressing = preload("res://scripts/data/campaign_scene_dressing.gd")
const Encounters = preload("res://scripts/world/campaign_encounter_layout.gd")
const WorldScene = preload("res://scenes/world/ashen_hollow.tscn")
const Temple = preload("res://scripts/world/awakening_temple_layout.gd")
const Mechanisms = preload("res://scripts/world/campaign_story_mechanisms.gd")
const StoryRenderer = preload("res://scripts/world/campaign_story_prop_renderer.gd")

class AuditWorld extends "res://scripts/game_world.gd":
	func _load_initial_state() -> void:
		_apply_settings()
	func _save_run(_reason: String) -> bool:
		_snapshot_run_state()
		return true

var _failures: Array[String] = []
var _checks := 0
var _props := 0
var _enemies := 0
var _world: AuditWorld
var _plans_only := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_plans_only = "--plans-only" in OS.get_cmdline_user_args()
	_world = AuditWorld.new()
	var contents := WorldScene.instantiate()
	for child: Node in contents.get_children():
		child.owner = null
		contents.remove_child(child)
		_world.add_child(child)
	contents.free()
	root.add_child(_world)
	_world.set_process(false)
	for level: Dictionary in _world.campaign_runtime.registry.get_levels():
		var id := String(level["id"])
		if not _check(_world._load_campaign_level(StringName(id)), id + ": actual level load"):
			continue
		_freeze()
		await physics_frame
		await physics_frame
		var current: Node3D = _world.campaign_runtime.current_level
		var layout: Dictionary = current.get_meta("story_layout",current.get_meta("modeled_layout", {}))
		if id == "level_01_01":
			if layout.is_empty():
				layout = Temple.read_manifest()
				layout["cells"] = Temple.walkable_cells(layout)
				layout["modules"] = Dressing.module_anchors(id)
				layout["story_props"] = Dressing.plan_scene(level, layout)
				layout["story_anchors"] = Dressing.story_anchors(id)
		var props := Dressing.plan_scene(level, layout)
		if not _plans_only:
			_check_imported_props(current, props, id)
		_check(props.size() >= 4, id + ": story-specific architecture missing")
		var ids: Dictionary = {}
		for prop: Dictionary in props:
			_check(not ids.has(prop["id"]), id + ": duplicate story placement identity")
			ids[prop["id"]] = true
			_check(String(prop["story_source"]).contains("docs/"), id + ": placement lacks story source")
			_check(Dressing.footprint(prop).x > 0, id + ": unknown modeled story part " + String(prop["part_id"]))
			if bool(prop["collision"]):
				_check_prop_support(current, prop, id)
				if layout.has("boss_arena_center"):
					var center: Vector3 = layout["boss_arena_center"]
					var at: Vector3 = prop["position"]
					var half := Dressing.footprint(prop)*.5
					var nearest := Vector2(maxf(absf(at.x-center.x)-half.x,0),maxf(absf(at.z-center.z)-half.y,0))
					_check(nearest.length()>=float(layout["boss_arena_radius"])+1.5,
						id+": permanent story building invades boss movement/phase radius "+String(prop["part_id"]))
			_props += 1
		for anchor_name: String in Dressing.story_anchors(id):
			var anchor: Vector3 = Dressing.story_anchors(id)[anchor_name]
			_check(Encounters.is_supported(layout,anchor,.6), id+": unsupported story interaction "+anchor_name)
		var suppressed := Mechanisms.suppressed_modules(id)
		if not suppressed.is_empty():
			var controller := current.get_node_or_null("StoryMechanisms")
			_check(controller != null and controller.get_script() == Mechanisms
				and controller.get("level") == current and controller.get("world") == _world
				and String(controller.get("level_id")) == id,
				id + ": removed modules require the actual level-bound story controller")
		for module_id: String in Dressing.module_anchors(id):
			var anchor: Vector3 = Dressing.module_anchors(id)[module_id]
			_check(Encounters.is_supported(layout,anchor,.6), id+": unsupported authored module "+module_id)
			var found_module := false
			for module: Node3D in current.get_node("Modules").get_children():
				if String(module.get_meta("module_id",""))==module_id:
					found_module = true
					_check(module.position.is_equal_approx(anchor),id+": module was not moved into its story room "+module_id)
			if suppressed.has(StringName(module_id)):
				_check(not found_module,id+": replaced module must not duplicate its live story mechanism "+module_id)
			else:
				_check(found_module,id+": authored module not present in real level "+module_id)
		if not _plans_only:
			_check_story_npcs(current,id)
		_check_memorials_and_bells(id, props)
		var rows: Array[Dictionary] = []
		var actors: Array[Node3D] = []
		var district_plans: Dictionary = {}
		for plan: Dictionary in current.get_meta("expansion", {}).get("encounters", []):
			district_plans[String(plan["placement_id"])] = plan
		var district_seen: Dictionary = {}
		for enemy: Node3D in _world.enemies:
			if enemy == _world.guardian:
				continue
			if enemy.has_meta("expansion_placement_id"):
				var placement_id := String(enemy.get_meta("expansion_placement_id"))
				_check(district_plans.has(placement_id) and not district_seen.has(placement_id), id + ": district actor has unique authored identity")
				district_seen[placement_id] = true
				if district_plans.has(placement_id):
					var plan: Dictionary = district_plans[placement_id]
					var expected: Vector3 = current.to_global(plan["position"])
					_check(String(enemy.content_id) == String(plan["content_id"]), id + ": district content matches its story plan")
					_check(Vector2(enemy.global_position.x - expected.x, enemy.global_position.z - expected.z).length() < .2,
						id + ": district actor remains at its own guarded route")
					_check(Encounters.is_supported(layout, plan["position"], enemy.body_shape.radius), id + ": district guard has genuine supporting terrain")
				continue
			rows.append({"content_id": String(enemy.content_id), "body_radius": enemy.body_shape.radius})
			actors.append(enemy)
		_check(district_seen.size() == district_plans.size(), id + ": complete added district roster")
		if id == "level_03_04":
			_check_lake_roster(current, actors)
		var input_snapshot: Dictionary = layout.duplicate(true)
		var roster_snapshot := rows.duplicate(true)
		_check(rows.size()==Encounters.authored_encounters(id).size(),id+": actual roster omitted an authored encounter")
		var assigned := Encounters.assign_encounters(id, layout, rows)
		_check(layout==input_snapshot and rows==roster_snapshot,id+": pure planner mutated caller data")
		_check(assigned.size() == rows.size(), id + ": real roster has no complete clear authored plan " + str(rows))
		for entry: Dictionary in assigned:
			_check_encounter(current, layout, actors[int(entry["source_index"])], entry, id)
			_enemies += 1
		var reversed := rows.duplicate(true)
		reversed.reverse()
		var other := Encounters.assign_encounters(id, layout, reversed)
		_check(_by_key(assigned) == _by_key(other), id + ": changing roster order changes authored placement")
		_check(Encounters.assign_encounters(id, layout, [{"content_id":"missing_content"}]).is_empty(),
			id + ": unknown content must fail instead of random fallback")
		print("CAMPAIGN_STORY_LAYOUT_LEVEL %s props=%d encounters=%d" % [id, props.size(), assigned.size()])
	_world.free()
	print("CAMPAIGN_STORY_LAYOUT_COUNTS props=%d encounters=%d checks=%d" % [_props,_enemies,_checks])
	if _failures.is_empty():
		print("ASHEN_CAMPAIGN_STORY_PLANS_OK" if _plans_only else "ASHEN_CAMPAIGN_STORY_LAYOUT_CONTRACT_OK")
		quit(0)
	else:
		for failure: String in _failures:
			push_error(failure)
		quit(1)


func _check_imported_props(current: Node3D, props: Array[Dictionary], id: String) -> void:
	var rendered := current.get_node_or_null("CampaignStoryProps") as Node3D
	if not _check(rendered != null,id+": actual Blender story scenery absent"):
		return
	var records: Array = rendered.get_meta("placements",[])
	_check(records.size()==props.size(),id+": actual imported placement count differs from story plan")
	var found: Dictionary = {}
	for record: Dictionary in records:
		found[record["id"]] = record
	for prop: Dictionary in props:
		_check(found.has(prop["id"]),id+": planned story prop was not rendered "+String(prop["id"]))
	var anchors := 0
	for anchor: Node in rendered.get_children():
		if not anchor.has_meta("story_prop_id"):
			continue
		anchors += 1
		var placement: Dictionary = anchor.get_meta("story_placement",{})
		var bounds: AABB = anchor.get_meta("story_mesh_bounds",AABB())
		_check(bounds.size.length()>1 and absf(bounds.position.y)<.015,
			id+": actual imported story mesh lost floor-origin geometry "+String(anchor.get_meta("story_part_id","")))
		_check((anchor as Node3D).position.is_equal_approx(placement["position"]),
			id+": physical story placement differs from visible batch")
		if bool(placement.get("collision",true)):
			var has_actor_collision := false
			for body: StaticBody3D in anchor.find_children("*","StaticBody3D",true,false):
				if body.collision_layer==1:
					has_actor_collision = true
			_check(has_actor_collision,id+": modeled solid has no real actor/camera collision")
	_check(anchors==props.size(),id+": story collider/mesh identities were not preserved")
	var mesh_count := 0
	for batch: MultiMeshInstance3D in rendered.find_children("*","MultiMeshInstance3D",true,false):
		mesh_count += 1
		_check(batch.multimesh.mesh is ArrayMesh,id+": procedural placeholder replaced authored story mesh")
		_check(String(batch.get_meta("story_asset_path","")).begins_with("res://assets/environment/story_props/"),
			id+": story art was not loaded from required modeled library")
		_check(batch.multimesh.instance_count == (batch.get_meta("placement_transforms",[]) as Array).size(),
			id+": imported story batch lost placement transforms")
	_check(mesh_count>0,id+": no imported story material batches")


func _check_story_npcs(current: Node3D, id: String) -> void:
	var anchors := Dressing.story_anchors(id)
	for npc: Node3D in _world._shrine_npcs:
		var anchor_name := String(npc.get_meta("story_anchor",""))
		if anchor_name.is_empty():
			continue
		if not _check(anchors.has(anchor_name),id+": NPC refers to a missing story location"):
			continue
		var expected: Vector3 = current.to_global(anchors[anchor_name])
		_check(npc.global_position.distance_to(expected)<.06,id+": NPC did not appear at its actual story site")
		var capsule := CapsuleShape3D.new()
		capsule.radius = .45
		capsule.height = 1.8
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = capsule
		query.collision_mask = 1
		query.transform.origin = npc.global_position + Vector3.UP*.96
		var hits := current.get_world_3d().direct_space_state.intersect_shape(query,16)
		_check(hits.is_empty(),id+": story NPC placed inside modeled solid "+anchor_name)


func _check_prop_support(current: Node3D, prop: Dictionary, id: String) -> void:
	if String(prop["part_id"]) == "LakePavilion":
		_check_pavilion_footings(current, prop, id)
		return
	var position: Vector3 = prop["position"]
	var half := Dressing.footprint(prop)*.5
	# Probe ground just outside the declared foot: support cannot come from the
	# prop's own raised plinth or collider.
	for offset: Vector2 in [Vector2(-half.x-.1,-half.y-.1),Vector2(half.x+.1,-half.y-.1),
		Vector2(-half.x-.1,half.y+.1),Vector2(half.x+.1,half.y+.1)]:
		var world_point := current.to_global(position + Vector3(offset.x,0,offset.y))
		var hit := current.get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(world_point+Vector3.UP*.08,world_point-Vector3.UP*.14,1))
		_check(not hit.is_empty() and absf((hit.get("position",Vector3.INF) as Vector3).y-world_point.y)<.035,
			id + ": unsupported story footprint " + String(prop["part_id"]) + " " + str(position) + " corner " + str(offset))


func _check_pavilion_footings(current: Node3D, prop: Dictionary, id: String) -> void:
	# The open pavilion's roof overhangs water. Sample its real imported foot
	# vertices instead of requiring solid terrain below empty AABB corners.
	var instance := StoryRenderer.instantiate_part("LakePavilion")
	if not _check(instance != null, id + ": required pavilion mesh unavailable for structural support check"):
		return
	var exclusions: Array[RID] = []
	var physical_anchor := current.get_node_or_null(NodePath("CampaignStoryProps/" + String(prop["id"]).validate_node_name()))
	if not _check(physical_anchor != null, id + ": actual pavilion collision anchor missing"):
		instance.free()
		return
	for body: StaticBody3D in physical_anchor.find_children("*", "StaticBody3D", true, false):
		exclusions.append(body.get_rid())
	var definition := StoryRenderer.get_part_definition("LakePavilion")
	var centers: Array[Vector3] = []
	for box: Dictionary in definition.get("navigation_boxes", []):
		var values: Array = box["center"]
		centers.append(Vector3(float(values[0]), 0, float(values[2])))
	_check(centers.size() == 8, id + ": pavilion must retain eight structural columns")
	var points: Dictionary = {}
	var represented: Dictionary = {}
	for mesh: MeshInstance3D in instance.get_children():
		for surface in mesh.mesh.get_surface_count():
			var vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for vertex: Vector3 in vertices:
				var local := mesh.transform * vertex
				if absf(local.y) > .015:
					continue
				var closest := -1
				var distance := INF
				for index in centers.size():
					var candidate := Vector2(local.x-centers[index].x, local.z-centers[index].z).length_squared()
					if candidate < distance:
						distance = candidate
						closest = index
				if closest >= 0:
					represented[closest] = true
				points[Vector2(local.x,local.z).snapped(Vector2(.001,.001))] = Vector3(local.x,0,local.z)
	instance.free()
	_check(represented.size() == 8 and points.size() >= 32, id + ": imported pavilion has no complete set of real footing vertices")
	var transform := Transform3D(Basis(Vector3.UP,float(prop.get("rotation_y",0.))).scaled_local(prop.get("scale",Vector3.ONE)),prop["position"])
	for local: Vector3 in points.values():
		var at := current.to_global(transform * local)
		var query := PhysicsRayQueryParameters3D.create(at+Vector3.UP*.08,at-Vector3.UP*.14,1,exclusions)
		var hit := current.get_world_3d().direct_space_state.intersect_ray(query)
		_check(not hit.is_empty() and absf((hit.get("position",Vector3.INF) as Vector3).y-at.y)<.035,
			id + ": actual pavilion footing has no supporting floor " + str(local))
	print("CAMPAIGN_PAVILION_STRUCTURAL_SUPPORT feet=%d vertices=%d" % [represented.size(),points.size()])


func _check_lake_roster(current: Node3D, actors: Array[Node3D]) -> void:
	var expected: Array[Vector2] = [Vector2(-6,-66),Vector2(0,-72),Vector2(6,-84)]
	var found: Array[int] = []
	var elite_count := 0
	_check(actors.size() == 7, "Lake roster has three true-stone spirits, two shore flowers and two elites")
	for enemy: Node3D in actors:
		var content := String(enemy.content_id)
		_check(content != "echo_spirit", "False-stone Echo Spirit is absent from the actual lake roster")
		if content == "elite_reflection_lord":
			elite_count += 1
		if content != "water_moon_spirit":
			continue
		var actual := current.to_local(enemy.global_position)
		var point := Vector2(actual.x, actual.z)
		var match_index := -1
		for index in expected.size():
			if expected[index].distance_to(point)<.06:
				match_index = index
		_check(match_index>=0 and not found.has(match_index), "Actual Water Moon Spirit stays on its distinct true stone " + str(point))
		found.append(match_index)
	_check(found.size()==3 and elite_count==1, "Actual lake has all three spirits and preserves its shore elite")


func _check_encounter(current: Node3D, layout: Dictionary, enemy: Node3D, entry: Dictionary, id: String) -> void:
	var point: Vector3 = entry["position"]
	if not _plans_only:
		var actual := current.to_local(enemy.global_position)
		_check(Vector2(actual.x-point.x,actual.z-point.z).length()<.06,
			id+": real enemy did not consume role plan "+String(entry["encounter_id"]))
	_check(Encounters.is_supported(layout,point,float(enemy.body_shape.radius)+.2), id+": enemy feet unsupported "+String(entry["encounter_id"]))
	_check(Encounters.is_clear(layout,point,float(enemy.body_shape.radius)+.5), id+": enemy inside reserved story region")
	_check(String(entry["activation"]) == "provoked" if id == "level_05_01" else true,
		id + ": contemplative shore creates an unsolicited combat encounter")
	var shape := CapsuleShape3D.new()
	shape.radius = float(enemy.body_shape.radius)
	shape.height = float(enemy.body_shape.height)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 1
	query.transform.origin = current.to_global(point + Vector3.UP*(shape.height*.5+.07))
	var hits := current.get_world_3d().direct_space_state.intersect_shape(query,16)
	var blockers: Array[String] = []
	for hit: Dictionary in hits:
		var collider: Node = hit["collider"]
		blockers.append(str(collider.get_path()))
	_check(hits.is_empty(), id + ": planned enemy capsule overlaps physical architecture " + str(entry["content_id"]) + " " + str(point) + " " + str(blockers))
	_check(entry["position"] != Vector3.ZERO and entry.has("facing_yaw") and entry.has("group_id"), id+": missing authored role data")
	for patrol: Vector3 in entry["patrol_points"]:
		_check(Encounters.is_supported(layout,patrol,shape.radius+.2), id+": patrol waypoint unsupported")
	var points: Array = entry["patrol_points"]
	if points.size()>=2:
		for index in points.size()-1:
			var from: Vector3 = points[index]
			var to: Vector3 = points[index+1]
			for sample in 13:
				var sample_point := from.lerp(to,float(sample)/12.)
				_check(Encounters.is_supported(layout,sample_point,shape.radius+.2),
					id+": authored patrol crosses a floor gap "+String(entry["encounter_id"]))


func _check_memorials_and_bells(id: String, props: Array[Dictionary]) -> void:
	if id == "level_05_04":
		var memorials: Dictionary = {}
		var living := 0
		for prop: Dictionary in props:
			var part := String(prop["part_id"])
			if part.begins_with("Memorial"):
				memorials[part] = true
			if part.begins_with("LivingSeal"):
				living += 1
		_check(memorials.size()==9 and living==3, "Nine dead and three living forgers must have distinct seats")
	if id == "level_05_06":
		var duplicate_bells := 0
		for prop: Dictionary in props:
			if prop["part_id"]=="DecoyBell":
				duplicate_bells += 1
		var anchors := Dressing.arena_interaction_anchors(id)
		_check((anchors.get("decoy_bells",[]) as Array).size()==12 and duplicate_bells==0,
			"Blind Bell arena must provide twelve owned decoy locations without duplicate static art")


func _by_key(plans: Array[Dictionary]) -> Dictionary:
	var result: Dictionary = {}
	for plan: Dictionary in plans:
		result[plan["encounter_id"]] = plan["position"]
	return result


func _freeze() -> void:
	_world.player.set_physics_process(false)
	_world.player.set_process(false)
	for enemy: Node in _world.enemies:
		enemy.set_physics_process(false)
		enemy.set_process(false)


func _check(value: bool, label: String) -> bool:
	_checks += 1
	if not value:
		_failures.append(label)
	return value
