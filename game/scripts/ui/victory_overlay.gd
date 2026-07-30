class_name VictoryOverlay
extends CanvasLayer
## Victory screen overlay — fades in with "CINDER SEAL BROKEN" message.
## Self-contained; instantiate and add_child to the HUD.

signal continue_requested

const ThemeScript = preload("res://scripts/ui/hud_theme.gd")

var _theme: HudTheme
var _overlay: ColorRect
var _reduced_motion := false


func _ready() -> void:
	_theme = HudTheme.new()
	layer = 20
	_overlay = _build_overlay()
	_overlay.visible = false


func setup(reduced_motion: bool) -> void:
	_reduced_motion = reduced_motion


func show_overlay() -> void:
	_overlay.visible = true
	if _reduced_motion:
		_overlay.modulate.a = 1.0
		return
	_overlay.modulate.a = 0.0
	var fade := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade.tween_property(_overlay, "modulate:a", 1.0, 1.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(2.0).timeout
	if _overlay != null and is_instance_valid(_overlay) and _overlay.visible:
		continue_requested.emit()


func hide_overlay() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.visible = false


func is_visible() -> bool:
	return _overlay != null and is_instance_valid(_overlay) and _overlay.visible


func _build_overlay() -> ColorRect:
	var overlay := ColorRect.new()
	overlay.color = Color(0.004, 0.02, 0.033, 0.88)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 12)
	center.add_child(content)

	var title_label := _theme.make_label("CINDER SEAL BROKEN", 54, HudTheme.COLOR_EMBER)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	title_label.add_theme_constant_override("shadow_offset_x", 3)
	title_label.add_theme_constant_override("shadow_offset_y", 3)
	content.add_child(title_label)

	var divider := HSeparator.new()
	divider.custom_minimum_size = Vector2(520.0, 1.0)
	divider.set_meta("base_width", 520.0)
	content.add_child(divider)

	var subtitle_label := _theme.make_label("The guardian falls. The path beyond the hollow opens.", 14, HudTheme.COLOR_MUTED)
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(subtitle_label)

	return overlay
