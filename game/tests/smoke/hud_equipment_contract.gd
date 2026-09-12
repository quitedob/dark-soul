extends SceneTree
## Actual player public equipment API + real HUD controls, isolated from save I/O.
const PlayerScript = preload("res://scripts/player/player.gd")
const HudScript = preload("res://scripts/hud.gd")
const InventoryScript = preload("res://scripts/ui/inventory_overlay.gd")
const InputConfig = preload("res://scripts/core/input_config.gd")

class FixtureWorld extends Node3D:
	var run_state = preload("res://scripts/core/run_state.gd").new()

var _failures: Array[String] = []
var _checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	InputConfig.configure_inputs()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	root.add_child(viewport)
	var world := FixtureWorld.new()
	viewport.add_child(world)
	var player = PlayerScript.new()
	player.world_node = world
	world.add_child(player)
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	var hud = HudScript.new()
	viewport.add_child(hud)
	hud.setup(player)
	hud.apply_accessibility_settings({"locale": "zh_CN", "reduced_motion": true})
	hud.set_mobile_controls_enabled(false)
	hud.set_location("第一章 / Chapter I", "苏醒之庭 / Courtyard of Awakening")
	hud.equipment_requested.connect(hud.open_equipment)
	await process_frame
	await process_frame
	_expect(hud.weapon_slot_buttons.size() == 3, "HUD must expose three weapon slots")
	_expect(hud.ember_panel.size.y <= 52. and hud.ember_panel.size.x < 180., "Currency panel must remain compact")
	_expect(hud.vitals_panel.size.y < 90., "Vitals must not retain the large black panel footprint")
	var body: Node = player.body_mesh
	var left_item: String = player.left_hand_item
	var before: String = player.right_hand_item
	hud.weapon_slot_buttons[1].pressed.emit()
	await process_frame
	_expect(player.right_hand_item != before, "Visible quickslot must switch the actual weapon")
	_expect(player.body_mesh == body and player.left_hand_item == left_item, "Weapon UI must not replace class body or offhand")
	_expect(bool(hud.weapon_slot_buttons[1].get_meta("active")), "HUD must reflect loadout-change signal")
	for button: Button in hud.weapon_slot_buttons:
		var caption: Label = button.get_meta("caption")
		_expect(not caption.text.is_empty() and not caption.text.contains("_"), "Weapon slots must show readable names")
		_expect((button.get_meta("icon") as TextureRect).texture != null, "Weapon slot silhouette missing")
	hud.set_input_buffer_debug("BUF RIGHT_PRIMARY 100ms")
	_expect(not hud.buffer_debug_label.visible, "Normal HUD must hide implementation diagnostics")
	hud._weapon_hint.pressed.emit()
	await process_frame
	_expect(hud.is_equipment_open() and paused, "Visible equipment entry must open a paused menu")
	var menu = hud.equipment_panel
	_expect(menu._slot_buttons.size() == 3 and menu._weapon_buttons.size() >= 3, "Equipment menu must expose real slots and owned weapons")
	_expect(viewport.gui_get_focus_owner() != null, "Equipment menu must establish keyboard/gamepad focus")
	menu._slot_buttons[0].pressed.emit()
	var choice: Button = menu._weapon_buttons[menu._weapon_buttons.size() - 1]
	var selected_id := String(choice.get_meta("item_id"))
	choice.pressed.emit()
	await process_frame
	_expect(player.right_hand_item == selected_id, "Equipment card must assign and equip through the player API")
	_expect(String(player.get_weapon_quickslots()[0]["item_id"]) == selected_id, "Equipment card must update its chosen quickslot")
	hud.close_equipment()
	_expect(not paused and not hud.is_equipment_open(), "Equipment close must restore gameplay pause state")
	hud._set_paused(true)
	_expect(hud.open_equipment(), "Equipment must also open from pause")
	hud.close_equipment()
	_expect(paused and hud.pause_overlay.visible, "Equipment opened from pause must return to pause")
	hud._set_paused(false)
	player.state = player.State.ATTACK_WINDUP
	before = player.right_hand_item
	hud.weapon_slot_buttons[1].pressed.emit()
	_expect(player.right_hand_item == before and not player.get_weapon_loadout_error().is_empty(), "Busy equipment request must respect the public rejection")
	player.state = player.State.LOCOMOTION
	hud.set_scene_objective("Follow the wedding and extinguish its three guiding lanterns in order.")
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(854, 480), Vector2i(390, 844)]:
		viewport.size = size
		hud.set_text_scale(1.0)
		await process_frame
		await process_frame
		_expect(_inside(hud.weapon_dock.get_global_rect(), Vector2(size)), "Weapon dock outside viewport " + str(size))
		_expect(_inside(hud.ember_panel.get_global_rect(), Vector2(size)), "Currency outside viewport " + str(size))
		_expect(hud.scene_objective_label.visible and _inside(hud.scene_objective_label.get_global_rect(), Vector2(size)), "Scene objective must remain visible inside viewport " + str(size))
		_expect(hud.scene_objective_label.get_line_count() <= hud.scene_objective_label.max_lines_visible, "Scene objective must not truncate its instructions " + str(size))
		_expect(not hud.scene_objective_label.get_global_rect().intersects(hud.vitals_panel.get_global_rect()), "Scene objective overlaps vitals " + str(size))
		_expect(hud.open_equipment(), "Equipment failed at viewport " + str(size))
		await process_frame
		await process_frame
		_expect(_inside(menu._panel.get_global_rect(), Vector2(size)), "Equipment panel outside viewport " + str(size))
		_expect(menu._catalog.columns == (1 if size.x < 760 else 2), "Catalog must adapt its columns")
		for slot_button: Button in menu._slot_buttons:
			var icon: TextureRect = slot_button.get_meta("weapon_icon")
			_expect(icon.visible == (size.x >= 760), "Quickslot icons must follow the resized viewport")
		hud.close_equipment()
		hud._set_paused(true)
		await process_frame
		await process_frame
		_expect(_inside(hud.pause_overlay.get_node("Center/Menu").get_global_rect(), Vector2(size)), "Pause menu outside viewport " + str(size))
		hud._toggle_help()
		await process_frame
		await process_frame
		_expect(_inside(hud.help_overlay.get_node("Center/Menu").get_global_rect(), Vector2(size)), "Controls menu outside viewport " + str(size))
		hud._close_help()
		hud._set_paused(false)
	viewport.size = Vector2i(1280, 720)
	await process_frame
	await process_frame
	hud.open_equipment()
	viewport.size = Vector2i(390, 844)
	await process_frame
	await process_frame
	for slot_button: Button in menu._slot_buttons:
		_expect(not (slot_button.get_meta("weapon_icon") as TextureRect).visible, "Open menu must hide slot icons when resized to portrait")
		var caption: Label = slot_button.get_meta("weapon_caption")
		_expect(slot_button.get_global_rect().grow(1.).encloses(caption.get_global_rect()), "Portrait quickslot caption must stay inside its card")
	hud.close_equipment()
	viewport.size = Vector2i(854, 480)
	hud.set_scene_objective("")
	_expect(not hud.scene_objective_label.visible, "Completed or unloaded scene must clear its objective")
	hud.set_text_scale(1.6)
	hud.set_high_contrast(true)
	await process_frame
	_expect(hud.open_equipment(), "Scaled equipment menu must open")
	await process_frame
	await process_frame
	_expect(_inside(menu._panel.get_global_rect(), Vector2(viewport.size)), "Large-text equipment panel must fit")
	hud.close_equipment()
	hud._set_paused(true)
	await process_frame
	await process_frame
	_expect(_inside(hud.pause_overlay.get_node("Center/Menu").get_global_rect(), Vector2(viewport.size)), "Large-text pause menu must fit")
	hud._set_paused(false)
	var inventory = InventoryScript.new()
	viewport.add_child(inventory)
	inventory.apply_accessibility_settings({"locale": "zh_CN", "text_scale": 1.6, "high_contrast": true})
	await process_frame
	_expect(inventory.open(player, world.run_state), "Shrine inventory must remain functional")
	await process_frame
	await process_frame
	_expect(_inside(inventory._panel.get_global_rect(), Vector2(viewport.size)), "Scrollable inventory must fit scaled viewport")
	_expect(inventory._close_button.has_focus(), "Inventory must establish close-button focus")
	inventory.close()
	_expect(not paused, "Inventory must restore prior pause state")
	viewport.free()
	if _failures.is_empty():
		print("ASHEN_HUD_EQUIPMENT_CONTRACTS_OK checks=%d" % _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _inside(rect: Rect2, size: Vector2) -> bool:
	return rect.position.x >= -.1 and rect.position.y >= -.1 and rect.end.x <= size.x + .1 and rect.end.y <= size.y + .1


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
