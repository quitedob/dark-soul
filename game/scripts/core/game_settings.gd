class_name AshenGameSettings
extends RefCounted

const SCHEMA_VERSION := 1
const QUALITY_PRESETS := [&"low", &"medium", &"high"]
const LocalizationScript = preload("res://scripts/core/localization.gd")

var locale := "en"
var ui_scale := 1.0
var text_scale := 1.0
var reduced_motion := false
var screen_shake_enabled := true
var screen_shake_intensity := 1.0
var high_contrast := false
var control_opacity := 0.72
var camera_sensitivity := 1.0
var invert_camera_y := false
var master_volume := 0.8
var music_volume := 0.7
var effects_volume := 0.85
var subtitles_enabled := true
var quality_preset: StringName = &"medium"
var target_fps := 60
var combat_hitbox_debug := false
## 战斗提示模式：跳劈条件等教学提示；默认关闭
var combat_tip_mode := false


func to_dictionary() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"locale": locale,
		"ui_scale": ui_scale,
		"text_scale": text_scale,
		"reduced_motion": reduced_motion,
		"screen_shake_enabled": screen_shake_enabled,
		"screen_shake_intensity": screen_shake_intensity,
		"high_contrast": high_contrast,
		"control_opacity": control_opacity,
		"camera_sensitivity": camera_sensitivity,
		"invert_camera_y": invert_camera_y,
		"master_volume": master_volume,
		"music_volume": music_volume,
		"effects_volume": effects_volume,
		"subtitles_enabled": subtitles_enabled,
		"quality_preset": String(quality_preset),
		"target_fps": target_fps,
		"combat_hitbox_debug": combat_hitbox_debug,
		"combat_tip_mode": combat_tip_mode,
	}


func to_bridge_dictionary() -> Dictionary:
	return {
		"schemaVersion": SCHEMA_VERSION,
		"locale": locale,
		"uiScale": ui_scale,
		"textScale": text_scale,
		"reducedMotion": reduced_motion,
		"screenShakeEnabled": screen_shake_enabled,
		"screenShakeIntensity": screen_shake_intensity,
		"highContrast": high_contrast,
		"controlOpacity": control_opacity,
		"cameraSensitivity": camera_sensitivity,
		"invertCameraY": invert_camera_y,
		"masterVolume": master_volume,
		"musicVolume": music_volume,
		"effectsVolume": effects_volume,
		"subtitlesEnabled": subtitles_enabled,
		"qualityPreset": String(quality_preset),
		"targetFps": target_fps,
		"combatHitboxDebug": combat_hitbox_debug,
		"combatTipMode": combat_tip_mode,
	}


func to_json() -> String:
	return JSON.stringify(to_dictionary())


func save_to_path(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(to_json())
	return true


func apply_runtime_defaults(is_mobile_web: bool) -> void:
	if is_mobile_web and quality_preset == &"medium" and target_fps == 60:
		quality_preset = &"low"
		target_fps = 30
	Engine.max_fps = target_fps
	TranslationServer.set_locale(locale)


static func from_json(text: String):
	var decoded = JSON.parse_string(text)
	if not decoded is Dictionary:
		return null
	return from_dictionary(decoded)


static func from_dictionary(data: Dictionary):
	var schema_version := int(data.get("schema_version", data.get("schemaVersion", SCHEMA_VERSION)))
	if schema_version != SCHEMA_VERSION:
		return null
	var settings = new()
	settings.locale = String(LocalizationScript.normalize_locale(String(data.get("locale", "en"))))
	settings.ui_scale = clampf(float(data.get("ui_scale", data.get("uiScale", 1.0))), 0.75, 2.0)
	settings.text_scale = clampf(float(data.get("text_scale", data.get("textScale", 1.0))), 0.85, 2.0)
	settings.reduced_motion = bool(data.get("reduced_motion", data.get("reducedMotion", false)))
	settings.screen_shake_enabled = bool(data.get("screen_shake_enabled", data.get("screenShakeEnabled", true)))
	settings.screen_shake_intensity = clampf(float(data.get("screen_shake_intensity", data.get("screenShakeIntensity", 1.0))), 0.0, 2.0)
	settings.high_contrast = bool(data.get("high_contrast", data.get("highContrast", false)))
	settings.control_opacity = clampf(
		float(data.get("control_opacity", data.get("controlOpacity", 0.72))),
		0.25,
		1.0
	)
	settings.camera_sensitivity = clampf(
		float(data.get("camera_sensitivity", data.get("cameraSensitivity", 1.0))),
		0.35,
		2.5
	)
	settings.invert_camera_y = bool(data.get("invert_camera_y", data.get("invertCameraY", false)))
	settings.master_volume = clampf(
		float(data.get("master_volume", data.get("masterVolume", 0.8))),
		0.0,
		1.0
	)
	settings.music_volume = clampf(
		float(data.get("music_volume", data.get("musicVolume", 0.7))),
		0.0,
		1.0
	)
	settings.effects_volume = clampf(
		float(data.get("effects_volume", data.get("effectsVolume", 0.85))),
		0.0,
		1.0
	)
	settings.subtitles_enabled = bool(
		data.get("subtitles_enabled", data.get("subtitlesEnabled", true))
	)
	var quality := StringName(
		String(data.get("quality_preset", data.get("qualityPreset", "medium")))
	)
	settings.quality_preset = quality if quality in QUALITY_PRESETS else &"medium"
	var requested_fps := int(data.get("target_fps", data.get("targetFps", 60)))
	settings.target_fps = 30 if requested_fps <= 30 else 60
	settings.combat_hitbox_debug = bool(
		data.get("combat_hitbox_debug", data.get("combatHitboxDebug", false))
	)
	settings.combat_tip_mode = bool(
		data.get("combat_tip_mode", data.get("combatTipMode", false))
	)
	return settings


static func load_from_path(path: String):
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	return from_json(file.get_as_text())
