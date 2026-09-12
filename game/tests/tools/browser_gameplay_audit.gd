extends Node
## Opt-in debug observer attached to the real world by -- --browser-audit --new-run.
## No bridge is installed during normal game startup or in release builds.
## Use an isolated browser context: production level transitions may write its save.
## Commands are JSON strings passed to AshenAudit.command:
## input {actions:["move_forward"],frames:60}; interact {path:optional scanner path};
## approach_boundary {from:"spawn"|"inspection_visit",frames:600}; release_inputs {}.
## sampling {enabled:false|true} controls automatic observation only; completed
## commands still publish immediately, including the sampling command itself.
## level/visit/boss_hit/boss_skill/phase are always labelled inspection. This bridge
## never grants evidence, marks a route visited, or commits a fate directly.

signal audit_physics_step_finished

var _world: Node3D
var _bridge: JavaScriptObject
var _callback: JavaScriptObject
var _elapsed := 0.0
var _busy := false
var _last_command: Dictionary = {}
var _inspection := false
var _held_actions: Array[StringName] = []
var _input_generation := 0
var _inspection_history: Array[Dictionary] = []
var _position_origin := "normal_startup"
var _sampling_enabled := true
var _level_ids: Array[String] = []
var _environment_counts: Dictionary = {"world_count": 0, "directional_count": 0}
var _environment_counts_dirty := true
var _counted_level_instance_id := 0
var _environment_count_refreshes := 0
var _last_publish_cost_usec := 0
var _publish_count := 0
const MAX_INPUT_FRAMES := 900
const SNAPSHOT_INTERVAL_SECONDS := 0.25


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Count completed actor updates, not SceneTree.physics_frame, which is emitted
	# before player polling and would release a one-frame action too early.
	process_physics_priority = 10000
	call_deferred("_boot")


func _physics_process(_delta: float) -> void:
	audit_physics_step_finished.emit()


func _boot() -> void:
	if not OS.has_feature("web") or not OS.is_debug_build():
		push_error("Browser gameplay audit requires a debug Web build.")
		queue_free()
		return
	_world = get_parent() as Node3D
	for data in _world.campaign_runtime.registry.get_levels():
		_level_ids.append(str(data.id))
	# Recount once for a newly loaded level, or when the two observed node types
	# actually change. Dynamic meshes, particles and collision bodies do not
	# invalidate these counts or cause another full world traversal.
	get_tree().node_added.connect(_on_observed_node_changed)
	get_tree().node_removed.connect(_on_observed_node_changed)
	JavaScriptBridge.eval("window.AshenAudit = {snapshot: '{}'};", true)
	_bridge = JavaScriptBridge.get_interface("AshenAudit")
	_callback = JavaScriptBridge.create_callback(_receive)
	_bridge.set("command", _callback)
	await get_tree().process_frame
	_publish()


func _process(delta: float) -> void:
	if not _sampling_enabled:
		return
	_elapsed += delta / maxf(Engine.time_scale, 0.1)
	if _elapsed >= SNAPSHOT_INTERVAL_SECONDS and is_instance_valid(_world) and _bridge != null:
		_elapsed = 0.0
		_publish()


func _receive(args: Array) -> void:
	if args.is_empty():
		return
	var command = JSON.parse_string(str(args[0]))
	if command is Dictionary:
		# Cancellation must work while an input command is awaiting physics frames.
		if String(command.get("op", "")) == "release_inputs":
			_input_generation += 1
			_release_inputs()
			return
		if _busy:
			return
		_busy = true
		call_deferred("_execute", command)


