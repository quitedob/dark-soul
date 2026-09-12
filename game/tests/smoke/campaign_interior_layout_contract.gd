extends SceneTree
## Independent dimensional/data acceptance for occupied interiors. The separate
## production-physics/input suite proves door blocking, walking and save/reload.
const Content = preload("res://scripts/data/campaign_content.gd")
const Layout = preload("res://scripts/world/campaign_modeled_layout.gd")
const Temple = preload("res://scripts/world/awakening_temple_layout.gd")
const PROP_MANIFEST := "res://assets/environment/story_props/manifest.json"
const BOSS_EXCLUSIONS := ["level_01_05", "level_02_06", "level_03_06", "level_04_04",
	"level_04_05", "level_04_06", "level_05_05", "level_05_06"]
var _failures: Array[String] = []
var _checks := 0
var _buildings := 0
var _bosses := 0
var _clues: Dictionary = {}
var _completion_flags: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROP_MANIFEST))
	if not _expect(parsed is Dictionary and parsed.has("parts"), "real story-prop manifest is required"):
		_finish()
		return
	var known_parts: Dictionary = parsed["parts"]
	var levels: Array = Content.levels()
	_expect(levels.size() == 29, "full campaign contains exactly 29 levels including the temple")
	var seen: Dictionary = {}
	for level: Dictionary in levels:
		var id := String(level["id"])
		_expect(not seen.has(id), "unique level " + id)
		seen[id] = true
		var state: Dictionary
		if id == "level_01_01":
			var manifest := Temple.read_manifest()
			state = Temple.expanded_state(manifest, level)
			for cell: Vector3i in Temple.walkable_cells(manifest):
				_expect(state["cell_set"].has(cell), id + " retains original temple floor " + str(cell))
		else:
			state = Layout.create(level)
			var original := Layout.create(level, false)
			for key: String in ["route", "modules", "story_anchors", "arena_interaction_anchors", "encounter_positions", "spawn", "checkpoint", "exit"]:
				_expect(state.get(key) == original.get(key), id + " preserves core " + key)
		var district: Dictionary = state.get("expansion", {})
		if not _expect(not district.is_empty(), id + " has expansion data"):
			continue
		if id in BOSS_EXCLUSIONS:
			_bosses += 1
			_expect(not district.has("interior"), id + " boss approach has no generic room puzzle")
			continue
		if not _expect(district.has("interior"), id + " requires an occupied three-storey building"):
			continue
		_buildings += 1
		_check_building(id, state, known_parts)
		if id == "level_05_01":
			_expect(district["encounters"].is_empty(), "the shore extension remains peaceful")
	_expect(_buildings == 21 and _bosses == 8, "exactly 21 occupied buildings and 8 boss exclusions")
	_finish()


func _check_building(id: String, state: Dictionary, known_parts: Dictionary) -> void:
	var district: Dictionary = state["expansion"]
	var interior: Dictionary = district["interior"]
	var origin: Vector3 = interior["origin"]
	var heights: Array = interior["floor_heights"]
	if not _expect(heights.size() == 3, id + " exactly three occupied floors"):
		return
	_expect(is_equal_approx(float(heights[0]), origin.y), id + " ground room matches its entrance height")
	for index in [1, 2]:
		_expect(is_equal_approx(float(heights[index]) - float(heights[index - 1]), 6.0), id + " six-metre storey separation")
	var cells: Dictionary = state["cell_set"]
	var floor_sets: Array[Dictionary] = [{}, {}, {}]
	for cell: Vector3i in interior["building_cells"]:
		_expect(cells.has(cell), id + " declared building floor exists " + str(cell))
		var at := _floor(cell)
		if absf(at.x - origin.x) > 21 or absf(at.z - origin.z) > 21:
			continue
		_expect(state.get("interior_cells", {}).has(cell), id + " renderer recognises occupied interior floor")
		for index in 3:
			if is_equal_approx(at.y, float(heights[index])):
				floor_sets[index][Vector2i(cell.x, cell.z)] = true
		for offset in [-2, -1, 1, 2]:
			_expect(not cells.has(cell + Vector3i(0, offset, 0)), id + " no two/four-metre overlapping floor " + str(cell))
	for index in 3:
		_expect(floor_sets[index].size() >= 20, id + " floor %d has at least 720 square metres of actual rooms" % index)
	var common := 0
	for footprint: Vector2i in floor_sets[0]:
		if floor_sets[1].has(footprint) and floor_sets[2].has(footprint):
			common += 1
	_expect(common >= 18, id + " floors overlap by at least 648 square metres; they are not remote terraces")
	_check_atrium(id, interior, state)
	_check_stairs(id, interior, state)
	_check_stages(id, interior, state, known_parts)
	_check_exit(id, district, state)
	var architecture_parts: Dictionary = {}
	for feature: Dictionary in interior["architecture"]:
		architecture_parts[String(feature["part"])] = true
	for part: String in ["Wall", "Roof", "Column", "Lantern"]:
		_expect(architecture_parts.has(part), id + " occupied architecture includes " + part)
	_expect(not interior["solid_boxes"].is_empty(), id + " rooms have physical masonry")
	for prop: Dictionary in interior["props"]:
		var part_id := String(prop["part_id"])
		if not _expect(known_parts.has(part_id), id + " real imported room part " + part_id):
			continue
		var definition: Dictionary = known_parts[part_id]
		_expect(FileAccess.file_exists(String(definition["resource"])), id + " prop source GLB exists")
		var size: Array = definition["bounds"]["size"]
		_expect(float(size[1]) * (prop["scale"] as Vector3).y <= 5.4, id + " imported prop fits a six-metre storey")
		_expect(_supported(prop["position"], cells), id + " room prop has real floor support")
	_expect(String(interior["story_source"]).begins_with("docs/story/"), id + " room investigation cites story source")
	print("INTERIOR %s floors=3 shared_tiles=%d cells=%d props=%d" % [id, common, interior["building_cells"].size(), interior["props"].size()])


