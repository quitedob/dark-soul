extends Node
## P0-2 / 玄霄 90s 逃出 —— 堕仙·玄霄（boss_xuan_xiao / arena collapsing_zenith）
##
## 专属流程：战斗挂载（_ready）即启动 90s 逃出倒计时。
##   倒计时内击杀（正常 _die 或命运终结 conclude_story_fate，均发 defeated）→ 取消计时，
##   走既有胜利链路，本流程不干预。
##   倒计时耗尽仍未击杀 → 触发逃出序列：
##     1. 冻结 Boss（停物理处理 / 禁碰撞 / 清速度），不再战斗；
##     2. 天顶崩塌表现（复用 arena_phase_vfx 金黑暗光柱 / 冲击环 / 余烬）+ 震屏 + 镜头聚焦；
##     3. 标记逃出结果 run_state.choice_flags["ch4_xuanxiao_escaped"]=true 并落盘；
##     4. 玄霄上升 + 发光淡出 + 缩小后移除（走可见收场，非卡死）。
## 全程不修改 Engine.time_scale。
##
## 挂载：boss_flow_controller.gd 读取章节内容 dict["flow"] 实例化本脚本为 "FlowController"，
## 注入 flow_boss / flow_config，并桥接 boss.phase_changed → _on_phase。

const ArenaPhaseVfxScript = preload("res://scripts/fx/arena_phase_vfx.gd")

## 逃出结果旗标：后续内容可读取分支。逃出 ≠ 击杀，不写入 defeated_bosses、不结算奖励、
## 不触发 ch4_xuanxiao_fate 命运抉择（现有 boss_fate_catalog / ending_resolver 无"逃出"分支）。
const ESCAPE_FLAG := "ch4_xuanxiao_escaped"
## 天顶崩塌 VFX key：复用 arena_phase_vfx 的金黑暗崩塌色（corrupted_divine_light 命中色表）。
const COLLAPSE_VFX_KEY := "corrupted_divine_light"

## 契约属性（boss_flow_controller 注入；必须先于 add_child 之后读取，故初始化推迟到帧末）
var flow_boss: Node
var flow_config: Dictionary = {}

var _escape_after_seconds := 90.0
var _elapsed := 0.0
var _initialized := false
var _countdown_active := false
var _defeated := false
var _escaped := false
var _warned_at := 0.0
var _urgency_shake_accum := 0.0
var _arena_vfx = null


func _ready() -> void:
	# 主机在 boss.add_child(node) 之后才写 flow_boss / flow_config，_ready 时仍为空 →
	# call_deferred 到帧末再初始化（此时 attach() 已完整返回，引用已注入）。
	call_deferred("_initialize")


func _initialize() -> void:
	if _initialized:
		return
	var boss: Variant = flow_boss
	if boss == null or not is_instance_valid(boss):
		return
	_initialized = true
	_escape_after_seconds = maxf(float(flow_config.get("escape_after_seconds", 90.0)), 1.0)
	_elapsed = 0.0
	_countdown_active = true
	_defeated = false
	_escaped = false
	_warned_at = ceilf(_escape_after_seconds)
	_urgency_shake_accum = 0.0
	# 倒计时内 Boss 死亡（正常击杀 / 命运终结）→ 取消计时，不触发逃出
	if boss.has_signal("defeated"):
		boss.defeated.connect(_on_boss_defeated)
	_show_message("THE ZENITH COLLAPSES IN %d SECONDS — SLAY XUAN XIAO" % int(_escape_after_seconds), 3.0)


func _process(delta: float) -> void:
	if not _initialized or not _countdown_active or _defeated or _escaped:
		return
	var boss: Variant = flow_boss
	# 命运抉择（ch4_xuanxiao_fate 清醒窗）进行中：暂停逃出倒计时，避免与命运菜单冲突
	if boss != null and is_instance_valid(boss) \
			and boss.has_method("is_in_story_resolution") and bool(boss.is_in_story_resolution()):
		return
	_elapsed += delta
	_tick_urgency(delta, _escape_after_seconds - _elapsed)
	if _elapsed >= _escape_after_seconds:
		_trigger_escape()


## 倒计时内 Boss 死亡：取消计时（不触发逃出）
func _on_boss_defeated(_enemy: Variant = null, _reward: int = 0, _is_guardian: bool = false) -> void:
	_defeated = true
	_countdown_active = false


## 紧迫提示：剩余 ≤30/15/10/5/3 各提示一次（可见 HUD 文案 + 震屏）；最后 10s 以渐快脉动震屏
func _tick_urgency(delta: float, remaining: float) -> void:
	for threshold in [30.0, 15.0, 10.0, 5.0, 3.0]:
		if remaining <= threshold and _warned_at > threshold:
			_warned_at = threshold
			_show_message("ZENITH COLLAPSE IN %d..." % int(threshold), 1.4)
			_inject_shake(0.4)
	if remaining <= 10.0:
		_urgency_shake_accum += delta
		if _urgency_shake_accum >= 0.22:
			_urgency_shake_accum = 0.0
			_inject_shake(0.12)