func _execute(command: Dictionary) -> void:
	var player = _world.player
	var operation := str(command.get("op", ""))
	var success := true
	var evidence: Dictionary = {"kind": "observation_control"}
	match operation:
		"sampling":
			var enabled: Variant = command.get("enabled", true)
			if enabled is bool:
				_sampling_enabled = enabled
				_elapsed = 0.0
				evidence["enabled"] = _sampling_enabled
			else:
				success = false
				evidence["reason"] = "Sampling enabled must be a boolean."
		"level":
			_release_inputs()
			evidence = _mark_inspection(operation, "Direct level load; not an earned transition or route traversal.")
			evidence["requested_level"] = String(command.get("id", ""))
			# Inspection may follow the real ending modal; close it through its
			# public UI API before loading another independent test scenario.
			if _world._fate_overlay != null and _world._fate_overlay.is_open():
				_world._fate_overlay.close()
			player._set_lock_target(null)
			success = _world._load_campaign_level(StringName(command.get("id", "")))
			_position_origin = "inspection_level_spawn"
			_inspection = bool(command.get("inspection", true))
			player.rotation = Vector3.ZERO
			player.camera_rig.rotation = Vector3.ZERO
			player.camera_pitch.rotation.x = -0.2
			player.spring_arm.spring_length = 5.2
			if _inspection:
				# Run real gravity and animation first: immediate freezing captures
				# airborne spawn offsets and the imported rest pose as false defects.
				await get_tree().create_timer(1.5).timeout
			_freeze_enemies(_inspection)
		"inspection":
			evidence = _mark_inspection(operation, "Enemy process freeze control; frozen actors are not live AI evidence.")
			_inspection = bool(command.get("enabled", true))
			_freeze_enemies(_inspection)
		"visit":
			# Explicit inspection positioning; route traversal is tested separately.
			evidence = _mark_inspection(operation, "Direct position visit; not traversal evidence.")
			var point: Array = command.get("position", [])
			evidence["requested_position"] = point
			if _valid_point(point):
				player.global_position = Vector3(float(point[0]), float(point[1]), float(point[2]))
				player.velocity = Vector3.ZERO
				_position_origin = "inspection_visit"
			else:
				success = false
		"input":
			evidence = await _hold_input(command)
			success = bool(evidence.get("success", false))
		"interact":
			evidence = await _interact_nearby(command)
			success = bool(evidence.get("success", false))
		"approach_boundary":
			evidence = await _approach_boundary(command)
			success = bool(evidence.get("success", false))
		"time_scale":
			# Slow real playback for frame-by-frame weapon review; never seek poses.
			Engine.time_scale = clampf(float(command.get("value", 1.0)), 0.1, 1.0)
		"camera":
			player._set_lock_target(null)
			player._camera_recover_timer = 0.0
			player.camera_rig.rotation.y = float(command.get("yaw", 0.0))
			player.camera_pitch.rotation.x = float(command.get("pitch", -0.2))
			player._camera_recenter_timer = 10.0
		"lock":
			var enemies := get_tree().get_nodes_in_group("enemies")
			var index := int(command.get("index", 0))
			if index >= 0 and index < enemies.size():
				player._set_lock_target(enemies[index])
			else:
				success = false
		"unlock":
			player._set_lock_target(null)
		"phase":
			evidence = _mark_inspection(operation, "Direct lighting preview; not a boss phase event.")
			_world._phase_environment.apply_lighting_key(str(command.get("key", "deep_crimson_darkness")), 0.0)
		"boss_hit":
			evidence = _mark_inspection(operation, "Injected damage through production receive_hit; not a player attack.")
			if _boss_action_allowed():
				var boss = _world.guardian
				evidence["health_before"] = boss.health
				boss.receive_hit(boss.max_health * clampf(float(command.get("fraction", 0.4)), 0.0, 2.0), 0.0, Vector3.FORWARD, player)
				evidence["health_after"] = boss.health
			else:
				success = false
				evidence["reason"] = "Boss damage requires an active boundary containing the living player."
		"boss_skill":
			evidence = _mark_inspection(operation, "Selected real attack profile; not an autonomous AI decision.")
			evidence["requested_attack"] = String(command.get("name", ""))
			success = false
			if _boss_action_allowed():
				var boss = _world.guardian
				for phase: Dictionary in boss.chapter_content.get("phases", {}).values():
					for attack: Dictionary in phase.get("attacks", []):
						if String(attack.get("name", "")) != String(command.get("name", "")):
							continue
						boss.process_mode = Node.PROCESS_MODE_INHERIT
						boss._active_attack_profile = attack.duplicate(true)
						boss._resolve_attack_data_or_dict(attack, &"browser_selected_boss_skill")
						boss._change_state(boss.State.WINDUP, boss.attack_windup)
						success = true
						break
					if success:
						break
			if not success:
				evidence["reason"] = "Boundary inactive, player outside/dead, or attack name unavailable."
		"respawn":
			player._die()
			await get_tree().create_timer(2.6).timeout
		_:
			success = false
	# Transform propagation, SpringArm physics and deferred navigation must finish.
	for index in range(8):
		await get_tree().physics_frame
	_last_command = {"op": operation, "id": command.get("id", ""), "token": command.get("token", ""), "success": success, "evidence": evidence}
	_busy = false
	_publish()


