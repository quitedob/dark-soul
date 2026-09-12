extends CanvasLayer
class_name InventoryOverlay
## L-10：背包/图鉴入口 —— 烬龛休息时打开，暂停树，展示收集战利品与当前装备状态。
## 数据只读：run_state.collected_loot + run_state.inventory（掉落统计）、player 装备与状态条。

signal inventory_closed
signal equipment_requested

const LocalizationScript = preload("res://scripts/core/localization.gd")
const HandEquipmentScript = preload("res://scripts/data/hand_equipment.gd")
const StatusEffectScript = preload("res://scripts/combat/data/status_effect.gd")
const MeridianSystemScript = preload("res://scripts/player/meridian_system.gd")
const ThemeScript = preload("res://scripts/ui/hud_theme.gd")

var _dim: ColorRect
var _panel: PanelContainer
var _title: Label
var _loot_section: VBoxContainer
var _equip_section: VBoxContainer
var _status_section: VBoxContainer
var _open := false
var _was_paused := false
var _previous_mouse := Input.MOUSE_MODE_CAPTURED
var _theme := ThemeScript.new()
var _locale := "en"
var _ui_scale := 1.0
var _text_scale := 1.0
var _scroll: ScrollContainer
var _close_button: Button
var _item_names: Dictionary = {}
var _columns: GridContainer


func _ready() -> void:
	layer = 85
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_locale = TranslationServer.get_locale()
	_build()
	get_viewport().size_changed.connect(_layout)
	_layout()


func is_open() -> bool:
	return _open


func open(player: Node, run_state) -> bool:
	if player == null or run_state == null:
		return false
	_title.text = _text("行囊", "INVENTORY")
	_item_names.clear()
	if player.has_method("get_available_right_weapons"):
		for item: Dictionary in player.call("get_available_right_weapons"):
			_item_names[String(item.get("item_id", ""))] = ThemeScript.readable_name(String(item.get("display_name", "")), _locale)
	_rebuild_loot(run_state)
	_rebuild_equipped(player, run_state)
	_rebuild_statuses(player)
	visible = true
	_open = true
	_was_paused = get_tree().paused
	_previous_mouse = Input.mouse_mode
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_layout()
	_close_button.grab_focus()
	return true


func close() -> void:
	_open = false
	visible = false
	get_tree().paused = _was_paused
	Input.mouse_mode = _previous_mouse


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_on_close()


func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(.009, .014, .018, .84)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel = PanelContainer.new()
	_panel.theme = _theme.build_theme()
	var style := _theme.panel_style(HudTheme.COLOR_SURFACE, HudTheme.COLOR_BORDER, 2, 24., 20.)
	_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_panel)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_panel.add_child(_scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	_scroll.add_child(vbox)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 28)
	_title.add_theme_color_override("font_color", Color(0.95, 0.82, 0.55))
	vbox.add_child(_title)

	var subtitle := Label.new()
	_bilingual(subtitle, "整理所得，重整行装。", "Gather your spoils. Prepare for the road.")
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.85, 0.8, 0.75, 0.9))
	vbox.add_child(subtitle)
	var equipment_button := _theme.make_button(_text("装备兵器", "Equipment"))
	_bilingual(equipment_button, "装备兵器", "Equipment")
	equipment_button.name = "InventoryEquipmentButton"
	equipment_button.pressed.connect(func() -> void: equipment_requested.emit())
	vbox.add_child(equipment_button)

	var columns := GridContainer.new()
	columns.columns = 2
	_columns = columns
	columns.add_theme_constant_override("h_separation", 28)
	columns.add_theme_constant_override("v_separation", 18)
	vbox.add_child(columns)

	var left_col := VBoxContainer.new()
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(left_col)
	_add_section_header(left_col, "收集物", "COLLECTED")
	_loot_section = VBoxContainer.new()
	_loot_section.add_theme_constant_override("separation", 4)
	left_col.add_child(_loot_section)

	var right_col := VBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right_col)
	_add_section_header(right_col, "当前装备", "EQUIPPED")
	_equip_section = VBoxContainer.new()
	_equip_section.add_theme_constant_override("separation", 4)
	right_col.add_child(_equip_section)

	_add_section_header(vbox, "身体状态", "CONDITION")
	_status_section = VBoxContainer.new()
	_status_section.add_theme_constant_override("separation", 4)
	vbox.add_child(_status_section)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	vbox.add_child(spacer)

	var close_button := Button.new()
	_bilingual(close_button, "返回  Esc", "Back  Esc")
	close_button.custom_minimum_size = Vector2(180, 48)
	close_button.add_theme_font_size_override("font_size", 16)
	_style_button(close_button)
	close_button.pressed.connect(_on_close)
	vbox.add_child(close_button)
	_close_button = close_button


