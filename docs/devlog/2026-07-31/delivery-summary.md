# 2026-07-31 — Delivery Summary

> 原 CHANGELOG 波次摘要，已统一并入 devlog。细节见同日其他条目。

### Soulslike Gap 纠偏 + Phase 1–3 竖切

- 权威缺口文档：`docs/planning/soulslike-gap-analysis.md`
- Phase 1：method-track 轻击/跃击 hitbox；B-12 角速度；敌人 `PoiseResolver` + 相位 WAM；D-02 root motion 物理接入
- Phase 2：dagger/fist GuardProfile；哨兵 AttackData `.tres`；Ch.1 heal-punish；相变 VFX 色键；H-05 / I-16 / A-07
- Phase 3：`QuestState` / `DialogueRunner` / `EndingResolver` + 烬龛云游对话竖切；`story_runtime_contract_test`
- Ch.2 遭遇接入 + 多 Boss `defeated_bosses` 存档修复（`chapter2_slice_contract_test`）

### Audit Backlog Wave

| 簇 | IDs | 交付 |
|----|-----|------|
| 资源正确性 | K-01 / K-02 / G-07 | 原子扣费、防双初始化、命中载荷路由 |
| 手感 | B-09…B-12 | 多槽队列、tap/hold 闪避冲刺、下落重力+snap、分状态加速度 |
| 抛光 | C-06 / E-11 / F-06 / I-14 / K-03 / K-04 | Music 总线、guard setter、镜头回跟、HUD tween 清理、关卡断锁、cue 警告 |
| 战斗中项 | D-08 / G-08 | 动画回调钩子、EnemyAttackCatalog |
| 测试 | I-12 / I-13 / I-15 / I-16 | FSM 边沿、focus/guard、求解器、敌 FSM 覆盖 |

### Deferred Trio Closed

- **C-05** 武器拖尾按攻击重量档着色
- **G-05** `EnemyAiCatalog` + behavior 注册表
- **G-06** 九尾/玄霄/烛阴章节权能微执行器

---