func _freeze_enemies(enabled: bool) -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.process_mode = Node.PROCESS_MODE_DISABLED if enabled else Node.PROCESS_MODE_INHERIT


func _publish() -> void:
	var started_usec := Time.get_ticks_usec()
	var snapshot: Dictionary = _json_value(_snapshot())
	_publish_count += 1
	# Current collection/conversion cost can be included without serializing the
	# entire payload twice. Total cost (including JSON and the JS bridge) belongs
	# to the preceding publication and is labelled accordingly.
	snapshot["audit_performance"] = {
		"snapshot_cost_usec": Time.get_ticks_usec() - started_usec,
		"snapshot_cost_scope": "collection_and_json_value_conversion",
		"previous_publish_cost_usec": _last_publish_cost_usec,
		"sampled_at_usec": started_usec,
		"publish_count": _publish_count,
		"sampling_enabled": _sampling_enabled,
		"sampling_interval_seconds": SNAPSHOT_INTERVAL_SECONDS,
		"environment_count_refreshes": _environment_count_refreshes,
		"world_count": _environment_counts["world_count"],
		"directional_count": _environment_counts["directional_count"],
	}
	_bridge.set("snapshot", JSON.stringify(snapshot))
	_last_publish_cost_usec = Time.get_ticks_usec() - started_usec


