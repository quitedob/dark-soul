class_name ContentRegistry
extends RefCounted

const CampaignContentScript = preload("res://scripts/data/campaign_content.gd")
const ContentValidatorScript = preload("res://scripts/core/content_validator.gd")

var _content: Dictionary
var _chapters_by_id: Dictionary
var _levels_by_id: Dictionary
var _themes_by_id: Dictionary
var _bosses_by_id: Dictionary


func _init(content: Dictionary = {}) -> void:
	_content = content.duplicate(true) if not content.is_empty() else default_content()
	_chapters_by_id = _index_by_id(_content.get("chapters", []))
	_levels_by_id = _index_by_id(_content.get("levels", []))
	_themes_by_id = _index_by_id(_content.get("themes", []))
	_bosses_by_id = _index_by_id(_content.get("bosses", []))


static func default_content() -> Dictionary:
	return {
		"chapters": CampaignContentScript.chapters(),
		"levels": CampaignContentScript.levels(),
		"themes": CampaignContentScript.themes(),
		"bosses": CampaignContentScript.bosses(),
	}


func validate() -> Array[String]:
	return ContentValidatorScript.validate(_content)


func get_chapter(chapter_id: StringName) -> Dictionary:
	return _chapters_by_id.get(chapter_id, {}).duplicate(true)


func get_level(level_id: StringName) -> Dictionary:
	return _levels_by_id.get(level_id, {}).duplicate(true)


func get_theme(theme_id: StringName) -> Dictionary:
	return _themes_by_id.get(theme_id, {}).duplicate(true)


func get_boss(boss_id: StringName) -> Dictionary:
	return _bosses_by_id.get(boss_id, {}).duplicate(true)


func get_chapters() -> Array[Dictionary]:
	return _duplicate_records(_content.get("chapters", []))


func get_levels() -> Array[Dictionary]:
	return _duplicate_records(_content.get("levels", []))


func get_themes() -> Array[Dictionary]:
	return _duplicate_records(_content.get("themes", []))


func get_levels_for_chapter(chapter_id: StringName) -> Array[Dictionary]:
	var chapter_levels: Array[Dictionary] = []
	for level_value in _content.get("levels", []):
		var level: Dictionary = level_value
		if StringName(level.get("chapter_id", &"")) == chapter_id:
			chapter_levels.append(level.duplicate(true))
	return chapter_levels


func _index_by_id(records: Array) -> Dictionary:
	var indexed := {}
	for record_value in records:
		if record_value is Dictionary:
			var record: Dictionary = record_value
			indexed[StringName(record.get("id", &""))] = record
	return indexed


func _duplicate_records(records: Array) -> Array[Dictionary]:
	var copies: Array[Dictionary] = []
	for record_value in records:
		if record_value is Dictionary:
			copies.append(record_value.duplicate(true))
	return copies
