# game/scripts/world/arena_director.gd
extends Node
## L-26：Boss 竞技场导演——环带石柱 + 可破坏药罐布景，相变「预警式坍塌」编排。
## 公平链：声光提示（emission 预警闪）→ 震屏请求 → 物理变化（set_deferred 关碰撞）→ 沉降消失。
## 不改共享场景/碰撞默认值；所有节点运行时构建。世界节点负责注入 TraumaShake（可后置、可为 null）。

const JarScene = preload("res://scenes/props/destructible_jar.tscn")

## 环带默认参数（build_arena options 可覆盖）
const DEFAULT_CHUNK_COUNT := 6
const DEFAULT_RING_RADIUS := 8.5
const CHUNK_SIZE := Vector3(1.6, 0.7, 1.6)
const DEFAULT_JAR_COUNT := 5
const JAR_MIN_CENTER_DIST := 3.0
const JAR_MIN_SPACING := 1.6
## 坍塌编排默认节奏（研究值：rumble 1.0-1.5s / 邻柱错峰 0.1-0.2s / 沉降 TRANS_QUAD EASE_IN）
const DEFAULT_RUMBLE_TIME := 1.2
const DEFAULT_SINK_TIME := 1.5
const DEFAULT_CHUNK_STAGGER := 0.12
const SINK_DEPTH := 12.0

var host: Node3D = null
var trauma_shake = null  # TraumaShake 实例（后注入，可能为 null）
var ring_collapsed := false

var _chunks: Array[Dictionary] = []  # {node, collision, mat, base_position, jitter_tween, flash_tween}
var _jars: Array[Node3D] = []
var _rumble_time := DEFAULT_RUMBLE_TIME
var _sink_time := DEFAULT_SINK_TIME
var _chunk_stagger := DEFAULT_CHUNK_STAGGER


## 绑定布景父节点（所有生成的柱/罐挂其下）
func setup(host_node: Node3D) -> void:
	host = host_node


## 世界节点后注入震屏组件（null 安全：注入前不震）
func set_trauma_shake(shake) -> void:
	trauma_shake = shake


## 构建竞技场：center 环心（取 x/z），floor_y 地面高度。
## options：chunk_count / jar_count / ring_radius / floor_y / rumble_time / sink_time / chunk_stagger / seed
func build_arena(center: Vector3, options := {}) -> void:
	if host == null or not is_instance_valid(host):
		push_warning("arena_director: setup(host) 未调用，跳过 build_arena")
		return
	_clear_existing()
	ring_collapsed = false
	_rumble_time = maxf(float(options.get("rumble_time", DEFAULT_RUMBLE_TIME)), 0.05)
	_sink_time = maxf(float(options.get("sink_time", DEFAULT_SINK_TIME)), 0.05)
	_chunk_stagger = maxf(float(options.get("chunk_stagger", DEFAULT_CHUNK_STAGGER)), 0.0)
	var floor_y := float(options.get("floor_y", 0.0))
	var ring_radius := maxf(float(options.get("ring_radius", DEFAULT_RING_RADIUS)), 5.0)
	_build_ring(center, floor_y, ring_radius, int(options.get("chunk_count", DEFAULT_CHUNK_COUNT)))
	_build_jars(center, floor_y, ring_radius, int(options.get("jar_count", DEFAULT_JAR_COUNT)), options)


## Boss 相变入口：读 content 表 phases[str(phase)].arena_event（同 boss_phase_polisher 的 vfx 读法）
func on_boss_phase(enemy: Node3D, new_phase: int) -> void:
	var event := _resolve_arena_event(enemy, new_phase)
	if event == "ring_collapse":
		_collapse_ring()


## Boss 死亡：温和清理残柱（快速沉降、无震屏，不打扰胜利镜头）
func on_boss_died() -> void:
	ring_collapsed = true
	for entry in _chunks:
		var node: Node3D = entry["node"]
		if not is_instance_valid(node):
			continue
		_kill_entry_tweens(entry)
		var collision: CollisionShape3D = entry["collision"]
		if collision != null:
			collision.set_deferred("disabled", true)
		if not is_inside_tree():
			continue
		var base_y := (entry["base_position"] as Vector3).y
		var sink := create_tween()
		sink.tween_property(node, "position:y", base_y - SINK_DEPTH, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		sink.tween_callback(node.queue_free)


# -- 内部 -------------------------------------------------------------------


## 环带石柱：StaticBody3D(layer1/mask0) + 盒碰撞 + 暗石材质（emission 关，坍塌时才点亮）
func _build_ring(center: Vector3, floor_y: float, ring_radius: float, chunk_count: int) -> void:
	var count := maxi(chunk_count, 3)
	for i in range(count):
		var ang := TAU * float(i) / float(count) + PI / 6.0
		var chunk := StaticBody3D.new()
		chunk.name = "ArenaPlinth%d" % i
		chunk.collision_layer = 1
		chunk.collision_mask = 0
		chunk.add_to_group("arena_chunks")
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = CHUNK_SIZE
		collision.shape = shape
		chunk.add_child(collision)
		var visual := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = CHUNK_SIZE
		visual.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.20, 0.22, 0.20)
		mat.roughness = 0.92
		mat.metallic = 0.04
		visual.material_override = mat
		chunk.add_child(visual)
		host.add_child(chunk)
		var base := Vector3(
			center.x + cos(ang) * ring_radius,
			floor_y + CHUNK_SIZE.y * 0.5,
			center.z + sin(ang) * ring_radius
		)
		chunk.global_position = base
		_chunks.append({
			"node": chunk,
			"collision": collision,
			"mat": mat,
			"base_position": base,
			"jitter_tween": null,
			"flash_tween": null,
		})