func _check_atrium(id: String, interior: Dictionary, state: Dictionary) -> void:
	var origin: Vector3 = interior["origin"]
	var atrium: Dictionary = interior["atrium"]
	var size: Vector3 = atrium["size"]
	_expect(size.x >= 18 and size.z >= 18, id + " atrium is at least 18 by 18 metres")
	var cells: Dictionary = state["cell_set"]
	for x in [-6, 0, 6]:
		for z in [-6, 0, 6]:
			var ground := origin + Vector3(x, 0, z)
			_expect(_supported(ground, cells), id + " atrium has an occupied ground floor")
			for rise in range(2, 18, 2):
				var sample := _cell(ground + Vector3(0, rise, 0))
				_expect(not cells.has(sample), id + " atrium stays open above ground " + str(sample))
				_expect(state.get("interior_cells", {}).has(sample), id + " atrium void suppresses default tall boundary walls")


func _check_stairs(id: String, interior: Dictionary, state: Dictionary) -> void:
	var stairs: Array = interior["stair_routes"]
	if not _expect(stairs.size() == 2, id + " two internal storey connections"):
		return
	var heights: Array = interior["floor_heights"]
	for index in 2:
		var route: Array = stairs[index]
		if not _expect(route.size() >= 4, id + " stair has successive supported landings"):
			continue
		_expect(is_equal_approx((route.front() as Vector3).y, float(heights[index])) and
			is_equal_approx((route.back() as Vector3).y, float(heights[index + 1])), id + " stairs rise forward to the next floor")
		for step in range(1, route.size()):
			var lower: Vector3 = route[step - 1]
			var upper: Vector3 = route[step]
			var horizontal := upper - lower
			horizontal.y = 0
			_expect(is_equal_approx(upper.y - lower.y, 2.0) and is_equal_approx(horizontal.length(), 12.0), id + " one physical rise per two-cell flight")
			_expect(_has_ramp(state["ramps"], _cell(lower), _cell(upper)), id + " staircase uses a production ramp")
			_expect(_supported(lower, state["cell_set"]) and _supported(upper, state["cell_set"]), id + " both stair landings are real floors")
			var direction := horizontal.normalized()
			for distance in range(0, 13):
				# Landings occupy the first/last three metres. The actual incline
				# crosses the intervening six metres, not the entire centre span.
				var sample := lower + direction * distance
				sample.y += clampf((float(distance) - 3.0) / 6.0, 0, 1) * 2.0
				_expect(_headroom(sample, state["cell_set"], interior["solid_boxes"]), id + " usable stair headroom at " + str(sample))


