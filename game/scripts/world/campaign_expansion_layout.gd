class_name CampaignExpansionLayout
extends RefCounted
## A delayed-return exploration district, in the same coordinates as the story.
## Pure geometry/data only. Production actors, rewards and doors have other owners.

const Dressing = preload("res://scripts/data/campaign_scene_dressing.gd")
const CELL := 6.0
const HEIGHT := 2.0
const CHAPTER_NAMES := ["守炉旧院", "血铁军道", "借忆园林", "坠城外廓", "天炉余脉"]
const NAMES := {
	"level_01_01": "守炉人的归途", "level_01_02": "送魂墓廊", "level_01_03": "照魂上阁",
	"level_01_04": "废炉运药院", "level_01_05": "旧誓观炉台",
	"level_02_01": "断辎重关", "level_02_02": "双军望垒", "level_02_03": "缚魂运铁道",
	"level_02_04": "无援的烽廊", "level_02_05": "两军粮道", "level_02_06": "止战观礼台",
	"level_03_01": "三见旧树", "level_03_02": "借忆根庭", "level_03_03": "空轿回廊",
	"level_03_04": "无月听水园", "level_03_05": "问影高庭", "level_03_06": "残月观花阁",
	"level_04_01": "落星扶梯", "level_04_02": "五百年药圃", "level_04_03": "未删的外藏",
	"level_04_04": "折柱观心台", "level_04_05": "留灯望归台", "level_04_06": "末日观星台",
	"level_05_01": "无名归岸", "level_05_02": "倒炉检修脉", "level_05_03": "四烬见证廊",
	"level_05_04": "九印守望道", "level_05_05": "最后的炉沿", "level_05_06": "无目听风廊",
}
const LORE := [
	"旧院的守炉记录写着：无人归来的五百年，烬龛仍为尚未苏醒的继承者留着一缕火。",
	"运铁簿上的两套军旗，领用的却是同一道军令。士兵不是战争的原因，他们也被困在命令之中。",
	"石上刻着陌生人的名字。这里保存的是他人的记忆；没有任何一段能替你证明未曾有过的童年。",
	"外藏散页的页码被反复刮去，唯有坠城的时刻仍清晰可辨。完整的实录还在藏经阁中，等待有人读完。",
	"九道封印围住三位生者的印记。这里没有替你写好的答案，只有等待你承担的选择。",
]
const GUARDS := [
	["lost_soul_soldier", "temple_guardian_warrior"],
	["battle_worn_soldier", "camp_guard_wraith"],
	["memory_thief", "maze_guardian"],
	["stairway_guard_wraith", "library_guardian_spirit"],
	["forked_path_shade", "shadow_of_possibility"],
]


