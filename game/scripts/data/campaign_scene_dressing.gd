class_name CampaignSceneDressing
extends RefCounted
## Story-authored floor-origin placements. Coordinates are Godot metres, front -Z.
## These plans never move a gameplay node or write progression state.

const CHAPTER_DOCS := [
	"docs/chapters/01-spirit-awakening/levels/01-levels-detail.md",
	"docs/chapters/02-blood-iron/chapter-overview.md",
	"docs/chapters/03-jade-veil/chapter-overview.md",
	"docs/chapters/04-celestial-fall/chapter-overview.md",
	"docs/chapters/05-throne-of-ashes/chapter-overview.md",
]
const LEVEL_LINES := {
	"01_01": 3, "01_02": 35, "01_03": 71, "01_04": 108, "01_05": 147,
	"02_01": 24, "02_02": 35, "02_03": 46, "02_04": 57, "02_05": 68, "02_06": 79,
	"03_01": 24, "03_02": 35, "03_03": 46, "03_04": 57, "03_05": 68, "03_06": 79,
	"04_01": 24, "04_02": 37, "04_03": 50, "04_04": 63, "04_05": 76, "04_06": 89,
	"05_01": 24, "05_02": 37, "05_03": 50, "05_04": 69, "05_05": 85,
}
const FOOTPRINTS := {
	"MuralWall": Vector2(6,.9), "AwakeningBier": Vector2(2,3.6),
	"KneelingStatue": Vector2(2.4,2.4), "CryptWall": Vector2(6,1),
	"Sarcophagus": Vector2(1.7,3.2), "WatchBrazier": Vector2(2,2),
	"PrisonCage": Vector2(4,4), "CommandTent": Vector2(8,8),
	"WarTable": Vector2(3,2.3), "WarBanner": Vector2(2.5,1),
	"SiegeWagon": Vector2(3.4,5), "Barricade": Vector2(6,1.4),
	"BeaconTower": Vector2(8,8), "BambooGrove": Vector2(6,6),
	"WeddingLantern": Vector2(1.4,1.4), "Palanquin": Vector2(3.5,5),
	"MemoryMirror": Vector2(3,1.2), "LakePavilion": Vector2(10,10),
	"IllusionTree": Vector2(6,6), "HedgeWall": Vector2(6,1.6),
	"LakeSurface": Vector2(18,18), "ArchiveShelf": Vector2(5,1.4),
	"BronzeCauldron": Vector2(5,5), "CelestialSpire": Vector2(5,5),
	"BrokenArch": Vector2(8,2), "Orrery": Vector2(6,6),
	"RitualDesk": Vector2(3,2), "AshShore": Vector2(16,10),
	"SoulRib": Vector2(7,3), "Throne": Vector2(5,5),
	"ChainAnchor": Vector2(3,5), "LivingSealTorchDragon": Vector2(3,3),
	"LivingSealCloudWanderer": Vector2(3,3), "LivingSealSilenceBringer": Vector2(3,3),
	"BellTower": Vector2(16,16), "DecoyBell": Vector2(1.4,1.4),
}
const MEMORIALS := ["StarForger", "ThoughtBreaker", "DustReturner", "FateWeaver",
	"GateKeeper", "SinMeasurer", "LampLighter", "SoulPacifier", "CycleTurner"]


static func story_source(level_id: String) -> String:
	if level_id == "level_05_06":
		return "docs/bestiary/boss-blind-bell-hearer.md:78"
	var short_id := level_id.trim_prefix("level_")
	return "%s:%d" % [CHAPTER_DOCS[clampi(int(short_id.left(2)) - 1, 0, 4)], LEVEL_LINES.get(short_id, 1)]


