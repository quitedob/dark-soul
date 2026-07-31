extends SceneTree
## G-08：敌人 AttackData 目录合约（三原型 + 守护者表 + dict 回退）

const Catalog = preload("res://scripts/data/enemy_attack_catalog.gd")
const EnemyTuningData = preload("res://scripts/data/enemy_tuning.gd")
const EnemyScript = preload("res://scripts/enemy.gd")

var _failures: Array[String] = []


func _init() -> void:
	_test_catalog_validates()
	_test_parity_with_tuning()
	_test_enemy_applies_attack_data()
	_test_content_dict_fallback()
	if _failures.is_empty():
		print("ASHEN_ENEMY_ATTACK_CATALOG_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_catalog_validates() -> void:
	Catalog.clear_cache()
	for attack in Catalog.all_built_attacks():
		_expect(attack is AttackData, "Catalog entry must be AttackData.")
		_expect(attack.validate().is_empty(), "Invalid AttackData: %s %s" % [attack.action_id, str(attack.validate())])


func _test_parity_with_tuning() -> void:
	# 与 EnemyTuningData 数字保持一致
	var sentinel: AttackData = Catalog.resolve_prototype("hollow_sentinel")
	_expect(is_equal_approx(sentinel.damage, EnemyTuningData.SENTINEL_ATTACK["damage"]), "Sentinel damage parity.")
	_expect(is_equal_approx(sentinel.windup_seconds, EnemyTuningData.SENTINEL_ATTACK["windup"]), "Sentinel windup parity.")
	var stalker: AttackData = Catalog.resolve_prototype("ash_stalker")
	_expect(is_equal_approx(stalker.poise_damage, EnemyTuningData.STALKER_ATTACK["stagger"]), "Stalker stagger→poise parity.")
	var g: AttackData = Catalog.resolve_guardian(&"long", 3, true)
	_expect(is_equal_approx(g.damage, EnemyTuningData.GUARDIAN_LONG[3]["damage"]), "Guardian long P3 damage parity.")


func _test_enemy_applies_attack_data() -> void:
	var enemy = EnemyScript.new()
	root.add_child(enemy)
	enemy.setup(null, null, null, Vector3.ZERO, false, EnemyScript.EnemyType.ASH_STALKER)
	enemy._select_attack_profile()
	_expect(enemy._current_attack_data != null, "Ash stalker should resolve AttackData.")
	_expect(is_equal_approx(enemy.attack_damage, 8.0), "Ash stalker damage from AttackData.")
	_expect(is_equal_approx(enemy.attack_windup, 0.22), "Ash stalker windup from AttackData.")
	enemy.queue_free()


func _test_content_dict_fallback() -> void:
	# active=0 的 Boss 特殊招不可变 AttackData，必须 dict 回退
	var profile := {
		"name": "chrono_reversal",
		"windup": 0.55, "active": 0.0, "recovery": 0.42,
		"damage": 0.0, "stagger": 0.0, "lunge": 0.0,
		"type": "status",
	}
	_expect(Catalog.try_from_profile_dict(profile) == null, "active=0 must not yield AttackData.")
	var enemy = EnemyScript.new()
	root.add_child(enemy)
	enemy.setup(null, null, null, Vector3.ZERO, true)
	enemy._active_attack_profile = profile.duplicate(true)
	enemy._resolve_attack_data_or_dict(profile, &"chrono_reversal")
	_expect(enemy._current_attack_data == null, "Fallback path should clear AttackData.")
	_expect(is_equal_approx(enemy.attack_windup, 0.55), "Dict fallback windup.")
	_expect(is_equal_approx(enemy.attack_active, 0.0), "Dict fallback active=0 preserved.")
	enemy.queue_free()


func _expect(cond: bool, message: String) -> void:
	if not cond:
		_failures.append(message)
