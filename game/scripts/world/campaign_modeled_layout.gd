class_name CampaignModeledLayout
extends RefCounted
## Authored, deterministic routes for the campaign kit scenes. Cell coordinates
## remain 6m across and 2m per height unit; steep transitions reserve bridge gaps.

const StoryDressing = preload("res://scripts/data/campaign_scene_dressing.gd")
const Expansion = preload("res://scripts/world/campaign_expansion_layout.gd")

const BOSS_RADII := {
	"level_01_05": 20.0, "level_02_06": 24.0, "level_03_06": 22.0,
	"level_04_04": 20.0, "level_04_05": 20.0, "level_04_06": 24.0,
	"level_05_05": 26.0, "level_05_06": 18.0,
}


static func create(level: Dictionary, include_expansion := true) -> Dictionary:
	var id := String(level["id"])
	var state := {"cell_set": {}, "cells": [], "ramps": [], "open_edges": {},
		"route": [], "features": [], "id": id, "theme": String(level["theme_id"])}
	_rect(state, -2, 2, -2, 3, 0)
	if BOSS_RADII.has(id):
		_build_arena(state, id)
	else:
		_build_route(state, id)
		_finish_route(state)
	if state["route"].is_empty():
		push_error("Missing authored campaign route: " + id)
		return {}
	_add_landmarks(state)
	# The dedicated story structures replace the former generic side monuments.
	# Their old galleries remain available; only new building aprons add cells.
	state["features"] = state["features"].filter(func(feature: Dictionary) -> bool:
		return feature["part"] != "Landmark" and not (id == "level_05_04" and feature["part"] == "ArenaCover"))
	state["story_props"] = StoryDressing.plan_scene(level, state)
	state["story_anchors"] = StoryDressing.story_anchors(id)
	state["arena_interaction_anchors"] = StoryDressing.arena_interaction_anchors(id)
	_reserve_story_support(state)
	if include_expansion:
		Expansion.extend(state, level)
	_clear_stair_gaps(state)
	var cells: Array[Vector3i] = []
	for cell: Vector3i in state["cell_set"]:
		cells.append(cell)
	cells.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		if a.y != b.y:
			return a.y < b.y
		if a.z != b.z:
			return a.z < b.z
		return a.x < b.x)
	state["cells"] = cells
	state["spawn"] = Vector3(0, 1.1, 2)
	state["checkpoint"] = Vector3(0, 0, -6)
	state["exit"] = floor_position(state["route"].back())
	var modules: Dictionary = {}
	var route: Array = state["route"]
	var module_ids: Array = level["modules"]
	for index in module_ids.size():
		var module_id := String(module_ids[index])
		var route_index := clampi(roundi(float(index + 1) / float(module_ids.size() + 1) * (route.size() - 1)), 2, route.size() - 1)
		modules[module_id] = floor_position(route[route_index])
		if module_id == "gate_exit":
			modules[module_id] = state["exit"] + Vector3(0, 0, 4)
		elif module_id == "arena_seal":
			var center: Vector3 = state["boss_arena_center"]
			modules[module_id] = center + Vector3(0, 0, float(state["boss_arena_radius"]) + 6.0)
	for module_id: String in StoryDressing.module_anchors(id):
		assert(modules.has(module_id), "Story plan must not invent an unregistered module")
		modules[module_id] = StoryDressing.module_anchors(id)[module_id]
	state["modules"] = modules
	state["encounter_positions"] = _encounter_positions(state)
	# Existing shrine NPCs and chapter quest props occupy the protected entry court.
	# Side passages and moving shortcuts have explicit, stable route anchors.
	state["shortcut_door"] = floor_position(route[mini(5, route.size() - 1)])
	state["shortcut_far_side"] = floor_position(route[clampi(int(route.size() * 0.7), 0, route.size() - 1)]) + Vector3.UP * 0.7
	state["shortcut_elevator"] = floor_position(route[clampi(int(route.size() * 0.8), 0, route.size() - 1)])
	state["shortcut_dock"] = Vector3(-6, 0, -12)
	if state.has("expansion"):
		var district: Dictionary = state["expansion"]
		if not district["return_gate"].is_empty():
			state["shortcut_door"] = district["return_gate"]["position"]
			state["shortcut_far_side"] = district["return_gate"]["far_side"]
			state["shortcut_door_yaw"] = district["return_gate"]["yaw"]
		if not district["lift"].is_empty():
			state["shortcut_elevator"] = district["lift"]["upper_dock"]
			state["shortcut_dock"] = district["lift"]["lower_dock"]
	return state


