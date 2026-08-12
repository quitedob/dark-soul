extends Node
## P0-2 / 烛阴「零重力」专属流程（烬渊之主·烛阴 Phase 3）。
##
## 触发：Boss 相变进入 P3（chapter_5 boss_zhu_yin.phases["3"].threshold = 0.4）时，把玩家
##       重力置零 —— 太空弹幕浮空。P4（抉择相 / threshold 0.1）、剧情抉择、Boss 死亡、
##       脱战/战斗重置、换关释放时恢复默认重力。战斗外 / 重开不残留零重力。
##
## 实现：
##   1. 复用宿主 BossFlowController 的 phase_changed → _on_phase(new_phase) 桥接；
##   2. 玩家定位：优先 flow_boss.target_node（enemy 对玩家的目标引用），兜底
##      flow_boss.world_node.player（game_world 的玩家引用）；
##   3. 调用 player.set_gravity_override(0.0) / clear_gravity_override()（player.gd 新增
##      重力覆盖 API，默认 -1.0 无副作用）；
##   4. 清理走多重信号 + _process 兜底，保证任何结束路径都不残留：
##        _on_phase(4) / _on_story_threshold / defeated / engagement_changed(false) /
##        boss.tree_exiting / _process 内 boss 失效或未交战时。
##
## 契约见 res://scripts/boss/boss_flow_controller.gd 文件头：声明 flow_boss / flow_config，
## 可选 _on_phase / _on_story_threshold（宿主按 has_method 自动连接）。缺失任何前提
## （flow_boss 为 null / 无效、玩家未找到）时安全空转，不影响正常 Boss 战。

var flow_boss: Node
var flow_config: Dictionary = {}

## 零重力是否已应用到玩家（幂等守卫）
var _zero_g_active := false
## 挂载后是否已完成信号接线（_process 首帧惰性完成，规避 add_child 先于写引用的时序）
var _initialized := false
## 缓存的玩家引用（无效时每次应用前重新定位）
var _player: Node = null


func _process(_delta: float) -> void:
	if not _initialized:
		_initialized = true
		_initialize()
	# 兜底清理：Boss 失效或已脱战（死亡/重置/脱出战斗）时确保不残留零重力
	if _zero_g_active:
		if flow_boss == null or not is_instance_valid(flow_boss) or not bool(flow_boss.get("engaged", false)):
			_clear_zero_g()


## 可选契约钩子：宿主在挂载时按 has_method 连接 boss.phase_changed → 本方法。
func _on_phase(new_phase: int) -> void:
	var zero_g_phase := int(flow_config.get("zero_g_phase", 3))
	if new_phase == 4:
		# P4 抉择相（非战斗）→ 恢复重力
		_clear_zero_g()
	elif new_phase >= zero_g_phase:
		_apply_zero_g()
	else:
		_clear_zero_g()


## 可选契约钩子：宿主按 has_method 连接 boss.story_threshold_reached → 本方法。
## 剧情阈值（命运抉择）触发即视为战斗收尾，恢复重力。
func _on_story_threshold(_story_flag: String, _health_ratio: float) -> void:
	_clear_zero_g()


## 惰性接线：首次 _process 帧执行（此时 flow_boss 已被宿主写入）。Boss 信号随
## Boss 释放自动断开，连接仅在本流程节点存活期间有效。
func _initialize() -> void:
	if flow_boss == null or not is_instance_valid(flow_boss):
		return
	if flow_boss.has_signal("defeated"):
		flow_boss.defeated.connect(_on_boss_defeated)
	if flow_boss.has_signal("engagement_changed"):
		flow_boss.engagement_changed.connect(_on_engagement_changed)
	if flow_boss.has_signal("tree_exiting"):
		flow_boss.tree_exiting.connect(_on_tree_exiting)


## 进入 P3：把玩家重力置零（太空弹幕）。玩家未找到时重试定位，仍找不到安全空转。
func _apply_zero_g() -> void:
	if _zero_g_active:
		return
	_locate_player()
	if _player == null or not is_instance_valid(_player) or not _player.has_method("set_gravity_override"):
		return
	_player.set_gravity_override(0.0)
	_zero_g_active = true


## 恢复默认重力。幂等：未应用时无副作用。
func _clear_zero_g() -> void:
	if not _zero_g_active:
		return
	if _player != null and is_instance_valid(_player) and _player.has_method("clear_gravity_override"):
		_player.clear_gravity_override()
	_zero_g_active = false


func _on_boss_defeated(_enemy: Node, _reward: int, _is_guardian: bool) -> void:
	_clear_zero_g()


## 脱战 / 战斗重置（死亡、休息、脱离仇恨）→ 恢复重力。
func _on_engagement_changed(_enemy: Node, _is_guardian: bool, engaged: bool) -> void:
	if not engaged:
		_clear_zero_g()


## 换关 / Boss 被释放 → 确保玩家不残留零重力。
func _on_tree_exiting() -> void:
	_clear_zero_g()


## 玩家定位：优先 flow_boss.target_node（enemy 对玩家目标引用），兜底 game_world.player。
func _locate_player() -> void:
	if flow_boss == null or not is_instance_valid(flow_boss):
		return
	var target: Variant = flow_boss.get("target_node")
	if target is Node and is_instance_valid(target) and target.has_method("set_gravity_override"):
		_player = target
		return
	var world: Variant = flow_boss.get("world_node")
	if world is Node and is_instance_valid(world):
		var candidate: Variant = world.get("player")
		if candidate is Node and is_instance_valid(candidate) and candidate.has_method("set_gravity_override"):
			_player = candidate