func _check_stages(id: String, interior: Dictionary, state: Dictionary, known_parts: Dictionary) -> void:
	var stages: Array = interior["stages"]
	if not _expect(stages.size() == 3, id + " one clue and gate stage on every floor"):
		return
	var room_names: Dictionary = {}
	for index in 3:
		var stage: Dictionary = stages[index]
		var label := id + " stage " + str(index)
		var mirror_return := id == "level_03_02" and index == 2
		var expected_floor := 0 if mirror_return else index
		_expect(int(stage["index"]) == index and int(stage["floor"]) == expected_floor, label + " has forward investigation order and its authored physical floor")
		var clue: Vector3 = stage["clue_position"]
		_expect(is_equal_approx(clue.y, float(interior["floor_heights"][expected_floor])) and _supported(clue, state["cell_set"]), label + " clue stands on the intended floor")
		var clue_text := String(stage["clue_text"]).strip_edges()
		var clue_key := id.substr(6, 2) + ":" + clue_text
		_expect(clue_text.length() >= 12 and not _clues.has(clue_key), label + " has distinct authored evidence within its chapter")
		_clues[clue_key] = true
		var room := String(stage["room_name"])
		_expect(not room.is_empty() and not room_names.has(room), label + " is a distinct useful room")
		room_names[room] = true
		var options: Array = stage["options"]
		_expect(options.size() == 3 and int(stage["correct_index"]) in range(3), label + " offers three choices with a valid answer")
		var option_texts: Dictionary = {}
		for option: String in options:
			_expect(not option.strip_edges().is_empty() and not option_texts.has(option), label + " choices have distinct readable text")
			option_texts[option] = true
		var controls: Array = stage["controls_positions"]
		_expect(controls.size() == 3, label + " provides three physical controls")
		var door: Dictionary = stage["door"]
		var size: Vector3 = door["size"]
		var at: Vector3 = door["position"]
		_expect(size.x >= 3.6 and size.x <= 4.0 and size.y >= 6.0 and size.z >= .4, label + " has a narrow door taller than a jump")
		_expect(is_equal_approx(at.y, float(interior["floor_heights"][index])), label + " door remains on its authored storey")
		var basis := Basis(Vector3.UP, float(door["yaw"]))
		var approach := (basis.inverse() * (clue - at)).z
		for control_index in controls.size():
			var control: Vector3 = controls[control_index]
			_expect(_supported(control, state["cell_set"]) and is_equal_approx(control.y, clue.y), label + " supported control on clue floor")
			if not mirror_return:
				_expect((basis.inverse() * (control - at)).z * approach > 0, label + " controls are before their gate")
			else:
				_expect(is_equal_approx(at.y - control.y, 12.0), label + " return mirror operates the actual upper gate from its explicitly authored lower chamber")
			for other in range(control_index):
				_expect(control.distance_to(controls[other]) >= 1.8, label + " controls have separate approach space")
		for side in [-1, 1]:
			for height in [1.0, 5.5]:
				_expect(_inside_masonry(at + basis * Vector3(side * 2.2, height, 0), interior["solid_boxes"]), label + " gate wings physically close side gaps")
		for part: String in stage["prop_ids"]:
			_expect(known_parts.has(part), label + " interactable uses a real recipe part ID")
		_expect(not stage["prop_ids"].is_empty(), label + " has authored clue scenery")
		var next_route: Array = stage["to_next_route"]
		if _expect(not next_route.is_empty(), label + " has a forward route out of the room"):
			var destination_floor := 0 if id == "level_03_02" and index == 1 else mini(index + 1, 2)
			_expect(is_equal_approx((next_route.front() as Vector3).y, clue.y) and
				is_equal_approx((next_route.back() as Vector3).y, float(interior["floor_heights"][destination_floor])), label + " route ends on the next required physical floor")
			for waypoint in next_route.size():
				var point: Vector3 = next_route[waypoint]
				_expect(_supported(point, state["cell_set"]), label + " next-room waypoint has real support")
				if waypoint > 0 and not (id == "level_03_02" and index == 1):
					_expect(point.y >= (next_route[waypoint - 1] as Vector3).y, label + " puzzle order never descends to a previous floor")


