extends SceneTree
## Static design acceptance only. It does not measure retry time, draw a frame,
## execute fall damage, or replace production door/lift/input/save tests.
## Story constraints: docs/story/lore.md (12 forgers,9 fallen,borrowed memories),
## main-story.md Chapters3-5, and chapter-bridge-map.md mandatory truth/choice order.
const Content = preload("res://scripts/data/campaign_content.gd")
const Layout = preload("res://scripts/world/campaign_modeled_layout.gd")
const Temple = preload("res://scripts/world/awakening_temple_layout.gd")
const CHAPTER_SOURCES := [preload("res://scripts/data/chapter_1_content.gd"), preload("res://scripts/data/chapter_2_content.gd"),
	preload("res://scripts/data/chapter_3_content.gd"), preload("res://scripts/data/chapter_4_content.gd"), preload("res://scripts/data/chapter_5_content.gd")]
const BOSSES := ["level_01_05", "level_02_06", "level_03_06", "level_04_04", "level_04_05", "level_04_06", "level_05_05", "level_05_06"]
const DESIGN_WALK_SPEED := 5.2
const INTERACTION_ALLOWANCE := 6.0
var _failures: Array[String] = []
var _checks := 0
var _buildings := 0
var _clues := 0
var _annexes := 0
var _chamber_returns := 0
var _vistas := 0
var _pressure_placements := 0
var _flags: Dictionary = {}
var _parts: Dictionary = {}
var _kits: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var props: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/environment/story_props/manifest.json"))
	var kits: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/environment/threejs_campaign/manifest.json"))
	if not _expect(props is Dictionary and props.has("parts") and kits is Dictionary and kits.has("themes"), "real asset manifests are required"):
		_finish()
		return
	_parts = props["parts"]
	_kits = kits["themes"]
	var count := 0
	for level: Dictionary in Content.levels():
		count += 1
		var id := String(level["id"])
		var state: Dictionary = Temple.expanded_state(Temple.read_manifest(), level) if id == "level_01_01" else Layout.create(level)
		var interior: Dictionary = state.get("expansion", {}).get("interior", {})
		if id in BOSSES:
			_expect(interior.is_empty(), id + " retains its authored boss approach")
			continue
		if not _expect(not interior.is_empty() and interior.has("souls"), id + " has a Souls loop"):
			continue
		_buildings += 1
		if id != "level_01_01":
			var baseline := Layout.create(level, false)
			for key: String in ["checkpoint", "story_anchors", "modules", "arena_interaction_anchors"]:
				_expect(state.get(key) == baseline.get(key), id + " loop does not rewrite main-story " + key)
		_check_recovery(id, state, interior)
		_check_vista(id, state, interior)
		_check_chamber_return(id, state, interior)
		_check_pressure(id, state, interior)
		_check_registered_changes(id, interior)
		_check_drop(id, state, interior)
		_check_roof(id, state, interior)
		_check_scene_evidence(id, interior)
		_check_ownership(id, interior)
		_check_top_rewards(id, state, interior)
		_check_annex(id, state, interior)
		if id == "level_05_01":
			_expect(state["expansion"]["encounters"].is_empty(), "peaceful shore district has no hostile guards")
	_expect(count == 29 and _buildings == 21, "all29 campaign levels include exactly21 occupied loop buildings")
	_expect(_clues == 63, "all63 room clues have inspected visual evidence")
	_expect(_annexes == 1, "exactly one cross-chapter archive storeroom")
	_expect(_chamber_returns == 1, "only the memory corridor relocates the final investigation downstairs")
	_expect(_vistas == 63, "three actual supported observations per occupied house")
	_expect(_pressure_placements == 60, "three authored threats in twenty houses; the shore remains peaceful")
	_finish()


