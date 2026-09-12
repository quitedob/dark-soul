extends Node
## P0-2 / 九尾「记忆凝视」打断剧情（玉面狐·九尾专属流程）。
##
## 触发：Boss 血量首次降到 <50%（_process 轮询 flow_boss.get_health_ratio()，
##       _gaze_triggered 标志防止重复触发）。
## 效果（可真实可感但不破坏战斗）：
##   1. set_visual_frozen 短暂冻结 Boss 行为（保留重力/滑行与既有状态，敌我时序不中断），
##      同时结束进行中的攻击挥击（避免冻结期间残留活性受击盒）；
##   2. 视觉打断：visual_root 缩放脉冲 + 身体/武器材质玉色冷光闪 + 镜头创伤（屏震）
##      + HUD 标题卡；
##   3. 本地时间膨胀 meta：set_meta("time_dilation") 只影响本流程 tween 时长，
##      禁改 Engine.time_scale；
##   4. run_state.set_choice_flag 记录命运旗标 ch3_memory_gaze_seen。
## 记忆凝视不跳过阶段（不强制推进 phase）：符合设计，战斗在 Phase 2 继续至正常 30%
## Phase 3 阈值。战斗重置（死亡/休息整场回满）后允许再次触发。
##
## 契约见 res://scripts/boss/boss_flow_controller.gd 文件头：声明 flow_boss / flow_config，
## 可选 _on_phase / _on_story_threshold（宿主按 has_method 自动连接）。缺失任何前提
## （flow_boss 为 null / 无效等）时安全空转，不影响正常 Boss 战。

var flow_boss: Node
var flow_config: Dictionary = {}

const DEFAULT_THRESHOLD := 0.5
const DEFAULT_FREEZE_SECONDS := 1.6
const FLAG_MEMORY_GAZE_SEEN := "ch3_memory_gaze_seen"

## 记忆凝视已触发标志（防止重复）
var _gaze_triggered := false
## 凝视打断进行中（冻结 + VFX 恢复待处理）
var _gaze_active := false
var _gaze_remaining := 0.0
var _last_phase := 1
## 材质原态缓存（body/weapon 发光，凝视结束后恢复）
var _stored_materials: Dictionary = {}
var _encounter: Node


func _process(delta: float) -> void:
	_poll_memory_gaze()
	if _gaze_active:
		_gaze_remaining -= delta
		if _gaze_remaining <= 0.0:
			_end_gaze()


## 可选契约钩子：宿主在挂载时按 has_method 连接 boss.phase_changed → 本方法。
func _on_phase(new_phase: int) -> void:
	_last_phase = int(new_phase)


## 可选契约钩子：宿主按 has_method 连接 boss.story_threshold_reached → 本方法。
## 记忆凝视走血量轮询（50% 并非剧情阈值事件），此处保留签名作为契约占位，无副作用。
func _on_story_threshold(_story_flag: String, _health_ratio: float) -> void:
	pass


## 轮询血量，首次低于阈值触发凝视；战斗重置（血量回满）后允许再次触发。
func _poll_memory_gaze() -> void:
	if flow_boss == null or not is_instance_valid(flow_boss):
		return
	if not flow_boss.has_method("get_health_ratio"):
		return
	if is_instance_valid(_encounter) and not _encounter.combat_is_active():
		return
	var threshold := float(flow_config.get("memory_gaze_threshold", DEFAULT_THRESHOLD))
	var ratio: float = flow_boss.get_health_ratio()
	# 重置（死亡/休息整场回满）后解除触发标志，下次降到阈值重新触发
	if _gaze_triggered and ratio > 0.95:
		_gaze_triggered = false
		return
	if _gaze_triggered:
		return
	if ratio <= threshold:
		_gaze_triggered = true
		_trigger_memory_gaze()


func _trigger_memory_gaze() -> void:
	if flow_boss == null or not is_instance_valid(flow_boss):
		return
	_gaze_active = true
	_gaze_remaining = maxf(float(flow_config.get("freeze_seconds", DEFAULT_FREEZE_SECONDS)), 0.1)
	# 结束进行中的攻击挥击，避免冻结期间残留活性受击盒（Boss 被 50% 那一下命中通常已 STAGGER）
	var combat_area: Variant = flow_boss.get("combat_area")
	if combat_area is Object and combat_area != null and combat_area.has_method("end_swing"):
		combat_area.end_swing()
	_record_flag()
	_play_interrupt_visuals()
	if flow_boss.has_method("set_visual_frozen"):
		flow_boss.set_visual_frozen(true)
	var arena = flow_boss.get_meta("boss_arena_director", null)
	if is_instance_valid(arena) and is_instance_valid(arena.story_props):
		arena.story_props.begin_memory_gaze()