static func _reserve_story_support(s: Dictionary) -> void:
	# Exact story footprints get grounded foundations. This does not fill terrain
	# under decorative water/ash surfaces or change a ramp's deliberately empty gap.
	for prop: Dictionary in s["story_props"]:
		if not bool(prop.get("collision", true)):
			continue
		var position: Vector3 = prop["position"]
		var half: Vector2 = StoryDressing.footprint(prop) * .5 + Vector2(.35,.35)
		var y := roundi(position.y / 2.0)
		var min_x := floori((position.x - half.x + 3.0) / 6.0)
		var max_x := floori((position.x + half.x + 3.0) / 6.0)
		var min_z := floori((-position.z - half.y + 3.0) / 6.0)
		var max_z := floori((-position.z + half.y + 3.0) / 6.0)
		_rect(s, min_x, max_x, min_z, max_z, y)


static func _finish_route(s: Dictionary) -> void:
	if s["route"].is_empty():
		return
	var last: Vector3i = s["route"].back()
	# Finish after the final incline/turn with a genuine court. Both gate pillars
	# and the interactive gate then stand on a broad, level terminal landing.
	_route(s, [[last.x, last.y, last.z], [last.x, last.y, last.z + 3]])
	_rect(s, last.x - 2, last.x + 2, last.z + 1, last.z + 4, last.y)


