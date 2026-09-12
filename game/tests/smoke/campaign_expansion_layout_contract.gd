extends SceneTree
## Pure-data topology audit. Physics/input and target-renderer gates are separate.
const Content = preload("res://scripts/data/campaign_content.gd")
const Layout = preload("res://scripts/world/campaign_modeled_layout.gd")
const Chapters := [preload("res://scripts/data/chapter_1_content.gd"), preload("res://scripts/data/chapter_2_content.gd"),
	preload("res://scripts/data/chapter_3_content.gd"), preload("res://scripts/data/chapter_4_content.gd"), preload("res://scripts/data/chapter_5_content.gd")]
var _failures: Array[String] = []
var _checks := 0
var _levels := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var pilot := "--pilot" in OS.get_cmdline_user_args()
	var known_enemies: Dictionary = {}
	for chapter: Script in Chapters:
		for enemy: Dictionary in chapter.enemies():
			known_enemies[String(enemy["id"])] = true
	for level: Dictionary in Content.levels():
		var id := String(level["id"])
		if id == "level_01_01" or (pilot and id != "level_01_02"):
			continue
		var baseline := Layout.create(level, false)
		var expanded := Layout.create(level)
		if not _expect(expanded.has("expansion"), id + " has district"):
			continue
		_check_level(id, baseline, expanded, known_enemies)
		_levels += 1
	_expect(_levels == (1 if pilot else 28), "all requested modeled levels checked")
	if _failures.is_empty():
		print("ASHEN_CAMPAIGN_EXPANSION_LAYOUT_CONTRACT_OK levels=%d checks=%d pilot=%s" % [_levels, _checks, pilot])
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _check_level(id: String, baseline: Dictionary, expanded: Dictionary, known_enemies: Dictionary) -> void:
	var district: Dictionary = expanded["expansion"]
	var cells: Dictionary = expanded["cell_set"]
	for key: String in ["route", "modules", "story_anchors", "arena_interaction_anchors", "story_props", "features",
		"spawn", "checkpoint", "exit", "encounter_positions", "boss_arena_center", "boss_arena_radius", "boss_spawn"]:
		_expect(baseline.get(key) == expanded.get(key), id + " unchanged " + key)
	for cell: Vector3i in baseline["cell_set"]:
		_expect(cells.has(cell), id + " retained original terrain " + str(cell))
	var path: Array = district["traversal_route"]
	var length := 0.0
	for index in path.size():
		_expect(_supported(path[index], cells), id + " supported route waypoint " + str(index))
		if index > 0:
			length += (path[index] as Vector3).distance_to(path[index - 1])
			_expect(_neighbors(_cell(path[index - 1]), _cell(path[index]), expanded["ramps"]), id + " continuous route " + str(index))
	for route_key: String in ["reward_spur", "lift_route"]:
		var branch: Array = district[route_key]
		for index in branch.size():
			_expect(_supported(branch[index], cells), id + " supported " + route_key)
			if index > 0:
				_expect(_neighbors(_cell(branch[index - 1]), _cell(branch[index]), expanded["ramps"]), id + " connected " + route_key)
	var boss: bool = district["boss_approach"]
	_expect(length >= (90.0 if boss else 180.0), id + " meaningful traversal length %.1fm" % length)
	_expect((district["overlook"] as Vector3).y - (district["entry"] as Vector3).y >= 6.0, id + " distinct upper layer")
	if not boss:
		_expect(float(district["entry_route_fraction"]) >= .35 and float(district["entry_route_fraction"]) <= .8, id + " earned mid-route return")
		_check_gate(id, district["return_gate"], cells)
		_check_lift(id, district["lift"], cells, expanded["open_edges"])
	else:
		var center: Vector3 = expanded["boss_arena_center"]
		var radius: float = expanded["boss_arena_radius"]
		for cell: Vector3i in district["new_cells"]:
			var at := Layout.floor_position(cell)
			_expect(Vector2(at.x - center.x, at.z - center.z).length() - 4.25 >= radius + 10.0, id + " expansion outside arena approach margin")
	for ramp: Dictionary in expanded["ramps"]:
		var lower: Vector3i = ramp["lower"]
		var upper: Vector3i = ramp["upper"]
		_expect(upper.y - lower.y == 1 and absi(upper.x - lower.x) + absi(upper.z - lower.z) == 2, id + " production ramp dimensions")
		_expect(cells.has(lower) and cells.has(upper), id + " ramp landing support")
		var middle := Vector3i((lower.x + upper.x) / 2, lower.y, (lower.z + upper.z) / 2)
		_expect(not cells.has(middle) and not cells.has(middle + Vector3i.UP), id + " ramp gap remains clear")
	for cell: Vector3i in district["new_cells"]:
		for height in [-2, -1, 1, 2]:
			_expect(not cells.has(cell + Vector3i(0, height, 0)), id + " at least 6m layer clearance " + str(cell))
	var placement_ids: Dictionary = {}
	for encounter: Dictionary in district["encounters"]:
		_expect(known_enemies.has(encounter["content_id"]), id + " existing guard content")
		_expect(not placement_ids.has(encounter["placement_id"]), id + " unique guard placement")
		placement_ids[encounter["placement_id"]] = true
		_expect(_supported(encounter["position"], cells), id + " guard supported")
		for point: Vector3 in encounter["patrol_points"]:
			_expect(_supported(point, cells), id + " patrol supported")
	_expect(district["encounters"].size() == 0 if boss or id == "level_05_01" else district["encounters"].size() in [2, 3], id + " restrained chapter-appropriate encounters")
	for reward: Dictionary in district["rewards"]:
		_expect(_supported(reward["position"], cells) and int(reward["embers"]) > 0, id + " supported real ember reward")
		_expect(not String(reward["lore_text"]).is_empty(), id + " authored story evidence")
	print("DISTRICT %s name=%s length=%.1f entry=%.3f cells=%d guards=%d high=%s" % [id, district["display_name"], length,
		district["entry_route_fraction"], district["new_cells"].size(), district["encounters"].size(), district["overlook"]])


