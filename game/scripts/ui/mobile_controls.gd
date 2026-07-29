extends Control

signal pause_requested

const LocalizationScript = preload("res://scripts/core/localization.gd")
const MIN_TOUCH_SIZE := 48.0
const STICK_RADIUS := 58.0
const SPRINT_HOLD_SECONDS := 0.32

var _ui_scale := 1.0
var _control_opacity := 0.78
var _locale := "en"
var _stick_pointer := -1
var _camera_pointer := -1
var _stick_center := Vector2.ZERO
var _dash_held := false
var _dash_hold_time := 0.0
var _sprinting := false

var _stick_zone: Control
var _stick_ring: Panel
var _stick_knob: Panel
var _camera_zone: Control
var _action_cluster: Control
var _utility_cluster: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ensure_actions()
	_build_controls()
	set_ui_scale(_ui_scale)
	set_control_opacity(_control_opacity)


func _exit_tree() -> void:
	_release_movement()
	_release_action(&"sprint")


func set_ui_scale(value: float) -> void:
	_ui_scale = clampf(value, 0.75, 1.6)
	if _stick_zone == null:
		return
	var stick_size := Vector2(156.0, 156.0) * _ui_scale
	_stick_zone.custom_minimum_size = stick_size
	_stick_zone.offset_left = 18.0 * _ui_scale
	_stick_zone.offset_bottom = -18.0 * _ui_scale
	_stick_zone.offset_right = _stick_zone.offset_left + stick_size.x
	_stick_zone.offset_top = _stick_zone.offset_bottom - stick_size.y
	_stick_ring.size = Vector2.ONE * STICK_RADIUS * 2.0 * _ui_scale
	_stick_ring.position = (stick_size - _stick_ring.size) * 0.5
	_stick_knob.size = Vector2.ONE * 54.0 * _ui_scale
	_stick_knob.position = (stick_size - _stick_knob.size) * 0.5
	_layout_action_buttons()
	_layout_utility_buttons()


func set_control_opacity(value: float) -> void:
	_control_opacity = clampf(value, 0.35, 1.0)
	modulate.a = _control_opacity


func set_locale(locale: String) -> void:
	_locale = String(LocalizationScript.normalize_locale(locale))
	for button in find_children("*", "Button", true, false):
		if button.has_meta("source_text"):
			button.text = LocalizationScript.text(
				String(button.get_meta("source_text")),
				_locale
			)


func _process(delta: float) -> void:
	if not _dash_held or _sprinting:
		return
	_dash_hold_time += delta
	if _dash_hold_time >= SPRINT_HOLD_SECONDS:
		_sprinting = true
		_press_action(&"sprint")


func _build_controls() -> void:
	_camera_zone = Control.new()
	_camera_zone.name = "CameraDragZone"
	_camera_zone.set_anchors_preset(Control.PRESET_FULL_RECT)
	_camera_zone.anchor_left = 0.42
	_camera_zone.mouse_filter = Control.MOUSE_FILTER_STOP
	_camera_zone.gui_input.connect(_on_camera_input)
	add_child(_camera_zone)

	_stick_zone = Control.new()
	_stick_zone.name = "MoveStick"
	_stick_zone.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_stick_zone.mouse_filter = Control.MOUSE_FILTER_STOP
	_stick_zone.gui_input.connect(_on_stick_input)
	add_child(_stick_zone)

	_stick_ring = Panel.new()
	_stick_ring.name = "Ring"
	_stick_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stick_ring.add_theme_stylebox_override("panel", _circle_style(Color(0.04, 0.05, 0.065, 0.64), Color(0.84, 0.56, 0.22, 0.78), 3))
	_stick_zone.add_child(_stick_ring)

	_stick_knob = Panel.new()
	_stick_knob.name = "Knob"
	_stick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stick_knob.add_theme_stylebox_override("panel", _circle_style(Color(0.72, 0.42, 0.14, 0.82), Color(1.0, 0.78, 0.39, 0.95), 2))
	_stick_zone.add_child(_stick_knob)

	_action_cluster = Control.new()
	_action_cluster.name = "CombatButtons"
	_action_cluster.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_action_cluster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_action_cluster)
	_add_action_button(_action_cluster, "LIGHT", &"light_attack", Vector2.ZERO)
	_add_action_button(_action_cluster, "HEAVY", &"heavy_attack", Vector2.ZERO)
	var dash := _make_button("DODGE\nSPRINT")
	dash.name = "DodgeSprint"
	dash.button_down.connect(_on_dash_down)
	dash.button_up.connect(_on_dash_up)
	_action_cluster.add_child(dash)

	_utility_cluster = Control.new()
	_utility_cluster.name = "UtilityButtons"
	_utility_cluster.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_utility_cluster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_utility_cluster)
	_add_action_button(_utility_cluster, "LOCK", &"lock_on", Vector2.ZERO)
	_add_action_button(_utility_cluster, "USE", &"interact", Vector2.ZERO)
	_add_action_button(_utility_cluster, "GUARD", &"guard", Vector2.ZERO)
	_add_action_button(_utility_cluster, "STYLE", &"cycle_style", Vector2.ZERO)
	_add_action_button(_utility_cluster, "SKILL", &"special_attack", Vector2.ZERO)
	var pause := _make_button("II")
	pause.name = "Pause"
	pause.pressed.connect(_on_pause_pressed)
	_utility_cluster.add_child(pause)


