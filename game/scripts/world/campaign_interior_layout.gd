class_name CampaignInteriorLayout
extends RefCounted
## Three occupied storeys, a visible central atrium and two enclosed internal
## stairs. Only the final upper room reaches the lift bridge. No story mutation.

const STORY_SOURCE := "docs/story/chapter-bridge-map.md"
const STOREY := 6.0
const WALL_HEIGHT := 6.0
const Story = preload("res://scripts/data/campaign_interior_story.gd")
const Souls = preload("res://scripts/world/campaign_interior_souls_layout.gd")
const SceneStory = preload("res://scripts/data/campaign_interior_scene_story.gd")
const PRESSURE_ROSTERS := {
	1: ["lost_soul_soldier", "lost_soul_soldier", "temple_guardian_warrior"],
	2: ["battle_worn_soldier", "generals_personal_guard", "camp_guard_wraith"],
	3: ["memory_thief", "maze_guardian", "maze_guardian"],
	4: ["stairway_guard_wraith", "stairway_guard_wraith", "library_guardian_spirit"],
	5: ["ember_shore_drifter", "inverted_guardian", "inverted_guardian"],
}


static func extend(state: Dictionary, level: Dictionary) -> void:
	var expansion: Dictionary = state["expansion"]
	if bool(expansion.get("boss_approach", false)) or expansion.has("interior"):
		return
	var level_id := String(level["id"])
	var chapter := clampi(int(level_id.substr(6, 2)) - 1, 0, 4)
	var old_reward: Vector3 = expansion["reward"]
	var origin := old_reward + Vector3(0, 0, -18)
	var base := _cell(origin)
	var id := level_id + "/interior"
	var completion_flag := "interior_complete:" + id
	var config := Story.apply(_chapter(chapter), level_id)
	var option_rotation := int(level_id.right(2)) % 3
	var boxes: Array[Dictionary] = []
	var architecture: Array[Dictionary] = []
	var props: Array[Dictionary] = []
	var building_cells: Array[Vector3i] = []
	var region: Dictionary = state.get("interior_cells", {})
	# The complete volume identifies interior atrium/stair edges to the renderer;
	# only building_cells/cell_set identify actual supported floors.
	for y in range(base.y, base.y + 10):
		for x in range(-3, 4):
			for z in range(-3, 4):
				region[base + Vector3i(x, y - base.y, z)] = true
	state["interior_cells"] = region
	for floor_index in 3:
		for x in range(-3, 4):
			for z in range(-3, 4):
				if not _has_floor(floor_index, x, z):
					continue
				var cell := base + Vector3i(x, floor_index * 3, z)
				_put(state, cell, building_cells)
	var first_stair: Array[Vector3] = []
	var second_stair: Array[Vector3] = []
	for step in 3:
		_ramp(state, base + Vector3i(-3, step, -3 + step * 2),
			base + Vector3i(-3, step + 1, -1 + step * 2), building_cells, first_stair)
		_ramp(state, base + Vector3i(3, 3 + step, 3 - step * 2),
			base + Vector3i(3, 4 + step, 1 - step * 2), building_cells, second_stair)
	# Exterior walls define actual rooms on all three floors. The two openings
	# are the ground entrance and the top-floor exit; no side stair entrances.
	var side := signi(roundi((expansion["lift"]["upper_dock"] as Vector3).x - origin.x))
	for floor_index in 3:
		var y := float(floor_index) * STOREY
		if floor_index == 0:
			# Original entrance and the new local-lift lobby have separate openings.
			_wall_x(boxes, architecture, origin, y, 21, -21, -3, INF, 0, true)
			_wall_x(boxes, architecture, origin, y, 21, 3, 9, INF, 0, true)
			_wall_x(boxes, architecture, origin, y, 21, 15, 21, INF, 0, true)
		elif floor_index == 1:
			_wall_x(boxes, architecture, origin, y, 21, -21, 21, 12, 6, true)
		else:
			_wall_x(boxes, architecture, origin, y, 21, -21, 21, INF, 0, true)
		_wall_x(boxes, architecture, origin, y, -21, -21, 21, 0.0 if floor_index == 2 else INF, 6, true)
		for wall_side in [-1, 1]:
			var opening := -18.0 if wall_side == side and (floor_index == 2 or (floor_index == 1 and level_id == "level_04_03")) else INF
			_wall_z(boxes, architecture, origin, y, wall_side * 21.0, -21.0, 21.0, opening, 6.0, true)
	_foundation(boxes, architecture, origin, chapter)
	# West stair: enter at ground south, exit into first-floor north archive.
	_wall_z(boxes, architecture, origin, 0, -15, -21, 15)
	_wall_z(boxes, architecture, origin, 6, -15, -15, 21)
	# East stair: enter from first-floor north, exit into top-floor south room.
	_wall_z(boxes, architecture, origin, 6, 15, -15, 21)
	_wall_z(boxes, architecture, origin, 12, 15, -15, 15)
	# The top west corridor has a long inner wall. A player cannot hop around
	# the final gate over the atrium's edge; entrances are at its two ends.
	_wall_z(boxes, architecture, origin, 12, -9, -15, -3)
	_wall_z(boxes, architecture, origin, 12, -9, 9, 15)
	# A sight opening faces the actual upper gate across the open atrium. There
	# is no adjacent upper floor on the atrium side of this low window sill.
	for window_z in [0, 6]:
		_box_wall(boxes, architecture, origin + Vector3(-9, 12.2, window_z), Vector3(.5, .4, 6))
		_box_wall(boxes, architecture, origin + Vector3(-9, 17.9, window_z), Vector3(.5, .2, 6))
	var door_positions := [Vector3(-18, 0, 15), Vector3(18, 6, -15), Vector3(-15, 12, 0)]
	# This side of the stair-wall end has a direct ten-metre view of door A.
	# Its evidence table remains clear of the three existing controls at z18.
	var clue_positions := [Vector3(-8, 0, 15.7), Vector3(-8, 6, -16), Vector3(8, 12, 16)]
	var controls := [[Vector3(-10, 0, 18), Vector3(-6, 0, 18), Vector3(-2, 0, 18)],
		[Vector3(-2, 6, -18), Vector3(2, 6, -18), Vector3(6, 6, -18)],
		[Vector3(-8, 12, 18), Vector3(-4, 12, 18), Vector3(0, 12, 18)]]
	var east_wall: Vector3 = origin + clue_positions[0] + Vector3(5.25, 0, -1.5)
	_box_wall(boxes, architecture, east_wall + Vector3(0, 1.3, 0), Vector3(.5, 2.6, 3))
	var first_route: Array[Vector3] = []
	first_route.assign(first_stair)
	first_route.append(origin + Vector3(-12, 6, -18))
	first_route.append(origin + Vector3(0, 6, -18))
	var second_route: Array[Vector3] = []
	second_route.assign(second_stair)
	second_route.append(origin + Vector3(12, 12, 18))
	second_route.append(origin + Vector3(0, 12, 18))
	var final_route: Array[Vector3] = [origin + Vector3(-15, 12, 18), origin + Vector3(-15, 12, 2),
		origin + Vector3(-15, 12, -2), origin + Vector3(-15, 12, -18), origin + Vector3(0, 12, -18)]
	var routes := [first_route, second_route, final_route]
	var chamber_violation := level_id == "level_03_02"
	var empty_frame := origin + Vector3(8, 12, 16)
	if chamber_violation:
		clue_positions[2] = Vector3(8, 0, 2)
		controls[2] = [Vector3(4, 0, -2), Vector3(8, 0, -2), Vector3(12, 0, -2)]
		routes[1] = _memory_return_route(origin, first_stair, second_stair, empty_frame)
		routes[2] = _memory_final_route(origin, first_stair, second_stair, final_route)
	var stages: Array[Dictionary] = []
	for index in 3:
		var recipe: Dictionary = config["stages"][index]
		var at: Vector3 = origin + door_positions[index]
		_gate_wings(boxes, architecture, at, 12.0 if index == 2 else 6.0)
		var control_positions: Array[Vector3] = []
		for control: Vector3 in controls[index]:
			control_positions.append(origin + control)
		var prop_ids: Array[String] = []
		for part_index in recipe["parts"].size():
			var prop_id := id + "/room_%d/prop_%d" % [index, part_index]
			var placement := Vector3(-6 if part_index == 0 else 6, index * STOREY, -7 if index == 0 else -13)
			props.append({"id": prop_id, "part_id": recipe["parts"][part_index], "position": origin + placement,
				"rotation_y": 0.0, "scale": Vector3(.65, .65, .65), "collision": true, "story_source": STORY_SOURCE})
			prop_ids.append(String(recipe["parts"][part_index]))
		var options: Array[String] = []
		for option_index in 3:
			options.append(String(recipe["options"][(option_index + option_rotation) % 3]))
		stages.append({"id": id + "/stage_%d" % index, "index": index, "floor": 0 if chamber_violation and index == 2 else index,
			"clue_position": origin + clue_positions[index], "clue_text": recipe["clue"],
			"options": options, "correct_index": (int(recipe["correct"]) - option_rotation + 3) % 3, "controls_positions": control_positions,
			"door": {"position": at, "yaw": PI if index == 1 else 0.0, "size": Vector3(3.8, 6, .5)},
			"to_next_route": routes[index], "room_name": "归名月室·守门灯阁" if chamber_violation and index == 2 else recipe["room"], "prop_ids": prop_ids})
	# Atrium columns visibly carry the gallery floors; a tiled roof closes the
	# building above its third storey, rather than leaving three empty platforms.
	for floor_index in 3:
		for x_side in [-1, 1]:
			for z_side in [-1, 1]:
				architecture.append({"part": "Column", "position": origin + Vector3(x_side * 10.5, floor_index * 6, z_side * 10.5),
					"yaw": 0.0, "scale": Vector3(.65, 1, .65), "collision": true})
		for x_side in [-1, 1]:
			architecture.append({"part": "Lantern", "position": origin + Vector3(x_side * 11.5, floor_index * 6, 11.5),
				"yaw": 0.0, "scale": Vector3.ONE, "collision": false})
	architecture.append({"part": "Roof", "position": origin + Vector3(0, 13, 0), "yaw": 0.0,
		"scale": Vector3(7, 1, 7), "collision": false})
	boxes.append({"position": origin + Vector3(0, 18.15, 0), "size": Vector3(42, .3, 42), "yaw": 0.0, "visual": false})
	var top_y := old_reward.y + 12.0
	var reward_position := origin + Vector3(0, 12, -18)
	var lift: Dictionary = expansion["lift"]
	var lower_dock: Vector3 = lift["lower_dock"]
	var upper_dock := Vector3(lower_dock.x, top_y, lower_dock.z)
	var upper_landing := upper_dock + Vector3(0, 0, -6)
	var exit_route: Array[Vector3] = []
	var exit_start := base + Vector3i(side * 3, 6, 3)
	_line(state, _cell(reward_position), exit_start, building_cells, exit_route)
	_line(state, exit_start, Vector3i(_cell(upper_landing).x, base.y + 6, exit_start.z), building_cells, exit_route)
	_line(state, _cell(exit_route.back()), _cell(upper_landing), building_cells, exit_route)
	lift["upper_dock"] = upper_dock
	lift["upper_landing"] = upper_landing
	lift["upper_exit"] = upper_landing + Vector3(0, 0, -6)
	lift["required_flag"] = completion_flag
	expansion["return_gate"]["required_flag"] = completion_flag
	var extra_edges: Dictionary = expansion["extra_open_edges"]
	extra_edges[_edge(_cell(upper_landing), Vector3i(0, 0, -1))] = true
	extra_edges[_edge(_cell(lift["lower_landing"]), Vector3i(0, 0, -1))] = true
	expansion["lift_route"] = exit_route
	expansion["reward"] = reward_position
	for reward: Dictionary in expansion["rewards"]:
		reward["embers"] = 1
		# Raise the imported lantern's luminous chamber above the existing
		# gallery rail; its physical interaction and supporting tile stay put.
		reward["visual_scale"] = Vector3(1, 1.4, 1)
		reward["position"] = reward_position
		reward["required_flag"] = completion_flag
		reward["lore_text"] = config["completion_text"]
	expansion["interior"] = {"id": id, "display_name": String(expansion["display_name"]) + "·" + String(config["title"]),
		"story_source": STORY_SOURCE, "origin": origin, "floor_heights": [old_reward.y, old_reward.y + 6, top_y],
		"building_cells": building_cells, "entry": old_reward, "stages": stages, "completion_flag": completion_flag,
		"reward_position": reward_position, "exit_route": exit_route, "architecture": architecture, "solid_boxes": boxes,
		"props": props, "atrium": {"center": origin + Vector3(0, 9, 0), "size": Vector3(18, 18, 18)},
		"stair_routes": [first_stair, second_stair], "completion_text": config["completion_text"],
		"chamber_violation": chamber_violation, "interior_pressure": _pressure(level_id, origin),
		"optical_well": {"floor": 1, "cell": base + Vector3i(0, 3, -3),
			"position": origin + Vector3(0, 6, 18), "size": Vector3(6, .6, 6), "fenced": true},
		"upper_optical_well": {"floor": 2, "cell": base + Vector3i(-1, 6, -2),
			"position": origin + Vector3(-6, 12, 12), "size": Vector3(6, .6, 6), "fenced": true},
		"stele_east_wall": {"position": east_wall, "yaw": PI * .5, "size": Vector3(.5, 2.6, 3)},
		"door_a_sight": {"position": stages[0]["clue_position"] + Vector3(0, 1.6, 0),
			"look_at": stages[0]["door"]["position"] + Vector3(0, 1.6, .25), "target_gate_id": stages[0]["id"]}}
	var interior: Dictionary = expansion["interior"]
	if chamber_violation:
		interior["return_mirror"] = {"wall_position": origin + Vector3(20.4, 0, -4), "empty_frame_position": empty_frame,
			"looks_toward": origin + Vector3(-18, 0, 18), "room_name": "归名月室·守门灯阁"}
		interior["memory_return"] = {"inspect_position": empty_frame, "return_position": stages[2]["clue_position"],
			"return_route": routes[1], "final_route": routes[2], "stage_index": 2, "physical_floor": 0,
			"guard_approach": origin + Vector3(-15, 12, 8), "guard_placement_id": level_id + "/interior/top_shield"}
		interior["empty_mirror"] = {"position": empty_frame, "looks_toward": stages[2]["clue_position"]}
	Souls.extend(state, level)
	interior["roof_ladder_id"] = interior["souls"]["roof_ladder"]["id"]
	interior["interior_expansion_mods_v2"] = {
		"stele_east_wall": interior["stele_east_wall"], "door_a_sight": interior["door_a_sight"],
		"upper_sight_opening": {"position": origin + Vector3(-9, 15.1, 3), "size": Vector3(.5, 5.4, 12)},
		"front_gallery_lightwell": interior["optical_well"],
		"upper_gallery_lightwell": interior["upper_optical_well"],
		"b2_wall_passage": {"latch_id": interior["souls"]["b2_latch"]["id"], "lift_id": interior["souls"]["b2_lift"]["id"]},
		"interior_pressure": {"id": id + "/interior_pressure", "placements": interior["interior_pressure"]},
		"chamber_revisit": {"enabled": chamber_violation, "stage_index": 2, "physical_floor": 0 if chamber_violation else 2},
		"reward_glimpse": interior["souls"]["reward_vista"],
		"roof_ladder_id": interior["roof_ladder_id"]}
	state["expansion"]["interior"] = SceneStory.decorate(state["expansion"]["interior"], level_id)


