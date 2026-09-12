extends SceneTree
## Actual PlayerScene: equipment changes combat resources while preserving the
## selected body/class, physical hit windows, and JSON/bridge save identity.

const PlayerScene = preload("res://scenes/actors/player.tscn")
const InputConfig = preload("res://scripts/core/input_config.gd")
const RunState = preload("res://scripts/core/run_state.gd")
const Equipment = preload("res://scripts/data/hand_equipment.gd")
const Loadout = preload("res://scripts/player/weapon_loadout.gd")

class FixtureWorld extends Node3D:
	var run_state = RunState.new()

class DiagnosticHud extends Node:
	var diagnostic := ""
	func set_input_buffer_debug(text: String) -> void:
		diagnostic = text

var _failures: Array[String] = []
var _checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	InputConfig.configure_inputs()
	var world := FixtureWorld.new()
	root.add_child(world)
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(100.0, 0.5, 100.0)
	shape.shape = box
	shape.position.y = -0.25
	floor_body.add_child(shape)
	world.add_child(floor_body)
	var player = PlayerScene.instantiate()
	player.setup(world, null, null)
	world.add_child(player)
	player.set_process_unhandled_input(false)
	player.max_stamina = 1000.0
	player.stamina = 1000.0
	await _frames(20)
	_expect(player.is_on_floor(), "fixture: real player must settle on physical floor")
	_expect(player.get_active_class_id().is_empty(), "fixture: starting Manny class remains blank")
	var identity := _identity(player)
	var initial_stats := Vector3(player.max_health, player.max_stamina, player.max_focus)
	_expect(player.get_weapon_quickslots().size() == 3, "three right-hand slots are presented")
	_expect(player.get_available_right_weapons().size() == 3, "three modeled starter weapons are available")
	var mesh_signatures: Array[String] = []
	var damages: Array[float] = []
	for slot in 3:
		var camera_before: Transform3D = player.camera.transform
		_expect(player.try_select_weapon_slot(slot), "select starter slot %d" % slot)
		_expect(player.camera.transform.is_equal_approx(camera_before), "selecting equipment leaves camera pose untouched")
		_check_identity(player, identity, "starter %d" % slot)
		_expect(Vector3(player.max_health, player.max_stamina, player.max_focus) == initial_stats,
			"weapon selection must not change class/stat bonuses")
		var meshes: Array[String] = []
		_mesh_paths(player.weapon_pivot, meshes)
		_expect(not meshes.is_empty(), "starter %d has imported visible meshes" % slot)
		mesh_signatures.append("|".join(meshes))
		var result := await _attack(player, false)
		damages.append(float(result.get("damage", 0.0)))
		_expect(result.get("item_id", "") == Loadout.STARTER_WEAPONS[slot],
			"physical hit payload must identify selected starter %d" % slot)
		_expect(float(result.get("sweep", 0.0)) > 0.2, "starter %d body drives a meaningful wrist sweep" % slot)
	_expect(mesh_signatures[0] != mesh_signatures[1] and mesh_signatures[1] != mesh_signatures[2]
		and mesh_signatures[0] != mesh_signatures[2], "three starters use distinct imported model meshes")
	_expect(damages[0] != damages[1] and damages[0] != damages[2] and damages[1] != damages[2],
		"three starters produce distinct physical damage, not just different meshes")

	# Greatsword K uses its charged-heavy data, F uses its own leap timings.
	var heavy := await _attack(player, true)
	_expect(float(heavy.get("damage", 0.0)) > damages[2], "greatsword heavy is stronger than its light")
	await _test_art(player, "greatsword")
	_expect(player.try_select_weapon_slot(1), "select axe for its weapon art")
	await _test_art(player, "axe")

	# Real X event cycles equipment; the style/class controls remain independent.
	var cycle_key := InputEventKey.new()
	cycle_key.physical_keycode = KEY_X
	cycle_key.pressed = true
	Input.parse_input_event(cycle_key)
	await _frames(2)
	cycle_key = InputEventKey.new()
	cycle_key.physical_keycode = KEY_X
	cycle_key.pressed = false
	Input.parse_input_event(cycle_key)
	_expect(player.right_hand_item == "class_greatsword", "X cycles axe to greatsword")
	_check_identity(player, identity, "X")

	var before: Array = player.get_weapon_quickslots()
	_expect(not player.try_select_weapon_slot(-1), "negative slot rejected")
	_expect(not player.try_select_weapon_slot(3), "fourth slot rejected")
	_expect(not player.try_assign_weapon_slot(0, "class_spear"), "unmodeled weapon excluded")
	_expect(not player.try_assign_weapon_slot(0, "marksman_bow"), "bow excluded until usable draw/release pose exists")
	_expect(not player.try_assign_weapon_slot(0, "class_axe"), "unowned weapon rejected")
	_expect(not player.get_weapon_loadout_error().is_empty(), "rejection has public presentation reason")
	_expect(player.get_weapon_quickslots() == before, "rejections leave all slots unchanged")
	world.run_state.inventory["class_axe"] = 1
	_expect(player.get_available_right_weapons().size() == 4, "newly acquired supported weapon appears without reload")
	_expect(player.try_assign_weapon_slot(0, "class_axe"), "acquired weapon may be assigned")
	_expect(player.right_hand_item == "class_greatsword", "assigning inactive slot keeps current weapon")
	_expect(player.try_select_weapon_slot(0), "acquired weapon equips")
	var acquired := await _attack(player, false)
	_expect(acquired.get("item_id", "") == "class_axe", "acquired weapon reaches actual hit payload")
	_expect(float(acquired.get("damage", 0.0)) != damages[0], "acquired weapon uses its own moveset")

	# Equipment modal pauses the world; a neutral player can still choose a slot.
	paused = true
	_expect(player.try_select_weapon_slot(2), "paused neutral equipment selection succeeds")
	paused = false
	_check_identity(player, identity, "paused UI selection")
	_test_debug_opt_in(player, world)
	await _test_save_restore(player, world)

	# Class changes are intentional; subsequent weapon changes cannot replace that body.
	player.set_combat_style(player.CombatStyle.CRESCENT_PAIR)
	await _frames(3)
	var class_identity := _identity(player)
	_expect(player.get_active_class_id() == "marksman", "fixture selects actual marksman class")
	for slot in 3:
		_expect(player.try_select_weapon_slot(slot), "native class accepts slot %d" % slot)
		_check_identity(player, class_identity, "native slot %d" % slot)
	await _test_hybrid_restore(player, world)
	world.free()
	await process_frame
	if _failures.is_empty():
		print("ASHEN_WEAPON_QUICKSLOT_CONTRACTS_OK checks=%d" % _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _attack(player, heavy: bool) -> Dictionary:
	player.stamina = player.max_stamina
	player._execute_hand_action("right", "secondary" if heavy else "primary")
	_expect(player.state in [player.State.ATTACK_WINDUP, player.State.CHARGE_HEAVY], "hand action enters combat FSM")
	var start_item: String = player.right_hand_item
	var slots_before: Array = player.get_weapon_quickslots()
	_expect(not player.try_cycle_weapon(), "combat-busy cycle rejected")
	_expect(not player.try_assign_weapon_slot(0, "guardian_sword"), "combat-busy assignment rejected")
	_expect(player.right_hand_item == start_item and player.get_weapon_quickslots() == slots_before,
		"busy selection cannot change the executing weapon")
	var seen: Dictionary = {}
	var result: Dictionary = {}
	var first_hand := Vector3.ZERO
	var sweep := 0.0
	for frame in 180:
		await _frames(1)
		seen[player.state] = true
		_expect(player.combat_area.active == (player.state == player.State.ATTACK_ACTIVE),
			"selected weapon hitbox follows the actual active phase")
		if player.state == player.State.ATTACK_ACTIVE:
			result = player.combat_area.hit_payload.duplicate()
			# Exclude the body's attack lunge: this must be arm/weapon pose motion.
			var hand: Vector3 = player.to_local(player.weapon_pivot.global_position)
			if first_hand == Vector3.ZERO:
				first_hand = hand
			sweep = maxf(sweep, first_hand.distance_to(hand))
			_expect(player._anim_bridge.clip_drives_real_body(player._anim_bridge._light_node.animation),
				"Manny melee uses a real body clip")
		if player.state == player.State.LOCOMOTION:
			break
	_expect(seen.has(player.State.ATTACK_WINDUP) and seen.has(player.State.ATTACK_ACTIVE)
		and seen.has(player.State.ATTACK_RECOVERY), "weapon visits windup, active, recovery")
	_expect(player.state == player.State.LOCOMOTION, "weapon action returns to locomotion")
	result["sweep"] = sweep
	print("WEAPON_QUICKSLOT_SWING item=%s heavy=%s damage=%.1f local_sweep=%.3f" % [
		start_item, heavy, float(result.get("damage", 0.0)), sweep])
	await _frames(8)
	return result


func _test_art(player, label: String) -> void:
	player.stamina = player.max_stamina
	var leap: AttackData = player._current_moveset().weapon_art_heavy
	_expect(leap != null, label + " provides a weapon art attack")
	if leap == null:
		return
	player._try_style_skill()
	_expect(player.state == player.State.LEAP_WINDUP, label + " F begins weapon art")
	var seen: Dictionary = {}
	for frame in 180:
		await _frames(1)
		if not seen.has(player.state):
			seen[player.state] = player.state_duration
		_expect(player.combat_area.active == (player.state == player.State.LEAP_ACTIVE), label + " art hit phase")
		if player.state == player.State.LOCOMOTION:
			break
	_expect(is_equal_approx(float(seen.get(player.State.LEAP_ACTIVE, -1.0)), leap.active_seconds),
		label + " art active duration comes from equipped weapon, not body class")
	_expect(is_equal_approx(float(seen.get(player.State.ATTACK_RECOVERY, -1.0)), leap.recovery_seconds),
		label + " art recovery comes from equipped weapon")
	_expect(player.state == player.State.LOCOMOTION, label + " art returns to locomotion")
	await _frames(15)


func _test_save_restore(player, world) -> void:
	world.run_state.combat_style = int(player.combat_style)
	world.run_state.progression_values["unrelated_progress"] = 7
	player.snapshot_weapon_loadout(world.run_state)
	var json_copy = RunState.from_json(world.run_state.to_json())
	var bridge_copy = RunState.from_dictionary(world.run_state.to_bridge_dictionary())
	_expect(json_copy != null and bridge_copy != null, "quickslots survive JSON and bridge schema validation")
	for saved in [json_copy, bridge_copy]:
		if saved == null:
			continue
		var expected: Array = player.get_weapon_quickslots()
		player.set_combat_style(player.CombatStyle.TWIN_COLOSSI)
		player.set_combat_style(saved.combat_style)
		var identity := _identity(player)
		player.restore_weapon_loadout(saved)
		_expect(player.get_weapon_quickslots() == expected, "saved slots and active weapon restored")
		_expect(player.get_active_class_id().is_empty(), "restored greatsword keeps default Manny identity")
		_check_identity(player, identity, "save restore")
		_expect(saved.progression_values.get("unrelated_progress") == 7, "unrelated progress preserved")
		await _frames(2)
	var old_save = RunState.new()
	old_save.right_hand = "guardian_sword"
	player.restore_weapon_loadout(old_save)
	_expect(player.get_weapon_quickslots().size() == 3 and player.right_hand_item == "guardian_sword",
		"old save without quickslot fields gains starter slots and retains equipped sword")
	var malformed = RunState.new()
	malformed.progression_values["right_weapon_slot_0"] = 17
	malformed.progression_values["right_weapon_slot_1"] = "class_spear"
	malformed.progression_values["right_weapon_active_slot"] = 99
	player.restore_weapon_loadout(malformed)
	_expect(player.right_hand_item == "guardian_sword", "unsupported saved slot values safely retain saved sword")


func _test_debug_opt_in(player, world) -> void:
	var hud := DiagnosticHud.new()
	world.add_child(hud)
	player.hud_node = hud
	player.enqueue_action(&"right_primary")
	player.apply_game_settings({})
	player._update_input_buffer_debug()
	_expect(hud.diagnostic.is_empty(), "normal debug build hides BUF diagnostics")
	player.apply_game_settings({"input_buffer_debug": true})
	player._update_input_buffer_debug()
	_expect(not hud.diagnostic.is_empty(), "explicit debug opt-in exposes queue diagnostic")
	player.apply_game_settings({})
	player._action_queue.clear()
	player.hud_node = null
	hud.free()


func _test_hybrid_restore(player, world) -> void:
	world.run_state.combat_style = player.CombatStyle.VEILCRAFT
	world.run_state.set_body_class_override("yin_yang")
	world.run_state.right_hand = "class_greatsword"
	world.run_state.left_hand = "spirit_stone"
	var saved = RunState.from_json(world.run_state.to_json())
	_expect(saved != null, "hybrid weapon save survives schema round-trip")
	if saved == null:
		return
	world.run_state = saved
	player.set_combat_style(saved.combat_style)
	player.apply_body_class_override()
	var identity := _identity(player)
	player.restore_weapon_loadout(saved)
	_expect(player.get_active_class_id() == "yin_yang" and player._class_override == "yin_yang",
		"hybrid load restores gameplay class identity as well as visual body")
	_check_identity(player, identity, "hybrid restore")
	for slot in 3:
		_expect(player.try_select_weapon_slot(slot), "hybrid class accepts weapon slot %d" % slot)
		_check_identity(player, identity, "hybrid slot %d" % slot)
	await _frames(2)


func _identity(player) -> Dictionary:
	return {"body": player.body_mesh, "skeleton": player._visuals._equipment_skeleton,
		"tree": player._anim_bridge.anim_tree, "camera": player.camera,
		"camera_fov": player.camera.fov, "spring_length": player.spring_arm.spring_length,
		"camera_collision": player.spring_arm.collision_mask, "style": player.combat_style,
		"class": player.get_active_class_id(), "override": player._class_override,
		"left": player.left_hand_item, "offhand_pivot": player.offhand_weapon_pivot}


func _check_identity(player, expected: Dictionary, label: String) -> void:
	var current := _identity(player)
	for key in expected:
		_expect(current[key] == expected[key], label + ": weapon selection preserves " + key)


func _mesh_paths(node: Node, paths: Array[String]) -> void:
	if node is MeshInstance3D and node.mesh != null and node.is_visible_in_tree():
		_expect(not node.mesh.resource_path.is_empty(), "equipped mesh is imported, not primitive fallback")
		paths.append(node.mesh.resource_path)
	for child in node.get_children():
		_mesh_paths(child, paths)


func _frames(count: int) -> void:
	for frame in count:
		await physics_frame
		await process_frame


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