func _layout_action_buttons() -> void:
	if _action_cluster == null:
		return
	var button_size := Vector2(72.0, 64.0) * _ui_scale
	var gap := 10.0 * _ui_scale
	var cluster_size := Vector2(button_size.x * 2.0 + gap, button_size.y * 2.0 + gap)
	_action_cluster.size = cluster_size
	_action_cluster.offset_right = -18.0 * _ui_scale
	_action_cluster.offset_bottom = -18.0 * _ui_scale
	_action_cluster.offset_left = _action_cluster.offset_right - cluster_size.x
	_action_cluster.offset_top = _action_cluster.offset_bottom - cluster_size.y
	var light := _action_cluster.get_node("LIGHT") as Button
	var heavy := _action_cluster.get_node("HEAVY") as Button
	var dash := _action_cluster.get_node("DodgeSprint") as Button
	_set_button_rect(light, Vector2(button_size.x + gap, 0.0), button_size)
	_set_button_rect(heavy, Vector2(0.0, button_size.y + gap), button_size)
	_set_button_rect(dash, Vector2(button_size.x + gap, button_size.y + gap), button_size)


func _layout_utility_buttons() -> void:
	if _utility_cluster == null:
		return
	var button_size := Vector2(58.0, 50.0) * _ui_scale
	var gap := 8.0 * _ui_scale
	var cluster_size := Vector2(button_size.x * 3.0 + gap * 2.0, button_size.y * 2.0 + gap)
	_utility_cluster.size = cluster_size
	_utility_cluster.offset_right = -16.0 * _ui_scale
	_utility_cluster.offset_top = 16.0 * _ui_scale
	_utility_cluster.offset_left = _utility_cluster.offset_right - cluster_size.x
	_utility_cluster.offset_bottom = _utility_cluster.offset_top + cluster_size.y
	_set_button_rect(_utility_cluster.get_node("LOCK") as Button, Vector2.ZERO, button_size)
	_set_button_rect(_utility_cluster.get_node("USE") as Button, Vector2(button_size.x + gap, 0.0), button_size)
	_set_button_rect(_utility_cluster.get_node("Pause") as Button, Vector2((button_size.x + gap) * 2.0, 0.0), button_size)
	_set_button_rect(_utility_cluster.get_node("GUARD") as Button, Vector2(0.0, button_size.y + gap), button_size)
	_set_button_rect(_utility_cluster.get_node("STYLE") as Button, Vector2(button_size.x + gap, button_size.y + gap), button_size)
	_set_button_rect(_utility_cluster.get_node("SKILL") as Button, Vector2((button_size.x + gap) * 2.0, button_size.y + gap), button_size)


func _set_button_rect(button: Button, at: Vector2, button_size: Vector2) -> void:
	button.position = at
	button.size = Vector2(maxf(button_size.x, MIN_TOUCH_SIZE), maxf(button_size.y, MIN_TOUCH_SIZE))
	button.add_theme_font_size_override("font_size", maxi(12, roundi(13.0 * _ui_scale)))


func _add_action_button(parent: Control, caption: String, action: StringName, _at: Vector2) -> void:
	var button := _make_button(caption)
	button.name = caption
	button.button_down.connect(_press_action.bind(action))
	button.button_up.connect(_release_action.bind(action))
	parent.add_child(button)