static func _pressure(level_id: String, origin: Vector3) -> Array[Dictionary]:
	if level_id == "level_05_01":
		return []
	var roster: Array = PRESSURE_ROSTERS[int(level_id.substr(6, 2))]
	return [
		{"placement_id": level_id + "/interior/ground_ambush", "content_id": roster[0], "role": "ambush", "combat_role": "door_ambush",
			"position": origin + Vector3(-18, 1, 12), "facing": Vector3.BACK, "guard_radius": 5.0, "activation": "provoked", "patrol_points": []},
		{"placement_id": level_id + "/interior/middle_patrol", "content_id": roster[1], "role": "patrol",
			"position": origin + Vector3(-6, 6, -18), "facing": Vector3.RIGHT, "guard_radius": 7.0,
			"patrol_points": [origin + Vector3(-10, 6, -18), origin + Vector3(12, 6, -18)]},
		{"placement_id": level_id + "/interior/top_shield", "content_id": roster[2], "role": "guard", "combat_role": "front_shield",
			"position": origin + Vector3(-15, 12, 5), "facing": Vector3.BACK, "guard_radius": 7.0, "patrol_points": []},
	]


static func _memory_return_route(origin: Vector3, first: Array[Vector3], second: Array[Vector3], empty_frame: Vector3) -> Array[Vector3]:
	var route: Array[Vector3] = []
	route.assign(second)
	# The empty frame leads along the already accessible front gallery to its
	# shield guard. Resolve that threat before returning to the lower mirror.
	route.append_array([origin + Vector3(12, 12, 18), empty_frame, origin + Vector3(12, 12, 18),
		origin + Vector3(0, 12, 18), origin + Vector3(-15, 12, 18), origin + Vector3(-15, 12, 8),
		origin + Vector3(-15, 12, 18), origin + Vector3(0, 12, 18), origin + Vector3(12, 12, 18)])
	for index in range(second.size() - 1, -1, -1):
		route.append(second[index])
	route.append_array([origin + Vector3(12, 6, -18), origin + Vector3(0, 6, -18), origin + Vector3(-12, 6, -18)])
	for index in range(first.size() - 1, -1, -1):
		route.append(first[index])
	route.append_array([origin + Vector3(-12, 0, 18), origin + Vector3(-12, 0, 6), origin + Vector3(0, 0, 6),
		origin + Vector3(8, 0, 6), origin + Vector3(8, 0, 2)])
	return route


