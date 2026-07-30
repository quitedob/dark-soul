@tool
extends EditorScript

const LevelIdMigrationScript = preload("res://scripts/tools/level_id_migration.gd")


func _run() -> void:
	var apply_changes := "--apply" in OS.get_cmdline_user_args()
	var report := LevelIdMigrationScript.run(
		LevelIdMigrationScript.DEFAULT_ROOTS,
		apply_changes,
		"res://level_id_migration_report.json"
	)
	print(JSON.stringify(report, "\t"))
	if not report["errors"].is_empty() or not report["potential_collisions"].is_empty():
		push_error("Level ID migration requires review before it can complete.")
		return
	if apply_changes and not report["applied_files"].is_empty():
		EditorInterface.get_resource_filesystem().scan()
