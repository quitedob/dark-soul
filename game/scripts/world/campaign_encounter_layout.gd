class_name CampaignEncounterLayout
extends RefCounted
## Pure placement plans keyed by actual content ID + occurrence, not roster order.
## AI consumes the plan through game_world; this provider never touches nodes.

const Dressing = preload("res://scripts/data/campaign_scene_dressing.gd")


static func authored_encounters(level_id: String) -> Array[Dictionary]:
	var p: Array[Dictionary] = []
	match level_id:
		"level_01_01":
			_e(p,"lost_soul_soldier",Vector3(-5,0,-42),"patrol","outer_court",[Vector3(-5,0,-37),Vector3(-5,0,-47)])
			_e(p,"lost_soul_soldier",Vector3(5,0,-57),"guard","processional_gate")
			_e(p,"lost_soul_soldier",Vector3(-8,0,-110),"patrol","inner_court",[Vector3(-8,0,-104),Vector3(-8,0,-116)])
			_e(p,"ember_shade_skirmisher",Vector3(-42,0,-60),"ranged","west_cloister")
			_e(p,"ember_shade_skirmisher",Vector3(42,0,-81),"ranged","east_cloister")
			_e(p,"temple_guardian_warrior",Vector3(8,0,-119),"guard","sanctum_watch")
		"level_01_02":
			_e(p,"lost_soul_soldier",Vector3(-12,0,-43),"ambush","alcove_watch")
			_e(p,"lost_soul_soldier",Vector3(2,0,-75),"patrol","cross_corridor",[Vector3(-5,0,-75),Vector3(5,0,-75)])
			_e(p,"lost_soul_soldier",Vector3(-3,0,-110),"guard","flame_vent")
			_e(p,"temple_guardian_warrior",Vector3(5,0,-140),"guard","exit_lever")
		"level_01_03":
			_e(p,"lost_soul_soldier",Vector3(-23,0,-46),"patrol","west_hall",[Vector3(-23,0,-40),Vector3(-23,0,-52)])
			_e(p,"lost_soul_soldier",Vector3(-11,0,-60),"patrol","east_hall",[Vector3(-11,0,-54),Vector3(-11,0,-64)])
			_e(p,"lost_soul_soldier",Vector3(12,0,-93),"guard","mirror_threshold")
			_e(p,"mirror_shade",Vector3(-27,0,-64),"ambush","north_mirror")
			_e(p,"mirror_shade",Vector3(27,0,-105),"ambush","east_mirror")
			_e(p,"ember_shade_skirmisher",Vector3(6,0,-70),"ranged","mirror_crossfire")
			_e(p,"elite_bronze_mirror_keeper",Vector3(16,0,-116),"elite","puzzle_guardian")
		"level_01_04":
			_e(p,"temple_guardian_warrior",Vector3(-34,0,-65),"guard","west_valve")
			_e(p,"temple_guardian_warrior",Vector3(34,0,-89),"guard","east_valve")
			_e(p,"furnace_slag_beast",Vector3(39,0,-99),"guard","ingredient_store")
			_e(p,"elite_elixir_golem",Vector3(-35,0,-77),"elite","abandoned_alchemist")
		"level_02_01":
			_e(p,"battle_worn_soldier",Vector3(-22,0,-45),"patrol","wrecked_convoy",[Vector3(-19,0,-42),Vector3(-26,0,-46)])
			_e(p,"battle_worn_soldier",Vector3(-34,2,-80),"ambush","scout_detour")
			_e(p,"battle_worn_soldier",Vector3(24,4,-111),"guard","upper_siege")
		"level_02_02":
			_e(p,"battle_worn_soldier",Vector3(-28,6,-61),"guard","lower_rampart")
			_e(p,"battle_worn_soldier",Vector3(17,10,-84),"patrol","cross_rampart",[Vector3(12,10,-84),Vector3(23,10,-84)])
			_e(p,"war_dog_wraith",Vector3(35,12,-121),"ambush","paired_hounds")
			_e(p,"war_dog_wraith",Vector3(41,12,-122),"ambush","paired_hounds")
		"level_02_03":
			_e(p,"camp_guard_wraith",Vector3(-32,0,-57),"patrol","cage_patrol",[Vector3(-32,0,-49),Vector3(-32,0,-62)])
			_e(p,"camp_guard_wraith",Vector3(32,0,-55),"guard","forced_forge")
			_e(p,"torture_device_spirit",Vector3(-32,0,-99),"guard","punishment_yard")
			_e(p,"elite_torture_master",Vector3(29,0,-98),"elite","warden_quarters")
		"level_02_04":
			_e(p,"battle_worn_soldier",Vector3(-24,6,-62),"ambush","unlit_landing")
			_e(p,"beacon_keeper_wraith",Vector3(20,12,-23),"ranged","middle_firepost")
			_e(p,"beacon_keeper_wraith",Vector3(-26,24,-98),"ranged","summit_firepost")
			_e(p,"elite_beacon_lord",Vector3(-7,24,-101),"elite","beacon_duel")
		"level_02_05":
			_e(p,"generals_personal_guard",Vector3(-5,0,-53),"guard","command_formation")
			_e(p,"generals_personal_guard",Vector3(0,0,-57),"guard","command_formation")
			_e(p,"generals_personal_guard",Vector3(5,0,-53),"guard","command_formation")
			_e(p,"elite_siege_commander",Vector3(-23,0,-118),"elite","quartermaster_store")
		"level_03_01":
			_e(p,"illusion_butterfly",Vector3(-22,0,-49),"ambush","first_bamboo_loop")
			_e(p,"illusion_butterfly",Vector3(-48,0,-92),"ambush","false_tree_loop")
			_e(p,"foxfire_lantern",Vector3(23,0,-74),"guard","false_foxfire")
		"level_03_02":
			_e(p,"memory_thief",Vector3(-17,0,-64),"patrol","memory_prison",[Vector3(-17,0,-60),Vector3(-17,0,-75)])
			_e(p,"memory_thief",Vector3(23,0,-115),"ambush","borrowed_memory")
			_e(p,"echo_spirit",Vector3(9,0,-126),"ranged","echo_gallery")
			_e(p,"elite_memory_eater",Vector3(-17,0,-78),"elite","memory_keeper_guard")
		"level_03_03":
			_e(p,"wedding_gown_ghost",Vector3(25,0,-61),"patrol","wedding_procession",[Vector3(24,0,-55),Vector3(24,0,-64)])
			_e(p,"water_moon_spirit",Vector3(-22,0,-109),"ambush","vanished_bride")
			_e(p,"foxfire_lantern",Vector3(16,0,-47),"guard","wedding_procession")
		"level_03_04":
			_e(p,"mirror_flower_spirit",Vector3(-27,0,-67),"ranged","west_reflection")
			_e(p,"mirror_flower_spirit",Vector3(27,0,-85),"ranged","east_reflection")
			_e(p,"water_moon_spirit",Vector3(-6,0,-66),"ambush","first_true_stone")
			_e(p,"water_moon_spirit",Vector3(0,0,-72),"ambush","pavilion_true_stone")
			_e(p,"water_moon_spirit",Vector3(6,0,-84),"ambush","last_true_stone")
			_e(p,"elite_reflection_lord",Vector3(0,0,-104),"elite","lake_exit")
			_e(p,"elite_ember_greed_ghost",Vector3(30,0,-104),"ambush","tea_bridge_truth")
		"level_03_05":
			_e(p,"maze_guardian",Vector3(-36,0,-44),"patrol","maze_first_turn",[Vector3(-36,0,-36),Vector3(-36,0,-50)])
			_e(p,"mind_lost_fox_demon",Vector3(33,0,-57),"ambush","riddle_flank")
			_e(p,"mind_lost_fox_demon",Vector3(-16,0,-112),"ambush","last_maze_turn")
			_e(p,"elite_fox_bride",Vector3(-16,0,-137),"elite","maze_poet")
		"level_04_01":
			_e(p,"stairway_guard_wraith",Vector3(13,4,-48),"guard","lower_stair_landing")
			_e(p,"stairway_guard_wraith",Vector3(-13,12,-96),"guard","upper_stair_landing")
			_e(p,"cloud_sky_eagle",Vector3(12,8,-72),"ambush","cloud_dive")
			_e(p,"elite_celestial_swordsman",Vector3(0,18,-139),"elite","last_cloud_guard")
		"level_04_02":
			_e(p,"elixir_furnace_spirit",Vector3(-31,2,-66),"guard","bronze_furnace")
			_e(p,"alchemy_fallen_immortal",Vector3(-29,2,-77),"ranged","ingredient_keeper")
			_e(p,"elite_alchemy_master",Vector3(29,4,-113),"elite","unquenched_furnace")
		"level_04_03":
			_e(p,"book_spirit",Vector3(-10,0,-39),"ranged","lower_archive")
			_e(p,"book_spirit",Vector3(10,6,-80),"ranged","upper_archive")
			_e(p,"library_guardian_spirit",Vector3(-12,6,-91),"guard","gravity_catalogue")
			_e(p,"elite_scripture_keeper",Vector3(-5,12,-131),"elite","original_record")
		"level_05_01":
			_e(p,"ember_shore_drifter",Vector3(-21,0,-52),"passive","silent_shore",[Vector3(-21,0,-48),Vector3(-21,0,-56)])
			_e(p,"ember_shore_drifter",Vector3(20,0,-102),"passive","soul_current",[Vector3(20,0,-106),Vector3(20,0,-96)])
			# Existing bat roster is retained, but quiet shoreline encounters cannot
			# ambush the mandatory witness route. They only defend themselves.
			_e(p,"ember_bat",Vector3(30,0,-138),"passive","distant_ember_roost")
			_e(p,"ember_bat",Vector3(36,0,-144),"passive","distant_ember_roost")
		"level_05_02":
			_e(p,"inverted_guardian",Vector3(-24,0,-42),"guard","lower_inverted_hall")
			_e(p,"inverted_guardian",Vector3(12,4,-72),"patrol","cross_surface_gallery",[Vector3(6,4,-72),Vector3(18,4,-72)])
			_e(p,"elite_gravity_twister",Vector3(4,8,-124),"elite","final_gravity_anchor")
		"level_05_03":
			_e(p,"forked_path_shade",Vector3(-42,0,-64),"guard","spirit_war_memories")
			_e(p,"forked_path_shade",Vector3(42,0,-90),"guard","jade_heaven_memories")
			_e(p,"shadow_of_possibility",Vector3(-42,0,-95),"ambush","unchosen_west_path")
			_e(p,"elite_void_sentinel",Vector3(41,0,-112),"elite","possibility_sea")
		"level_05_04":
			_e(p,"soul_forger_remnant",Vector3(-29,0,-55),"guard","memorial_trial_north")
			_e(p,"soul_forger_remnant",Vector3(-31,0,-91),"guard","memorial_trial_south")
			_e(p,"elite_soul_forger_echo",Vector3(-8,0,-107),"elite","last_torch_servant")
	for row: Dictionary in p:
		row["story_source"] = Dressing.story_source(level_id)
	return p