func _check_recovery(id: String, state: Dictionary, interior: Dictionary) -> void:
	var souls: Dictionary = interior["souls"]
	var latch: Dictionary = souls["b2_latch"]
	var lift: Dictionary = souls["b2_lift"]
	var refuge: Dictionary = souls["refuge"]
	var flag := String(latch["flag"])
	_expect(flag.begins_with(id + "/") and flag.contains("door_b2_latch") and not _flags.has(flag), id + " latch persistence is namespaced and unique")
	_flags[flag] = true
	_expect(flag != String(interior["completion_flag"]) and String(lift["required_flag"]) == flag and String(refuge["unlock_flag"]) == flag, id + " earned B2 recovery is independent of all-three-puzzle completion")
	var upper: Vector3 = lift["upper_dock"]
	var lower: Vector3 = lift["lower_dock"]
	_expect(float(lift["travel_seconds"]) > 0 and float(lift["travel_seconds"]) <= 5, id + " local recovery budgets a real platform ride")
	_expect(is_equal_approx(upper.y - lower.y, 6.0) and is_equal_approx(upper.x, lower.x) and is_equal_approx(upper.z, lower.z), id + " local lift is a six-metre physical shaft")
	_expect(is_equal_approx(lower.y, float(interior["floor_heights"][0])) and is_equal_approx(upper.y, float(interior["floor_heights"][1])), id + " local shaft joins ground and patrol floors")
	var gate: Vector3 = latch["position"]
	var size: Vector3 = latch["size"]
	var basis := Basis(Vector3.UP, float(latch["yaw"]))
	var inside := (basis.inverse() * ((latch["far_side"] as Vector3) - gate)).z
	var outside := (basis.inverse() * (upper - gate)).z
	_expect(inside * outside < 0 and gate.distance_to(latch["far_side"]) <= 2.0, id + " latch is reachable only from the room side before unlocking")
	_expect(size.x >= 3.6 and size.x <= 4 and size.y >= 6 and size.z >= .4, id + " B2 door closes a narrow physical opening")
	_expect(_supported(latch["far_side"], state) and _supported(refuge["position"], state) and _supported(refuge["spawn_position"], state), id + " latch and earned refuge stand on real floors")
	for key: String in ["lower_landing", "upper_landing", "upper_return_landing"]:
		var landing: Vector3 = lift[key]
		var dock: Vector3 = lower if key == "lower_landing" else upper
		_expect(_supported(landing, state) and is_equal_approx(landing.distance_to(dock), 6), id + " adjacent floor at " + key)
		_expect(state["open_edges"].has(Layout.edge_key(_cell(landing), _cell(dock) - _cell(landing))), id + " open platform seam at " + key)
	for y in range(_cell(lower).y, _cell(upper).y + 1):
		_expect(not state["cell_set"].has(Vector3i(_cell(lower).x, y, _cell(lower).z)), id + " local shaft has no fixed floor obstruction")
	var route: Array = souls["b2return_route"]
	if not _expect(route.size() >= 4 and route.front() == refuge["position"], id + " recovery starts at the earned refuge"):
		return
	var walking := (refuge["spawn_position"] as Vector3).distance_to(refuge["position"])
	var rides := 0
	for index in route.size():
		var point: Vector3 = route[index]
		_expect(_supported(point, state) or point == upper or point == lower, id + " recovery waypoint has floor/platform support")
		if index == 0:
			continue
		var previous: Vector3 = route[index - 1]
		if not is_equal_approx(point.y, previous.y):
			_expect(previous == lower and point == upper, id + " recovery elevation change is the local moving platform")
			rides += 1
		else:
			walking += point.distance_to(previous)
			_expect(point.distance_to(previous) <= 6.01, id + " recovery walk has no unmodeled long gap")
	var seconds := walking / DESIGN_WALK_SPEED + float(lift["travel_seconds"]) * rides + INTERACTION_ALLOWANCE
	_expect(rides == 1 and walking <= 45 and seconds <= 20, id + " recovery DESIGN budget <=20s, including six seconds for interactions")
	_expect(is_equal_approx((route.back() as Vector3).y, upper.y) and (route.back() as Vector3).distance_to(gate) < 15, id + " retry reaches the patrol room rather than a remote corridor")
	print("SOULS_RECOVERY_DESIGN %s walk_m=%.1f ride_s=%.1f budget_s=%.2f measured=false" % [id, walking, lift["travel_seconds"], seconds])


