class_name CampaignInteriorSceneStory
extends RefCounted
## Scene evidence is derived after the layout rotates the three responses.
## All positions are level-local metres. This adds no inventory or truth flags.

const VERSION := 2
const MOTIFS := [
	{"shape": "ring", "color": Color("57c6c8"), "mirror_angle": -PI / 6.0},
	{"shape": "triangle", "color": Color("dd865c"), "mirror_angle": PI / 6.0},
	{"shape": "square", "color": Color("b5a0df"), "mirror_angle": PI / 3.0},
]
const OWNERS := {
	"level_01_01": "迟来的守灯人", "level_01_02": "末班守门匠", "level_01_03": "明镜殿的校镜匠", "level_01_04": "停炉前的记药人",
	"level_02_01": "山道担架队的掌簿", "level_02_02": "没有等到交班的哨长", "level_02_03": "被抹去姓名的锻工", "level_02_04": "守至天明的值烽人", "level_02_05": "军图背面的执笔人",
	"level_03_01": "留下第三份路签的旅人", "level_03_02": "借忆簿的保管人", "level_03_03": "空轿旁的送行客", "level_03_04": "水下亭的量影人", "level_03_05": "九转园的验客人",
	"level_04_01": "悬阶的测候人", "level_04_02": "未署验成的记药人", "level_04_03": "保留缺页的抄书人",
	"level_05_01": "岸边的留灯人", "level_05_02": "倒悬殿的修缮人", "level_05_03": "为歧路分墨的执笔人", "level_05_04": "残环前的守碑人",
}
const LEAVES := [
	["旧报：院墙与灯具俱全。\n夹批：裂墙三处，缺灯两盏。", "报给上院的副本写着院墙与灯具俱全，夹页却逐笔列出三处裂墙、两盏缺灯。批注说：若无人记下损处，后来者仍会踏进同一道裂缝。两页署着同一人的名字，墨色却隔了许久。"],
	["军报：当班诸人全数归营。\n点簿：归者十一，未归二十七。", "官报写当班诸人全数归营，夹在背面的点名簿却写归者十一、未归二十七。执笔人没有把官报撕去，只在旁添上：若只准留一页，名字便又要死一次。这份副册没有将军的批示。"],
	["园录：留忆者皆愿永驻。\n寄签：愿寄一夜，明日取回。", "园录把这段记忆列作自愿永驻，原主人的寄签却写愿寄一夜，明日取回。夹页保留了两种记载与同一枚寄存印，没有代原主人改写意愿。这是他人留下的寄签，镜前的阅者只是见证。"],
	["馆录：此卷未曾增删。\n校签：副本删三行，原卷另封。", "馆录写此卷未曾增删，校对签却记着副本删去三行，并附另行封存的原卷借阅号。被删的三行没有抄在这里。夹页只要求把矛盾留下，等真正读到原卷时再核对。"],
	["汇录：来者俱已渡去。\n岸记：仍有人留灯等候。", "汇录写来者俱已渡去，岸边的逐时记录却留着几个未填姓名的等候位置。执笔人划去了汇录中的俱字，又把原字另抄在旁：我不愿替沉默的人宣告离开。夹页没有替任何人选择终点。"],
]


