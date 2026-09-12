class_name CampaignInteriorSoulsLayout
extends RefCounted
## Spatial loops around the occupied house. Runtime owns persistence, the local
## moving platform, damage, encounters and the earned refuge. No story mutation.


static func extend(state: Dictionary, level: Dictionary) -> void:
	var expansion: Dictionary = state["expansion"]
	var interior: Dictionary = expansion["interior"]
	if interior.has("souls"):
		return
	var id := String(level["id"])
	var origin: Vector3 = interior["origin"]
	var side := signi(roundi((expansion["lift"]["upper_dock"] as Vector3).x - origin.x))
	var loop_id := id + "/door_b2_latch"
	var lower_dock := origin + Vector3(12, 0, 24)
	var upper_dock := origin + Vector3(12, 6, 24)
	var lower_landing := origin + Vector3(12, 0, 18)
	var upper_landing := origin + Vector3(12, 6, 18)
	var return_landing := origin + Vector3(12, 6, 30)
	for point: Vector3 in [lower_landing, upper_landing, return_landing]:
		_put(state, interior, _cell(point))
	_open(state, _cell(lower_landing), Vector3i(0, 0, -1))
	_open(state, _cell(upper_landing), Vector3i(0, 0, -1))
	_open(state, _cell(return_landing), Vector3i(0, 0, 1))
	# The shaft is an addition beyond the facade, never a hole cut in old terrain.
	for y in range(_cell(lower_dock).y, _cell(upper_dock).y + 1):
		assert(not state["cell_set"].has(Vector3i(_cell(lower_dock).x, y, _cell(lower_dock).z)), id + ": local lift shaft intersects old floor")
	var latch_position := origin + Vector3(12, 6, 21)
	for direction in [-1, 1]:
		_box(interior, latch_position + Vector3(direction * 2.45, 3, 0), Vector3(1.1, 6, .6))
	# This railing seam is also the optical opening through the upper west wall.
	_open(state, _cell(origin + Vector3(-12, 12, 0)), Vector3i.RIGHT)
	_open(state, _cell(origin + Vector3(-12, 12, 6)), Vector3i.RIGHT)
	# The front gallery intentionally opens over the atrium rather than hiding a
	# teleporter behind an interaction. The middle-floor opening stays below it.
	_open(state, _cell(origin + Vector3(0, 12, 12)), Vector3i(0, 0, 1))
	var roof := _roof_loop(state, interior, origin, -side, return_landing)
	var gate: Dictionary = interior["stages"][2]["door"]
	var gate_position: Vector3 = gate["position"]
	var goal_position := gate_position + Vector3(0, 5.4, .62)
	var vistas: Array[Dictionary] = []
	for view: Dictionary in [
		{"id": "ground", "position": Vector3(8, 1.6, 6), "label": "一层挑空大厅"},
		{"id": "middle", "position": Vector3(12, 7.6, 6), "label": "二层东回廊瞭望台"},
		{"id": "ramp", "position": Vector3(8, 1.6, 24.8), "label": "外部坡道尽头的入院平台"}]:
		vistas.append({"id": view["id"], "position": origin + (view["position"] as Vector3),
			"look_at": goal_position, "target_gate_id": interior["stages"][2]["id"], "label": view["label"]})
	var recovery: Array[Vector3] = [origin + Vector3(12, 0, 12), lower_landing, lower_dock,
		upper_dock, upper_landing, origin + Vector3(6, 6, 18)]
	var souls := {
		"vista": vistas[0], "vistas": vistas,
		"reward_vista": {"id": "reward", "position": origin + Vector3(-9.75, 13.6, 2.4),
			"look_at": (interior["reward_position"] as Vector3) + Vector3(0, 1.7, 0),
			"target_reward_id": expansion["rewards"][0]["id"], "label": "最终门框东侧·隔庭目认余烬",
			"requires_gate_open": false},
		"goal_landmark": {"position": goal_position, "gate_position": gate_position, "gate_id": interior["stages"][2]["id"]},
		"b2_latch": {"id": loop_id, "flag": loop_id, "position": latch_position, "yaw": 0.0,
			"size": Vector3(3.8, 6, .5), "far_side": origin + Vector3(12, 6, 19.5)},
		"refuge": {"id": id + "/ash_refuge", "position": origin + Vector3(12, 0, 12),
			"spawn_position": origin + Vector3(12, 0, 16), "unlock_flag": loop_id},
		"b2_lift": {"id": id + "/b2_return_lift", "lower_dock": lower_dock, "upper_dock": upper_dock,
			"lower_landing": lower_landing, "upper_landing": upper_landing, "upper_return_landing": return_landing,
			"required_flag": loop_id, "travel_seconds": 3.0},
		"b2return_route": recovery,
		"drop": {"takeoff": origin + Vector3(0, 12, 10), "landing_center": origin + Vector3(0, 0, 6),
			"size": Vector3(6, 1, 6), "fall_height": 12.0, "damage_scale": .3, "minimum_damage": 3},
		"roof_route": roof["route"], "roof_ladder": roof["ladder"],
	}
	if id == "level_04_03":
		var annex := _archive_annex(state, interior, origin, side)
		souls["annex"] = annex
		interior["archive_annex"] = {"position": annex["origin"], "entry": annex["entry"]}
	interior["souls"] = souls


