# game/scripts/boss/boss_attack_hazard.gd
extends Area3D
## L-19：Boss 持续危害区域（trail_hazard）。检测玩家层(2)，进入即受击，时长后自毁。
## 属于 scripts/boss 下的独立 helper（不影响共享场景/碰撞默认值）。
## L-26：可选预警 telegraph（脉动指示，预警期不监测不伤害）+ 可选 dot_interval 周期再命中。
## 默认（无 telegraph / dot_interval 元数据）保持旧契约：setup 即监测、一次性命中。

var source: Node3D
var damage := 20.0
var stagger := 20.0
var _hit_payload: Dictionary = {}
var _already_hit: Dictionary = {}

## L-26：预警 / DoT 状态
var _lifetime := 3.0
var _telegraph := 0.0
var _dot_interval := 0.0
var _active := false
var _expired := false
var _hit_times: Dictionary = {}
var _visual_mesh: MeshInstance3D = null
var _visual_mat: StandardMaterial3D = null
var _telegraph_tween: Tween = null


## 配置伤害与危害元数据
func setup(new_source: Node3D, new_damage: float, new_stagger: float, metadata: Dictionary = {}) -> void:
	source = new_source
	damage = maxf(new_damage, 0.0)
	stagger = maxf(new_stagger, 0.0)
	_lifetime = maxf(float(metadata.get("lifetime", 3.0)), 0.1)
	_telegraph = maxf(float(metadata.get("telegraph", 0.0)), 0.0)
	_dot_interval = maxf(float(metadata.get("dot_interval", 0.0)), 0.0)
	_build(metadata)
	_hit_payload = {
		"damage": damage,
		"stagger": stagger,
		"poise": stagger,
		"guard_damage": metadata.get("guard_damage", damage + stagger * 0.25),
		"direction": Vector3.ZERO,
		"source": source,
		"action_id": String(metadata.get("action_id", "boss_trail_hazard")),
		"tags": ["hazard", "enemy", "boss"],
		"blockable": true,
		"parryable": false,
	}
	body_entered.connect(_on_body_entered)
	if _telegraph > 0.0 and is_inside_tree():
		# L-26：预警期——闪烁指示、不监测、不伤害；须在树内才能用 timer/tween
		monitoring = false
		_begin_telegraph()
	else:
		# L-19 旧路径：立即监测（默认 telegraph==0 时行为不变）
		_active = true
		monitoring = true
		_begin_lifetime()


## 碰撞体 + 视觉：先清默认再启用监测（遵循 Collision 约定）
func _build(metadata: Dictionary) -> void:
	collision_layer = 0
	collision_mask = 0
	set_collision_mask_value(2, true)  # 玩家层
	monitorable = false
	monitoring = false
	var radius := float(metadata.get("radius", 1.6))
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = radius
	collision.shape = shape
	add_child(collision)
	var visual := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	visual.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.35, 0.1, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.25, 0.05)
	mat.emission_energy_multiplier = 1.6
	visual.material_override = mat
	add_child(visual)
	_visual_mesh = visual  # L-26：预警脉动需要
	_visual_mat = mat      # L-26：预警/激活视觉切换需要


func _on_body_entered(body: Node3D) -> void:
	_try_hit(body)


func _expire() -> void:
	_expired = true
	if _telegraph_tween != null and _telegraph_tween.is_valid():
		_telegraph_tween.kill()
		_telegraph_tween = null
	if is_inside_tree():
		queue_free()


# -- L-26：telegraph / DoT ---------------------------------------------------