static func _build_route(s: Dictionary, id: String) -> void:
	match id:
		"level_01_02":
			_route(s, [[0,0,3],[0,0,24]])
			for z in [7, 13, 19]:
				_rect(s, -3, 3, z - 1, z + 1, 0)
			_rect(s, -3, 3, 22, 26, 0)
		"level_01_03":
			_route(s, [[0,0,3],[-3,0,8],[-3,0,12],[3,0,12],[3,0,20]])
			_rect(s, -6, 0, 5, 11, 0)
			_rect(s, 0, 6, 14, 21, 0)
			_route(s, [[-3,0,8],[3,0,8],[3,0,15]], false)
		"level_01_04":
			_route(s, [[0,0,3],[0,0,23]])
			_route(s, [[0,0,8],[-6,0,8],[-6,0,15],[0,0,15]], false)
			_route(s, [[0,0,11],[6,0,11],[6,0,19],[0,0,19]], false)
			_rect(s, -8, -4, 9, 13, 0)
			_rect(s, 4, 8, 13, 17, 0)
		"level_02_01":
			_route(s, [[0,0,3],[-4,0,8],[-4,1,10],[0,1,14],[4,1,14],[4,2,16],[4,2,20],[0,2,20],[0,3,22],[0,3,26]])
			_route(s, [[-4,1,12],[-7,1,12],[-7,1,16],[-2,1,16],[0,1,14]], false)
		"level_02_02":
			_route(s, [[0,0,3],[0,0,4],[0,1,6],[0,2,8],[0,3,10],[-6,3,10],[-6,4,12],[-6,5,14],[6,5,14],[6,6,16],[6,6,23],[0,6,23]])
			_rect(s, -7, 7, 14, 14, 5)
			_rect(s, 3, 8, 18, 23, 6)
		"level_02_03":
			_route(s, [[0,0,3],[0,0,21]])
			for z in [7, 15]:
				_route(s, [[0,0,z],[-6,0,z],[-6,0,z+4],[6,0,z+4],[6,0,z],[0,0,z]], false)
				_rect(s, -7, -4, z, z + 3, 0)
				_rect(s, 4, 7, z, z + 3, 0)
		"level_02_04":
			_route(s, [[0,0,3],[-4,0,4],[-4,1,6],[-4,2,8],[-4,3,10],[4,3,10],[4,4,8],[4,5,6],[4,6,4],[-4,6,4],[-4,7,6],[-4,8,8],[-4,9,10],[-4,10,12],[-4,11,14],[-4,12,16],[0,12,16]])
			_rect(s, -4, 4, 10, 11, 3)
			_rect(s, -4, 4, 3, 4, 6)
			_rect(s, -6, 2, 16, 19, 12)
		"level_02_05":
			_route(s, [[0,0,3],[0,0,10],[-4,0,10],[-4,0,16],[0,0,16],[0,0,23]])
			_rect(s, -5, 5, 5, 11, 0)
			_rect(s, -6, 3, 16, 23, 0)
			_route(s, [[4,0,10],[4,0,18],[0,0,18]], false)
		"level_03_01":
			_route(s, [[0,0,3],[-4,0,7],[-4,0,16],[3,0,16],[3,0,23]])
			_route(s, [[-4,0,8],[4,0,8],[4,0,16]], false)
			_route(s, [[-4,0,12],[-8,0,12],[-8,0,20],[-2,0,20],[-2,0,16]], false)
		"level_03_02":
			_route(s, [[0,0,3],[0,0,8],[-3,0,8],[-3,0,15],[3,0,15],[3,0,25]])
			_rect(s, -6, -1, 10, 13, 0)
			_rect(s, 1, 6, 19, 22, 0)
		"level_03_03":
			_route(s, [[0,0,3],[0,0,8],[4,0,8],[4,0,14],[-3,0,14],[-3,0,24]])
			for z in [6, 18, 22]:
				_rect(s, -6 if z > 10 else -3, 0 if z > 10 else 3, z, z + 1, 0)
			_route(s, [[0,0,6],[-5,0,6],[-5,0,14],[-3,0,14]], false)
		"level_03_04":
			_route(s, [[0,0,3],[-5,0,7],[-5,0,18],[0,0,18],[0,0,23]])
			_route(s, [[0,0,5],[5,0,5],[5,0,18],[0,0,18]], false)
			_route(s, [[-5,0,12],[5,0,12]], false)
			_rect(s, -2, 2, 10, 14, 0)
		"level_03_05":
			_route(s, [[0,0,3],[-6,0,5],[-6,0,10],[6,0,10],[6,0,18],[-3,0,18],[-3,0,25],[0,0,25]])
			_route(s, [[0,0,10],[0,0,5],[6,0,5]], false)
			_route(s, [[-3,0,18],[-7,0,18],[-7,0,24]], false)
			_route(s, [[6,0,18],[8,0,18],[8,0,25],[0,0,25]], false)
		"level_04_01":
			_route(s, [[0,0,3],[0,0,4],[0,1,6],[0,2,8],[3,2,8],[3,3,10],[3,4,12],[0,4,12],[0,5,14],[0,6,16],[-3,6,16],[-3,7,18],[-3,8,20],[0,8,20],[0,9,22]])
		"level_04_02":
			_route(s, [[0,0,3],[0,0,7],[-5,0,7],[-5,1,9],[-5,1,13],[0,1,13],[0,2,15],[5,2,15],[5,2,21],[0,2,21]])
			_rect(s, -7, -3, 10, 14, 1)
			_rect(s, 3, 7, 17, 22, 2)
			_rect(s, -2, 2, 5, 7, 0)
		"level_04_03":
			_route(s, [[0,0,3],[0,0,9],[4,0,9],[6,1,9],[6,2,11],[4,3,11],[0,3,11],[0,3,16],[-4,3,16],[-6,4,16],[-6,5,18],[-4,6,18],[0,6,18],[0,6,24]])
			_rect(s, -4, 4, 4, 9, 0)
			_rect(s, -4, 4, 11, 16, 3)
			_rect(s, -4, 4, 18, 24, 6)
		"level_05_01":
			_route(s, [[0,0,3],[-3,0,10],[1,0,17],[4,0,25]])
			_rect(s, -5, 3, 4, 12, 0)
			_rect(s, -3, 5, 13, 20, 0)
			_rect(s, 0, 7, 21, 27, 0)
		"level_05_02":
			_route(s, [[0,0,3],[0,0,8],[-4,0,8],[-4,1,10],[-4,2,12],[4,2,12],[4,3,14],[4,4,16],[0,4,16],[0,4,23]])
			_rect(s, -6, -2, 5, 8, 0)
			_rect(s, -4, 4, 12, 12, 2)
			_rect(s, -3, 4, 17, 23, 4)
		"level_05_03":
			_route(s, [[0,0,3],[0,0,23]])
			_route(s, [[0,0,7],[-7,0,7],[-7,0,17],[0,0,17]], false)
			_route(s, [[0,0,11],[7,0,11],[7,0,21],[0,0,21]], false)
			_rect(s, -9, -5, 10, 14, 0)
			_rect(s, 5, 9, 14, 18, 0)
		"level_05_04":
			_ring(s, Vector3i(0,0,12), 24.0, 42.0)
			_route(s, [[0,0,3],[0,0,7],[-5,0,7],[-5,0,17],[0,0,17],[0,0,22]])
			for index in 9:
				var angle := float(index) / 9.0 * TAU
				_feature(s, "ArenaCover", Vector3(cos(angle) * 36.0, 0, -72 + sin(angle) * 36.0), -angle, Vector3(2.0, 0.5, 2.5))