func _snapshot() -> Dictionary:
	var player = _world.player
	var camera: Camera3D = player.camera
	var level: Node3D = _world.campaign_runtime.current_level
	_refresh_environment_counts(level)
	var level_data: Dictionary = _world.campaign_runtime.get_level_data()
	var nav := level.get_node_or_null("NavigationSurface") as NavigationRegion3D
	var env: Environment = _world.world_environment.environment
	var ground_query := PhysicsRayQueryParameters3D.create(player.global_position + player.up_direction * 0.5, player.global_position - player.up_direction * 3.0, 1)
	var ground := _world.get_world_3d().direct_space_state.intersect_ray(ground_query)
	var blockers: Array[String] = []
	var enemy_states: Array[Dictionary] = []
	for node in get_tree().get_nodes_in_group("enemies"):
		blockers.append(str(node.name))
		if node is CharacterBody3D:
			var assignment: Dictionary = node.get_meta("encounter_assignment", {})
			enemy_states.append({"name": str(node.name), "position": _v3(node.global_position),
				"velocity": _v3(node.velocity), "on_floor": node.is_on_floor(), "content_id": node.content_id,
				"role": assignment.get("role", "boss" if node.guardian else "unassigned"),
				"group_id": assignment.get("group_id", ""), "activation": assignment.get("activation", ""),
				"patrol_points": assignment.get("patrol_points", []), "state": node.state,
				"health": node.health, "process_mode": node.process_mode, "story_source": assignment.get("story_source", "")})
	var level_props: Array[Dictionary] = []
	for prop in get_tree().get_nodes_in_group("campaign_level_props"):
		level_props.append({"name": str(prop.name), "level": str(prop.get_meta("level_id", "")), "position": _v3(prop.global_position)})
	var target: Variant = player.lock_target
	var target_screen: Variant = null
	if is_instance_valid(target):
		var point: Vector3 = target.get_target_point() if target.has_method("get_target_point") else target.global_position
		target_screen = _v2(camera.unproject_position(point))
	var boss_state: Dictionary = {}
	if is_instance_valid(_world.guardian):
		var boss = _world.guardian
		boss_state = {"id": String(boss.chapter_content.get("id", "")), "health": boss.health,
			"max_health": boss.max_health, "phase": boss._current_phase(), "state": boss.state,
			"attack": boss._active_attack_profile.get("name", ""), "position": _v3(boss.global_position)}
	var arena_state: Dictionary = _world._arena_director.get_arena_state() if is_instance_valid(_world._arena_director) else {}
	for effect: Dictionary in arena_state.get("effects", []):
		if effect.get("position") is Vector3:
			effect["position"] = _v3(effect["position"])
	return {
		"audit_provenance": {"position_origin": _position_origin, "inspection_history": _inspection_history,
			"held_actions": _held_actions, "physics_frame": Engine.get_physics_frames(),
			"note": "Direct level/visit/damage/skill previews are inspection only. Inputs and interactions use production handling; inspect resulting state for success."},
		"campaign_story": _story_snapshot(level), "evidence": _evidence_snapshot(),
		"field_mechanisms": level.get_node("StoryMechanisms").snapshot() if level.has_node("StoryMechanisms") else {},
		"interaction": _interaction_snapshot(), "boundary": _boundary_snapshot(),
		"boss_story": _boss_story_snapshot(), "saved_fates": _saved_fates(),
		"exit_position": _v3(_world.campaign_runtime.get_exit_marker().global_position),
		"boss": boss_state, "arena": arena_state,
		"navigation_revision": int(nav.get_meta("geometry_revision", 0)) if nav != null else 0,
		"level": str(_world.campaign_runtime.current_level_id),
		"levels": _level_ids,
		"topology": str(level_data.get("topology", "")),
		"theme": str(level_data.get("theme_id", "")),
		"paused": get_tree().paused, "busy": _busy, "last_command": _last_command,
		"time_scale": Engine.time_scale,
		"max_fps": Engine.max_fps,
		"equipment": {"class_id": player.get_active_class_id(), "combat_style": player.combat_style, "action_id": player.attack_action_id, "right_hand": player.right_hand_item,
			"slots": player.get_weapon_quickslots(), "open": _world.hud.is_equipment_open(), "error": player.get_weapon_loadout_error()},
		"combat": {"state_time": player.state_time, "stamina": player.stamina, "chain_index": player._combo_chain_index, "hitbox_active": player.combat_area.active, "weapon_grip": _v3(player.weapon_pivot.global_position), "weapon_tip": _v3(player.weapon_pivot.to_global(player._visuals._weapon_tip_local)), "animation_position": player._anim_bridge._playback.get_current_play_position() if player._anim_bridge != null and player._anim_bridge.enabled else -1.0},
		"inspection_enemies_frozen": _inspection,
		"player": {"position": _v3(player.global_position), "up_direction": _v3(player.up_direction), "yaw": player.rotation.y, "state": player.state, "health": player.health, "on_floor": player.is_on_floor()},
		"camera": {"position": _v3(camera.global_position), "rig": _v3(player.camera_rig.global_position), "pitch": player.camera_pitch.rotation.x, "yaw": player.camera_rig.rotation.y, "boom": player.spring_arm.spring_length, "hit_length": player.spring_arm.get_hit_length(), "forward": _v3(-camera.global_basis.z), "feet_screen": _v2(camera.unproject_position(player.global_position)), "head_screen": _v2(camera.unproject_position(player.global_position + player.up_direction * 2.0)), "target_screen": target_screen},
		"environment": {"background": env.background_color.to_html(), "ambient": env.ambient_light_color.to_html(), "fog": env.fog_light_color.to_html(), "phase": _world._phase_environment.active_key, "world_count": _environment_counts["world_count"], "directional_count": _environment_counts["directional_count"], "legacy_nav_helper": _world.has_node("NavRegion"), "navigation_polygons": nav.navigation_mesh.get_polygon_count() if nav != null else -1},
		"ground": str(ground.collider.get_path()) if not ground.is_empty() else "",
		"enemies": blockers,
		"enemy_states": enemy_states,
		"level_props": level_props,
		"fps": Engine.get_frames_per_second(),
		"hud": {"root_size": _v2(_world.hud.root.size), "ember_position": _v2(_world.hud.ember_panel.global_position), "ember_size": _v2(_world.hud.ember_panel.size)},
		"viewport": _v2(get_viewport().get_visible_rect().size),
	}


func _on_observed_node_changed(node: Node) -> void:
	if node is WorldEnvironment or node is DirectionalLight3D:
		_environment_counts_dirty = true


func _refresh_environment_counts(level: Node3D) -> void:
	var level_instance_id := level.get_instance_id()
	if not _environment_counts_dirty and _counted_level_instance_id == level_instance_id:
		return
	_environment_counts = {"world_count": 0, "directional_count": 0}
	_count_environment_nodes(_world)
	_counted_level_instance_id = level_instance_id
	_environment_counts_dirty = false
	_environment_count_refreshes += 1


func _count_environment_nodes(node: Node) -> void:
	if node is WorldEnvironment:
		_environment_counts["world_count"] += 1
	elif node is DirectionalLight3D:
		_environment_counts["directional_count"] += 1
	for child: Node in node.get_children():
		_count_environment_nodes(child)