static func _memory_final_route(origin: Vector3, first: Array[Vector3], second: Array[Vector3], finale: Array[Vector3]) -> Array[Vector3]:
	var route: Array[Vector3] = [origin + Vector3(8, 0, 2), origin + Vector3(8, 0, 6), origin + Vector3(0, 0, 6),
		origin + Vector3(-12, 0, 6), origin + Vector3(-12, 0, 18)]
	route.append_array(first)
	route.append_array([origin + Vector3(-12, 6, -18), origin + Vector3(0, 6, -18), origin + Vector3(12, 6, -18)])
	route.append_array(second)
	route.append_array([origin + Vector3(12, 12, 18), origin + Vector3(0, 12, 18)])
	route.append_array(finale)
	return route


static func _has_floor(floor_index: int, x: int, z: int) -> bool:
	# A fenced front-gallery lightwell lets the real approach see the upper
	# pendant through the clerestory. Adjacent B2 and investigation routes stay.
	if floor_index == 1 and x == 0 and z == -3:
		return false
	# Continue the optical well through the top slab's full0.6m thickness.
	# The separate centre drop landing and front-row controls remain supported.
	if floor_index == 2 and x == -1 and z == -2:
		return false
	if floor_index > 0 and absi(x) <= 1 and absi(z) <= 1:
		return false
	if floor_index == 0 and x == -3:
		return z == -3
	if floor_index == 1 and absi(x) == 3:
		return z == 3
	if floor_index == 2 and x == 3:
		return absi(z) == 3
	if floor_index == 2 and x == 2 and absi(z) <= 1:
		return false
	return true