func _check_vista(id: String, state: Dictionary, interior: Dictionary) -> void:
	var souls: Dictionary = interior["souls"]
	var landmark: Dictionary = souls["goal_landmark"]
	var final_stage: Dictionary = interior["stages"][2]
	var door: Dictionary = final_stage["door"]
	var at: Vector3 = door["position"]
	var views: Array = souls.get("vistas", [])
	_expect(views.size() == 3, id + " has ground, middle-gallery and exterior-approach observations")
	var seen: Dictionary = {}
	for vista: Dictionary in views:
		_vistas += 1
		var name := String(vista.get("id", ""))
		_expect(name in ["ground", "middle", "ramp"] and not seen.has(name), id + " named observation is unique")
		seen[name] = true
		var eye: Vector3 = vista["position"]
		var target: Vector3 = vista["look_at"]
		var feet := eye - Vector3.UP * 1.6
		_expect(vista["target_gate_id"] == final_stage["id"] and landmark["gate_id"] == final_stage["id"] and landmark["gate_position"] == at, id + " " + name + " references the actual final gate")
		var target_local := Basis(Vector3.UP, float(door["yaw"])).inverse() * (target - at)
		var size: Vector3 = door["size"]
		_expect(absf(target_local.x) <= size.x * .5 and target_local.y > 0 and target_local.y <= size.y and absf(target_local.z) <= 1, id + " sight target belongs to the door, not a proxy marker")
		_expect(_supported(feet, state), id + " " + name + " eye stands 1.6m above a real floor")
		var expected_y := float(interior["floor_heights"][1 if name == "middle" else 0])
		_expect(is_equal_approx(feet.y, expected_y), id + " observation is on its required storey")
		if name == "ramp":
			var relative := feet - (interior["origin"] as Vector3)
			_expect(absf(relative.x) > 21 or absf(relative.z) > 21, id + " approach observation is outside the house")
			var approach: Array = state["expansion"]["reward_spur"]
			var nearest := INF
			for point: Vector3 in approach:
				nearest = minf(nearest, point.distance_to(feet))
			_expect(nearest <= 9, id + " exterior observation adjoins the real reward approach")
		_expect(eye.distance_to(target) >= 15, id + " sightline crosses meaningful space")
		var obstruction := _obstruction(eye, target, state, interior)
		_expect(obstruction.is_empty(), id + " " + name + " static floor/masonry/rail sightline clear; obstruction=" + obstruction)
	_expect(interior["top_landmark"]["position"] == at and bool(interior["top_landmark"]["isolated_material"]), id + " distinctive goal material is attached to the actual door")
	var clue: Vector3 = interior["stages"][0]["clue_position"]
	var door_a: Vector3 = interior["stages"][0]["door"]["position"]
	var sight: Dictionary = interior.get("door_a_sight", {})
	_expect(clue.distance_to(door_a) <= 12, id + " door A is within fifteen ordinary steps of its clue")
	_expect(sight.get("target_gate_id") == interior["stages"][0]["id"] and sight.get("position") == clue + Vector3.UP * 1.6, id + " near-door sight begins at the actual clue")
	if not sight.is_empty():
		var actual_front := door_a + Vector3(0, 1.6, float(interior["stages"][0]["door"]["size"].z) * .5)
		_expect((sight["look_at"] as Vector3).distance_to(actual_front) < .001, id + " near-door target is the physical panel's front surface")
		var obstruction := _obstruction(sight["position"], sight["look_at"], state, interior)
		_expect(obstruction.is_empty(), id + " door A is directly visible; obstruction=" + obstruction)
	for control: Vector3 in interior["stages"][0]["controls_positions"]:
		# The four-metre evidence table must not overlap a control's approach.
		_expect(absf(control.x - clue.x) >= 2.7 or absf(control.z - clue.z) >= 1.7, id + " near-door evidence leaves control approach space")
	for key: String in ["optical_well", "upper_optical_well"]:
		var well: Dictionary = interior.get(key, {})
		if _expect(not well.is_empty(), id + " external sight has an explicit guarded " + key):
			var cell: Vector3i = well["cell"]
			_expect(not state["cell_set"].has(cell) and state["interior_cells"].has(cell), id + " optical well removes only its floor, not region recognition")
			var protected_edges := 0
			for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.BACK, Vector3i.FORWARD]:
				var neighbor := cell + direction
				if not state["cell_set"].has(neighbor):
					continue
				protected_edges += 1
				_expect(not state["open_edges"].has(Layout.edge_key(neighbor, -direction)), id + " occupied side of lightwell keeps its physical rail")
			_expect(protected_edges == 3, id + " lightwell has three supported guarded approaches")


