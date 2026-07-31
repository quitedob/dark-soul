# game/tests/unit/combat/test_hit_deduplication.gd
extends "res://addons/gut/test.gd"
## I-05：同一挥击对同一 body 只结算一次（already_hit 去重）

const CombatAreaScript = preload("res://scripts/combat_area.gd")
const HitVictimStub = preload("res://tests/unit/combat/support/hit_victim_stub.gd")

var area: Area3D
var source: CharacterBody3D


func before_each() -> void:
	# 攻击源与命中体积挂到场景树，便于方向与生命周期
	source = CharacterBody3D.new()
	source.name = "AttackSource"
	add_child_autofree(source)
	area = CombatAreaScript.new()
	area.name = "CombatAreaUnderTest"
	add_child_autofree(area)
	area.configure(source, 1.25, 1.45, Vector3(0.0, 1.0, -1.0))


func after_each() -> void:
	await get_tree().process_frame


## 构造可 double 的受击体并加入场景树（stub 静默，靠 spy 计数）
func _make_victim_double():
	var victim = double(HitVictimStub).new()
	stub(victim, "receive_hit_payload").to_do_nothing()
	stub(victim, "receive_hit").to_do_nothing()
	add_child_autofree(victim)
	return victim


## 开启一记挥击（清空 already_hit 并激活监测）
func _start_swing(damage_amount: float = 12.0, stagger_amount: float = 8.0) -> void:
	area.begin_swing(damage_amount, stagger_amount, {"action_id": "i05_test_swing"})


func test_same_body_settles_once_per_swing_via_spy() -> void:
	# double + assert_called：同 body 连入三次只结算一次
	var victim = _make_victim_double()
	_start_swing(15.0, 10.0)
	area._on_body_entered(victim)
	area._on_body_entered(victim)
	area._on_body_entered(victim)
	assert_called(victim, "receive_hit_payload")
	assert_called_count(victim.receive_hit_payload, 1)
	assert_true(area.already_hit.has(victim), "Victim must be marked in already_hit.")


func test_two_bodies_each_settle_once() -> void:
	# 不同 body 各自结算一次，互不抢占去重表
	var victim_a = _make_victim_double()
	var victim_b = _make_victim_double()
	_start_swing()
	area._on_body_entered(victim_a)
	area._on_body_entered(victim_b)
	area._on_body_entered(victim_a)
	area._on_body_entered(victim_b)
	assert_called_count(victim_a.receive_hit_payload, 1)
	assert_called_count(victim_b.receive_hit_payload, 1)


func test_new_swing_allows_same_body_again() -> void:
	# end_swing/begin_swing 清空去重后，下一挥可再次命中
	var victim = _make_victim_double()
	_start_swing(10.0, 5.0)
	area._on_body_entered(victim)
	assert_called_count(victim.receive_hit_payload, 1)
	area.end_swing()
	_start_swing(10.0, 5.0)
	area._on_body_entered(victim)
	assert_called_count(victim.receive_hit_payload, 2)


func test_damage_count_also_dedupes_without_spy() -> void:
	# 直接伤害计数路径：同挥击多次进入只加一次伤害
	var victim = HitVictimStub.new()
	add_child_autofree(victim)
	_start_swing(20.0, 6.0)
	area._on_body_entered(victim)
	area._on_body_entered(victim)
	area._on_body_entered(victim)
	assert_eq(victim.hit_count, 1)
	assert_almost_eq(victim.damage_taken, 20.0, 0.001)


func test_source_body_is_ignored() -> void:
	# 攻击源自身进入 hitbox 不结算
	var source_as_victim = double(HitVictimStub).new()
	stub(source_as_victim, "receive_hit_payload").to_do_nothing()
	add_child_autofree(source_as_victim)
	area.source = source_as_victim
	_start_swing()
	area._on_body_entered(source_as_victim)
	assert_not_called(source_as_victim, "receive_hit_payload")
	assert_false(area.already_hit.has(source_as_victim))


func test_inactive_swing_does_not_settle() -> void:
	# 未 begin 或已 end 时不应结算
	var victim = _make_victim_double()
	area._on_body_entered(victim)
	assert_not_called(victim, "receive_hit_payload")
	_start_swing()
	area.end_swing()
	area._on_body_entered(victim)
	assert_not_called(victim, "receive_hit_payload")


func test_hit_landed_emits_once_per_body_per_swing() -> void:
	# hit_landed 与伤害结算共享 already_hit，同体只发一次
	var victim = HitVictimStub.new()
	add_child_autofree(victim)
	var emit_count := [0]
	area.hit_landed.connect(func(_target, _heavy): emit_count[0] += 1)
	_start_swing(40.0, 12.0)
	area._on_body_entered(victim)
	area._on_body_entered(victim)
	assert_eq(emit_count[0], 1)
	assert_eq(victim.hit_count, 1)