## 预警期：脉动指示（缩放 + 发光能量），到期激活
func _begin_telegraph() -> void:
	_apply_warning_visual()
	if _visual_mesh == null and _visual_mat == null:
		_finish_telegraph_by_timer()
		return
	_telegraph_tween = create_tween()
	_telegraph_tween.set_loops()
	var base_scale := _visual_mesh.scale if _visual_mesh != null else Vector3.ONE
	if _visual_mesh != null:
		_telegraph_tween.tween_property(_visual_mesh, "scale", base_scale * 1.18, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if _visual_mat != null:
		_telegraph_tween.parallel().tween_property(_visual_mat, "emission_energy_multiplier", 1.9, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if _visual_mesh != null:
		_telegraph_tween.tween_property(_visual_mesh, "scale", base_scale, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if _visual_mat != null:
		_telegraph_tween.parallel().tween_property(_visual_mat, "emission_energy_multiplier", 0.5, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_finish_telegraph_by_timer()


## 预警计时（与视觉分离：即使网格缺失也能按时激活）
func _finish_telegraph_by_timer() -> void:
	var tree := get_tree()
	if tree == null:
		_activate()
		return
	var timer := tree.create_timer(_telegraph)
	timer.timeout.connect(_activate, CONNECT_ONE_SHOT)


## 预警视觉：暗琥珀色闪烁（危险预兆，非伤害态）
func _apply_warning_visual() -> void:
	if _visual_mat == null:
		return
	_visual_mat.albedo_color = Color(1.0, 0.75, 0.3, 0.26)
	_visual_mat.emission = Color(1.0, 0.55, 0.15)
	_visual_mat.emission_energy_multiplier = 0.6


## 激活：停止脉动 → 稳定炽热视觉 → 开监测 → 立即扫场 → 起 DoT
func _activate() -> void:
	if _expired or _active:
		return
	_active = true
	if _telegraph_tween != null and _telegraph_tween.is_valid():
		_telegraph_tween.kill()
		_telegraph_tween = null
	if _visual_mesh != null:
		_visual_mesh.scale = Vector3.ONE
	if _visual_mat != null:
		_visual_mat.albedo_color = Color(1.0, 0.35, 0.1, 0.45)
		_visual_mat.emission = Color(1.0, 0.25, 0.05)
		_visual_mat.emission_energy_multiplier = 1.6
	monitoring = true
	_begin_lifetime()
	_sweep_overlaps()
	# physics 更新前 get_overlapping_bodies 可能为空：下一物理帧补扫一次（限频保证不重复命中）
	var tree := get_tree()
	if tree != null:
		tree.physics_frame.connect(_sweep_overlaps, CONNECT_ONE_SHOT)
	if _dot_interval > 0.0:
		_schedule_dot_tick()


## 生命周期计时（自激活起算；telegraph 不计入）
func _begin_lifetime() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var timer := tree.create_timer(_lifetime)
	timer.timeout.connect(_expire, CONNECT_ONE_SHOT)


## 重查重叠并尝试命中（body_entered 信号可能滞后，tick 不信任信号）
func _sweep_overlaps() -> void:
	if _expired or not _active:
		return
	for body in get_overlapping_bodies():
		_try_hit(body)


## DoT 周期：每 dot_interval 重扫一次
func _schedule_dot_tick() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var timer := tree.create_timer(_dot_interval)
	timer.timeout.connect(_on_dot_tick, CONNECT_ONE_SHOT)


func _on_dot_tick() -> void:
	if _expired or not _active or not is_inside_tree():
		return
	_sweep_overlaps()
	_schedule_dot_tick()


## 限频命中：DoT 按 per-body 时间戳；旧契约为一次性（_already_hit）
func _try_hit(body: Node3D) -> void:
	if _expired or not _active:
		return
	if body == null or not is_instance_valid(body):
		return
	if _dot_interval > 0.0:
		var now := Time.get_ticks_msec() / 1000.0
		var last := float(_hit_times.get(body, -1.0e9))
		if now - last < _dot_interval:
			return
		_hit_times[body] = now
	else:
		if _already_hit.has(body):
			return
		_already_hit[body] = true
	var dir := body.global_position - global_position
	if dir.length_squared() < 0.001:
		dir = Vector3.FORWARD
	else:
		dir = dir.normalized()
	if body.has_method("receive_hit_payload"):
		var payload := _hit_payload.duplicate(true)
		payload["direction"] = dir
		payload["source"] = source
		body.receive_hit_payload(payload)
	elif body.has_method("receive_hit"):
		body.receive_hit(damage, stagger, dir, source)
