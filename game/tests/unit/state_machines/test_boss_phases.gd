extends "res://addons/gut/test.gd"
## I-16：Boss 相变 / 招式表 / 剧情血量地板 / Execution Break / 治疗惩罚 GUT 覆盖

const EnemyScene = preload("res://scenes/actors/enemy.tscn")
const Chapter1Content = preload("res://scripts/data/chapter_1_content.gd")

var enemy


func before_each() -> void:
	enemy = add_child_autofree(EnemyScene.instantiate())
	# 巨阙（章一 Boss）：二阶段阈值 0.6，含独立 Execution Break Profile
	enemy.setup_from_content(null, null, null, Vector3(20.0, 0.0, 20.0), Chapter1Content.boss(), true)


func after_each() -> void:
	await get_tree().process_frame


## 相变——血量比例跌破章节阈值应触发二阶段（武器变色、_phase 前进）
func test_boss_phase_transition_fires_at_health_threshold() -> void:
	var threshold_health: float = enemy.max_health * 0.6
	enemy.health = threshold_health + 1.0
	var fired_phases: Array = []
	enemy.phase_changed.connect(func(_e, phase): fired_phases.append(phase))
	enemy.receive_hit_payload({"damage": 5.0, "stagger": 5.0})
	assert_true(enemy._phase_transition_played, "血量越过 60% 阈值应触发二阶段")
	assert_eq(enemy._current_phase(), 2)
	assert_true(fired_phases.has(2), "phase_changed 应广播阶段 2")


## 招式表——不同阶段应从 ChapterContent.phases 各自的 attacks 列表中选招
func test_boss_phase_attack_table_selects_current_phase_attacks() -> void:
	var phase1_names: Array = []
	for atk in Chapter1Content.boss().phases["1"].attacks:
		phase1_names.append(String(atk.name))
	var phase2_names: Array = []
	for atk in Chapter1Content.boss().phases["2"].attacks:
		phase2_names.append(String(atk.name))
	# 阶段 1：满血
	enemy.health = enemy.max_health
	enemy.attack_index = 0
	enemy._select_attack_profile()
	assert_true(
		phase1_names.has(String(enemy._active_attack_profile.get("name", ""))),
		"阶段 1 应选自阶段 1 招式表"
	)
	# 压到阶段 2 血线，招式表应切换
	enemy.health = enemy.max_health * 0.4
	enemy.attack_index = 0
	enemy._select_attack_profile()
	assert_true(
		phase2_names.has(String(enemy._active_attack_profile.get("name", ""))),
		"阶段 2 应选自阶段 2 招式表"
	)


## 剧情血量地板——不可处决击杀的 Boss，处决伤害应停在 story_floor_ratio 并广播剧情阈值
func test_execution_damage_respects_story_floor() -> void:
	var floor_hp: float = enemy.max_health * enemy.boss_break_profile.story_floor_ratio
	enemy.health = floor_hp + 20.0
	var reached := [false]
	enemy.story_threshold_reached.connect(func(_flag, _ratio): reached[0] = true)
	enemy.apply_execution_damage(9999.0, true)
	assert_almost_eq(enemy.health, floor_hp, 0.05)
	assert_true(reached[0], "触底应广播 story_threshold_reached")
	assert_ne(enemy.state, enemy.State.DEAD, "地板保护下不应死亡")


## Execution Break——蓄满应清零槽位、广播 weak_point_exposed 并切换到 WEAK_POINT_EXPOSED
func test_execution_break_fill_triggers_weak_point_exposed() -> void:
	enemy.state = enemy.State.CHASE
	enemy.execution_break = enemy.max_execution_break - 1.0
	var exposed := [false]
	enemy.weak_point_exposed.connect(func(_e): exposed[0] = true)
	enemy.receive_hit_payload({"damage": 5.0, "stagger": 5.0, "execution_break_damage": 500.0})
	assert_eq(enemy.state, enemy.State.WEAK_POINT_EXPOSED)
	assert_true(exposed[0], "应广播 weak_point_exposed")
	assert_almost_eq(enemy.execution_break, 0.0, 0.01)


## 治疗惩罚——玩家开奶应打断待机/追击并插入 WINDUP 前摇（数据驱动 punish 变体）
func test_on_player_healing_triggers_heal_punish_windup() -> void:
	var target: Node3D = add_child_autofree(Node3D.new())
	target.global_position = enemy.global_position + Vector3(0.0, 0.0, -3.0)
	enemy.target_node = target
	enemy.on_player_healing()
	assert_eq(enemy.state, enemy.State.WINDUP)
	assert_ne(enemy._active_heal_punish_variant, &"", "应选定一种治疗惩罚变体")
	assert_true(enemy.engaged, "开奶惩罚应视为接敌")
