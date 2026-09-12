extends SceneTree
## Actual world startup, physical menu input and autosave wiring. Only disk
## save/load is replaced; save callbacks still snapshot the live world.

const WorldScene = preload("res://scenes/world/ashen_hollow.tscn")
const RunState = preload("res://scripts/core/run_state.gd")

class AuditWorld extends "res://scripts/game_world.gd":
	var recorded_saves: Array[Dictionary] = []
	func _load_initial_state() -> void:
		_apply_settings()
	func _save_run(reason: String) -> bool:
		recorded_saves.append({
			"reason": reason, "restoring": _restoring_run_state,
			"ready": _systems_ready, "state": _snapshot_run_state().duplicate(true),
		})
		return true

var _world: AuditWorld
var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_world = AuditWorld.new()
	var scene := WorldScene.instantiate()
	for child in scene.get_children():
		child.owner = null
		scene.remove_child(child)
		_world.add_child(child)
	scene.free()
	root.add_child(_world)
	_world.set_process(false)
	_freeze_actors()
	await _settle()
	_expect(_world._systems_ready, "real world finishes system initialization")
	_expect(_world.recorded_saves.is_empty(), "startup cannot save a partially initialized loadout")
	_expect(not paused and not _world.hud.title_overlay.visible, "fixture begins in gameplay")
	# Physical I traverses InputMap -> world -> HUD; closing must work while paused.
	await _tap_i()
	_expect(_world.hud.is_equipment_open() and paused, "I opens equipment through world input")
	if _world.hud.is_equipment_open():
		await _tap_i()
	_expect(not _world.hud.is_equipment_open() and not paused, "I closes paused equipment")
	_world.hud.close_equipment()
	paused = false

	_world._grant_loot("class_axe")
	var identity := _equipment_identity()
	await _tap_i()
	if _world.hud.is_equipment_open():
		var panel = _world.hud.equipment_panel
		panel._slot_buttons[1].pressed.emit()
		await process_frame
		var choice: Button = null
		for button: Button in panel._weapon_buttons:
			if String(button.get_meta("item_id", "")) == "class_axe":
				choice = button
				break
		_expect(choice != null, "equipment catalog contains newly granted supported loot")
		if choice != null:
			choice.pressed.emit()
		await process_frame
		_expect(_world.player.right_hand_item == "class_axe", "visible card equips acquired weapon")
		_expect(String(_world.player.get_weapon_quickslots()[1]["item_id"]) == "class_axe",
			"visible card assigns chosen slot")
		for key in identity:
			_expect(_equipment_identity()[key] == identity[key], "equipment UI preserves " + key)
		await _tap_i()
	_world.hud.close_equipment()
	paused = false
	_expect(not _world.recorded_saves.is_empty(), "world autosaves equipment signals")
	if not _world.recorded_saves.is_empty():
		var snapshot: Dictionary = _world.recorded_saves.back()["state"]
		_expect(snapshot.get("right_hand") == "class_axe", "autosave records final selected weapon")
		_expect(snapshot.get("progression_values", {}).get("right_weapon_slot_1") == "class_axe",
			"autosave records assigned slots")
		await _reload_equipment(snapshot, "Manny")

	# Inventory must transfer modal ownership, then I must resume gameplay.
	_world._open_inventory()
	_expect(_world._inventory_overlay.is_open() and paused, "real inventory entry opens modal")
	var inventory_button := _world._inventory_overlay.find_child("InventoryEquipmentButton", true, false) as Button
	_expect(inventory_button != null, "inventory exposes a visible equipment entry")
	if inventory_button != null:
		inventory_button.pressed.emit()
	await process_frame
	_expect(not _world._inventory_overlay.is_open() and _world.hud.is_equipment_open() and paused,
		"inventory button transfers to equipment without overlapping modals")
	await _tap_i()
	_expect(not _world.hud.is_equipment_open() and not paused, "I closes equipment entered through inventory")
	_world.hud.close_equipment()
	paused = false

	var hybrid = RunState.new()
	hybrid.level_id = "level_01_01"
	hybrid.combat_style = _world.player.CombatStyle.VEILCRAFT
	hybrid.set_body_class_override("yin_yang")
	hybrid.right_hand = "class_greatsword"
	hybrid.left_hand = "spirit_stone"
	hybrid.progression_values["right_weapon_slot_0"] = "xingtian_axe_right"
	hybrid.progression_values["right_weapon_slot_1"] = "guardian_sword"
	hybrid.progression_values["right_weapon_slot_2"] = "class_greatsword"
	hybrid.progression_values["right_weapon_active_slot"] = 2
	await _reload_equipment(hybrid.to_dictionary(), "hybrid")
	_expect(_world.player.get_active_class_id() == "yin_yang", "hybrid restores gameplay class")
	_expect(_world.player._visuals._active_class_id == "yin_yang", "hybrid restores actual body")
	var hybrid_identity := _equipment_identity()
	_expect(_world.player.try_select_weapon_slot(0), "restored hybrid can switch weapon")
	for key in hybrid_identity:
		_expect(_equipment_identity()[key] == hybrid_identity[key], "hybrid selection preserves " + key)
	_expect(not _world.recorded_saves.is_empty(), "autosave resumes after restoration")
	if not _world.recorded_saves.is_empty():
		var final: Dictionary = _world.recorded_saves.back()["state"]
		_expect(final.get("right_hand") == "xingtian_axe_right", "post-restore save captures next selection")
		_expect(final.get("progression_values", {}).get("body_class_override") == "yin_yang",
			"post-restore save retains hybrid identity")
	await _settle()
	paused = false
	_world.free()
	await process_frame
	if _failures.is_empty():
		print("ASHEN_WORLD_EQUIPMENT_CONTRACTS_OK checks=%d" % _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _reload_equipment(snapshot: Dictionary, label: String) -> void:
	var restored = RunState.from_json(JSON.stringify(snapshot))
	_expect(restored != null, label + ": save survives schema decoding")
	if restored == null:
		return
	var expected_values: Dictionary = restored.progression_values.duplicate(true)
	var expected_right: String = restored.right_hand
	var expected_left: String = restored.left_hand
	var expected_style: int = restored.combat_style
	# Force a genuinely different live body/loadout before invoking world restore.
	_world.player.set_combat_style(_world.player.CombatStyle.CRESCENT_PAIR)
	_world.recorded_saves.clear()
	_world._apply_run_state(restored)
	_freeze_actors()
	_expect(_world.recorded_saves.is_empty(), label + ": no intermediate autosave during restore")
	_expect(not _world._restoring_run_state, label + ": restoration guard releases")
	_expect(_world.player.right_hand_item == expected_right and _world.run_state.right_hand == expected_right,
		label + ": selected weapon survives class restoration")
	_expect(_world.player.left_hand_item == expected_left, label + ": saved offhand survives")
	_expect(int(_world.player.combat_style) == expected_style, label + ": saved class style survives")
	for key in expected_values:
		if String(key).begins_with("right_weapon_"):
			_expect(_world.run_state.progression_values.get(key) == expected_values[key],
				label + ": saved " + String(key) + " remains intact")
	var slots: Array = _world.player.get_weapon_quickslots()
	for slot in 3:
		_expect(String(slots[slot]["item_id"]) == String(expected_values.get("right_weapon_slot_" + str(slot), "")),
			label + ": runtime restores slot " + str(slot))
	_expect(String(slots[int(expected_values.get("right_weapon_active_slot", 0))]["item_id"]) == expected_right,
		label + ": runtime restores active slot")
	await _settle()
	_expect(_world.recorded_saves.is_empty(), label + ": deferred callbacks do not corrupt restored save")


func _equipment_identity() -> Dictionary:
	return {"body": _world.player.body_mesh, "skeleton": _world.player._visuals._equipment_skeleton,
		"class": _world.player.get_active_class_id(), "style": _world.player.combat_style,
		"offhand": _world.player.left_hand_item, "camera": _world.player.camera}


func _tap_i() -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_I
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.physical_keycode = KEY_I
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame


func _freeze_actors() -> void:
	_world.player.set_physics_process(false)
	for enemy: Node in _world.enemies:
		if is_instance_valid(enemy):
			enemy.set_process(false)
			enemy.set_physics_process(false)


func _settle() -> void:
	for frame in 180:
		await process_frame
		var navigation: Node = _world.campaign_runtime.current_level.get_node_or_null("NavigationSurface")
		if frame >= 3 and navigation != null and bool(navigation.get_meta("bake_complete", false)):
			return


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
