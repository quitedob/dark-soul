extends CanvasLayer
class_name FastTravelOverlay
## L-12：快速旅行菜单 —— 从烬龛休息打开，选择已激活祠堂进行跨烬龛传送。
## game_world 构建目的地列表（shrine_id → level_id → display_name），本菜单只负责渲染与选择。

signal destination_selected(level_id: String)
signal travel_cancelled

const LocalizationScript = preload("res://scripts/core/localization.gd")

var _dim: ColorRect
var _panel: PanelContainer
var _title: Label
var _subtitle: Label
var _list: VBoxContainer
var _open := false


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()


func is_open() -> bool:
	return _open


func open(destinations: Array[Dictionary], current_level_id: String) -> bool:
	if destinations.is_empty():
		return false
	_title.text = LocalizationScript.text("FAST TRAVEL")
	_subtitle.text = LocalizationScript.text("The ember paths join. Choose a shrine.")
	_rebuild_buttons(destinations, current_level_id)
	visible = true
	_open = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# CanvasLayer 无 modulate；淡入挂在遮罩 Control 上
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
		close()
		travel_cancelled.emit()


func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0.02, 0.01, 0.04, 0.72)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(460, 300)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.06, 0.09, 0.96)
	style.border_color = Color(0.72, 0.45, 0.22, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	_panel.add_child(vbox)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 26)
	_title.add_theme_color_override("font_color", Color(0.95, 0.82, 0.55))
	vbox.add_child(_title)

	_subtitle = Label.new()
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.add_theme_font_size_override("font_size", 15)
	_subtitle.add_theme_color_override("font_color", Color(0.85, 0.8, 0.75, 0.9))
	vbox.add_child(_subtitle)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	vbox.add_child(_list)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	vbox.add_child(spacer)

	var close_button := Button.new()
	close_button.text = LocalizationScript.text("STAY AT THIS SHRINE")
	close_button.custom_minimum_size = Vector2(380, 40)
	close_button.add_theme_font_size_override("font_size", 16)
	_style_button(close_button)
	close_button.pressed.connect(_on_cancel)
	vbox.add_child(close_button)


func _rebuild_buttons(destinations: Array[Dictionary], current_level_id: String) -> void:
	for child in _list.get_children():
		child.queue_free()
	var has_option := false
	for dest in destinations:
		var level_id := String(dest.get("level_id", ""))
		if level_id.is_empty() or level_id == current_level_id:
			continue
		has_option = true
		var label := String(dest.get("display_name", level_id))
		var btn := _make_destination_button(label, level_id)
		_list.add_child(btn)
	if not has_option:
		var none_label := Label.new()
		none_label.text = LocalizationScript.text("No other shrines are lit.")
		none_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		none_label.add_theme_font_size_override("font_size", 15)
		none_label.add_theme_color_override("font_color", Color(0.7, 0.68, 0.62))
		_list.add_child(none_label)


func _make_destination_button(label: String, level_id: String) -> Button:
	var btn := Button.new()
	btn.text = LocalizationScript.text(label)
	btn.custom_minimum_size = Vector2(380, 44)
	btn.add_theme_font_size_override("font_size", 17)
	_style_button(btn)
	btn.pressed.connect(func() -> void: _on_destination(level_id))
	return btn


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


func _on_destination(level_id: String) -> void:
	if not _open:
		return
	close()
	destination_selected.emit(level_id)


func _on_cancel() -> void:
	if not _open:
		return
	close()
	travel_cancelled.emit()