static func extend(state: Dictionary, level: Dictionary) -> void:
	if state.has("expansion"):
		return
	var id := String(level["id"])
	var chapter := clampi(int(id.substr(6, 2)) - 1, 0, 4)
	var serial := int(id.right(2))
	var boss := state.has("boss_arena_center")
	var original: Dictionary = state["cell_set"].duplicate()
	var entry_plan := _choose_entry(state, original, -1 if serial % 2 == 0 else 1, boss)
	assert(not entry_plan.is_empty(), id + ": no isolated district connection")
	if entry_plan.is_empty():
		return
	var side: int = entry_plan["side"]
	var entry: Vector3i = entry_plan["entry"]
	var bounds := _bounds(original)
	var outer_x: int = (int(bounds["max_x"]) + 5) if side > 0 else (int(bounds["min_x"]) - 5)
	var rise: int = 3 if boss else [4, 6, 4, 8, 6][chapter] + serial % 2
	var high_y := entry.y + rise
	var return_x: int = outer_x + side * 8
	var lift_x: int = outer_x + side * 4
	var walk: Array[Vector3i] = []
	_line(state, entry, Vector3i(outer_x, entry.y, entry.z), walk)
	var lower_court := Vector3i(outer_x, entry.y, entry.z)
	_court(state, lower_court, 1 if boss else 2)
	var climb_start := Vector3i(outer_x, entry.y, entry.z + (-3 if boss else 3))
	_line(state, lower_court, climb_start, walk)
	var climb_direction := -1 if boss else 1
	var at := climb_start
	for step in rise:
		var next := at + Vector3i(0, 1, climb_direction * 2)
		_ramp(state, at, next, walk)
		at = next
	var upper_court := at + Vector3i(0, 0, climb_direction * 2)
	_line(state, at, upper_court, walk)
	_court(state, upper_court, 1 if boss else 2)
	# The treasure is a genuine spur: the onward return loop does not cross it.
	var spur: Array[Vector3i] = []
	var reward_cell := upper_court + Vector3i(0, 0, climb_direction * (6 + serial % 3))
	_line(state, upper_court, reward_cell, spur)
	_court(state, reward_cell, 1)
	var descent_start := Vector3i(return_x, high_y, upper_court.z)
	_line(state, upper_court, descent_start, walk)
	# The side stair descends along the outermost rib, away from all old geometry.
	at = descent_start
	var descent_direction := 1 if boss else -1
	for step in high_y:
		var next := at + Vector3i(0, -1, descent_direction * 2)
		_ramp(state, at, next, walk)
		at = next
	# Continue beyond the last descent landing. Reversing a boss stair along its
	# own axis would fill the ramp gap with a floor and create a 2m ceiling.
	var return_z: int = at.z + 3 if boss else mini(int(bounds["min_z"]) - 4, at.z - 3)
	_line(state, at, Vector3i(return_x, 0, return_z), walk)
	var gate_cell := Vector3i(side * 4, 0, return_z)
	_line(state, walk.back(), gate_cell, walk)
	var shrine_approach := Vector3i(0, 0, return_z)
	_line(state, gate_cell, shrine_approach, walk)
	_line(state, shrine_approach, Vector3i(0, 0, -2), walk)
	# A second return option is a real vertical shaft. There is no upper floor in
	# the shaft itself; its neighboring landing opens only towards the platform.
	var upper_shaft := Vector3i(lift_x, high_y, return_z - 1)
	var lift_walk: Array[Vector3i] = []
	var extra_edges: Dictionary = {}
	if not boss:
		_line(state, upper_court, Vector3i(lift_x, high_y, upper_court.z), lift_walk)
		_line(state, lift_walk.back(), upper_shaft + Vector3i(0, 0, 1), lift_walk)
		extra_edges[_edge(upper_shaft + Vector3i(0, 0, 1), Vector3i(0, 0, -1))] = true
		extra_edges[_edge(Vector3i(lift_x, 0, return_z), Vector3i(0, 0, -1))] = true
	var new_cells: Array[Vector3i] = []
	for cell: Vector3i in state["cell_set"]:
		if not original.has(cell):
			new_cells.append(cell)
	var gate_position := _floor(gate_cell)
	var gate_yaw := PI * .5
	var gate_walls: Array[Dictionary] = []
	for cross_side in [-1, 1]:
		gate_walls.append({"position": gate_position + Vector3(0, 3, cross_side * 2.475), "size": Vector3(1.0, 6, 1.15), "yaw": 0.0})
		gate_walls.append({"position": gate_position + Vector3(0, 3, cross_side * 2.9), "size": Vector3(9, 6, .3), "yaw": 0.0})
	var encounters: Array[Dictionary] = []
	if not boss and id != "level_05_01":
		var guard_position := _floor(lower_court) + Vector3(0, 0, 4)
		encounters.append(_encounter(id, "threshold_patrol", GUARDS[chapter][0], guard_position,
			[_floor(lower_court) + Vector3(0, 0, 6), _floor(lower_court) + Vector3(0, 0, -6)], "patrol", -Vector3(side, 0, 0)))
		encounters.append(_encounter(id, "record_guard", GUARDS[chapter][1], _floor(reward_cell) + Vector3(0, 0, -climb_direction * 2),
			[], "guard", Vector3(0, 0, climb_direction)))
		if serial % 2 == 0:
			encounters.append(_encounter(id, "overlook_watch", GUARDS[chapter][0], _floor(upper_court) + Vector3(side * 5, 0, 0),
			[], "guard", Vector3(0, 0, climb_direction)))
	var architecture := _architecture(lower_court, upper_court, reward_cell, side, chapter, walk, original, boss)
	var return_gate: Dictionary = {}
	var lift: Dictionary = {}
	if not boss:
		return_gate = {"id": id + "/district/return_gate", "position": gate_position, "yaw": gate_yaw,
			"far_side": gate_position + Vector3(side * 1.4, .7, 0), "clear_width": 3.8, "walls": gate_walls}
		lift = {"id": id + "/district/lift", "upper_dock": _floor(upper_shaft),
			"lower_dock": _floor(Vector3i(lift_x, 0, return_z - 1)),
			"upper_landing": _floor(upper_shaft + Vector3i(0, 0, 1)),
			"lower_landing": _floor(Vector3i(lift_x, 0, return_z)),
			"upper_exit": _floor(upper_shaft + Vector3i(0, 0, 2)),
			"lower_exit": _floor(Vector3i(lift_x - side, 0, return_z)), "shaft_clearance": 6.0}
	state["expansion"] = {
		"schema_version": 1, "district_id": id + "/district", "display_name": String(NAMES.get(id, CHAPTER_NAMES[chapter])),
		"story_role": CHAPTER_NAMES[chapter], "entry": _floor(entry), "entry_route_index": entry_plan["route_index"],
		"entry_route_fraction": entry_plan["route_fraction"], "overlook": _floor(upper_court), "reward": _floor(reward_cell),
		"traversal_route": _positions(walk), "reward_spur": _positions(spur), "lift_route": _positions(lift_walk),
		"new_cells": new_cells, "extra_open_edges": extra_edges,
		"return_gate": return_gate, "lift": lift,
		"encounters": encounters,
		"rewards": [{"id": id + "/district/record", "embers": 80 + chapter * 70 + serial * 15,
			"position": _floor(reward_cell), "lore_text": LORE[chapter]}],
		"vista": {"position": _floor(upper_court) + Vector3(0, 1.8, 0),
			"look_at": state.get("boss_arena_center", Vector3(0, 2, -6))},
		"architecture": architecture, "boss_approach": boss,
	}


