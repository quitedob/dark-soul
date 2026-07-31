extends CanvasLayer

signal locale_requested(locale: String)
signal play_started
signal combat_tip_mode_requested(enabled: bool)

const MobileControlsScript = preload("res://scripts/ui/mobile_controls.gd")
const LocalizationScript = preload("res://scripts/core/localization.gd")
const InterfaceFont = preload("res://assets/fonts/NotoSansCJKsc-AshenHollow.otf")
const HudThemeScript = preload("res://scripts/ui/hud_theme.gd")

const COLOR_SURFACE := Color(0.022, 0.027, 0.035, 0.94)
const COLOR_SURFACE_SOFT := Color(0.035, 0.04, 0.048, 0.9)
const COLOR_BORDER := Color(0.43, 0.36, 0.24, 0.92)
const COLOR_BORDER_SOFT := Color(0.2, 0.21, 0.22, 0.9)
const COLOR_TEXT := Color(0.92, 0.88, 0.78)
const COLOR_MUTED := Color(0.61, 0.62, 0.61)
const COLOR_EMBER := Color(0.96, 0.59, 0.18)
const COLOR_HEALTH := Color(0.59, 0.065, 0.075)
const COLOR_STAMINA := Color(0.12, 0.49, 0.24)
const COLOR_FOCUS := Color(0.16, 0.34, 0.72)
const STYLE_SOURCE_NAMES := [
	"RELIQUARY GUARD",
	"TWIN COLOSSI",
	"CRESCENT PAIR",
	"VEILCRAFT",
	"EMBER RITE",
]

var player: Node
var root: Control
var safe_area: MarginContainer
var top_row: HBoxContainer
var vitals_panel: PanelContainer
var health_bar: ProgressBar
var stamina_bar: ProgressBar
var focus_bar: ProgressBar
var poise_bar: ProgressBar
var poise_row: Control
var charge_bar: ProgressBar
var charge_row: Control
var health_value_label: Label
var stamina_value_label: Label
var focus_value_label: Label
var style_label: Label
var embers_label: Label
var ember_panel: PanelContainer
var prompt_panel: PanelContainer
var prompt_label: Label
var message_panel: PanelContainer
var message_label: Label
var buffer_debug_label: Label  # B-03：输入缓冲 debug 可视化
var lock_label: Label
var boss_panel: PanelContainer
var boss_name_label: Label
var boss_bar: ProgressBar
var death_overlay: ColorRect
var victory_overlay: ColorRect
var title_overlay: ColorRect
var pause_overlay: ColorRect
var help_overlay: ColorRect
var play_button: Button
var resume_button: Button
var back_button: Button
var combat_tip_check: CheckButton
var mobile_controls: Control
var lock_target: Node3D
var _message_serial := 0
var _paused_before_help := false
var _last_ember_amount := 0
var _current_prompt_text := ""
var _prompt_tween: Tween
var _message_tween: Tween
var _ember_tween: Tween
var _message_safe_area: MarginContainer
var _menu_panels: Array[PanelContainer] = []
var _ui_scale := 1.0
var _text_scale := 1.0
var _locale := "en"
var _reduced_motion := false
var _high_contrast := false
var _control_opacity := 0.78
var _mobile_controls_requested := false
var _theme: HudTheme


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	_theme = HudThemeScript.new()
	_mobile_controls_requested = _should_use_mobile_controls()
	_build_interface()
	root.resized.connect(_update_responsive_layout)
	_apply_accessibility_to_tree(root)
	_update_responsive_layout.call_deferred()


