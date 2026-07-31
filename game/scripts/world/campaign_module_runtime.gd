class_name CampaignModuleRuntime
extends Node
## 激活关卡模块行为 + H-05 shortcut 空间折叠（单向门 / 升降梯回祠堂）

signal exit_requested(level_id: StringName)
signal fragile_collapsed(module: Node3D)
signal shortcut_fold_opened(shortcut_id: String)

const LocalizationScript = preload("res://scripts/core/localization.gd")

var _player: Node3D
var _hud: Node
var _audio: Node
var _level_root: Node3D
var _wired: Array[Node] = []
var _exit_cooldown := 0.0
var _projectile_lanes: Array[Dictionary] = []
var _moving_platforms: Array[Dictionary] = []


func bind(player: Node3D, hud: Node, audio: Node) -> void:
	# 绑定世界侧依赖
	_player = player
	_hud = hud
	_audio = audio


func activate(level_root: Node3D) -> void:
	# 清理旧连线后扫描当前关卡模块与折叠拓扑
	clear()
	_level_root = level_root
	if level_root == null:
		return
	var modules := level_root.get_node_or_null("Modules")
	if modules != null:
		for module in modules.get_children():
			if not module is Node3D:
				continue
			var module_id := StringName(module.get_meta("module_id", &""))
			match module_id:
				&"fragile_floor":
					_wire_fragile_floor(module as Node3D)
				&"gate_exit":
					_wire_gate_exit(module as Node3D)
				&"poison_fire_zone", &"hazard":
					_wire_damage_zone(module as Node3D)
				&"arena_seal":
					_wire_arena_seal(module as Node3D)
				&"switch_offering":
					_wire_switch_offering(module as Node3D)
				&"moving_platform":
					_wire_moving_platform(module as Node3D)
				&"projectile_lane":
					_wire_projectile_lane(module as Node3D)
				&"illusion_marker":
					_wire_illusion_marker(module as Node3D)
				&"gravity_visual_zone":
					_wire_gravity_visual_zone(module as Node3D)
				# —— L-16/L-17 扩充谜题族 ——
				&"mirror_light":
					_wire_mirror_light(module as Node3D)
				&"valve_shutoff":
					_wire_valve_shutoff(module as Node3D)
				&"celestial_dial":
					_wire_celestial_dial(module as Node3D)
				&"alchemy_ingredients":
					_wire_alchemy_ingredients(module as Node3D)
				&"gravity_anchor":
					_wire_gravity_anchor(module as Node3D)
				&"gravity_inversion":
					_wire_gravity_inversion(module as Node3D)
				&"riddle_gate":
					_wire_riddle_gate(module as Node3D)
				&"stealth_passage":
					_wire_stealth_passage(module as Node3D)
				&"memory_verification":
					_wire_memory_verification(module as Node3D)
				&"soul_forger_trial":
					_wire_soul_forger_trial(module as Node3D)
	_wire_shortcut_fold(level_root)


func clear() -> void:
	# 断开并释放运行时挂件
	for node in _wired:
		if is_instance_valid(node):
			node.queue_free()
	_wired.clear()
	_projectile_lanes.clear()
	_moving_platforms.clear()
	_level_root = null


func _process(delta: float) -> void:
	if _exit_cooldown > 0.0:
		_exit_cooldown = maxf(_exit_cooldown - delta, 0.0)
	_tick_projectile_lanes(delta)
	_tick_moving_platforms(delta)


func _wire_fragile_floor(module: Node3D) -> void:
	# 在静态地板上叠加触发区，踩踏后延迟崩塌
	var floor_body := module.get_node_or_null("FragileFloor") as StaticBody3D
	if floor_body == null:
		return
	var trigger := Area3D.new()
	trigger.name = "FragileTrigger"
	trigger.collision_layer = 0
	trigger.collision_mask = 2
	trigger.monitoring = true
	trigger.monitorable = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.0, 1.2, 4.0)
	shape.shape = box
	shape.position.y = 0.6
	trigger.add_child(shape)
	module.add_child(trigger)
	_wired.append(trigger)
	var delay := float(module.get_meta("collapse_delay", 2.0))
	var collapsing := {"active": false}
	trigger.body_entered.connect(func(body: Node3D) -> void:
		if collapsing["active"]:
			return
		if body != _player:
			return
		collapsing["active"] = true
		_notify(LocalizationScript.text("THE FLOOR GROANS"), 1.2)
		var timer := get_tree().create_timer(delay)
		timer.timeout.connect(func() -> void:
			if not is_instance_valid(module):
				return
			_collapse_fragile(module, floor_body)
		)
	)


func _collapse_fragile(module: Node3D, floor_body: StaticBody3D) -> void:
	# 禁用碰撞并淡出视觉
	for child in floor_body.get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).disabled = true
		elif child is MeshInstance3D:
			var mesh := child as MeshInstance3D
			var tween := create_tween()
			tween.tween_property(mesh, "transparency", 1.0, 0.45)
	floor_body.visible = false
	_play("death", -8.0, 0.55)
	fragile_collapsed.emit(module)


func _wire_gate_exit(module: Node3D) -> void:
	# 出口门交互：靠近后可用交互推进下一关
	var gate := module.get_node_or_null("Gate") as StaticBody3D
	var marker := module.get_node_or_null("ExitMarker") as Marker3D
	var ExitScript = load("res://scripts/world/campaign_exit_interact.gd")
	var interact: Area3D = ExitScript.new()
	interact.name = "GateExitInteract"
	interact.collision_layer = 8
	interact.collision_mask = 0
	interact.monitoring = false
	interact.monitorable = true
	interact.add_to_group("interactable")
	interact.set_meta("campaign_exit", true)
	interact.prompt_text = LocalizationScript.text("Advance to the next ruin")
	interact.world_callback = Callable(self, "_on_exit_interact")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.2, 3.0, 2.4)
	shape.shape = box
	shape.position = marker.position if marker != null else Vector3(0.0, 1.2, -1.2)
	interact.add_child(shape)
	module.add_child(interact)
	_wired.append(interact)
	if gate != null:
		gate.set_meta("is_campaign_exit", true)


