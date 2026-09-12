extends Node
## Local, event-only playtest evidence. Automated runs never enter human metrics.
var world: Node3D
var level_root: Node3D
var investigation: Node3D
var plan: Dictionary
var events: Array[Dictionary] = []
var _entered: Dictionary = {}
var _read: Dictionary = {}
var _solved: Dictionary = {}
var _elapsed := 0.0
var _session := ""
var _automated := false

func setup(owner_world: Node3D, owner_level: Node3D, interior: Dictionary, rooms: Node3D) -> void:
	world = owner_world
	level_root = owner_level
	plan = interior
	investigation = rooms
	_session = "%s-%s" % [Time.get_unix_time_from_system(), randi()]
	_automated = "--script" in OS.get_cmdline_args() or DisplayServer.get_name() == "headless"
	for index in 3:
		_read[index] = bool(world.run_state.get_choice_flag(rooms.stage_flag(index, "clue"), false))
		_solved[index] = bool(world.run_state.get_choice_flag(rooms.stage_flag(index, "solved"), false))
	rooms.progress_changed.connect(_on_progress)
	world.player.died.connect(_on_death)
	_record("session", {"loaded_solved": rooms.completed_stage_count()})

func _physics_process(delta: float) -> void:
	if not is_instance_valid(world) or not is_instance_valid(world.player): return
	_elapsed += delta
	if world.player.health <= 0: return
	var local := level_root.to_local(world.player.global_position)
	var origin: Vector3 = plan["origin"]
	if absf(local.x - origin.x) > 22 or absf(local.z - origin.z) > 22: return
	var index := int(investigation.completed_stage_count())
	if index >= plan["stages"].size(): return
	var stage: Dictionary = plan["stages"][index]
	if absf(local.y - (stage["clue_position"] as Vector3).y) > 1.5: return
	if not _entered.has(index) and not bool(_solved.get(index, false)):
		_entered[index] = _elapsed
		_record("puzzle_entered", {"floor": int(stage.get("floor", index)) + 1, "stage_id": stage["id"]})

func _on_progress(_id: String, _count: int, _total: int) -> void:
	for index in 3:
		var read_now := bool(world.run_state.get_choice_flag(investigation.stage_flag(index, "clue"), false))
		if read_now and not bool(_read.get(index, false)):
			_record("clue_read", {"floor": int(plan["stages"][index].get("floor", index)) + 1, "stage_id": plan["stages"][index]["id"]})
		_read[index] = read_now
		var solved_now := bool(world.run_state.get_choice_flag(investigation.stage_flag(index, "solved"), false))
		if solved_now and not bool(_solved.get(index, false)):
			_record("puzzle_solved", {"floor": int(plan["stages"][index].get("floor", index)) + 1, "stage_id": plan["stages"][index]["id"],
				"read_clue": read_now, "seconds": _elapsed - float(_entered[index]) if _entered.has(index) else null,
				"entered_observed": _entered.has(index)})
		_solved[index] = solved_now

func _on_death(at: Vector3) -> void:
	if not is_instance_valid(level_root) or world.campaign_runtime.current_level != level_root: return
	var local := level_root.to_local(at)
	var origin: Vector3 = plan["origin"]
	if absf(local.x - origin.x) > 28 or absf(local.z - origin.z) > 28: return
	var floor_index := clampi(roundi((local.y - origin.y) / 6.0), 0, 2)
	_record("death", {"floor": floor_index + 1, "position": [local.x - origin.x, local.y - origin.y, local.z - origin.z],
		"solved_stages": investigation.completed_stage_count(), "first_ascent": investigation.completed_stage_count() < 3})

func record_loop_event(kind: String, details: Dictionary) -> void:
	_record(kind, details)

func _record(kind: String, details: Dictionary) -> void:
	var event := details.duplicate(true)
	event.merge({"schema_version": 1, "session": _session, "level_id": String(level_root.get_meta("level_id", "")),
		"kind": kind, "elapsed_seconds": _elapsed, "source": "automated" if _automated else "interactive",
		"unix_time": Time.get_unix_time_from_system()}, true)
	events.append(event)
	if _automated: return
	var directory := "user://playtests"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var path := directory + "/interior-events.jsonl"
	var file := FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	if file == null: return
	file.seek_end()
	file.store_line(JSON.stringify(event))
	file.close()
