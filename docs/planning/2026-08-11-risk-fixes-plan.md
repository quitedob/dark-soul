# 风险修复 Implementation Plan（玄霄逃出软锁 + 动画 clip 管线）

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复两个已验证风险：①玄霄 90s 逃出导致竞技场软锁；②真动画 clip 因名字错配/误导 API 永不驱动。用户批准范围：逃出=解封+出口；动画只修管线（route-B 真 locomotion 资产生产保持为后续任务）。

**Architecture:** Fix 1 通过新增 `game_world.on_boss_escaped()`（复用 `_open_boss_victory_exit()`）+ 逃出流程 `_unseal_arena()` 通知，逃出时解封竞技场并生成出口（不发 `defeated`，无胜利/战利品）。Fix 2 修正 `player_animation_bridge.gd` 的死常量（`mixamo.com`→`mixamo_com`）、给绑位 clip 兜底加内容守卫、把 `has_real_animations()` 改为诚实语义。

**Tech Stack:** Godot 4.7.1 / GDScript · SceneTree 合约测试（`--script`）· GUT 单测 · 引擎 headless 验证

**Design spec:** `docs/planning/2026-08-11-risk-fixes-design.md`

**Godot 命令常量：**
- exe：`"E:/godot/Godot_v4.7.1-stable_win64_console.exe"`
- 项目：`"e:/godot/darksoul/game"`
- 合约脚本路径相对项目目录（`--script tests/smoke/<name>.gd`），与既有验证一致。
- 已知基线：GUT 95/96，唯一失败是既有陈旧断言 `test_stamina_economy`（只报不改）。

---

## 文件结构

| 文件 | 责任 | 操作 |
|---|---|---|
| `game/scripts/game_world.gd`（热文件，主线程写） | 新增 `on_boss_escaped()` 公开入口 | Modify（~1467 之后） |
| `game/scripts/boss/flow/xuanxiao_escape_flow.gd` | `_trigger_escape` 加 `_unseal_arena()` 通知 world | Modify |
| `game/tests/smoke/xuanxiao_escape_contract.gd` | Fix 1 合约：逃出通知+旗标+幂等 | Create |
| `game/scripts/combat/player_animation_bridge.gd` | Fix 2：修常量/守卫/诚实 API | Modify |
| `game/tests/smoke/player_animation_real_contract.gd` | Fix 2 合约第 4 用例（绑位守卫+名字对齐） | Modify |
| `game/scripts/tools/export_mannyquin_animations.gd` | 注释说明名字消毒 | Modify（仅注释） |
| `docs/devlog/2026-08-11/04-risk-fixes-validation.md` | 会话记录 + 验证结果 | Create（最后） |

---

## Task 1: 写 Fix 1 合约（红）

**Files:**
- Create: `game/tests/smoke/xuanxiao_escape_contract.gd`

- [ ] **Step 1: 创建合约文件**，完整内容如下：

