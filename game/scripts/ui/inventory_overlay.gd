extends CanvasLayer
class_name InventoryOverlay
## L-10：背包/图鉴入口 —— 烬龛休息时打开，暂停树，展示收集战利品与当前装备状态。
## 数据只读：run_state.collected_loot + run_state.inventory（掉落统计）、player 装备与状态条。

signal inventory_closed

const LocalizationScript = preload("res://scripts/core/localization.gd")
const HandEquipmentScript = preload("res://scripts/data/hand_equipment.gd")
const StatusEffectScript = preload("res://scripts/combat/data/status_effect.gd")
const MeridianSystemScript = preload("res://scripts/player/meridian_system.gd")

var _dim: ColorRect
var _panel: PanelContainer
var _title: Label
var _loot_section: VBoxContainer
var _equip_section: VBoxContainer
var _status_section: VBoxContainer
var _open := false


func _ready() -> void:
	layer = 85
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()


func is_open() -> bool:
	return _open


func open(player: Node, run_state) -> bool:
	if player == null or run_state == null:
		return false
	_title.text = LocalizationScript.text("BACKPACK")
	_rebuild_loot(run_state)
	_rebuild_equipped(player, run_state)
	_rebuild_statuses(player)
	visible = true
	_open = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _dim != null:
		_dim.modulate.a = 0.0
		var tw := create_tween()
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(_dim, "modulate:a", 1.0, 0.25)
	return true


func close() -> void:
	_open = false
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_on_close()


func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0.02, 0.01, 0.04, 0.74)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(640, 460)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.06, 0.09, 0.97)
	style.border_color = Color(0.72, 0.45, 0.22, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 26
	style.content_margin_right = 26
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	_panel.add_child(vbox)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 28)
	_title.add_theme_color_override("font_color", Color(0.95, 0.82, 0.55))
	vbox.add_child(_title)

	var subtitle := Label.new()
	subtitle.text = LocalizationScript.text("What the hollow remembers, you carry.")
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.85, 0.8, 0.75, 0.9))
	vbox.add_child(subtitle)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 28)
	vbox.add_child(columns)

	var left_col := VBoxContainer.new()
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(left_col)
	_add_section_header(left_col, "COLLECTED")
	_loot_section = VBoxContainer.new()
	_loot_section.add_theme_constant_override("separation", 4)
	left_col.add_child(_loot_section)

	var right_col := VBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right_col)
	_add_section_header(right_col, "EQUIPPED")
	_equip_section = VBoxContainer.new()
	_equip_section.add_theme_constant_override("separation", 4)
	right_col.add_child(_equip_section)

	_add_section_header(vbox, "STATUS")
	_status_section = VBoxContainer.new()
	_status_section.add_theme_constant_override("separation", 4)
	vbox.add_child(_status_section)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	vbox.add_child(spacer)

	var close_button := Button.new()
	close_button.text = LocalizationScript.text("RETURN TO THE HOLLOW")
	close_button.custom_minimum_size = Vector2(360, 40)
	close_button.add_theme_font_size_override("font_size", 16)
	_style_button(close_button)
	close_button.pressed.connect(_on_close)
	vbox.add_child(close_button)


func _add_section_header(parent: Control, text: String) -> void:
	var header := Label.new()
	header.text = text
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
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.18, 0.12, 0.08, 0.95)
	normal.border_color = Color(0.7, 0.42, 0.18)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(8)
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
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
		empty_label.text = LocalizationScript.text("No loot gathered yet.")
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
	_add_row(_equip_section, "RIGHT", _item_display_name(right))
	_add_row(_equip_section, "LEFT", _item_display_name(left))
	var style_name := "STYLE %d" % (int(_prop(player, "combat_style", 0)) + 1)
	if player.has_method("_style_display_name"):
		style_name = String(player.call("_style_display_name"))
	_add_row(_equip_section, "STYLE", style_name)
	_add_row(_equip_section, "HP", "%d" % int(float(_prop(player, "max_health", 0.0))))
	_add_row(_equip_section, "STA", "%d" % int(float(_prop(player, "max_stamina", 0.0))))
	_add_row(_equip_section, "FOC", "%d" % int(float(_prop(player, "max_focus", 0.0))))
	var forge := 0
	if player.has_method("get_forge_level"):
		forge = int(player.call("get_forge_level"))
	var talent := 0
	if player.has_method("get_talent_points"):
		talent = int(player.call("get_talent_points"))
	var meridian_total := MeridianSystemScript.total_level(run_state.progression_values)
	_add_row(_equip_section, "FORGE", "+%d" % forge)
	_add_row(_equip_section, "TALENT", str(talent))
	_add_row(_equip_section, "MERIDIAN", str(meridian_total))


func _rebuild_statuses(player: Node) -> void:
	for child in _status_section.get_children():
		child.queue_free()
	var status_bar: Dictionary = _prop(player, "status_bar", {})
	if status_bar.is_empty():
		_add_row(_status_section, "STATUS", "CLEAN")
		return
	for status_id in status_bar.keys():
		var def: Dictionary = StatusEffectScript.STATUS_DEFS.get(status_id, {})
		var label := String(def.get("label", String(status_id)))
		var entry: Variant = status_bar[status_id]
		var stacks := 0.0
		if entry is Dictionary:
			stacks = float(entry.get("stacks", 0.0))
		_add_row(_status_section, String(status_id).to_upper(), "%s x%d" % [label, int(stacks)])


func _item_display_name(item_id: String) -> String:
	var pretty := item_id.replace("_", " ").capitalize()
	var item := HandEquipmentScript.get_item(item_id)
	if item.is_empty():
		return pretty
	var primary := String(item.get("primary_label", ""))
	if primary.is_empty():
		return pretty
	return "%s  ·  %s" % [pretty, primary]


func _on_close() -> void:
	if not _open:
		return
	close()
	inventory_closed.emit()