static func _chapter(chapter: int) -> Dictionary:
	var titles := ["守炉旧约", "两军补给簿", "借名三页", "校回缺页", "无名者归途"]
	var rooms := [["引魂值房", "守门灯阁", "留火书室"], ["押运账房", "匠魂档室", "归还军需库"],
		["借忆辨名室", "记忆校对阁", "归名月室"], ["坠城索引室", "缺页校读阁", "原卷指引室"],
		["归岸登记室", "见证留印阁", "无名归途室"]]
	var clues := [
		["值房木牌写着：先护住烬龛，才有人能够走到守门灯下。此处第一道封条应回应什么？", "灯谱的顺序是引魂、守门、归火。此刻已离开值房，尚未抵达归火书室，应点亮中间哪盏灯？", "最后一页留下旧院主的嘱托：不占余火，留给后来者。请按这句原文解除最后的封条。"],
		["两面军旗旁的运单有相同编号。账房注明：先核对编号，不能仅凭旗色把同一批物资算成两批。第一步是什么？", "中层欠簿写着：这些工具属于被迫锻造的匠魂，并非战利品。应将哪一栏列为待归还？", "库门批注写着：保存原簿，交给清醒的铁心核对；不要据副本替所有人宣判。封存哪份记录？"],
		["苔纸上每段记忆都署着陌生人的名字。它们来自被困的他人，并不是你的童年。第一份标签应该怎样写？", "忆录的校对规则写着：先核实署名，再辨认事件，最后归还记录。已有署名，现在应核对什么？", "月室最后一页写着：把记忆还给原来的名字，别把幸福幻象写成自己的经历。应保留怎样的归名标签？"],
		["坠城索引要求先按页码整理散页，不要以残句推断大破碎的全貌。第一步核对什么？", "校读规约写着：缺失处留白，原文未读不得补写。中间一页已失，应怎样记录？", "副本只指出藏经阁中原始实录的位置；它不能替代原卷，也不能替云游的责任作答。最终应保留哪条指引？"],
		["归岸登记簿先问来者的名字，再录见证，最后送其前行。无名者也有位置，应先登记什么？", "留印阁记着十二位铸魂者：九位陨落、三位仍活着。纪念与证言不可混写。哪一项符合记录？", "归途室的嘱托是：保留真实见证，让来者自己选择。此处的封条只校对这份嘱托，不替你选择世界的结局。"],
	]
	var choices := [
		[["护住烬龛", "封死来路", "夺取魂火"], ["归火灯", "守门灯", "引魂灯"], ["熄灭余火", "闭门占火", "为后来者留火"]],
		[["核对运单编号", "只按旗色分类", "烧去重号运单"], ["将军的战利品", "匠魂被扣的工具", "敌军的欠款"], ["自行改写军令", "只留下旗色", "保留原簿供铁心核对"]],
		[["他人留下的记忆", "我失去的童年", "尚未发生的预言"], ["寻找更美的幻象", "核对原记载事件", "抹去所有署名"], ["据为自己的经历", "改成无名梦境", "保留原主人的名字"]],
		[["核对散页页码", "补写缺失真相", "把副本当原卷"], ["填入猜测", "如实标记缺页", "删去整个章节"], ["就此定论", "替见证者作答", "前往藏经阁核验原始实录"]],
		[["登记无名来者", "先替其决定去处", "拒绝无名者"], ["十二位都已陨落", "九位陨落，三位仍生", "只有九位铸魂者"], ["替来者选择结局", "删去有分歧的证言", "保留见证，让来者选择"]],
	]
	var parts := [["MuralWall", "Sarcophagus"], ["WarTable", "WarBanner"], ["MemoryMirror", "WeddingLantern"],
		["ArchiveShelf", "RitualDesk"], ["RitualDesk", "SoulRib"]]
	var stages: Array[Dictionary] = []
	for index in 3:
		stages.append({"room": rooms[chapter][index], "clue": clues[chapter][index], "options": choices[chapter][index],
			"correct": index, "parts": parts[chapter]})
	return {"title": titles[chapter], "stages": stages,
		"completion_text": "你依次读完了" + String(titles[chapter]) + "的三层记录。封条褪去，留给后来者的余烬重新发亮。上层风铃响起，归途的升降台终于回应了你的脚步。"}


