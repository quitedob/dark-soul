class_name WorldEnvSetup
extends RefCounted
## Environment node creation, materials, and brazier flicker animation.
## Composition helper — takes a world node reference for add_child / brazier access.

const MaterialUtils = preload("res://scripts/core/procedural_utils.gd")
const ThemeFactory = preload("res://scripts/world/level_theme_factory.gd")
const PhaseEnvironment = preload("res://scripts/fx/phase_environment.gd")
const THEME_LIGHTING_KEYS := {
	&"theme_spirit_ruins": "cool_blue_moonlight",
	&"theme_blood_iron": "blood_sunset_dim",
	&"theme_jade_veil": "silver_moonlight_soft",
	&"theme_celestial_fall": "eternal_sunset_gold",
	&"theme_ember_abyss": "shifting_light_dark_cycle",
}

var _world: Node3D


func setup(world_node: Node3D) -> void:
	_world = world_node


# -- public API ------------------------------------------------------------


func create_environment() -> void:
	var env_node := WorldEnvironment.new()
	env_node.name = "NightEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("101c25")
	sky_material.sky_horizon_color = Color("354d58")
	sky_material.ground_bottom_color = Color("07101a")
	sky_material.ground_horizon_color = Color("354d58")
	sky_material.sun_angle_max = 8.0
	sky.sky_material = sky_material
	environment.sky = sky
	environment.background_color = Color("07101a")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("526882")
	environment.ambient_light_energy = 0.28
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.55
	environment.glow_bloom = 0.25
	environment.fog_enabled = true
	environment.fog_light_color = Color("26405a")
	environment.fog_light_energy = 0.42
	environment.fog_density = 0.010
	# Adjusted tonemap for deeper blacks and richer highlights
	environment.adjustment_enabled = true
	environment.adjustment_contrast = 1.08
	environment.adjustment_saturation = 0.95
	env_node.environment = environment
	_world.add_child(env_node)

	# Moonlight — cool blue directional key light
	var moon := DirectionalLight3D.new()
	moon.name = "Moonlight"
	moon.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	moon.light_color = Color("a8c2de")
	moon.light_energy = 1.05
	moon.light_indirect_energy = 0.35
	moon.shadow_enabled = true
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	moon.directional_shadow_split_1 = 0.15
	_world.add_child(moon)

	# Shrine glow — warm ember light
	var warm_light := OmniLight3D.new()
	warm_light.name = "ShrineGlow"
	warm_light.position = Vector3(0.0, 2.4, 6.0)
	warm_light.light_color = Color("ff8844")
	warm_light.light_energy = 5.5
	warm_light.omni_range = 10.0
	warm_light.light_indirect_energy = 0.5
	warm_light.shadow_enabled = true
	_world.add_child(warm_light)

	# Secondary ambient shrine fill light (softer, wider)
	var fill_light := OmniLight3D.new()
	fill_light.name = "ShrineFill"
	fill_light.position = Vector3(0.0, 1.2, 7.5)
	fill_light.light_color = Color("ffaa77")
	fill_light.light_energy = 1.8
	fill_light.omni_range = 14.0
	fill_light.light_indirect_energy = 0.25
	fill_light.shadow_enabled = false
	_world.add_child(fill_light)


func apply_theme(theme_id: StringName) -> void:
	# One live WorldEnvironment owns the level baseline and boss-phase transitions.
	var world_env := _world.get_node_or_null("NightEnvironment") as WorldEnvironment
	var moon := _world.get_node_or_null("Moonlight") as DirectionalLight3D
	if world_env == null or world_env.environment == null or moon == null:
		return
	var colors: Dictionary = ThemeFactory.THEMES.get(theme_id, ThemeFactory.THEMES[&"theme_spirit_ruins"])
	var profile: Dictionary = PhaseEnvironment.LIGHTING_TABLE[THEME_LIGHTING_KEYS.get(theme_id, "cool_blue_moonlight")]
	var environment := world_env.environment
	environment.background_color = colors["sky"]
	var sky_material := environment.sky.sky_material as ProceduralSkyMaterial
	sky_material.sky_top_color = colors["sky"]
	sky_material.sky_horizon_color = profile["fog"]
	sky_material.ground_bottom_color = colors["sky"]
	sky_material.ground_horizon_color = profile["fog"]
	environment.fog_light_color = profile["fog"]
	environment.fog_density = profile["fog_density"]
	environment.fog_light_energy = profile["fog_energy"]
	environment.ambient_light_color = profile["amb"]
	environment.ambient_light_energy = profile["amb_energy"]
	environment.adjustment_saturation = profile["sat"]
	environment.adjustment_contrast = profile["contrast"]
	environment.glow_intensity = profile["glow"]
	moon.light_color = profile["moon"]
	moon.light_energy = profile["moon_energy"]
	world_env.set_meta("theme_id", theme_id)


func create_materials() -> Dictionary:
	var mats: Dictionary = {}
	mats["stone"] = _material(Color("27303a"), 0.92, 0.05)
	mats["stone_dark"] = _material(Color("121922"), 0.98, 0.02)
	mats["metal"] = _material(Color("303a43"), 0.46, 0.72)
	mats["ember"] = _material(Color("ff6a2e"), 0.28, 0.0, Color("ff4418"), 3.8)
	mats["moss"] = _material(Color("203a31"), 0.95, 0.0)
	mats["void"] = _material(Color("05070c"), 1.0, 0.0)
	mats["rubble"] = _material(Color("1a1f28"), 0.95, 0.03)
	mats["wood"] = _material(Color("2a1f14"), 0.85, 0.02)
	mats["ember_vein"] = _material(Color("ff4418"), 0.35, 0.0, Color("ff6628"), 3.0)
	mats["ember_glow"] = _material(Color("ff9933"), 0.2, 0.0, Color("ff6600"), 6.0)
	return mats


func update_brazier_flicker(delta: float, brazier_lights: Array[OmniLight3D], brazier_flicker_phases: Array[float]) -> void:
	## Dynamic ember light flickering for braziers — adds life and atmosphere.
	for i in range(brazier_lights.size()):
		var light := brazier_lights[i]
		if light == null or not is_instance_valid(light):
			continue
		brazier_flicker_phases[i] += delta * (2.2 + float(i) * 0.7)
		var flicker: float = 1.0 + sin(brazier_flicker_phases[i]) * 0.12 + sin(brazier_flicker_phases[i] * 3.7) * 0.06
		light.light_energy = 2.8 * flicker


# -- helpers ---------------------------------------------------------------


func _material(color: Color, roughness: float, metallic: float, emission := Color.BLACK, emission_energy := 0.0, transparent := false) -> StandardMaterial3D:
	return MaterialUtils.make_material(color, roughness, metallic, emission, emission_energy, transparent)