static func assign_encounters(level_id: String, layout: Dictionary, enemies: Array) -> Array[Dictionary]:
	var authored := authored_encounters(level_id)
	var used: Dictionary = {}
	var assigned: Array[Dictionary] = []
	var reserved: Array[Vector3] = []
	for index in enemies.size():
		if not enemies[index] is Dictionary:
			return []
		var enemy: Dictionary = enemies[index]
		var content_id := String(enemy.get("content_id", enemy.get("id", "")))
		var occurrence := int(used.get(content_id, 0))
		used[content_id] = occurrence + 1
		var matching: Array[Dictionary] = []
		for recipe: Dictionary in authored:
			if recipe["content_id"] == content_id:
				matching.append(recipe)
		if occurrence >= matching.size():
			return []
		var row: Dictionary = matching[occurrence].duplicate(true)
		var radius := maxf(float(enemy.get("body_radius", .5)), .5)
		var position := _clear_position(layout, row["position"], radius, reserved)
		if not position.is_finite():
			return []
		row["position"] = position
		row["source_index"] = index
		row["occurrence"] = occurrence
		row["encounter_id"] = "%s/%s/%d" % [level_id, content_id, occurrence]
		var patrol: Array[Vector3] = []
		for waypoint: Vector3 in row["patrol_points"]:
			var point := _clear_position(layout, waypoint, radius, [])
			if point.is_finite():
				patrol.append(point)
		row["patrol_points"] = patrol
		reserved.append(position)
		assigned.append(row)
	return assigned


