extends SceneTree
## G-05：全敌 AI 调参与 behavior 注册合约

const EnemyAiCatalog = preload("res://scripts/data/enemy_ai_catalog.gd")
const EnemyBehaviorRegistry = preload("res://scripts/enemy/enemy_behavior_registry.gd")
const EnemyScript = preload("res://scripts/enemy.gd")
const Chapter1Content = preload("res://scripts/data/chapter_1_content.gd")
const AmbushBehavior = preload("res://scripts/enemy/behaviors/ambush_behavior.gd")
const PatrolBehavior = preload("res://scripts/enemy/behaviors/patrol_behavior.gd")

var _failures: Array[String] = []


func _init() -> void:
	_test_catalog_coverage()
	_test_all_behaviors_resolve()
	_test_defensive_hold_leash()
	_test_teleport_ambush()
	_test_patrol_moves()
	if _failures.is_empty():
		print("ASHEN_ENEMY_AI_TUNING_CONTRACTS_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_catalog_coverage() -> void:
	var profiles := EnemyAiCatalog.all_enemy_profiles()
	_expect(profiles.size() >= 32, "Catalog should cover at least 32 enemy types (got %d)." % profiles.size())
	for p in profiles:
		_expect(float(p.get("aggro_range", 0.0)) > 0.0, "Missing aggro_range on %s" % p.get("id"))
		_expect(float(p.get("leash_range", 0.0)) > 0.0, "Missing leash_range on %s" % p.get("id"))
		_expect(float(p.get("nav_radius", 0.0)) > 0.0, "Missing nav_radius on %s" % p.get("id"))
		_expect(not String(p.get("behavior", "")).is_empty(), "Missing behavior on %s" % p.get("id"))


func _test_all_behaviors_resolve() -> void:
	for p in EnemyAiCatalog.all_enemy_profiles():
		var tag := String(p.get("behavior", ""))
		_expect(EnemyBehaviorRegistry.is_registered(tag), "Unregistered behavior: %s" % tag)
		var mod = EnemyBehaviorRegistry.create_module(tag)
		_expect(mod != null, "Null module for behavior: %s" % tag)


func _test_defensive_hold_leash() -> void:
	var raw := Chapter1Content.enemies()[1]
	var base_leash := float(raw["leash_range"])
	var enemy = EnemyScript.new()
	root.add_child(enemy)
	enemy.setup_from_content(null, null, null, Vector3.ZERO, raw, false)
	_expect(enemy.leash_range < base_leash, "defensive_hold should tighten leash_range.")
	enemy.queue_free()


## 直接测 Ambush 模块（不依赖 SceneTree 入树时序）
func _test_teleport_ambush() -> void:
	var mod = AmbushBehavior.new("teleport_ambush")
	var enemy := CharacterBody3D.new()
	var player := CharacterBody3D.new()
	enemy.position = Vector3(8, 0, 0)
	player.position = Vector3.ZERO
	var before: Vector3 = enemy.position
	mod.on_engage(enemy, player)
	_expect(mod.did_teleport(), "teleport_ambush should relocate on engage.")
	_expect(enemy.position.distance_to(before) > 0.5, "Ambush teleport distance too small.")
	enemy.free()
	player.free()


## 直接测 Patrol 模块速度积分
func _test_patrol_moves() -> void:
	var mod = PatrolBehavior.new("slow_patrol")
	var enemy := CharacterBody3D.new()
	enemy.set_meta("g05_spawn_origin", Vector3.ZERO)
	enemy.set("acceleration", 15.0)
	enemy.set("move_speed", 3.2)
	enemy.velocity = Vector3.ZERO
	enemy.position = Vector3.ZERO
	var pos := Vector3.ZERO
	for i in range(40):
		mod.update_idle(enemy, 0.1)
		pos.x += enemy.velocity.x * 0.1
		pos.z += enemy.velocity.z * 0.1
		enemy.position = pos
	_expect(pos.distance_to(Vector3.ZERO) > 0.15, "slow_patrol should leave spawn origin.")
	enemy.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
