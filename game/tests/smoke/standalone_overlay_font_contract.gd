extends SceneTree
## Actual standalone controls must use the bundled font, including project defaults.
const SharedFont = preload("res://assets/fonts/NotoSansSC-AshenHollow.ttf")
const Fate = preload("res://scripts/ui/fate_choice_overlay.gd")
const Dialogue = preload("res://scripts/ui/dialogue_overlay.gd")
const Travel = preload("res://scripts/ui/fast_travel_overlay.gd")
const Catalog = preload("res://scripts/combat/data/boss_fate_catalog.gd")
var _failures: Array[String] = []
var _checks := 0
var _controls := 0
var _hanzi: Dictionary = {}
var _chosen := ""
var _dialogue_finished := false
var _destination := ""
var _cancelled := false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	TranslationServer.set_locale("zh_CN")
	var unthemed := Label.new()
	unthemed.text = "烛阴 · 终末裁决  薪火相传"
	root.add_child(unthemed)
	await process_frame
	_check_text(unthemed)
	_expect(unthemed.theme == null, "Project default proof must not assign a per-control theme")
	unthemed.queue_free()
	var fate := Fate.new()
	root.add_child(fate)
	await process_frame
	fate.choice_made.connect(func(_flag: StringName, value: String): _chosen = value)
	for flag: StringName in Catalog.all_entries():
		_expect(fate.open_for_flag(flag), "Actual fate catalog entry must open")
		await process_frame
		_check_descendants(fate)
		_expect(paused and fate.is_open(), "Fate remains modal and paused")
		fate.close()
	_expect(fate.open_for_flag(&"ending_state"), "Actual ZhuYin ending must open")
	fate.add_extra_option("forge", "共铸新炉", "将三段真相铸入新炉")
	await process_frame
	_check_descendants(fate)
	if DisplayServer.get_name() != "headless":
		await create_timer(.3).timeout
		await RenderingServer.frame_post_draw
		var capture := ProjectSettings.globalize_path("res://../build/temple-redesign-20260909/fate-font-native.png")
		_expect(root.get_texture().get_image().save_png(capture) == OK, "Native ending capture must save")
		print("FATE_FONT_NATIVE_CAPTURE " + capture)
	var last := fate._buttons.get_child(fate._buttons.get_child_count() - 1) as Button
	last.pressed.emit()
	_expect(_chosen == "forge" and not paused and not fate.is_open(), "Actual fate button still closes and emits unchanged choice")
	fate.free()
	var dialogue := Dialogue.new()
	root.add_child(dialogue)
	await process_frame
	dialogue.dialogue_finished.connect(func(_id: StringName): _dialogue_finished = true)
	dialogue.open_lines(&"font_contract", ["烛阴 · 终末裁决", "轮回将由你落笔。"])
	await process_frame
	_check_descendants(dialogue)
	_expect(paused and dialogue.is_open(), "Dialogue retains modal pause")
	if not InputMap.has_action("interact"):
		InputMap.add_action("interact")
	var accept := InputEventAction.new()
	accept.action = "ui_accept"
	accept.pressed = true
	dialogue._unhandled_input(accept)
	_check_descendants(dialogue)
	dialogue._unhandled_input(accept)
	_expect(_dialogue_finished and not paused and not dialogue.is_open(), "Dialogue input still advances and closes")
	dialogue.free()
	var travel := Travel.new()
	root.add_child(travel)
	await process_frame
	travel.destination_selected.connect(func(id: String): _destination = id)
	travel.travel_cancelled.connect(func(): _cancelled = true)
	var destinations: Array[Dictionary] = [{"level_id": "level_01_01", "display_name": "灵墟 · 觉醒古庙"}]
	_expect(travel.open(destinations, "level_05_05"), "Travel must open with actual destination controls")
	await process_frame
	_check_descendants(travel)
	_expect(paused and travel.is_open(), "Travel retains modal pause")
	(travel._list.get_child(0) as Button).pressed.emit()
	_expect(_destination == "level_01_01" and not paused, "Destination input still emits and resumes")
	travel.open(destinations, "level_05_05")
	var cancel := InputEventKey.new()
	cancel.keycode = KEY_ESCAPE
	cancel.pressed = true
	travel._unhandled_input(cancel)
	_expect(_cancelled and not paused and not travel.is_open(), "Travel Escape remains functional")
	travel.free()
	_expect(_hanzi.size() >= 100, "Exercise real catalog Chinese coverage, not only a sample glyph")
	print("OVERLAY_FONT_COUNTS controls=%d chinese_glyphs=%d checks=%d" % [_controls, _hanzi.size(), _checks])
	if _failures.is_empty():
		print("ASHEN_STANDALONE_OVERLAY_FONT_OK")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)

func _check_descendants(node: Node) -> void:
	if node.is_queued_for_deletion():
		return
	if node is Label or node is Button:
		_check_text(node)
	for child in node.get_children():
		_check_descendants(child)

func _check_text(control: Control) -> void:
	_controls += 1
	var font := control.get_theme_font("font")
	_expect(font.resource_path == SharedFont.resource_path, "Actual control must resolve bundled font: " + String(control.name))
	var missing := ""
	var content: String = control.get("text")
	for index in content.length():
		var code := content.unicode_at(index)
		if code < 32:
			continue
		if code >= 0x4e00 and code <= 0x9fff:
			_hanzi[code] = true
		if not font.has_char(code):
			missing += content[index]
	_expect(missing.is_empty(), "Missing actual overlay glyphs: " + missing)

func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