static func _clear_position(layout: Dictionary, requested: Vector3, radius: float, reserved: Array) -> Vector3:
	# Adjust only inside the authored encounter region. Failure must be surfaced
	# to the caller; it must never silently move an enemy back onto a generic row.
	var offsets: Array[Vector2] = [Vector2.ZERO]
	for distance: float in [2.,4.,6.]:
		for direction: Vector2 in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN,
			Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]:
			offsets.append(direction * distance)
	for offset: Vector2 in offsets:
		var point := requested + Vector3(offset.x,0,offset.y)
		if not is_supported(layout, point, radius + .2) or not is_clear(layout, point, radius + .5):
			continue
		var occupied := false
		for previous: Vector3 in reserved:
			if absf(point.y-previous.y)<3 and Vector2(point.x-previous.x,point.z-previous.z).length()<3.:
				occupied = true
		if not occupied:
			return point
	return Vector3(INF,INF,INF)


static func is_supported(layout: Dictionary, point: Vector3, margin: float = .7) -> bool:
	var cells: Array = layout.get("cells", [])
	if cells.is_empty() and layout.has("walkable_cells"):
		cells = [] # Do not append to a caller-owned empty cells array.
		for raw: Array in layout["walkable_cells"]:
			cells.append(Vector3i(int(raw[0]),int(raw[1]),int(raw[2])))
	for offset: Vector2 in [Vector2.ZERO,Vector2(-margin,-margin),Vector2(margin,-margin),Vector2(-margin,margin),Vector2(margin,margin)]:
		var supported := false
		for cell: Vector3i in cells:
			if absf(cell.y*2.-point.y)<.05 and absf(cell.x*6.-point.x-offset.x)<=3.001 and absf(-cell.z*6.-point.z-offset.y)<=3.001:
				supported = true
				break
		if not supported:
			return false
	return true


