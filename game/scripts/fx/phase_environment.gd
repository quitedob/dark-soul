extends Node
## Boss 相位环境光切换：雾 / 环境光 / 校色 / 辉光 / 主光 的平滑过渡。
## Phase lighting shifter — tweens the live Environment + key light between looks.
## bind() 时的现场值即“默认档”，restore_defaults() 可随时还原（Boss 死亡 / 离场）。

const LIGHTING_TABLE := {
	# 章节 1 / chapter 1
	"cool_blue_moonlight": {"fog": Color("354d58"), "fog_density": 0.0035, "fog_energy": 0.42, "amb": Color("526882"), "amb_energy": 0.62, "sat": 0.95, "contrast": 1.05, "glow": 0.55, "moon": Color("a8c2de"), "moon_energy": 1.05},
	"flickering_fire_orange": {"fog": Color("554139"), "fog_density": 0.007, "fog_energy": 0.55, "amb": Color("a09186"), "amb_energy": 0.52, "sat": 0.95, "contrast": 1.08, "glow": 0.80, "moon": Color("f5cfa8"), "moon_energy": 0.95},
	# 章节 2 / chapter 2
	"blood_sunset_dim": {"fog": Color("494047"), "fog_density": 0.0038, "fog_energy": 0.48, "amb": Color("858590"), "amb_energy": 0.56, "sat": 0.88, "contrast": 1.06, "glow": 0.65, "moon": Color("f2d0b8"), "moon_energy": 1.00},
	"crimson_rage_glow": {"fog": Color("50383e"), "fog_density": 0.008, "fog_energy": 0.60, "amb": Color("978990"), "amb_energy": 0.52, "sat": 0.95, "contrast": 1.08, "glow": 0.85, "moon": Color("ffd0c6"), "moon_energy": 0.96},
	"deep_crimson_darkness": {"fog": Color("382c39"), "fog_density": 0.012, "fog_energy": 0.72, "amb": Color("817480"), "amb_energy": 0.55, "sat": 0.95, "contrast": 1.08, "glow": 1.00, "moon": Color("efbcc4"), "moon_energy": 0.95},
	# 章节 3 / chapter 3
	"silver_moonlight_soft": {"fog": Color("3a5252"), "fog_density": 0.0040, "fog_energy": 0.45, "amb": Color("729c96"), "amb_energy": 0.50, "sat": 0.92, "contrast": 1.06, "glow": 0.60, "moon": Color("ccdce4"), "moon_energy": 1.00},
	"shifting_foxfire_colors": {"fog": Color("2e4a48"), "fog_density": 0.016, "fog_energy": 0.50, "amb": Color("4a6a66"), "amb_energy": 0.36, "sat": 1.04, "contrast": 1.10, "glow": 0.70, "moon": Color("8affd9"), "moon_energy": 0.95},
	"dim_cyan_desperation": {"fog": Color("2e464c"), "fog_density": 0.009, "fog_energy": 0.55, "amb": Color("789592"), "amb_energy": 0.52, "sat": 0.95, "contrast": 1.08, "glow": 0.75, "moon": Color("abe5dc"), "moon_energy": 0.95},
	# 章节 4 / chapter 4
	"angry_red_glow": {"fog": Color("55403e"), "fog_density": 0.007, "fog_energy": 0.55, "amb": Color("a08f88"), "amb_energy": 0.52, "sat": 0.95, "contrast": 1.08, "glow": 0.75, "moon": Color("f6ccc0"), "moon_energy": 0.98},
	"intense_crimson": {"fog": Color("503039"), "fog_density": 0.01, "fog_energy": 0.62, "amb": Color("9a7b89"), "amb_energy": 0.55, "sat": 0.95, "contrast": 1.08, "glow": 0.90, "moon": Color("f8c1bf"), "moon_energy": 0.95},
	"cold_blue_white": {"fog": Color("4a5a70"), "fog_density": 0.013, "fog_energy": 0.48, "amb": Color("64788e"), "amb_energy": 0.34, "sat": 0.90, "contrast": 1.08, "glow": 0.60, "moon": Color("d8e6f5"), "moon_energy": 1.15},
	"deep_frozen_blue": {"fog": Color("33465d"), "fog_density": 0.009, "fog_energy": 0.55, "amb": Color("8091ab"), "amb_energy": 0.5, "sat": 0.95, "contrast": 1.08, "glow": 0.70, "moon": Color("bad5f4"), "moon_energy": 1},
	"eternal_sunset_gold": {"fog": Color("696671"), "fog_density": 0.0035, "fog_energy": 0.50, "amb": Color("9da3b1"), "amb_energy": 0.35, "sat": 0.90, "contrast": 1.06, "glow": 0.60, "moon": Color("dce2e5"), "moon_energy": 0.72},
	"radiant_gold_white": {"fog": Color("817567"), "fog_density": 0.007, "fog_energy": 0.62, "amb": Color("b1aa9d"), "amb_energy": 0.52, "sat": 0.95, "contrast": 1.08, "glow": 0.95, "moon": Color("fff0d6"), "moon_energy": 1.1},
	"chaotic_gold_darkness": {"fog": Color("46404e"), "fog_density": 0.011, "fog_energy": 0.70, "amb": Color("958890"), "amb_energy": 0.52, "sat": 0.95, "contrast": 1.08, "glow": 1.00, "moon": Color("e7d4b8"), "moon_energy": 0.95},
	# 章节 5 / chapter 5
	"shifting_light_dark_cycle": {"fog": Color("373445"), "fog_density": 0.0045, "fog_energy": 0.45, "amb": Color("79758d"), "amb_energy": 0.55, "sat": 0.94, "contrast": 1.08, "glow": 0.65, "moon": Color("cbc9e3"), "moon_energy": 1.00},
	"focused_spotlight_tracking": {"fog": Color("303240"), "fog_density": 0.008, "fog_energy": 0.38, "amb": Color("8a8b99"), "amb_energy": 0.44, "sat": 0.95, "contrast": 1.08, "glow": 0.60, "moon": Color("e0e3fc"), "moon_energy": 1.1},
	"chaotic_multicolor_void": {"fog": Color("3e324e"), "fog_density": 0.009, "fog_energy": 0.66, "amb": Color("9486aa"), "amb_energy": 0.52, "sat": 0.95, "contrast": 1.08, "glow": 1.00, "moon": Color("d8b8f2"), "moon_energy": 0.95},
	"dim_dying_ember_glow": {"fog": Color("382d32"), "fog_density": 0.012, "fog_energy": 0.55, "amb": Color("79675f"), "amb_energy": 0.55, "sat": 0.95, "contrast": 1.08, "glow": 0.85, "moon": Color("f0caa3"), "moon_energy": 1},
	# 隐藏 Boss / optional bosses
	"moonlight_through_arrow_slits": {"fog": Color("243448"), "fog_density": 0.014, "fog_energy": 0.46, "amb": Color("46586c"), "amb_energy": 0.26, "sat": 0.92, "contrast": 1.12, "glow": 0.60, "moon": Color("bcd0e8"), "moon_energy": 1.20},
	"darkness_ember_only": {"fog": Color("2d2830"), "fog_density": 0.012, "fog_energy": 0.50, "amb": Color("766762"), "amb_energy": 0.55, "sat": 0.95, "contrast": 1.08, "glow": 0.90, "moon": Color("f5ceaa"), "moon_energy": 0.85},
}