func _on_exit_interact(_interactable: Node, _player: Node) -> void:
	# 出口交互回调 → 发出关卡推进信号
	if _exit_cooldown > 0.0:
		return
	_exit_cooldown = 1.5
	var level_id: StringName = &""
	if _level_root != null:
		level_id = StringName(_level_root.get_meta("level_id", &""))
	exit_requested.emit(level_id)


func _wire_damage_zone(module: Node3D) -> void:
	# 伤害区：玩家进入持续扣血
	var area: Area3D = null
	for child in module.get_children():
		if child is Area3D:
			area = child
			break
	if area == null:
		return
	area.monitoring = true
	area.collision_mask = 2
	var dps := float(module.get_meta("damage_per_second", 8.0))
	area.set_meta("hazard_dps", dps)
	area.set_meta("hazard_active", true)
	_wired.append(area)


func _wire_arena_seal(module: Node3D) -> void:
	# 进场后升起封场墙；Boss 击败后由 release_arena_seals 降下
	var trigger := module.get_node_or_null("ArenaTrigger") as Area3D
	var seal := module.get_node_or_null("ArenaSeal") as StaticBody3D
	if seal != null:
		_set_static_colliders_enabled(seal, false)
		seal.visible = false
		seal.set_meta("arena_sealed", false)
	if trigger == null:
		return
	trigger.monitoring = true
	trigger.collision_mask = 2
	var sealed := {"active": false}
	trigger.body_entered.connect(func(body: Node3D) -> void:
		if sealed["active"] or body != _player:
			return
		sealed["active"] = true
		if seal != null and is_instance_valid(seal):
			_set_static_colliders_enabled(seal, true)
			seal.visible = true
			seal.set_meta("arena_sealed", true)
		_notify(LocalizationScript.text("THE SEAL LOCKS"), 1.5)
		_play("rest", -6.0, 0.7)
	)


func _wire_switch_offering(module: Node3D) -> void:
	# 供物台：交互达标后解除 TargetMarker 处屏障
	var activator := module.get_node_or_null("Activator") as Area3D
	var marker := module.get_node_or_null("TargetMarker") as Marker3D
	if activator == null:
		return
	var required := int(module.get_meta("required_count", 1))
	var barrier := StaticBody3D.new()
	barrier.name = "OfferingBarrier"
	barrier.collision_layer = 1
	var barrier_shape := CollisionShape3D.new()
	var barrier_box := BoxShape3D.new()
	barrier_box.size = Vector3(3.0, 3.0, 0.5)
	barrier_shape.shape = barrier_box
	barrier_shape.position = marker.position if marker != null else Vector3(0.0, 1.5, -4.0)
	barrier.add_child(barrier_shape)
	module.add_child(barrier)
	_wired.append(barrier)
	var ExitScript = load("res://scripts/world/campaign_exit_interact.gd")
	var interact: Area3D = ExitScript.new()
	interact.name = "OfferingInteract"
	interact.collision_layer = 8
	interact.collision_mask = 0
	interact.monitoring = false
	interact.monitorable = true
	interact.add_to_group("interactable")
	interact.prompt_text = LocalizationScript.text("Offer the relic")
	var progress := {"count": 0}
	interact.world_callback = func(_a: Node, _p: Node) -> void:
		if progress["count"] >= required:
			return
		progress["count"] += 1
		if progress["count"] < required:
			_notify(LocalizationScript.text("OFFERING %d / %d") % [progress["count"], required], 1.2)
			return
		_set_static_colliders_enabled(barrier, false)
		barrier.visible = false
		_notify(LocalizationScript.text("THE PATH ACCEPTS THE OFFERING"), 1.8)
		_play("rest", -5.0, 1.1)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.0, 2.0, 2.0)
	shape.shape = box
	shape.position.y = 1.0
	interact.add_child(shape)
	module.add_child(interact)
	_wired.append(interact)


func _wire_moving_platform(module: Node3D) -> void:
	# 往返平台：在原点与 TravelEnd 间振荡
	var platform := module.get_node_or_null("Platform") as AnimatableBody3D
	var end_marker := module.get_node_or_null("TravelEnd") as Marker3D
	if platform == null:
		return
	var travel := end_marker.position if end_marker != null else Vector3(0.0, 3.0, 0.0)
	var duration := maxf(float(module.get_meta("travel_time", 3.0)), 0.4)
	_moving_platforms.append({
		"platform": platform,
		"origin": platform.position,
		"travel": travel,
		"duration": duration,
		"elapsed": 0.0,
	})


func _wire_projectile_lane(module: Node3D) -> void:
	# 弹道廊：按 interval 脉冲伤害进入廊道的玩家
	var area := module.get_node_or_null("ProjectileLane") as Area3D
	if area == null:
		return
	area.monitoring = true
	area.collision_mask = 2
	_projectile_lanes.append({
		"area": area,
		"interval": maxf(float(module.get_meta("interval", 2.0)), 0.4),
		"damage": float(module.get_meta("damage", 12.0)),
		"accum": 0.0,
		"module": module,
	})


