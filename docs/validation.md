# Validation

Validated on **2026-07-30** using Godot 4.7.1. Project root for all `--path` arguments is `game/` (this repository: `e:/godot/darksoul/game`).

## Engine

```text
E:\godot\Godot_v4.7.1-stable_win64.exe
E:\godot\Godot_v4.7.1-stable_win64_console.exe
```

Reported version:

```text
4.7.1.stable.official.a13da4feb
```

## Automated Results

### Script parsing

Command pattern (recursive):

```bash
for script in scripts/**/*.gd; do
  "E:/godot/Godot_v4.7.1-stable_win64_console.exe" \
    --headless --path "e:/godot/darksoul/game" \
    --check-only --script "$script"
done
```

Result: `ALL_SCRIPTS_PARSE_OK` (re-run after large combat/campaign changes).

### Editor import

```bash
"E:/godot/Godot_v4.7.1-stable_win64_console.exe" \
  --headless --editor --path "e:/godot/darksoul/game" --quit
```

### Bounded runtime

```bash
"E:/godot/Godot_v4.7.1-stable_win64_console.exe" \
  --headless --path "e:/godot/darksoul/game" --quit-after 180
```

### Gameplay smoke path

```bash
"E:/godot/Godot_v4.7.1-stable_win64_console.exe" \
  --headless --path "e:/godot/darksoul/game" \
  --quit-after 600 -- --smoke-test
```

Result: `ASHEN_HOLLOW_SMOKE_OK` when the smoke path is enabled.

### Core / combat / campaign contracts

```bash
"E:/godot/Godot_v4.7.1-stable_win64_console.exe" \
  --headless --path "e:/godot/darksoul/game" \
  --script tests/smoke/core_contract_test.gd

"E:/godot/Godot_v4.7.1-stable_win64_console.exe" \
  --headless --path "e:/godot/darksoul/game" \
  --script tests/smoke/poise_contract_test.gd

"E:/godot/Godot_v4.7.1-stable_win64_console.exe" \
  --headless --path "e:/godot/darksoul/game" \
  --script tests/smoke/chapter1_slice_contract_test.gd

"E:/godot/Godot_v4.7.1-stable_win64_console.exe" \
  --headless --path "e:/godot/darksoul/game" \
  --script tests/smoke/chapter2_slice_contract_test.gd

"E:/godot/Godot_v4.7.1-stable_win64_console.exe" \
  --headless --path "e:/godot/darksoul/game" \
  --script tests/smoke/death_loop_contract_test.gd

"E:/godot/Godot_v4.7.1-stable_win64_console.exe" \
  --headless --path "e:/godot/darksoul/game" \
  --script tests/smoke/combat_contract_test.gd
```

Expected prints include `ASHEN_CORE_CONTRACTS_OK`, `ASHEN_POISE_CONTRACTS_OK`, `ASHEN_CHAPTER1_SLICE_CONTRACTS_OK`, `ASHEN_CHAPTER2_SLICE_CONTRACTS_OK`, `ASHEN_DEATH_LOOP_CONTRACTS_OK`.

I-07 death loop covers ember drop, LostEcho spawn/recover, enemy `reset_enemy`, and checkpoint respawn (smoke + GUT `tests/unit/systems/test_death_loop.gd`).

### Deferred-trio contracts (C-05 / G-05 / G-06)

```bash
"E:/godot/Godot_v4.7.1-stable_win64_console.exe" \
  --headless --path "e:/godot/darksoul/game" \
  --script tests/smoke/weapon_trail_contract_test.gd

"E:/godot/Godot_v4.7.1-stable_win64_console.exe" \
  --headless --path "e:/godot/darksoul/game" \
  --script tests/smoke/enemy_ai_tuning_contract_test.gd

"E:/godot/Godot_v4.7.1-stable_win64_console.exe" \
  --headless --path "e:/godot/darksoul/game" \
  --script tests/smoke/boss_chapter_powers_contract_test.gd
```

Expected: `ASHEN_WEAPON_TRAIL_CONTRACTS_OK`, `ASHEN_ENEMY_AI_TUNING_CONTRACTS_OK`, `ASHEN_BOSS_CHAPTER_POWERS_OK`.

### Enemy AttackData catalog (G-08)

```bash
"E:/godot/Godot_v4.7.1-stable_win64_console.exe" \
  --headless --path "e:/godot/darksoul/game" \
  --script tests/smoke/enemy_attack_catalog_contract_test.gd
```

Expected: `ASHEN_ENEMY_ATTACK_CATALOG_OK`.

### Boss weak-point / polish contracts (E-10 / D-07 / fate UI)

```bash
"E:/godot/Godot_v4.7.1-stable_win64_console.exe" \
  --headless --path "e:/godot/darksoul/game" \
  --script tests/smoke/boss_weakpoint_contract_test.gd

"E:/godot/Godot_v4.7.1-stable_win64_console.exe" \
  --headless --path "e:/godot/darksoul/game" \
  --script tests/smoke/boss_polish_contract_test.gd
```

Expected prints: `ASHEN_BOSS_WEAKPOINT_CONTRACTS_OK`, `ASHEN_BOSS_POLISH_CONTRACTS_OK`.

Also covered by `tools/build.ps1` combat contract section (guard / polish / weak-point / boss polish / lock-on).

### Combat Resource schema (A-05)

Verifies `class_name` registration for `AttackData` / `ChargeProfile` / `MovesetData` / `WeaponData` / `WeaponArtData` / `GuardProfile` / `ExecutionProfile` / `GrabProfile`, runs `validate()` on factory weapons and authored Reliquary `.tres`.