func setup(new_player: Node) -> void:
	player = new_player
	if player == null:
		return
	var health := _read_number(player, [&"health", &"current_health"], 1.0)
	var max_health := _read_number(player, [&"max_health", &"maximum_health"], maxf(health, 1.0))
	var stamina := _read_number(player, [&"stamina", &"current_stamina"], 1.0)
	var max_stamina := _read_number(player, [&"max_stamina", &"maximum_stamina"], maxf(stamina, 1.0))
	update_stats(health, max_health, stamina, max_stamina)
	var focus := _read_number(player, [&"focus"], 1.0)
	var max_focus := _read_number(player, [&"max_focus"], maxf(focus, 1.0))
	update_focus(focus, max_focus)
	update_embers(int(_read_number(player, [&"embers", &"souls", &"currency"], 0.0)))
	if player.has_method("get_hand_loadout") and player.has_method("get_hand_action_labels"):
		var loadout: Dictionary = player.get_hand_loadout()
		set_hands(
			String(loadout.get("right_hand", "")),
			String(loadout.get("left_hand", "")),
			player.get_hand_action_labels()
		)


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
	health_bar.tooltip_text = "%s: %d / %d" % [
		LocalizationScript.text("Health", _locale),
		roundi(current_health),
		roundi(maximum_health),
	]
	health_value_label.text = "%d / %d" % [roundi(current_health), roundi(maximum_health)]
	stamina_bar.max_value = maxf(maximum_stamina, 1.0)
	stamina_bar.value = clampf(current_stamina, 0.0, stamina_bar.max_value)
	stamina_bar.tooltip_text = "%s: %d / %d" % [
		LocalizationScript.text("Stamina", _locale),
		roundi(current_stamina),
		roundi(maximum_stamina),
	]
	stamina_value_label.text = "%d / %d" % [roundi(current_stamina), roundi(maximum_stamina)]
	# These arguments remain accepted for API compatibility; healing is checkpoint-only.
	var _unused_flask_values := Vector2i(current_flasks, maximum_flasks)


func update_embers(amount: int) -> void:
	if embers_label == null:
		return
	var safe_amount := maxi(amount, 0)
	embers_label.text = "◆  %s" % _format_number(safe_amount)
	if safe_amount != _last_ember_amount and ember_panel != null:
		_pulse_ember_panel()
	_last_ember_amount = safe_amount


func update_focus(current: float, maximum: float) -> void:
	if focus_bar == null:
		return
	focus_bar.max_value = maxf(maximum, 1.0)
	focus_bar.value = clampf(current, 0.0, focus_bar.max_value)
	focus_bar.tooltip_text = "%s: %d / %d" % [
		LocalizationScript.text("FOC", _locale),
		roundi(current),
		roundi(maximum),
	]
	focus_value_label.text = "%d / %d" % [roundi(current), roundi(maximum)]


func update_poise(current: float, maximum: float) -> void:
	if poise_bar == null or poise_row == null:
		return
	poise_bar.max_value = maxf(maximum, 1.0)
	poise_bar.value = clampf(current, 0.0, poise_bar.max_value)
	poise_bar.tooltip_text = "Poise: %d / %d" % [roundi(current), roundi(maximum)]
	poise_row.visible = current < maximum - 0.01


func update_charge_progress(ratio: float, tier: int) -> void:
	# 蓄力短条：ratio=0 隐藏
	if charge_bar == null or charge_row == null:
		return
	if ratio <= 0.001:
		charge_row.visible = false
		charge_bar.value = 0.0
		return
	charge_row.visible = true
	charge_bar.max_value = 1.0
	charge_bar.value = clampf(ratio, 0.0, 1.0)
	charge_bar.tooltip_text = "Charge T%d" % maxi(tier, 1)


func set_combat_style(style_id: int, display_name: String) -> void:
	if style_label != null:
		if style_id >= 0 and style_id < STYLE_SOURCE_NAMES.size():
			style_label.set_meta("source_text", STYLE_SOURCE_NAMES[style_id])
		style_label.text = display_name


func set_hands(right_hand_item: String, left_hand_item: String, action_labels: Dictionary) -> void:
	if style_label != null:
		style_label.set_meta("source_text", "")
		style_label.text = "R: %s  |  L: %s\nR1 %s · R2 %s · L1 %s · L2 %s" % [
			right_hand_item,
			left_hand_item,
			action_labels.get("right_primary", "R1"),
			action_labels.get("right_secondary", "R2"),
			action_labels.get("left_primary", "L1"),
			action_labels.get("left_secondary", "L2"),
		]
	if mobile_controls != null and mobile_controls.has_method("set_hand_labels"):
		mobile_controls.set_hand_labels(action_labels)