func _mark_inspection(operation: String, note: String) -> Dictionary:
	var record := {"op": operation, "kind": "inspection", "note": note,
		"level_before": String(_world.campaign_runtime.current_level_id), "frame": Engine.get_physics_frames()}
	_inspection_history.append(record.duplicate())
	if _inspection_history.size() > 32:
		_inspection_history.pop_front()
	return record


func _valid_point(point: Array) -> bool:
	if point.size() != 3:
		return false
	for value: Variant in point:
		if not (value is float or value is int) or not is_finite(float(value)):
			return false
	return true


func _set_input(action: StringName, strength: float) -> void:
	# parse_input_event supplies both real action polling and normal input events.
	# Never write actor velocity or call locomotion/attack handlers here.
	var event := InputEventAction.new()
	event.action = action
	event.pressed = strength > 0.0
	event.strength = clampf(strength, 0.0, 1.0)
	Input.parse_input_event(event)
	if event.pressed and action not in _held_actions:
		_held_actions.append(action)
	elif not event.pressed:
		_held_actions.erase(action)


func _release_inputs() -> void:
	for action: StringName in _held_actions.duplicate():
		_set_input(action, 0.0)


func _hold_input(command: Dictionary) -> Dictionary:
	var actions: Variant = command.get("actions", [])
	var frames := int(command.get("frames", 1))
	var report := {"kind": "real_input", "success": false, "frames_requested": frames,
		"frames_held": 0, "position_before": _v3(_world.player.global_position), "origin": _position_origin,
		"enemies_frozen": _inspection, "paused_before": get_tree().paused}
	if not actions is Array or actions.is_empty() or frames < 1 or frames > MAX_INPUT_FRAMES:
		report["reason"] = "Use nonempty actions and 1–900 physics frames."
		return report
	var names: Array[StringName] = []
	for value: Variant in actions:
		if not (value is String) or not InputMap.has_action(StringName(value)):
			report["reason"] = "Unknown InputMap action: " + str(value)
			return report
		if StringName(value) not in names:
			names.append(StringName(value))
	_release_inputs()
	var generation := _input_generation
	for action in names:
		_set_input(action, 1.0)
	for index in frames:
		await audit_physics_step_finished
		report["frames_held"] = index + 1
		if generation != _input_generation:
			break
	_release_inputs()
	report["actions"] = names
	report["released"] = true
	report["position_after"] = _v3(_world.player.global_position)
	report["success"] = int(report["frames_held"]) == frames
	return report


func _interact_nearby(command: Dictionary) -> Dictionary:
	var report := {"kind": "production_interaction_dispatch", "success": false}
	if get_tree().paused or float(_world.player.health) <= 0.0:
		report["reason"] = "Player must be alive and gameplay unpaused."
		return report
	# Refresh only the production scanner. A supplied path cannot select a distant
	# object, replace the scanner target, or bypass a prop's own reach validation.
	_world._update_interaction_target()
	var target: Node = _world.player.interaction_target
	if not is_instance_valid(target) or not target is Area3D or not target.has_method("interact"):
		report["reason"] = "No nearby production interaction target."
		return report
	var expected := String(command.get("path", ""))
	if not expected.is_empty() and expected != String(target.get_path()):
		report["reason"] = "Requested path is not the actual scanner target."
		report["actual_target"] = String(target.get_path())
		return report
	var distance: float = _world.player.global_position.distance_to(target.global_position)
	if target not in _world.interaction_candidates or not target.monitorable or distance >= 3.0:
		report["reason"] = "Target failed production candidate, monitorable or 3 m scanner reach check."
		return report
	report["target"] = String(target.get_path())
	report["distance"] = distance
	report["prompt"] = target.get_prompt() if target.has_method("get_prompt") else ""
	report["input"] = await _hold_input({"actions": ["interact"], "frames": 1})
	report["success"] = bool(report["input"]["success"])
	report["note"] = "Dispatch accepted; inventory/events/fates show whether the interaction's own conditions accepted it."
	return report


func _boss_action_allowed() -> bool:
	var boundary = _world._boss_boundary
	return is_instance_valid(_world.guardian) and float(_world.guardian.health) > 0.0 \
		and float(_world.player.health) > 0.0 and is_instance_valid(boundary) \
		and boundary.combat_is_active() and boundary.contains_actor(_world.player, 0.0)