```gdscript
extends SceneTree
## 玄霄逃出流程合约：90s 倒计时耗尽触发逃出时，必须通知 world 解封竞技场（不软锁），
## 且 ch4_xuanxiao_escaped 旗标落盘；通知恰好一次（幂等）。
##
## 用桩 world + 桩 boss 走 BossFlowController.attach 真实挂载路径，直接 _trigger_escape()
## （绕过 90s 计时），断言逃出通知与旗标。

const FlowHostScript = preload("res://scripts/boss/boss_flow_controller.gd")

const SUCCESS_MARKER := "ASHEN_XUANXIAO_ESCAPE_CONTRACTS_OK"
const ESCAPE_FLAG := "ch4_xuanxiao_escaped"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	call_deferred("_test_escape")


func _test_escape() -> void:
	var world := StubWorld.new()
	root.add_child(world)
	var boss := StubBoss.new()
	boss.world_node = world
	boss.visual_root = Node3D.new()
	boss.add_child(boss.visual_root)
	root.add_child(boss)

	var host := FlowHostScript.new()
	boss.add_child(host)
	var attached := host.attach(boss, {
		"flow": {
			"script": "res://scripts/boss/flow/xuanxiao_escape_flow.gd",
			"config": {"escape_after_seconds": 90.0},
		},
	})
	_expect(attached, "escape: BossFlowController must attach the escape flow.")

	var flow: Variant = boss.get_node_or_null("FlowController")
	_expect(flow != null, "escape: flow node must be mounted on the boss.")
	if flow == null:
		_finish()
		return

	flow._trigger_escape()

	_expect(world.escape_notified == 1,
		"escape: world.on_boss_escaped must be notified exactly once, got %d." % world.escape_notified)
	_expect(bool(world.run_state.flags.get(ESCAPE_FLAG, false)) == true,
		"escape: ch4_xuanxiao_escaped flag must be recorded in run_state.choice_flags.")
	_expect(flow._escaped == true, "escape: flow must be in escaped state.")

	# 幂等：第二次触发不得重复通知
	flow._trigger_escape()
	_expect(world.escape_notified == 1,
		"escape: second trigger must NOT re-notify, got %d." % world.escape_notified)

	boss.queue_free()
	world.queue_free()
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print(SUCCESS_MARKER)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


class StubWorld:
	extends Node
	var run_state := StubRunState.new()
	var hud: Node
	var escape_notified := 0

	func on_boss_escaped() -> void:
		escape_notified += 1

	func _save_run(_reason: String) -> void:
		pass


class StubRunState:
	extends RefCounted
	var flags := {}

	func set_choice_flag(flag: String, value: Variant) -> void:
		flags[flag] = value


class StubBoss:
	extends Node3D
	signal defeated(enemy, reward, is_guardian)
	var world_node: Node
	var velocity := Vector3.ZERO
	var combat_area: Node
	var body_collision: Node3D
	var visual_root: Node3D
	var body_material: StandardMaterial3D
```

- [ ] **Step 2: 运行合约，确认红（逃出通知缺失）**

Run: `"E:/godot/Godot_v4.7.1-stable_win64_console.exe" --headless --path "e:/godot/darksoul/game" --script tests/smoke/xuanxiao_escape_contract.gd`
Expected: 失败（无 marker），输出含 `escape: world.on_boss_escaped must be notified exactly once, got 0.`，退出码 1。原因：`_trigger_escape` 尚未调用 `_unseal_arena`。

---

## Task 2: 实现 Fix 1 绿色（game_world 入口 + 流程接线）

**Files:**
- Modify: `game/scripts/game_world.gd`（在 `_open_boss_victory_exit()` 函数 `game_world.gd:1467-1472` 之后新增）
- Modify: `game/scripts/boss/flow/xuanxiao_escape_flow.gd`

- [ ] **Step 1: `game_world.gd` 新增公开入口**（紧跟 `_open_boss_victory_exit` 定义之后）：

```gdscript
func on_boss_escaped() -> void:
	# 玄霄逃出（90s 未击杀）：boss 未发 defeated → 无胜利/战利品；
	# 但解封竞技场 + 开放出口，避免玩家被困崩塌竞技场（软锁）。
	_open_boss_victory_exit()
```

- [ ] **Step 2: 逃出流程 `_trigger_escape` 加 `_unseal_arena()` 调用**（`xuanxiao_escape_flow.gd:100-113`，把 `_trigger_escape` 替换为）：

```gdscript
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
```

- [ ] **Step 3: 新增 `_unseal_arena` 方法**（放在 `_mark_escape_result` 之后，风格与文件其余防御式守卫一致）：

```gdscript
## 逃出后通知 world 解封竞技场 + 开放出口（reuse game_world.on_boss_escaped）。
func _unseal_arena() -> void:
	var world: Variant = _world()
	if world == null:
		return
	if world.has_method("on_boss_escaped"):
		world.on_boss_escaped()
```

- [ ] **Step 4: 运行合约，确认绿**

Run: `"E:/godot/Godot_v4.7.1-stable_win64_console.exe" --headless --path "e:/godot/darksoul/game" --script tests/smoke/xuanxiao_escape_contract.gd`
Expected: 打印 `ASHEN_XUANXIAO_ESCAPE_CONTRACTS_OK`，退出码 0。

- [ ] **Step 5: 提交**

