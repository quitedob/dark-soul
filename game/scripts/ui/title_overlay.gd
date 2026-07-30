class_name TitleOverlay
extends CanvasLayer
## Title screen overlay with "ASHEN HOLLOW" branding, begin-journey button, and language picker.
## Self-contained; instantiate and add_child to the HUD.

signal play_started
signal locale_requested(locale: String)

const ThemeScript = preload("res://scripts/ui/hud_theme.gd")

var _theme: HudTheme
var _overlay: ColorRect
var _play_button: Button
var _menu_panels: Array[PanelContainer] = []


func _ready() -> void:
	_theme = HudTheme.new()
	layer = 20
	_overlay = _build_overlay()
	_overlay.visible = false


func show_overlay(has_save: bool) -> void:
	if has_save and _play_button != null:
		_play_button.text = "CONTINUE JOURNEY"
	_overlay.visible = true


func hide_overlay() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.visible = false


func is_visible() -> bool:
	return _overlay != null and is_instance_valid(_overlay) and _overlay.visible


func get_menu_panels() -> Array[PanelContainer]:
	return _menu_panels


func _build_overlay() -> ColorRect:
	var overlay := ColorRect.new()
	overlay.color = Color(0.004, 0.006, 0.009, 0.84)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var menu := PanelContainer.new()
	menu.name = "Menu"
	menu.custom_minimum_size = Vector2(520.0, 0.0)
	_menu_panels.append(menu)
	menu.add_theme_stylebox_override("panel", _theme.panel_style(HudTheme.COLOR_SURFACE, HudTheme.COLOR_BORDER, 7, 0.0, 0.0))
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

	var eyebrow_label := _theme.make_label("A DELIBERATE ACTION JOURNEY", 12, HudTheme.COLOR_MUTED)
	eyebrow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(eyebrow_label)

	var title_label := _theme.make_label("ASHEN HOLLOW", 34, HudTheme.COLOR_EMBER)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title_label)

	var divider := HSeparator.new()
	divider.custom_minimum_size = Vector2(420.0, 1.0)
	divider.set_meta("base_width", 420.0)
	content.add_child(divider)

	var summary := _theme.make_label(
		"Cross the moonlit reliquary, reclaim your embers, and break the cinder seal.",
		15,
		HudTheme.COLOR_MUTED
	)
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.custom_minimum_size = Vector2(420.0, 48.0)
	content.add_child(summary)

	_play_button = _theme.make_button("BEGIN JOURNEY")
	_play_button.pressed.connect(func() -> void: play_started.emit())
	content.add_child(_play_button)

	var language_title := _theme.make_label("LANGUAGE", 13, HudTheme.COLOR_MUTED)
	language_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(language_title)

	var language_row := HBoxContainer.new()
	language_row.alignment = BoxContainer.ALIGNMENT_CENTER
	language_row.add_theme_constant_override("separation", 10)
	content.add_child(language_row)

	var english_button := _theme.make_button("ENGLISH")
	english_button.custom_minimum_size.x = 150.0
	english_button.set_meta("base_minimum_size", Vector2(150.0, 48.0))
	english_button.pressed.connect(func() -> void: locale_requested.emit("en"))
	language_row.add_child(english_button)

	var chinese_button := _theme.make_button("SIMPLIFIED CHINESE")
	chinese_button.custom_minimum_size.x = 180.0
	chinese_button.set_meta("base_minimum_size", Vector2(180.0, 48.0))
	chinese_button.pressed.connect(func() -> void: locale_requested.emit("zh_CN"))
	language_row.add_child(chinese_button)

	return overlay
