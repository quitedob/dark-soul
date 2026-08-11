# 风险修复：玄霄逃出解封 + 动画 clip 管线

> 2026-08-11 · 依据 [03-all-gaps-fix-orchestration-reflection.md](03-all-gaps-fix-orchestration-reflection.md) 的独立验证结论。
> 设计 spec：[planning/2026-08-11-risk-fixes-design.md](../../planning/2026-08-11-risk-fixes-design.md) · 计划：[planning/2026-08-11-risk-fixes-plan.md](../../planning/2026-08-11-risk-fixes-plan.md)
> 执行：subagent-driven（Task 1/2/3/4 每任务独立实现子代理 + spec/quality 双审；Task 5 验证父进程独立重跑）。

---

## 修复的两个风险

### R1 — 玄霄 90s 逃出软锁（真实风险，阻断游玩路径）
- **根因**：`xuanxiao_escape_flow.gd::_trigger_escape` 冻结并移除 Boss 但不发 `defeated`；`game_world._on_enemy_defeated` 只在 `defeated` 分支解封竞技场 + 生成出口。玩家 90s 未击杀 → 封场墙保持 + 无出口 → 被困崩塌竞技场。
- **修复**：
  - `game_world.gd` 新增 `on_boss_escaped()`（复用 `_open_boss_victory_exit()`：解封 + 出口 + 文案，幂等）。
  - `xuanxiao_escape_flow.gd::_trigger_escape` 在 `_mark_escape_result()` 后调用 `_unseal_arena()`（`has_method` 守卫）。
  - 逃出 ≠ 击杀：无 `defeated`、无胜利结算/战利品、不写 `defeated_bosses`、不触发 `ch4_xuanxiao_fate`；`ch4_xuanxiao_escaped` 照常落盘供后续章节分支。
- **合约**：新增 `xuanxiao_escape_contract.gd`（通知恰好一次 + 旗标落盘 + 幂等），marker `ASHEN_XUANXIAO_ESCAPE_CONTRACTS_OK`。

### R2 — 真动画 clip 永不驱动（管线 bug，非阻断）
- **根因**：
  1. `player_animation_bridge.gd::REAL_IDLE_FALLBACK` 用点号名 `mixamo.com`，但 Godot GLB 导入把 clip 名消毒为 `mixamo_com`（下划线）→ 常量**永久死**。
  2. `has_real_animations()` 只要"库非空 + 层激活"就返回 true，即使没有状态真正用真 clip（误导 API）。
  3. 唯一现成 clip（mannyquin）是 1 帧 3 轨绑位姿，非 locomotion；若名字修对后让它接管 idle 会冻结玩家为 A-pose。
- **修复**（全部在 `player_animation_bridge.gd`）：
  - `REAL_IDLE_FALLBACK` 改为下划线导入名。
  - 新增 `MIN_FALLBACK_TRACKS := 4` / `MIN_FALLBACK_LENGTH := 0.1`：绑位兜底只在该 clip 有实质内容时才接管 idle（3 轨 0.04s 绑位姿被守卫，保持程序化 idle；精确同名状态键不受影响）。
  - `has_real_animations()` 诚实化：至少一个状态（10 个状态键）实际解析到真 clip 才返回 true。
  - `export_mannyquin_animations.gd` 注释说明 `.`→`_` 消毒 + 守卫。
- **合约**：`player_animation_real_contract.gd` 新增第 4 用例 `_test_mannyquin_bind_pose_guarded()`（用真实 `mannyquin_lib.tres` 验证：名字已对齐、绑位姿被守卫、`has_real_animations` 为 false、Idle 保持 `combat/idle`）。

---

## 验证（父进程独立重跑）

| 项 | 结果 |
|---|---|
| 编辑器导入（全部脚本 + 资源） | EXIT 0，无 SCRIPT ERROR / Parse Error |
| 新合约 `xuanxiao_escape_contract.gd` | `ASHEN_XUANXIAO_ESCAPE_CONTRACTS_OK` |
| 改合约 `player_animation_real_contract.gd` | `PLAYER_ANIMATION_REAL_CONTRACTS_OK` |
| 全量 smoke 39 合约回归扫描 | 39/39 全过 |
| GUT | 96 测 95 过 1 挂（唯一失败 = 既有 `test_stamina_economy` 陈旧断言，只报不改） |
| 运行时 smoke | `ASHEN_HOLLOW_SMOKE_OK` |
| git 噪音 | `mannyquin_lib.tres` 未被重写，无残留 tmp 文件 |

**提交**：`66caec2`（design spec）→ `bc661b3`（R1 修复 + 合约）→ `ce2589c`（R2 修复 + 合约扩展）。

---

## 遗留 / 范围外（记录不改）

- **真 locomotion 动画资产生产**（`example/Godot4-OpenAnimationLibraries/Libraries/Humanoid/*.res` → 玩家骨架重定向）——route-B 后续任务；管线已修好，真 clip 命名用状态键（idle/walk/...）即精确匹配。
- **潜在边缘**（code review 记录，非本次范围）：`_real_clip_for` 按源库解析但 `_ingest_real_library` 会剔除 0 轨 clip —— 未来某"精确同名状态键但骨骼全被剔除"的作者化 clip 会让 `_clip_path` 引用不存在的 `real/<clip>`。建议后续改为按注入后库校验。
- **已知债不变**：LimboAI 真替换、NG+ 凝视打断、结局尾声、精英名册 11 项文本错位、武器 scale 目检、P3 浮空手测。
