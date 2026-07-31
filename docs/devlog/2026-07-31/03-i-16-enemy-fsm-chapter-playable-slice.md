# 2026-07-31 — I-16 Enemy FSM + Chapter 2 Playable Slice

### Scope

- **I-16**：敌人 FSM ≥14 测 + Boss 相 ≥5 测（GUT `state_machines/`）
- **Ch.2**：`game_world` 接入 `Chapter2Content` 遭遇（`02_01`–`02_06` 刑天）；多 Boss `defeated_bosses` 存档修复
- Smoke：`ASHEN_CHAPTER2_SLICE_CONTRACTS_OK`

### Verify

```powershell
$Godot = "E:\godot\Godot_v4.7.1-stable_win64_console.exe"
& $Godot --headless --path game -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit/state_machines -gexit
& $Godot --headless --path game --script res://tests/smoke/chapter2_slice_contract_test.gd
```

### Follow-ups

- Ch.2 文档支线（锻造/战旗谜题）仍为设计超标，未进 MVP
- Boss 抓投 `_begin_grab_telegraph` monitoring 时序噪音可单开修
- Ch.3–5 遭遇工厂接线同模式扩展

---