func _wire_illusion_marker(module: Node3D) -> void:
	# 幻象标记：进入感知区时提示假路/轮回歧路
	var sense := module.get_node_or_null("IllusionSense") as Area3D
	if sense == null:
		return
	sense.monitoring = true
	sense.collision_mask = 2
	var kind := StringName(module.get_meta("illusion_kind", &"false_path"))
	var shown := {"active": false}
	sense.body_entered.connect(func(body: Node3D) -> void:
		if shown["active"] or body != _player:
			return
		shown["active"] = true
		match kind:
			&"samsara_fork":
				_notify(LocalizationScript.text("A FORK OF WHAT MIGHT HAVE BEEN"), 1.8)
			_:
				_notify(LocalizationScript.text("THE PATH LIES"), 1.5)
		_play("rest", -9.0, 1.3)
	)
	sense.body_exited.connect(func(body: Node3D) -> void:
		if body == _player:
			shown["active"] = false
	)


func _wire_gravity_visual_zone(module: Node3D) -> void:
	# 重力操作区（L-16）：进入真正倒置玩家重力（取反号），离开恢复；速度偏置保留为次级效果
	var area := module.get_node_or_null("GravityVisualZone") as Area3D
	if area == null:
		return
	area.monitoring = true
	area.collision_mask = 2
	var direction: Vector3 = module.get_meta("visual_direction", Vector3.UP)
	if typeof(direction) != TYPE_VECTOR3:
		direction = Vector3.UP
	area.body_entered.connect(func(body: Node3D) -> void:
		if body != _player:
			return
		_notify(LocalizationScript.text("GRAVITY SHIFTS"), 1.2)
		_play("rest", -8.0, 0.55)
		if body is CharacterBody3D:
			var cb := body as CharacterBody3D
			cb.velocity += direction.normalized() * 2.4
			_set_gravity_inverted(cb, true, module)
	)
	area.body_exited.connect(func(body: Node3D) -> void:
		if body != _player:
			return
		if body is CharacterBody3D:
			_set_gravity_inverted(body as CharacterBody3D, false, module)
	)


func _wire_gravity_inversion(module: Node3D) -> void:
	# L-16 专属重力倒置区：纯翻转，不含速度偏置
	var area := module.get_node_or_null("InvertZone") as Area3D
	if area == null:
		return
	area.monitoring = true
	area.collision_mask = 2
	area.body_entered.connect(func(body: Node3D) -> void:
		if body != _player:
			return
		if body is CharacterBody3D:
			_set_gravity_inverted(body as CharacterBody3D, true, module)
			_notify(LocalizationScript.text("GRAVITY INVERTED"), 1.3)
			_play("rest", -7.0, 0.9)
	)
	area.body_exited.connect(func(body: Node3D) -> void:
		if body != _player:
			return
		if body is CharacterBody3D:
			_set_gravity_inverted(body as CharacterBody3D, false, module)
	)


func _set_gravity_inverted(player: CharacterBody3D, inverted: bool, module: Node3D) -> void:
	# 玩家 gravity 是普通 var（DEFAULT_GRAVITY 24.0）：进入倒置时取反号，退出还原
	if player == null or not ("gravity" in player):
		return
	if not module.has_meta("gravity_original_sign"):
		module.set_meta("gravity_original_sign", signf(float(player.gravity)))
	var magnitude := absf(float(player.gravity))
	var original := signf(float(module.get_meta("gravity_original_sign", 1.0)))
	player.set("gravity", magnitude * (-original if inverted else original))


func _wire_mirror_light(module: Node3D) -> void:
	# 镜光谜题：转动镜面点亮光束，玩家站在光束内充能后开启受光之门
	var mirror := module.get_node_or_null("MirrorBody") as StaticBody3D
	var beam := module.get_node_or_null("LightBeam") as Area3D
	var marker := module.get_node_or_null("ReceptorMarker") as Marker3D
	if mirror == null or beam == null:
		return
	var charge_seconds := maxf(float(module.get_meta("charge_seconds", 1.6)), 0.4)
	var gate := _make_gate_barrier(module, "MirrorGate", marker, Vector3(3.0, 3.0, 0.5))
	var state := {"beam_on": false, "charging": false, "accum": 0.0, "opened": false}
	var ExitScript = load("res://scripts/world/campaign_exit_interact.gd")
	var interact: Area3D = ExitScript.new()
	interact.name = "MirrorInteract"
	interact.collision_layer = 8
	interact.collision_mask = 0
	interact.monitoring = false
	interact.monitorable = true
	interact.add_to_group("interactable")
	interact.prompt_text = LocalizationScript.text("Rotate the mirror")
	interact.world_callback = func(_a: Node, _p: Node) -> void:
		if bool(state["opened"]):
			return
		state["beam_on"] = not bool(state["beam_on"])
		if bool(state["beam_on"]):
			beam.monitoring = true
			beam.collision_mask = 2
			_notify(LocalizationScript.text("A LIGHT CUTS ACROSS THE HALL"), 1.4)
			_play("rest", -6.0, 1.2)
		else:
			beam.monitoring = false
			beam.collision_mask = 0
			state["charging"] = false
			state["accum"] = 0.0
			_notify(LocalizationScript.text("THE MIRROR TURNS DARK"), 1.0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.6, 1.6, 1.6)
	shape.shape = box
	shape.position.y = 1.1
	interact.add_child(shape)
	module.add_child(interact)
	_wired.append(interact)
	beam.body_entered.connect(func(body: Node3D) -> void:
		if body != _player or not bool(state["beam_on"]) or bool(state["opened"]):
			return
		state["charging"] = true
	)
	beam.body_exited.connect(func(body: Node3D) -> void:
		if body == _player:
			state["charging"] = false
			state["accum"] = 0.0
	)
	var charge_tween := create_tween().set_loops().bind_node(gate)
	charge_tween.tween_interval(0.2)
	charge_tween.tween_callback(func() -> void:
		if bool(state["opened"]):
			return
		if not bool(state["charging"]) or not beam.get_overlapping_bodies().has(_player):
			state["accum"] = 0.0
			return
		state["accum"] = float(state["accum"]) + 0.2
		if float(state["accum"]) >= charge_seconds:
			state["opened"] = true
			_open_barrier(gate)
			_notify(LocalizationScript.text("THE LIGHT RECEIVES THE BEAM"), 1.8)
			_play("rest", -5.0, 1.1)
	)


