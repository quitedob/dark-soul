# I-16 — Enemy FSM and Boss Phase Test Coverage

**Priority:** P2 (important)
**Status:** ✅ DONE
**Effort:** L (week)
**Completed:** 2026-07-31
**Depends On:** I-04 (stamina tests pattern), G-03 (enemy AttackData migration)
**Blocks:** None
**Source:** Code review full audit 2026-07-30 — test coverage gap analysis

---

## Problem

The player FSM has GUT tests (`test_player_fsm.gd`) but the enemy FSM has NO unit tests. The following critical enemy behaviors are untested:

1. State transitions: IDLE → CHASE → WINDUP → ACTIVE → RECOVERY → CHASE
2. Grab states: GRAB_WINDUP → GRAB_ACTIVE → GRAB_RECOVERY
3. Stagger/parry vulnerability/guard break state entry and exit
4. Boss phase transitions at HP thresholds
5. Healing-punish behavior
6. Navigation fallback when navmesh invalid
7. Death/reset/return-to-spawn contracts
8. Leash distance enforcement

## Target

Create GUT unit tests for the enemy FSM. Since enemies are `CharacterBody3D`, tests can use `auto_free(Enemy.new())` to create isolated instances:

### Basic FSM (`tests/unit/enemy/test_enemy_fsm.gd`)

```gdscript
func test_idle_transitions_to_chase_when_target_in_range() -> void:
    var enemy := auto_free(Enemy.new())
    # setup enemy with mock target in detection range
    # verify state transitions to CHASE

func test_chase_transitions_to_windup_when_in_attack_range() -> void:
    pass

func test_active_clears_hit_record_on_swing_start() -> void:
    pass

func test_recovery_returns_to_chase() -> void:
    pass

func test_stagger_interrupts_attack() -> void:
    pass

func test_parry_vulnerable_prevents_action() -> void:
    pass

func test_guard_broken_enables_critical_hit() -> void:
    pass

func test_dead_prevents_all_state_changes() -> void:
    pass

func test_return_to_spawn_when_target_out_of_leash() -> void:
    pass

func test_reset_restores_hp_and_poise() -> void:
    pass
```

### Boss phases (`tests/unit/enemy/test_boss_phases.gd`)

```gdscript
func test_phase_transition_at_hp_threshold() -> void:
    pass

func test_phase2_uses_different_attack_table() -> void:
    pass

func test_story_floor_prevents_lethal_damage() -> void:
    pass

func test_execution_break_accumulates_from_hits() -> void:
    pass

func test_healing_punish_triggers_on_player_heal() -> void:
    pass
```

## Acceptance Criteria

- [x] ≥10 enemy FSM transition tests
- [x] ≥5 boss phase/execution break tests
- [x] Tests cover all 14 enemy states
- [x] Tests cover healing-punish, leash, and reset contracts
- [x] All tests pass in GUT headless runner
- [x] Tests use `auto_free()` for proper cleanup
