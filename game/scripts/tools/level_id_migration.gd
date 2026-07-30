@tool
class_name LevelIdMigration
extends RefCounted

const ContentRegistryScript = preload("res://scripts/core/content_registry.gd")
const DEFAULT_ROOTS := [
	"res://scripts/levels/",
	"res://scripts/world/",
	"res://scripts/bosses/",
	"res://scenes/levels/",
	"res://scenes/actors/bosses/",
]
const SUPPORTED_EXTENSIONS := ["gd", "tscn", "tres"]


static func run(roots: Array[String] = DEFAULT_ROOTS, apply_changes: bool = false, report_path: String = "") -> Dictionary:
	var report := {
		"dry_run": not apply_changes,
		"roots": roots.duplicate(),
		"missing_roots": [],
		"scanned_files": 0,
		"changed_files": [],
		"applied_files": [],
		"total_replacements": 0,
		"potential_collisions": [],
		"errors": [],
	}
	var paths: Array[String] = []
	var planned_content := {}
	for root in roots:
		_collect_files(root, paths, report["missing_roots"])
	paths.sort()
	for path in paths:
		report["scanned_files"] += 1
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			report["errors"].append("Cannot read %s." % path)
			continue
		var analysis := analyze_text(file.get_as_text(), path)
		if analysis["replacements"].is_empty():
			continue
		report["changed_files"].append({
			"path": path,
			"replacement_count": analysis["replacements"].size(),
			"replacements": analysis["replacements"],
		})
		report["total_replacements"] += analysis["replacements"].size()
		report["potential_collisions"].append_array(analysis["potential_collisions"])
		planned_content[path] = analysis["content"]
	if apply_changes and report["errors"].is_empty() and report["potential_collisions"].is_empty():
		for path in paths:
			if not planned_content.has(path):
				continue
			var output := FileAccess.open(path, FileAccess.WRITE)
			if output == null:
				report["errors"].append("Cannot write %s." % path)
				break
			output.store_string(planned_content[path])
			report["applied_files"].append(path)
	if not report_path.is_empty():
		_write_report(report_path, report)
	return report


static func analyze_text(content: String, source_path: String = "") -> Dictionary:
	var pattern := RegEx.new()
	pattern.compile("([\"'])([0-9]{1,2})-([0-9]{1,2})([\"'])")
	var registry = ContentRegistryScript.new()
	var replacements: Array[Dictionary] = []
	var potential_collisions: Array[Dictionary] = []
	for match in pattern.search_all(content):
		if match.get_string(1) != match.get_string(4):
			continue
		var legacy_id := "%s-%s" % [match.get_string(2), match.get_string(3)]
		var canonical_id := String(ContentRegistryScript.normalize_level_id(StringName(legacy_id)))
		if registry.get_level(StringName(canonical_id)).is_empty():
			continue
		var quote := match.get_string(1)
		var replacement := {
			"legacy_id": legacy_id,
			"canonical_id": canonical_id,
			"line": _line_number(content, match.get_start()),
			"start": match.get_start(),
			"end": match.get_end(),
			"quote": quote,
		}
		replacements.append(replacement)
		if "%s%s%s" % [quote, canonical_id, quote] in content:
			potential_collisions.append({
				"path": source_path,
				"legacy_id": legacy_id,
				"canonical_id": canonical_id,
				"line": replacement["line"],
			})
	var transformed := content
	for index in range(replacements.size() - 1, -1, -1):
		var replacement: Dictionary = replacements[index]
		var quoted_id := "%s%s%s" % [replacement["quote"], replacement["canonical_id"], replacement["quote"]]
		transformed = transformed.substr(0, replacement["start"]) + quoted_id + transformed.substr(replacement["end"])
	return {
		"content": transformed,
		"replacements": replacements,
		"potential_collisions": potential_collisions,
	}


static func _collect_files(root: String, paths: Array[String], missing_roots: Array) -> void:
	var directory := DirAccess.open(root)
	if directory == null:
		missing_roots.append(root)
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		var path := root.path_join(entry)
		if directory.current_is_dir():
			_collect_files(path, paths, missing_roots)
		elif path.get_extension().to_lower() in SUPPORTED_EXTENSIONS:
			paths.append(path)
		entry = directory.get_next()
	directory.list_dir_end()


static func _line_number(content: String, offset: int) -> int:
	return content.substr(0, offset).count("\n") + 1


static func _write_report(path: String, report: Dictionary) -> void:
	var output := FileAccess.open(path, FileAccess.WRITE)
	if output == null:
		report["errors"].append("Cannot write report %s." % path)
		return
	output.store_string(JSON.stringify(report, "\t"))
