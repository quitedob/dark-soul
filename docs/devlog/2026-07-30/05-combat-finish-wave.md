# 2026-07-30 — Combat Finish Wave 3→2→1

### Scope

Closed the planned combat gap pack: humanoid Guard Meter / executions, polish (cancel / weapon arts / charge HUD / Reliquary `.tres`), and straight-sword AnimationTree root-motion POC.

### Wave 3 — Guard & Executions

- `GuardResolver` meter + direct break + stamina break reasons
- Player `GUARD_BROKEN` + `guard_meter`; enemy `PARRY_VULNERABLE` / `GUARD_BROKEN` + exclusive claim
- `ExecutionProfile` + `ExecutionSolver`; riposte / backstab with event-point damage
- Contract: `ASHEN_GUARD_EXECUTION_CONTRACTS_OK`

### Wave 2 — Details

- Twin zero dodge-cancel; Crescent wide cancel window
- Five styles `WeaponArtData` on `WeaponData.default_weapon_art`
- Charge progress HUD bar; Reliquary authored `resources/weapons|movesets`
- Contract: `ASHEN_COMBAT_POLISH_CONTRACTS_OK`

### Wave 1 — Animation POC

- `PlayerAnimationBridge`: placeholder Skeleton + AnimationTree (Physics callback)
- Light attack prefers `get_root_motion_position()`, falls back to `authored_displacement`
- Placeholder bones ≠ final art pipeline

---