static func decorate(interior: Dictionary, level_id: String) -> Dictionary:
	var result: Dictionary = interior.duplicate(true)
	if int(result.get("scene_story_version", 0)) == VERSION or result.is_empty():
		return result
	var stages: Array = result.get("stages", [])
	if stages.size() != 3:
		push_error("Scene evidence requires three interior stages: " + level_id)
		return result
	var chapter := clampi(int(level_id.substr(6, 2)) - 1, 0, 4)
	var seed := int(level_id.right(2))
	var owners: Array[Dictionary] = []
	var props: Array = result.get("props", [])
	var readables: Array = result.get("scene_readables", [])
	var owner_name := String(OWNERS.get(level_id, "旧屋的看守人"))
	for index in 3:
		var stage: Dictionary = stages[index]
		var correct := int(stage.get("correct_index", -1))
		var controls: Array = stage.get("controls_positions", [])
		if correct not in range(3) or controls.size() != 3:
			push_error("Scene evidence requires the final response order: " + level_id)
			return interior.duplicate(true)
		var option_visuals: Array[Dictionary] = []
		for option in 3:
			var motif: Dictionary = MOTIFS[(option + index + seed) % 3].duplicate(true)
			motif["position"] = controls[option]
			motif["option_index"] = option
			motif["yaw"] = PI if index == 1 else 0.0
			option_visuals.append(motif)
		var answer: Dictionary = option_visuals[correct]
		var clue_position: Vector3 = stage["clue_position"]
		var facing := PI if index == 1 else 0.0
		# Two separately visible links: source through a shaped aperture, then
		# the angled relay to its receiving stone. The receiver repeats a control.
		stage["visual_clue"] = {"position": clue_position, "yaw": facing,
			"mode": ["aperture", "mirror", "split_ray"][index],
			"source": Vector3(-1.22, 1.25, 0.12), "relay": Vector3(0, 1.65, -0.30),
			"receiver": Vector3(1.22, 1.25, 0.12), "cause_links": [["source", "relay"], ["relay", "receiver"]],
			"shape": answer["shape"], "color": answer["color"], "mirror_angle": answer["mirror_angle"],
			"correct_index": correct, "control_position": controls[correct]}
		stage["option_visuals"] = option_visuals
		stage["clue_optional"] = true
		var door: Dictionary = stage["door"]
		var target: Vector3 = door["position"]
		stage["visual_clue"]["target_door"] = target
		var owner_id := String(stage["id"]) + "/owner"
		var room_owner := String(stage["room_name"]) + "值守·" + owner_name
		var owner_at := clue_position + Basis(Vector3.UP, facing) * Vector3(2.25, 0, 0.0)
		# Existing props remain in their supported recesses. Their open face and
		# the owner's hand point toward the next passage, not back downstairs.
		for prop_index in props.size():
			var prop: Dictionary = props[prop_index]
			if not String(prop.get("id", "")).contains("/room_%d/" % index):
				continue
			var at: Vector3 = prop["position"]
			prop["belongs_to"] = room_owner
			prop["dead_owner_pose"] = "slumped_kneeling"
			prop["owner_id"] = owner_id
			prop["looks_toward"] = target
			prop["mechanism_position"] = controls[correct]
			prop["seal_shape"] = answer["shape"]
			var direction := target - at
			prop["rotation_y"] = atan2(-direction.x, -direction.z)
			props[prop_index] = prop
		owners.append({"id": owner_id, "part_id": "KneelingStatue", "position": owner_at,
			"belongs_to": room_owner, "dead_owner_pose": "slumped_kneeling", "looks_toward": target,
			"scale": Vector3.ONE * .53, "pose_lean": .34 if index != 1 else -.26,
			"owned_prop_ids": _owned_ids(props, owner_id), "clue_position": clue_position,
			"story_source": String(result.get("story_source", "docs/story"))})
		stages[index] = stage
	result["stages"] = stages
	result["owners"] = owners
	result["props"] = props
	var top_stage: Dictionary = stages[2]
	var top_door: Dictionary = top_stage["door"]
	result["top_landmark"] = {"id": String(result["id"]) + "/goal_fixture", "position": top_door["position"], "yaw": float(top_door.get("yaw", 0.0)),
		"lintel_center_y": 5.70, "pendant_center_y": 5.40, "isolated_material": true,
		"belongs_to": owner_name, "dead_owner_pose": "slumped_kneeling", "looks_toward": result["reward_position"]}
	var reward: Vector3 = result["reward_position"]
	var leaf: Array = LEAVES[chapter]
	readables.append({"id": String(result["id"]) + "/scribe_leaf", "title": "执笔者的夹页",
		"position": reward + Vector3(3.0, 0, 1.1), "inscription": String(leaf[0]), "text": String(leaf[1]),
		"required_flag": String(result["completion_flag"]), "belongs_to": owner_name,
		"dead_owner_pose": "slumped_kneeling", "looks_toward": reward, "kind": "scribe_leaf"})
	if level_id == "level_04_03":
		_add_foreign_archive(result, readables)
	result["scene_readables"] = readables
	_add_revisit_evidence(result, level_id, chapter, owner_name)
	_add_return_mirror(result, level_id)
	_refresh_owner_links(result)
	_register_object_lore(result)
	result["scene_story_version"] = VERSION
	return result


static func _owned_ids(props: Array, owner_id: String) -> Array[String]:
	var ids: Array[String] = []
	for prop: Dictionary in props:
		if String(prop.get("owner_id", "")) == owner_id:
			ids.append(String(prop["id"]))
	return ids