func _wire_valve_shutoff(module: Node3D) -> void:
	# 阀门谜题：转动阀门关闭本模块的毒雾/危险区
	var valve := module.get_node_or_null("ValveBody") as StaticBody3D
	var zone := module.get_node_or_null("ValveHazardZone") as Area3D
	if valve == null or zone == null:
		return
	zone.monitoring = true
	zone.collision_mask = 2
	zone.set_meta("hazard_dps", float(module.get_meta("damage_per_second", 8.0)))
	zone.set_meta("hazard_active", true)
	_wired.append(zone)
	var shut := {"off": false}
	var ExitScript = load("res://scripts/world/campaign_exit_interact.gd")
	var interact: Area3D = ExitScript.new()
	interact.name = "ValveInteract"
	interact.collision_layer = 8
	interact.collision_mask = 0
	interact.monitoring = false
	interact.monitorable = true
	interact.add_to_group("interactable")
	interact.prompt_text = LocalizationScript.text("Turn the valve")
	interact.world_callback = func(_a: Node, _p: Node) -> void:
		if bool(shut["off"]):
			return
		shut["off"] = true
		zone.monitoring = false
		zone.collision_mask = 0
		zone.set_meta("hazard_active", false)
		_set_area_visible(zone, false)
		_notify(LocalizationScript.text("THE VAPOR SEALS"), 1.8)
		_play("rest", -5.0, 1.1)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.4, 1.6, 1.4)
	shape.shape = box
	shape.position.y = 1.0
	interact.add_child(shape)
	module.add_child(interact)
	_wired.append(interact)


func _wire_celestial_dial(module: Node3D) -> void:
	# 天仪谜题：转动天仪至星位对齐，解开对应星门
	var dial := module.get_node_or_null("DialBody") as StaticBody3D
	var gate := module.get_node_or_null("CelestialGate") as StaticBody3D
	if dial == null:
		return
	var required := maxi(int(module.get_meta("required_turns", 3)), 1)
	var state := {"turns": 0}
	var ExitScript = load("res://scripts/world/campaign_exit_interact.gd")
	var interact: Area3D = ExitScript.new()
	interact.name = "DialInteract"
	interact.collision_layer = 8
	interact.collision_mask = 0
	interact.monitoring = false
	interact.monitorable = true
	interact.add_to_group("interactable")
	interact.prompt_text = LocalizationScript.text("Turn the celestial dial")
	interact.world_callback = func(_a: Node, _p: Node) -> void:
		state["turns"] = int(state["turns"]) + 1
		if int(state["turns"]) < required:
			_notify(LocalizationScript.text("THE DIAL ALIGNS  %d / %d") % [int(state["turns"]), required], 1.2)
			_play("rest", -7.0, 1.2)
			return
		if gate != null and is_instance_valid(gate):
			_set_static_colliders_enabled(gate, false)
			gate.visible = false
		_notify(LocalizationScript.text("THE CELESTIAL GATE OPENS"), 1.8)
		_play("rest", -5.0, 1.1)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.2, 1.6, 2.2)
	shape.shape = box
	shape.position.y = 1.1
	interact.add_child(shape)
	module.add_child(interact)
	_wired.append(interact)


func _wire_alchemy_ingredients(module: Node3D) -> void:
	# 炼丹配料谜题：交互炉台投入配料，集齐后丹炉开启
	var station := module.get_node_or_null("IngredientStation") as StaticBody3D
	var gate := module.get_node_or_null("AlchemyGate") as StaticBody3D
	if station == null:
		return
	var required := maxi(int(module.get_meta("required_count", 3)), 1)
	var state := {"count": 0}
	var ExitScript = load("res://scripts/world/campaign_exit_interact.gd")
	var interact: Area3D = ExitScript.new()
	interact.name = "IngredientInteract"
	interact.collision_layer = 8
	interact.collision_mask = 0
	interact.monitoring = false
	interact.monitorable = true
	interact.add_to_group("interactable")
	interact.prompt_text = LocalizationScript.text("Add an ingredient")
	interact.world_callback = func(_a: Node, _p: Node) -> void:
		state["count"] = int(state["count"]) + 1
		if int(state["count"]) < required:
			_notify(LocalizationScript.text("INGREDIENTS  %d / %d") % [int(state["count"]), required], 1.2)
			_play("rest", -7.0, 1.3)
			return
		if gate != null and is_instance_valid(gate):
			_set_static_colliders_enabled(gate, false)
			gate.visible = false
		_notify(LocalizationScript.text("THE ELIXIR BREWS"), 1.8)
		_play("rest", -5.0, 1.1)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.8, 1.8, 1.8)
	shape.shape = box
	shape.position.y = 1.0
	interact.add_child(shape)
	module.add_child(interact)
	_wired.append(interact)