static func _roof_loop(state: Dictionary, interior: Dictionary, origin: Vector3, side: int, return_landing: Vector3) -> Dictionary:
	var route: Array[Vector3] = []
	var start := origin + Vector3(0, 12, -24)
	_line(state, interior, interior["reward_position"], start, route)
	var ascent: Array[Vector3] = [start, origin + Vector3(side * 12, 14, -24), origin + Vector3(side * 24, 16, -24),
		origin + Vector3(side * 24, 18, -36), origin + Vector3(side * 12, 20, -36), origin + Vector3(0, 22, -36)]
	for index in range(1, ascent.size()):
		_ramp(state, interior, ascent[index - 1], ascent[index], route)
	var ridge_end := origin + Vector3(0, 22, 24)
	_line(state, interior, ascent.back(), ridge_end, route)
	# The roof mesh peaks at21m. This supported22m stone ridge has0.4m
	# clearance under its0.6m deck, while the occupied top floor keeps its roof.
	for z in [-18, 0, 18]:
		interior["architecture"].append({"part": "Column", "position": origin + Vector3(0, 18.3, z),
			"yaw": 0.0, "scale": Vector3(.8, 3.7 / 6.0, .8), "collision": true})
	var descent: Array[Vector3] = [ridge_end, origin + Vector3(side * 12, 20, 24), origin + Vector3(side * 24, 18, 24),
		origin + Vector3(side * 24, 16, 36), origin + Vector3(side * 12, 14, 36), origin + Vector3(0, 12, 36),
		origin + Vector3(0, 10, 48), origin + Vector3(side * 12, 8, 48), origin + Vector3(side * 24, 6, 48)]
	for index in range(1, descent.size()):
		_ramp(state, interior, descent[index - 1], descent[index], route)
	# Continue beyond the last descent, then go around it. Reversing across the
	# same incline would put a two-metre ceiling over the return passage.
	var outside := origin + Vector3(side * 36, 6, 48)
	var corner := origin + Vector3(side * 36, 6, 30)
	_line(state, interior, descent.back(), outside, route)
	_line(state, interior, outside, corner, route)
	_line(state, interior, corner, return_landing, route)
	var direction := (ascent[1] - ascent[0])
	direction.y = 0
	direction = direction.normalized()
	var bottom := ascent[0] + direction * 3
	var top := ascent[1] - direction * 3
	return {"route": route, "ladder": {"id": String(interior["id"]) + "/roof_ladder", "kind": "inclined_ladder",
		"bottom": bottom, "top": top, "route": [ascent[0], bottom, top, ascent[1]]}}


