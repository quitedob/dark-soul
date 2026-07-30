extends "res://addons/gut/test.gd"


func test_gut_is_loaded() -> void:
	assert_true(true, "GUT framework is operational")


func test_godot_version() -> void:
	var version := Engine.get_version_info()
	assert_eq(int(version["major"]), 4, "Godot 4.x is required")
	assert_gte(int(version["minor"]), 7, "Godot 4.7+ is required")
