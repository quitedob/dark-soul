extends SceneTree
## L-26 合约：Boss-竞技场交互三件套
##   (a) 危害区 telegraph 预警（预警期不监测不伤害；激活即扫场；dot_interval 重判定）
##   (b) 旧元数据（无 telegraph/dot）→ setup 即监测 + 一次性命中（向后兼容）
##   (c) executor radial_aoe + spawn_hazard 键 → last_hazard + 世界 VFX 请求（has_method 守卫）
##   (d) AoE 组呼叫路径砸碎可破坏药罐（近处碎 / 远处不碎）
##   (e) ArenaDirector：环带石柱 + 药罐布景；phase2 arena_event=ring_collapse 预警式坍塌；
##       不重复坍塌；on_boss_died 温和清理
## Run: godot --headless --path game --script res://tests/smoke/arena_interaction_contract_test.gd

const Executor = preload("res://scripts/boss/boss_attack_executor.gd")
const BossAttackHazard = preload("res://scripts/boss/boss_attack_hazard.gd")
const ArenaDirectorScript = preload("res://scripts/world/arena_director.gd")
const TraumaShakeScript = preload("res://scripts/components/trauma_shake.gd")
const JarScene = preload("res://scenes/props/destructible_jar.tscn")
const Chapter1Content = preload("res://scripts/data/chapter_1_content.gd")

const SUCCESS_MARKER := "ASHEN_ARENA_INTERACTION_OK"
var _failures: Array[String] = []


## 玩家层(2)受击桩：receive_hit_payload / receive_hit 记录命中
class StubBody:
	extends CharacterBody3D
	var hits := 0
	var last_damage := 0.0

	func receive_hit_payload(payload: Dictionary) -> void:
		hits += 1
		last_damage = float(payload.get("damage", 0.0))

	func receive_hit(damage, stagger, hit_direction, source) -> void:
		hits += 1
		last_damage = float(damage)


## 世界桩：记录 spawn_boss_impact_vfx 请求 + 提供空候选表
class VfxWorld:
	extends Node3D
	var vfx_calls: Array = []
	var candidates: Array = []

	func get_target_candidates() -> Array:
		return candidates

	func spawn_boss_impact_vfx(position: Vector3, radius: float) -> void:
		vfx_calls.append({"position": position, "radius": radius})


