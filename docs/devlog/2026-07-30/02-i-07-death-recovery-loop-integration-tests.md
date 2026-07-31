# 2026-07-30 — I-07 Death/Recovery Loop Integration Tests

### Scope

Complete death-loop coverage: ember drop, LostEcho spawn/recover, enemy reset, checkpoint respawn (smoke + GUT).

### Tests

- Smoke: `tests/smoke/death_loop_contract_test.gd` → `ASHEN_DEATH_LOOP_CONTRACTS_OK`
- GUT: `tests/unit/systems/test_death_loop.gd` (6 cases)

### Verify

```bash
"E:/godot/Godot_v4.7.1-stable_win64_console.exe" --headless --path "e:/godot/darksoul/game" --script tests/smoke/death_loop_contract_test.gd
"E:/godot/Godot_v4.7.1-stable_win64_console.exe" --headless --path "e:/godot/darksoul/game" -s addons/gut/gut_cmdln.gd "-gdir=res://tests/unit/systems/" "-gprefix=test_death_loop" -gexit
```

---