static func _add_foreign_archive(interior: Dictionary, readables: Array) -> void:
	# Geometry ownership remains with the layout: no guessed off-grid annex.
	var annex: Dictionary = interior.get("archive_annex", {})
	if annex.is_empty():
		push_error("The archive's foreign store requires a reserved archive_annex")
		return
	var center: Vector3 = annex["position"]
	var target: Vector3 = annex.get("entry", center + Vector3(0, 0, 6))
	var id := String(interior["id"]) + "/foreign_store"
	var props: Array = interior["props"]
	for item: Array in [["WarTable", Vector3(0, 0, 0), Vector3(.8, .8, .8)],
		["WarBanner", Vector3(2.5, 0, -1.8), Vector3(.8, .8, .8)]]:
		props.append({"id": id + "/" + String(item[0]), "part_id": String(item[0]), "position": center + (item[1] as Vector3),
			"rotation_y": 0.0, "scale": item[2], "collision": true, "belongs_to": "血铁押运副使与藏经阁收存人",
			"dead_owner_pose": "slumped_kneeling", "looks_toward": target, "owner_id": id + "/owner",
			"story_source": "docs/chapters/02-blood-iron/chapter-overview.md; docs/chapters/04-celestial-fall/chapter-overview.md"})
	interior["props"] = props
	var owners: Array = interior["owners"]
	owners.append({"id": id + "/owner", "part_id": "KneelingStatue", "position": center + Vector3(-2.2, 0, -1),
		"belongs_to": "血铁押运副使与藏经阁收存人", "dead_owner_pose": "slumped_kneeling", "looks_toward": target,
		"scale": Vector3.ONE * .43, "pose_lean": .34, "owned_prop_ids": _owned_ids(props, id + "/owner"), "clue_position": center})
	interior["owners"] = owners
	interior["foreign_store_art"] = {"position": center, "theme": &"theme_blood_iron", "size": Vector3(6, .10, 6)}
	readables.append({"id": id + "/letter", "title": "赤旗后的入库函", "position": center + Vector3(0, 1.22, .1),
		"inscription": "馆录：未收外域兵械。\n收函：血铁封箱，入阁暂存。",
		"text": "馆录说藏经阁未收外域兵械。压在赤旗旧桌上的入库函却写着：血铁封箱十七，随押运副使入阁暂存，箱封不得擅启。函尾只有收存人的私押，没有发令人的名字。两份记录为何相反，函中没有答案。",
		"belongs_to": "血铁押运副使与藏经阁收存人", "dead_owner_pose": "slumped_kneeling", "looks_toward": target,
		"kind": "foreign_letter", "on_existing_table": true})
	# Shelves turn the open side corridor into a gap behind the archive stacks.
	# Their narrow depth faces the corridor; the middle opening stays 3.2 m.
	var across := Vector3(0, 0, 1)
	var shelf_line := center + (target - center).normalized() * 5.7
	for side in [-1, 1]:
		props.append({"id": String(interior["id"]) + "/archive_entry_shelf_%d" % side, "part_id": "ArchiveShelf",
			"position": shelf_line + across * side * 3.0, "rotation_y": PI / 2.0,
			"scale": Vector3(.56, .64, .65), "collision": true, "belongs_to": "藏经阁收存人",
			"dead_owner_pose": "slumped_kneeling", "looks_toward": center, "owner_id": id + "/owner",
			"story_source": "docs/chapters/04-celestial-fall/chapter-overview.md"})
	interior["props"] = props