func _check_gate(id: String, gate: Dictionary, cells: Dictionary) -> void:
	_expect(is_equal_approx(float(gate["clear_width"]), 3.8), id + " 3.8m real gate aperture")
	var position: Vector3 = gate["position"]
	var far: Vector3 = gate["far_side"]
	_expect(position.distance_to(far) < 1.7 and absf(far.x - position.x) >= 1.3, id + " reachable latch truly beside far side")
	_expect(gate["walls"].size() == 4, id + " gate wings and anti-bypass sidewalls")
	for wall: Dictionary in gate["walls"]:
		_expect((wall["size"] as Vector3).y >= 6.0, id + " walls above jump height")
	var center := _cell(position)
	for x in [-1, 0, 1]:
		_expect(cells.has(center + Vector3i(x, 0, 0)), id + " continuous gate throat")
		for z in [-1, 1]:
			_expect(not cells.has(center + Vector3i(x, 0, z)), id + " no side tiles around locked gate")


func _check_lift(id: String, lift: Dictionary, cells: Dictionary, open_edges: Dictionary) -> void:
	var upper: Vector3 = lift["upper_dock"]
	var lower: Vector3 = lift["lower_dock"]
	_expect(is_equal_approx(upper.x, lower.x) and is_equal_approx(upper.z, lower.z) and upper.y - lower.y >= 6.0, id + " physical vertical lift")
	var shaft := _cell(lower)
	for y in range(shaft.y, _cell(upper).y + 1):
		_expect(not cells.has(Vector3i(shaft.x, y, shaft.z)), id + " clear lift shaft")
	for key: String in ["upper_landing", "lower_landing", "upper_exit", "lower_exit"]:
		_expect(_supported(lift[key], cells), id + " accessible lift " + key)
	for key: String in ["upper_landing", "lower_landing"]:
		_expect(open_edges.has(Layout.edge_key(_cell(lift[key]), Vector3i(0, 0, -1))), id + " lift landing has open rail seam")


func _neighbors(a: Vector3i, b: Vector3i, ramps: Array) -> bool:
	if a == b or (a.y == b.y and absi(a.x - b.x) + absi(a.z - b.z) == 1):
		return true
	for ramp: Dictionary in ramps:
		if (a == ramp["lower"] and b == ramp["upper"]) or (b == ramp["lower"] and a == ramp["upper"]):
			return true
	return false


func _cell(point: Vector3) -> Vector3i:
	return Vector3i(roundi(point.x / 6.0), roundi(point.y / 2.0), roundi(-point.z / 6.0))


func _supported(point: Vector3, cells: Dictionary) -> bool:
	return cells.has(_cell(point))


func _expect(condition: bool, message: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(message)
	return condition
