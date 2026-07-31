# game/tests/smoke/g03_ranged_ambush_contract_test.gd
extends SceneTree
## G-03 契约：远程伏击原型存在、后撤决策、投射物可配置

const EnemyScript = preload("res://scripts/enemy.gd")
const RangedAmbushBehavior = preload("res://scripts/enemy/ranged_ambush_behavior.gd")
const EnemyProjectileScript = preload("res://scripts/enemy/enemy_projectile.gd")
const Chapter1Content = preload("res://scripts/data/chapter_1_content.gd")
const EnemyTuning = preload("res://scripts/data/enemy_tuning.gd")

var _failures: Array[String] = []


func _init() -> void:
	_test_enum_and_tuning()
	_test_behavior_kite()
	_test_content_archetype()
	_test_projectile_setup()
	_test_enemy_skirmisher_runtime()
	if _failures.is_empty():
		print("G03_RANGED_AMBUSH_CONTRACTS_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _test_enum_and_tuning() -> void:
	_expect(EnemyScript.EnemyType.EMBER_SKIRMISHER >= 0, "EMBER_SKIRMISHER enum missing.")
	_expect(EnemyTuning.TYPE_TUNING.has("ember_skirmisher"), "enemy_tuning lacks ember_skirmisher.")
	_expect(EnemyTuning.SKIRMISHER_ATTACK.has("damage"), "SKIRMISHER_ATTACK profile missing.")


func _test_behavior_kite() -> void:
	var from := Vector3.ZERO
	var close := Vector3(2.0, 0.0, 0.0)
	var mid := Vector3(7.0, 0.0, 0.0)
	var far := Vector3(12.0, 0.0, 0.0)
	var retreat_v := RangedAmbushBehavior.desired_horizontal_velocity(from, close, 4.0)
	_expect(retreat_v.x < -0.1, "Close target should trigger retreat velocity.")
	var hold_v := RangedAmbushBehavior.desired_horizontal_velocity(from, mid, 4.0)
	_expect(hold_v.length() < 0.2, "Preferred band should hold still.")
	var chase_v := RangedAmbushBehavior.desired_horizontal_velocity(from, far, 4.0)
	_expect(chase_v.x > 0.1, "Far target should approach.")
	_expect(RangedAmbushBehavior.should_fire(7.0, 9.0, 4.0), "Mid range should allow fire.")
	_expect(not RangedAmbushBehavior.should_fire(2.0, 9.0, 4.0), "Face-hug should not fire.")


func _test_content_archetype() -> void:
	var found := false
	for e in Chapter1Content.enemies():
		if String(e.get("id", "")) != "ember_shade_skirmisher":
			continue
		found = true
		_expect(String(e.get("archetype", "")) == "ember_skirmisher", "Content archetype mismatch.")
		_expect(String(e.get("behavior", "")) == "ranged_ambush", "Content behavior mismatch.")
		_expect(float(e.get("attack_range", 0.0)) >= 8.0, "Skirmisher attack_range too short.")
	_expect(found, "Chapter1 missing ember_shade_skirmisher.")


func _test_projectile_setup() -> void:
	var proj = EnemyProjectileScript.new()
	proj.setup(null, Vector3.FORWARD, 11.0, 9.0, {
		"proj_speed": 10.0,
		"action_id": "ember_shade_bolt",
		"tags": ["projectile", "enemy"],
	})
	_expect(is_equal_approx(proj.damage, 11.0), "Projectile damage not applied.")
	_expect(proj.hit_payload.has("tags"), "Projectile payload missing tags.")
	_expect(proj.hit_payload["tags"].has("projectile"), "Projectile tag missing.")
	proj.free()


func _test_enemy_skirmisher_runtime() -> void:
	var enemy = EnemyScript.new()
	root.add_child(enemy)
	enemy.setup(null, null, null, Vector3(0, 1, 0), false, EnemyScript.EnemyType.EMBER_SKIRMISHER)
	_expect(enemy.enemy_type == EnemyScript.EnemyType.EMBER_SKIRMISHER, "setup type not skirmisher.")
	_expect(enemy.attack_range >= 8.0, "Skirmisher legacy attack_range wrong.")
	_expect(enemy._legacy_type_key() == "ember_skirmisher", "legacy mesh key wrong.")
	# 内容映射
	var content_enemy = EnemyScript.new()
	root.add_child(content_enemy)
	content_enemy.setup_from_content(null, null, null, Vector3(1, 1, 0), {
		"id": "ember_shade_skirmisher",
		"archetype": "ember_skirmisher",
		"behavior": "ranged_ambush",
		"max_health": 48.0,
		"attack_range": 9.0,
		"attack": {"windup": 0.5, "active": 0.1, "recovery": 0.7, "damage": 11.0, "stagger": 9.0, "lunge": 0.8},
	}, false)
	_expect(content_enemy.enemy_type == EnemyScript.EnemyType.EMBER_SKIRMISHER, "content map failed.")
	enemy.queue_free()
	content_enemy.queue_free()