static func _wall_x(boxes: Array[Dictionary], architecture: Array[Dictionary], origin: Vector3, y: float, z: float,
		from: float, to: float, opening := INF, width := 0.0, windows := false) -> void:
	if is_finite(opening):
		_wall_x(boxes, architecture, origin, y, z, from, opening - width * .5, INF, 0.0, windows)
		_wall_x(boxes, architecture, origin, y, z, opening + width * .5, to, INF, 0.0, windows)
		return
	if to <= from:
		return
	var segments := ceili((to - from) / 6.0)
	var span := (to - from) / segments
	for index in segments:
		_wall_panel(boxes, architecture, origin + Vector3(from + span * (index + .5), y, z), span, false, windows)


static func _wall_z(boxes: Array[Dictionary], architecture: Array[Dictionary], origin: Vector3, y: float, x: float,
		from: float, to: float, opening := INF, width := 0.0, windows := false) -> void:
	if is_finite(opening):
		_wall_z(boxes, architecture, origin, y, x, from, opening - width * .5, INF, 0.0, windows)
		_wall_z(boxes, architecture, origin, y, x, opening + width * .5, to, INF, 0.0, windows)
		return
	if to <= from:
		return
	var segments := ceili((to - from) / 6.0)
	var span := (to - from) / segments
	for index in segments:
		_wall_panel(boxes, architecture, origin + Vector3(x, y, from + span * (index + .5)), span, true, windows)


