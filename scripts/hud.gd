extends CanvasLayer

const COLOR_SURFACE := Color(0.022, 0.027, 0.035, 0.94)
const COLOR_SURFACE_SOFT := Color(0.035, 0.04, 0.048, 0.9)
const COLOR_BORDER := Color(0.43, 0.36, 0.24, 0.92)
const COLOR_BORDER_SOFT := Color(0.2, 0.21, 0.22, 0.9)
const COLOR_TEXT := Color(0.92, 0.88, 0.78)
const COLOR_MUTED := Color(0.61, 0.62, 0.61)
const COLOR_EMBER := Color(0.96, 0.59, 0.18)
const COLOR_HEALTH := Color(0.59, 0.065, 0.075)
const COLOR_STAMINA := Color(0.12, 0.49, 0.24)

var player: Node
var root: Control
var health_bar: ProgressBar
var stamina_bar: ProgressBar
var flask_label: Label
var embers_label: Label
var ember_panel: PanelContainer
var prompt_panel: PanelContainer
var prompt_label: Label
var message_panel: PanelContainer
var message_label: Label
var lock_label: Label
var boss_panel: PanelContainer
var boss_name_label: Label
var boss_bar: ProgressBar
var death_overlay: ColorRect
var victory_overlay: ColorRect
var pause_overlay: ColorRect
var help_overlay: ColorRect
var resume_button: Button
var back_button: Button
var lock_target: Node3D
var _message_serial := 0
var _paused_before_help := false
var _last_ember_amount := 0
var _current_prompt_text := ""
var _prompt_tween: Tween
var _message_tween: Tween
var _ember_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	_build_interface()


func setup(new_player: Node) -> void:
	player = new_player
	if player == null:
		return
	var health := _read_number(player, [&"health", &"current_health"], 1.0)
	var max_health := _read_number(player, [&"max_health", &"maximum_health"], maxf(health, 1.0))
	var stamina := _read_number(player, [&"stamina", &"current_stamina"], 1.0)
	var max_stamina := _read_number(player, [&"max_stamina", &"maximum_stamina"], maxf(stamina, 1.0))
	var flasks := int(_read_number(player, [&"flasks", &"current_flasks", &"estus"], -1.0))
	var max_flasks := int(_read_number(player, [&"max_flasks", &"maximum_flasks"], -1.0))
	update_stats(health, max_health, stamina, max_stamina, flasks, max_flasks)
	update_embers(int(_read_number(player, [&"embers", &"souls", &"currency"], 0.0)))


func update_stats(
		current_health: float,
		maximum_health: float,
		current_stamina: float,
		maximum_stamina: float,
		current_flasks: int = -1,
		maximum_flasks: int = -1
) -> void:
	if health_bar == null:
		return
	health_bar.max_value = maxf(maximum_health, 1.0)
	health_bar.value = clampf(current_health, 0.0, health_bar.max_value)
	health_bar.tooltip_text = "Health: %d / %d" % [roundi(current_health), roundi(maximum_health)]
	stamina_bar.max_value = maxf(maximum_stamina, 1.0)
	stamina_bar.value = clampf(current_stamina, 0.0, stamina_bar.max_value)
	stamina_bar.tooltip_text = "Stamina: %d / %d" % [roundi(current_stamina), roundi(maximum_stamina)]
	if current_flasks < 0:
		flask_label.visible = false
	else:
		flask_label.visible = true
		flask_label.text = "FLASK  %d" % current_flasks
		if maximum_flasks >= 0:
			flask_label.text += " / %d" % maximum_flasks


func update_embers(amount: int) -> void:
	if embers_label == null:
		return
	var safe_amount := maxi(amount, 0)
	embers_label.text = "◆  %s" % _format_number(safe_amount)
	if safe_amount != _last_ember_amount and ember_panel != null:
		_pulse_ember_panel()
	_last_ember_amount = safe_amount