## 环内散布可破坏药罐：避开中心 3m、罐间距下限；固定种子可复现
func _build_jars(center: Vector3, floor_y: float, ring_radius: float, jar_count: int, options: Dictionary) -> void:
	var count := maxi(jar_count, 0)
	if count == 0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(options.get("seed", "ashen_arena_l26")))
	var inner := JAR_MIN_CENTER_DIST + 1.5
	var outer := maxf(ring_radius - 1.5, inner + 1.0)
	var placed: Array[Vector3] = []
	var tries := 0
	while placed.size() < count and tries < count * 40:
		tries += 1
		var dist := rng.randf_range(inner, outer)
		var ang := rng.randf() * TAU
		var pos := Vector3(center.x + cos(ang) * dist, floor_y, center.z + sin(ang) * dist)
		var ok := true
		for other in placed:
			if Vector2(other.x, other.z).distance_to(Vector2(pos.x, pos.z)) < JAR_MIN_SPACING:
				ok = false
				break
		if ok:
			placed.append(pos)
	# 兜底：拒绝采样不足时按环角补齐
	var i := 0
	while placed.size() < count:
		var ang := TAU * float(i) / float(count) + 0.35
		var dist := lerpf(inner, outer, 0.5)
		placed.append(Vector3(center.x + cos(ang) * dist, floor_y, center.z + sin(ang) * dist))
		i += 1
	for pos in placed:
		var jar := JarScene.instantiate()
		host.add_child(jar)
		jar.global_position = pos
		_jars.append(jar)


## 解析相变的 arena_event（空表/缺键安全返回 ""）
func _resolve_arena_event(enemy: Node3D, new_phase: int) -> String:
	if enemy == null or not is_instance_valid(enemy):
		return ""
	if not ("chapter_content" in enemy):
		return ""
	var content: Dictionary = enemy.chapter_content
	if content.is_empty():
		return ""
	var phases = content.get("phases", {})
	if typeof(phases) != TYPE_DICTIONARY:
		return ""
	var key := str(new_phase)
	if not phases.has(key):
		return ""
	var phase_data: Dictionary = phases[key]
	return String(phase_data.get("arena_event", ""))


## 坍塌编排：每柱错峰 0.12s → rumble 预警（抖动+emission 闪）→ 关碰撞 → 沉降 12m → 释放
func _collapse_ring() -> void:
	if ring_collapsed:
		return
	if _chunks.is_empty():
		return
	ring_collapsed = true
	# 公平链第一环：物理变化前先给震屏提示（组件可能未注入）
	if trauma_shake != null and trauma_shake.has_method("inject_weight"):
		trauma_shake.inject_weight(&"explosion")
	var tree := get_tree()
	if tree == null:
		return
	for i in range(_chunks.size()):
		var entry: Dictionary = _chunks[i]
		var node: Node3D = entry["node"]
		if not is_instance_valid(node):
			continue
		var rumble_delay := float(i) * _chunk_stagger
		var sink_delay := rumble_delay + _rumble_time
		tree.create_timer(rumble_delay).timeout.connect(func() -> void:
			if is_instance_valid(node):
				_start_rumble(entry)
		, CONNECT_ONE_SHOT)
		tree.create_timer(sink_delay).timeout.connect(func() -> void:
			if is_instance_valid(node):
				_sink_chunk(entry)
		, CONNECT_ONE_SHOT)


## rumble 预警：位置抖动（约 0.2s 一循环）+ emission 橙红预警闪
func _start_rumble(entry: Dictionary) -> void:
	if not is_inside_tree():
		return
	var node: Node3D = entry["node"]
	var mat: StandardMaterial3D = entry["mat"]
	var base: Vector3 = entry["base_position"]
	var offset := Vector3(0.06, 0.0, 0.06)
	var jitter := create_tween()
	jitter.set_loops()
	jitter.tween_property(node, "position", base + offset, 0.05)
	jitter.tween_property(node, "position", base - offset, 0.1)
	jitter.tween_property(node, "position", base, 0.05)
	entry["jitter_tween"] = jitter
	if mat != null:
		mat.emission_enabled = true
		mat.emission = Color("ff5522")
		mat.emission_energy_multiplier = 0.4
		var flash := create_tween()
		flash.set_loops()
		flash.tween_property(mat, "emission_energy_multiplier", 1.8, 0.18)
		flash.tween_property(mat, "emission_energy_multiplier", 0.5, 0.18)
		entry["flash_tween"] = flash


## rumble 结束：停抖复位 → set_deferred 关碰撞 → TRANS_QUAD EASE_IN 沉降 12m → 释放
func _sink_chunk(entry: Dictionary) -> void:
	_kill_entry_tweens(entry)
	var node: Node3D = entry["node"]
	var collision: CollisionShape3D = entry["collision"]
	node.position = entry["base_position"]
	if collision != null:
		collision.set_deferred("disabled", true)
	if not is_inside_tree():
		node.queue_free()
		return
	var base_y := (entry["base_position"] as Vector3).y
	var sink := create_tween()
	sink.tween_property(node, "position:y", base_y - SINK_DEPTH, _sink_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	sink.tween_callback(node.queue_free)


func _kill_entry_tweens(entry: Dictionary) -> void:
	for key in ["jitter_tween", "flash_tween"]:
		var tween: Tween = entry.get(key)
		if tween != null and tween.is_valid():
			tween.kill()
		entry[key] = null


## 重复 build 前清理旧布景
func _clear_existing() -> void:
	for entry in _chunks:
		_kill_entry_tweens(entry)
		var node: Node3D = entry["node"]
		if is_instance_valid(node):
			node.queue_free()
	_chunks.clear()
	for jar in _jars:
		if is_instance_valid(jar):
			jar.queue_free()
	_jars.clear()
