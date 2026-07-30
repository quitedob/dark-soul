# B-01 — Per-Style Stamina Cost Differentiation

**Priority:** P0 (blocking)
**Status:** ✅ DONE
**Effort:** S (hours)
**Depends On:** None
**Blocks:** B-02, E-01
**Source:** Audit §3.2 gaps #1, #4; `research-dark-souls-weapons.md` §11

---

## Problem

All 5 combat styles currently share flat stamina costs (light=20, heavy=38) despite `STYLE_TIMING` existing in `player.gd`. This eliminates the resource-management dimension of weapon choice. A Twin Colossi heavy swing should cost nearly double a Crescent Pair light slash, forcing players to commit to their weapon's economic profile.

## Current State (verified in `player.gd`)

```gdscript
# player.gd — STYLE_TIMING dict exists but stamina values are flat
const STYLE_TIMING := {
    CombatStyle.RELIQUARY_GUARD: {
        light_stamina = 20, heavy_stamina = 38, ...
    },
    CombatStyle.TWIN_COLOSSI: {
        light_stamina = 20, heavy_stamina = 38, ...  # ← SAME VALUES
    },
    ...
}
```

## Target State

| Combat Style | Light Stamina | Heavy Stamina | Dodge Stamina | Special Stamina |
|---|---|---|---|---|
| 护卫之道 (Reliquary Guard) | 22 | 40 | 24 | 26 (Pierce Thrust) |
| 刑天斧法 (Twin Colossi) | 38 | 65 | 32 | 38 (Colossal Leap) |
| 羿弓术 (Crescent Pair) | 16 | 28 | 18 | 27 (Crescent Leap) |
| 五行术 (Veilcraft) | 14 Focus | 22 Focus | 22 stam | 20 Focus (Arcane Barrage) |
| 天祝术 (Ember Rite) | 20 Focus | 35 Focus | 24 stam | 22 Focus (Divine Smite) |

## Implementation Steps

### Step 1: Update `STYLE_TIMING` dictionary

File: `game/scripts/player/player.gd` (~line 47)

Replace existing `light_stamina` and `heavy_stamina` values with the target table above. Ensure `dodge_stamina` is also differentiated (currently shared 26 across all styles).

### Step 2: Verify stamina consumption in `_try_attack()`

File: `game/scripts/player/player.gd` — `_try_attack()` function

Confirm it reads from `STYLE_TIMING[combat_style]` rather than hardcoded constants. The devlog confirms `_style_value()` helper exists — verify it's used for stamina reads.

### Step 3: Verify stamina check before attack

```gdscript
# Guard clause pattern (should already exist):
if stamina < _style_value("light_stamina"):
    return  # insufficient stamina — no attack allowed
```

### Step 4: Update HUD stamina bar to reflect proportionally

The stamina bar is 100 units max. With Twin Colossi heavy costing 65, the bar should visibly deplete by 65%. Verify HUD rendering handles this without hardcoded assumptions.

### Step 5: Update `combat-styles.md` docs

File: `docs/systems/combat-styles.md`

Update the stamina column in each style's table to match the new values.

### Step 6: Run validation

```bash
# Script parse
godot --headless --path game --check-only

# Contract tests
godot --headless --path game --script tests/smoke/combat_contract_test.gd

# Smoke test
godot --headless --path game --quit-after 600 -- --smoke-test
```

## Acceptance Criteria

- [ ] Twin Colossi heavy attack consumes 65 stamina (not 38)
- [ ] Crescent Pair light attack consumes 16 stamina (not 20)
- [ ] Insufficient stamina correctly blocks attack execution for all 5 styles
- [ ] Stamina bar visually depletes proportionally
- [ ] `ASHEN_COMBAT_CONTRACTS_OK` passes
- [ ] `ASHEN_HOLLOW_SMOKE_OK` passes
- [ ] Manual playtest: economic pressure feels distinct between Twin Colossi and Crescent Pair

## Risk Assessment

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Players find Twin Colossi unplayable at 65 stamina | Medium | Playtest and iterate; 65 is a starting point, may tune to 55-60 |
| HUD stamina bar hardcoded to old ranges | Low | HUD reads from player.stamina/max_stamina dynamically |
| Existing smoke test assertions break | Low | Smoke test reads real values, not hardcoded expectations |