static func _choose_entry(state: Dictionary, cells: Dictionary, preferred_side: int, boss: bool) -> Dictionary:
	var route: Array = state["route"]
	if boss:
		return {"entry": Vector3i(preferred_side * 2, 0, 0), "side": preferred_side, "route_index": 0, "route_fraction": 0.0}
	var candidates: Array[int] = []
	for index in range(1, route.size() - 2):
		candidates.append(index)
	candidates.sort_custom(func(a: int, b: int) -> bool:
		return absf(float(a) / maxf(route.size() - 1, 1) - .57) < absf(float(b) / maxf(route.size() - 1, 1) - .57))
	var bounds := _bounds(cells)
	for index: int in candidates:
		var origin: Vector3i = route[index]
		# A perpendicular branch from a stair landing is legitimate. The connector
		# scan rejects the neighboring upper/lower cells of an along-stair branch.
		for side: int in [preferred_side, -preferred_side]:
			var border := origin
			while cells.has(border + Vector3i(side, 0, 0)):
				border.x += side
			var outer_x: int = int(bounds["max_x"]) + 5 if side > 0 else int(bounds["min_x"]) - 5
			if _connector_clear(state, cells, border, outer_x, side):
				return {"entry": border, "side": side, "route_index": index,
					"route_fraction": float(index) / maxf(route.size() - 1, 1)}
	return {}


static func _connector_clear(state: Dictionary, cells: Dictionary, border: Vector3i, outer_x: int, side: int) -> bool:
	# After leaving the selected edge, do not accidentally touch another floor,
	# create a second story connection, or put a 2m ceiling over an old route.
	for x in range(border.x + side, outer_x + side, side):
		var point := Vector3i(x, border.y, border.z)
		for cell: Vector3i in cells:
			if cell.x != x or absi(cell.z - point.z) > 1:
				continue
			if absi(cell.y - point.y) < 3:
				return false
		var position := _floor(point)
		for prop: Dictionary in state.get("story_props", []):
			if not bool(prop.get("collision", true)):
				continue
			var prop_position: Vector3 = prop["position"]
			var footprint: Vector2 = Dressing.footprint(prop) * .5 + Vector2(3.2, 3.2)
			if absf(position.x - prop_position.x) < footprint.x and absf(position.z - prop_position.z) < footprint.y \
					and position.y >= prop_position.y - 3.0 and position.y < prop_position.y + 18.0:
				return false
	return true