static func plan_scene(level: Dictionary, _layout: Dictionary) -> Array[Dictionary]:
	var id := String(level.get("id", ""))
	var p: Array[Dictionary] = []
	# Each case describes a particular place in the chapter story. Repetition below
	# is architectural rhythm (shelves, processional lamps), not random scattering.
	match id:
		"level_01_01":
			_add(p, "AwakeningBier", Vector3(-9,0,7), "waking_chamber")
			_add(p, "KneelingStatue", Vector3(9,0,7), "forgotten_scions")
			_pair(p, "MuralWall", Vector3(0,0,-15), 15, PI * .5, "furnace_cycle")
			_pair(p, "WatchBrazier", Vector3(0,0,-96), 12, 0, "inner_sanctum")
		"level_01_02":
			_pair(p, "KneelingStatue", Vector3(0,0,-42), 12, 0, "training_alcoves")
			_pair(p, "MuralWall", Vector3(0,0,-72), 8, PI * .5, "scorched_corridor")
			_pair(p, "CryptWall", Vector3(0,0,-108), 8, PI * .5, "watch_gallery")
			_pair(p, "WatchBrazier", Vector3(0,0,-144), 12, 0, "gate_chamber")
		"level_01_03":
			for z in [-42,-54,-66]:
				_add(p, "MemoryMirror", Vector3(-32,0,z), "north_mirror_gallery", PI*.5)
			for z in [-90,-102,-114]:
				_add(p, "MemoryMirror", Vector3(32,0,z), "east_mirror_gallery", -PI*.5)
			_add(p, "MuralWall", Vector3(-18,0,-33), "ceiling_hint_relic")
			_add(p, "KneelingStatue", Vector3(7,0,-115), "puzzle_witness")
		"level_01_04":
			_add(p, "BronzeCauldron", Vector3(-40,0,-66), "west_valve_room")
			_add(p, "BronzeCauldron", Vector3(40,0,-90), "east_valve_room")
			_add(p, "Sarcophagus", Vector3(46,0,-99), "alchemist_remains")
			_add(p, "ArchiveShelf", Vector3(46,0,-83), "ingredient_store")
			_pair(p, "MuralWall", Vector3(0,0,-126), 8, PI*.5, "keeper_offering")
			_add(p, "WatchBrazier", Vector3(-44,0,-58), "green_fire_furnace")
		"level_02_01":
			_add(p, "SiegeWagon", Vector3(-30,0,-43), "ambushed_supply_train", .25)
			_add(p, "WarBanner", Vector3(-16,0,-37), "forgotten_front")
			_add(p, "Barricade", Vector3(-42,2,-80), "scout_bypass")
			_add(p, "Sarcophagus", Vector3(-42,2,-94), "mass_grave_marker")
			_add(p, "SiegeWagon", Vector3(30,4,-112), "upper_siege_post", PI*.5)
			_add(p, "WarBanner", Vector3(18,4,-118), "summit_sighting")
		"level_02_02":
			_add(p, "SiegeWagon", Vector3(-30,6,-60), "lower_ballista")
			_add(p, "Barricade", Vector3(-15,10,-89), "cross_wall_oil")
			_add(p, "WarBanner", Vector3(12,10,-79), "opposed_armies")
			_add(p, "SiegeWagon", Vector3(43,12,-116), "upper_ballista")
			_add(p, "WarBanner", Vector3(47,12,-135), "upper_watch")
			_add(p, "Barricade", Vector3(27,12,-127), "hound_yard")
		"level_02_03":
			for z in [-46,-58,-98]:
				_add(p, "PrisonCage", Vector3(-39,0,z), "spirit_smith_cages")
			_add(p, "BronzeCauldron", Vector3(37,0,-49), "forced_forge")
			_add(p, "WarTable", Vector3(37,0,-101), "warden_desk")
			_add(p, "CommandTent", Vector3(42,0,-96), "warden_quarters")
			_add(p, "WarBanner", Vector3(-28,0,-101), "broken_smith_seal")
		"level_02_04":
			_add(p, "WarBanner", Vector3(-30,6,-64), "first_watch_landing")
			_add(p, "WatchBrazier", Vector3(18,6,-65), "unlit_ambush_brazier")
			_add(p, "WarBanner", Vector3(12,12,-18), "second_watch_landing")
			_add(p, "BeaconTower", Vector3(-30,24,-107), "summit_beacon")
			_add(p, "WarTable", Vector3(-10,24,-108), "beacon_protocol")
			_add(p, "Barricade", Vector3(-32,24,-94), "twin_generals_post")
		"level_02_05":
			_add(p, "CommandTent", Vector3(21,0,-47), "general_command")
			_add(p, "WarTable", Vector3(21,0,-47), "campaign_map")
			for x in [-20,-10,10,20]:
				_add(p, "WarBanner", Vector3(x,0,-58), "four_banner_oath")
			_add(p, "SiegeWagon", Vector3(-31,0,-118), "quartermaster_store")
			_add(p, "CommandTent", Vector3(12,0,-124), "last_muster")
		"level_03_01":
			for z in [-43,-66,-89]:
				_pair(p, "BambooGrove", Vector3(-24,0,z), 7, 0, "repeated_bamboo_path")
			_add(p, "IllusionTree", Vector3(-49,0,-110), "third_identical_tree")
			_add(p, "MemoryMirror", Vector3(31,0,-76), "impossible_stream")
			_add(p, "WeddingLantern", Vector3(11,0,-127), "false_foxfire")
		"level_03_02":
			for z in [-62,-70,-78]:
				_add(p, "MemoryMirror", Vector3(-31,0,z), "three_true_memories", PI*.5)
			_add(p, "IllusionTree", Vector3(-8,0,-70), "memory_moss_prison")
			_add(p, "MemoryMirror", Vector3(30,0,-124), "borrowed_memory", -PI*.5)
			_add(p, "RitualDesk", Vector3(28,0,-117), "lady_testimony")
		"level_03_03":
			for z in [-42,-57,-72]:
				_pair(p, "WeddingLantern", Vector3(24,0,z), 6, 0, "procession_lamps")
			_add(p, "Palanquin", Vector3(30,0,-80), "fox_wedding")
			_add(p, "BambooGrove", Vector3(-37,0,-63), "hidden_following_path")
			_add(p, "WeddingLantern", Vector3(-29,0,-111), "bridal_rest")
			_add(p, "Palanquin", Vector3(-28,0,-135), "vanished_bride")
		"level_03_04":
			_add(p, "LakePavilion", Vector3(0,0,-72), "reflection_pavilion")
			_add(p, "LakeSurface", Vector3(0,-.09,-47), "north_moon_lake", 0, false)
			_add(p, "LakeSurface", Vector3(0,-.09,-96), "south_moon_lake", 0, false)
			_add(p, "MemoryMirror", Vector3(-36,0,-84), "water_moon_reflection", PI*.5)
			_add(p, "WeddingLantern", Vector3(36,0,-59), "tea_bridge_light")
			_add(p, "RitualDesk", Vector3(35,0,-77), "tea_offering")
		"level_03_05":
			for z in [-35,-47,-59]:
				_add(p, "HedgeWall", Vector3(-43,0,z), "jade_maze_west", PI*.5)
			for x in [-25,-13,1,13,25]:
				# The live nine-state maze owns X[-9,9], Z[-33,-75].
				# Its solved middle lane must not retain a permanent hedge.
				var position := Vector3(43,0,-65) if x == 1 else Vector3(x,0,-67)
				_add(p, "HedgeWall", position, "nine_configurations", PI*.5 if x == 1 else 0.0)
			for z in [-77,-89,-101]:
				_add(p, "HedgeWall", Vector3(43,0,z), "jade_maze_east", PI*.5)
			_add(p, "RitualDesk", Vector3(-24,0,-143), "maze_poet")
			_add(p, "IllusionTree", Vector3(48,0,-142), "last_riddle")
		"level_04_01":
			# Keep the solid spire on the outer landing apron, clear of the
			# eastbound turn between the ramp rail and the modeled gate pillar.
			_add(p, "CelestialSpire", Vector3(-12,4,-48), "first_cloud_landing")
			_add(p, "BrokenArch", Vector3(18,8,-78), "broken_ascent")
			_add(p, "Orrery", Vector3(-7,12,-96), "celestial_dial")
			_add(p, "BrokenArch", Vector3(-18,16,-126), "upper_cloud_bridge")
			_add(p, "WarBanner", Vector3(8,18,-138), "last_guardian")
		"level_04_02":
			_add(p, "BronzeCauldron", Vector3(-7,0,-38), "entry_drug_fire")
			_add(p, "BronzeCauldron", Vector3(-37,2,-66), "left_elixir_furnace")
			_add(p, "BronzeCauldron", Vector3(-23,2,-78), "right_elixir_furnace")
			_add(p, "RitualDesk", Vector3(-38,2,-79), "ingredient_formula")
			_add(p, "BronzeCauldron", Vector3(38,4,-113), "unquenched_medicine")
			_add(p, "ArchiveShelf", Vector3(39,4,-128), "elixir_vials")
		"level_04_03":
			for floor_spec in [[0,36],[6,81],[12,126]]:
				for x in [-18,18]:
					for dz in [-5,5]:
						_add(p, "ArchiveShelf", Vector3(x,floor_spec[0],-floor_spec[1]+dz), "celestial_archive", PI*.5)
			_add(p, "RitualDesk", Vector3(10,12,-135), "original_heavenly_record")
			_add(p, "Orrery", Vector3(-10,6,-85), "inverted_catalogue")
		"level_05_01":
			for shore in [Vector3(-19,-.28,-47),Vector3(18,-.28,-91),Vector3(36,-.28,-144)]:
				_add(p, "AshShore", shore, "cooled_ember_shore", 0, false)
			_add(p, "SoulRib", Vector3(-26,0,-62), "silent_soul_current", PI*.5)
			_add(p, "SoulRib", Vector3(25,0,-99), "souls_return_to_core", PI*.5)
			_add(p, "LivingSealCloudWanderer", Vector3(-12,0,-31), "witness_confession")
		"level_05_02":
			_add(p, "BrokenArch", Vector3(-29,0,-40), "upturned_sanctuary")
			_add(p, "ChainAnchor", Vector3(-32,0,-48), "first_gravity_lock")
			_add(p, "Orrery", Vector3(-12,4,-78), "cross_surface_lock")
			_add(p, "SoulRib", Vector3(31,8,-105), "inverted_roof_ribs", PI*.5)
			_add(p, "ChainAnchor", Vector3(-11,8,-127), "last_gravity_lock")
			_add(p, "BrokenArch", Vector3(10,8,-125), "ceiling_sanctum")
		"level_05_03":
			_add(p, "MuralWall", Vector3(-48,0,-64), "remembered_spirit_ruins", PI*.5)
			_add(p, "WarBanner", Vector3(-33,0,-81), "remembered_war_oath")
			_add(p, "MemoryMirror", Vector3(35,0,-89), "remembered_fox_truth", -PI*.5)
			_add(p, "CelestialSpire", Vector3(49,0,-102), "remembered_heaven")
			_add(p, "RitualDesk", Vector3(-46,0,-75), "accept_or_regret_west")
			_add(p, "RitualDesk", Vector3(38,0,-100), "accept_or_regret_east")
			_add(p, "SoulRib", Vector3(-7,0,-122), "unchangeable_history")
		"level_05_04":
			# Twelve seats, nine dead: the three living seals occupy the remaining arc.
			for index in 9:
				var angle := TAU * float(index + 2) / 12.0
				_add(p, "Memorial" + MEMORIALS[index], Vector3(cos(angle)*36,0,-72+sin(angle)*36), "nine_fallen_forgers", -angle-PI*.5)
			for index in 3:
				var angle := TAU * float(index + 11) / 12.0
				_add(p, ["LivingSealTorchDragon","LivingSealCloudWanderer","LivingSealSilenceBringer"][index], Vector3(cos(angle)*36,0,-72+sin(angle)*36), "three_living_witnesses", -angle-PI*.5)
		_:
			_boss_dressing(p, id)
	for index in p.size():
		p[index]["id"] = "%s_%s_%02d" % [id, p[index]["region"], index]
		p[index]["story_source"] = story_source(id)
	return p