```bash
"E:/godot/Godot_v4.7.1-stable_win64_console.exe" \
  --headless --path "e:/godot/darksoul/game" \
  --script tests/smoke/combat_resource_schema_contract_test.gd
```

Expected print: `ASHEN_COMBAT_RESOURCE_SCHEMA_OK`.

Optional direct tool entry (same checks):

```bash
"E:/godot/Godot_v4.7.1-stable_win64_console.exe" \
  --headless --path "e:/godot/darksoul/game" \
  --script scripts/tools/verify_combat_resource_schema_cli.gd
```

GUT coverage lives in `tests/unit/combat/test_attack_moveset_schema.gd` (class registration + schema pipeline + authored round-trip).

### GUT unit tests

```bash
"E:/godot/Godot_v4.7.1-stable_win64_console.exe" \
  --headless --path "e:/godot/darksoul/game" \
  -s addons/gut/gut_cmdln.gd
```

Uses `.gutconfig.json` (`tests/unit/`, `tests/integration/`).

Targeted combat schema GUT:

```bash
"E:/godot/Godot_v4.7.1-stable_win64_console.exe" \
  --headless --path "e:/godot/darksoul/game" \
  -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit/combat \
  -gprefix=test_attack_moveset_schema
```

### Local CI (I-11) — full GUT + JUnit XML

Preferred entrypoint for headless CI (import + full suite + collect JUnit):

```powershell
# Windows（推荐）
.\tools\ci.ps1
# 或显式指定 Godot
.\tools\ci.ps1 -Godot "E:\godot\Godot_v4.7.1-stable_win64_console.exe"

# Linux / macOS
./tools/ci.sh --godot /path/to/Godot_v4.7.1-stable_linux.x86_64
```

- Success marker: `ASHEN_HOLLOW_CI_OK`
- JUnit XML: `build/ci/gut-results.xml` (under gitignored `build/`; retained even when GUT fails)
- Override output: `-JUnitOut` / `--junit`
- Override Godot: `-Godot` / `--godot` or env `GODOT_BIN`
- `-SkipImport` / `--skip-import` skips editor import warmup
- `-StrictImport` / `--strict-import` fails CI on import SCRIPT/Parse errors
- GitHub Actions: `.github/workflows/gut-ci.yml` (downloads Godot 4.7.1, uploads JUnit artifact)

`tools/build.ps1` delegates its GUT step to `tools/ci.ps1`.

## Manual Test Checklist

Automated headless tests cannot judge game feel. In the graphical build, verify:

- `WASD` movement follows camera orientation.
- Mouse orbit starts behind the player and the spring arm avoids walls.
- Light/heavy attacks spend different stamina amounts and hit only once per swing.
- Standing poise absorbs light hits without stagger until the reserve empties.
- Veilcraft/Ember melee spends Focus (not free stamina-zero spam).
- Hit-stop freezes the struck/striking actors briefly without global `Engine.time_scale`.
- Recovery dodge-cancel works on styles that author `dodge_cancel_seconds`.
- Dodge moves in the intended direction and avoids damage only during its central interval.
- Controller bindings work for move, attack, dodge, lock-on, and style cycle.
- `Q` or middle mouse locks to a nearby living enemy and releases on death/range.
- `E` activates and rests at the shrine; reload restores shrine respawn via `checkpoint_id`.
- Chapter 1: `level_01_01` → `01_05` encounters, arena seal, boss `守炉灵·巨阙`, victory exit to `level_02_01`.
- Chapter 2: `level_02_01` → `02_06` encounters, arena seal, boss `血将军·刑天`, victory exit to `level_03_01`; defeating both chapter bosses in the same run keeps each guardian's victory state independent (multi-boss save fix).
- Death drops embers and respawns at the shrine after the overlay.
- Touching the Lost Echo restores the dropped amount.
- Boss weak-point expose → light attack execution → story HP floor → fate modal writes `choice_flags`.
- Boss grab telegraph is dodgeable; miss recovery is punishable; capture uses GrabCapture Area3D (not CombatArea).
- Combat camera shots fire on weak-point / grab / fate without locking daily orbit permanently; reduced motion softens trauma.

### Chapter 1 Vertical Slice — Feel Gate（人工）

对照 `docs/planning/soulslike-gap-analysis.md` Phase 2：

1. 烬龛休息 → 进入 `level_01_01` → 击杀首波哨兵，确认轻击 method-track 命中窗与本地 HitStop。
2. 翻滚 i-frame 中心段无敌；Space tap=翻滚 / hold=冲刺。
3. 重击中转向明显变钝（B-12 角速度）。
4. 削满杂兵韧性进入 STAGGER / 破防可处决。
5. Boss 相变可见场地 VFX；治疗中触发 heal-punish。
6. 命运选择写入 `choice_flags`；死亡环失烬可拾回。
7. 单向捷径门/升降梯可回到烬龛（H-05）。

## Known Limitations

- Visuals and sounds are generated primitives intended to validate systems, not final production assets.
- Campaign levels beyond Chapter 2 still use placeholder encounters.
- Independent `GUARD_BROKEN` / `PARRY_VULNERABLE` / Boss weak-point / grab / fate UI are now in prototype; authored grab `.glb` pairs remain open.
- Human playtesting is still required for combat balance, telegraph clarity, camera comfort, and accessibility.
- 真蒙皮动画资产与 LimboAI 真插件仍为后续 XL 项。
