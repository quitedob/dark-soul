# 2026-07-31 — Deferred Trio Closed（C-05 / G-05 / G-06）

### Scope

父 agent 按 `godot-builder`/`godot-director` 编排，绑定 `example/godot-ai-builder-main/skills/*`（effects / polish / enemies / gdscript）+ 项目 docs。**收口**此前 ⏸️ DEFERRED 三项。

### Waves

| Wave | Tasks | 结果 |
|------|-------|------|
| 1 | C-05 Weapon trail | ✅ 重量档 + `trail_color`；`ASHEN_WEAPON_TRAIL_CONTRACTS_OK` |
| 2 | G-05 Enemy AI tuning | ✅ Catalog + behavior 注册表；`ASHEN_ENEMY_AI_TUNING_CONTRACTS_OK` |
| 3 | G-06 Boss chapter powers | ✅ type 微执行器；九尾/玄霄/烛阴；`ASHEN_BOSS_CHAPTER_POWERS_OK` |

### Parent verify

```powershell
$Godot = "E:\godot\Godot_v4.7.1-stable_win64_console.exe"
& $Godot --headless --path game --script res://tests/smoke/weapon_trail_contract_test.gd
& $Godot --headless --path game --script res://tests/smoke/enemy_ai_tuning_contract_test.gd
& $Godot --headless --path game --script res://tests/smoke/boss_chapter_powers_contract_test.gd
```

### Docs

- `docs/tasks/c-05-weapon-trail-vfx.md` / `g-05-enemy-ai-tuning.md` / `g-06-chapter-boss-powers.md`
- `docs/systems/enemy-ai.md` — behavior 已接线
- `docs/tasks-master.md` — Deferred 清零；Done **78**

### Known follow-ups

- ~~玩家侧完整消费 `g06_time_dilation`~~ → 已在 backlog wave 落地
- Ch.2–5 精英全量补 behavior 字段（Ch.1 已补；catalog 有缺省）
- ~~G-07 / G-08~~ → 已在 backlog wave 落地

---
