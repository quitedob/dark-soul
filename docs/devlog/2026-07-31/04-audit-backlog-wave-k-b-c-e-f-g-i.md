# 2026-07-31 — Audit Backlog Wave（K/B/C/E/F/G/I 收口）

### Scope

从 `docs/tasks-master` + 审计扩表 backlog 批量实装可落地项；学习 `example/` 的 Action Queue / dodge-sprint / camera recenter 模式。禁止全局 `Engine.time_scale`。

### Delivered

| 簇 | IDs | 要点 |
|----|-----|------|
| 资源正确性 | K-01 / K-02 / G-07 | 原子扣费、防双初始化、去掉硬编码 execution_break |
| 手感 | B-09 / B-10 / B-11 / B-12 | 多槽队列、tap/hold、下落重力、状态加速度 |
| 抛光 | C-06 / E-11 / F-06 / I-14 / K-03 / K-04 | Music 总线、guard setter、镜头回跟、tween 清理、关卡锁、cue 警告 |
| 战斗中项 | D-08 / G-08 | 动画回调钩子、EnemyAttackCatalog |
| 测试 | I-12 / I-13 / I-15 | FSM 边沿、focus/guard、三求解器单测 |
| 故事钩子 | G-06 消费 | 玩家读取 `g06_time_dilation`（移速/回复/动画） |

### Parent verify

```powershell
$Godot = "E:\godot\Godot_v4.7.1-stable_win64_console.exe"
& $Godot --headless --path game --script res://tests/smoke/weapon_trail_contract_test.gd
& $Godot --headless --path game --script res://tests/smoke/enemy_ai_tuning_contract_test.gd
& $Godot --headless --path game --script res://tests/smoke/boss_chapter_powers_contract_test.gd
& $Godot --headless --path game --script res://tests/smoke/enemy_attack_catalog_contract_test.gd
```

### Still open（多会话 XL）

- I-16 全敌 FSM 覆盖
- 真动画资产 / LimboAI 真插件 / Ch.2–5 补篇全可玩重做
- A-07、D-02/D-05、H-05 等原表 Pending

---