static func _bounds(cells: Dictionary) -> Dictionary:
	var result := {"min_x": 0, "max_x": 0, "min_z": 0}
	for cell: Vector3i in cells:
		result["min_x"] = mini(result["min_x"], cell.x)
		result["max_x"] = maxi(result["max_x"], cell.x)
		result["min_z"] = mini(result["min_z"], cell.z)
	return result


static func _line(state: Dictionary, from: Vector3i, to: Vector3i, path: Array[Vector3i]) -> void:
	assert(from.y == to.y and (from.x == to.x or from.z == to.z), "District line must be orthogonal")
	var delta := to - from
	var steps := maxi(absi(delta.x), absi(delta.z))
	var direction := Vector3i(signi(delta.x), 0, signi(delta.z))
	for step in steps + 1:
		var cell := from + direction * step
		state["cell_set"][cell] = true
		if path.is_empty() or path.back() != cell:
			path.append(cell)


static func _ramp(state: Dictionary, from: Vector3i, to: Vector3i, path: Array[Vector3i]) -> void:
	assert(absi(from.y - to.y) == 1 and absi(from.x - to.x) + absi(from.z - to.z) == 2, "District ramp must match production bridge geometry")
	state["cell_set"][from] = true
	state["cell_set"][to] = true
	var lower := from if from.y < to.y else to
	var upper := to if from.y < to.y else from
	state["ramps"].append({"lower": lower, "upper": upper})
	var direction := Vector3i(signi(to.x - from.x), 0, signi(to.z - from.z))
	state["open_edges"][_edge(from, direction)] = true
	state["open_edges"][_edge(to, -direction)] = true
	if path.is_empty() or path.back() != from:
		path.append(from)
	path.append(to)


static func _court(state: Dictionary, center: Vector3i, radius: int) -> void:
	for x in range(center.x - radius, center.x + radius + 1):
		for z in range(center.z - radius, center.z + radius + 1):
			state["cell_set"][Vector3i(x, center.y, z)] = true


static func _floor(cell: Vector3i) -> Vector3:
	return Vector3(cell.x * CELL, cell.y * HEIGHT, -cell.z * CELL)


static func _edge(cell: Vector3i, direction: Vector3i) -> String:
	return "%d,%d,%d:%d,%d" % [cell.x, cell.y, cell.z, direction.x, direction.z]


static func _positions(cells: Array[Vector3i]) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for cell: Vector3i in cells:
		result.append(_floor(cell))
	return result


static func _encounter(id: String, role_id: String, content: String, at: Vector3, patrol: Array, role: String, facing: Vector3) -> Dictionary:
	var points: Array[Vector3] = []
	for point: Vector3 in patrol:
		points.append(point)
	return {"placement_id": id + "/district/" + role_id, "content_id": content, "role": role,
		"position": at, "facing": facing, "patrol_points": points}


static func _architecture(lower: Vector3i, upper: Vector3i, reward: Vector3i, side: int, chapter: int,
		walk: Array[Vector3i], original: Dictionary, boss: bool) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for center: Vector3i in [lower, upper]:
		var position := _floor(center)
		result.append({"part": "Arcade", "position": position + Vector3(side * (8.0 if boss else 14.0), 0, 0), "yaw": PI * .5, "scale": Vector3.ONE})
		var tower_offset := 6.0 if boss else 10.5
		result.append({"part": "Watchtower", "position": position + Vector3(side * tower_offset, 0, tower_offset), "yaw": 0.0,
			"scale": Vector3(.45, .65 + chapter * .05, .45)})
	result.append({"part": "Roof", "position": _floor(reward), "yaw": 0.0, "scale": Vector3.ONE})
	for x_side in [-1, 1]:
		for z_side in [-1, 1]:
			result.append({"part": "Column", "position": _floor(reward) + Vector3(x_side * 2.5, 0, z_side * 2.5),
				"yaw": 0.0, "scale": Vector3(.25, 5.0 / 6.0, .25)})
	for index in range(4, walk.size() - 4, 7):
		var cell: Vector3i = walk[index]
		if original.has(cell):
			continue
		result.append({"part": "Lantern", "position": _floor(cell) + Vector3(side * 2.25, 0, 0), "yaw": 0.0, "scale": Vector3.ONE})
	return result