```bash
cd e:/godot/darksoul
git add game/scripts/game_world.gd game/scripts/boss/flow/xuanxiao_escape_flow.gd game/tests/smoke/xuanxiao_escape_contract.gd
git commit -m "$(cat <<'EOF'
fix: xuanxiao 90s escape unseals arena + spawns exit (no soft-lock)

Escape now notifies game_world via new on_boss_escaped(), which reuses
_open_boss_victory_exit() to drop the arena seal and open a path forward.
No defeated signal, no victory/loot, ch4_xuanxiao_escaped flag still recorded
for future chapters. Adds xuanxiao_escape_contract.gd covering notify-once +
flag persistence + idempotency.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: 扩展 Fix 2 合约（红）

**Files:**
- Modify: `game/tests/smoke/player_animation_real_contract.gd`

- [ ] **Step 1: 在 `_test_root_only_clip_stays_fallback` 之后、`_cleanup_tmp_files` 之前调用新用例**（`player_animation_real_contract.gd:101-126`，在 `_test_root_only_clip_stays_fallback()` 调用行后加）：

```gdscript
	_test_mannyquin_bind_pose_guarded()
```

- [ ] **Step 2: 新增第 4 用例函数**（加在 `_test_root_only_clip_stays_fallback` 函数结束 `}` 之后、`_make_head_library` 之前）：

```gdscript
## 4) 真实 mannyquin 绑位姿：REAL_IDLE_FALLBACK 名字已对齐（下划线导入名），
##    但内容太薄（3 轨 0.04s）→ 被守卫 → 不驱动 idle，程序化回退。
func _test_mannyquin_bind_pose_guarded() -> void:
	var body := CharacterBody3D.new()
	root.add_child(body)
	var skel := Skeleton3D.new()
	skel.name = "Skeleton3D"
	skel.add_bone("root")
	skel.set_bone_rest(0, Transform3D.IDENTITY)
	skel.add_bone("DEF-thumb.01.R")
	skel.set_bone_rest(1, Transform3D.IDENTITY)
	body.add_child(skel)

	var bridge = AnimBridge.new()
	bridge.setup(body)
	var ok := bridge.configure_real_animations("res://resources/animations/mannyquin_lib.tres", skel)
	_expect(ok, "bind-pose: configure must succeed (lib loads + skeleton matches).")
	_expect(bridge.real_layer_active, "bind-pose: real layer injected (library present).")
	_expect(bool(bridge._real_library.has_animation(String(bridge.REAL_IDLE_FALLBACK))),
		"bind-pose: REAL_IDLE_FALLBACK must match imported lib key (underscore).")
	_expect(bridge.real_clip_for(&"idle").is_empty(),
		"bind-pose: bind-pose clip must NOT drive idle (guarded).")
	_expect(not bridge.has_real_animations(),
		"bind-pose: has_real_animations must be false (no state driven).")
	var sm := bridge.anim_tree.tree_root as AnimationNodeStateMachine
	var idle_node := sm.get_node("Idle") as AnimationNodeAnimation
	if idle_node != null:
		_expect(idle_node.animation == "combat/idle",
			"bind-pose: Idle must stay 'combat/idle', got '%s'." % idle_node.animation)
	body.queue_free()
