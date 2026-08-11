# 风险修复设计：玄霄逃出软锁 + 动画 clip 管线

> 2026-08-11 · 依据 `docs/devlog/2026-08-11/03-all-gaps-fix-orchestration-reflection.md` 的独立验证结论。
> 用户批准范围：①逃出=解封+出口；②动画只修管线（route-B 真 locomotion 资产生产保持为后续任务）。

---

## 背景（验证发现的风险）

### R1 — 玄霄 90s 逃出软锁（真实风险）
`xuanxiao_escape_flow.gd::_trigger_escape` 冻结并 `queue_free()` 掉 boss，但**不发 `defeated`**；
`game_world.gd::_on_enemy_defeated` 只在 `defeated` 分支解封竞技场 + 生成出口
（`_open_boss_victory_exit` → `campaign_module_runtime.release_arena_seals()` + `spawn_victory_exit()`）。
结果：玩家 90s 内未击杀 → 封场墙保持 + 无出口 → 被困在崩塌竞技场（软锁）。
`ch4_xuanxiao_escaped` 旗标被写入但无运行时消费者（存档落点标记，供后续章节分支）。

### R2 — 真动画 clip 永不驱动（管线 bug，非阻断）
- `player_animation_bridge.gd::REAL_IDLE_FALLBACK = "Armature|mixamo.com|..."`（点号），但 Godot GLB 导入把 `mixamo.com` 消毒成 `mixamo_com`（下划线），常量**永久死**——任何 Mixamo 命名的真 clip 都不会被兜底命中。
- `has_real_animations()` 只要"库非空 + 层激活"就返回 true，即使没有状态真正使用真 clip（误导 API）。
- 唯一现成 clip（mannyquin）是 1 帧（0.04s）3 轨绑位姿，非 locomotion；若名字修对后让它接管 idle，会冻结玩家为 A-pose（回归）。
- 真 locomotion 资产在 `example/Godot4-OpenAnimationLibraries/Libraries/Humanoid/`（MeleeLib.res / ShooterLib.res），从未重定向/接线 → route-B 后续任务，不在本次范围。

---

## Fix 1 — 玄霄逃出：解封 + 开放出口（防软锁）

### 目标
90s 倒计时耗尽、玄霄逃出时：竞技场封场墙降下 + 生成通往下一关的出口。逃出 ≠ 击杀：
不发 `defeated`、无胜利结算、无战利品、不写入 `defeated_bosses`、不触发 `ch4_xuanxiao_fate`
命运抉择；`ch4_xuanxiao_escaped` 照常落盘供后续章节分支。玩家可继续推进（不软锁）。

### 文件与改动

**`game/scripts/game_world.gd`** — 新增公开入口：
```gdscript
## 玄霄逃出（90s 未击杀）：boss 未发 defeated → 无胜利/战利品；
## 但解封竞技场 + 开放出口，避免玩家被困崩塌竞技场（软锁）。
func on_boss_escaped() -> void:
    _open_boss_victory_exit()
```
复用 `_open_boss_victory_exit()`：`release_arena_seals()`（遍历降墙，幂等）+
`spawn_victory_exit()`（守卫已存在出口，幂等）+ HUD 文案。

**`game/scripts/boss/flow/xuanxiao_escape_flow.gd`** — `_trigger_escape()` 加一步：
```gdscript
_escaped = true
_countdown_active = false
_mark_escape_result()
_unseal_arena()          # 新增：倒计时耗尽即解封，墙随崩塌落下
_freeze_boss(boss)
_play_collapse_vfx(boss)
_close_out_boss(boss)
```
```gdscript
## 逃出后通知 world 解封竞技场 + 开放出口（reuse game_world.on_boss_escaped）。
func _unseal_arena() -> void:
    var world: Variant = _world()
    if world == null:
        return
    if world.has_method("on_boss_escaped"):
        world.on_boss_escaped()
```
（与文件其余部分一致的防御式 `has_method`/null 守卫风格。）

### 新增合约 `game/tests/smoke/xuanxiao_escape_contract.gd`
- SceneTree 合约：`_initialize()` + `call_deferred("_run_all")`（项目 Godot 4.7 既有模式）。
- 桩 world：Node，含 `run_state`（mock `set_choice_flag` 记录进 Dictionary + `_save_run`）、
  `on_boss_escaped()`（记录调用次数）、`hud`（mock `show_message`/`hide_boss`）、
  `add_child`、`get_node_or_null` 返回 null（TraumaShake/CombatCameraDirector 守卫走空）。
- 桩 boss：Node，含 `defeated` 信号、`global_position`、`is_inside_tree()`、`set_physics_process`、
  `set velocity`、`combat_area`（mock `end_swing`）、`body_collision`、`visual_root`、`body_material`、`world_node`。
- 挂载：用 `BossFlowController.attach(stub_boss, {"flow": {...}})` 走真实挂载路径，
  帧末 `_initialize` 后直接 `_trigger_escape()`（绕过 90s 计时）。