static func _boss_dressing(p: Array[Dictionary], id: String) -> void:
	match id:
		"level_01_05":
			_pair(p, "MuralWall", Vector3(0,0,-42), 26, PI*.5, "four_watchpoints")
			_pair(p, "WatchBrazier", Vector3(0,0,-64), 25, 0, "keeper_furnace")
			_add(p, "BronzeCauldron", Vector3(0,0,-79), "始烬炉心")
		"level_02_06":
			for z in [-36,-48,-60]:
				_pair(p, "WarBanner", Vector3(0,0,z), 38, 0, "opposed_spectral_stands")
			_pair(p, "ChainAnchor", Vector3(0,0,-48), 29, 0, "war_shackles")
			_pair(p, "Barricade", Vector3(0,0,-34), 37, PI*.5, "battle_spectators")
		"level_03_06":
			for index in 9:
				var angle := TAU * float(index) / 9.0
				_add(p, "WeddingLantern", Vector3(cos(angle)*27,0,-48+sin(angle)*27), "nine_illusion_flowers")
			_add(p, "MemoryMirror", Vector3(0,0,-78), "true_mirror")
			_add(p, "LakeSurface", Vector3(42,-.09,-63), "moon_terrace_lake", 0, false)
		"level_04_04":
			_add(p, "BrokenArch", Vector3(-29,0,-59), "wrath_ruins", .2)
			_add(p, "CelestialSpire", Vector3(-29,0,-77), "shattered_ascetic_city")
			_pair(p, "MuralWall", Vector3(0,0,-68), 24, PI*.5, "fist_scarred_stone")
		"level_04_05":
			_add(p, "RitualDesk", Vector3(24,0,-42), "unchanged_tea_and_last_page")
			_add(p, "ArchiveShelf", Vector3(29,0,-50), "preserved_study", PI*.5)
			_add(p, "Orrery", Vector3(26,0,-76), "repeated_cultivation_ritual")
			_pair(p, "MuralWall", Vector3(0,0,-70), 23, PI*.5, "ordered_chamber")
		"level_04_06":
			_add(p, "CelestialSpire", Vector3(-34,0,-54), "last_heavenly_remnant")
			_add(p, "BrokenArch", Vector3(-37,0,-33), "fallen_zenith")
			_add(p, "Orrery", Vector3(0,0,-81), "sky_ember_focus")
			_add(p, "RitualDesk", Vector3(8,0,-91), "three_voices_testimony")
		"level_05_05":
			_add(p, "Throne", Vector3(0,0,-83), "dragon_binding")
			_pair(p, "ChainAnchor", Vector3(0,0,-60), 32, 0, "nine_forgers_chains")
			_pair(p, "SoulRib", Vector3(0,0,-48), 42, PI*.5, "dying_constellation")
			_add(p, "LivingSealTorchDragon", Vector3(0,0,-91), "last_furnace_choice")
		"level_05_06":
			_add(p, "BellTower", Vector3(0,0,-88), "blind_bell_tower", PI)
			_pair(p, "CryptWall", Vector3(0,0,-61), 23, PI*.5, "listening_prayer_walls")
			_add(p, "MuralWall", Vector3(0,0,-100), "sound_and_silence_prayer")