func _wire_gravity_anchor(module: Node3D) -> void:
	# 重力锚谜题：激活锚点使目标区域的重力倒置生效/失效（L-16）
	var anchor := module.get_node_or_null("AnchorBody") as StaticBody3D
	var target := module.get_node_or_null("AnchorTarget") as Area3D
	if anchor == null or target == null:
		return
	target.monitoring = true
	target.collision_mask = 2
	target.set_meta("gravity_active", true)
	var active := {"state": true}
	var ExitScript = load("res://scripts/world/campaign_exit_interact.gd")
	var interact: Area3D = ExitScript.new()
	interact.name = "AnchorInteract"
	interact.collision_layer = 8
	interact.collision_mask = 0
	interact.monitoring = false
	interact.monitorable = true
	interact.add_to_group("interactable")
	interact.prompt_text = LocalizationScript.text("Deactivate the gravity anchor")
	interact.world_callback = func(_a: Node, _p: Node) -> void:
		active["state"] = not bool(active["state"])
		target.set_meta("gravity_active", bool(active["state"]))
		if bool(active["state"]):
			target.monitoring = true
			target.collision_mask = 2
			interact.prompt_text = LocalizationScript.text("Deactivate the gravity anchor")
			_notify(LocalizationScript.text("THE ANCHOR HOLDS THE SKY"), 1.6)
			_play("rest", -6.0, 1.2)
		else:
			target.monitoring = false
			target.collision_mask = 0
			if _player != null and target.get_overlapping_bodies().has(_player):
				_set_gravity_inverted(_player as CharacterBody3D, false, module)
			interact.prompt_text = LocalizationScript.text("Activate the gravity anchor")
			_notify(LocalizationScript.text("GRAVITY RETURNS"), 1.4)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.6, 1.8, 1.6)
	shape.shape = box
	shape.position.y = 1.0
	interact.add_child(shape)
	module.add_child(interact)
	_wired.append(interact)
	target.body_entered.connect(func(body: Node3D) -> void:
		if body != _player:
			return
		if bool(target.get_meta("gravity_active", true)):
			_set_gravity_inverted(body as CharacterBody3D, true, module)
			_notify(LocalizationScript.text("GRAVITY INVERTED"), 1.2)
			_play("rest", -7.0, 0.9)
	)
	target.body_exited.connect(func(body: Node3D) -> void:
		if body == _player:
			_set_gravity_inverted(body as CharacterBody3D, false, module)
	)


func _wire_riddle_gate(module: Node3D) -> void:
	# 九尾谜语之门：向答题石交互，答对开启（答案存于 config）
	var gate := module.get_node_or_null("RiddleGate") as StaticBody3D
	if gate == null:
		return
	var correct := int(module.get_meta("correct_index", 0))
	var opened := {"done": false}
	var ExitScript = load("res://scripts/world/campaign_exit_interact.gd")
	for child in module.get_children():
		if not child is Marker3D or not String(child.name).begins_with("Answer"):
			continue
		var answer_index := int(child.get_meta("answer_index", -1))
		var answer_text := String(child.get_meta("answer_text", "?"))
		var interact: Area3D = ExitScript.new()
		interact.name = "AnswerInteract%d" % answer_index
		interact.collision_layer = 8
		interact.collision_mask = 0
		interact.monitoring = false
		interact.monitorable = true
		interact.add_to_group("interactable")
		interact.position = child.position
		interact.prompt_text = answer_text
		interact.world_callback = func(_a: Node, _p: Node) -> void:
			if bool(opened["done"]):
				return
			if answer_index == correct:
				opened["done"] = true
				_set_static_colliders_enabled(gate, false)
				gate.visible = false
				_notify(LocalizationScript.text("THE NINE-TAILS ACCEPTS YOUR ANSWER"), 1.8)
				_play("rest", -5.0, 1.1)
			else:
				if _player != null and _player.has_method("receive_hit"):
					_player.receive_hit(8.0, 0.25, Vector3.ZERO, interact)
				_notify(LocalizationScript.text("THE RIDDLE REJECTS YOU"), 1.4)
				_play("hit", -10.0, 1.5)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.6, 1.6, 1.6)
		shape.shape = box
		shape.position.y = 1.0
		interact.add_child(shape)
		module.add_child(interact)
		_wired.append(interact)


func _wire_stealth_passage(module: Node3D) -> void:
	# 潜行通道：进入警报区被察觉；未被察觉抵达出口则开启通道
	var alarm := module.get_node_or_null("AlarmZone") as Area3D
	var gate := module.get_node_or_null("StealthGate") as StaticBody3D
	var exit_marker := module.get_node_or_null("StealthExit") as Marker3D
	if alarm == null or gate == null:
		return
	var alarm_damage := float(module.get_meta("alarm_damage", 10.0))
	var seen := {"state": false, "opened": false}
	alarm.monitoring = true
	alarm.collision_mask = 2
	alarm.body_entered.connect(func(body: Node3D) -> void:
		if body != _player or bool(seen["opened"]):
			return
		seen["state"] = true
		if _player != null and _player.has_method("receive_hit"):
			_player.receive_hit(alarm_damage, 0.2, Vector3.ZERO, alarm)
		_notify(LocalizationScript.text("YOU HAVE BEEN SEEN"), 1.4)
		_play("hit", -10.0, 1.6)
	)
	alarm.body_exited.connect(func(body: Node3D) -> void:
		if body == _player and not bool(seen["opened"]):
			seen["state"] = false
	)
	var exit_area := Area3D.new()
	exit_area.name = "StealthExitCheck"
	exit_area.monitoring = true
	exit_area.collision_mask = 2
	var exit_shape := CollisionShape3D.new()
	var exit_box := BoxShape3D.new()
	exit_box.size = Vector3(2.5, 2.5, 2.5)
	exit_shape.shape = exit_box
	exit_area.add_child(exit_shape)
	exit_area.position = exit_marker.position if exit_marker != null else Vector3(0.0, 0.0, -5.0)
	module.add_child(exit_area)
	_wired.append(exit_area)
	exit_area.body_entered.connect(func(body: Node3D) -> void:
		if body != _player or bool(seen["opened"]):
			return
		if bool(seen["state"]):
			_notify(LocalizationScript.text("THE SENTRY WATCHES YOU"), 1.4)
			_play("rest", -8.0, 1.2)
			return
		seen["opened"] = true
		_set_static_colliders_enabled(gate, false)
		gate.visible = false
		_notify(LocalizationScript.text("THE PATH REMAINS HIDDEN"), 1.8)
		_play("rest", -5.0, 1.1)
	)