func _add_section_header(parent: Control, zh: String, en: String) -> void:
	var header := Label.new()
	_bilingual(header, zh, en)
	header.add_theme_font_size_override("font_size", 17)
	header.add_theme_color_override("font_color", Color(0.88, 0.62, 0.32))
	parent.add_child(header)


func _add_row(container: VBoxContainer, key: String, value: String) -> void:
	var row := HBoxContainer.new()
	var key_label := Label.new()
	key_label.text = key
	key_label.custom_minimum_size = Vector2(96, 0)
	key_label.add_theme_font_size_override("font_size", 15)
	key_label.add_theme_color_override("font_color", Color(0.7, 0.68, 0.62))
	row.add_child(key_label)
	var value_label := Label.new()
	value_label.text = value
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value_label.add_theme_font_size_override("font_size", 15)
	value_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	row.add_child(value_label)
	container.add_child(row)


func _style_button(btn: Button) -> void:
	var normal := _theme.slot_style(false)
	btn.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.28, 0.18, 0.1, 0.98)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.12, 0.08, 0.05, 1.0)
	btn.add_theme_stylebox_override("pressed", pressed)


## 安全读取对象属性（Node 的 get() 仅接受 1 参，带默认值需自行兜底）
func _prop(obj, property: String, fallback: Variant) -> Variant:
	if obj == null:
		return fallback
	if property in obj:
		return obj.get(property)
	return fallback


## 收集战利品：inventory(item_id→count) 为权威计数；collected_loot 补充未入账的发现记录
func _rebuild_loot(run_state) -> void:
	for child in _loot_section.get_children():
		child.queue_free()
	var counts := {}
	var inventory: Dictionary = run_state.inventory
	for item_id in inventory.keys():
		counts[String(item_id)] = int(inventory[item_id])
	var collected: Array = run_state.collected_loot
	for item_id in collected:
		var key := String(item_id)
		if not counts.has(key):
			counts[key] = 1
	if counts.is_empty():
		var empty_label := Label.new()
		empty_label.text = _text("尚未收集战利品", "No spoils collected yet")
		empty_label.add_theme_font_size_override("font_size", 14)
		empty_label.add_theme_color_override("font_color", Color(0.6, 0.58, 0.54))
		_loot_section.add_child(empty_label)
		return
	for item_id in counts.keys():
		_add_row(_loot_section, "x%d" % int(counts[item_id]), _item_display_name(String(item_id)))


func _rebuild_equipped(player: Node, run_state) -> void:
	for child in _equip_section.get_children():
		child.queue_free()
	var right := String(_prop(player, "right_hand_item", "guardian_sword"))
	var left := String(_prop(player, "left_hand_item", "reliquary_shield"))
	_add_row(_equip_section, _text("右手", "Right"), _item_display_name(right))
	_add_row(_equip_section, _text("左手", "Left"), _item_display_name(left))
	_add_row(_equip_section, _text("生命", "Health"), "%d" % int(float(_prop(player, "max_health", 0.0))))
	_add_row(_equip_section, _text("耐力", "Stamina"), "%d" % int(float(_prop(player, "max_stamina", 0.0))))
	_add_row(_equip_section, _text("专注", "Focus"), "%d" % int(float(_prop(player, "max_focus", 0.0))))
	var forge := 0
	if player.has_method("get_forge_level"):
		forge = int(player.call("get_forge_level"))
	var talent := 0
	if player.has_method("get_talent_points"):
		talent = int(player.call("get_talent_points"))
	var meridian_total := MeridianSystemScript.total_level(run_state.progression_values)
	_add_row(_equip_section, _text("锻造", "Forge"), "+%d" % forge)
	_add_row(_equip_section, _text("天赋", "Talent"), str(talent))
	_add_row(_equip_section, _text("经脉", "Meridian"), str(meridian_total))


