# game/scripts/ui/dialogue_overlay.gd
extends CanvasLayer
class_name DialogueOverlay
## 极简对白面板：逐行显示，结束后发信号

signal dialogue_finished(dialogue_id: StringName)

var _dim: ColorRect
var _label: Label
var _hint: Label
var _lines: PackedStringArray = []
var _index := 0
var _dialogue_id: StringName = &""
var _open := false


func _ready() -> void:
	layer = 75
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()


## 打开对白；空台词直接结束
func open_lines(dialogue_id: StringName, lines: PackedStringArray) -> void:
	_dialogue_id = dialogue_id
	_lines = lines
	_index = 0
	if _lines.is_empty():
		dialogue_finished.emit(_dialogue_id)
		return
	_show_current()
	visible = true
	_open = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func is_open() -> bool:
	return _open


func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0.02, 0.02, 0.04, 0.55)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.gui_input.connect(_on_gui_input)
	add_child(_dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -160.0
	panel.offset_left = 40.0
	panel.offset_right = -40.0
	panel.offset_bottom = -24.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.06, 0.09, 0.94)
	style.border_color = Color(0.55, 0.42, 0.28, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(_label)
	_hint = Label.new()
	_hint.text = "[E / Click] 继续"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.modulate = Color(0.7, 0.65, 0.55)
	vbox.add_child(_hint)


func _show_current() -> void:
	if _index < 0 or _index >= _lines.size():
		return
	_label.text = String(_lines[_index])


func _advance() -> void:
	_index += 1
	if _index >= _lines.size():
		_close_and_finish()
		return
	_show_current()


func _close_and_finish() -> void:
	_open = false
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	dialogue_finished.emit(_dialogue_id)


func _on_gui_input(event: InputEvent) -> void:
	if not _open:
		return
	if event is InputEventMouseButton and event.pressed:
		_advance()


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		_advance()
		get_viewport().set_input_as_handled()