static func _add_revisit_evidence(interior: Dictionary, level_id: String, chapter: int, owner_name: String) -> void:
	var stage: Dictionary = interior["stages"][0]
	var clue: Vector3 = stage["clue_position"]
	var cue: Dictionary = stage["visual_clue"]
	var owner_id := String(stage["id"]) + "/owner"
	var wall: Dictionary = interior.get("stele_east_wall", {"position": clue + Vector3(5.25, 0, -1.5), "yaw": PI / 2.0})
	interior["stele_east_wall"] = wall
	interior["stele_east_marks"] = {"id": String(interior["id"]) + "/east_marks", "position": wall["position"],
		"yaw": float(wall.get("yaw", PI / 2.0)), "shape": cue["shape"], "color": cue["color"],
		"belongs_to": owner_name, "dead_owner_pose": "hand_holds_lamp_record", "looks_toward": cue["control_position"]}
	var owners: Array = interior["owners"]
	for index in owners.size():
		var owner: Dictionary = owners[index]
		if String(owner["id"]) == owner_id:
			owner["position"] = clue + Vector3(2.7, 0, -1.2)
			owner["hand_target"] = (wall["position"] as Vector3) + Vector3(0, 1.1, 0)
			owner["holds_record"] = true
			owner["fixed_position"] = true
			owners[index] = owner
	interior["owners"] = owners
	var shelf_position := clue + Vector3(4.15, 0, -4.1)
	var copy_position := shelf_position + Vector3(0, 2.30, -.33)
	var props: Array = interior["props"]
	props.append({"id": String(interior["id"]) + "/scout_shelf", "part_id": "ArchiveShelf", "position": shelf_position,
		"rotation_y": PI, "scale": Vector3(.32, .28, .40), "collision": true, "belongs_to": owner_name,
		"dead_owner_pose": "hand_holds_lamp_record", "looks_toward": copy_position, "owner_id": owner_id,
		"story_source": "docs/tasks/enviroment_require.md:107"})
	interior["props"] = props
	interior["stele_scout_reward"] = {"id": String(interior["id"]) + "/stele_scout_reward", "flag": level_id + "/stele_scouted",
		"consumed_flag": level_id + "/stele_scout_window_used", "duration_seconds": 10.0, "stage_index": 0,
		"position": copy_position, "node_name": "SteleScoutCopy", "shape": cue["shape"], "color": cue["color"],
		"belongs_to": owner_name, "dead_owner_pose": "hand_holds_lamp_record", "looks_toward": cue["control_position"]}
	var relic_names := ["守灯纸背的私记", "未交回的押运签", "原主人的寄存绳", "夹在书缝的验页签", "岸边未署名的留灯签"]
	var relic_texts := ["纸背仍留着添油人的指印。正面的值守记录已经读完，背面却写着：我若不在，请把灯转给后来的人。折痕与手中残纸相接。",
		"押运签没有盖收讫印。绳下另绑着工匠自留的姓名，与官簿上的工号并不相同；它一直留在未归还的那一边。",
		"寄存绳上有原主人的结法和领取时限。旁边的镜影再熟悉，也不能让寄存者的名字换成阅者的名字。",
		"验页签留下了未盖章的一格。签尾写着：缺页未见，不能以抄者的猜想充作原文。它没有记下缺失的那段实录。",
		"留灯签没有姓名，只记着一个仍愿等候的位置。你翻过签背，看见那人给后来者留出的一行空白。"]
	var revisit: Array = interior.get("revisit_interactions", [])
	var relic_at := clue + Vector3(-3.2, 0, -2.6)
	revisit.append({"id": level_id + "/ground_relic", "position": relic_at, "title": relic_names[chapter],
		"text": relic_texts[chapter], "inscription": "残纸背面，尚有一行私记。", "kind": "ground_relic",
		"flag": level_id + "/ground_relic_examined", "prerequisite_flags": [], "belongs_to": owner_name,
		"dead_owner_pose": "hand_holds_lamp_record", "looks_toward": clue})
	var reward: Vector3 = interior["reward_position"]
	revisit.append({"id": level_id + "/scribe_annotation", "position": reward + Vector3(-3, 0, 1.1), "title": "并记两种说法",
		"text": "你把官录与夹页的矛盾并列抄下，保留两边的署记。未见原证的地方仍然留白；这段批注可以带到烬海的见证案前再读。",
		"inscription": "官录与夹批，各留其名。", "kind": "scribe_annotation", "flag": level_id + "/scribe_annotation",
		"required_stage": 2, "prerequisite_flags": [String(interior["completion_flag"])], "belongs_to": owner_name,
		"dead_owner_pose": "slumped_kneeling", "looks_toward": reward})
	if chapter == 4:
		var prior_annotations: Array[String] = []
		for previous: String in OWNERS:
			if int(previous.substr(6, 2)) < 5:
				prior_annotations.append(previous + "/scribe_annotation")
		revisit.append({"id": level_id + "/annotation_recall", "position": relic_at + Vector3(0, 0, -2.8), "title": "重读沿途夹批",
			"text": "沿途并记过的官录与私批，在见证案上有了并排的位置。矛盾仍是待核的矛盾，来者不必为了让故事齐整而替陌生人补完结局。",
			"inscription": "旧批在案，见证仍待续写。", "kind": "memory_return", "flag": level_id + "/annotation_recalled",
			"prerequisite_flags": [], "any_prerequisite_flags": prior_annotations, "belongs_to": "烬海见证案的留灯人",
			"dead_owner_pose": "slumped_kneeling", "looks_toward": relic_at})
	interior["revisit_interactions"] = revisit