func _rebuild_statuses(player: Node) -> void:
	for child in _status_section.get_children():
		child.queue_free()
	var status_bar: Dictionary = _prop(player, "status_bar", {})
	if status_bar.is_empty():
		_add_row(_status_section, _text("状态", "Condition"), _text("无异常", "Clear"))
		return
	for status_id in status_bar.keys():
		var names := {"bleed": _text("出血", "Bleed"), "poison": _text("中毒", "Poison"), "burn": _text("灼烧", "Burn"), "confusion": _text("混乱", "Confusion"), "foxfire": _text("狐火", "Foxfire")}
		var label := String(names.get(String(status_id), _text("异常状态", "Affliction")))
		var entry: Variant = status_bar[status_id]
		var stacks := 0.0
		if entry is Dictionary:
			stacks = float(entry.get("stacks", 0.0))
		_add_row(_status_section, label, "× %d" % int(stacks))


func _item_display_name(item_id: String) -> String:
	if _item_names.has(item_id):
		return String(_item_names[item_id])
	var known := {"reliquary_shield": _text("圣匣盾", "Reliquary Shield"), "guardian_sword": _text("守卫直剑", "Guardian Sword"), "ember_flask": _text("余烬药瓶", "Ember Flask"), "soul_shard": _text("魂之碎片", "Soul Shard")}
	return String(known.get(item_id, _text("遗迹藏品", "Relic")))


func apply_accessibility_settings(settings: Dictionary) -> void:
	_locale = String(settings.get("locale", TranslationServer.get_locale()))
	_ui_scale = clampf(float(settings.get("ui_scale", 1.0)), .75, 1.6)
	_text_scale = clampf(float(settings.get("text_scale", 1.0)), .85, 2.)
	_theme.high_contrast = bool(settings.get("high_contrast", false))
	if _panel != null:
		_panel.theme = _theme.build_theme()
		_layout()


func _layout() -> void:
	if _scroll == null:
		return
	var viewport := get_viewport().get_visible_rect().size
	_scroll.custom_minimum_size = Vector2(minf(680. * _ui_scale, maxf(240., viewport.x - 88.)), minf(520. * _ui_scale, maxf(220., viewport.y - 88.)))
	_columns.columns = 1 if viewport.x < 760. or _text_scale > 1.35 else 2
	_scale_text(_panel)


func _scale_text(node: Node) -> void:
	if node is Label or node is Button:
		if node.has_meta("zh"):
			node.text = _text(String(node.get_meta("zh")), String(node.get_meta("en")))
		if not node.has_meta("inventory_font_size"):
			node.set_meta("inventory_font_size", node.get_theme_font_size("font_size"))
		node.add_theme_font_size_override("font_size", roundi(float(node.get_meta("inventory_font_size")) * _ui_scale * _text_scale))
		if not node.has_meta("inventory_font_color"):
			node.set_meta("inventory_font_color", node.get_theme_color("font_color"))
		node.add_theme_color_override("font_color", Color.WHITE if _theme.high_contrast else Color(node.get_meta("inventory_font_color")))
	for child in node.get_children():
		_scale_text(child)


func _bilingual(control: Control, zh: String, en: String) -> void:
	control.set_meta("zh", zh)
	control.set_meta("en", en)
	control.set("text", _text(zh, en))


func _text(zh: String, en: String) -> String:
	return ThemeScript.copy(zh, en, _locale)


func _on_close() -> void:
	if not _open:
		return
	close()
	inventory_closed.emit()