func set_prompt(text: String) -> void:
	if prompt_panel == null:
		return
	var clean_text := text.strip_edges()
	if clean_text.is_empty():
		if _current_prompt_text.is_empty():
			return
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
	if _reduced_motion:
		prompt_panel.modulate.a = 1.0
		prompt_panel.scale = Vector2.ONE
		return
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
	if _reduced_motion:
		message_panel.modulate.a = 1.0
		message_panel.scale = Vector2.ONE
		if duration > 0.0:
			await get_tree().create_timer(duration, true).timeout
			if serial == _message_serial and is_instance_valid(message_panel):
				message_panel.visible = false
		return
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


## B-03：显示当前输入缓冲槽（空字符串则隐藏）
func set_input_buffer_debug(text: String) -> void:
	if buffer_debug_label == null:
		return
	buffer_debug_label.text = text
	buffer_debug_label.visible = not text.is_empty()


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


func update_execution_break(current: float, maximum: float) -> void:
	# Boss 处决槽提示挂在 boss bar tooltip
	if boss_bar == null:
		return
	var tip := String(boss_bar.tooltip_text)
	var base := tip.split(" | ")[0] if " | " in tip else tip
	if maximum <= 0.0:
		boss_bar.tooltip_text = base
		return
	boss_bar.tooltip_text = "%s | Break %d / %d" % [base, roundi(current), roundi(maximum)]


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


func show_title(has_save: bool) -> void:
	if title_overlay == null:
		return
	get_tree().paused = true
	title_overlay.visible = true
	var source_text := "CONTINUE" if has_save else "BEGIN JOURNEY"
	play_button.set_meta("source_text", source_text)
	play_button.text = LocalizationScript.text(source_text, _locale)
	if mobile_controls != null:
		mobile_controls.visible = false
	play_button.grab_focus()


func _process(_delta: float) -> void:
	if lock_target != null and not is_instance_valid(lock_target):
		set_lock_target(null)
	elif lock_target != null:
		_update_lock_indicator()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if title_overlay != null and title_overlay.visible:
		return
	if event.is_action_pressed("help"):
		_toggle_help()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
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

	safe_area = MarginContainer.new()
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
	_build_buffer_debug_label()
	_build_lock_marker()
	_build_mobile_controls()
	death_overlay = _make_end_overlay(Color(0.11, 0.0, 0.0, 0.74), "THE RELIQUARY ENDURES", Color(0.78, 0.18, 0.12), "YOUR SCATTERED EMBERS AWAIT")
	victory_overlay = _make_end_overlay(Color(0.025, 0.045, 0.028, 0.7), "ASHEN RELIQUARY UNSEALED", Color(0.9, 0.68, 0.25), "THE CINDER SEAL FALLS SILENT")
	_build_pause_overlay()
	_build_help_overlay()
	_build_title_overlay()


