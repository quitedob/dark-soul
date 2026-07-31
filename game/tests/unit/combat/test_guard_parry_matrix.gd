extends "res://addons/gut/test.gd"
## I-08：格挡/招架结算矩阵 — 正面、背后穿透、破防、弹反窗口边界

const GuardResolver = preload("res://scripts/combat/guard_resolver.gd")
const HandEq = preload("res://scripts/data/hand_equipment.gd")
const PlayerScene = preload("res://scenes/actors/player.tscn")
const InputConfigScript = preload("res://scripts/core/input_config.gd")

## 防御者朝向前方（-Z）；命中 direction 为攻击飞行方向
const DEFENDER_FWD := Vector3(0, 0, -1)
const HIT_FROM_FRONT := Vector3(0, 0, 1)
const HIT_FROM_REAR := Vector3(0, 0, -1)

var player
var _shield: Dictionary


func before_each() -> void:
	# 与 FSM/精力套件一致：before_each 建玩家，动画引擎警告不计入学例失败
	InputConfigScript.configure_inputs()
	player = add_child_autofree(PlayerScene.instantiate())
	_shield = HandEq.get_guard_profile("reliquary_shield")
	assert_false(_shield.is_empty(), "reliquary_shield GuardProfile 投影缺失")


func after_each() -> void:
	await get_tree().process_frame


## 构造标准可格挡近战 payload
func _payload(overrides: Dictionary = {}) -> Dictionary:
	var base := {
		"damage": 40.0,
		"stagger": 30.0,
		"guard_damage": 40.0,
		"direction": HIT_FROM_FRONT,
		"blockable": true,
	}
	for key in overrides:
		base[key] = overrides[key]
	return base


## 水平朝向：使 forward · (0,0,-1) == desired_dot
func _forward_for_dot(desired_dot: float) -> Vector3:
	var d := clampf(desired_dot, -1.0, 1.0)
	var lateral := sqrt(maxf(1.0 - d * d, 0.0))
	return Vector3(lateral, 0.0, -d)


## 将玩家置于 PARRY，并固定已过时间 elapsed（秒）
func _arm_parry_at(elapsed: float, item_id: String = "reliquary_shield") -> Dictionary:
	player.set_hand_loadout("guardian_sword", item_id)
	var parry: Dictionary = HandEq.get_item(item_id).get("parry", {})
	assert_false(parry.is_empty(), "%s 缺少 parry 档案" % item_id)
	var startup := float(parry.get("startup", 0.0))
	var active := float(parry.get("active", 0.0))
	var recovery := float(parry.get("recovery", 0.0))
	var total := startup + active + recovery
	# 直接写状态：elapsed = state_duration - state_time
	player.state = player.State.PARRY
	player.state_duration = total
	player.state_time = total - elapsed
	return parry


# ---------- 正面格挡 ----------

func test_frontal_guard_absorbs_damage_and_zeroes_stagger() -> void:
	var result := GuardResolver.resolve(_payload(), true, DEFENDER_FWD, 100.0, _shield, 100.0)
	assert_true(bool(result["guarded"]), "正面命中应被格挡")
	assert_false(bool(result["guard_broken"]), "充足精力/Meter 不应破防")
	assert_lt(float(result["damage"]), 10.0, "吸收后伤害应明显降低")
	assert_almost_eq(float(result["stagger"]), 0.0, 0.001, "成功格挡应清零硬直")
	assert_gt(float(result["stamina_cost"]), 0.0, "格挡应消耗精力")
	assert_lt(float(result["guard_meter_remaining"]), 100.0, "格挡应削减 Guard Meter")


func test_frontal_guard_requires_guard_active() -> void:
	var result := GuardResolver.resolve(_payload(), false, DEFENDER_FWD, 100.0, _shield, 100.0)
	assert_false(bool(result["guarded"]), "未举盾时正面命中不得格挡")
	assert_almost_eq(float(result["damage"]), 40.0, 0.001)


# ---------- 背后穿透 ----------

func test_rear_hit_bypasses_guard() -> void:
	var result := GuardResolver.resolve(
		_payload({"direction": HIT_FROM_REAR}),
		true,
		DEFENDER_FWD,
		100.0,
		_shield,
		100.0
	)
	assert_false(bool(result["guarded"]), "背后命中应穿透格挡")
	assert_false(bool(result["guard_broken"]), "穿透不是破防")
	assert_almost_eq(float(result["damage"]), 40.0, 0.001, "背后应保留全额伤害")
	assert_almost_eq(float(result["stagger"]), 30.0, 0.001, "背后应保留硬直")