```

- [ ] **Step 3: 运行合约，确认红（名字未对齐 + 诚实 API 未做）**

Run: `"E:/godot/Godot_v4.7.1-stable_win64_console.exe" --headless --path "e:/godot/darksoul/game" --script tests/smoke/player_animation_real_contract.gd`
Expected: 失败，输出含：
- `bind-pose: REAL_IDLE_FALLBACK must match imported lib key (underscore).`
- `bind-pose: has_real_animations must be false (no state driven).`
退出码 1。原因：const 仍是点号名（不命中）+ `has_real_animations()` 只看"库非空"。

---

## Task 4: 实现 Fix 2 绿色（bridge 管线修正）

**Files:**
- Modify: `game/scripts/combat/player_animation_bridge.gd`
- Modify: `game/scripts/tools/export_mannyquin_animations.gd`（仅注释）

- [ ] **Step 1: 修死常量 `REAL_IDLE_FALLBACK`**（`player_animation_bridge.gd:37`，把点号名改为下划线导入名并更新注释）：

```gdscript
## 真库缺 idle 时的 mannyquin rig 绑位 clip 名。
## Godot GLB 导入把 clip 名 "mixamo.com" 消毒为 "mixamo_com"（下划线），const 用导入后名。
const REAL_IDLE_FALLBACK := &"Armature|mixamo_com|Layer0_godot_rig"
```

- [ ] **Step 2: 新增守卫常量**（紧跟 `REAL_IDLE_FALLBACK` 常量之后）：

```gdscript
## 绑位 clip 兜底只在该 clip 有实质内容时才接管 idle，防止 1 帧绑位姿冻结玩家为 A-pose。
const MIN_FALLBACK_TRACKS := 4
const MIN_FALLBACK_LENGTH := 0.1
## `_clip_path` 用到的全部状态键：真动画层是否驱动以它们为准。
const REAL_STATE_KEYS: Array[StringName] = [
	&"idle", &"walk",
	&"strafe_fwd", &"strafe_back", &"strafe_left", &"strafe_right",
	&"sword_light_1", &"colossal_leap", &"riposte", &"backstab",
]
```

- [ ] **Step 3: `has_real_animations()` 诚实化**（`player_animation_bridge.gd:214-218`，替换为）：

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

- [ ] **Step 4: `_real_clip_for` 加绑位守卫**（`player_animation_bridge.gd:407-415`，替换为）：

```gdscript
## 状态 → 真 clip 名：优先精确同名；idle 缺省时回退 mannyquin rig 绑位层
## （仅当该 clip 有实质内容，避免 1 帧绑位姿冻结玩家）。
func _real_clip_for(state_key: StringName) -> StringName:
	if _real_library == null:
		return &""
	if _real_library.has_animation(String(state_key)):
		return state_key
	if state_key == IDLE_ANIM and _real_library.has_animation(String(REAL_IDLE_FALLBACK)):
		var fb := _real_library.get_animation(String(REAL_IDLE_FALLBACK))
		if fb != null and fb.get_track_count() >= MIN_FALLBACK_TRACKS \
				and fb.length >= MIN_FALLBACK_LENGTH:
			return REAL_IDLE_FALLBACK
	return &""
```

- [ ] **Step 5: 更新抽库工具注释**（`export_mannyquin_animations.gd` 文件头说明块，`export_mannyquin_animations.gd:12-15`，把 `## 说明：` 段替换为）：

```gdscript
## 说明：mannyquin.glb 当前只带一条 rig/Layer0 绑位 clip（root+hips 的 2 帧），
## 导出后 clip 名保留原样（"Armature|mixamo.com|Layer0_godot_rig"）。注意 Godot GLB
## 导入会把 clip 名里的 "." 消毒为 "_"（导入后为 "Armature|mixamo_com|Layer0_godot_rig"）；
## bridge 的 REAL_IDLE_FALLBACK 用导入后名，且绑位姿（3 轨 0.04s）会被守卫不会驱动 idle。
## 未来作者化真 clip 直接用状态键命名（idle/walk/strafe_*）即精确匹配。
```

- [ ] **Step 6: 运行合约，确认绿（全部 4 用例）**

Run: `"E:/godot/Godot_v4.7.1-stable_win64_console.exe" --headless --path "e:/godot/darksoul/game" --script tests/smoke/player_animation_real_contract.gd`
Expected: 打印 `PLAYER_ANIMATION_REAL_CONTRACTS_OK`，退出码 0。

- [ ] **Step 7: 提交**