static func _wall_panel(boxes: Array[Dictionary], architecture: Array[Dictionary], at: Vector3, span: float,
		along_z: bool, window: bool) -> void:
	var axis := Vector3.FORWARD if along_z else Vector3.RIGHT
	if not window or span < 4.0:
		_box_wall(boxes, architecture, at + Vector3(0, 3, 0), Vector3(.5, 6, span) if along_z else Vector3(span, 6, .5))
		return
	# Clerestory openings begin 3.5 m above each gallery. Their physical sill
	# remains higher than a jump, including alongside the enclosed stair strips.
	_box_wall(boxes, architecture, at + Vector3(0, 1.75, 0), Vector3(.5, 3.5, span) if along_z else Vector3(span, 3.5, .5))
	_box_wall(boxes, architecture, at + Vector3(0, 5.6, 0), Vector3(.5, .8, span) if along_z else Vector3(span, .8, .5))
	var jamb := 1.1
	for direction in [-1, 1]:
		_box_wall(boxes, architecture, at + axis * direction * (span - jamb) * .5 + Vector3(0, 4.35, 0),
			Vector3(.5, 1.7, jamb) if along_z else Vector3(jamb, 1.7, .5))


static func _foundation(boxes: Array[Dictionary], architecture: Array[Dictionary], origin: Vector3, chapter: int) -> void:
	# The fourth chapter is a suspended city. Its underside keeps short stone
	# buttresses; all other houses stand on piers that reach the ground plane.
	var foundation_y := maxf(0.0, origin.y - 8.0) if chapter == 3 else 0.0
	var pier_height := maxf(origin.y - foundation_y, 1.0)
	for x_side in [-1, 1]:
		for z_side in [-1, 1]:
			_box_wall(boxes, architecture, Vector3(origin.x + x_side * 18, foundation_y - .6, origin.z + z_side * 18), Vector3(8, 1.2, 8))
			architecture.append({"part": "Column", "position": Vector3(origin.x + x_side * 18, foundation_y, origin.z + z_side * 18),
				"yaw": 0.0, "scale": Vector3(2.0, pier_height / 6.0, 2.0), "collision": true})
	# Projecting courses and external pilasters make the three occupied levels
	# legible at a distance without stretching a single brick panel across 42 m.
	for floor_index in 3:
		var y := float(floor_index) * 6.0
		for side in [-1, 1]:
			for index in range(-3, 4):
				var along := float(index) * 6.0
				_box_wall(boxes, architecture, origin + Vector3(along, y - .3, side * 21), Vector3(6, .6, .9))
				_box_wall(boxes, architecture, origin + Vector3(side * 21, y - .3, along), Vector3(.9, .6, 6))
			for corner_side in [-1, 1]:
				_box_wall(boxes, architecture, origin + Vector3(side * 20, y - .2, corner_side * 20), Vector3(2.6, .4, 2.6))
				architecture.append({"part": "Column", "position": origin + Vector3(side * 20, y, corner_side * 20),
					"yaw": 0.0, "scale": Vector3(.75, 1, .75), "collision": true})