static func _archive_annex(state: Dictionary, interior: Dictionary, origin: Vector3, side: int) -> Dictionary:
	var center := origin + Vector3(side * 36, 6, -18)
	var entry := origin + Vector3(side * 24, 6, -18)
	var connector: Array[Vector3] = []
	_line(state, interior, origin + Vector3(side * 18, 6, -18), center, connector)
	for x in [-6, 0, 6]:
		for z in [-6, 0, 6]:
			_put(state, interior, _cell(center + Vector3(x, 0, z)))
			_box(interior, center + Vector3(x, 5.7, z), Vector3(6, .6, 6))
	for index in [-1, 0, 1]:
		_box(interior, center + Vector3(index * 6, 3, -9), Vector3(6, 6, .5))
		_box(interior, center + Vector3(index * 6, 3, 9), Vector3(6, 6, .5))
		_box(interior, center + Vector3(side * 9, 3, index * 6), Vector3(.5, 6, 6))
		if index != 0:
			_box(interior, center + Vector3(-side * 9, 3, index * 6), Vector3(.5, 6, 6))
	return {"origin": center, "entry": entry, "room_name": "借来的血铁军需室", "theme": "theme_blood_iron",
		"story_source": "docs/story/chapter-bridge-map.md", "prop_anchors": [center, center + Vector3(2.5, 0, -1.8)]}


static func _put(state: Dictionary, interior: Dictionary, cell: Vector3i) -> void:
	state["cell_set"][cell] = true
	state["interior_cells"][cell] = true
	if cell not in interior["building_cells"]:
		interior["building_cells"].append(cell)


static func _line(state: Dictionary, interior: Dictionary, from: Vector3, to: Vector3, route: Array[Vector3]) -> void:
	var first := _cell(from)
	var last := _cell(to)
	assert(first.y == last.y and (first.x == last.x or first.z == last.z))
	var steps := maxi(absi(last.x - first.x), absi(last.z - first.z))
	var direction := Vector3i(signi(last.x - first.x), 0, signi(last.z - first.z))
	for index in steps + 1:
		var cell := first + direction * index
		_put(state, interior, cell)
		var point := _floor(cell)
		if route.is_empty() or route.back() != point:
			route.append(point)


static func _ramp(state: Dictionary, interior: Dictionary, from: Vector3, to: Vector3, route: Array[Vector3]) -> void:
	var lower := _cell(from if from.y < to.y else to)
	var upper := _cell(to if from.y < to.y else from)
	assert(upper.y - lower.y == 1 and absi(upper.x - lower.x) + absi(upper.z - lower.z) == 2)
	_put(state, interior, lower)
	_put(state, interior, upper)
	state["ramps"].append({"lower": lower, "upper": upper})
	if route.is_empty() or route.back() != from:
		route.append(from)
	route.append(to)


static func _open(state: Dictionary, cell: Vector3i, direction: Vector3i) -> void:
	state["expansion"]["extra_open_edges"]["%d,%d,%d:%d,%d" % [cell.x, cell.y, cell.z, direction.x, direction.z]] = true


static func _box(interior: Dictionary, position: Vector3, size: Vector3) -> void:
	interior["solid_boxes"].append({"position": position, "size": size, "yaw": 0.0, "visual": false})
	var along_z := size.z > size.x
	interior["architecture"].append({"part": "Wall", "position": position - Vector3(0, size.y * .5, 0),
		"yaw": PI * .5 if along_z else 0.0,
		"scale": Vector3((size.z if along_z else size.x) / 6.0, size.y / 10.0, (size.x if along_z else size.z) / 1.5), "collision": false})


static func _cell(point: Vector3) -> Vector3i:
	return Vector3i(roundi(point.x / 6), roundi(point.y / 2), roundi(-point.z / 6))


static func _floor(cell: Vector3i) -> Vector3:
	return Vector3(cell.x * 6, cell.y * 2, -cell.z * 6)
