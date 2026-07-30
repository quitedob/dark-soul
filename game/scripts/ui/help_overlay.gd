class_name HelpOverlay
extends CanvasLayer
## Controls reference overlay — keyboard & mouse bindings grid.
## Self-contained; instantiate and add_child to the HUD.

signal close_requested

const ThemeScript = preload("res://scripts/ui/hud_theme.gd")

var _theme: HudTheme
var _overlay: ColorRect
var _back_button: Button
var _menu_panels: Array[PanelContainer] = []


func _ready() -> void:
	_theme = HudTheme.new()
	layer = 20
	_overlay = _build_overlay()
	_overlay.visible = false


func show_overlay() -> void:
	if _back_button != null:
		_back_button.grab_focus()
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

	var eyebrow_label := _theme.make_label("KEYBOARD & MOUSE", 12, HudTheme.COLOR_MUTED)
	eyebrow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(eyebrow_label)

	var title_label := _theme.make_label("CONTROLS", 34, HudTheme.COLOR_EMBER)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title_label)

	var divider := HSeparator.new()
	divider.custom_minimum_size = Vector2(420.0, 1.0)
	divider.set_meta("base_width", 420.0)
	content.add_child(divider)

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

	var hint := _theme.make_label("Esc  Pause     F1  Toggle controls", 13, HudTheme.COLOR_MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(hint)

	_back_button = _theme.make_button("BACK")
	_back_button.pressed.connect(func() -> void: close_requested.emit())
	content.add_child(_back_button)

	return overlay


func _add_control_row(grid: GridContainer, action: String, binding: String) -> void:
	var action_label := _theme.make_label(action, 14, HudTheme.COLOR_MUTED)
	action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	grid.add_child(action_label)
	var binding_label := _theme.make_label(binding, 14, HudTheme.COLOR_TEXT)
	binding_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	binding_label.add_theme_color_override("font_color", Color.WHITE)
	grid.add_child(binding_label)