## 到点：触发逃出序列（恰好一次）
func _trigger_escape() -> void:
	if _escaped or _defeated:
		return
	var boss: Variant = flow_boss
	if boss == null or not is_instance_valid(boss):
		_escaped = true
		return
	_escaped = true
	_countdown_active = false
	_mark_escape_result()
	_unseal_arena()
	_freeze_boss(boss)
	_play_collapse_vfx(boss)
	_close_out_boss(boss)


## 逃出结果落点：run_state.choice_flags["ch4_xuanxiao_escaped"]=true + 落盘。
## 依据：现有结局链路（boss_fate_catalog.ch4_xuanxiao_fate / ending_resolver）只有"击杀→命运抉择"
## 分支，无"逃出"分支；逃出 = 未击杀，故落独立 choice_flag，供后续章节内容读取分支。
func _mark_escape_result() -> void:
	var world: Variant = _world()
	if world == null:
		return
	var run_state: Variant = world.get("run_state")
	if run_state != null and run_state.has_method("set_choice_flag"):
		run_state.set_choice_flag(ESCAPE_FLAG, true)
	if world.has_method("_save_run"):
		world._save_run("xuanxiao_escaped")


## 逃出后通知 world 解封竞技场 + 开放出口（reuse game_world.on_boss_escaped）。
func _unseal_arena() -> void:
	var world: Variant = _world()
	if world == null:
		return
	if world.has_method("on_boss_escaped"):
		world.on_boss_escaped()


## 冻结 Boss：停物理处理 / 禁碰撞 / 清速度，结束战斗但不发 defeated（≠ 击杀）
func _freeze_boss(boss: Variant) -> void:
	if boss == null or not is_instance_valid(boss):
		return
	if boss.has_method("set_physics_process"):
		boss.set_physics_process(false)
	boss.set("velocity", Vector3.ZERO)
	# 取消进行中的挥击伤害窗，避免冻结后残留攻击命中玩家
	var combat_area: Variant = boss.get("combat_area")
	if combat_area != null and combat_area.has_method("end_swing"):
		combat_area.end_swing()
	var collision: Variant = boss.get("body_collision")
	if collision != null:
		collision.set_deferred("disabled", true)


## 天顶崩塌表现：金黑暗崩塌 VFX（复用 arena_phase_vfx）+ 震屏 + 镜头聚焦 + 文案
func _play_collapse_vfx(boss: Variant) -> void:
	var world: Variant = _world()
	if world == null:
		return
	var origin: Vector3 = boss.get("global_position") if boss.is_inside_tree() else Vector3.ZERO
	if _arena_vfx == null:
		_arena_vfx = ArenaPhaseVfxScript.new()
		_arena_vfx.name = "XuanxiaoEscapeVfx"
		world.add_child(_arena_vfx)
	if _arena_vfx != null and _arena_vfx.has_method("play_at"):
		# parent 传 world：崩塌 VFX 挂在世界下，Boss 移除后仍可播完
		_arena_vfx.play_at(origin, 3, COLLAPSE_VFX_KEY, world)
	_inject_shake(1.0)
	var camera: Variant = world.get_node_or_null("CombatCameraDirector")
	if camera != null and camera.has_method("play_shot_id"):
		camera.play_shot_id(&"fate_halfbody", boss)
	var hud: Variant = _hud()
	if hud != null:
		hud.hide_boss()
	_show_message("THE ZENITH COLLAPSES\nXUAN XIAO FLEES INTO THE RUINS", 3.4)


## 可见收场：玄霄上升 + 发光过载 + 缩小后移除（非卡死，不发 defeated）
func _close_out_boss(boss: Variant) -> void:
	if boss == null or not is_instance_valid(boss):
		return
	var visual: Variant = boss.get("visual_root")
	var body_mat: Variant = boss.get("body_material")
	var start_y := 0.0
	if visual != null and visual.is_inside_tree():
		start_y = visual.get("global_position").y
	var tw := create_tween()
	tw.set_parallel(true)
	if visual != null:
		tw.tween_property(visual, "position:y", start_y + 2.6, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(visual, "scale", Vector3.ZERO, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if body_mat != null:
		tw.tween_property(body_mat, "emission_energy_multiplier", 6.0, 1.2)
	tw.chain().tween_callback(func():
		if is_instance_valid(boss):
			boss.queue_free()
	)


## 相变钩子（主机转发 boss.phase_changed → 本方法）：phase3 起叠加紧迫感
func _on_phase(new_phase: int) -> void:
	if new_phase >= 3 and not _escaped and not _defeated:
		_inject_shake(0.5)
		_show_message("THE SKY BREAKS", 1.4)


func _world() -> Variant:
	var boss: Variant = flow_boss
	if boss == null or not is_instance_valid(boss):
		return null
	return boss.get("world_node")


func _hud() -> Variant:
	var world: Variant = _world()
	if world == null:
		return null
	return world.get("hud")


func _inject_shake(amount: float) -> void:
	var world: Variant = _world()
	if world == null:
		return
	var shake: Variant = world.get_node_or_null("TraumaShake")
	if shake != null and shake.has_method("inject"):
		shake.inject(amount)


func _show_message(text: String, duration: float) -> void:
	var hud: Variant = _hud()
	if hud != null and hud.has_method("show_message"):
		hud.show_message(text, duration)