func set_prompt(text: String) -> void:
	if prompt_panel == null:
		return
	var clean_text := text.strip_edges()
	if clean_text.is_empty():
		_current_prompt_text = ""
		_hide_prompt()
		return
	if clean_text == _current_prompt_text and prompt_panel.visible:
		return
	_current_prompt_text = clean_text
	prompt_label.text = clean_text
	if _prompt_tween != null and _prompt_tween.is_valid():
		_prompt_tween.kill()
	prompt_panel.visible = true
	prompt_panel.modulate.a = 0.0
	prompt_panel.scale = Vector2(0.97, 0.97)
	_prompt_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	_prompt_tween.tween_property(prompt_panel, "modulate:a", 1.0, 0.16)
	_prompt_tween.tween_property(prompt_panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func show_message(text: String, duration: float = 2.0) -> void:
	if message_label == null:
		return
	_message_serial += 1
	var serial := _message_serial
	if _message_tween != null and _message_tween.is_valid():
		_message_tween.kill()
	message_label.text = text
	message_panel.visible = not text.is_empty()
	message_panel.modulate.a = 0.0
	message_panel.scale = Vector2(0.98, 0.98)
	_message_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	_message_tween.tween_property(message_panel, "modulate:a", 1.0, 0.2)
	_message_tween.tween_property(message_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if duration <= 0.0:
		return
	await get_tree().create_timer(duration, true).timeout
	if serial != _message_serial or not is_instance_valid(message_panel):
		return
	_message_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_message_tween.tween_property(message_panel, "modulate:a", 0.0, 0.28)
	await _message_tween.finished
	if serial == _message_serial and is_instance_valid(message_panel):
		message_panel.visible = false


func set_lock_target(target: Node) -> void:
	lock_target = target as Node3D
	if lock_label != null:
		lock_label.visible = is_instance_valid(lock_target)
		_update_lock_indicator()


func show_boss(boss_name: String, current: float, maximum: float) -> void:
	if boss_panel == null:
		return
	boss_name_label.text = boss_name.to_upper()
	boss_bar.max_value = maxf(maximum, 1.0)
	boss_bar.value = clampf(current, 0.0, boss_bar.max_value)
	boss_bar.tooltip_text = "%s: %d / %d" % [boss_name, roundi(current), roundi(maximum)]
	if not boss_panel.visible:
		boss_panel.visible = true
		boss_panel.modulate.a = 0.0
		var reveal := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		reveal.tween_property(boss_panel, "modulate:a", 1.0, 0.3)


func hide_boss() -> void:
	if boss_panel != null:
		boss_panel.visible = false


func show_death() -> void:
	set_prompt("")
	set_lock_target(null)
	hide_boss()
	victory_overlay.visible = false
	_show_end_overlay(death_overlay, 1.0)


func clear_death() -> void:
	if death_overlay != null:
		death_overlay.visible = false
		death_overlay.modulate.a = 0.0


func show_victory() -> void:
	set_prompt("")
	set_lock_target(null)
	hide_boss()
	death_overlay.visible = false
	_show_end_overlay(victory_overlay, 0.8)


func is_death_visible() -> bool:
	return death_overlay != null and death_overlay.visible


func is_prompt_visible() -> bool:
	return prompt_panel != null and prompt_panel.visible


func is_boss_visible() -> bool:
	return boss_panel != null and boss_panel.visible


func _process(_delta: float) -> void:
	if lock_target != null and not is_instance_valid(lock_target):
		set_lock_target(null)
	elif lock_target != null:
		_update_lock_indicator()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key_event := event as InputEventKey
	if key_event.keycode == KEY_F1:
		_toggle_help()
		get_viewport().set_input_as_handled()
	elif key_event.keycode == KEY_ESCAPE:
		if help_overlay.visible:
			_close_help()
		else:
			_set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()


func _build_interface() -> void:
	root = Control.new()
	root.name = "HUDRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _build_theme()
	add_child(root)

	var safe_area := MarginContainer.new()
	safe_area.name = "SafeArea"
	safe_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe_area.add_theme_constant_override("margin_left", 28)
	safe_area.add_theme_constant_override("margin_top", 24)
	safe_area.add_theme_constant_override("margin_right", 28)
	safe_area.add_theme_constant_override("margin_bottom", 22)
	root.add_child(safe_area)

	var vertical_layout := VBoxContainer.new()
	vertical_layout.name = "ResponsiveLayout"
	vertical_layout.add_theme_constant_override("separation", 8)
	safe_area.add_child(vertical_layout)
	vertical_layout.add_child(_build_top_row())
	var flexible_space := Control.new()
	flexible_space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	flexible_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vertical_layout.add_child(flexible_space)
	vertical_layout.add_child(_build_boss_lane())
	vertical_layout.add_child(_build_prompt_lane())

	_build_message_lane()
	_build_lock_marker()
	death_overlay = _make_end_overlay(Color(0.11, 0.0, 0.0, 0.74), "YOU DIED", Color(0.69, 0.09, 0.09), "YOUR EMBERS REMAIN IN THE HOLLOW")
	victory_overlay = _make_end_overlay(Color(0.025, 0.045, 0.028, 0.7), "PREY VANQUISHED", Color(0.9, 0.68, 0.25), "THE SEALED HEART FALLS SILENT")
	_build_pause_overlay()
	_build_help_overlay()


func _build_top_row() -> HBoxContainer:
	var top_row := HBoxContainer.new()
	top_row.name = "TopRow"
	top_row.add_theme_constant_override("separation", 18)

	var vitals_panel := PanelContainer.new()
	vitals_panel.name = "VitalsPanel"
	vitals_panel.custom_minimum_size = Vector2(360.0, 82.0)
	vitals_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.016, 0.02, 0.027, 0.82), COLOR_BORDER_SOFT, 4, 14.0, 8.0))
	top_row.add_child(vitals_panel)

	var vitals := VBoxContainer.new()
	vitals.name = "Vitals"
	vitals.add_theme_constant_override("separation", 5)
	vitals_panel.add_child(vitals)
	vitals.add_child(_make_bar_row("VIT", COLOR_HEALTH, 21.0, true))
	vitals.add_child(_make_bar_row("END", COLOR_STAMINA, 13.0, false))
	flask_label = _make_label("FLASK  0", 13, COLOR_MUTED)
	vitals.add_child(flask_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(spacer)

	ember_panel = PanelContainer.new()
	ember_panel.name = "EmberPanel"
	ember_panel.custom_minimum_size = Vector2(190.0, 52.0)
	ember_panel.add_theme_stylebox_override("panel", _panel_style(COLOR_SURFACE, COLOR_BORDER, 5, 14.0, 7.0))
	top_row.add_child(ember_panel)
	embers_label = _make_label("◆  0", 21, COLOR_EMBER)
	embers_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	embers_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ember_panel.add_child(embers_label)
	return top_row


func _make_bar_row(caption: String, fill_color: Color, height: float, is_health: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	var caption_label := _make_label(caption, 11, COLOR_MUTED)
	caption_label.custom_minimum_size = Vector2(30.0, 0.0)
	caption_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(caption_label)
	var bar := _make_bar(fill_color, height)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(bar)
	if is_health:
		health_bar = bar
	else:
		stamina_bar = bar
	return row


func _build_boss_lane() -> CenterContainer:
	var lane := CenterContainer.new()
	lane.name = "BossLane"
	lane.custom_minimum_size.y = 68.0
	boss_panel = PanelContainer.new()
	boss_panel.name = "BossPanel"
	boss_panel.custom_minimum_size = Vector2(760.0, 62.0)
	boss_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	boss_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.012, 0.015, 0.02, 0.94), Color(0.34, 0.27, 0.2), 3, 18.0, 8.0))
	boss_panel.visible = false
	lane.add_child(boss_panel)
	var boss_box := VBoxContainer.new()
	boss_box.add_theme_constant_override("separation", 4)
	boss_panel.add_child(boss_box)
	boss_name_label = _make_label("BOSS", 15, COLOR_TEXT)
	boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_box.add_child(boss_name_label)
	boss_bar = _make_bar(Color(0.47, 0.035, 0.07), 16.0)
	boss_box.add_child(boss_bar)
	return lane