static func _add_return_mirror(interior: Dictionary, level_id: String) -> void:
	if level_id != "level_03_02":
		return
	var spec: Dictionary = interior.get("return_mirror", {})
	if spec.is_empty():
		push_error("The jade return mirror requires layout-owned return_mirror anchors")
		return
	var props: Array = interior["props"]
	for index in range(props.size() - 1, -1, -1):
		var prop: Dictionary = props[index]
		if String(prop["id"]).contains("/room_2/") and String(prop["part_id"]) == "MemoryMirror":
			var mirror: Dictionary = prop.duplicate(true)
			mirror["position"] = spec["wall_position"]
			mirror["looks_toward"] = spec["looks_toward"]
			mirror["mounted"] = true
			mirror["collision"] = false
			mirror["rotation_y"] = float(spec.get("yaw", PI / 2.0))
			interior["mounted_return_mirror"] = mirror
			props.remove_at(index)
	interior["props"] = props
	interior["empty_mirror_frame"] = {"id": level_id + "/empty_top_mirror", "position": spec["empty_frame_position"],
		"belongs_to": "借忆簿的保管人", "dead_owner_pose": "slumped_kneeling", "looks_toward": spec["wall_position"]}
	var revisit: Array = interior["revisit_interactions"]
	revisit.append({"id": level_id + "/memory_return", "position": (spec["wall_position"] as Vector3) + Vector3(-1.2, 0, 0),
		"title": "守门灯阁的归名镜", "text": "上层留下空框，原镜却挂在已经走过的灯阁。镜边仍是寄存者的旧签，映纹朝向再次上行的石阶。你认回的是那人的署名，不是自己的往世。",
		"kind": "memory_return", "art_kind": "mounted_mirror", "flag": level_id + "/memory_return", "required_stage": 1,
		"prerequisite_flags": [], "belongs_to": "借忆簿的保管人", "dead_owner_pose": "slumped_kneeling", "looks_toward": spec["looks_toward"]})
	interior["revisit_interactions"] = revisit


static func _register_object_lore(interior: Dictionary) -> void:
	var lore: Dictionary = {}
	for prop: Dictionary in interior.get("props", []):
		lore[String(prop["id"])] = {"belongs_to": prop.get("belongs_to", "旧屋的收存人"),
			"dead_owner_pose": prop.get("dead_owner_pose", "slumped_kneeling"), "looks_toward": prop.get("looks_toward", interior["reward_position"]),
			"position": prop["position"], "part_id": prop["part_id"], "mechanism_position": prop.get("mechanism_position", prop.get("looks_toward", interior["reward_position"]))}
		var part := String(prop["part_id"])
		lore[String(prop["id"])]["visible_relation"] = "相位小旗与断杆指向机关罩" if part == "WarTable" else (
			"撕页残边、对应封蜡与朝门的未干笔" if part == "RitualDesk" else "物件朝向与遗留者所属记录相连")
	for collection: String in ["scene_readables", "revisit_interactions", "owners"]:
		for record: Dictionary in interior.get(collection, []):
			lore[String(record["id"])] = record.duplicate(true)
	for key: String in ["stele_scout_reward", "stele_east_marks", "mounted_return_mirror", "empty_mirror_frame", "top_landmark"]:
		var record: Dictionary = interior.get(key, {})
		if not record.is_empty():
			lore[String(record["id"])] = record.duplicate(true)
	interior["object_lore"] = lore


static func _refresh_owner_links(interior: Dictionary) -> void:
	# New shelves and the relocated mirror are authored after the room pass.
	# Resolve ownership once from the final object set, so neither direction
	# retains a partial snapshot or loses the mounted mirror's original ID.
	var objects: Array = interior.get("props", []).duplicate()
	var mirror: Dictionary = interior.get("mounted_return_mirror", {})
	if not mirror.is_empty():
		objects.append(mirror)
	var owners: Array = interior.get("owners", [])
	for index in owners.size():
		var owner: Dictionary = owners[index]
		owner["owned_prop_ids"] = _owned_ids(objects, String(owner["id"]))
		owners[index] = owner
	interior["owners"] = owners