func _wire_memory_verification(module: Node3D) -> void:
	# 记忆验证：选择 真/假 印记，答对开启
	var gate := module.get_node_or_null("VerificationGate") as StaticBody3D
	if gate == null:
		return
	var correct := String(module.get_meta("correct_choice", "true"))
	var opened := {"done": false}
	var ExitScript = load("res://scripts/world/campaign_exit_interact.gd")
	var choices: Array = [
		{"node": module.get_node_or_null("TrueMarker"), "label": "true"},
		{"node": module.get_node_or_null("FalseMarker"), "label": "false"},
	]
	for choice in choices:
		var marker := choice["node"] as Marker3D
		if marker == null:
			continue
		var label := String(choice["label"])
		var interact: Area3D = ExitScript.new()
		interact.name = "MemoryInteract%s" % label.capitalize()
		interact.collision_layer = 8
		interact.collision_mask = 0
		interact.monitoring = false
		interact.monitorable = true
		interact.add_to_group("interactable")
		interact.position = marker.position
		interact.prompt_text = LocalizationScript.text("Affirm this memory (%s)") % label
		interact.world_callback = func(_a: Node, _p: Node) -> void:
			if bool(opened["done"]):
				return
			if label == correct:
				opened["done"] = true
				_set_static_colliders_enabled(gate, false)
				gate.visible = false
				_notify(LocalizationScript.text("THE MEMORY HOLDS TRUE"), 1.8)
				_play("rest", -5.0, 1.1)
			else:
				if _player != null and _player.has_method("receive_hit"):
					_player.receive_hit(6.0, 0.2, Vector3.ZERO, interact)
				_notify(LocalizationScript.text("THE MEMORY REJECTS YOU"), 1.4)
				_play("hit", -10.0, 1.5)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.6, 1.6, 1.6)
		shape.shape = box
		shape.position.y = 1.0
		interact.add_child(shape)
		module.add_child(interact)
		_wired.append(interact)


func _wire_soul_forger_trial(module: Node3D) -> void:
	# 铸魂试炼：入场封场，试炼区域内承受压力，撑过时长后开封印
	var trigger := module.get_node_or_null("TrialTrigger") as Area3D
	var seal := module.get_node_or_null("TrialSeal") as StaticBody3D
	var aura := module.get_node_or_null("TrialAura") as Area3D
	if trigger == null or aura == null:
		return
	var duration := maxf(float(module.get_meta("trial_duration", 12.0)), 2.0)
	var dps := float(module.get_meta("trial_dps", 6.0))
	if seal != null:
		_set_static_colliders_enabled(seal, false)
		seal.visible = false
	var state := {"active": false}
	trigger.monitoring = true
	trigger.collision_mask = 2
	trigger.body_entered.connect(func(body: Node3D) -> void:
		if body != _player or bool(state["active"]):
			return
		state["active"] = true
		if seal != null and is_instance_valid(seal):
			_set_static_colliders_enabled(seal, true)
			seal.visible = true
		aura.monitoring = true
		aura.collision_mask = 2
		aura.set_meta("hazard_dps", dps)
		aura.set_meta("hazard_active", true)
		if aura not in _wired:
			_wired.append(aura)
		_notify(LocalizationScript.text("THE TRIAL BEGINS"), 1.4)
		_play("rest", -6.0, 1.2)
		var timer := get_tree().create_timer(duration)
		timer.timeout.connect(func() -> void:
			if not is_instance_valid(module):
				return
			state["active"] = false
			aura.set_meta("hazard_active", false)
			aura.monitoring = false
			if seal != null and is_instance_valid(seal):
				_set_static_colliders_enabled(seal, false)
				seal.visible = false
			_notify(LocalizationScript.text("THE SOUL-FORGERS ACCEPT YOU"), 1.8)
			_play("rest", -4.0, 1.2)
		)
	)


func _make_gate_barrier(module: Node3D, barrier_name: String, marker: Marker3D, size: Vector3) -> StaticBody3D:
	# 在指定标记处生成封闭门体（默认封死，解开时禁用碰撞并隐藏）
	var barrier := StaticBody3D.new()
	barrier.name = barrier_name
	barrier.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = marker.position if marker != null else Vector3(0.0, 1.5, 4.0)
	barrier.add_child(shape)
	module.add_child(barrier)
	_wired.append(barrier)
	return barrier


func _open_barrier(barrier: StaticBody3D) -> void:
	if not is_instance_valid(barrier):
		return
	_set_static_colliders_enabled(barrier, false)
	barrier.visible = false


func _set_area_visible(area: Area3D, visible_value: bool) -> void:
	for child in area.get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).disabled = not visible_value
		elif child is MeshInstance3D:
			(child as MeshInstance3D).visible = visible_value