var active_key := ""

var _env_node: WorldEnvironment = null
var _key_light: Light3D = null
var _env: Environment = null
var _defaults: Dictionary = {}
var _tween: Tween = null


# -- public API ------------------------------------------------------------


func bind(world_env: WorldEnvironment, key_light: Light3D) -> void:
	## 绑定现场 WorldEnvironment / 主光，并快照当前值作为默认档。
	_env_node = world_env
	_key_light = key_light
	_env = world_env.environment if world_env != null else null
	_defaults = _snapshot()
	active_key = ""


func apply_lighting_key(key: String, duration := 1.4) -> void:
	## 平滑切到指定光照档；未知 key 走通用相位档（key 内嵌数字→相位提示，否则中性）。
	if not is_bound():
		return
	_transition(_profile_for_key(key), duration)
	active_key = key


func restore_defaults(duration := 1.0) -> void:
	## 回到 bind() 时的快照（Boss 死亡 / 离开场地的善后）。
	if not is_bound() or _defaults.is_empty():
		return
	_transition(_defaults, duration)
	active_key = ""


func is_bound() -> bool:
	return _env != null and is_instance_valid(_env) and _key_light != null and is_instance_valid(_key_light)


static func known_keys() -> Array[String]:
	var keys: Array[String] = []
	for k in LIGHTING_TABLE.keys():
		var key := str(k)
		if not keys.has(key):
			keys.append(key)
	keys.sort()
	return keys