func _check_chamber_return(id: String, state: Dictionary, interior: Dictionary) -> void:
	var exception := id == "level_03_02"
	_expect(bool(interior.get("chamber_violation", false)) == exception, id + " chamber relocation is exactly scoped")
	for index in 3:
		var stage: Dictionary = interior["stages"][index]
		_expect(int(stage["index"]) == index and int(stage["floor"]) == (0 if exception and index == 2 else index), id + " logical order remains distinct from the one physical-floor exception")
	if not exception:
		_expect(not interior.has("return_mirror") and not interior.has("memory_return"), id + " ordinary house keeps its original three-floor sequence")
		return
	_chamber_returns += 1
	var stage: Dictionary = interior["stages"][2]
	var origin: Vector3 = interior["origin"]
	_expect(stage["room_name"] == "归名月室·守门灯阁" and is_equal_approx((stage["clue_position"] as Vector3).y, origin.y), "03_02 final clue is the lower guarding-lamp chamber")
	_expect(is_equal_approx((stage["door"]["position"] as Vector3).y, origin.y + 12), "03_02 still operates the real final upper gate")
	var mirror: Dictionary = interior.get("return_mirror", {})
	var memory: Dictionary = interior.get("memory_return", {})
	if not _expect(not mirror.is_empty() and not memory.is_empty(), "03_02 supplies physical mirror and revisit anchors"):
		return
	var empty: Vector3 = mirror["empty_frame_position"]
	_expect(_supported(mirror["wall_position"], state) and _supported(empty, state), "03_02 real mirror and empty upper frame have floor support")
	_expect(is_equal_approx((mirror["wall_position"] as Vector3).y, origin.y) and is_equal_approx(empty.y, origin.y + 12), "03_02 mirror moves downstairs while its first-visit absence stays upstairs")
	var return_route: Array = interior["stages"][1]["to_next_route"]
	var finale: Array = stage["to_next_route"]
	var empty_index := return_route.find(empty)
	_expect(empty_index > 0 and empty_index < return_route.size() - 1, "03_02 visits the upper empty frame before returning downstairs")
	var guard_approach: Vector3 = memory["guard_approach"]
	var guard_index := return_route.find(guard_approach)
	_expect(guard_index > empty_index and guard_index < return_route.size() - 1 and guard_approach.y == empty.y, "03_02 first top visit reaches the shield guard after its empty frame")
	_expect(String(memory["guard_placement_id"]) == id + "/interior/top_shield" and guard_approach.distance_to(stage["door"]["position"]) < 10, "03_02 guard approach reaches the real final-gate corridor")
	_expect(return_route.back() == stage["clue_position"] and finale.front() == stage["clue_position"] and finale.back() == interior["reward_position"], "03_02 revisit and final return use the actual clue and upper reward")
	for route: Array in [return_route, finale]:
		_check_walk_route(id + " mirror revisit", route, state)
		for stair: Array in interior["stair_routes"]:
			for landing: Vector3 in stair:
				_expect(landing in route, "03_02 revisit has a complete walkable fallback through both opened stairs")
	for point: Vector3 in stage["controls_positions"]:
		_expect(is_equal_approx(point.y, origin.y) and _supported(point, state), "03_02 all final controls physically relocated downstairs")
	_expect(not interior.get("mounted_return_mirror", {}).is_empty() and interior["mounted_return_mirror"].get("looks_toward") == mirror["looks_toward"], "03_02 mounted memory mirror points back toward the ascent")


func _check_walk_route(label: String, route: Array, state: Dictionary) -> void:
	for index in route.size():
		var point: Vector3 = route[index]
		_expect(_supported(point, state), label + " waypoint has physical floor support")
		if index == 0:
			continue
		var previous: Vector3 = route[index - 1]
		if not is_equal_approx(point.y, previous.y):
			_expect(not _find_ramp(previous, point, state["ramps"]).is_empty(), label + " elevation changes only on a real internal ramp")
			continue
		var steps := maxi(1, ceili(point.distance_to(previous) * 2))
		for sample in range(1, steps):
			_expect(_supported(previous.lerp(point, float(sample) / steps), state), label + " continuous walkway has no unsupported skipped gap")


func _check_pressure(id: String, state: Dictionary, interior: Dictionary) -> void:
	var rows: Array = interior.get("interior_pressure", [])
	if id == "level_05_01":
		_expect(rows.is_empty(), "peaceful shore also excludes indoor threats")
		return
	_expect(rows.size() == 3, id + " one door ambush, one patrol and one final shield guard")
	var canonical: Dictionary = {}
	for enemy: Dictionary in CHAPTER_SOURCES[int(id.substr(6, 2)) - 1].enemies():
		canonical[String(enemy["id"])] = true
	var seen: Dictionary = {}
	var origin: Vector3 = interior["origin"]
	for row: Dictionary in rows:
		_pressure_placements += 1
		var placement := String(row["placement_id"])
		_expect(placement.begins_with(id + "/interior/") and not seen.has(placement), id + " pressure placement is stable and level scoped")
		seen[placement] = true
		_expect(canonical.has(String(row["content_id"])), id + " pressure uses real chapter enemy content")
		var point: Vector3 = row["position"]
		_expect(_supported(point, state) or _on_ramp(point, state["ramps"]), id + " pressure actor stands on the real floor/ramp")
		if String(row.get("combat_role", "")) == "door_ambush":
			var door: Dictionary = interior["stages"][0]["door"]
			var local := Basis(Vector3.UP, float(door["yaw"])).inverse() * (point - (door["position"] as Vector3))
			_expect(local.z < 0 and local.length() < 6 and String(row.get("activation", "")) == "provoked", id + " ambush waits immediately behind actual door A")
		elif String(row.get("combat_role", "")) == "front_shield":
			_expect(is_equal_approx(point.y, origin.y + 12) and point.distance_to(interior["stages"][2]["door"]["position"]) <= 8, id + " shield guard blocks the final physical upper-room approach")
		else:
			_expect(row.get("role") == "patrol" and is_equal_approx(point.y, origin.y + 6) and row.get("patrol_points", []).size() >= 2, id + " middle threat actually patrols the middle gallery")
			for patrol: Vector3 in row.get("patrol_points", []):
				_expect(_supported(patrol, state), id + " patrol endpoints have real floors")
		_expect(point.distance_to(interior["souls"]["refuge"]["position"]) > 15, id + " authored threats do not spawn beside the earned refuge")


