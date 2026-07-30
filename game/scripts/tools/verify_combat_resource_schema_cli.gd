extends SceneTree
## A-05 CLI：直接运行 combat Resource schema 校验工具

const Verifier = preload("res://scripts/tools/verify_combat_resource_schema.gd")


func _init() -> void:
	var failures: Array[String] = Verifier.run()
	if failures.is_empty():
		print("ASHEN_COMBAT_RESOURCE_SCHEMA_OK")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
