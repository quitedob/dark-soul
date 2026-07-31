# game/tests/unit/combat/test_poise_resolver.gd
extends "res://addons/gut/test.gd"
## I-15：PoiseResolver 纯逻辑覆盖（无场景树）

const PoiseResolver = preload("res://scripts/combat/poise_resolver.gd")


## 轻击：满储备 + 动作护甲应扛住
func test_poise_holds_under_light_hit() -> void:
	# current=30, base=30, wam=0.3 → capacity=max(30,9)=30；伤害 10*(1-0)=10 → holds
	var result := PoiseResolver.resolve(30.0, 30.0, 0.3, 0.0, 10.0)
	assert_true(bool(result["holds"]), "轻击应被站立储备扛住")
	assert_almost_eq(float(result["settled_poise"]), 20.0, 0.001)
	assert_almost_eq(float(result["reduced_damage"]), 10.0, 0.001)


## 连续削韧：第三下打穿（每击 12，储备 30）
func test_poise_breaks_from_chain() -> void:
	var poise := 30.0
	var base := 30.0
	for i in range(3):
		var hit := PoiseResolver.resolve(poise, base, 0.0, 0.0, 12.0)
		poise = float(hit["settled_poise"])
		if i < 2:
			assert_true(bool(hit["holds"]), "第 %d 击仍应 holds" % (i + 1))
		else:
			assert_false(bool(hit["holds"]), "第 3 击应破韧")
			assert_lt(poise, 0.001)


## 护甲削减有效削韧伤害
func test_armor_reduction_reduces_effective_damage() -> void:
	# PDR 0.3 → 20 * 0.7 = 14
	var result := PoiseResolver.resolve(100.0, 100.0, 0.0, 0.3, 20.0)
	assert_almost_eq(float(result["reduced_damage"]), 14.0, 0.001)
	assert_true(bool(result["holds"]))


## Recovery 阶段 WAM=0：不抬容量
func test_zero_action_armor_during_recovery() -> void:
	var with_wam := PoiseResolver.resolve(10.0, 100.0, 0.35, 0.0, 20.0)
	var recovery := PoiseResolver.resolve(10.0, 100.0, 0.0, 0.0, 20.0)
	assert_true(bool(with_wam["holds"]), "动作护甲应抬高低储备容量")
	assert_false(bool(recovery["holds"]), "recovery WAM=0 不抬容量，应破韧")


## 低储备时动作护甲仍可扛一次轻击
func test_action_armor_boosts_low_reserve() -> void:
	var result := PoiseResolver.resolve(10.0, 100.0, 0.35, 0.30, 20.0)
	assert_true(bool(result["holds"]), "WAM 抬容量后应 holds")
	assert_gt(float(result["settled_poise"]), 0.0)


## 足够削韧可打穿动作护甲
func test_sufficient_damage_breaks_action_armor() -> void:
	var result := PoiseResolver.resolve(10.0, 100.0, 0.35, 0.30, 60.0)
	assert_false(bool(result["holds"]), "大削韧应破动作护甲")