func test_guard_angle_edge_at_front_dot_boundary() -> void:
	# 闭区间：dot >= front_dot 格挡；严格小于则穿透（加 epsilon 避开 normalize 浮点）
	var front_dot := float(_shield.get("front_dot", 0.15))
	var held := GuardResolver.resolve(
		_payload(), true, _forward_for_dot(front_dot + 0.001), 100.0, _shield, 100.0
	)
	assert_true(bool(held["guarded"]), "点积略高于 front_dot 应在盾角内")
	var bypass := GuardResolver.resolve(
		_payload(), true, _forward_for_dot(front_dot - 0.001), 100.0, _shield, 100.0
	)
	assert_false(bool(bypass["guarded"]), "点积略低于 front_dot 应穿透")


# ---------- 破防 ----------

func test_guard_break_by_insufficient_stamina() -> void:
	var result := GuardResolver.resolve(_payload(), true, DEFENDER_FWD, 1.0, _shield, 100.0)
	assert_true(bool(result["guarded"]), "破防前仍算进入格挡结算")
	assert_true(bool(result["guard_broken"]), "精力不足应破防")
	assert_eq(String(result["guard_broken_reason"]), "stamina")
	assert_gte(float(result["stagger"]), 36.0, "破防应强制硬直下限")


func test_guard_break_by_direct_impact() -> void:
	var threshold := float(_shield.get("direct_break_threshold", 75.0))
	var result := GuardResolver.resolve(
		_payload({"guard_damage": threshold + 1.0}),
		true,
		DEFENDER_FWD,
		100.0,
		_shield,
		100.0
	)
	assert_true(bool(result["guard_broken"]), "超过直接击穿阈值应破防")
	assert_eq(String(result["guard_broken_reason"]), "direct")


func test_guard_break_by_meter_depletion() -> void:
	var result := GuardResolver.resolve(
		_payload({"guard_damage": 40.0}),
		true,
		DEFENDER_FWD,
		100.0,
		_shield,
		20.0
	)
	assert_true(bool(result["guard_broken"]), "Guard Meter 归零应破防")
	assert_eq(String(result["guard_broken_reason"]), "meter")
	assert_almost_eq(float(result["guard_meter_remaining"]), 0.0, 0.001)


func test_unblockable_bypasses_guard_entirely() -> void:
	var result := GuardResolver.resolve(
		_payload({"blockable": false, "damage": 20.0}),
		true,
		DEFENDER_FWD,
		100.0,
		_shield,
		100.0
	)
	assert_false(bool(result["guarded"]), "unblockable 不得被格挡")
	assert_almost_eq(float(result["damage"]), 20.0, 0.001)


# ---------- 弹反窗口边界 ----------

func test_parry_window_inactive_before_startup() -> void:
	var parry := _arm_parry_at(0.0)
	var startup := float(parry["startup"])
	assert_false(player._is_parry_active(), "startup 前不得激活")
	# 紧贴 startup 内侧
	_arm_parry_at(startup - 0.001)
	assert_false(player._is_parry_active(), "elapsed < startup 仍应关闭")


func test_parry_window_active_at_startup_inclusive() -> void:
	var parry := _arm_parry_at(0.0)
	var startup := float(parry["startup"])
	_arm_parry_at(startup)
	assert_true(player._is_parry_active(), "elapsed == startup 应进入有效窗")


func test_parry_window_active_at_end_inclusive() -> void:
	var parry := _arm_parry_at(0.0)
	var startup := float(parry["startup"])
	var active := float(parry["active"])
	_arm_parry_at(startup + active)
	assert_true(player._is_parry_active(), "elapsed == startup+active 仍有效（闭区间）")


func test_parry_window_inactive_after_active_end() -> void:
	var parry := _arm_parry_at(0.0)
	var startup := float(parry["startup"])
	var active := float(parry["active"])
	_arm_parry_at(startup + active + 0.001)
	assert_false(player._is_parry_active(), "超过 active 末端应关闭")


func test_parry_window_midpoint_is_active() -> void:
	var parry := _arm_parry_at(0.0)
	var startup := float(parry["startup"])
	var active := float(parry["active"])
	_arm_parry_at(startup + active * 0.5)
	assert_true(player._is_parry_active(), "窗口中点必须有效")


func test_buckler_parry_window_wider_than_medium_shield() -> void:
	# 装备差异：小圆盾 active 宽于中盾（E-04 合约）
	var medium: Dictionary = HandEq.get_item("reliquary_shield").get("parry", {})
	var buckler: Dictionary = HandEq.get_item("jade_buckler").get("parry", {})
	assert_gt(float(buckler["active"]), float(medium["active"]), "小圆盾有效窗应更宽")
	# 中盾已过末端时，小圆盾同 elapsed 仍可能有效
	var medium_end := float(medium["startup"]) + float(medium["active"])
	_arm_parry_at(medium_end + 0.01, "reliquary_shield")
	assert_false(player._is_parry_active(), "中盾末端后应关闭")
	var buckler_elapsed := float(buckler["startup"]) + float(medium["active"]) + 0.01
	if buckler_elapsed <= float(buckler["startup"]) + float(buckler["active"]):
		_arm_parry_at(buckler_elapsed, "jade_buckler")
		assert_true(player._is_parry_active(), "同相对偏移下小圆盾仍应有效")
