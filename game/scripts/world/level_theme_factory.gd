class_name LevelThemeFactory
extends RefCounted

const THEMES := {
	&"theme_spirit_ruins": {
		"ground": Color("202a2d"), "structure": Color("52605a"),
		"accent": Color("f06b32"), "detail": Color("263d32"), "sky": Color("07131b"),
	},
	&"theme_blood_iron": {
		"ground": Color("241718"), "structure": Color("4b3b38"),
		"accent": Color("d52f22"), "detail": Color("5b2e1f"), "sky": Color("16090b"),
	},
	&"theme_jade_veil": {
		"ground": Color("10231d"), "structure": Color("315b49"),
		"accent": Color("7be0b0"), "detail": Color("183d31"), "sky": Color("061712"),
	},
	&"theme_celestial_fall": {
		"ground": Color("30293b"), "structure": Color("786b83"),
		"accent": Color("ffc46b"), "detail": Color("493955"), "sky": Color("24152f"),
	},
	&"theme_ember_abyss": {
		"ground": Color("15151c"), "structure": Color("42404e"),
		"accent": Color("f6d9ad"), "detail": Color("292636"), "sky": Color("030308"),
	},
}


static func create(theme_id: StringName) -> Dictionary:
	var colors: Dictionary = THEMES.get(theme_id, THEMES[&"theme_spirit_ruins"])
	return {
		"ground": _material(colors["ground"], 0.96),
		"structure": _material(colors["structure"], 0.82),
		"accent": _material(colors["accent"], 0.35, colors["accent"], 2.4),
		"detail": _material(colors["detail"], 0.9),
		"sky": colors["sky"],
		"accent_color": colors["accent"],
	}


static func _material(
	color: Color,
	roughness: float,
	emission := Color.BLACK,
	emission_energy := 0.0
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	if emission != Color.BLACK:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = emission_energy
	return material
