class_name EquipmentPanel
extends Control
## Presentation only: all equipment mutations go through the player's public API.
signal close_requested
signal loadout_updated

const HudThemeScript = preload("res://scripts/ui/hud_theme.gd")
var _player: Node
var _theme := HudThemeScript.new()
var _locale := "en"
var _ui_scale := 1.0
var _text_scale := 1.0
var _selected_slot := 0
var _margin: MarginContainer
var _panel: PanelContainer
var _title: Label
var _subtitle: Label
var _slot_row: HBoxContainer
var _catalog: GridContainer
var _status: Label
var _close_button: Button
var _slot_buttons: Array[Button] = []
var _weapon_buttons: Array[Button] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	resized.connect(_layout)
	visible = false


func show_for(player: Node, settings: Dictionary = {}) -> bool:
	if not is_instance_valid(player) or not player.has_method("get_weapon_quickslots"):
		return false
	_player = player
	_locale = String(settings.get("locale", TranslationServer.get_locale()))
	_ui_scale = clampf(float(settings.get("ui_scale", 1.0)), .75, 1.6)
	_text_scale = clampf(float(settings.get("text_scale", 1.0)), .85, 2.0)
	_theme.high_contrast = bool(settings.get("high_contrast", false))
	theme = _theme.build_theme()
	for label in [_title, _subtitle, _status]:
		label.add_theme_font_size_override("font_size", roundi(float(label.get_meta("base_font_size")) * _ui_scale * _text_scale))
	var rows: Array = _player.call("get_weapon_quickslots")
	for row: Dictionary in rows:
		if bool(row.get("active", false)):
			_selected_slot = int(row.get("slot", 0))
	visible = true
	refresh()
	_layout()
	if not _slot_buttons.is_empty():
		_slot_buttons[clampi(_selected_slot, 0, _slot_buttons.size() - 1)].grab_focus()
	return true


func refresh() -> void:
	if not is_instance_valid(_player):
		return
	_title.text = _text("兵器装备", "ARMAMENTS")
	_subtitle.text = _text("选择快捷栏，再为下一段旅途装备兵器。", "Choose a quick slot, then equip a weapon for the road ahead.")
	_close_button.text = _text("返回  Esc", "Back  Esc")
	_clear(_slot_row)
	_clear(_catalog)
	_slot_buttons.clear()
	_weapon_buttons.clear()
	var slots: Array = _player.call("get_weapon_quickslots")
	for row: Dictionary in slots:
		var index := int(row.get("slot", _slot_buttons.size()))
		var button := _card(row, index == _selected_slot, true)
		button.name = "QuickSlot%d" % index
		button.tooltip_text = _text("选择要更换的快捷栏", "Choose the quick slot to replace")
		button.pressed.connect(_choose_slot.bind(index))
		_slot_row.add_child(button)
		_slot_buttons.append(button)
	var choices: Array = _player.call("get_available_right_weapons") if _player.has_method("get_available_right_weapons") else []
	for row: Dictionary in choices:
		var item_id := String(row.get("item_id", ""))
		if item_id.is_empty():
			continue
		var assigned := false
		for slot: Dictionary in slots:
			if int(slot.get("slot", -1)) == _selected_slot and String(slot.get("item_id", "")) == item_id:
				assigned = true
		var button := _card(row, assigned, false)
		button.name = "WeaponChoice%d" % _weapon_buttons.size()
		button.set_meta("item_id", item_id)
		button.disabled = not bool(row.get("can_select", true))
		button.pressed.connect(_assign.bind(item_id))
		_catalog.add_child(button)
		_weapon_buttons.append(button)
	_status.text = _text("X  轮换兵器     I  打开装备", "X  Cycle weapons     I  Equipment")
	_layout()


func _build() -> void:
	theme = _theme.build_theme()
	var shade := ColorRect.new()
	shade.name = "EquipmentShade"
	shade.color = Color(.009, .014, .018, .84)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	_margin = MarginContainer.new()
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_margin)
	_panel = PanelContainer.new()
	_panel.name = "EquipmentMenu"
	_panel.add_theme_stylebox_override("panel", _theme.panel_style(HudTheme.COLOR_SURFACE, HudTheme.COLOR_BORDER, 2, 24., 20.))
	_margin.add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	_panel.add_child(column)
	var heading := HBoxContainer.new()
	column.add_child(heading)
	_title = _label("", 30, HudTheme.COLOR_TEXT)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(_title)
	_close_button = Button.new()
	_close_button.custom_minimum_size = Vector2(112., 48.)
	_close_button.pressed.connect(func() -> void: close_requested.emit())
	heading.add_child(_close_button)
	_subtitle = _label("", 15, HudTheme.COLOR_MUTED)
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_subtitle)
	_slot_row = HBoxContainer.new()
	_slot_row.add_theme_constant_override("separation", 10)
	column.add_child(_slot_row)
	column.add_child(HSeparator.new())
	var scroll := ScrollContainer.new()
	scroll.name = "WeaponCatalogScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	column.add_child(scroll)
	_catalog = GridContainer.new()
	_catalog.name = "WeaponCatalog"
	_catalog.columns = 2
	_catalog.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_catalog.add_theme_constant_override("h_separation", 12)
	_catalog.add_theme_constant_override("v_separation", 10)
	scroll.add_child(_catalog)
	_status = _label("", 14, HudTheme.COLOR_EMBER)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)