static func is_clear(layout: Dictionary, point: Vector3, margin: float = 1.) -> bool:
	if Vector2(point.x,point.z+6.).length()<22.:
		return false
	var lake_stone := _is_lake_true_stone(layout, point)
	for prop: Dictionary in layout.get("story_props", []):
		if not bool(prop.get("collision", true)):
			continue
		var origin: Vector3 = prop["position"]
		# This pavilion is an open column structure, with a measured 3.58m
		# central passage and no raised slab. Its AABB is not a solid room.
		if lake_stone and prop["part_id"] == "LakePavilion" and absf(point.x-origin.x)+margin < 1.79:
			continue
		var half := Dressing.footprint(prop)*.5 + Vector2(margin,margin)
		if absf(origin.y-point.y)<3. and absf(origin.x-point.x)<half.x and absf(origin.z-point.z)<half.y:
			return false
	for origin: Vector3 in layout.get("story_anchors", {}).values():
		if absf(origin.y-point.y)<3. and Vector2(origin.x-point.x,origin.z-point.z).length()<2.5+margin:
			return false
	for module_id: String in layout.get("modules", {}):
		# The live reflection controller replaces this old device with the
		# revealed stone course; the stone's center is an intended ambush post.
		if lake_stone and module_id == "illusion_marker":
			continue
		var origin: Vector3 = layout["modules"][module_id]
		if absf(origin.y-point.y)<3. and absf(origin.x-point.x)<2.5+margin and absf(origin.z-point.z)<2.5+margin:
			return false
	# Runtime module children can stand beyond their device origin. Reserve the
	# real offering-door target and shortcut bodies, not just the switch point.
	if layout.get("modules",{}).has("switch_offering"):
		var barrier: Vector3 = layout["modules"]["switch_offering"] + Vector3(0,0,-4)
		if absf(barrier.y-point.y)<3. and absf(barrier.x-point.x)<1.5+margin and absf(barrier.z-point.z)<.25+margin:
			return false
	if layout.has("shortcut_door"):
		var door: Vector3 = layout["shortcut_door"]
		if absf(door.y-point.y)<3.2 and absf(door.x-point.x)<2.1+margin and absf(door.z-point.z)<.225+margin:
			return false
	if layout.has("shortcut_elevator"):
		var elevator: Vector3 = layout["shortcut_elevator"]
		if absf(elevator.y-point.y)<2. and absf(elevator.x-point.x)<2.+margin and absf(elevator.z-point.z)<2.+margin:
			return false
	for feature: Dictionary in layout.get("features", []):
		var origin: Vector3 = feature["position"]
		if absf(origin.y-point.y)>=8.:
			continue
		if feature["part"] == "Gate":
			for side in [-1,1]:
				var pillar := origin + Basis(Vector3.UP,float(feature.get("yaw",0))) * Vector3(side*4.8,0,0)
				if Vector2(pillar.x-point.x,pillar.z-point.z).length()<1.5+margin:
					return false
	return true


static func _is_lake_true_stone(layout: Dictionary, point: Vector3) -> bool:
	if String(layout.get("id", "")) != "level_03_04":
		return false
	for stone: Vector3 in [Vector3(-6,0,-66),Vector3(0,0,-72),Vector3(6,0,-84)]:
		if point.is_equal_approx(stone):
			return true
	return false


static func _e(p: Array[Dictionary], content: String, position: Vector3, role: String, group: String, patrol: Array = []) -> void:
	var activation := "proximity"
	if role == "passive":
		activation = "provoked"
	elif role == "ambush":
		activation = "ambush"
	var yaw := PI # Most watchmen face the approach (+Z); first patrol faces away.
	if role == "patrol":
		yaw = 0.
	p.append({"content_id": content, "position": position, "facing_yaw": yaw,
		"role": role, "group_id": group, "patrol_points": patrol,
		"activation": activation, "guard_radius": 8. if role == "guard" else 14.})
