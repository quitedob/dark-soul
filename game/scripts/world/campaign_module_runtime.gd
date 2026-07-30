class_name CampaignModuleRuntime
extends Node
## 激活关卡模块行为：脆弱地板崩塌、出口门推进、伤害区等

signal exit_requested(level_id: StringName)
signal fragile_collapsed(module: Node3D)

const LocalizationScript = preload("res://scripts/core/localization.gd")

var _player: Node3D
var _hud: Node
var _audio: Node
var _level_root: Node3D
var _wired: Array[Node] = []
var _exit_cooldown := 0.0


func bind(player: Node3D, hud: Node, audio: Node) -> void:
	# 绑定世界侧依赖
	_player = player
	_hud = hud
	_audio = audio


func activate(level_root: Node3D) -> void:
	# 清理旧连线后扫描当前关卡模块
	clear()
	_level_root = level_root
	if level_root == null:
		return
	var modules := level_root.get_node_or_null("Modules")
	if modules == null:
		return
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


func clear() -> void:
	# 断开并释放运行时挂件
	for node in _wired:
		if is_instance_valid(node):
			node.queue_free()
	_wired.clear()
	_level_root = null


func _process(delta: float) -> void:
	if _exit_cooldown > 0.0:
		_exit_cooldown = maxf(_exit_cooldown - delta, 0.0)


func _wire_fragile_floor(module: Node3D) -> void:
	# 在静态地板上叠加触发区，踩踏后延迟崩塌
	var floor_body := module.get_node_or_null("FragileFloor") as StaticBody3D
	if floor_body == null:
		return
	var trigger := Area3D.new()
	trigger.name = "FragileTrigger"
	trigger.collision_layer = 0
	trigger.collision_mask = 2  # 玩家层（CharacterBody 默认 layer 2 在本项目可能不同）
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
	interact.collision_layer = 8  # INTERACTABLE_LAYER
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
	var tick := {"accum": 0.0}
	area.body_entered.connect(func(body: Node3D) -> void:
		if body == _player:
			tick["accum"] = 0.0
	)
	area.body_exited.connect(func(body: Node3D) -> void:
		if body == _player:
			tick["accum"] = -1.0
	)
	# 轻量每帧检测由 process 代理：把区域登记为 meta
	area.set_meta("hazard_dps", dps)
	area.set_meta("hazard_active", true)
	_wired.append(area)


func _wire_arena_seal(module: Node3D) -> void:
	# Boss 场触发仅打标记，具体封印留待 Boss 切片
	var trigger := module.get_node_or_null("ArenaTrigger") as Area3D
	if trigger == null:
		return
	trigger.monitoring = true
	trigger.collision_mask = 2
	trigger.body_entered.connect(func(body: Node3D) -> void:
		if body == _player:
			_notify(LocalizationScript.text("THE SEAL STIRS"), 1.5)
	)


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


func _notify(message: String, duration: float) -> void:
	if _hud != null and _hud.has_method("show_message"):
		_hud.show_message(message, duration)


func _play(cue: String, volume_db: float, pitch: float) -> void:
	if _audio != null and is_instance_valid(_audio) and _audio.has_method("play_cue"):
		_audio.call("play_cue", cue, volume_db, pitch)