func _approach_boundary(command: Dictionary) -> Dictionary:
	var boundary = _world._boss_boundary
	var player = _world.player
	var report := {"kind": "real_input_boundary_approach", "success": false,
		"origin": _position_origin, "position_before": _v3(player.global_position), "frames_held": 0,
		"enemies_frozen": _inspection}
	if not is_instance_valid(boundary) or get_tree().paused or float(player.health) <= 0.0:
		report["reason"] = "Requires a living player, boss boundary and unpaused gameplay."
		return report
	var from := String(command.get("from", "spawn"))
	if from == "spawn":
		var spawn: Node3D = _world.campaign_runtime.get_spawn_marker()
		if not is_instance_valid(spawn) or player.global_position.distance_to(spawn.global_position) > 6.0:
			report["reason"] = "Player is not at the real spawn; no automatic teleport performed."
			return report
	elif from != "inspection_visit" or _position_origin != "inspection_visit":
		report["reason"] = "Use from:spawn or an explicitly labelled visit followed by from:inspection_visit."
		return report
	var frames := int(command.get("frames", 600))
	if frames < 1 or frames > MAX_INPUT_FRAMES:
		report["reason"] = "Approach frame limit is 1–900."
		return report
	_release_inputs()
	player._set_lock_target(null)
	var generation := _input_generation
	for index in frames:
		if boundary.combat_is_active() or generation != _input_generation or float(player.health) <= 0.0 or get_tree().paused:
			break
		var direction: Vector3 = boundary.center - player.global_position
		direction.y = 0.0
		# Stop just inside the normal admission threshold. Failure to admit is
		# observable; do not walk through the boss or grant missing evidence.
		if direction.length() <= float(boundary.radius) - 2.5:
			break
		direction = direction.normalized()
		var forward: Vector3 = -player.camera.global_basis.z
		forward.y = 0.0
		forward = forward.normalized()
		var right: Vector3 = player.camera.global_basis.x
		right.y = 0.0
		right = right.normalized()
		var horizontal := direction.dot(right)
		var vertical := direction.dot(forward)
		_set_input(&"move_right", maxf(0.0, horizontal))
		_set_input(&"move_left", maxf(0.0, -horizontal))
		_set_input(&"move_forward", maxf(0.0, vertical))
		_set_input(&"move_back", maxf(0.0, -vertical))
		await audit_physics_step_finished
		report["frames_held"] = index + 1
	_release_inputs()
	await get_tree().physics_frame
	report["released"] = true
	report["position_after"] = _v3(player.global_position)
	report["boundary_after"] = _boundary_snapshot()
	report["success"] = boundary.combat_is_active()
	if not report["success"]:
		report["reason"] = "Admission denied, approach obstructed, cancelled, or frame limit reached; inspect boundary and position."
	return report


func _story_snapshot(level: Node3D) -> Dictionary:
	var root := level.get_node_or_null("CampaignStoryProps")
	var anchors: Array[Dictionary] = []
	var counts: Dictionary = {}
	if root != null:
		for child: Node in root.get_children():
			if not child is Node3D or not child.has_meta("story_prop_id"):
				continue
			var part := String(child.get_meta("story_part_id", ""))
			counts[part] = int(counts.get(part, 0)) + 1
			var placement: Dictionary = child.get_meta("story_placement", {})
			anchors.append({"id": child.get_meta("story_prop_id"), "part_id": part,
				"path": String(child.get_path()), "position": child.global_position,
				"asset": child.get_meta("story_asset_path", ""), "mesh_bounds": child.get_meta("story_mesh_bounds", AABB()),
				"story_source": placement.get("story_source", ""), "region": placement.get("region", "")})
	return {"present": root != null, "part_counts": counts, "anchor_count": anchors.size(), "anchors": anchors}


func _evidence_snapshot() -> Dictionary:
	var clues: Array[Dictionary] = []
	for node in get_tree().get_nodes_in_group("campaign_story_evidence"):
		if node is Node3D and not node.is_queued_for_deletion():
			clues.append({"id": String(node.memory_key), "path": String(node.get_path()),
				"position": node.global_position, "prompt": node.get_prompt(),
				"story_source": node.get_meta("story_source", "")})
	return {"available": clues, "inventory": _world.run_state.inventory.duplicate(true),
		"collected_loot": _world.run_state.collected_loot.duplicate(), "source": "actual live run state; no audit item grants"}