static func footprint(placement: Dictionary) -> Vector2:
	var part := String(placement["part_id"])
	var size: Vector2 = Vector2(3,4) if part.begins_with("Memorial") else FOOTPRINTS.get(part, Vector2.ZERO)
	var scale: Vector3 = placement.get("scale", Vector3.ONE)
	var yaw := float(placement.get("rotation_y", 0.0))
	return Vector2(absf(cos(yaw))*size.x*scale.x + absf(sin(yaw))*size.y*scale.z,
		absf(sin(yaw))*size.x*scale.x + absf(cos(yaw))*size.y*scale.z)


static func story_anchors(level_id: String) -> Dictionary:
	match level_id:
		"level_01_04":
			return {"keeper_rune": Vector3(43,0,-94)}
		"level_02_03":
			return {"iron_heart_cage": Vector3(-39,0,-58),
				"cage_key_1": Vector3(-33,0,-46), "cage_key_2": Vector3(31,0,-49),
				"cage_key_3": Vector3(37,0,-107)}
		"level_03_02":
			return {"memory_keeper": Vector3(-25,0,-71), "true_memory_1": Vector3(-27,0,-62),
				"true_memory_2": Vector3(-27,0,-70), "true_memory_3": Vector3(-27,0,-78)}
		"level_03_04":
			return {"tea_offering": Vector3(31,0,-77), "tea_soul": Vector3(35,0,-73),
				"bell_tower_entrance": Vector3(34,0,-95)}
		"level_03_05":
			return {"true_mirror": Vector3(-20,0,-143)}
		"level_04_03":
			return {"xuanxiao_record": Vector3(10,12,-131),"xuanxiao_remnant": Vector3(14,12,-131)}
		"level_05_01":
			return {"furnace_memory": Vector3(-20,0,-63)}
		"level_05_02":
			return {"furnace_memory": Vector3(-7,8,-127)}
		"level_05_03":
			return {"furnace_memory": Vector3(43,0,-100), "samsara_replay": Vector3(-42,0,-75)}
		"level_05_04":
			return {"furnace_memory": Vector3(-36,0,-78), "nine_forgers_memorial": Vector3(-31,0,-72),
				"silence_threshold": Vector3(5,0,-125)}
	return {}