func _build_prompt_lane() -> CenterContainer:
	var lane := CenterContainer.new()
	lane.name = "PromptLane"
	lane.custom_minimum_size.y = 58.0
	prompt_panel = PanelContainer.new()
	prompt_panel.name = "PromptPanel"
	prompt_panel.custom_minimum_size = Vector2(440.0, 48.0)
	prompt_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	prompt_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.012, 0.015, 0.02, 0.93), COLOR_BORDER_SOFT, 5, 14.0, 7.0))
	prompt_panel.visible = false
	lane.add_child(prompt_panel)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	prompt_panel.add_child(row)
	var keycap := Label.new()
	keycap.text = "E"
	keycap.custom_minimum_size = Vector2(32.0, 30.0)
	keycap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	keycap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	keycap.add_theme_font_size_override("font_size", 15)
	keycap.add_theme_color_override("font_color", COLOR_EMBER)
	keycap.add_theme_stylebox_override("normal", _panel_style(Color(0.08, 0.07, 0.045, 0.96), COLOR_BORDER, 4, 4.0, 2.0))
	keycap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(keycap)
	prompt_label = _make_label("", 17, COLOR_TEXT)
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(prompt_label)
	return lane


func _build_message_lane() -> void:
	var top_margin := MarginContainer.new()
	top_margin.name = "MessageSafeArea"
	top_margin.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_margin.offset_top = 108.0
	top_margin.offset_bottom = 188.0
	top_margin.add_theme_constant_override("margin_left", 24)
	top_margin.add_theme_constant_override("margin_right", 24)
	top_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top_margin)
	var lane := CenterContainer.new()
	top_margin.add_child(lane)
	message_panel = PanelContainer.new()
	message_panel.name = "MessagePanel"
	message_panel.custom_minimum_size = Vector2(360.0, 54.0)
	message_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.01, 0.013, 0.018, 0.76), Color(0.28, 0.24, 0.17, 0.72), 3, 20.0, 8.0))
	message_panel.visible = false
	lane.add_child(message_panel)
	message_label = _make_label("", 21, COLOR_TEXT)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	message_label.add_theme_constant_override("shadow_offset_x", 2)
	message_label.add_theme_constant_override("shadow_offset_y", 2)
	message_panel.add_child(message_label)


