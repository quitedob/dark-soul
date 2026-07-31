extends SceneTree
## 可选隐藏 Boss 盲钟·听烬 接线合约：
## 关卡注册 / Boss 内容表 / 致死处决 Profile / 双相位解析

const ContentRegistryScript = preload("res://scripts/core/content_registry.gd")
const OptionalBossContent = preload("res://scripts/data/optional_boss_content.gd")
const BossCatalogScript = preload("res://scripts/combat/data/boss_execution_catalog.gd")
const EnemyScript = preload("res://scripts/enemy.gd")

var _failures: Array[String] = []


func _init() -> void:
	_test_registry()
	_test_content()
	_test_execution_profile()
	_test_phase_parse()
	if _failures.is_empty():
		print("OPTIONAL_BOSS_BLIND_BELL_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_registry() -> void:
	var registry = ContentRegistryScript.new()
	var level := registry.get_level(&"level_05_06")
	_expect(not level.is_empty(), "level_05_06 missing from registry.")
	if level.is_empty():
		return
	var boss := registry.get_boss_for_level(&"level_05_06")
	_expect(not boss.is_empty(), "level_05_06 has no boss mapping.")
	_expect(StringName(boss.get("id", &"")) == &"boss_blind_bell", "level_05_06 boss id mismatch.")
	_expect(StringName(level.get("chapter_id", &"")) == &"chapter_05", "level_05_06 must belong to chapter_05.")


func _test_content() -> void:
	var content := OptionalBossContent.boss()
	_expect(String(content.get("id", "")) == "boss_blind_bell", "Optional boss id mismatch.")
	var phases: Dictionary = content.get("phases", {})
	_expect(phases.size() == 2, "Optional boss must have exactly 2 phases.")
	var phase_two: Dictionary = phases.get("2", {})
	_expect(is_equal_approx(float(phase_two.get("threshold", -1.0)), 0.55), "Phase 2 threshold must be 0.55.")
	var phase_one: Dictionary = phases.get("1", {})
	_expect(is_equal_approx(float(phase_one.get("threshold", -1.0)), 1.0), "Phase 1 threshold must be 1.0.")
	_expect(String(content.get("body_type", "")) == "hanging_bell", "body_type must be hanging_bell.")
	_expect(String(content.get("weak_point", "")) == "bell_mouth", "weak_point must be bell_mouth.")
	_expect(int(content.get("reward", 0)) == 420, "Reward must be 420 embers.")


func _test_execution_profile() -> void:
	var p = BossCatalogScript.profile_for_boss_id("boss_blind_bell")
	_expect(p != null, "Missing execution profile for boss_blind_bell.")
	if p == null:
		return
	_expect(p.validate().is_empty(), "Invalid profile: %s" % str(p.validate()))
	_expect(p.story_flag.is_empty(), "Optional boss story_flag must be empty.")
	_expect(bool(p.allow_lethal_on_execution), "Optional boss must be lethal on execution.")
	_expect(p.weak_point_anchor == &"bell_mouth", "Weak-point anchor must be bell_mouth.")
	_expect(is_equal_approx(float(p.story_floor_ratio), 0.0), "story_floor_ratio must be 0.")


func _test_phase_parse() -> void:
	var enemy = EnemyScript.new()
	enemy._parse_boss_phases(OptionalBossContent.boss())
	_expect(is_equal_approx(enemy._content_phase_two_threshold, 0.55), "Phase-2 threshold parse mismatch.")
	_expect(enemy._content_phase_attacks.size() == 2, "Phase attack table size mismatch.")
	_expect(enemy._content_phase_attacks.has(1) and enemy._content_phase_attacks.has(2), "Phase 1/2 attack tables missing.")
	enemy.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