## Boss 桩：携带 chapter_content（on_boss_phase 解析 phases[str].arena_event）
class StubBoss:
	extends Node3D
	var chapter_content := {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_hazard_telegraph_and_dot()
	await _test_hazard_legacy_metadata()
	await _test_executor_spawn_hazard()
	await _test_executor_breaks_jars()
	await _test_arena_director_collapse()
	await _test_arena_director_boss_died()
	if _failures.is_empty():
		print(SUCCESS_MARKER)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


## (a) telegraph 0.2 + dot 0.15：预警期 monitoring=false / 零伤害；激活即监测并扫场命中；DoT 再判定
func _test_hazard_telegraph_and_dot() -> void:
	var arena := Node3D.new()
	arena.name = "HazardTelegraphArena"
	root.add_child(arena)
	var hazard = BossAttackHazard.new()
	arena.add_child(hazard)
	hazard.global_position = Vector3.ZERO
	var body := StubBody.new()
	body.collision_layer = 2  # 玩家层（Area3D mask=2）
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.4
	shape.shape = sphere
	body.add_child(shape)
	arena.add_child(body)
	body.global_position = Vector3(0.6, 0.0, 0.0)
	for i in 4:
		await physics_frame  # 让物理空间先登记刚体
	hazard.setup(null, 14.0, 7.0, {
		"radius": 1.6, "lifetime": 1.4, "telegraph": 0.2, "dot_interval": 0.15,
		"action_id": "l26_telegraph_test",
	})
	_expect(not hazard.monitoring, "telegraph hazard must NOT monitor right after setup")
	await create_timer(0.1).timeout
	_expect(not hazard.monitoring, "telegraph must keep monitoring off mid-warning")
	_expect(body.hits == 0, "telegraph period must deal no damage (got %d hits)" % body.hits)
	await create_timer(0.25).timeout  # 总计 > 0.2s：预警到期激活
	_expect(hazard.monitoring, "hazard must activate (monitoring on) after telegraph")
	for i in 4:
		await physics_frame
	_expect(body.hits >= 1, "activation sweep must hit body inside area (got %d)" % body.hits)
	var after_activation := body.hits
	await create_timer(0.45).timeout
	_expect(body.hits > after_activation, "dot_interval must re-tick damage (%d -> %d)" % [after_activation, body.hits])
	arena.free()


## (b) 旧元数据：无 telegraph → 立即监测；一次性命中（不重复）
func _test_hazard_legacy_metadata() -> void:
	var arena := Node3D.new()
	arena.name = "HazardLegacyArena"
	root.add_child(arena)
	var hazard = BossAttackHazard.new()
	arena.add_child(hazard)
	hazard.global_position = Vector3(60.0, 0.0, 0.0)
	var body := StubBody.new()
	body.collision_layer = 2
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.4
	shape.shape = sphere
	body.add_child(shape)
	arena.add_child(body)
	body.global_position = Vector3(60.5, 0.0, 0.0)
	hazard.setup(null, 10.0, 5.0, {"radius": 1.2, "lifetime": 0.6})
	_expect(hazard.monitoring, "legacy metadata must monitor immediately (compat)")
	for i in 4:
		await physics_frame
	_expect(body.hits == 1, "legacy hazard must hit exactly once (got %d)" % body.hits)
	await create_timer(0.2).timeout
	_expect(body.hits == 1, "legacy hazard must not re-hit without dot_interval (got %d)" % body.hits)
	arena.free()


## (c) radial_aoe + spawn_hazard 键：last_hazard / VFX 桩记录 / 危害区带 telegraph；无键不出危害但仍有 VFX
func _test_executor_spawn_hazard() -> void:
	var ex := Executor.new()
	var attacker := Node3D.new()
	var world := VfxWorld.new()
	root.add_child(attacker)
	root.add_child(world)
	attacker.global_position = Vector3(5.0, 0.0, -3.0)
	attacker.set_meta("g06_world", world)
	ex.execute_active(attacker, attacker, {
		"type": "radial_aoe", "range": 6.0, "damage": 20.0, "stagger": 8.0,
		"name": "furnace_burst", "spawn_hazard": true,
		"hazard_radius": 2.2, "hazard_lifetime": 5.0, "hazard_telegraph": 0.8,
	})
	_expect(ex.last_type == "radial_aoe", "radial_aoe must record last_type")
	_expect(ex.last_hazard, "spawn_hazard radial must set last_hazard")
	_expect(world.vfx_calls.size() == 1, "world vfx stub must record one impact call (got %d)" % world.vfx_calls.size())
	if world.vfx_calls.size() == 1:
		_expect(is_equal_approx(float(world.vfx_calls[0]["radius"]), 6.0), "vfx call must carry aoe radius")
		_expect((world.vfx_calls[0]["position"] as Vector3).distance_to(Vector3(5.0, 0.0, -3.0)) < 0.01,
			"vfx call must carry attacker ground point")
	var hazards: Array = world.find_children("*", "Area3D", true, false)
	_expect(hazards.size() == 1, "spawn_hazard must leave exactly one hazard zone (got %d)" % hazards.size())
	if hazards.size() >= 1:
		var hz: Area3D = hazards[0]
		_expect(not hz.monitoring, "hazard with telegraph 0.8 must hold monitoring off right after execute")
		_expect(hz.global_position.distance_to(attacker.global_position) < 0.01, "hazard must sit at aoe ground point")
	# 反例：无 spawn_hazard 键 → 不留危害区，但冲击通知（VFX）仍发出
	var ex2 := Executor.new()
	ex2.execute_active(attacker, attacker, {"type": "radial_aoe", "range": 6.0, "damage": 10.0, "stagger": 4.0})
	_expect(not ex2.last_hazard, "radial without spawn_hazard must not set last_hazard")
	_expect(world.find_children("*", "Area3D", true, false).size() == 1, "no extra hazard without spawn_hazard key")
	_expect(world.vfx_calls.size() == 2, "arena impact vfx must still be requested without hazard (got %d)" % world.vfx_calls.size())
	attacker.free()
	world.free()


## (d) AoE 组呼叫路径：近处药罐碎 / 远处药罐不碎
func _test_executor_breaks_jars() -> void:
	var host := Node3D.new()
	host.name = "JarBreakHost"
	root.add_child(host)
	var near_jar := JarScene.instantiate()
	near_jar.position = Vector3(1.2, 0.0, 0.4)
	host.add_child(near_jar)
	var far_jar := JarScene.instantiate()
	far_jar.position = Vector3(30.0, 0.0, 30.0)
	host.add_child(far_jar)
	await process_frame  # jar _ready → destructibles 组 + 盒碰撞
	await process_frame
	var ex := Executor.new()
	var attacker := Node3D.new()
	root.add_child(attacker)
	attacker.global_position = Vector3.ZERO
	ex.execute_active(attacker, attacker, {
		"type": "radial_aoe", "range": 4.0, "damage": 15.0, "stagger": 6.0,
		"name": "l26_jar_break_test",
	})
	_expect(bool(near_jar.call("is_broken")), "radial_aoe must break destructible jar in radius via group call")
	_expect(not bool(far_jar.call("is_broken")), "out-of-radius jar must survive the aoe")
	attacker.free()
	host.free()


## (e) ArenaDirector：布景计数 / phase1 无事件 / phase2 环带坍塌（预警→沉降→释放）/ 不重复坍塌
func _test_arena_director_collapse() -> void:
	var arena_host := Node3D.new()
	arena_host.name = "ArenaHost"
	root.add_child(arena_host)
	var director = ArenaDirectorScript.new()
	director.name = "ArenaDirector"
	root.add_child(director)
	director.setup(arena_host)
	var shake := TraumaShakeScript.new()
	shake.name = "ArenaTraumaStub"
	root.add_child(shake)
	director.set_trauma_shake(shake)
	director.build_arena(Vector3(0.0, 0.0, -18.0), {
		"floor_y": 0.0, "rumble_time": 0.2, "sink_time": 0.3, "chunk_stagger": 0.05,
	})
	await process_frame  # 罐 _ready 入组
	await process_frame
	var chunks: Array = get_nodes_in_group("arena_chunks")
	_expect(chunks.size() >= 6, "arena ring must build >= 6 chunks (got %d)" % chunks.size())
	_expect(director._jars.size() == 5, "arena must scatter 5 jars (got %d)" % director._jars.size())
	var jars_grouped := true
	for jar in director._jars:
		if not (jar as Node).is_in_group("destructibles"):
			jars_grouped = false
	_expect(jars_grouped, "director jars must be in destructibles group")
	var jars_clear_of_center := true
	for jar in director._jars:
		var flat := (jar as Node3D).global_position - Vector3(0.0, 0.0, -18.0)
		flat.y = 0.0
		if flat.length() < 3.0:
			jars_clear_of_center = false
	_expect(jars_clear_of_center, "jars must avoid center 3m radius")
	# 真实章内容：phase1 无 arena_event → 不坍塌
	var boss_stub := StubBoss.new()
	boss_stub.chapter_content = Chapter1Content.boss()
	root.add_child(boss_stub)
	director.on_boss_phase(boss_stub, 1)
	await create_timer(0.1).timeout
	_expect(not director.ring_collapsed, "phase 1 has no arena_event — must not collapse")
	# phase2 巨阙 ring_collapse → 预警坍塌
	var start_y := {}
	for chunk in chunks:
		start_y[chunk] = (chunk as Node3D).global_position.y
	director.on_boss_phase(boss_stub, 2)
	_expect(director.ring_collapsed, "phase 2 arena_event=ring_collapse must trigger collapse")
	_expect(shake.trauma > 0.0, "collapse must request trauma shake (got %.3f)" % shake.trauma)
	await create_timer(0.4).timeout
	var freed := 0
	var sinking := 0
	for chunk in chunks:
		if not is_instance_valid(chunk):
			freed += 1
		elif (chunk as Node3D).position.y < float(start_y[chunk]) - 0.05:
			sinking += 1
	_expect(freed + sinking >= 1, "chunks must disable/sink after rumble (freed %d, sinking %d)" % [freed, sinking])
	await create_timer(1.0).timeout
	var alive := 0
	for chunk in chunks:
		if is_instance_valid(chunk):
			alive += 1
	_expect(alive == 0, "all chunks must free after collapse (alive %d)" % alive)
	# 不重复坍塌
	director.on_boss_phase(boss_stub, 2)
	await create_timer(0.2).timeout
	_expect(get_nodes_in_group("arena_chunks").is_empty(), "second phase event must not rebuild/re-collapse ring")
	_expect(director.ring_collapsed, "collapse state must stay latched")
	boss_stub.free()


## 附加：on_boss_died 温和清理（无震屏、快速沉降释放）
func _test_arena_director_boss_died() -> void:
	var host := Node3D.new()
	host.name = "ArenaDiedHost"
	root.add_child(host)
	var director = ArenaDirectorScript.new()
	director.name = "ArenaDirectorDied"
	root.add_child(director)
	director.setup(host)
	director.build_arena(Vector3(40.0, 0.0, 40.0), {
		"chunk_count": 4, "jar_count": 2, "rumble_time": 0.2, "sink_time": 0.2,
	})
	await process_frame
	await process_frame
	var chunks: Array = get_nodes_in_group("arena_chunks")
	_expect(chunks.size() == 4, "died-test arena must build 4 chunks (got %d)" % chunks.size())
	director.on_boss_died()
	await create_timer(0.9).timeout
	var alive := 0
	for chunk in chunks:
		if is_instance_valid(chunk):
			alive += 1
	_expect(alive == 0, "on_boss_died must quietly free remaining chunks (alive %d)" % alive)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