func _build_top_row() -> HBoxContainer:
	top_row = HBoxContainer.new()
	top_row.name = "TopRow"
	top_row.add_theme_constant_override("h_separation", 18)
	top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	vitals_panel = PanelContainer.new()
	vitals_panel.name = "VitalsPanel"
	vitals_panel.custom_minimum_size = Vector2(360.0, 122.0)
	vitals_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	vitals_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.016, 0.02, 0.027, 0.82), COLOR_BORDER_SOFT, 4, 14.0, 8.0))
	top_row.add_child(vitals_panel)

	var vitals := VBoxContainer.new()
	vitals.name = "Vitals"
	vitals.add_theme_constant_override("separation", 5)
	vitals_panel.add_child(vitals)
	vitals.add_child(_make_bar_row("VIT", COLOR_HEALTH, 21.0, true))
	vitals.add_child(_make_bar_row("END", COLOR_STAMINA, 13.0, false))
	vitals.add_child(_make_focus_row())
	poise_row = _make_poise_row()
	vitals.add_child(poise_row)
	charge_row = _make_charge_row()
	vitals.add_child(charge_row)

	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(top_spacer)

	ember_panel = PanelContainer.new()
	ember_panel.name = "EmberPanel"
	ember_panel.custom_minimum_size = Vector2(190.0, 52.0)
	ember_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	ember_panel.add_theme_stylebox_override("panel", _panel_style(COLOR_SURFACE, COLOR_BORDER, 5, 14.0, 7.0))
	top_row.add_child(ember_panel)
	var resource_stack := VBoxContainer.new()
	resource_stack.add_theme_constant_override("separation", 2)
	ember_panel.add_child(resource_stack)
	embers_label = _make_label("◆  0", 21, COLOR_EMBER)
	embers_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	embers_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	resource_stack.add_child(embers_label)
	style_label = _make_label(LocalizationScript.text("RELIQUARY GUARD", _locale), 12, COLOR_MUTED)
	style_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	resource_stack.add_child(style_label)
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
	var value_label := _make_label("100 / 100", 12, COLOR_TEXT)
	value_label.custom_minimum_size = Vector2(76.0, 0.0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(value_label)
	if is_health:
		health_bar = bar
		health_value_label = value_label
	else:
		stamina_bar = bar
		stamina_value_label = value_label
	return row


func _make_poise_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	var caption_label := _make_label("POI", 10, COLOR_MUTED)
	caption_label.custom_minimum_size = Vector2(30.0, 0.0)
	row.add_child(caption_label)
	poise_bar = _make_bar(Color("d9903d"), 7.0)
	poise_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(poise_bar)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(76.0, 0.0)
	row.add_child(spacer)
	row.visible = false
	return row


func _make_charge_row() -> HBoxContainer:
	# 蓄力三档进度条（短）
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	var caption_label := _make_label("CHG", 10, COLOR_MUTED)
	caption_label.custom_minimum_size = Vector2(30.0, 0.0)
	row.add_child(caption_label)
	charge_bar = _make_bar(Color("c9a35a"), 7.0)
	charge_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(charge_bar)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(76.0, 0.0)
	row.add_child(spacer)
	row.visible = false
	return row


func _make_focus_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	var caption_label := _make_label("FOC", 11, COLOR_MUTED)
	caption_label.custom_minimum_size = Vector2(30.0, 0.0)
	caption_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(caption_label)
	focus_bar = _make_bar(COLOR_FOCUS, 11.0)
	focus_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(focus_bar)
	focus_value_label = _make_label("80 / 80", 12, COLOR_TEXT)
	focus_value_label.custom_minimum_size = Vector2(76.0, 0.0)
	focus_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	focus_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(focus_value_label)
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
	_message_safe_area = MarginContainer.new()
	_message_safe_area.name = "MessageSafeArea"
	_message_safe_area.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_message_safe_area.offset_top = 108.0
	_message_safe_area.offset_bottom = 188.0
	_message_safe_area.add_theme_constant_override("margin_left", 24)
	_message_safe_area.add_theme_constant_override("margin_right", 24)
	_message_safe_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_message_safe_area)
	var lane := CenterContainer.new()
	_message_safe_area.add_child(lane)
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


## B-03：左上角缓冲队列 debug 标签（combat tip / debug build 时由 player 刷新）
func _build_buffer_debug_label() -> void:
	buffer_debug_label = _make_label("", 16, COLOR_EMBER)
	buffer_debug_label.name = "InputBufferDebug"
	buffer_debug_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	buffer_debug_label.offset_left = 18.0
	buffer_debug_label.offset_top = 96.0
	buffer_debug_label.offset_right = 320.0
	buffer_debug_label.offset_bottom = 120.0
	buffer_debug_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	buffer_debug_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	buffer_debug_label.add_theme_constant_override("shadow_offset_x", 1)
	buffer_debug_label.add_theme_constant_override("shadow_offset_y", 1)
	buffer_debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buffer_debug_label.visible = false
	root.add_child(buffer_debug_label)


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


func _build_mobile_controls() -> void:
	mobile_controls = MobileControlsScript.new()
	mobile_controls.name = "MobileControls"
	mobile_controls.visible = _mobile_controls_requested
	mobile_controls.pause_requested.connect(_on_mobile_pause_requested)
	root.add_child(mobile_controls)
	mobile_controls.set_ui_scale(_ui_scale)
	mobile_controls.set_control_opacity(_control_opacity)


