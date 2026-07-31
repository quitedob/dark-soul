class_name ContentValidator
extends RefCounted

const REQUIRED_CHAPTER_COUNTS := {
	&"chapter_01": 5,
	&"chapter_02": 6,
	&"chapter_03": 6,
	&"chapter_04": 6,
	&"chapter_05": 6,
}
const REQUIRED_LEVEL_FIELDS := ["id", "display_name", "chapter_id", "topology", "theme_id", "kind", "purpose", "boss_id", "next_level_id"]


static func validate(content: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var chapters: Array = content.get("chapters", [])
	var levels: Array = content.get("levels", [])
	var themes: Array = content.get("themes", [])
	var bosses: Array = content.get("bosses", [])
	var chapter_by_id := _index_records(chapters, "chapter", errors)
	var level_by_id := _index_records(levels, "level", errors)
	var theme_by_id := _index_records(themes, "theme", errors)
	var boss_by_id := _index_records(bosses, "boss", errors)
	if chapters.size() != 5:
		errors.append("Expected 5 chapters, found %d." % chapters.size())
	if levels.size() != 29:
		errors.append("Expected 29 levels, found %d." % levels.size())
	if themes.size() != 5:
		errors.append("Expected 5 themes, found %d." % themes.size())
	_validate_chapters(chapters, level_by_id, theme_by_id, boss_by_id, errors)
	_validate_levels(levels, chapter_by_id, level_by_id, theme_by_id, boss_by_id, errors)
	_validate_bosses(bosses, chapter_by_id, level_by_id, errors)
	return errors


static func _validate_chapters(chapters: Array, level_by_id: Dictionary, theme_by_id: Dictionary, boss_by_id: Dictionary, errors: Array[String]) -> void:
	for chapter_value in chapters:
		var chapter: Dictionary = chapter_value
		var chapter_id := StringName(chapter.get("id", &""))
		if chapter_id.is_empty():
			continue
		if not REQUIRED_CHAPTER_COUNTS.has(chapter_id):
			errors.append("Unexpected chapter ID %s." % chapter_id)
			continue
		var actual_count := 0
		for level in level_by_id.values():
			if StringName(level.get("chapter_id", &"")) == chapter_id:
				actual_count += 1
		var expected_count: int = REQUIRED_CHAPTER_COUNTS[chapter_id]
		if actual_count != expected_count:
			errors.append("Chapter %s expected %d levels, found %d." % [chapter_id, expected_count, actual_count])
		var theme_id := StringName(chapter.get("theme_id", &""))
		if not theme_by_id.has(theme_id):
			errors.append("Chapter %s references missing theme %s." % [chapter_id, theme_id])
		_validate_endpoint(chapter_id, StringName(chapter.get("start_level_id", &"")), "start", level_by_id, errors)
		_validate_endpoint(chapter_id, StringName(chapter.get("exit_level_id", &"")), "exit", level_by_id, errors)
		for boss_id_value in chapter.get("boss_ids", []):
			var boss_id := StringName(boss_id_value)
			if not boss_by_id.has(boss_id):
				errors.append("Chapter %s references missing boss %s." % [chapter_id, boss_id])
			elif StringName(boss_by_id[boss_id].get("chapter_id", &"")) != chapter_id:
				errors.append("Boss %s is mapped to the wrong chapter." % boss_id)


static func _validate_levels(levels: Array, chapter_by_id: Dictionary, level_by_id: Dictionary, theme_by_id: Dictionary, boss_by_id: Dictionary, errors: Array[String]) -> void:
	for level_value in levels:
		var level: Dictionary = level_value
		var level_id := StringName(level.get("id", &""))
		_validate_level_id_format(level_id, "Level ID", errors)
		for field in REQUIRED_LEVEL_FIELDS:
			if not level.has(field):
				errors.append("Level %s is missing field %s." % [level_id, field])
		var chapter_id := StringName(level.get("chapter_id", &""))
		if not chapter_by_id.has(chapter_id):
			errors.append("Level %s references missing chapter %s." % [level_id, chapter_id])
		var theme_id := StringName(level.get("theme_id", &""))
		if not theme_by_id.has(theme_id):
			errors.append("Level %s references missing theme %s." % [level_id, theme_id])
		elif chapter_by_id.has(chapter_id) and StringName(chapter_by_id[chapter_id].get("theme_id", &"")) != theme_id:
			errors.append("Level %s theme does not match chapter %s." % [level_id, chapter_id])
		var next_level_id := StringName(level.get("next_level_id", &""))
		if not next_level_id.is_empty():
			_validate_level_id_format(next_level_id, "Level %s next level ID" % level_id, errors)
		if not next_level_id.is_empty() and not level_by_id.has(next_level_id):
			errors.append("Level %s references missing next level %s." % [level_id, next_level_id])
		var boss_id := StringName(level.get("boss_id", &""))
		if boss_id.is_empty():
			continue
		if not boss_by_id.has(boss_id):
			errors.append("Level %s references missing boss %s." % [level_id, boss_id])
			continue
		var boss: Dictionary = boss_by_id[boss_id]
		if StringName(boss.get("chapter_id", &"")) != chapter_id or StringName(boss.get("level_id", &"")) != level_id:
			errors.append("Boss %s has an invalid level-to-chapter mapping." % boss_id)
		elif chapter_by_id.has(chapter_id) and boss_id not in chapter_by_id[chapter_id].get("boss_ids", []):
			errors.append("Boss %s is not declared by chapter %s." % [boss_id, chapter_id])


static func _validate_bosses(bosses: Array, chapter_by_id: Dictionary, level_by_id: Dictionary, errors: Array[String]) -> void:
	for boss_value in bosses:
		var boss: Dictionary = boss_value
		var boss_id := StringName(boss.get("id", &""))
		var chapter_id := StringName(boss.get("chapter_id", &""))
		var level_id := StringName(boss.get("level_id", &""))
		_validate_level_id_format(level_id, "Boss %s level ID" % boss_id, errors)
		if not chapter_by_id.has(chapter_id):
			errors.append("Boss %s references missing chapter %s." % [boss_id, chapter_id])
		if not level_by_id.has(level_id):
			errors.append("Boss %s references missing level %s." % [boss_id, level_id])
		elif StringName(level_by_id[level_id].get("boss_id", &"")) != boss_id:
			errors.append("Boss %s is not assigned to its declared level %s." % [boss_id, level_id])


static func _validate_endpoint(chapter_id: StringName, level_id: StringName, endpoint: String, level_by_id: Dictionary, errors: Array[String]) -> void:
	_validate_level_id_format(level_id, "Chapter %s %s level ID" % [chapter_id, endpoint], errors)
	if level_id.is_empty() or not level_by_id.has(level_id):
		errors.append("Chapter %s has a missing %s level." % [chapter_id, endpoint])
		return
	if StringName(level_by_id[level_id].get("chapter_id", &"")) != chapter_id:
		errors.append("Chapter %s %s level belongs to another chapter." % [chapter_id, endpoint])


static func _validate_level_id_format(level_id: StringName, label: String, errors: Array[String]) -> void:
	var pattern := RegEx.new()
	pattern.compile("^level_[0-9]{2}_[0-9]{2}$")
	if pattern.search(String(level_id)) == null:
		errors.append("%s %s is not canonical." % [label, level_id])


static func _index_records(records: Array, label: String, errors: Array[String]) -> Dictionary:
	var indexed := {}
	for record_value in records:
		if not record_value is Dictionary:
			errors.append("Invalid %s record." % label)
			continue
		var record: Dictionary = record_value
		var id := StringName(record.get("id", &""))
		if id.is_empty():
			errors.append("A %s is missing its ID." % label)
			continue
		if indexed.has(id):
			errors.append("Duplicate %s ID %s." % [label, id])
			continue
		indexed[id] = record
	return indexed