func _wire_shortcut_fold(level_root: Node3D) -> void:
	# H-05：接线单向门远端激活 + 升降梯回祠堂
	var fold := level_root.get_node_or_null("ShortcutFold") as Node3D
	if fold == null:
		return
	var one_way := fold.get_node_or_null("OneWayDoor") as Node3D
	if one_way != null:
		_wire_one_way_door(fold, one_way)
	var elevator := fold.get_node_or_null("ElevatorLift") as Node3D
	if elevator != null:
		_wire_elevator(fold, elevator)
	# 读档恢复已开启折叠
	_restore_shortcut_folds(fold)


func _wire_one_way_door(fold: Node3D, door_root: Node3D) -> void:
	# 远端激活后升起门体，形成回祠堂捷径
	var far := door_root.get_node_or_null("FarSideMarker") as Marker3D
	var door := door_root.get_node_or_null("DoorBody") as StaticBody3D
	if far == null or door == null:
		return
	var ExitScript = load("res://scripts/world/campaign_exit_interact.gd")
	var interact: Area3D = ExitScript.new()
	interact.name = "OneWayFarInteract"
	interact.collision_layer = 8
	interact.collision_mask = 0
	interact.monitoring = false
	interact.monitorable = true
	interact.add_to_group("interactable")
	interact.prompt_text = LocalizationScript.text("Open one-way shortcut")
	interact.position = far.position
	var shortcut_id := String(fold.get_meta("one_way_id", "one_way_door"))
	interact.world_callback = func(_a: Node, _p: Node) -> void:
		if bool(door_root.get_meta("is_open", false)):
			return
		_open_one_way_door(door_root, door)
		_persist_shortcut(shortcut_id)
		_notify(LocalizationScript.text("ONE-WAY PATH OPENS TO THE SHRINE"), 2.0)
		_play("rest", -6.0, 0.8)
		shortcut_fold_opened.emit(shortcut_id)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.4, 2.4, 2.4)
	shape.shape = box
	shape.position.y = 1.0
	interact.add_child(shape)
	door_root.add_child(interact)
	_wired.append(interact)


func _open_one_way_door(door_root: Node3D, door: StaticBody3D) -> void:
	door_root.set_meta("is_open", true)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(door, "position:y", door.position.y + 3.8, 1.15)
	tween.tween_callback(func() -> void:
		_set_static_colliders_enabled(door, false)
	)


func _wire_elevator(fold: Node3D, elevator: Node3D) -> void:
	# 激活后平台可往返；交互可立刻送回 Ember Shrine 停靠点
	var tip := elevator.get_node_or_null("ActivateMarker") as Marker3D
	var platform := elevator.get_node_or_null("LiftPlatform") as AnimatableBody3D
	var dock := elevator.get_node_or_null("ShrineDock") as Marker3D
	if tip == null or platform == null:
		return
	var ExitScript = load("res://scripts/world/campaign_exit_interact.gd")
	var interact: Area3D = ExitScript.new()
	interact.name = "ElevatorActivateInteract"
	interact.collision_layer = 8
	interact.collision_mask = 0
	interact.monitoring = false
	interact.monitorable = true
	interact.add_to_group("interactable")
	interact.prompt_text = LocalizationScript.text("Activate shrine elevator")
	interact.position = tip.position
	var shortcut_id := String(fold.get_meta("elevator_id", "elevator"))
	interact.world_callback = func(_a: Node, _p: Node) -> void:
		var already := bool(elevator.get_meta("is_active", false))
		if not already:
			elevator.set_meta("is_active", true)
			_persist_shortcut(shortcut_id)
			_notify(LocalizationScript.text("ELEVATOR LINKS TO EMBER SHRINE"), 2.0)
			_play("rest", -5.5, 0.9)
			shortcut_fold_opened.emit(shortcut_id)
			interact.prompt_text = LocalizationScript.text("Ride to Ember Shrine")
			# 首次激活：平台驶向祠堂停靠
			_ride_elevator_to_shrine(elevator, platform, dock)
			return
		_ride_elevator_to_shrine(elevator, platform, dock)
		_return_player_to_shrine()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.6, 2.4, 2.6)
	shape.shape = box
	shape.position.y = 1.0
	interact.add_child(shape)
	elevator.add_child(interact)
	_wired.append(interact)


func _ride_elevator_to_shrine(elevator: Node3D, platform: AnimatableBody3D, dock: Marker3D) -> void:
	# 平台 tween 到祠堂停靠局部坐标
	var target := dock.position if dock != null else Vector3(elevator.get_meta("shrine_dock_local", Vector3(-4.0, 0.0, 0.0)))
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(platform, "position", target, 1.6)


func _return_player_to_shrine() -> void:
	# 将玩家放到关卡 Checkpoint / Spawn 标记（Ember Shrine 空间折叠）
	if _player == null or _level_root == null:
		return
	var marker := _level_root.get_node_or_null("Markers/Checkpoint") as Marker3D
	if marker == null:
		marker = _level_root.get_node_or_null("Markers/Spawn") as Marker3D
	if marker == null:
		return
	_player.global_position = marker.global_position + Vector3(0.0, 1.1, 2.0)
	if _player is CharacterBody3D:
		(_player as CharacterBody3D).velocity = Vector3.ZERO
	_notify(LocalizationScript.text("RETURNED TO EMBER SHRINE"), 1.6)
	_play("rest", -4.0, 1.0)