func _build_lock_marker() -> void:
	lock_label = _make_label("◈", 32, COLOR_EMBER)
	lock_label.name = "LockMarker"
	lock_label.custom_minimum_size = Vector2(46.0, 46.0)
	lock_label.size = Vector2(46.0, 46.0)
	lock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lock_label.add_theme_color_override("font_shadow_color", Color(0.02, 0.01, 0.0, 0.95))
	lock_label.add_theme_constant_override("shadow_offset_x", 2)
	lock_label.add_theme_constant_override("shadow_offset_y", 2)
	lock_label.visible = false
	root.add_child(lock_label)


func _build_pause_overlay() -> void:
	pause_overlay = _make_menu_overlay("PAUSED", "THE HOLLOW WAITS")
	var content := pause_overlay.get_node("Center/Menu/Margins/Content") as VBoxContainer
	resume_button = _make_button("RESUME")
	resume_button.pressed.connect(func() -> void: _set_paused(false))
	content.add_child(resume_button)
	var help_button := _make_button("CONTROLS")
	help_button.pressed.connect(_toggle_help)
	content.add_child(help_button)


func _build_help_overlay() -> void:
	help_overlay = _make_menu_overlay("CONTROLS", "KEYBOARD & MOUSE")
	var content := help_overlay.get_node("Center/Menu/Margins/Content") as VBoxContainer
	var controls_grid := GridContainer.new()
	controls_grid.columns = 2
	controls_grid.add_theme_constant_override("h_separation", 34)
	controls_grid.add_theme_constant_override("v_separation", 10)
	controls_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(controls_grid)
	_add_control_row(controls_grid, "MOVE", "W  A  S  D")
	_add_control_row(controls_grid, "LOOK", "MOUSE")
	_add_control_row(controls_grid, "LIGHT ATTACK", "LMB  /  J")
	_add_control_row(controls_grid, "HEAVY ATTACK", "RMB  /  K")
	_add_control_row(controls_grid, "DODGE", "SPACE")
	_add_control_row(controls_grid, "SPRINT", "SHIFT")
	_add_control_row(controls_grid, "INTERACT", "E")
	_add_control_row(controls_grid, "LOCK TARGET", "Q  /  MMB")
	var hint := _make_label("Esc  Pause     F1  Toggle controls", 13, COLOR_MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(hint)
	back_button = _make_button("BACK")
	back_button.pressed.connect(_close_help)
	content.add_child(back_button)


func _add_control_row(grid: GridContainer, action: String, binding: String) -> void:
	var action_label := _make_label(action, 14, COLOR_MUTED)
	action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	grid.add_child(action_label)
	var binding_label := _make_label(binding, 15, COLOR_TEXT)
	grid.add_child(binding_label)


func _make_bar(fill_color: Color, height: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0.0, height)
	bar.show_percentage = false
	bar.value = 100.0
	bar.add_theme_stylebox_override("background", _panel_style(Color(0.018, 0.02, 0.024, 0.98), Color(0.16, 0.17, 0.18), 2, 2.0, 2.0))
	bar.add_theme_stylebox_override("fill", _panel_style(fill_color, fill_color.lightened(0.14), 2, 2.0, 2.0))
	return bar


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(240.0, 42.0)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_ALL
	return button


func _make_end_overlay(color: Color, title: String, title_color: Color, subtitle: String) -> ColorRect:
	var overlay := ColorRect.new()
	overlay.color = color
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.visible = false
	root.add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 12)
	center.add_child(content)
	var title_label := _make_label(title, 54, title_color)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	title_label.add_theme_constant_override("shadow_offset_x", 3)
	title_label.add_theme_constant_override("shadow_offset_y", 3)
	content.add_child(title_label)
	var divider := HSeparator.new()
	divider.custom_minimum_size = Vector2(520.0, 1.0)
	content.add_child(divider)
	var subtitle_label := _make_label(subtitle, 14, COLOR_MUTED)
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(subtitle_label)
	return overlay


