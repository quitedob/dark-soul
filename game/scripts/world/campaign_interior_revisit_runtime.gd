extends Node3D
## Optional reconnaissance and revisit records. All durable writes belong to
## this level; neither puzzle answers nor canonical story outcomes depend on them.

signal scout_window_changed(visible: bool)
signal revisit_recorded(kind: String, interaction_id: String, position_world: Vector3)

const Interaction = preload("res://scripts/world/campaign_exit_interact.gd")
const Copy = preload("res://scripts/ui/hud_theme.gd")

var world: Node3D
var level_root: Node3D
var rooms: Node3D
var interior: Dictionary = {}
var scout: Dictionary = {}
var scout_copy: Node3D
var interaction_areas: Dictionary = {}
var _records: Dictionary = {}
var _level_id := ""
var _configured := false
var _window_tween: Tween


func setup(owner_world: Node3D, owner_level: Node3D, plan: Dictionary, investigation: Node3D) -> void:
	if _configured or not is_instance_valid(owner_world) or not is_instance_valid(owner_level) or not is_instance_valid(investigation):
		return
	world = owner_world
	level_root = owner_level
	rooms = investigation
	interior = plan.duplicate(true)
	_level_id = String(world.campaign_runtime.current_level_id)
	scout = interior.get("stele_scout_reward", {})
	if not scout.is_empty():
		if String(scout.get("flag", "")) != _level_id + "/stele_scouted" or not _owned_flag(String(scout.get("consumed_flag", ""))):
			push_error("Interior scout rewards require their own level-scoped flags")
			scout = {}
		else:
			scout_copy = level_root.find_child(String(scout.get("node_name", "SteleScoutCopy")), true, false) as Node3D
			if scout_copy != null and String(scout_copy.get_meta("interior_stele_scout_id", "")) != String(interior.get("id", "")):
				push_error("The scout copy belongs to another interior")
				scout_copy = null
	_configured = true
	_set_scout_visible(false)
	for record: Dictionary in interior.get("revisit_interactions", []):
		_build_record(record)
	rooms.progress_changed.connect(_on_progress_changed)
	_on_progress_changed(String(interior.get("id", "")), rooms.completed_stage_count(), rooms.stages.size())


func _owned_flag(flag: String) -> bool:
	return flag.begins_with(_level_id + "/") and flag.length() > _level_id.length() + 1


func _on_progress_changed(_id: String, _count: int, _total: int) -> void:
	if not _current_level() or scout.is_empty():
		return
	if not bool(world.run_state.get_choice_flag(rooms.stage_flag(0, "clue"), false)):
		return
	var scouted_flag := String(scout["flag"])
	if not bool(world.run_state.get_choice_flag(scouted_flag, false)):
		world.run_state.set_choice_flag(scouted_flag, true)
		if not bool(world._save_run("interior_stele_scouted")):
			world.run_state.choice_flags.erase(scouted_flag)
			return
	if not bool(world.run_state.get_choice_flag(rooms.stage_flag(0, "solved"), false)):
		return
	var consumed_flag := String(scout["consumed_flag"])
	if bool(world.run_state.get_choice_flag(consumed_flag, false)) or not is_instance_valid(scout_copy):
		return
	# Reserve before showing the temporary copy: reload or repeated interaction
	# cannot restart its10-second advantage. A failed save grants no window.
	world.run_state.set_choice_flag(consumed_flag, true)
	if not bool(world._save_run("interior_stele_scout_window")):
		world.run_state.choice_flags.erase(consumed_flag)
		return
	_set_scout_visible(true)
	_window_tween = create_tween()
	_window_tween.tween_interval(float(scout.get("duration_seconds", 10.0)))
	_window_tween.tween_callback(_set_scout_visible.bind(false))
	_say(Copy.copy("门 A 已开：右侧书架后的凿痕复制品亮起，十秒后褪去。", "Door A is open: the copied marks behind the right shelf glow for ten seconds."), 5.0)


func _set_scout_visible(value: bool) -> void:
	if not is_instance_valid(scout_copy):
		return
	scout_copy.visible = value
	var light := scout_copy.get_node_or_null("WarmLight") as OmniLight3D
	if light != null:
		light.visible = value
	scout_window_changed.emit(value)


