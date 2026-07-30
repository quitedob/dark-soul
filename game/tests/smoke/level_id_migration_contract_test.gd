extends SceneTree

const LevelIdMigrationScript = preload("res://scripts/tools/level_id_migration.gd")

const FIXTURE_ROOT := "user://level_id_migration_contract"

var _failures: Array[String] = []


func _init() -> void:
	_test_text_analysis()
	_test_recursive_dry_run_and_apply()
	_test_collision_blocks_apply()
	if _failures.is_empty():
		print("EMBER_ABYSS_LEVEL_ID_MIGRATION_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_text_analysis() -> void:
	var source := "var opening = \"1-1\"\nvar finale = '5-5'\nvar note = \"99-99\"\nvar canonical = \"level_01_01\"\n"
	var result := LevelIdMigrationScript.analyze_text(source, "fixture.gd")
	_expect(result["replacements"].size() == 2, "Text analysis did not restrict replacements to known campaign IDs.")
	_expect("\"level_01_01\"" in result["content"], "Double-quoted legacy ID was not migrated.")
	_expect("'level_05_05'" in result["content"], "Single-quoted legacy ID was not migrated.")
	_expect("\"99-99\"" in result["content"], "Unknown ID was unexpectedly rewritten.")
	_expect(result["potential_collisions"].size() == 1, "Existing canonical ID collision was not reported.")


func _test_recursive_dry_run_and_apply() -> void:
	_cleanup_fixture()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FIXTURE_ROOT.path_join("nested")))
	_write(FIXTURE_ROOT.path_join("root.gd"), "var level_id = \"1-2\"\n")
	_write(FIXTURE_ROOT.path_join("nested/scene.tscn"), "level_id = \"2-3\"\n")
	_write(FIXTURE_ROOT.path_join("nested/resource.tres"), "level_id = \"3-4\"\n")
	_write(FIXTURE_ROOT.path_join("nested/ignored.txt"), "4-5\n")
	var report_path := FIXTURE_ROOT.path_join("report.json")
	var dry_run := LevelIdMigrationScript.run([FIXTURE_ROOT], false, report_path)
	_expect(dry_run["dry_run"], "Migration did not report dry-run mode.")
	_expect(dry_run["scanned_files"] == 3, "Recursive scan did not include exactly the supported fixture files.")
	_expect(dry_run["total_replacements"] == 3, "Dry run found the wrong replacement count.")
	_expect(dry_run["applied_files"].is_empty(), "Dry run wrote fixture files.")
	_expect("\"1-2\"" in _read(FIXTURE_ROOT.path_join("root.gd")), "Dry run modified source content.")
	_expect(FileAccess.file_exists(report_path), "Dry-run report was not written.")
	var applied := LevelIdMigrationScript.run([FIXTURE_ROOT], true)
	_expect(applied["applied_files"].size() == 3, "Apply mode did not write all changed files.")
	_expect("\"level_01_02\"" in _read(FIXTURE_ROOT.path_join("root.gd")), "Script fixture was not migrated.")
	_expect("\"level_02_03\"" in _read(FIXTURE_ROOT.path_join("nested/scene.tscn")), "Scene fixture was not migrated.")
	_expect("\"level_03_04\"" in _read(FIXTURE_ROOT.path_join("nested/resource.tres")), "Resource fixture was not migrated.")
	_cleanup_fixture()


func _test_collision_blocks_apply() -> void:
	_cleanup_fixture()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FIXTURE_ROOT))
	var source := "var legacy = \"1-1\"\nvar canonical = \"level_01_01\"\n"
	var path := FIXTURE_ROOT.path_join("collision.gd")
	_write(path, source)
	var report := LevelIdMigrationScript.run([FIXTURE_ROOT], true)
	_expect(report["potential_collisions"].size() == 1, "Apply preflight did not report the collision.")
	_expect(report["applied_files"].is_empty(), "Apply mode wrote files despite a collision.")
	_expect(_read(path) == source, "Collision preflight changed source content.")
	_cleanup_fixture()


func _write(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_failures.append("Could not write fixture %s." % path)
		return
	file.store_string(content)


func _read(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_failures.append("Could not read fixture %s." % path)
		return ""
	return file.get_as_text()


func _cleanup_fixture() -> void:
	_remove_tree(FIXTURE_ROOT)


func _remove_tree(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		var child := path.path_join(entry)
		if directory.current_is_dir():
			_remove_tree(child)
		else:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(child))
		entry = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
