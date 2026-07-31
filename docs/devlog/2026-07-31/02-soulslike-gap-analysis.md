# 2026-07-31 — Soulslike Gap Analysis 纠偏

### Scope

对照外部「类魂全景审查稿」与仓库实况：纠正已过时的手感债务判断，固化权威缺口文档与三期演进路线；并落地 Phase 1–3 最小实现。

### Delivered

- 权威缺口文档：`docs/planning/soulslike-gap-analysis.md`
- 纠错要点：B-09 多槽队列 / B-10 tap-hold / B-11 下落重力+snap / C-01 本地 HitStop / E-08 脆弱态 **均已落地**，不可再当开放债
- **Phase 1：** method-track 接管轻击/跃击 hitbox；B-12 角速度；敌人 `PoiseResolver` + 相位 WAM；D-02 root motion 物理接入
- **Phase 2：** dagger/fist GuardProfile；哨兵 AttackData `.tres`；Ch.1 heal-punish 覆盖；相变 VFX 色键；H-05/I-16/A-07 收口；Ch.1 Feel Gate 清单
- **Phase 3：** `QuestState` / `DialogueRunner` / `EndingResolver` + 烬龛云游对话竖切；`story_runtime_contract_test`
- 明确排除：RAM/EAC 逆向、ds3os 联机、Markov 替代 DialogueRunner、Unity clone 照搬

### Parent verify

```powershell
$Godot = "E:\godot\Godot_v4.7.1-stable_win64_console.exe"
& $Godot --headless --path game --script res://tests/smoke/story_runtime_contract_test.gd
& $Godot --headless --path game --script res://tests/smoke/enemy_attack_catalog_contract_test.gd
& $Godot --headless --path game --script res://tests/smoke/poise_contract_test.gd
```

### Still open

真蒙皮资产、LimboAI 真插件、Ch.2–5 全可玩重做、跨章 NPC 迁移与隐藏结局全证物内容填充。

---
