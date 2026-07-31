extends SceneTree
## G-06：章专属 Boss 超能力合约（瞬移链 / 引力 / 局部时间）

const BossAttackExecutor = preload("res://scripts/boss/boss_attack_executor.gd")
const Chapter3Content = preload("res://scripts/data/chapter_3_content.gd")
const Chapter4Content = preload("res://scripts/data/chapter_4_content.gd")
const Chapter5Content = preload("res://scripts/data/chapter_5_content.gd")
const EnemyScript = preload("res://scripts/enemy.gd")

var _failures: Array[String] = []


func _init() -> void:
	_test_global_time_scale_untouched()
	_test_nine_tails_chain_teleport()
	_test_xuan_xiao_pull()
	_test_zhu_yin_local_time()
	_test_phase_four_support()
	if _failures.is_empty():
		print("ASHEN_BOSS_CHAPTER_POWERS_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_global_time_scale_untouched() -> void:
	_expect(is_equal_approx(Engine.time_scale, 1.0), "Engine.time_scale must stay 1.0 before tests.")


## 九尾：chain_teleport hops ≥ chain_count
func _test_nine_tails_chain_teleport() -> void:
	var ex = BossAttackExecutor.new()
	var boss := CharacterBody3D.new()
	var player := CharacterBody3D.new()
	boss.position = Vector3(10, 0, 0)
	player.position = Vector3.ZERO
	var attack := {"type": "chain_teleport", "chain_count": 4}
	var before: Vector3 = boss.position
	ex.execute_active(boss, player, attack)
	_expect(ex.teleport_hops >= 4, "chain_teleport should hop chain_count times.")
	_expect(boss.position.distance_to(before) > 0.5, "Boss should relocate after chain teleport.")
	_expect(is_equal_approx(Engine.time_scale, 1.0), "Teleport must not touch time_scale.")
	boss.free()
	player.free()


## 玄霄：pull 后玩家更靠近 Boss
func _test_xuan_xiao_pull() -> void:
	var ex = BossAttackExecutor.new()
	var boss := CharacterBody3D.new()
	var player := CharacterBody3D.new()
	boss.position = Vector3.ZERO
	player.position = Vector3(4, 0, 0)
	player.velocity = Vector3.ZERO
	var before_dist: float = player.position.distance_to(boss.position)
	ex.execute_active(boss, player, {"type": "pull_in_aoe", "range": 6.0})
	_expect(ex.last_pull_applied, "pull_in_aoe should apply within range.")
	# 积分一帧速度
	player.position += player.velocity * 0.1
	var after_dist: float = player.position.distance_to(boss.position)
	_expect(after_dist < before_dist, "Pull should reduce distance to boss.")
	_expect(is_equal_approx(Engine.time_scale, 1.0), "Gravity pull must not touch time_scale.")
	boss.free()
	player.free()


## 烛阴：局部 dilation ≠ 1 且全局 time_scale == 1
func _test_zhu_yin_local_time() -> void:
	var ex = BossAttackExecutor.new()
	var boss := CharacterBody3D.new()
	var player := CharacterBody3D.new()
	boss.position = Vector3.ZERO
	player.position = Vector3(2, 0, 0)
	ex.execute_active(boss, player, {"type": "freeze_then_strike"})
	_expect(not is_equal_approx(ex.last_dilation, 1.0), "freeze_then_strike should set local dilation.")
	_expect(player.has_meta("g06_time_dilation"), "Player should carry local dilation meta.")
	_expect(is_equal_approx(Engine.time_scale, 1.0), "Local time must keep Engine.time_scale=1.")
	# rewind status
	player.set("last_safe_transform", Transform3D(Basis.IDENTITY, Vector3(1, 0, 1)))
	ex.execute_active(boss, player, {"type": "status", "effect": "rewind_player_position"})
	_expect(ex.last_rewind, "chrono rewind status should flag rewind.")
	boss.free()
	player.free()


## 烛阴 phase 4 阈值可解析
func _test_phase_four_support() -> void:
	var enemy = EnemyScript.new()
	root.add_child(enemy)
	var boss := Chapter5Content.boss()
	enemy.setup_from_content(null, null, null, Vector3.ZERO, boss, true)
	_expect(enemy._content_phase_four_threshold > 0.0, "Zhu Yin should parse phase 4 threshold.")
	_expect(enemy._content_phase_attacks.has(4), "Zhu Yin should have phase 4 attacks.")
	# 血量压到 5% → phase 4
	enemy.health = enemy.max_health * 0.05
	_expect(enemy._current_phase() == 4, "Health below phase4 threshold should report phase 4.")
	# 九尾/玄霄 content 含签名 type
	_expect(_boss_has_type(Chapter3Content.boss(), "chain_teleport"), "Nine-tails content missing chain_teleport.")
	var xuan := _find_xuan_xiao()
	_expect(_boss_has_type(xuan, "pull_in_aoe"), "Xuan Xiao content missing pull_in_aoe.")
	enemy.queue_free()


func _find_xuan_xiao() -> Dictionary:
	for b in Chapter4Content.bosses():
		if String(b.get("id", "")) == "boss_xuan_xiao":
			return b
	return {}


func _boss_has_type(boss: Dictionary, atype: String) -> bool:
	var phases = boss.get("phases", {})
	if not phases is Dictionary:
		return false
	for key in phases.keys():
		for atk in phases[key].get("attacks", []):
			if String(atk.get("type", "")) == atype:
				return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