func _make_menu_overlay(title: String, eyebrow: String) -> ColorRect:
	var overlay := ColorRect.new()
	overlay.color = Color(0.004, 0.006, 0.009, 0.84)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	root.add_child(overlay)
	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var menu := PanelContainer.new()
	menu.name = "Menu"
	menu.custom_minimum_size = Vector2(520.0, 0.0)
	menu.add_theme_stylebox_override("panel", _panel_style(COLOR_SURFACE, COLOR_BORDER, 7, 0.0, 0.0))
	center.add_child(menu)
	var margins := MarginContainer.new()
	margins.name = "Margins"
	margins.add_theme_constant_override("margin_left", 38)
	margins.add_theme_constant_override("margin_top", 32)
	margins.add_theme_constant_override("margin_right", 38)
	margins.add_theme_constant_override("margin_bottom", 32)
	menu.add_child(margins)
	var content := VBoxContainer.new()
	content.name = "Content"
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 16)
	margins.add_child(content)
	var eyebrow_label := _make_label(eyebrow, 12, COLOR_MUTED)
	eyebrow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(eyebrow_label)
	var title_label := _make_label(title, 34, COLOR_EMBER)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title_label)
	var divider := HSeparator.new()
	divider.custom_minimum_size = Vector2(420.0, 1.0)
	content.add_child(divider)
	return overlay