static func _build_arena(s: Dictionary, id: String) -> void:
	var radius := float(BOSS_RADII[id])
	var center := Vector3(0, 0, -48)
	var center_cell := Vector3i(0, 0, 8)
	_ring(s, center_cell, 0.0, radius + 8.0)
	_route(s, [[0,0,3],[0,0,8],[0,0,15]])
	# Different approaches/galleries supplement each arena silhouette without
	# placing columns or permanent blockers in the agreed clear fighting radius.
	match id:
		"level_01_05":
			_rect(s, -4, 4, 1, 3, 0)
		"level_02_06":
			_rect(s, -7, -5, 5, 11, 0)
			_rect(s, 5, 7, 5, 11, 0)
		"level_03_06":
			for side in [-1, 1]:
				_route(s, [[0,0,2],[side*6,0,2],[side*6,0,8]], false)
		"level_04_04":
			_rect(s, -6, -4, 9, 14, 0)
		"level_04_05":
			_rect(s, -5, 5, 4, 11, 0)
			_rect(s, 3, 6, 12, 15, 0)
		"level_04_06":
			_route(s, [[0,0,2],[-6,0,2],[-6,0,8]], false)
			_rect(s, -2, 2, 14, 17, 0)
		"level_05_05":
			for side in [-1, 1]:
				_rect(s, side * 7 - 1, side * 7 + 1, 7, 9, 0)
				_route(s, [[side*4,0,8],[side*7,0,8]], false)
		"level_05_06":
			_route(s, [[0,0,2],[5,0,2],[5,0,7]], false)
			_rect(s, -2, 2, 12, 16, 0)
	s["boss_arena_center"] = center
	s["boss_arena_radius"] = radius
	s["boss_spawn"] = center
	_feature(s, "Gate", center + Vector3(0, 0, radius + 6.0))
	_feature(s, "Gate", center - Vector3(0, 0, radius + 6.0))
	for index in 6:
		var angle := float(index) / 6.0 * TAU
		var position := center + Vector3(cos(angle) * (radius + 5.0), 0, sin(angle) * (radius + 5.0))
		for x_offset: float in [-1.5, 1.5]:
			for z_offset: float in [-1.5, 1.5]:
				_cell(s, Vector3i(roundi((position.x + x_offset) / 6.0), 0, roundi(-(position.z + z_offset) / 6.0)))
		_feature(s, "Column", position)


static func _route(s: Dictionary, points: Array, primary := true) -> void:
	for index in range(1, points.size()):
		var a := Vector3i(int(points[index - 1][0]), int(points[index - 1][1]), int(points[index - 1][2]))
		var b := Vector3i(int(points[index][0]), int(points[index][1]), int(points[index][2]))
		if a.y != b.y:
			_stair(s, a, b, primary)
		else:
			var corner := Vector3i(b.x, a.y, a.z)
			_line(s, a, corner, primary)
			_line(s, corner, b, primary)


static func _line(s: Dictionary, from: Vector3i, to: Vector3i, primary: bool) -> void:
	var delta := to - from
	var steps := maxi(absi(delta.x), absi(delta.z))
	var direction := Vector3i(signi(delta.x), 0, signi(delta.z))
	var cross := Vector3i(0, 0, 1) if delta.x != 0 else Vector3i(1, 0, 0)
	for step in steps + 1:
		var center := from + direction * step
		for lane in range(-1, 2):
			_cell(s, center + cross * lane)
		if primary and (s["route"].is_empty() or s["route"].back() != center):
			s["route"].append(center)