- 断言：
  - `world.on_boss_escaped` 被调用**恰好 1 次**；
  - `run_state.choice_flags["ch4_xuanxiao_escaped"] == true`；
  - `_escaped == true`（幂等：再调一次不重复通知）。
- 成功 marker：`ASHEN_XUANXIAO_ESCAPE_CONTRACTS_OK`。

---

## Fix 2 — 动画 clip 管线修正（修死常量 + 诚实 API + 绑位守卫）

### 目标
让 D-01 真动画层的兜底/状态解析**真实可用**：名字不再错配、`has_real_animations()` 诚实、
mannyquin 绑位姿不会冻结玩家。管线修好后，未来真 locomotion clip 到来即能驱动。

### 文件与改动（`game/scripts/combat/player_animation_bridge.gd`）

1. **修死常量**（行 37）：
```gdscript
## 真库缺 idle 时的 mannyquin rig 绑位 clip 名。
## Godot GLB 导入把 "mixamo.com" 消毒为 "mixamo_com"（下划线），const 用导入后名。
const REAL_IDLE_FALLBACK := &"Armature|mixamo_com|Layer0_godot_rig"
```

2. **绑位兜底守卫**（新增常量 + `_real_clip_for` 分支收紧）：
```gdscript
## 绑位 clip 兜底只在该 clip 有实质内容时才接管 idle，防止 1 帧绑位姿冻结玩家为 A-pose。
const MIN_FALLBACK_TRACKS := 4
const MIN_FALLBACK_LENGTH := 0.1
```
```gdscript
if state_key == IDLE_ANIM and _real_library.has_animation(String(REAL_IDLE_FALLBACK)):
    var fb := _real_library.get_animation(String(REAL_IDLE_FALLBACK))
    if fb != null and fb.get_track_count() >= MIN_FALLBACK_TRACKS \
            and fb.length >= MIN_FALLBACK_LENGTH:
        return REAL_IDLE_FALLBACK
return &""
```
（mannyquin 绑位姿 3 轨 0.04s → 被守卫 → idle 保持 `combat/idle`。精确同名状态键不受守卫影响。）

3. **诚实 `has_real_animations()`**（行 215）：
```gdscript
## 真动画层是否在驱动：至少一个状态实际解析到真 clip（而非"库非空"）。
func has_real_animations() -> bool:
    if not real_layer_active or _real_library == null:
        return false
    for key in REAL_STATE_KEYS:
        if not _real_clip_for(key).is_empty():
            return true
    return false
```
新增常量 `REAL_STATE_KEYS`（`_clip_path` 用到的 10 个状态键：idle/walk/strafe_fwd/strafe_back/
strafe_left/strafe_right/sword_light_1/colossal_leap/riposte/backstab）。

### 合约扩展 `game/tests/smoke/player_animation_real_contract.gd`
新增第 4 用例 `_test_mannyquin_bind_pose_guarded()`：
- 加载真实 `res://resources/animations/mannyquin_lib.tres`，用 `configure_real_animations` 注入；
- 断言 `REAL_IDLE_FALLBACK` 键在库中存在（**名字已修**）；
- 断言 `_real_clip_for(&"idle")` 为 `&""`（**绑位姿被守卫**）；
- 断言 `has_real_animations()` 为 false、Idle 节点动画 == `combat/idle`。

### 注释更新 `game/scripts/tools/export_mannyquin_animations.gd`
文件头说明：Godot GLB 导入把 clip 名 `mixamo.com` 消毒为 `mixamo_com`，bridge 的
`REAL_IDLE_FALLBACK` 用导入后名；未来作者化真 clip 用状态键命名（idle/walk/...）即精确匹配。

---

## 验证（父进程独立重跑，不信子代理自报）

1. 编辑器导入：`--headless --editor --path game --quit` → EXIT 0，无 SCRIPT ERROR / Parse Error。
2. 新合约：`xuanxiao_escape_contract.gd` → `ASHEN_XUANXIAO_ESCAPE_CONTRACTS_OK`。
3. 改合约：`player_animation_real_contract.gd` → `PLAYER_ANIMATION_REAL_CONTRACTS_OK`。
4. 全量 smoke 38 合约：全绿（回归扫描）。
5. GUT：95/96（维持既有 `test_stamina_economy` 陈旧断言，只报不改）。
6. 运行时 smoke：`-- --smoke-test` → `ASHEN_HOLLOW_SMOKE_OK`。

## 范围外（记录不改）

- 真 locomotion 动画资产生产（OpenAnimationLibraries Humanoid `.res` → 玩家骨架重定向）——route-B 后续任务。
- `ch3_memory_gaze_seen` / `ch4_xuanxiao_escaped` 是存档落点标记：escape 修复后 `ch4` 旗标已有实际语义
  （逃出分支已由 world.on_boss_escaped 消费），未来章节内容读取分支。
- LimboAI 真替换、NG+ 凝视打断、结局尾声、精英名册 11 项文本错位、武器 scale 目检、P3 浮空手测——
  均为已记录的非阻断/装饰性/人工 QA 项。