func _check_registered_changes(id: String, interior: Dictionary) -> void:
	var mods: Dictionary = interior.get("interior_expansion_mods_v2", {})
	for key: String in ["stele_east_wall", "door_a_sight", "upper_sight_opening", "front_gallery_lightwell", "upper_gallery_lightwell", "b2_wall_passage", "interior_pressure", "chamber_revisit", "reward_glimpse", "roof_ladder_id"]:
		_expect(mods.has(key), id + " registers actual modification " + key)
	_expect(interior.get("roof_ladder_id") == interior["souls"]["roof_ladder"]["id"] and mods.get("roof_ladder_id") == interior.get("roof_ladder_id"), id + " named roof ladder resolves to real geometry")
	if mods.has("interior_pressure"):
		_expect(mods["interior_pressure"].get("placements") == interior["interior_pressure"], id + " registered pressure is the runtime placement plan")
	if mods.has("b2_wall_passage"):
		_expect(mods["b2_wall_passage"].get("latch_id") == interior["souls"]["b2_latch"]["id"], id + " registered wall passage is the physical B2 latch")


func _check_drop(id: String, state: Dictionary, interior: Dictionary) -> void:
	var drop: Dictionary = interior["souls"]["drop"]
	var top: Vector3 = drop["takeoff"]
	var bottom: Vector3 = drop["landing_center"]
	_expect(is_equal_approx(top.y - bottom.y, 12) and is_equal_approx(float(drop["fall_height"]), 12), id + " deliberate drop spans two whole storeys")
	_expect(_supported(top, state) and _supported(bottom, state), id + " drop begins and ends on actual floors")
	_expect(float(drop["damage_scale"]) > 0 and float(drop["damage_scale"]) < 1 and int(drop["minimum_damage"]) > 0, id + " book landing reduces damage without granting immunity")
	var size: Vector3 = drop["size"]
	_expect(size.x >= 3 and size.z >= 3 and size.x <= 8 and size.z <= 8, id + " cushion is a local landing zone")
	var direction := _cell(bottom) - _cell(top)
	direction.y = 0
	direction = Vector3i(signi(direction.x), 0, signi(direction.z))
	_expect(state["open_edges"].has(Layout.edge_key(_cell(top), direction)), id + " intended top drop edge has no blocking rail")
	for rise in range(1, 12):
		var sample := bottom + Vector3(0, rise, 0)
		_expect(not _floor_blocks(sample, state["cell_set"]), id + " middle floor does not intercept the twelve-metre fall")


func _check_roof(id: String, state: Dictionary, interior: Dictionary) -> void:
	var souls: Dictionary = interior["souls"]
	var route: Array = souls["roof_route"]
	if not _expect(route.size() >= 8 and route.front() == interior["reward_position"] and route.back() == souls["b2_lift"]["upper_return_landing"], id + " roof circuit joins the top reward gallery back to B2"):
		return
	var climbed := 0
	var descended := 0
	var peak := (route.front() as Vector3).y
	for index in route.size():
		var point: Vector3 = route[index]
		peak = maxf(peak, point.y)
		_expect(_supported(point, state), id + " roof waypoint has real floor support")
		if index == 0:
			continue
		var previous: Vector3 = route[index - 1]
		if is_equal_approx(previous.y, point.y):
			_expect(point.distance_to(previous) <= 6.01, id + " continuous roof walkway")
			continue
		var ramp := _find_ramp(previous, point, state["ramps"])
		if not _expect(not ramp.is_empty(), id + " each roof flight is a real production ramp"):
			continue
		var horizontal := point - previous
		horizontal.y = 0
		_expect(is_equal_approx(absf(point.y - previous.y), 2) and is_equal_approx(horizontal.length(), 12), id + " roof stair uses a supported two-cell physical rise")
		climbed += 1 if point.y > previous.y else 0
		descended += 1 if point.y < previous.y else 0
		var lower: Vector3i = ramp["lower"]
		var upper: Vector3i = ramp["upper"]
		var midpoint := Vector3i((lower.x + upper.x) / 2, lower.y, (lower.z + upper.z) / 2)
		_expect(not state["cell_set"].has(midpoint) and not state["cell_set"].has(midpoint + Vector3i.UP), id + " no tile fills a roof incline")
	_expect(climbed > 0 and descended > 0 and peak >= float(interior["floor_heights"][2]) + 6, id + " alternate exit actually crosses the roof and descends")
	var ladder: Dictionary = souls["roof_ladder"]
	var bottom: Vector3 = ladder["bottom"]
	var top: Vector3 = ladder["top"]
	_expect(top.y > bottom.y and top.distance_to(bottom) >= 3, id + " visible ladder describes a real climb")
	var ladder_route: Array = ladder["route"]
	_expect(ladder_route.size() >= 2 and (ladder_route.front() as Vector3).y == float(interior["floor_heights"][2]), id + " ladder starts at the upper reward-gallery elevation")
	for point: Vector3 in ladder_route:
		_expect(_supported(point, state) or _on_ramp(point, state["ramps"]), id + " ladder route rests on real landings/incline")
	_expect(_on_ramp(bottom.lerp(top, .5), state["ramps"]), id + " ladder rungs span the physical incline rather than a teleport")