static func _stair(s: Dictionary, a: Vector3i, b: Vector3i, primary: bool) -> void:
	var delta := b - a
	assert(absi(delta.y) == 1 and absi(delta.x) + absi(delta.z) == 2 and (delta.x == 0 or delta.z == 0), "Authored stair needs a one-cell gap")
	var direction := Vector3i(signi(delta.x), 0, signi(delta.z))
	var cross := Vector3i(0, 0, 1) if delta.x != 0 else Vector3i(1, 0, 0)
	for lane in range(-1, 2):
		var from := a + cross * lane
		var to := b + cross * lane
		_cell(s, from)
		_cell(s, to)
		s["ramps"].append({"lower": from if from.y < to.y else to, "upper": to if from.y < to.y else from})
		s["open_edges"][edge_key(from, direction)] = true
		s["open_edges"][edge_key(to, -direction)] = true
	if primary:
		if s["route"].is_empty() or s["route"].back() != a:
			s["route"].append(a)
		s["route"].append(b)


static func _cell(s: Dictionary, cell: Vector3i) -> void:
	s["cell_set"][cell] = true


static func _clear_stair_gaps(s: Dictionary) -> void:
	# A landing or adjoining room must not fill the incline with an upper tile.
	# That would leave a vertical collision lip halfway up the visible bridge.
	for ramp: Dictionary in s["ramps"]:
		var lower: Vector3i = ramp["lower"]
		var upper: Vector3i = ramp["upper"]
		var midpoint := Vector3i((lower.x + upper.x) / 2, lower.y, (lower.z + upper.z) / 2)
		s["cell_set"].erase(midpoint)
		midpoint.y = upper.y
		s["cell_set"].erase(midpoint)
	var retained: Array[Dictionary] = []
	s["open_edges"].clear()
	for ramp: Dictionary in s["ramps"]:
		var lower: Vector3i = ramp["lower"]
		var upper: Vector3i = ramp["upper"]
		if not s["cell_set"].has(lower) or not s["cell_set"].has(upper):
			continue
		retained.append(ramp)
		var direction := Vector3i(signi(upper.x - lower.x), 0, signi(upper.z - lower.z))
		s["open_edges"][edge_key(lower, direction)] = true
		s["open_edges"][edge_key(upper, -direction)] = true
	s["ramps"] = retained
	if s.has("expansion"):
		for key: String in s["expansion"].get("extra_open_edges", {}):
			s["open_edges"][key] = true
		var current_new_cells: Array[Vector3i] = []
		for cell: Vector3i in s["expansion"]["new_cells"]:
			if s["cell_set"].has(cell):
				current_new_cells.append(cell)
		s["expansion"]["new_cells"] = current_new_cells


static func _add_landmarks(s: Dictionary) -> void:
	var route: Array = s["route"]
	if s.has("boss_arena_center"):
		var center: Vector3 = s["boss_arena_center"]
		var side_x := ceili((float(s["boss_arena_radius"]) + 17.0) / 6.0)
		_route(s, [[0,0,8],[side_x,0,8]], false)
		_rect(s, side_x - 1, side_x + 1, 7, 9, 0)
		_feature(s, "Landmark", center + Vector3(side_x * 6.0, 0, 0))
		return
	var flat: Array[Vector3i] = []
	for cell: Vector3i in route:
		if cell.z < 5:
			continue
		var incline_landing := false
		for ramp: Dictionary in s["ramps"]:
			if cell == ramp["lower"] or cell == ramp["upper"]:
				incline_landing = true
				break
		if incline_landing:
			continue
		if s["cell_set"].has(cell + Vector3i(0,0,1)) and s["cell_set"].has(cell - Vector3i(0,0,1)) \
				and s["cell_set"].has(cell + Vector3i(1,0,0)) and s["cell_set"].has(cell - Vector3i(1,0,0)):
			flat.append(cell)
	if flat.is_empty():
		flat.append(route.front())
	for index in 2:
		var cell: Vector3i = flat[clampi(roundi((0.3 + index * 0.4) * (flat.size() - 1)), 0, flat.size() - 1)]
		var side := -1 if (int(String(s["id"]).right(2)) + index) % 2 else 1
		var alcove := _free_alcove(s, cell, side)
		side = signi(alcove.x - cell.x)
		_line(s, cell, alcove, false)
		_rect(s, alcove.x - 1, alcove.x + 1, alcove.z - 1, alcove.z + 1, alcove.y)
		_feature(s, "Landmark", floor_position(alcove), PI * 0.5 * side)
		_feature(s, "Gate", floor_position(cell))
	# Terminate the route with a modeled gate as well as the functional module.
	_feature(s, "Gate", floor_position(route.back()) + Vector3(0, 0, 4))


