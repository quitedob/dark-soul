class_name HudTheme
extends RefCounted
## Shared theme constants, StyleBox builders, and widget factories for the HUD.
## Extracted from hud.gd so overlays and the main HUD share one visual language.

const InterfaceFont = preload("res://assets/fonts/NotoSansSC-AshenHollow.ttf")

const COLOR_SURFACE := Color(0.035, 0.043, 0.047, 0.96)
const COLOR_SURFACE_SOFT := Color(0.05, 0.058, 0.061, 0.9)
const COLOR_BORDER := Color(0.43, 0.36, 0.24, 0.92)
const COLOR_BORDER_SOFT := Color(0.2, 0.21, 0.22, 0.9)
const COLOR_TEXT := Color(0.92, 0.88, 0.78)
const COLOR_MUTED := Color(0.61, 0.62, 0.61)
const COLOR_EMBER := Color(0.96, 0.59, 0.18)
const COLOR_HEALTH := Color(0.59, 0.065, 0.075)
const COLOR_STAMINA := Color(0.12, 0.49, 0.24)
const COLOR_FOCUS := Color(0.16, 0.34, 0.72)

var high_contrast := false

const WEAPON_ICONS := {
	"sword": preload("res://assets/ui/icons/sword.svg"),
	"greatsword": preload("res://assets/ui/icons/greatsword.svg"),
	"axe": preload("res://assets/ui/icons/axe.svg"),
	"bow": preload("res://assets/ui/icons/bow.svg"),
	"seal": preload("res://assets/ui/icons/seal.svg"),
	"prayer": preload("res://assets/ui/icons/prayer.svg"),
	"shield": preload("res://assets/ui/icons/shield.svg"),
}


static func copy(zh: String, en: String, locale := "") -> String:
	var current := locale if not locale.is_empty() else TranslationServer.get_locale()
	return zh if current.to_lower().begins_with("zh") else en


static func readable_name(value: String, locale := "") -> String:
	if value.is_empty() or value.contains("_"):
		return copy("未装备", "Empty", locale)
	var parts := value.split(" / ")
	if parts.size() < 2:
		return value
	var want_chinese := (locale if not locale.is_empty() else TranslationServer.get_locale()).to_lower().begins_with("zh")
	for part in parts:
		var chinese := false
		for index in part.length():
			if part.unicode_at(index) >= 0x4e00 and part.unicode_at(index) <= 0x9fff:
				chinese = true
		if chinese == want_chinese:
			return part
	return parts[0]


static func weapon_icon(weapon_type: String) -> Texture2D:
	var kind := weapon_type.to_lower()
	if kind in ["dagger", "katana"]:
		kind = "sword"
	elif kind in ["staff", "catalyst", "talisman", "magic"]:
		kind = "seal"
	return WEAPON_ICONS.get(kind, WEAPON_ICONS["sword"])


func slot_style(active: bool, hover := false) -> StyleBoxFlat:
	var background := Color(0.105, 0.09, 0.055, 0.94) if active else Color(0.026, 0.034, 0.038, 0.88)
	if hover:
		background = background.lightened(0.08)
	var style := panel_style(background, COLOR_EMBER if active else COLOR_BORDER, 2, 12.0, 10.0)
	style.border_width_bottom = 3 if active else 1
	return style


func build_theme() -> Theme:
	var interface_theme := Theme.new()
	interface_theme.default_font = InterfaceFont
	var theme_text := Color.WHITE if high_contrast else COLOR_TEXT
	var theme_muted_border := Color(0.78, 0.78, 0.72) if high_contrast else COLOR_BORDER_SOFT
	interface_theme.set_color("font_color", "Label", theme_text)
	interface_theme.set_color("font_shadow_color", "Label", Color(0.01, 0.015, 0.02, 0.95))
	interface_theme.set_constant("shadow_offset_x", "Label", 1)
	interface_theme.set_constant("shadow_offset_y", "Label", 1)
	interface_theme.set_color("font_outline_color", "Label", Color(0.01, 0.015, 0.02, 0.8))
	interface_theme.set_constant("outline_size", "Label", 2)
	interface_theme.set_font_size("font_size", "Label", 16)
	interface_theme.set_color("font_color", "Button", theme_text)
	interface_theme.set_color("font_hover_color", "Button", Color.WHITE)
	interface_theme.set_color("font_focus_color", "Button", Color.WHITE)
	interface_theme.set_color("font_disabled_color", "Button", COLOR_MUTED)
	interface_theme.set_font_size("font_size", "Button", 16)
	interface_theme.set_stylebox("normal", "Button", panel_style(Color(0.01, 0.01, 0.015, 1.0) if high_contrast else Color(0.055, 0.06, 0.07, 0.97), theme_muted_border, 4, 12.0, 7.0))
	interface_theme.set_stylebox("hover", "Button", panel_style(Color(0.12, 0.09, 0.045, 0.99), COLOR_BORDER, 4, 12.0, 7.0))
	interface_theme.set_stylebox("pressed", "Button", panel_style(Color(0.16, 0.1, 0.04, 0.99), COLOR_EMBER.darkened(0.2), 4, 12.0, 7.0))
	interface_theme.set_stylebox("focus", "Button", outline_style(COLOR_EMBER, 4, 2))
	interface_theme.set_stylebox("disabled", "Button", panel_style(COLOR_SURFACE_SOFT, COLOR_BORDER_SOFT, 2))
	interface_theme.set_stylebox("separator", "HSeparator", line_style(Color(0.38, 0.31, 0.2, 0.7)))
	return interface_theme


func panel_style(background: Color, border: Color, radius: int, horizontal_margin: float = 12.0, vertical_margin: float = 5.0) -> StyleBoxFlat:
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


func outline_style(color: Color, radius: int, width: int) -> StyleBoxFlat:
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


func line_style(color: Color) -> StyleBoxLine:
	var style := StyleBoxLine.new()
	style.color = color
	style.thickness = 1
	style.vertical = false
	return style


func make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.set_meta("source_text", text)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.set_meta("base_font_size", font_size)
	label.set_meta("base_font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.set_meta("source_text", text)
	button.custom_minimum_size = Vector2(240.0, 48.0)
	button.set_meta("base_minimum_size", Vector2(240.0, 48.0))
	button.set_meta("base_font_size", 16)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_ALL
	return button