func _check_scene_evidence(id: String, interior: Dictionary) -> void:
	for stage: Dictionary in interior["stages"]:
		_clues += 1
		var clue: Dictionary = stage.get("visual_clue", {})
		if not _expect(not clue.is_empty(), id + " each room supplies non-text evidence"):
			continue
		var links: Array = clue.get("cause_links", [])
		_expect(links.size() == 2 and links[0].size() == 2 and links[1].size() == 2, id + " visual evidence has two causal links")
		if links.size() == 2:
			_expect(links[0][1] == links[1][0] and links[0][0] != links[1][1], id + " source reaches receiver through a distinct relay")
		for link: Array in links:
			if link.size() != 2:
				continue
			_expect(clue.has(link[0]) and clue.has(link[1]), id + " visual link endpoints exist")
			if clue.has(link[0]) and clue.has(link[1]):
				_expect((clue[link[0]] as Vector3).distance_to(clue[link[1]]) >= .5, id + " visual link is spatially legible")
		var visuals: Array = stage.get("option_visuals", [])
		_expect(visuals.size() == 3 and bool(stage.get("clue_optional", false)), id + " text is optional and all three controls have visible seals")
		var shapes: Dictionary = {}
		var indices: Dictionary = {}
		for visual: Dictionary in visuals:
			var index := int(visual["option_index"])
			var shape := String(visual["shape"])
			_expect(shape in ["ring", "triangle", "square"] and not shapes.has(shape), id + " every option has a distinguishable shape")
			_expect(index in range(3) and not indices.has(index), id + " each physical option has one visual")
			shapes[shape] = true
			indices[index] = true
			if index in range(3):
				_expect(visual["position"] == stage["controls_positions"][index], id + " seal is attached to its actual control")
			if index == int(stage["correct_index"]):
				_expect(clue["shape"] == visual["shape"] and clue["color"] == visual["color"] and clue["control_position"] == visual["position"], id + " receiver visually identifies the actual correct control")


func _check_ownership(id: String, interior: Dictionary) -> void:
	var owners: Dictionary = {}
	for owner: Dictionary in interior.get("owners", []):
		owners[String(owner["id"])] = owner
		_expect(not String(owner["belongs_to"]).is_empty() and not String(owner["dead_owner_pose"]).is_empty(), id + " corpse has a named former role and authored pose")
		_expect(_parts.has(owner["part_id"]) and not owner["owned_prop_ids"].is_empty(), id + " posed owner belongs to actual scene objects")
	for prop: Dictionary in interior["props"]:
		var owner_id := String(prop.get("owner_id", ""))
		_expect(not String(prop.get("belongs_to", "")).is_empty() and not String(prop.get("dead_owner_pose", "")).is_empty() and owners.has(owner_id), id + " existing prop retains ownership and death evidence")
		if owners.has(owner_id):
			_expect(prop["id"] in owners[owner_id]["owned_prop_ids"], id + " prop and owner reference each other")
		for index in 3:
			if String(prop["id"]).contains("/room_%d/" % index):
				var next: Vector3 = interior["stages"][index]["door"]["position"]
				_expect(prop.get("looks_toward") == next, id + " room object points toward its next passage")
				var direction := next - (prop["position"] as Vector3)
				direction.y = 0
				var forward := Basis(Vector3.UP, float(prop["rotation_y"])) * Vector3.FORWARD
				_expect(forward.dot(direction.normalized()) > .98, id + " object orientation matches its next-room sightline")