static func _free_alcove(s: Dictionary, from: Vector3i, side: int) -> Vector3i:
	# Reserve the whole landmark footprint outside existing routes at every
	# height, not merely a nominal side offset which can hit another loop/hall.
	for direction in [side, -side]:
		for distance in range(3, 24):
			var candidate := from + Vector3i(direction * distance, 0, 0)
			var occupied := false
			for cell: Vector3i in s["cell_set"]:
				if absi(cell.x - candidate.x) <= 2 and absi(cell.z - candidate.z) <= 2:
					occupied = true
					break
				# The connecting gallery must not run directly under/over an
				# adjacent-height route with less than the actor's headroom.
				if absi(cell.y - from.y) == 1 and absi(cell.z - from.z) <= 1 \
						and cell.x >= mini(from.x, candidate.x) and cell.x <= maxi(from.x, candidate.x):
					occupied = true
					break
			if not occupied:
				return candidate
	assert(false, "No reserved space for authored campaign landmark")
	return from


static func _rect(s: Dictionary, min_x: int, max_x: int, min_z: int, max_z: int, y: int) -> void:
	for z in range(min_z, max_z + 1):
		for x in range(min_x, max_x + 1):
			_cell(s, Vector3i(x, y, z))


static func _ring(s: Dictionary, center: Vector3i, inner: float, outer: float) -> void:
	var reach := ceili(outer / 6.0)
	for z in range(-reach, reach + 1):
		for x in range(-reach, reach + 1):
			var distance := Vector2(x, z).length() * 6.0
			if distance <= outer and distance >= inner:
				_cell(s, center + Vector3i(x, 0, z))


static func _feature(s: Dictionary, part: String, position: Vector3, yaw := 0.0, scale := Vector3.ONE) -> void:
	for existing: Dictionary in s["features"]:
		if existing["part"] == part and (existing["position"] as Vector3).is_equal_approx(position):
			return
	s["features"].append({"part": part, "position": position, "yaw": yaw, "scale": scale})


static func _encounter_positions(s: Dictionary) -> Array[Vector3]:
	var result: Array[Vector3] = []
	var route: Array = s["route"]
	var available: Array[Vector3] = []
	for index in range(maxi(2, roundi(route.size() * 0.15)), maxi(3, route.size() - 2)):
		var point := floor_position(route[index])
		var occupied := false
		for anchor: Vector3 in s["modules"].values():
			if absf(point.y - anchor.y) < 3.0 and Vector2(point.x - anchor.x, point.z - anchor.z).length() < 6.0:
				occupied = true
		for feature: Dictionary in s["features"]:
			var anchor: Vector3 = feature["position"]
			if feature["part"] == "Landmark" and absf(point.y - anchor.y) < 12.0 \
					and Vector2(point.x - anchor.x, point.z - anchor.z).length() < 9.0:
				occupied = true
			if feature["part"] == "Gate" and absf(point.y - anchor.y) < 8.0:
				for side in [-1, 1]:
					var pillar := anchor + Basis(Vector3.UP, float(feature["yaw"])) * Vector3(side * 4.8, 0, 0)
					if Vector2(point.x - pillar.x, point.z - pillar.z).length() < 2.6:
						occupied = true
		if not occupied:
			available.append(point)
	assert(not available.is_empty(), "No clear campaign encounter positions")
	for index in 12:
		var at := clampi(roundi(float(index) / 11.0 * (available.size() - 1)), 0, available.size() - 1)
		result.append(available[at])
	return result


static func floor_position(cell: Vector3i) -> Vector3:
	return Vector3(float(cell.x) * 6.0, float(cell.y) * 2.0, -float(cell.z) * 6.0)


static func edge_key(cell: Vector3i, direction: Vector3i) -> String:
	return "%d,%d,%d:%d,%d" % [cell.x, cell.y, cell.z, direction.x, direction.z]