func _make_button(caption: String) -> Button:
	var button := Button.new()
	button.text = caption
	button.set_meta("source_text", caption)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.add_theme_stylebox_override("normal", _button_style(Color(0.035, 0.04, 0.052, 0.86), Color(0.57, 0.39, 0.19, 0.9)))
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.4, 0.19, 0.055, 0.96), Color(1.0, 0.69, 0.25, 1.0)))
	button.add_theme_stylebox_override("hover", _button_style(Color(0.1, 0.075, 0.045, 0.92), Color(0.82, 0.55, 0.23, 0.95)))
	return button


func _on_stick_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _stick_pointer < 0:
			_stick_pointer = touch.index
			_stick_center = touch.position
			_update_stick(touch.position)
			accept_event()
		elif not touch.pressed and touch.index == _stick_pointer:
			_stick_pointer = -1
			_release_movement()
			_center_stick_knob()
			accept_event()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _stick_pointer:
			_update_stick(drag.position)
			accept_event()
	elif event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			if mouse_button.pressed:
				_stick_pointer = -2
				_stick_center = mouse_button.position
				_update_stick(mouse_button.position)
			else:
				_stick_pointer = -1
				_release_movement()
				_center_stick_knob()
			accept_event()
	elif event is InputEventMouseMotion and _stick_pointer == -2:
		_update_stick((event as InputEventMouseMotion).position)
		accept_event()


func _update_stick(pointer_position: Vector2) -> void:
	var local_center := _stick_zone.size * 0.5
	var delta := pointer_position - _stick_center
	var radius := STICK_RADIUS * _ui_scale
	var vector := delta.limit_length(radius) / maxf(radius, 1.0)
	_apply_axis(&"move_left", &"move_right", vector.x)
	_apply_axis(&"move_forward", &"move_back", vector.y)
	_stick_knob.position = local_center - _stick_knob.size * 0.5 + vector * radius


func _center_stick_knob() -> void:
	_stick_knob.position = (_stick_zone.size - _stick_knob.size) * 0.5


func _apply_axis(negative_action: StringName, positive_action: StringName, value: float) -> void:
	if value < -0.08:
		Input.action_press(negative_action, -value)
	else:
		Input.action_release(negative_action)
	if value > 0.08:
		Input.action_press(positive_action, value)
	else:
		Input.action_release(positive_action)


func _release_movement() -> void:
	for action in [&"move_left", &"move_right", &"move_forward", &"move_back"]:
		_release_action(action)


func _on_camera_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _camera_pointer < 0:
			_camera_pointer = touch.index
			accept_event()
		elif not touch.pressed and touch.index == _camera_pointer:
			_camera_pointer = -1
			accept_event()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _camera_pointer:
			_dispatch_camera_motion(drag.relative)
			accept_event()
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_dispatch_camera_motion((event as InputEventMouseMotion).relative)
		accept_event()


func _dispatch_camera_motion(relative: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.relative = relative
	motion.screen_relative = relative
	Input.parse_input_event(motion)


func _on_dash_down() -> void:
	_dash_held = true
	_dash_hold_time = 0.0
	_sprinting = false


func _on_dash_up() -> void:
	if not _dash_held:
		return
	_dash_held = false
	if _sprinting:
		_release_action(&"sprint")
		_sprinting = false
	else:
		_pulse_action(&"dodge")


func _on_pause_pressed() -> void:
	_pulse_action(&"pause")
	pause_requested.emit()


func _pulse_action(action: StringName) -> void:
	_press_action(action)
	get_tree().create_timer(0.08, true).timeout.connect(_release_action.bind(action), CONNECT_ONE_SHOT)


func _press_action(action: StringName) -> void:
	Input.action_press(action)


func _release_action(action: StringName) -> void:
	Input.action_release(action)


func _ensure_actions() -> void:
	for action in [
		&"move_left", &"move_right", &"move_forward", &"move_back",
		&"light_attack", &"heavy_attack", &"dodge", &"sprint",
		&"lock_on", &"interact", &"pause", &"guard",
		&"cycle_style", &"special_attack"
	]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)


func _circle_style(background: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(999)
	return style


func _button_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	return style