func _build_record(record: Dictionary) -> void:
	var id := String(record.get("id", ""))
	var flag := String(record.get("flag", ""))
	var kind := String(record.get("kind", ""))
	if id.is_empty() or _records.has(id) or not _owned_flag(flag) or kind not in ["ground_relic", "scribe_annotation", "memory_return"]:
		push_error("Interior revisit records need a unique ID, local flag and supported kind")
		return
	var stage := int(record.get("required_stage", -1))
	if stage < -1 or stage >= rooms.stages.size():
		push_error("Interior revisit required_stage must name a solved stage, not a physical floor")
		return
	_records[id] = record.duplicate(true)
	var area := Interaction.new()
	area.name = "InteriorRevisit_" + id.validate_node_name()
	area.collision_layer = 8
	area.collision_mask = 0
	area.monitoring = false
	area.add_to_group("interactable")
	area.add_to_group("campaign_interior_revisit")
	area.set_meta("revisit_id", id)
	area.world_callback = Callable(self, "_use_record")
	area.prompt_text = String(record.get("prompt", Copy.copy("翻检遗留物", "Examine the relic") if kind == "ground_relic" else Copy.copy("留下批注", "Annotate the page") if kind == "scribe_annotation" else Copy.copy("核对归名记录", "Check the returned name")))
	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = .8
	collision.shape = sphere
	collision.position.y = .8
	area.add_child(collision)
	add_child(area)
	area.global_position = level_root.to_global(record["position"])
	interaction_areas[id] = area


func _use_record(area: Node3D, actor: Node) -> void:
	if not _current_level() or not is_instance_valid(area) or area.get_parent() != self or actor != world.player or not is_instance_valid(actor):
		return
	if float(actor.health) <= 0 or actor.global_position.distance_to(area.global_position) > 3.0:
		return
	var id := String(area.get_meta("revisit_id", ""))
	if not _records.has(id) or interaction_areas.get(id) != area:
		return
	var ray := PhysicsRayQueryParameters3D.create(actor.global_position + Vector3.UP * .8, area.global_position + Vector3.UP * .8, 1)
	if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
		return
	var record: Dictionary = _records[id]
	var stage := int(record.get("required_stage", -1))
	if stage >= 0 and not bool(world.run_state.get_choice_flag(rooms.stage_flag(stage, "solved"), false)):
		_say(Copy.copy("相关房间的机关尚未解开，先保留这处痕迹。", "Leave this trace in place until the related room is resolved."))
		return
	for required: String in record.get("prerequisite_flags", []):
		if not bool(world.run_state.get_choice_flag(required, false)):
			_say(Copy.copy("还缺一份可核对的记录；这不是定论。", "Another record is needed for comparison; this is not a conclusion."))
			return
	var alternatives: Array = record.get("any_prerequisite_flags", [])
	if not alternatives.is_empty():
		var found := false
		for required: String in alternatives:
			found = found or bool(world.run_state.get_choice_flag(required, false))
		if not found:
			_say(Copy.copy("此前还没有留下可供对照的批注。", "No earlier annotation has been left for comparison."))
			return
	var flag := String(record["flag"])
	if not bool(world.run_state.get_choice_flag(flag, false)):
		world.run_state.set_choice_flag(flag, true)
		if not bool(world._save_run("interior_revisit_" + String(record["kind"]))):
			world.run_state.choice_flags.erase(flag)
			return
		revisit_recorded.emit(String(record["kind"]), id, actor.global_position)
	_say(String(record.get("text", "")), 8.0)


func _current_level() -> bool:
	return _configured and is_inside_tree() and is_instance_valid(world) and is_instance_valid(level_root) and not level_root.is_queued_for_deletion() and world.campaign_runtime.current_level == level_root


func _say(message: String, seconds: float = 4.0) -> void:
	if is_instance_valid(world.hud):
		world.hud.show_message(message, seconds)


func _exit_tree() -> void:
	if is_instance_valid(scout_copy):
		scout_copy.visible = false