static func arena_interaction_anchors(level_id: String) -> Dictionary:
	if level_id == "level_05_06":
		var bells: Array[Vector3] = []
		for index in 12:
			var angle := TAU * float(index) / 12.0
			bells.append(Vector3(cos(angle)*15,0,-48+sin(angle)*15))
		return {"decoy_bells": bells}
	return {}


static func module_anchors(level_id: String) -> Dictionary:
	# Device origins belong to their story rooms. Exits and arena seals retain
	# the geometry provider's measured terminal/arena boundary positions.
	match level_id:
		"level_01_01":
			return {"fragile_floor": Vector3(-42,0,-66)}
		"level_01_02":
			return {"hazard": Vector3(0,0,-108)}
		"level_01_03":
			return {"switch_offering": Vector3(18,0,-111),"mirror_light": Vector3(-18,0,-57)}
		"level_01_04":
			return {"hazard": Vector3(0,0,-72),"poison_fire_zone": Vector3(0,0,-102),
				"valve_shutoff": Vector3(-33,0,-66),"fragile_floor": Vector3(36,0,-102),
				"switch_offering": Vector3(0,0,-132)}
		"level_02_01":
			return {"hazard": Vector3(-24,0,-42),"fragile_floor": Vector3(-36,2,-96)}
		"level_02_02":
			return {"projectile_lane": Vector3(0,10,-84),"hazard": Vector3(36,12,-129)}
		"level_02_03":
			return {"switch_offering": Vector3(30,0,-104),"fragile_floor": Vector3(-36,0,-102)}
		"level_02_04":
			return {"moving_platform": Vector3(-5,6,-60),"switch_offering": Vector3(-15,24,-108),
				"fragile_floor": Vector3(0,12,-24)}
		"level_02_05":
			return {"switch_offering": Vector3(12,0,-60),"projectile_lane": Vector3(-24,0,-109)}
		"level_03_01":
			return {"illusion_marker": Vector3(-24,0,-54),"fragile_floor": Vector3(-48,0,-98)}
		"level_03_02":
			return {"illusion_marker": Vector3(24,0,-124),"switch_offering": Vector3(18,0,-144),
				"memory_verification": Vector3(-18,0,-78),"hazard": Vector3(-12,0,-90)}
		"level_03_03":
			return {"projectile_lane": Vector3(24,0,-54),"illusion_marker": Vector3(-18,0,-117),
				"stealth_passage": Vector3(24,0,-64)}
		"level_03_04":
			return {"moving_platform": Vector3(-18,0,-72),"illusion_marker": Vector3(0,0,-72),
				"switch_offering": Vector3(0,0,-117)}
		"level_03_05":
			return {"illusion_marker": Vector3(0,0,-60),"switch_offering": Vector3(48,0,-132),
				"riddle_gate": Vector3(-18,0,-132)}
		"level_04_01":
			return {"moving_platform": Vector3(18,4,-48),"celestial_dial": Vector3(-7,12,-102),
				"fragile_floor": Vector3(0,16,-120)}
		"level_04_02":
			return {"moving_platform": Vector3(-30,2,-56),"poison_fire_zone": Vector3(-30,2,-70),
				"alchemy_ingredients": Vector3(-30,2,-78),"switch_offering": Vector3(30,4,-122)}
		"level_04_03":
			return {"gravity_visual_zone": Vector3(0,6,-75),"gravity_inversion": Vector3(0,6,-90),
				"hazard": Vector3(6,0,-43),"switch_offering": Vector3(6,12,-139)}
		"level_05_02":
			return {"gravity_anchor": Vector3(-12,4,-72),"gravity_visual_zone": Vector3(-24,0,-42),
				"moving_platform": Vector3(24,4,-72),"switch_offering": Vector3(0,8,-130)}
		"level_05_03":
			return {"illusion_marker": Vector3(-42,0,-87),"switch_offering": Vector3(42,0,-108),
				"gravity_visual_zone": Vector3(0,0,-117)}
		"level_05_04":
			return {"switch_offering": Vector3(-30,0,-47),"soul_forger_trial": Vector3(-30,0,-90)}
	return {}


static func _add(p: Array[Dictionary], part: String, position: Vector3, region: String, yaw := 0.0, collision := true) -> void:
	p.append({"part_id": part, "position": position, "region": region,
		"rotation_y": yaw, "scale": Vector3.ONE, "collision": collision})


static func _pair(p: Array[Dictionary], part: String, center: Vector3, offset: float, yaw: float, region: String) -> void:
	for side in [-1,1]:
		_add(p, part, center + Vector3(side*offset,0,0), region, -side*yaw)
