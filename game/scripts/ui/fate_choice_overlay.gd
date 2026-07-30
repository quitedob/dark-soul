extends CanvasLayer
class_name FateChoiceOverlay
## 命运选择模态：暂停树，写入字符串旗标

signal choice_made(story_flag: StringName, value: String)

const FateCatalog = preload("res://scripts/combat/data/boss_fate_catalog.gd")
const LocalizationScript = preload("res://scripts/core/localization.gd")

var _dim: ColorRect
var _panel: PanelContainer
var _title: Label
var _subtitle: Label
var _buttons: VBoxContainer
var _story_flag: StringName = &""
var _open := false


func _ready() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()


func open_for_flag(story_flag: StringName) -> bool:
	var entry: Dictionary = FateCatalog.entry_for_flag(story_flag)
	if entry.is_empty():
		return false
	_story_flag = story_flag
	_title.text = LocalizationScript.text(String(entry.get("title", "FATE")))
	_subtitle.text = LocalizationScript.text(String(entry.get("subtitle", "")))
	_rebuild_buttons(entry.get("options", []))
	visible = true
	_open = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	modulate.a = 0.0
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(self, "modulate:a", 1.0, 0.25)
	return true


func is_open() -> bool:
	return _open


func close() -> void:
	_open = false
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0.02, 0.01, 0.03, 0.72)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(420, 280)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.1, 0.96)
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
	vbox.add_theme_constant_override("separation", 14)
	_panel.add_child(vbox)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 28)
	_title.add_theme_color_override("font_color", Color(0.95, 0.82, 0.55))
	vbox.add_child(_title)

	_subtitle = Label.new()
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.add_theme_font_size_override("font_size", 16)
	_subtitle.add_theme_color_override("font_color", Color(0.85, 0.8, 0.75, 0.9))
	vbox.add_child(_subtitle)

	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 10)
	vbox.add_child(_buttons)


func _rebuild_buttons(options: Array) -> void:
	for child in _buttons.get_children():
		child.queue_free()
	for opt in options:
		var value := String(opt.get("id", ""))
		var label := String(opt.get("label", value))
		var hint := String(opt.get("hint", ""))
		var btn := _make_option_button("%s\n%s" % [label, hint], value)
		_buttons.add_child(btn)


func _make_option_button(text: String, value: String) -> Button:
	var btn := Button.new()
	btn.text = LocalizationScript.text(text)
	btn.custom_minimum_size = Vector2(340, 56)
	btn.add_theme_font_size_override("font_size", 18)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.18, 0.12, 0.08, 0.95)
	normal.border_color = Color(0.7, 0.42, 0.18)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(8)
	normal.content_margin_top = 10
	normal.content_margin_bottom = 10
	btn.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.28, 0.18, 0.1, 0.98)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.12, 0.08, 0.05, 1.0)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.pivot_offset = Vector2(170, 28)
	btn.mouse_entered.connect(func() -> void:
		var t := btn.create_tween()
		t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		t.tween_property(btn, "scale", Vector2(1.04, 1.04), 0.08)
	)
	btn.mouse_exited.connect(func() -> void:
		var t := btn.create_tween()
		t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		t.tween_property(btn, "scale", Vector2.ONE, 0.08)
	)
	btn.pressed.connect(func() -> void: _on_choice(value))
	return btn


func _on_choice(value: String) -> void:
	if not _open:
		return
	var flag := _story_flag
	close()
	choice_made.emit(flag, value)
