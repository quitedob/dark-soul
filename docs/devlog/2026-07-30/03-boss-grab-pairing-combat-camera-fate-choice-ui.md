# 2026-07-30 — Boss Grab Pairing · Combat Camera · Fate Choice UI

### Scope

Finish the three polish items on top of Boss Execution Break: procedural grab pairing, exclusive combat camera shots, and story fate choice overlay with string `choice_flags`.

### Runtime

- `GrabPairedDirector` — socket hold, single damage event, safe cancel; enemy grab path delegates to it
- `CameraShotProfile` + `CombatCameraDirector` — weak-point expose / exec / grab / fate shots; honors `reduced_motion`
- `BossFateCatalog` + `FateChoiceOverlay` — five boss flags from chapter-bridge-map; pause modal with styled options
- `AshenRunState.set_choice_flag` accepts `String | bool`; story threshold opens fate UI and freezes boss via `enter_story_resolution`
- Contract: `ASHEN_BOSS_POLISH_CONTRACTS_OK`

### Files

| Path | Role |
|------|------|
| `game/scripts/combat/grab_paired_director.gd` | Procedural paired grab timeline |
| `game/scripts/combat/combat_camera_director.gd` | Temporary spring/pitch/look override |
| `game/scripts/combat/data/camera_shot_profile.gd` | Shot catalog (expose/exec/grab/fate) |
| `game/scripts/combat/data/boss_fate_catalog.gd` | Bridge-map fate options |
| `game/scripts/ui/fate_choice_overlay.gd` | Pause-safe fate modal |
| `game/tests/smoke/boss_polish_contract_test.gd` | Headless polish contracts |
| `tools/build.ps1` | Runs polish contract in build gate |

### Docs touched

- [systems/combat-execution-guard-weapon-arts.md](systems/combat-execution-guard-weapon-arts.md) — implementation status + gap table
- [controls.md](controls.md) — weak-point / grab / fate mention
- [tasks-master.md](tasks-master.md) — D-07 ✅, G-04 🟡 PARTIAL
- [systems/save-persistence.md](systems/save-persistence.md) — string `choice_flags`
- [systems/attack-moveset-data-schema.md](systems/attack-moveset-data-schema.md) — GrabProfile runtime complete
- [architecture.md](architecture.md) — grab/camera/fate notes
- [master-index.md](master-index.md) — chapter-choice persistence boundary
- [validation.md](validation.md) — polish + weak-point contracts

### Verify

```powershell
$Godot = "E:\godot\Godot_v4.7.1-stable_win64_console.exe"
& $Godot --headless --path game --script res://tests/smoke/boss_polish_contract_test.gd
& $Godot --headless --path game --script res://tests/smoke/boss_weakpoint_contract_test.gd
```

---