func _check_top_rewards(id: String, state: Dictionary, interior: Dictionary) -> void:
	var flag := String(interior["completion_flag"])
	_expect(state["expansion"]["rewards"].size() == 1, id + " final room contains exactly one fixed ember cache")
	for reward: Dictionary in state["expansion"]["rewards"]:
		_expect(int(reward["embers"]) == 1 and reward["position"] == interior["reward_position"] and String(reward.get("required_flag", "")) == flag, id + " one fixed top ember requires the completed investigation")
		_expect(reward.get("visual_scale") == Vector3(1, 1.4, 1), id + " real lantern's luminous chamber rises above the retained gallery rail")
		_check_reward_vista(id, state, interior, reward)
	var pages := 0
	for readable: Dictionary in interior["scene_readables"]:
		if readable.get("kind") == "scribe_leaf":
			pages += 1
			var point: Vector3 = readable["position"]
			_expect(is_equal_approx(point.y, float(interior["floor_heights"][2])) and _supported(point, state), id + " contradiction page is physically in the top gallery")
			_expect(String(readable.get("required_flag", "")) == flag and String(readable["inscription"]).contains("\n") and String(readable["text"]).length() > 30, id + " top page has two conflicting records and the final-room condition")
	_expect(pages == 1, id + " one authored scribe page accompanies the top cache and roof exit")


func _check_reward_vista(id: String, state: Dictionary, interior: Dictionary, reward: Dictionary) -> void:
	var view: Dictionary = interior["souls"].get("reward_vista", {})
	if not _expect(not view.is_empty(), id + " final doorway overlooks the actual top ember"):
		return
	var eye: Vector3 = view["position"]
	var target: Vector3 = view["look_at"]
	var feet := eye - Vector3.UP * 1.6
	var gate: Dictionary = interior["stages"][2]["door"]
	var gate_local := Basis(Vector3.UP, float(gate["yaw"])).inverse() * (feet - (gate["position"] as Vector3))
	_expect(_supported(feet, state) and is_equal_approx(feet.y, float(interior["floor_heights"][2])), id + " reward observation stands on the real upper gallery")
	_expect(gate_local.z > 0 and feet.distance_to(gate["position"]) < 6.0 and not bool(view.get("requires_gate_open", true)), id + " reward is glimpsed at the final doorway before opening it")
	_expect(view.get("target_reward_id") == reward["id"] and target == (reward["position"] as Vector3) + Vector3.UP * 1.7, id + " reward sight targets the scaled real lantern, not a substitute marker")
	_expect(eye.distance_to(target) >= 15, id + " reward is seen across the atrium")
	var obstruction := _obstruction(eye, target, state, interior)
	_expect(obstruction.is_empty(), id + " actual reward static floor/masonry/rail sightline clear; obstruction=" + obstruction)
	for stage: Dictionary in interior["stages"]:
		var door: Dictionary = stage["door"]
		var size: Vector3 = door["size"]
		_expect(not _segment_box(eye, target, (door["position"] as Vector3) + Vector3.UP * size.y * .5, size, float(door["yaw"])), id + " reward ray clears every physically closed puzzle door")
	# Keep the full original north-gallery guard: this sight must not be won by
	# silently removing the player's fall barrier or cutting a new bypass.
	var origin: Vector3 = interior["origin"]
	var guarded_cell := _cell(origin + Vector3(-6, 12, -12))
	_expect(state["cell_set"].has(guarded_cell) and not state["open_edges"].has(Layout.edge_key(guarded_cell, Vector3i.FORWARD)), id + " reward sight retains the original full-height north-gallery rail")


func _check_annex(id: String, state: Dictionary, interior: Dictionary) -> void:
	var annex: Dictionary = interior["souls"].get("annex", {})
	if id != "level_04_03":
		_expect(annex.is_empty() and not interior.has("archive_annex"), id + " foreign archive is not copied to unrelated rooms")
		return
	_annexes += 1
	if not _expect(not annex.is_empty(), "04_03 has a real foreign storeroom"):
		return
	var center: Vector3 = annex["origin"]
	_expect(_supported(center, state) and _supported(annex["entry"], state), "archive annex has a physical entrance and floor")
	for x in [-6, 0, 6]:
		for z in [-6, 0, 6]:
			_expect(_supported(center + Vector3(x, 0, z), state), "archive annex contains an18m square usable room")
	var foreign_parts: Dictionary = {}
	for prop: Dictionary in interior["props"]:
		if not String(prop["id"]).contains("/foreign_store/"):
			continue
		foreign_parts[String(prop["part_id"])] = true
		_expect(_parts[prop["part_id"]]["theme"] == "blood_iron" and String(prop["belongs_to"]).contains("血铁"), "foreign objects carry blood-iron provenance and ownership")
	_expect(foreign_parts.has("WarTable") and foreign_parts.has("WarBanner"), "archive contains recognizable imported military table and banner")
	var letters := 0
	for readable: Dictionary in interior["scene_readables"]:
		if readable.get("kind") == "foreign_letter":
			letters += 1
			_expect(bool(readable.get("on_existing_table", false)) and String(readable["text"]).contains("血铁"), "cross-chapter transfer evidence lies on the existing table")
	_expect(letters == 1, "only04_03 has its specific foreign-store transfer letter")