func _build_pause_overlay() -> void:
	pause_overlay = _make_menu_overlay("PAUSED", "THE HOLLOW WAITS")
	var content := pause_overlay.get_node("Center/Menu/Margins/Content") as VBoxContainer
	resume_button = _make_button("RESUME")
	resume_button.pressed.connect(func() -> void: _set_paused(false))
	content.add_child(resume_button)
	var help_button := _make_button("CONTROLS")
	help_button.pressed.connect(_toggle_help)
	content.add_child(help_button)
	var language_title := _make_label("LANGUAGE", 13, COLOR_MUTED)
	language_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(language_title)
	var language_row := HBoxContainer.new()
	language_row.alignment = BoxContainer.ALIGNMENT_CENTER
	language_row.add_theme_constant_override("separation", 10)
	content.add_child(language_row)
	var english_button := _make_button("ENGLISH")
	english_button.custom_minimum_size.x = 150.0
	english_button.set_meta("base_minimum_size", Vector2(150.0, 48.0))
	english_button.pressed.connect(_request_locale.bind("en"))
	language_row.add_child(english_button)
	var chinese_button := _make_button("SIMPLIFIED CHINESE")
	chinese_button.custom_minimum_size.x = 180.0
	chinese_button.set_meta("base_minimum_size", Vector2(180.0, 48.0))
	chinese_button.pressed.connect(_request_locale.bind("zh_CN"))
	language_row.add_child(chinese_button)
	# 战斗提示模式：默认关闭，仅显示跳劈等教学提示
	var tip_title := _make_label("COMBAT TIP MODE", 13, COLOR_MUTED)
	tip_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(tip_title)
	combat_tip_check = CheckButton.new()
	combat_tip_check.text = "Show combat tips (charge / grip / context)"
	combat_tip_check.set_meta("source_text", "Show combat tips (charge / grip / context)")
	combat_tip_check.button_pressed = false
	combat_tip_check.focus_mode = Control.FOCUS_ALL
	combat_tip_check.process_mode = Node.PROCESS_MODE_ALWAYS
	combat_tip_check.toggled.connect(_on_combat_tip_mode_toggled)
	content.add_child(combat_tip_check)


