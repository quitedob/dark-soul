# 施法/战技动画 + 命中盒审查修复（D-08）

> 2026-08-11 · 对施法/战技动画与命中盒的代码审查结论 + 修复归档。
> 合约：[tests/smoke/light_attack_hitbox_contract.gd](../../../game/tests/smoke/light_attack_hitbox_contract.gd)（marker `ASHEN_LIGHT_HITBOX_CONTRACTS_OK`）· 文档同步：[research/godot/actions-combat.md](../../research/godot/actions-combat.md)

---

## 审查发现（1–7 + 跃击同源 bug）

1. **[HIGH] 轻击命中盒从未开启 → 0 近战伤害**：method-track `hitbox_on`（@0.18s）在 windup（0.30s）内触发；`_should_defer_hitbox_to_anim` 把命中盒 defer 到已错过的动画事件。空中轻击（0 伤害）由同一改动修复。
2. **[HIGH→FIXED] root-motion 跃击同源死锁**：windup 0.30~0.45 > method-track `hitbox_on` @0.28s → 跃击 0 伤害。
3. **[MEDIUM] 施法/战技无身体动画**：新增程序化 Cast/Skill 姿态状态 + `travel_cast(stance)` / `travel_skill(stance)`（`player_animation_bridge.gd`，真 clip 感知、程序化回落）；player 在 CAST / GUARD_THRUST / 曲刃 LEAP 进入时调用。真身体姿态仍待资产 clip（资产阻塞）。
4. **[LOW] `stance_animation` 字段（`weapon_art_data.gd`）为死字段** → 现作为真 clip 键传给 `travel_cast` / `travel_skill`。
5. **[LOW] Boss 诱饵分身物理免疫**（裸 Node3D）→ 现为 StaticBody3D + CapsuleShape3D，仅挂 Enemies 逻辑层（raw 4），自身 mask=0。
6. **[LOW] socket-follow 命中盒只跟踪位置** → 现跟踪完整 `global_transform`（旋转 + 偏移）。
7. **[INFO] 移除死代码 `_anim_hitbox_latched` / `_anim_combo_latched`；修正 `travel_leap` 冗余三元。**

## 修复方式

退役动画 defer：轻/重/跃击一律用 **state 计时**开盒 —— `_change_state` 进入 `ATTACK_ACTIVE` / `LEAP_ACTIVE` 时调用 `_begin_melee_swing()`。method-track 触发时刻与 `AttackData` windup 是两套独立作者化、从未对齐；windup 更长时命中盒永不开启。统一 state 计时后这些时序依赖全部消除。`_should_defer_hitbox_to_anim` 恒返回 false（仅保留签名与调用点，避免其它路径假设 defer 存在）。

## 涉及文件

- `game/scripts/player/player.gd`（state 入口开盒、cast/skill 播放入口、死代码清理）
- `game/scripts/combat/player_animation_bridge.gd`（`travel_cast` / `travel_skill`）
- `game/scripts/combat/combat_area.gd`（socket-follow 跟随完整 transform）
- `game/scripts/combat/data/weapon_art_data.gd`（`stance_animation` 消费）
- `game/scripts/boss/boss_attack_clone.gd`（分身物理体）

## 新合约

`tests/smoke/light_attack_hitbox_contract.gd`（marker `ASHEN_LIGHT_HITBOX_CONTRACTS_OK`）：轻/重/跃击进入 `ATTACK_ACTIVE` / `LEAP_ACTIVE` 用 state 计时开盒（地面与空中皆然），root-motion 跃击回归断言。`docs/validation.md` 已登记该合约命令。

## 验证（父进程独立重跑）

| 项 | 结果 |
|---|---|
| 运行时 smoke | `ASHEN_HOLLOW_SMOKE_OK` |
| 新合约 `light_attack_hitbox_contract.gd` | `ASHEN_LIGHT_HITBOX_CONTRACTS_OK` |
| GUT | 96 测 95 过 1 挂（唯一失败 = 既有 `test_stamina_economy` 数据漂移，只报不改） |

---

## 遗留 / 范围外（记录不改）

- **真 cast/skill 资产 clip**：施法/战技身体姿态仍资产阻塞（asset-blocked），程序化姿态为当前兜底。
- **跃击 lunges windup 调优**：leap lunge 在 windup 期间的节奏待手感调优。
- **分身 / socket 运行时测试**：clone 物理接触合约与 socket-follow 旋转合约测试正在补充。
- **已知债不变**：`test_stamina_economy` 数据漂移由独立 Worker 另行协调；LimboAI 真替换、精英名册 11 项文本错位等未涉及。

## 结论

一次审查同时暴露并修复了「轻击 0 伤害」与「root-motion 跃击 0 伤害」两个同源死锁：以 state 计时取代动画轨 defer 作为命中窗口权威，命中盒时序不再依赖动画事件。