func _end_gaze() -> void:
	if flow_boss != null and is_instance_valid(flow_boss) and flow_boss.has_method("set_visual_frozen"):
		flow_boss.set_visual_frozen(false)
	_restore_emission()
	_gaze_active = false
	_gaze_remaining = 0.0
	if is_instance_valid(flow_boss):
		var arena = flow_boss.get_meta("boss_arena_director", null)
		if is_instance_valid(arena) and is_instance_valid(arena.story_props):
			arena.story_props.end_memory_gaze()


func bind_encounter(boundary: Node) -> void:
	_encounter = boundary


func _on_encounter_reset() -> void:
	_end_gaze()
	_gaze_triggered = false
	_last_phase = 1


func _on_encounter_resolved() -> void:
	_end_gaze()


## 通过 run_state.set_choice_flag 记录命运旗标（ch3_memory_gaze_seen）。
func _record_flag() -> void:
	var world := _world()
	if world == null:
		return
	var state: Variant = world.get("run_state")
	if state is Object and state != null and state.has_method("set_choice_flag"):
		state.set_choice_flag(FLAG_MEMORY_GAZE_SEEN, true)


## 视觉打断：缩放脉冲 + 玉色冷光闪 + 屏震 + HUD 标题卡 + 本地时间膨胀 meta。
func _play_interrupt_visuals() -> void:
	if flow_boss == null or not is_instance_valid(flow_boss):
		return
	var dilation := clampf(float(flow_config.get("time_dilation", 0.6)), 0.3, 1.0)
	# 本地 meta：观察用时间膨胀值（仅影响本流程 tween 时长；禁改 Engine.time_scale）
	set_meta("time_dilation", dilation)
	_pulse_visual_scale(dilation)
	_flash_emission()
	_inject_screen_shake(0.45)
	_show_message("MEMORY GAZE  ·  记忆凝视")


func _pulse_visual_scale(dilation: float) -> void:
	var visual: Variant = flow_boss.get("visual_root")
	if not visual is Node3D:
		return
	var base: Vector3 = visual.scale
	if base.length_squared() < 0.01:
		base = Vector3.ONE * (1.22 if bool(flow_boss.get("guardian")) else 1.0)
	var up_in := 0.22 * dilation
	var settle := 0.5 * dilation
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(visual, "scale", base * 1.1, up_in)
	tw.tween_property(visual, "scale", base, settle)


## 身体/武器材质短促玉色冷光（记忆凝视的视觉信号），原态缓存供 _end_gaze 恢复。
func _flash_emission() -> void:
	_stored_materials.clear()
	for key in ["body_material", "weapon_material"]:
		var mat: Variant = flow_boss.get(key)
		if not mat is StandardMaterial3D:
			continue
		_stored_materials[key] = {
			"enabled": mat.emission_enabled,
			"energy": mat.emission_energy_multiplier,
			"color": mat.emission,
		}
		mat.emission_enabled = true
		mat.emission = Color(0.72, 1.0, 0.96)
		mat.emission_energy_multiplier = 3.2


func _restore_emission() -> void:
	if flow_boss == null or not is_instance_valid(flow_boss):
		return
	for key in _stored_materials:
		var mat: Variant = flow_boss.get(key)
		if not mat is StandardMaterial3D:
			continue
		var record: Dictionary = _stored_materials[key]
		var restore_tw := create_tween()
		restore_tw.tween_property(mat, "emission_energy_multiplier", float(record.get("energy", 0.0)), 0.55)
		restore_tw.tween_property(mat, "emission", record.get("color", Color.WHITE), 0.55)
		restore_tw.tween_property(mat, "emission_enabled", bool(record.get("enabled", false)), 0.0)
	_stored_materials.clear()


func _inject_screen_shake(amount: float) -> void:
	var world := _world()
	if world == null:
		return
	var shake: Variant = world.get("_trauma_shake")
	if shake is Object and shake != null and shake.has_method("inject"):
		shake.inject(amount)


func _show_message(message: String) -> void:
	var world := _world()
	if world == null:
		return
	var hud: Variant = world.get("hud")
	if hud is Object and hud != null and hud.has_method("show_message"):
		hud.show_message(message, 1.8)


## 取所属 Boss 的 world_node（game_world）；无效时返回 null（安全空转）。
func _world() -> Node:
	if flow_boss == null or not is_instance_valid(flow_boss):
		return null
	var world: Variant = flow_boss.get("world_node")
	if world is Node and is_instance_valid(world):
		return world as Node
	return null