func _obstruction(from: Vector3, to: Vector3, state: Dictionary, interior: Dictionary) -> String:
	for cell: Vector3i in state["cell_set"]:
		var point := _floor(cell)
		if _segment_box(from, to, point + Vector3(0, -.3, 0), Vector3(6, .6, 6), 0):
			return "floor " + str(cell)
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]:
			if state["cell_set"].has(cell + direction) or state["open_edges"].has(Layout.edge_key(cell, direction)):
				continue
			var at := point + Vector3(direction.x, 0, -direction.z) * 2.88 + Vector3(0, .7, 0)
			if _segment_box(from, to, at, Vector3(6, 1.4, .48), PI * .5 if direction.x != 0 else 0):
				return "rail " + str(cell) + " " + str(direction)
	for box: Dictionary in interior["solid_boxes"]:
		if _segment_box(from, to, box["position"], box["size"], float(box.get("yaw", 0))):
			return "masonry " + str(box["position"])
	var theme := String(state["theme"]).trim_prefix("theme_")
	for feature: Dictionary in interior["architecture"]:
		if feature["part"] != "Column":
			continue
		var bounds: Dictionary = _kits[theme]["parts"]["Column"]
		var minimum := _vector(bounds["min"])
		var maximum := _vector(bounds["max"])
		var scale: Vector3 = feature["scale"]
		var yaw := float(feature.get("yaw", 0))
		var center: Vector3 = feature["position"] + Basis(Vector3.UP, yaw) * ((minimum + maximum) * .5 * scale)
		if _segment_box(from, to, center, (maximum - minimum) * scale, yaw):
			return "column " + str(center)
	return ""


func _segment_box(from: Vector3, to: Vector3, center: Vector3, size: Vector3, yaw: float) -> bool:
	var inverse := Basis(Vector3.UP, yaw).inverse()
	var start := inverse * (from - center)
	var delta := inverse * (to - from)
	var near := .0001
	var far := .9999
	for axis in 3:
		var half := size[axis] * .5
		if absf(delta[axis]) < .00001:
			if absf(start[axis]) > half:
				return false
			continue
		var first := (-half - start[axis]) / delta[axis]
		var last := (half - start[axis]) / delta[axis]
		near = maxf(near, minf(first, last))
		far = minf(far, maxf(first, last))
		if near > far:
			return false
	return true


func _find_ramp(a: Vector3, b: Vector3, ramps: Array) -> Dictionary:
	for ramp: Dictionary in ramps:
		if (_cell(a) == ramp["lower"] and _cell(b) == ramp["upper"]) or (_cell(b) == ramp["lower"] and _cell(a) == ramp["upper"]):
			return ramp
	return {}


func _on_ramp(point: Vector3, ramps: Array) -> bool:
	for ramp: Dictionary in ramps:
		var lower := _floor(ramp["lower"])
		var upper := _floor(ramp["upper"])
		var direction := upper - lower
		direction.y = 0
		direction = direction.normalized()
		var offset := point - lower
		var distance := offset.dot(direction)
		var lateral := Vector3(offset.x, 0, offset.z) - direction * distance
		if distance >= 3 and distance <= 9 and lateral.length() <= 3 and is_equal_approx(point.y, lower.y + (distance - 3) / 3):
			return true
	return false


func _floor_blocks(point: Vector3, cells: Dictionary) -> bool:
	for cell: Vector3i in cells:
		var top := _floor(cell)
		if absf(point.x - top.x) <= 3 and absf(point.z - top.z) <= 3 and point.y <= top.y and point.y >= top.y - .6:
			return true
	return false


func _supported(point: Vector3, state: Dictionary) -> bool:
	var center := _cell(point)
	for x in [-1, 0, 1]:
		for z in [-1, 0, 1]:
			var cell := center + Vector3i(x, 0, z)
			var at := _floor(cell)
			if state["cell_set"].has(cell) and is_equal_approx(point.y, at.y) and absf(point.x - at.x) <= 3.001 and absf(point.z - at.z) <= 3.001:
				return true
	return false


func _cell(point: Vector3) -> Vector3i:
	return Vector3i(roundi(point.x / 6), roundi(point.y / 2), roundi(-point.z / 6))


func _floor(cell: Vector3i) -> Vector3:
	return Vector3(cell.x * 6, cell.y * 2, -cell.z * 6)


func _vector(value: Array) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2]))


func _expect(condition: bool, label: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(label)
	return condition


func _finish() -> void:
	if _failures.is_empty():
		print("ASHEN_CAMPAIGN_INTERIOR_SOULS_LAYOUT_CONTRACT_OK buildings=%d visual_clues=%d annexes=%d checks=%d measured_runtime=false rendered_visibility=false" % [_buildings, _clues, _annexes, _checks])
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)
