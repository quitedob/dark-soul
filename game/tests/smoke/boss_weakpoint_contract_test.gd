extends SceneTree
## Boss Execution Break / 五 Boss 目录 / GrabProfile 合约

const Catalog = preload("res://scripts/combat/data/boss_execution_catalog.gd")
const GrabProfileScript = preload("res://scripts/combat/data/grab_profile.gd")
const ExecutionProfileScript = preload("res://scripts/combat/data/execution_profile.gd")
const ExecutionSolver = preload("res://scripts/combat/execution_solver.gd")
const Factory = preload("res://scripts/combat/data/compatibility_moveset_factory.gd")
const PlayerScript = preload("res://scripts/player/player.gd")

var _failures: Array[String] = []


func _init() -> void:
	_test_five_boss_profiles()
	_test_break_accumulation_and_expose()
	_test_story_floor()
	_test_grab_profile()
	_test_charged_break_damage_on_attacks()
	if _failures.is_empty():
		print("ASHEN_BOSS_WEAKPOINT_CONTRACTS_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_five_boss_profiles() -> void:
	var ids := [
		"boss_giant_gate", "boss_xing_tian", "boss_nine_tails", "boss_xuan_xiao", "boss_zhu_yin"
	]
	var profiles := Catalog.all_profiles()
	_expect(profiles.size() == 6, "Need 5 main + 1 optional boss break profiles.")
	for boss_id in ids:
		var p = Catalog.profile_for_boss_id(boss_id)
		_expect(p != null, "Missing profile for %s" % boss_id)
		_expect(p.validate().is_empty(), "Invalid profile %s: %s" % [boss_id, str(p.validate())])
		_expect(float(p.story_floor_ratio) > 0.0, "%s needs story floor." % boss_id)
	# 可选 Boss 盲钟·听烬：致死处决、零剧情地板、空命运旗标（不触发 fate overlay）
	var optional = Catalog.profile_for_boss_id("boss_blind_bell")
	_expect(optional != null, "Missing optional profile for boss_blind_bell.")
	if optional != null:
		_expect(optional.validate().is_empty(), "Invalid optional profile: %s" % str(optional.validate()))
		_expect(is_equal_approx(float(optional.story_floor_ratio), 0.0), "Optional boss must have zero story floor.")
		_expect(bool(optional.allow_lethal_on_execution), "Optional boss must be lethal on execution.")
		_expect(optional.story_flag.is_empty(), "Optional boss must have an empty story flag.")
		_expect(optional.weak_point_anchor == &"bell_mouth", "Optional boss weak-point anchor must be bell_mouth.")
	_expect(is_equal_approx(float(Catalog.make_nine_tails().story_floor_ratio), 0.30), "九尾 floor must be 30%.")
	_expect(is_equal_approx(float(Catalog.make_zhu_yin().story_floor_ratio), 0.10), "烛阴 floor must be 10%.")


func _test_break_accumulation_and_expose() -> void:
	var EnemyScript = load("res://scripts/enemy.gd")
	var enemy = EnemyScript.new()
	root.add_child(enemy)
	enemy.setup_from_content(null, null, null, Vector3.ZERO, {
		"id": "boss_giant_gate",
		"max_health": 360.0,
		"phases": {},
	}, true)
	_expect(enemy.guardian, "Boss setup must set guardian.")
	_expect(enemy.boss_break_profile != null, "Boss break profile missing.")
	_expect(enemy.max_execution_break > 0.0, "max_execution_break unset.")
	enemy.receive_hit_payload({
		"damage": 10.0,
		"stagger": 20.0,
		"execution_break_damage": enemy.max_execution_break * 0.6,
		"tags": ["charged"],
		"direction": Vector3(0, 0, 1),
		"source": null,
	})
	_expect(enemy.execution_break > 0.0 or enemy.state == enemy.State.WEAK_POINT_EXPOSED, "Break should accumulate.")
	# 第二次打满
	enemy.receive_hit_payload({
		"damage": 5.0,
		"stagger": 10.0,
		"execution_break_damage": enemy.max_execution_break,
		"tags": ["charged", "heavy"],
		"direction": Vector3(0, 0, 1),
		"source": null,
	})
	_expect(enemy.state == enemy.State.WEAK_POINT_EXPOSED, "Full break must expose weak point.")
	_expect(enemy.is_execution_candidate(&"weak_point"), "Exposed boss is weak-point candidate.")
	_expect(not enemy.is_execution_candidate(&"back"), "Boss must not allow backstab.")
	var wp = ExecutionProfileScript.make_weak_point(enemy.boss_break_profile)
	_expect(not bool(wp.allow_lethal_damage), "Boss weak-point exec must be non-lethal by default.")
	enemy.queue_free()


func _test_story_floor() -> void:
	var EnemyScript = load("res://scripts/enemy.gd")
	var enemy = EnemyScript.new()
	root.add_child(enemy)
	enemy.setup_from_content(null, null, null, Vector3.ZERO, {"id": "boss_nine_tails", "max_health": 200.0}, true)
	enemy.health = 80.0
	enemy.apply_execution_damage(500.0, false)
	_expect(enemy.health >= enemy.max_health * 0.30 - 0.01, "九尾 execution must respect 30% floor.")
	enemy.queue_free()


func _test_grab_profile() -> void:
	var grab = GrabProfileScript.make_boss_default()
	_expect(grab.validate().is_empty(), "GrabProfile invalid.")
	_expect(not bool(grab.blockable) and not bool(grab.parryable), "Grab must ignore guard/parry.")


func _test_charged_break_damage_on_attacks() -> void:
	var style = PlayerScript.STYLE_RESOURCES[PlayerScript.CombatStyle.RELIQUARY_GUARD]
	var moveset = Factory.create(style, &"one_handed")
	_expect(moveset.neutral_heavy.execution_break_damage > 0.0, "Heavy needs break damage.")
	_expect(
		moveset.charged_heavy.tier_three_attack.execution_break_damage
		> moveset.neutral_heavy.execution_break_damage,
		"Charged T3 should deal more break than neutral heavy."
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