```bash
cd e:/godot/darksoul
git add game/scripts/combat/player_animation_bridge.gd game/scripts/tools/export_mannyquin_animations.gd game/tests/smoke/player_animation_real_contract.gd
git commit -m "$(cat <<'EOF'
fix: real-animation clip pipeline (dead fallback name + honest API + bind guard)

- REAL_IDLE_FALLBACK now matches Godot's sanitized import name (mixamo_com),
  fixing a permanently-dead fallback constant.
- Bind-pose clip (3 tracks / 0.04s) is guarded so it can't freeze the player
  into an A-pose; exact-name state clips are unaffected.
- has_real_animations() now reports true only when a state actually resolves
  to a real clip, not merely when the library is non-empty.
- Extends player_animation_real_contract with a bind-pose guard case verified
  against the real mannyquin_lib.tres.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: 独立验证（父进程重跑，不信子代理自报）

**Files:** 无（只读验证）

- [ ] **Step 1: 编辑器导入（全部脚本 + 资源）**

Run: `"E:/godot/Godot_v4.7.1-stable_win64_console.exe" --headless --editor --path "e:/godot/darksoul/game" --quit`
Expected: 退出码 0，无 `SCRIPT ERROR` / `Parse Error`（Godot 关闭时的 ObjectDB/resource-leak 提示属正常）。

- [ ] **Step 2: 新增合约**

Run: `"E:/godot/Godot_v4.7.1-stable_win64_console.exe" --headless --path "e:/godot/darksoul/game" --script tests/smoke/xuanxiao_escape_contract.gd`
Expected: `ASHEN_XUANXIAO_ESCAPE_CONTRACTS_OK`

- [ ] **Step 3: 改合约**

Run: `"E:/godot/Godot_v4.7.1-stable_win64_console.exe" --headless --path "e:/godot/darksoul/game" --script tests/smoke/player_animation_real_contract.gd`
Expected: `PLAYER_ANIMATION_REAL_CONTRACTS_OK`

- [ ] **Step 4: 全量 smoke 38 合约回归扫描**

Run（从 `game/` 目录）:
```bash
cd e:/godot/darksoul/game
GODOT="E:/godot/Godot_v4.7.1-stable_win64_console.exe"
PASS=0; FAIL=0; FAILED_LIST=""
for f in tests/smoke/*.gd; do
  if grep -q "extends SceneTree" "$f"; then
    name=$(basename "$f" .gd)
    out=$("$GODOT" --headless --path "e:/godot/darksoul/game" --script "$f" 2>&1)
    rc=$?
    if [ $rc -eq 0 ] && ! echo "$out" | grep -qiE "SCRIPT ERROR|Parse Error|assertion failed"; then
      PASS=$((PASS+1))
    else
      FAIL=$((FAIL+1)); FAILED_LIST="$FAILED_LIST $name"
    fi
  fi
done
echo "PASS=$PASS FAIL=$FAIL FAILED=$FAILED_LIST"
```
Expected: `PASS=38 FAIL=0`。

- [ ] **Step 5: GUT 套件**

Run: `"E:/godot/Godot_v4.7.1-stable_win64_console.exe" --headless --path "e:/godot/darksoul/game" -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit`
Expected: `Tests 96 / Passing 95 / Failing 1`，唯一失败是既有 `test_target_style_costs_and_insufficient_block`（`test_stamina_economy` 陈旧断言，只报不改）。

- [ ] **Step 6: 运行时 smoke**

Run: `"E:/godot/Godot_v4.7.1-stable_win64_console.exe" --headless --path "e:/godot/darksoul/game" --quit-after 600 -- --smoke-test`
Expected: `ASHEN_HOLLOW_SMOKE_OK`，无 ERROR。

- [ ] **Step 7: 确认 git 工作区无验证噪音**

Run: `cd e:/godot/darksoul && git status --porcelain`
Expected: 仅 Task 2/4 已提交的改动 + 既有 08-11 交付未提交文件；无新增意外文件（检查 `resources/animations/mannyquin_lib.tres` 未被重写）。

---

## Task 6: 文档（devlog 记录 + 索引）

**Files:**
- Create: `docs/devlog/2026-08-11/04-risk-fixes-validation.md`
- Modify: `docs/devlog/index.md`

- [ ] **Step 1: 创建 devlog 条目**，简短记录本次两个修复 + 验证结果（含 `path:line` 证据与"范围外"清单），标题示例：
`# 风险修复：玄霄逃出解封 + 动画 clip 管线（2026-08-11）`

- [ ] **Step 2: 更新 `docs/devlog/index.md`** 追加一条 2026-08-11 条目。

- [ ] **Step 3: 提交**

```bash
cd e:/godot/darksoul
git add docs/devlog/2026-08-11/04-risk-fixes-validation.md docs/devlog/index.md
git commit -m "$(cat <<'EOF'
docs: devlog for risk fixes (xuanxiao escape unseal + anim clip pipeline)

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

## 范围外（本计划不实现）

- 真 locomotion 动画资产生产（`example/Godot4-OpenAnimationLibraries/Libraries/Humanoid/*.res` → 玩家骨架重定向）——route-B 后续任务。
- LimboAI 真替换、NG+ 凝视打断、结局尾声、精英名册 11 项文本错位、武器 scale 目检、P3 浮空手测。
- 既有 GUT 失败 `test_stamina_economy`（陈旧断言，只报不改）。
