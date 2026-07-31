# 2026-07-30 — A/B/C/D Full Fix Slice

### Scope

Ship the planned A→B→C→D pass: standing poise, spell-melee Focus cost, entity HitStop freeze, dead `SPELL_CONFIG` removal, dodge-cancel wiring, Chapter 1 vertical slice closure, and docs sync.

### Combat (A/B)

- `PoiseResolver` now takes `current_poise`; standing reserve absorbs hits without requiring WAM>0
- Veilcraft/Ember melee writes `focus_cost` (10/18) and `_commit_attack` spends Focus
- HitStop freezes player/enemy state + horizontal motion; world continues; heavy uses tags/`is_heavy`
- Removed duplicate `SPELL_CONFIG` from `player.gd`; factory sets `dodge_cancel_seconds` (Twin Colossi heavy = -1)

### Chapter 1 (C)

- Encounters for `01_01`–`01_05` + elites; boss-only `01_05`
- Boss phases from `Chapter1Content.boss().phases` (phase-2 @ 0.6); HUD uses 守炉灵·巨阙
- Ch.1 module table + `arena_seal` / `switch_offering` runtime; victory exit to `level_02_01`
- Checkpoint reload restores shrine respawn via `checkpoint_id`
- Contracts: `ASHEN_POISE_CONTRACTS_OK`, `ASHEN_CHAPTER1_SLICE_CONTRACTS_OK`, `ASHEN_DEATH_LOOP_CONTRACTS_OK`

### Docs (D)

- Updated `architecture.md`, `validation.md`, `research.md` banner, `tasks-master.md`, `combat-expansion-roadmap.md`

### Resume order

1. Playtest Chapter 1 seal → boss → victory exit
2. Optional: E-02 phase WAM on windup/recovery; E-08 `GUARD_BROKEN`
3. Remaining H-04 modules for chapters 2–5

---