func _interaction_snapshot() -> Dictionary:
	var candidates: Array[Dictionary] = []
	var selected: Node = _world.player.interaction_target
	for area in _world.interaction_candidates:
		if not is_instance_valid(area) or not area is Area3D:
			continue
		var distance: float = _world.player.global_position.distance_to(area.global_position)
		candidates.append({"path": String(area.get_path()), "position": area.global_position,
			"distance": distance, "monitorable": area.monitorable, "selected": area == selected,
			"prompt": area.get_prompt() if area.has_method("get_prompt") else ""})
	return {"selected": String(selected.get_path()) if is_instance_valid(selected) else "", "candidates": candidates}


func _boundary_snapshot() -> Dictionary:
	var boundary = _world._boss_boundary
	if not is_instance_valid(boundary):
		return {}
	var states := ["WAITING", "ACTIVE", "RESOLVING", "CLEARED"]
	return {"state": states[int(boundary.state)], "active": boundary.combat_is_active(),
		"profile": boundary.boundary_profile, "center": boundary.center, "radius": boundary.radius,
		"contains_player": boundary.contains_actor(_world.player), "admission_count": boundary.admission_count,
		"generation": boundary.generation,
		"admission_allowed": bool(boundary.admission_check.call()) if boundary.admission_check.is_valid() else true}


func _boss_story_snapshot() -> Dictionary:
	var director = _world._arena_director
	if not is_instance_valid(director) or not is_instance_valid(director.story_props):
		return {}
	var story = director.story_props
	var props: Array[Dictionary] = []
	for prop in story.props:
		if not is_instance_valid(prop):
			continue
		props.append({"role": prop.role, "part_id": prop.part_id, "path": String(prop.get_path()),
			"position": prop.global_position, "durability": prop.durability, "hits": prop.hits,
			"enabled": prop.enabled, "broken": prop.is_broken, "visible": prop.visible,
			"can_reach": prop.can_reach(_world.player), "action": prop.get_meta("boss_scene_action", {}),
			"interaction_path": String(prop.interaction.get_path()) if is_instance_valid(prop.interaction) else "",
			"prompt": prop.interaction.get_prompt() if is_instance_valid(prop.interaction) else ""})
	var escape: Dictionary = {}
	if is_instance_valid(story.escape_course):
		var course = story.escape_course
		var platforms: Array[Dictionary] = []
		for pad in course.platforms:
			platforms.append({"index": pad.get_meta("course_index"), "position": pad.global_position,
				"visible": pad.visible, "has_bridge": pad.has_meta("bridge")})
		escape = {"active": course.active, "remaining": course.remaining, "checkpoint": course.checkpoint,
			"goal": course.goal, "visited": course.visited.duplicate(), "warned": course.warned.duplicate(),
			"collapsed": course.collapsed.duplicate(), "retries": course.retries, "platforms": platforms}
	return {"boss_id": story.boss_id, "phase": story.phase, "combat_active": story.combat_active,
		"props": props, "events": story.events.duplicate(true), "judgement_flag": String(story.judgement_flag),
		"aftermath_active": story.aftermath_active, "aftermath_completed": story.aftermath_completed, "escape": escape}


func _saved_fates() -> Dictionary:
	return {"source": "live persistent run model; disk reload is a separate verification",
		"choice_flags": _world.run_state.choice_flags.duplicate(true),
		"defeated_bosses": _world.run_state.defeated_bosses.duplicate(),
		"completed_levels": _world.run_state.completed_levels.duplicate()}


func _json_value(value: Variant) -> Variant:
	if value is Vector3:
		return _v3(value)
	if value is Vector2:
		return _v2(value)
	if value is AABB:
		return {"position": _v3(value.position), "size": _v3(value.size)}
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value:
			result[str(key)] = _json_value(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value:
			result.append(_json_value(item))
		return result
	return value


func _exit_tree() -> void:
	_input_generation += 1
	_release_inputs()


func _v3(value: Vector3) -> Array:
	return [snappedf(value.x, 0.001), snappedf(value.y, 0.001), snappedf(value.z, 0.001)]


func _v2(value: Vector2) -> Array:
	return [snappedf(value.x, 0.1), snappedf(value.y, 0.1)]
