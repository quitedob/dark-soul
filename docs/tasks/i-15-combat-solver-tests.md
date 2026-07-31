# I-15 — Combat Solver Standalone Tests (Poise, Execution, Lock-On)

**Priority:** P2 (important)
**Status:** ✅ DONE
**Effort:** M (days)
**Depends On:** I-04 (stamina tests pattern)
**Blocks:** None
**Source:** Code review full audit 2026-07-30 — test coverage gap analysis

---

## Problem

The codebase has three RefCounted solver classes with no standalone unit tests:

1. **PoiseResolver** — continuous poise with action armor, break thresholds, reset delay
2. **ExecutionSolver** — backstab/riposte candidate finding, execution eligibility
3. **LockOnSolver** — target scoring, directional cycling, break distance

These are pure-logic classes (no scene tree dependency) and should be fully testable in GUT. The lack of tests means regression risk when tuning poise thresholds, execution conditions, or lock-on scoring.

## Target

Create GUT unit tests for each solver:

### PoiseResolver tests (`tests/unit/combat/test_poise_resolver.gd`)

```gdscript
func test_poise_holds_under_light_hit() -> void:
    # 30 base poise + 0.3 action armor vs 10 poise damage → should hold

func test_poise_breaks_from_chain() -> void:
    # 3 consecutive hits of 15 poise damage vs 30 base → should break on 3rd

func test_poise_resets_after_delay() -> void:
    # After 1.6s without damage, poise returns to full

func test_armor_reduction_reduces_effective_damage() -> void:
    # 0.3 armor reduction on 20 poise damage → 14 effective

func test_zero_action_armor_during_recovery() -> void:
    # Recovery phase has no action armor bonus
```

### ExecutionSolver tests (`tests/unit/combat/test_execution_solver.gd`)

```gdscript
func test_backstab_eligible_from_rear_sector() -> void:
    # Target facing away, attacker behind → eligible

func test_backstab_ineligible_from_front() -> void:
    # Target facing attacker → not eligible

func test_riposte_eligible_during_parry_vulnerable() -> void:
    # Target in PARRY_VULNERABLE state → front riposte candidate

func test_guard_broken_eligible_for_critical() -> void:
    # Target in GUARD_BROKEN → execution candidate
```

### LockOnSolver tests (`tests/unit/combat/test_lock_on_solver.gd`)

```gdscript
func test_closest_to_camera_wins() -> void:
    # Two targets, one more centered on screen → that one wins

func test_cycle_left_selects_next_counterclockwise() -> void:
    # Directional cycling picks correct next target

func test_break_distance_releases_lock() -> void:
    # Target beyond max distance → lock releases

func test_dead_target_not_scored() -> void:
    # Dead enemies excluded from lock-on candidates
```

## Acceptance Criteria

- [ ] PoiseResolver has ≥5 tests covering hold, break, reset, armor reduction, recovery
- [ ] ExecutionSolver has ≥4 tests covering backstab, riposte, guard break, fail cases
- [ ] LockOnSolver has ≥4 tests covering scoring, cycling, break, exclusion
- [ ] All tests pass in GUT headless runner
- [ ] Tests run in <1 second (pure logic, no scene tree)