func _check_exit(id: String, district: Dictionary, state: Dictionary) -> void:
	var interior: Dictionary = district["interior"]
	var flag := String(interior["completion_flag"])
	_expect(not flag.is_empty() and not _completion_flags.has(flag), id + " has a unique persistent completion flag")
	_completion_flags[flag] = true
	var top_y := float(interior["floor_heights"][2])
	var reward_position: Vector3 = interior["reward_position"]
	_expect(is_equal_approx(reward_position.y, top_y) and _supported(reward_position, state["cell_set"]), id + " finale reward occupies top room")
	_expect(not district["rewards"].is_empty(), id + " completed side investigation has a useful reward")
	for reward: Dictionary in district["rewards"]:
		_expect(reward["position"] == reward_position and String(reward.get("required_flag", "")) == flag and int(reward["embers"]) > 0, id + " real ember reward requires all rooms")
	var lift: Dictionary = district["lift"]
	var upper: Vector3 = lift["upper_dock"]
	var lower: Vector3 = lift["lower_dock"]
	_expect(is_equal_approx(upper.y, top_y) and is_equal_approx(upper.x, lower.x) and is_equal_approx(upper.z, lower.z), id + " top exit uses one physical vertical shaft")
	_expect(is_equal_approx(lower.y, (state["checkpoint"] as Vector3).y) and upper.y - lower.y >= 12.0, id + " lift returns from the roof level to the shrine elevation")
	_expect(String(lift.get("required_flag", "")) == flag and String(district["return_gate"].get("required_flag", "")) == flag, id + " reverse shortcut cannot bypass incomplete floors")
	var route: Array = interior["exit_route"]
	_expect(not route.is_empty() and route.front() == reward_position and route.back() == lift["upper_landing"], id + " forward route joins final room to upper landing")
	for index in route.size():
		var point: Vector3 = route[index]
		_expect(is_equal_approx(point.y, top_y) and _supported(point, state["cell_set"]), id + " top exit has continuous actual floor")
		if index > 0:
			_expect(point.distance_to(route[index - 1]) <= 6.01, id + " no unsupported exit waypoint gaps")
	for prefix: String in ["upper", "lower"]:
		var landing: Vector3 = lift[prefix + "_landing"]
		var dock: Vector3 = lift[prefix + "_dock"]
		_expect(_supported(landing, state["cell_set"]) and is_equal_approx(landing.distance_to(dock), 6.0), id + " shaft has adjacent " + prefix + " landing")
		var direction := _cell(dock) - _cell(landing)
		_expect(state["open_edges"].has(Layout.edge_key(_cell(landing), direction)), id + " landing rail leaves shaft entry open")
	for y in range(_cell(lower).y, _cell(upper).y + 1):
		_expect(not state["cell_set"].has(Vector3i(_cell(lower).x, y, _cell(lower).z)), id + " shaft is unobstructed throughout ascent")


func _headroom(point: Vector3, cells: Dictionary, boxes: Array) -> bool:
	for cell: Vector3i in cells:
		var floor_point := _floor(cell)
		if absf(point.x - floor_point.x) < 2.99 and absf(point.z - floor_point.z) < 2.99:
			if floor_point.y > point.y + .1 and floor_point.y - .6 < point.y + 2.4:
				return false
	for height in [.5, 1.5, 2.4]:
		if _inside_masonry(point + Vector3(0, height, 0), boxes):
			return false
	return true


func _inside_masonry(point: Vector3, boxes: Array) -> bool:
	for box: Dictionary in boxes:
		var local := Basis(Vector3.UP, float(box.get("yaw", 0.0))).inverse() * (point - (box["position"] as Vector3))
		var half: Vector3 = (box["size"] as Vector3) * .5
		if absf(local.x) <= half.x and absf(local.y) <= half.y and absf(local.z) <= half.z:
			return true
	return false


func _has_ramp(ramps: Array, lower: Vector3i, upper: Vector3i) -> bool:
	for ramp: Dictionary in ramps:
		if ramp["lower"] == lower and ramp["upper"] == upper:
			return true
	return false


func _supported(point: Vector3, cells: Dictionary) -> bool:
	return cells.has(_cell(point)) and is_equal_approx(point.y, float(_cell(point).y) * 2.0)


func _cell(point: Vector3) -> Vector3i:
	return Vector3i(roundi(point.x / 6), roundi(point.y / 2), roundi(-point.z / 6))


func _floor(cell: Vector3i) -> Vector3:
	return Vector3(cell.x * 6, cell.y * 2, -cell.z * 6)


func _expect(condition: bool, label: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(label)
	return condition


func _finish() -> void:
	if _failures.is_empty():
		print("ASHEN_CAMPAIGN_INTERIOR_LAYOUT_CONTRACT_OK levels=29 buildings=%d boss_exclusions=%d checks=%d" % [_buildings, _bosses, _checks])
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)
