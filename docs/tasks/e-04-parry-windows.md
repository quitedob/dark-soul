# E-04 — Parry Window Differentiation by Shield Type

**Priority:** P2 (high)
**Status:** ✅ DONE
**Effort:** M (days)
**Depends On:** None
**Blocks:** None
**Source:** Audit document §5 "精力、韧性与防反机制的系统重塑"; `research-dark-souls-mechanics-deep.md` §3.3

---

## Problem

The Reliquary Guard parry has a uniform active window (0.06s–0.26s) regardless of shield type. In the DS-series, parry windows vary dramatically by tool:

| Item | Startup (frames @ 30fps) | Active Window | Recovery Penalty |
|------|--------------------------|---------------|------------------|
| Fist / Bare Hands | 8 frames | 8 frames | Medium |
| Buckler / Small Shield | 8 frames | 10 frames | Heavy |
| Small Shield | 12 frames | 12 frames | Medium |
| Medium Shield | 14 frames | ~6 frames | Very Heavy |
| Weapon Parry (dagger) | 10 frames | 8 frames | Light |

This differentiation creates meaningful equipment choices:
- **Buckler:** Highest parry success rate but catastrophic miss penalty (long recovery)
- **Medium Shield:** Can block AND parry, but parry window is tiny — requires prediction
- **Fist:** Fastest startup, balanced window — high skill ceiling

## Current State

```gdscript
# player.gd — STYLE_TIMING[RELIQUARY_GUARD]
"parry_window_start": 0.06,  # All shields share this
"parry_window_end": 0.26,    # All shields share this
```

Parry window is read from the left-hand equipment profile (`hand_equipment.gd`), which means the infrastructure for per-item parry windows already exists — it's just not differentiated.

## Implementation

### Step 1: Add parry profiles to equipment definitions

File: `game/scripts/data/hand_equipment.gd`

```gdscript
# Add to each shield item's definition:
const PARRY_PROFILES := {
    "reliquary_shield": {
        "parry_startup": 0.40,     # 12 frames @ 30fps
        "parry_active": 0.40,      # 12 frames active window
        "parry_recovery": 0.60,    # Long miss recovery
        "parry_miss_penalty": 1.5, # Multiplier on recovery if whiffed
    },
    "buckler": {                   # Future: add buckler as separate item
        "parry_startup": 0.266,    # 8 frames
        "parry_active": 0.333,     # 10 frames — generous
        "parry_recovery": 0.80,    # Catastrophic miss penalty
        "parry_miss_penalty": 2.0,
    },
    "parry_dagger": {              # Future: Crescent Pair off-hand
        "parry_startup": 0.333,    # 10 frames
        "parry_active": 0.266,     # 8 frames
        "parry_recovery": 0.40,    # Quick recovery
        "parry_miss_penalty": 1.0,
    },
    "fists": {                     # Bare hands / no shield
        "parry_startup": 0.266,    # 8 frames — fastest
        "parry_active": 0.266,     # 8 frames
        "parry_recovery": 0.50,
        "parry_miss_penalty": 1.2,
    },
}
```

### Step 2: Read parry profile in `_try_parry()`

File: `game/scripts/player/player.gd`

```gdscript
func _try_parry() -> void:
    # ... existing guard checks ...
    
    var left_item := get_left_hand_item()
    var parry_profile := HandEquipment.get_parry_profile(left_item.item_id)
    
    # Use profile values instead of STYLE_TIMING constants
    _parry_window_start = parry_profile.parry_startup
    _parry_window_duration = parry_profile.parry_active
    _parry_recovery = parry_profile.parry_recovery
    
    state = State.PARRY
    _parry_timer = _parry_window_start
    _parry_active = false  # activates after startup

func _is_parry_active() -> bool:
    return state == State.PARRY and _parry_active

func _on_parry_miss() -> void:
    # Apply miss penalty
    var left_item := get_left_hand_item()
    var profile := HandEquipment.get_parry_profile(left_item.item_id)
    _parry_miss_stagger_duration = profile.parry_recovery * profile.parry_miss_penalty
    # Force longer stagger on whiff
```

### Step 3: Visual differentiation

- **Buckler parry:** Wider spark VFX, longer active flash
- **Medium shield parry:** Narrow spark, brief flash
- **Fist parry:** Minimal VFX, quick motion

### Step 4: Future equipment additions

This infrastructure supports adding new shield types in future chapters:
- Chapter 3: Jade Buckler (wide window, light weight)
- Chapter 4: Celestial Guard Shield (medium window, spell parry)
- Chapter 5: Void Aegis (narrow window, parries projectiles)

## Acceptance Criteria

- [ ] Different shield types have measurably different parry windows
- [ ] Buckler active window is ~1.67× wider than medium shield
- [ ] Parry miss penalty is noticeably harsher on buckler vs fist
- [ ] Parry profile is read from equipment data, not hardcoded in player.gd
- [ ] HUD/audio feedback differentiates parry success based on tool used
- [ ] `ASHEN_COMBAT_CONTRACTS_OK` passes with updated parry profiles

## Risk Assessment

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Only 1 shield type currently implemented | High | Implement differentiated profiles now; future shield types benefit immediately |
| Parry windows feel unfair to players | Medium | Visual feedback (spark VFX size) communicates window width; tutorial explains |