static func _box_wall(boxes: Array[Dictionary], architecture: Array[Dictionary], position: Vector3, size: Vector3) -> void:
	boxes.append({"position": position, "size": size, "yaw": 0.0, "visual": false})
	var along_z := size.z > size.x
	architecture.append({"part": "Wall", "position": position - Vector3(0, size.y * .5, 0), "yaw": PI * .5 if along_z else 0.0,
		"scale": Vector3((size.z if along_z else size.x) / 6.0, size.y / 10.0, (size.x if along_z else size.z) / 1.5), "collision": false})


static func _gate_wings(boxes: Array[Dictionary], architecture: Array[Dictionary], door: Vector3, width: float) -> void:
	var wing := (width - 3.8) * .5
	for side in [-1, 1]:
		_box_wall(boxes, architecture, door + Vector3(side * (1.9 + wing * .5), 3, 0), Vector3(wing, 6, .6))


static func _put(state: Dictionary, cell: Vector3i, building_cells: Array[Vector3i]) -> void:
	state["cell_set"][cell] = true
	if cell not in building_cells:
		building_cells.append(cell)


static func _ramp(state: Dictionary, lower: Vector3i, upper: Vector3i, building_cells: Array[Vector3i], route: Array[Vector3]) -> void:
	assert(upper.y - lower.y == 1 and absi(upper.x - lower.x) + absi(upper.z - lower.z) == 2)
	_put(state, lower, building_cells)
	_put(state, upper, building_cells)
	state["ramps"].append({"lower": lower, "upper": upper})
	if route.is_empty():
		route.append(_floor(lower))
	route.append(_floor(upper))


static func _line(state: Dictionary, from: Vector3i, to: Vector3i, building_cells: Array[Vector3i], route: Array[Vector3]) -> void:
	assert(from.y == to.y and (from.x == to.x or from.z == to.z))
	var steps := maxi(absi(to.x - from.x), absi(to.z - from.z))
	var direction := Vector3i(signi(to.x - from.x), 0, signi(to.z - from.z))
	for index in steps + 1:
		var cell := from + direction * index
		_put(state, cell, building_cells)
		var position := _floor(cell)
		if route.is_empty() or route.back() != position:
			route.append(position)


static func _cell(position: Vector3) -> Vector3i:
	return Vector3i(roundi(position.x / 6), roundi(position.y / 2), roundi(-position.z / 6))


static func _floor(cell: Vector3i) -> Vector3:
	return Vector3(cell.x * 6, cell.y * 2, -cell.z * 6)


static func _edge(cell: Vector3i, direction: Vector3i) -> String:
	return "%d,%d,%d:%d,%d" % [cell.x, cell.y, cell.z, direction.x, direction.z]
