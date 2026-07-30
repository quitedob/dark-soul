extends SceneTree

const ContentRegistryScript = preload("res://scripts/core/content_registry.gd")
const ContentValidatorScript = preload("res://scripts/core/content_validator.gd")

var _failures: Array[String] = []


func _init() -> void:
	_test_default_catalog()
	_test_registry_lookups()
	_test_legacy_level_id_compatibility()
	_test_validator_rejects_broken_contracts()
	if _failures.is_empty():
		print("EMBER_ABYSS_CONTENT_REGISTRY_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_default_catalog() -> void:
	var registry = ContentRegistryScript.new()
	var errors: Array[String] = registry.validate()
	_expect(errors.is_empty(), "Default content registry failed validation: %s" % [errors])
	_expect(registry.get_chapters().size() == 5, "Registry must contain exactly five chapters.")
	_expect(registry.get_levels().size() == 28, "Registry must contain exactly 28 levels.")
	_expect(registry.get_themes().size() == 5, "Registry must contain exactly five themes.")
	var expected_counts := [5, 6, 6, 6, 5]
	for chapter_number in range(1, 6):
		var chapter_id := StringName("chapter_%02d" % chapter_number)
		_expect(registry.get_levels_for_chapter(chapter_id).size() == expected_counts[chapter_number - 1], "Wrong level count for %s." % chapter_id)


func _test_registry_lookups() -> void:
	var registry = ContentRegistryScript.new()
	var opening := registry.get_level(&"level_01_01")
	var finale := registry.get_level(&"level_05_05")
	_expect(opening.get("next_level_id") == &"level_01_02", "Opening level progression is unstable.")
	_expect(finale.get("boss_id") == &"boss_zhu_yin", "Final boss mapping is unstable.")
	_expect(StringName(finale.get("next_level_id", &"")) == &"", "Final level must terminate progression.")
	_expect(not registry.get_theme(&"theme_celestial_fall").is_empty(), "Celestial Fall theme lookup failed.")
	opening["display_name"] = "mutated"
	_expect(registry.get_level(&"level_01_01").get("display_name") != "mutated", "Registry exposed mutable source records.")
	_expect(registry.get_next_level(&"1-1").get("id") == &"level_01_02", "Legacy next-level lookup failed.")
	_expect(registry.get_boss_for_level(&"1-5").get("id") == &"boss_giant_gate", "Legacy boss lookup failed.")


func _test_legacy_level_id_compatibility() -> void:
	var registry = ContentRegistryScript.new()
	for canonical_level in registry.get_levels():
		var canonical_id := String(canonical_level.get("id", &""))
		var legacy_id := "%d-%d" % [int(canonical_id.substr(6, 2)), int(canonical_id.substr(9, 2))]
		_expect(ContentRegistryScript.normalize_level_id(StringName(legacy_id)) == StringName(canonical_id), "Legacy ID %s normalized incorrectly." % legacy_id)
		_expect(registry.get_level(StringName(legacy_id)) == registry.get_level(StringName(canonical_id)), "Legacy ID %s did not resolve to canonical content." % legacy_id)
	_expect(ContentRegistryScript.normalize_level_id(&"unknown") == &"unknown", "Unknown level IDs must not silently redirect.")
	_expect(registry.get_level(&"unknown").is_empty(), "Unknown level lookup must fail closed.")


func _test_validator_rejects_broken_contracts() -> void:
	var duplicate_content: Dictionary = ContentRegistryScript.default_content()
	duplicate_content["levels"].append(duplicate_content["levels"][0].duplicate(true))
	_expect(_contains_error(ContentValidatorScript.validate(duplicate_content), "Duplicate level ID"), "Duplicate level IDs were not detected.")
	var missing_reference_content: Dictionary = ContentRegistryScript.default_content()
	missing_reference_content["levels"][0]["next_level_id"] = &"level_missing"
	_expect(_contains_error(ContentValidatorScript.validate(missing_reference_content), "missing next level"), "Missing next-level references were not detected.")
	var legacy_id_content: Dictionary = ContentRegistryScript.default_content()
	legacy_id_content["levels"][0]["id"] = &"1-1"
	_expect(_contains_error(ContentValidatorScript.validate(legacy_id_content), "not canonical"), "Legacy level IDs were accepted in canonical content.")
	var wrong_boss_content: Dictionary = ContentRegistryScript.default_content()
	wrong_boss_content["bosses"][0]["chapter_id"] = &"chapter_02"
	_expect(_contains_error(ContentValidatorScript.validate(wrong_boss_content), "wrong chapter"), "Invalid boss-to-chapter mappings were not detected.")
	var missing_endpoint_content: Dictionary = ContentRegistryScript.default_content()
	missing_endpoint_content["chapters"][0]["start_level_id"] = &""
	missing_endpoint_content["chapters"][1]["exit_level_id"] = &"level_missing"
	var endpoint_errors := ContentValidatorScript.validate(missing_endpoint_content)
	_expect(_contains_error(endpoint_errors, "missing start level"), "Missing chapter starts were not detected.")
	_expect(_contains_error(endpoint_errors, "missing exit level"), "Missing chapter exits were not detected.")


func _contains_error(errors: Array[String], fragment: String) -> bool:
	for error in errors:
		if fragment in error:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