# -- internals -------------------------------------------------------------


func _profile_for_key(key: String) -> Dictionary:
	var profile: Dictionary = LIGHTING_TABLE.get(key, {})
	if not profile.is_empty():
		return profile
	return _fallback_profile(key)


func _fallback_profile(key: String) -> Dictionary:
	# 未知 key：按 key 中嵌入的相位数字生成“越高越暖越浓”的通用档位；无数字→中性
	var phase := 2
	for c in key:
		if c >= "0" and c <= "9":
			phase = clampi(int(c), 1, 4)
			break
	var t := (float(phase) - 1.0) / 3.0
	return {
		"fog": Color("2e4458").lerp(Color("4a2a18"), t),
		"fog_density": lerpf(0.012, 0.036, t),
		"fog_energy": lerpf(0.44, 0.62, t),
		"amb": Color("50607a").lerp(Color("6a4a30"), t),
		"amb_energy": lerpf(0.28, 0.34, t),
		"sat": lerpf(0.96, 1.08, t),
		"contrast": lerpf(1.08, 1.20, t),
		"glow": lerpf(0.60, 0.90, t),
		"moon": Color("b0c4dc").lerp(Color("ffa060"), t),
		"moon_energy": lerpf(1.05, 0.70, t),
	}


func _transition(profile: Dictionary, duration: float) -> void:
	_kill_tween()
	if duration <= 0.0 or not is_inside_tree():
		# 0 时长 / 不在树内：直接落值（无头模式友好）
		for t in _targets(profile):
			(t[0] as Object).set(t[1], t[2])
		return
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE)
	tw.set_ease(Tween.EASE_IN_OUT)
	tw.set_parallel(true)
	for t in _targets(profile):
		tw.tween_property(t[0] as Object, t[1], t[2], duration)
	_tween = tw


func _targets(profile: Dictionary) -> Array[Array]:
	# [对象, 属性名, 目标值] 三元组：tween 与直落值共用同一清单
	var list: Array[Array] = []
	list.append([_env, "fog_light_color", profile.fog])
	list.append([_env, "fog_density", profile.fog_density])
	list.append([_env, "fog_light_energy", profile.fog_energy])
	list.append([_env, "ambient_light_color", profile.amb])
	list.append([_env, "ambient_light_energy", profile.amb_energy])
	list.append([_env, "adjustment_saturation", profile.sat])
	list.append([_env, "adjustment_contrast", profile.contrast])
	list.append([_env, "glow_intensity", profile.glow])
	list.append([_key_light, "light_color", profile.moon])
	list.append([_key_light, "light_energy", profile.moon_energy])
	return list


func _snapshot() -> Dictionary:
	if not is_bound():
		return {}
	return {
		"fog": _env.fog_light_color,
		"fog_density": _env.fog_density,
		"fog_energy": _env.fog_light_energy,
		"amb": _env.ambient_light_color,
		"amb_energy": _env.ambient_light_energy,
		"sat": _env.adjustment_saturation,
		"contrast": _env.adjustment_contrast,
		"glow": _env.glow_intensity,
		"moon": _key_light.light_color,
		"moon_energy": _key_light.light_energy,
	}


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