func _build_title_overlay() -> void:
	title_overlay = _make_menu_overlay(
		"ASHEN HOLLOW",
		"A DELIBERATE ACTION JOURNEY"
	)
	var content := title_overlay.get_node("Center/Menu/Margins/Content") as VBoxContainer
	var summary := _make_label(
		"Cross the moonlit reliquary, reclaim your embers, and break the cinder seal.",
		15,
		COLOR_MUTED
	)
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.custom_minimum_size = Vector2(420.0, 48.0)
	content.add_child(summary)
	play_button = _make_button("BEGIN JOURNEY")
	play_button.pressed.connect(_begin_play)
	content.add_child(play_button)
	var language_title := _make_label("LANGUAGE", 13, COLOR_MUTED)
	language_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(language_title)
	var language_row := HBoxContainer.new()
	language_row.alignment = BoxContainer.ALIGNMENT_CENTER
	language_row.add_theme_constant_override("separation", 10)
	content.add_child(language_row)
	var english_button := _make_button("ENGLISH")
	english_button.custom_minimum_size.x = 150.0
	english_button.set_meta("base_minimum_size", Vector2(150.0, 48.0))
	english_button.pressed.connect(_request_locale.bind("en"))
	language_row.add_child(english_button)
	var chinese_button := _make_button("SIMPLIFIED CHINESE")
	chinese_button.custom_minimum_size.x = 180.0
	chinese_button.set_meta("base_minimum_size", Vector2(180.0, 48.0))
	chinese_button.pressed.connect(_request_locale.bind("zh_CN"))
	language_row.add_child(chinese_button)


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
	_add_control_row(controls_grid, "RIGHT PRIMARY", "LMB  /  J")
	_add_control_row(controls_grid, "RIGHT SECONDARY", "RMB  /  K")
	_add_control_row(controls_grid, "LEFT PRIMARY", "C")
	_add_control_row(controls_grid, "LEFT SECONDARY", "R")
	_add_control_row(controls_grid, "DODGE", "SPACE")
	_add_control_row(controls_grid, "SPRINT", "SHIFT")
	_add_control_row(controls_grid, "INTERACT", "E")
	_add_control_row(controls_grid, "LOCK TARGET", "Q  /  MMB")
	_add_control_row(controls_grid, "CHANGE STYLE", "1–5  /  TAB")
	_add_control_row(controls_grid, "GUARD / PARRY", "C  /  R")
	_add_control_row(controls_grid, "STYLE SKILL", "F")
	_add_control_row(controls_grid, "CAST", "G")
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
	label.set_meta("source_text", text)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.set_meta("base_font_size", font_size)
	label.set_meta("base_font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.set_meta("source_text", text)
	button.custom_minimum_size = Vector2(240.0, 48.0)
	button.set_meta("base_minimum_size", Vector2(240.0, 48.0))
	button.set_meta("base_font_size", 16)
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
	divider.set_meta("base_width", 520.0)
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
	_menu_panels.append(menu)
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
	divider.set_meta("base_width", 420.0)
	content.add_child(divider)
	return overlay


func _build_theme() -> Theme:
	_theme.high_contrast = _high_contrast
	return _theme.build_theme()


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
	if _reduced_motion:
		overlay.modulate.a = 1.0
		return
	overlay.modulate.a = 0.0
	var fade := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade.tween_property(overlay, "modulate:a", 1.0, duration)


func _hide_prompt() -> void:
	if not prompt_panel.visible:
		return
	if _prompt_tween != null and _prompt_tween.is_valid():
		_prompt_tween.kill()
	if _reduced_motion:
		prompt_panel.modulate.a = 0.0
		prompt_panel.visible = false
		return
	_prompt_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_prompt_tween.tween_property(prompt_panel, "modulate:a", 0.0, 0.12)
	_prompt_tween.tween_callback(_finish_prompt_hide)


func _pulse_ember_panel() -> void:
	if _reduced_motion:
		return
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
	if mobile_controls != null:
		mobile_controls.visible = _mobile_controls_requested and not paused
	if paused and resume_button != null:
		resume_button.grab_focus()


func _toggle_help() -> void:
	if help_overlay.visible:
		_close_help()
		return
	_paused_before_help = get_tree().paused
	pause_overlay.visible = false
	help_overlay.visible = true
	if mobile_controls != null:
		mobile_controls.visible = false
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if back_button != null:
		back_button.grab_focus()


func _close_help() -> void:
	help_overlay.visible = false
	get_tree().paused = _paused_before_help
	pause_overlay.visible = _paused_before_help
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _paused_before_help else Input.MOUSE_MODE_CAPTURED
	if mobile_controls != null:
		mobile_controls.visible = _mobile_controls_requested and not _paused_before_help
	if _paused_before_help and resume_button != null:
		resume_button.grab_focus()


func set_ui_scale(value: float) -> void:
	_ui_scale = clampf(value, 0.75, 1.6)
	if root == null:
		return
	_apply_accessibility_to_tree(root)
	if mobile_controls != null:
		mobile_controls.set_ui_scale(_ui_scale)
	_update_responsive_layout()


func set_text_scale(value: float) -> void:
	_text_scale = clampf(value, 0.85, 2.0)
	if root != null:
		_apply_accessibility_to_tree(root)
		_update_responsive_layout()


func apply_accessibility_settings(settings: Dictionary) -> void:
	set_locale(String(settings.get("locale", "en")))
	set_ui_scale(float(settings.get("ui_scale", 1.0)))
	set_text_scale(float(settings.get("text_scale", 1.0)))
	set_reduced_motion(bool(settings.get("reduced_motion", false)))
	set_high_contrast(bool(settings.get("high_contrast", false)))
	set_control_opacity(float(settings.get("control_opacity", 0.78)))
	set_mobile_controls_enabled(_should_use_mobile_controls())
	if combat_tip_check != null:
		combat_tip_check.set_pressed_no_signal(bool(settings.get("combat_tip_mode", false)))


func _on_combat_tip_mode_toggled(enabled: bool) -> void:
	combat_tip_mode_requested.emit(enabled)


func set_locale(locale: String) -> void:
	_locale = String(LocalizationScript.normalize_locale(locale))
	if root == null:
		return
	for control in _walk_controls(root):
		if control.has_meta("source_text"):
			var translated := LocalizationScript.text(
				String(control.get_meta("source_text")),
				_locale
			)
			if control is Label:
				(control as Label).text = translated
			elif control is Button:
				(control as Button).text = translated
	if mobile_controls != null and mobile_controls.has_method("set_locale"):
		mobile_controls.set_locale(_locale)


func set_reduced_motion(enabled: bool) -> void:
	_reduced_motion = enabled
	if not enabled:
		return
	for tween in [_prompt_tween, _message_tween, _ember_tween]:
		if tween != null and tween.is_valid():
			tween.kill()
	if prompt_panel != null:
		prompt_panel.scale = Vector2.ONE
	if message_panel != null:
		message_panel.scale = Vector2.ONE
	if ember_panel != null:
		ember_panel.scale = Vector2.ONE


func set_high_contrast(enabled: bool) -> void:
	_high_contrast = enabled
	if root == null:
		return
	root.theme = _build_theme()
	_apply_accessibility_to_tree(root)


func set_control_opacity(value: float) -> void:
	_control_opacity = clampf(value, 0.35, 1.0)
	if mobile_controls != null:
		mobile_controls.set_control_opacity(_control_opacity)


func set_mobile_controls_enabled(enabled: bool) -> void:
	_mobile_controls_requested = enabled
	if mobile_controls != null:
		mobile_controls.visible = enabled and not get_tree().paused and not help_overlay.visible
	_update_responsive_layout()


func _request_locale(locale: String) -> void:
	set_locale(locale)
	locale_requested.emit(locale)


func _begin_play() -> void:
	title_overlay.visible = false
	get_tree().paused = false
	if mobile_controls != null:
		mobile_controls.visible = _mobile_controls_requested
	play_started.emit()


func _should_use_mobile_controls() -> bool:
	var ProcUtils = preload("res://scripts/core/procedural_utils.gd")
	if ProcUtils.is_mobile_runtime():
		return true
	if not DisplayServer.is_touchscreen_available():
		return false
	var screen_size := DisplayServer.screen_get_size()
	return mini(screen_size.x, screen_size.y) <= 900


func _finish_prompt_hide() -> void:
	if is_instance_valid(prompt_panel) and _current_prompt_text.is_empty():
		prompt_panel.visible = false


func _on_mobile_pause_requested() -> void:
	if help_overlay.visible:
		_close_help()
	else:
		_set_paused(not get_tree().paused)


func _update_responsive_layout() -> void:
	if root == null or safe_area == null or root.size.x <= 0.0:
		return
	var viewport_size := root.size
	var safe_insets := _get_safe_insets(viewport_size)
	var compact := viewport_size.x < 760.0 * _ui_scale
	var base_margin := (16.0 if compact else 28.0) * _ui_scale
	var top_reserved := 132.0 * _ui_scale if _mobile_controls_requested else base_margin
	var bottom_reserved := 176.0 * _ui_scale if _mobile_controls_requested else base_margin
	var left_margin := maxi(roundi(base_margin), roundi(safe_insets.x))
	var top_margin := maxi(roundi(top_reserved), roundi(safe_insets.y))
	var right_margin := maxi(roundi(base_margin), roundi(safe_insets.z))
	var bottom_margin := maxi(roundi(bottom_reserved), roundi(safe_insets.w))
	safe_area.add_theme_constant_override("margin_left", left_margin)
	safe_area.add_theme_constant_override("margin_top", top_margin)
	safe_area.add_theme_constant_override("margin_right", right_margin)
	safe_area.add_theme_constant_override("margin_bottom", bottom_margin)
	var available_width := maxf(viewport_size.x - left_margin - right_margin, 220.0)
	vitals_panel.custom_minimum_size = Vector2(minf(360.0 * _ui_scale, available_width), 104.0 * _ui_scale)
	ember_panel.custom_minimum_size = Vector2(minf(190.0 * _ui_scale, available_width), 50.0 * _ui_scale)
	ember_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	boss_panel.custom_minimum_size.x = minf(760.0 * _ui_scale, available_width)
	prompt_panel.custom_minimum_size.x = minf(440.0 * _ui_scale, available_width)
	message_panel.custom_minimum_size.x = minf(360.0 * _ui_scale, available_width)
	_message_safe_area.offset_top = top_margin + 72.0 * _ui_scale
	_message_safe_area.offset_bottom = _message_safe_area.offset_top + 80.0 * _ui_scale
	_message_safe_area.add_theme_constant_override("margin_left", left_margin)
	_message_safe_area.add_theme_constant_override("margin_right", right_margin)
	for menu in _menu_panels:
		menu.custom_minimum_size.x = minf(520.0 * _ui_scale, maxf(available_width, 220.0))
		var margins := menu.get_node_or_null("Margins") as MarginContainer
		if margins != null:
			var menu_margin := 20 if compact else roundi(38.0 * _ui_scale)
			margins.add_theme_constant_override("margin_left", menu_margin)
			margins.add_theme_constant_override("margin_right", menu_margin)
	for child in _walk_controls(root):
		if child is HSeparator and child.has_meta("base_width"):
			child.custom_minimum_size.x = minf(float(child.get_meta("base_width")) * _ui_scale, maxf(available_width - 48.0, 160.0))


func _get_safe_insets(viewport_size: Vector2) -> Vector4:
	if DisplayServer.get_name() == "headless":
		return Vector4.ZERO
	var screen_size := Vector2(DisplayServer.screen_get_size())
	var safe_rect := Rect2(DisplayServer.get_display_safe_area())
	if screen_size.x <= 0.0 or screen_size.y <= 0.0 or safe_rect.size.x <= 0.0:
		return Vector4.ZERO
	var scale_to_viewport := viewport_size / screen_size
	return Vector4(
		safe_rect.position.x * scale_to_viewport.x,
		safe_rect.position.y * scale_to_viewport.y,
		(screen_size.x - safe_rect.end.x) * scale_to_viewport.x,
		(screen_size.y - safe_rect.end.y) * scale_to_viewport.y
	)


func _apply_accessibility_to_tree(node: Node) -> void:
	for control in _walk_controls(node):
		if control.has_meta("base_font_size"):
			control.add_theme_font_size_override(
				"font_size",
				maxi(
					10,
					roundi(
						float(control.get_meta("base_font_size"))
						* _ui_scale
						* _text_scale
					)
				)
			)
		if control.has_meta("base_minimum_size"):
			var scaled_minimum := Vector2(control.get_meta("base_minimum_size")) * _ui_scale
			if control is BaseButton:
				scaled_minimum.x = maxf(scaled_minimum.x, 48.0)
				scaled_minimum.y = maxf(scaled_minimum.y, 48.0)
			control.custom_minimum_size = scaled_minimum
		if control is Label and control.has_meta("base_font_color"):
			var base_color := Color(control.get_meta("base_font_color"))
			control.add_theme_color_override("font_color", Color.WHITE if _high_contrast else base_color)


func _walk_controls(node: Node) -> Array[Control]:
	var controls: Array[Control] = []
	if node is Control:
		controls.append(node as Control)
	for child in node.get_children():
		controls.append_array(_walk_controls(child))
	return controls


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


## I-14：离树时杀掉消息/提示 tween，避免孤儿协程
func _exit_tree() -> void:
	_message_serial += 1
	for tween in [_prompt_tween, _message_tween, _ember_tween]:
		if tween != null and is_instance_valid(tween) and tween.is_valid():
			tween.kill()
	_prompt_tween = null
	_message_tween = null
	_ember_tween = null


func _read_number(object: Object, names: Array[StringName], fallback: float) -> float:
	for property in object.get_property_list():
		var property_name := StringName(property.get("name", ""))
		if property_name in names:
			var value: Variant = object.get(property_name)
			if value is int or value is float:
				return float(value)
	return fallback