func _card(data: Dictionary, selected: bool, slot: bool) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0., maxf(94., 46. * _text_scale + 32.) * _ui_scale)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_stylebox_override("normal", _theme.slot_style(selected))
	button.add_theme_stylebox_override("hover", _theme.slot_style(selected, true))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 12.
	row.offset_right = -12.
	row.offset_top = 10.
	row.offset_bottom = -10.
	row.add_theme_constant_override("separation", 12)
	button.add_child(row)
	var icon := TextureRect.new()
	icon.texture = HudThemeScript.weapon_icon(String(data.get("weapon_type", "sword")))
	icon.custom_minimum_size = Vector2(42., 42.) * _ui_scale
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.visible = not slot or size.x >= 760. * _ui_scale
	button.set_meta("weapon_icon", icon)
	row.add_child(icon)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(words)
	var name := HudThemeScript.readable_name(String(data.get("display_name", "")), _locale)
	var caption := _label(name, 14 if slot else 17, HudTheme.COLOR_TEXT)
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.set_meta("weapon_caption", caption)
	words.add_child(caption)
	var detail := _text("已装备" if selected else "装备至此栏", "Equipped" if selected else "Equip in this slot")
	if slot:
		detail = _text("快捷栏 %d", "Slot %d") % (int(data.get("slot", 0)) + 1)
		if bool(data.get("active", false)):
			detail = "%d · " % (int(data.get("slot", 0)) + 1) + _text("当前", "Active")
	var hint := _label(detail, 11 if slot else 12, HudTheme.COLOR_EMBER if selected else HudTheme.COLOR_MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(hint)
	button.tooltip_text = name
	return button


func _choose_slot(index: int) -> void:
	_selected_slot = index
	refresh()
	if index >= 0 and index < _slot_buttons.size():
		_slot_buttons[index].grab_focus()


func _assign(item_id: String) -> void:
	if not is_instance_valid(_player):
		return
	var accepted := bool(_player.call("try_assign_weapon_slot", _selected_slot, item_id))
	if accepted:
		accepted = bool(_player.call("try_select_weapon_slot", _selected_slot))
	if not accepted:
		_status.text = _rejection()
		return
	refresh()
	_status.text = _text("兵器已装备", "Weapon equipped")
	if _selected_slot < _slot_buttons.size():
		_slot_buttons[_selected_slot].grab_focus()
	loadout_updated.emit()


func _rejection() -> String:
	if _player.has_method("get_weapon_loadout_error"):
		return String(_player.call("get_weapon_loadout_error"))
	return _text("当前动作中无法更换兵器，请稍后再试。", "Finish your current action before changing weapons.")


func _layout() -> void:
	if _margin == null:
		return
	var horizontal := maxf(18., (size.x - 960. * _ui_scale) * .5)
	var vertical := maxf(18., (size.y - 610. * _ui_scale) * .5)
	for side in ["left", "right"]:
		_margin.add_theme_constant_override("margin_" + side, roundi(horizontal))
	for side in ["top", "bottom"]:
		_margin.add_theme_constant_override("margin_" + side, roundi(vertical))
	_catalog.columns = 1 if size.x < 760. * _ui_scale else 2
	# An open menu can cross the compact breakpoint without rebuilding its cards.
	for button: Button in _slot_buttons:
		var icon: TextureRect = button.get_meta("weapon_icon")
		icon.visible = size.x >= 760. * _ui_scale


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		get_viewport().set_input_as_handled()
		close_requested.emit()


func _label(text: String, pixels: int, color: Color) -> Label:
	var label := _theme.make_label(text, roundi(pixels * _ui_scale * _text_scale), Color.WHITE if _theme.high_contrast else color)
	return label


func _text(zh: String, en: String) -> String:
	return HudThemeScript.copy(zh, en, _locale)


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