func _restore_shortcut_folds(fold: Node3D) -> void:
	# 根据 run_state 已激活列表恢复门/梯状态
	var activated := _read_activated_shortcuts()
	var one_way_id := String(fold.get_meta("one_way_id", ""))
	var elevator_id := String(fold.get_meta("elevator_id", ""))
	var door_root := fold.get_node_or_null("OneWayDoor") as Node3D
	if door_root != null and one_way_id in activated:
		var door := door_root.get_node_or_null("DoorBody") as StaticBody3D
		if door != null:
			door.position.y += 3.8
			_set_static_colliders_enabled(door, false)
			door_root.set_meta("is_open", true)
	var elevator := fold.get_node_or_null("ElevatorLift") as Node3D
	if elevator != null and elevator_id in activated:
		elevator.set_meta("is_active", true)
		var platform := elevator.get_node_or_null("LiftPlatform") as AnimatableBody3D
		var dock := elevator.get_node_or_null("ShrineDock") as Marker3D
		if platform != null and dock != null:
			platform.position = dock.position
		var interact := elevator.get_node_or_null("ElevatorActivateInteract")
		if interact != null and "prompt_text" in interact:
			interact.prompt_text = LocalizationScript.text("Ride to Ember Shrine")


func _read_activated_shortcuts() -> Array:
	var parent := get_parent()
	if parent != null and "run_state" in parent:
		var state = parent.get("run_state")
		if state != null and "activated_shortcuts" in state:
			return state.activated_shortcuts
	return []


func _persist_shortcut(shortcut_id: String) -> void:
	# 写入世界 run_state；兼容旧 ancient_gate 列表
	if shortcut_id.is_empty():
		return
	var parent := get_parent()
	if parent == null or not ("run_state" in parent):
		return
	var state = parent.get("run_state")
	if state == null or not ("activated_shortcuts" in state):
		return
	if shortcut_id not in state.activated_shortcuts:
		state.activated_shortcuts.append(shortcut_id)
	if parent.has_method("_save_run"):
		parent.call("_save_run", "shortcut_fold_activated")


func release_arena_seals() -> void:
	# Boss 胜后降下所有封场墙
	if _level_root == null:
		return
	var modules := _level_root.get_node_or_null("Modules")
	if modules == null:
		return
	for module in modules.get_children():
		if StringName(module.get_meta("module_id", &"")) != &"arena_seal":
			continue
		var seal := module.get_node_or_null("ArenaSeal") as StaticBody3D
		if seal == null:
			continue
		_set_static_colliders_enabled(seal, false)
		seal.visible = false
		seal.set_meta("arena_sealed", false)
	_notify(LocalizationScript.text("THE SEAL BREAKS"), 1.4)


func spawn_victory_exit(level_root: Node3D) -> void:
	# Boss 关无 gate_exit 时生成通往下一关的出口交互
	if level_root == null:
		return
	if level_root.find_child("GateExitInteract", true, false) != null:
		return
	if level_root.find_child("VictoryExitInteract", true, false) != null:
		return
	var ExitScript = load("res://scripts/world/campaign_exit_interact.gd")
	var interact: Area3D = ExitScript.new()
	interact.name = "VictoryExitInteract"
	interact.collision_layer = 8
	interact.collision_mask = 0
	interact.monitoring = false
	interact.monitorable = true
	interact.add_to_group("interactable")
	interact.set_meta("campaign_exit", true)
	interact.prompt_text = LocalizationScript.text("Advance to the next ruin")
	interact.world_callback = Callable(self, "_on_exit_interact")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.2, 3.0, 2.4)
	shape.shape = box
	shape.position = Vector3(0.0, 1.2, -22.0)
	interact.add_child(shape)
	level_root.add_child(interact)
	_wired.append(interact)


func _set_static_colliders_enabled(body: StaticBody3D, enabled: bool) -> void:
	for child in body.get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).disabled = not enabled


func tick_hazards(delta: float) -> void:
	# 对仍激活的伤害区结算
	if _player == null or not is_instance_valid(_player):
		return
	if not _player.has_method("receive_hit"):
		return
	for node in _wired:
		if not is_instance_valid(node) or not node is Area3D:
			continue
		var area := node as Area3D
		if not bool(area.get_meta("hazard_active", false)):
			continue
		if not area.get_overlapping_bodies().has(_player):
			continue
		var dps := float(area.get_meta("hazard_dps", 8.0))
		_player.receive_hit(dps * delta, 0.0, Vector3.ZERO, area)


func _tick_projectile_lanes(delta: float) -> void:
	# 弹道廊脉冲伤害
	if _player == null or not is_instance_valid(_player):
		return
	if not _player.has_method("receive_hit"):
		return
	for lane in _projectile_lanes:
		var area: Area3D = lane.get("area")
		if area == null or not is_instance_valid(area):
			continue
		lane["accum"] = float(lane["accum"]) + delta
		if float(lane["accum"]) < float(lane["interval"]):
			continue
		lane["accum"] = 0.0
		if not area.get_overlapping_bodies().has(_player):
			continue
		_player.receive_hit(float(lane["damage"]), 0.15, Vector3.ZERO, area)
		_play("hit", -10.0, 1.4)


func _tick_moving_platforms(delta: float) -> void:
	# 平台正弦往返
	for entry in _moving_platforms:
		var platform: AnimatableBody3D = entry.get("platform")
		if platform == null or not is_instance_valid(platform):
			continue
		entry["elapsed"] = float(entry["elapsed"]) + delta
		var t := float(entry["elapsed"]) / float(entry["duration"])
		var wave := (sin(t * TAU - PI * 0.5) + 1.0) * 0.5
		var origin: Vector3 = entry["origin"]
		var travel: Vector3 = entry["travel"]
		platform.position = origin + travel * wave


func _notify(message: String, duration: float) -> void:
	if _hud != null and _hud.has_method("show_message"):
		_hud.show_message(message, duration)


func _play(cue: String, volume_db: float, pitch: float) -> void:
	if _audio != null and is_instance_valid(_audio) and _audio.has_method("play_cue"):
		_audio.call("play_cue", cue, volume_db, pitch)