func _build_theme() -> Theme:
	var interface_theme := Theme.new()
	interface_theme.set_color("font_color", "Label", COLOR_TEXT)
	interface_theme.set_font_size("font_size", "Label", 16)
	interface_theme.set_color("font_color", "Button", COLOR_TEXT)
	interface_theme.set_color("font_hover_color", "Button", Color.WHITE)
	interface_theme.set_color("font_focus_color", "Button", Color.WHITE)
	interface_theme.set_font_size("font_size", "Button", 16)
	interface_theme.set_stylebox("normal", "Button", _panel_style(Color(0.055, 0.06, 0.07, 0.97), COLOR_BORDER_SOFT, 4, 12.0, 7.0))
	interface_theme.set_stylebox("hover", "Button", _panel_style(Color(0.12, 0.09, 0.045, 0.99), COLOR_BORDER, 4, 12.0, 7.0))
	interface_theme.set_stylebox("pressed", "Button", _panel_style(Color(0.16, 0.1, 0.04, 0.99), COLOR_EMBER.darkened(0.2), 4, 12.0, 7.0))
	interface_theme.set_stylebox("focus", "Button", _outline_style(COLOR_EMBER, 4, 2))
	interface_theme.set_stylebox("separator", "HSeparator", _line_style(Color(0.38, 0.31, 0.2, 0.7)))
	return interface_theme


func _panel_style(background: Color, border: Color, radius: int, horizontal_margin: float = 12.0, vertical_margin: float = 5.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = horizontal_margin
	style.content_margin_right = horizontal_margin
	style.content_margin_top = vertical_margin
	style.content_margin_bottom = vertical_margin
	return style


func _outline_style(color: Color, radius: int, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = color
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.expand_margin_left = 2.0
	style.expand_margin_top = 2.0
	style.expand_margin_right = 2.0
	style.expand_margin_bottom = 2.0
	return style


func _line_style(color: Color) -> StyleBoxLine:
	var style := StyleBoxLine.new()
	style.color = color
	style.thickness = 1
	style.vertical = false
	return style


func _show_end_overlay(overlay: ColorRect, duration: float) -> void:
	overlay.visible = true
	overlay.modulate.a = 0.0
	var fade := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade.tween_property(overlay, "modulate:a", 1.0, duration)


func _hide_prompt() -> void:
	if not prompt_panel.visible:
		return
	if _prompt_tween != null and _prompt_tween.is_valid():
		_prompt_tween.kill()
	_prompt_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_prompt_tween.tween_property(prompt_panel, "modulate:a", 0.0, 0.12)
	await _prompt_tween.finished
	if is_instance_valid(prompt_panel) and prompt_panel.modulate.a <= 0.01:
		prompt_panel.visible = false


func _pulse_ember_panel() -> void:
	if _ember_tween != null and _ember_tween.is_valid():
		_ember_tween.kill()
	ember_panel.pivot_offset = ember_panel.size * 0.5
	ember_panel.scale = Vector2.ONE
	_ember_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_ember_tween.tween_property(ember_panel, "scale", Vector2(1.045, 1.045), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_ember_tween.tween_property(ember_panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func _set_paused(paused: bool) -> void:
	if help_overlay.visible:
		help_overlay.visible = false
	pause_overlay.visible = paused
	get_tree().paused = paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED
	if paused and resume_button != null:
		resume_button.grab_focus()


func _toggle_help() -> void:
	if help_overlay.visible:
		_close_help()
		return
	_paused_before_help = get_tree().paused
	pause_overlay.visible = false
	help_overlay.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if back_button != null:
		back_button.grab_focus()


func _close_help() -> void:
	help_overlay.visible = false
	get_tree().paused = _paused_before_help
	pause_overlay.visible = _paused_before_help
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _paused_before_help else Input.MOUSE_MODE_CAPTURED
	if _paused_before_help and resume_button != null:
		resume_button.grab_focus()


func _update_lock_indicator() -> void:
	if lock_label == null or not is_instance_valid(lock_target):
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null or camera.is_position_behind(lock_target.global_position):
		lock_label.visible = false
		return
	lock_label.visible = true
	lock_label.position = camera.unproject_position(lock_target.global_position) - lock_label.size * 0.5


func _format_number(value: int) -> String:
	var digits := str(value)
	var formatted := ""
	while digits.length() > 3:
		formatted = "," + digits.right(3) + formatted
		digits = digits.left(digits.length() - 3)
	return digits + formatted


func _read_number(object: Object, names: Array[StringName], fallback: float) -> float:
	for property in object.get_property_list():
		var property_name := StringName(property.get("name", ""))
		if property_name in names:
			var value: Variant = object.get(property_name)
			if value is int or value is float:
				return float(value)
	return fallback
