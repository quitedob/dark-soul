# I-03 — Player FSM State Transition Validity Tests

**Priority:** P0 (blocking)
**Status:** ✅ DONE
**Effort:** M (days)
**Depends On:** I-01 (GUT deploy)
**Blocks:** None
**Source:** Audit document §9; `validation.md`

---

## Problem

The 12-state player FSM has zero automated tests. Illegal state transitions (e.g., DEAD → LOCOMOTION without respawn) can be introduced by any code change touching state management. The FSM is the backbone of all combat interactions — a single regression here breaks the entire game.

## Current Player States

```gdscript
enum State {
    LOCOMOTION,
    ATTACK_WINDUP, ATTACK_ACTIVE, ATTACK_RECOVERY,
    DODGE,
    PARRY,
    GUARD, GUARD_THRUST,
    LEAP_WINDUP, LEAP_ACTIVE,
    CAST,
    STAGGER,
    DEAD
}
```

## Legal Transition Matrix

| From ↓ / To → | LOCO | A_WUP | A_ACT | A_REC | DODGE | PARRY | GUARD | G_THR | L_WUP | L_ACT | CAST | STAG | DEAD |
|---------------|------|-------|-------|-------|-------|-------|-------|-------|-------|-------|------|------|------|
| LOCOMOTION    | —    | ✅    | ❌    | ❌    | ✅    | ✅    | ✅    | ✅    | ✅    | ❌    | ✅   | ❌   | ❌   |
| A_WINDUP      | ❌   | ❌    | ✅    | ❌    | ❌    | ❌    | ❌    | ❌    | ❌    | ❌    | ❌   | ❌   | ❌   |
| A_ACTIVE      | ❌   | ❌    | ❌    | ✅    | ❌    | ❌    | ❌    | ❌    | ❌    | ❌    | ❌   | ❌   | ❌   |
| A_RECOVERY    | ✅   | ❌    | ❌    | ❌    | ❌    | ❌    | ❌    | ❌    | ❌    | ❌    | ❌   | ❌   | ❌   |
| DODGE         | ✅   | ❌    | ❌    | ❌    | ❌    | ❌    | ❌    | ❌    | ❌    | ❌    | ❌   | ❌   | ❌   |
| PARRY         | ✅   | ❌    | ❌    | ❌    | ❌    | ❌    | ❌    | ❌    | ❌    | ❌    | ❌   | ❌   | ❌   |
| GUARD         | ✅   | ❌    | ❌    | ❌    | ❌    | ❌    | ❌    | ✅    | ❌    | ❌    | ❌   | ❌   | ❌   |
| G_THRUST      | ✅   | ❌    | ❌    | ❌    | ❌    | ❌    | ❌    | ❌    | ❌    | ❌    | ❌   | ❌   | ❌   |
| L_WINDUP      | ❌   | ❌    | ❌    | ❌    | ❌    | ❌    | ❌    | ❌    | ❌    | ✅    | ❌   | ❌   | ❌   |
| L_ACTIVE      | ❌   | ❌    | ❌    | ❌    | ❌    | ❌    | ❌    | ❌    | ❌    | ❌    | ❌   | ❌   | ❌   |
| CAST          | ✅   | ❌    | ❌    | ❌    | ❌    | ❌    | ❌    | ❌    | ❌    | ❌    | ❌   | ❌   | ❌   |
| STAGGER       | ✅   | ❌    | ❌    | ❌    | ❌    | ❌    | ❌    | ❌    | ❌    | ❌    | ❌   | ❌   | ✅   |
| DEAD          | ❌   | ❌    | ❌    | ❌    | ❌    | ❌    | ❌    | ❌    | ❌    | ❌    | ❌   | ❌   | ❌   |

**Key invariants:**
- DEAD accepts NO input — cannot transition out without respawn (world-level, not FSM-level)
- STAGGER → DEAD is the only path to death (any damageable state → STAGGER → DEAD is valid)
- ATTACK states form a strict chain: WINDUP → ACTIVE → RECOVERY → LOCOMOTION (no shortcuts)
- No state can transition directly to DEAD except STAGGER

## Test Cases

### File: `game/tests/unit/state_machines/test_player_fsm.gd`

```gdscript
extends GutTest

var _player: CharacterBody3D
var _simulator: PlayerStateSimulator  # helper class

func before_each() -> void:
    _player = auto_free(CharacterBody3D.new())
    _player.set_script(load("res://scripts/player/player.gd"))
    _player._ready()  # Initialize state machine
    _simulator = PlayerStateSimulator.new(_player)

# --- State Transition Legality ---

func test_attack_chain_is_strict() -> void:
    # WINDUP → ACTIVE (legal)
    _simulator.force_state(State.ATTACK_WINDUP)
    _player._change_state(State.ATTACK_ACTIVE)
    assert_eq(_player.state, State.ATTACK_ACTIVE, "WINDUP → ACTIVE should be legal")
    
    # ACTIVE → RECOVERY (legal)
    _player._change_state(State.ATTACK_RECOVERY)
    assert_eq(_player.state, State.ATTACK_RECOVERY, "ACTIVE → RECOVERY should be legal")
    
    # RECOVERY → LOCOMOTION (legal)
    _player._change_state(State.LOCOMOTION)
    assert_eq(_player.state, State.LOCOMOTION, "RECOVERY → LOCOMOTION should be legal")

func test_cannot_skip_attack_phases() -> void:
    # WINDUP → RECOVERY (illegal — must go through ACTIVE)
    _simulator.force_state(State.ATTACK_WINDUP)
    _player._change_state(State.ATTACK_RECOVERY)
    assert_ne(_player.state, State.ATTACK_RECOVERY, "WINDUP → RECOVERY should be illegal")
    
    # ACTIVE → LOCOMOTION (illegal — must go through RECOVERY)
    _simulator.force_state(State.ATTACK_ACTIVE)
    _player._change_state(State.LOCOMOTION)
    assert_ne(_player.state, State.LOCOMOTION, "ACTIVE → LOCOMOTION should be illegal")

func test_dead_accepts_no_input() -> void:
    # Dead player can't attack
    _simulator.force_state(State.DEAD)
    _player._change_state(State.ATTACK_WINDUP)
    assert_eq(_player.state, State.DEAD, "DEAD → ATTACK_WINDUP should be rejected")
    
    # Dead player can't dodge
    _player._change_state(State.DODGE)
    assert_eq(_player.state, State.DEAD, "DEAD → DODGE should be rejected")
    
    # Dead player can't parry
    _player._change_state(State.PARRY)
    assert_eq(_player.state, State.DEAD, "DEAD → PARRY should be rejected")
    
    # Dead player can't guard
    _player._change_state(State.GUARD)
    assert_eq(_player.state, State.DEAD, "DEAD → GUARD should be rejected")
    
    # Dead player can't cast
    _player._change_state(State.CAST)
    assert_eq(_player.state, State.DEAD, "DEAD → CAST should be rejected")
    
    # Dead player can't go directly to LOCOMOTION
    _player._change_state(State.LOCOMOTION)
    assert_eq(_player.state, State.DEAD, "DEAD → LOCOMOTION should be rejected (respawn is world-level)")

func test_stagger_to_dead_path() -> void:
    # Only STAGGER can transition to DEAD
    _simulator.force_state(State.STAGGER)
    _player._change_state(State.DEAD)
    assert_eq(_player.state, State.DEAD, "STAGGER → DEAD should be legal")

func test_stagger_to_locomotion_recovery() -> void:
    _simulator.force_state(State.STAGGER)
    _player._change_state(State.LOCOMOTION)
    assert_eq(_player.state, State.LOCOMOTION, "STAGGER → LOCOMOTION should be legal (stagger recovery)")

func test_dodge_to_locomotion_completion() -> void:
    _simulator.force_state(State.DODGE)
    # Simulate dodge timer completion
    _simulator.simulate_dodge_complete()
    assert_eq(_player.state, State.LOCOMOTION, "DODGE should return to LOCOMOTION on completion")

func test_parry_to_locomotion_completion() -> void:
    _simulator.force_state(State.PARRY)
    _simulator.simulate_parry_complete()
    assert_eq(_player.state, State.LOCOMOTION, "PARRY should return to LOCOMOTION on completion")

# --- Input Buffering Tests ---

func test_input_buffer_stores_during_recovery() -> void:
    _simulator.force_state(State.ATTACK_RECOVERY)
    _simulator.press_action("dodge")
    assert_true(_player._buffered_action != "", "Dodge should be buffered during recovery")

func test_input_buffer_executes_on_locomotion() -> void:
    _simulator.force_state(State.ATTACK_RECOVERY)
    _simulator.press_action("dodge")
    _player._change_state(State.LOCOMOTION)  # Recovery completes
    # Buffer should execute dodge
    assert_eq(_player.state, State.DODGE, "Buffered dodge should execute on entering LOCOMOTION")

func test_input_buffer_decays_after_window() -> void:
    _simulator.force_state(State.ATTACK_RECOVERY)
    _simulator.press_action("dodge")
    _simulator.advance_buffer_timer(0.16)  # 160ms > 150ms window
    _player._change_state(State.LOCOMOTION)
    assert_ne(_player.state, State.DODGE, "Buffered action should decay after 150ms window")

# --- Hyper Armor / Poise Tests ---

func test_hyper_armor_prevents_stagger() -> void:
    _simulator.force_state(State.ATTACK_ACTIVE)
    _player._wam_active = 0.35  # Twin Colossi heavy
    _player.base_poise_health = 100.0
    _player.armor_pdr = 0.15
    
    _player.receive_hit_payload({
        damage = 30, stagger = 40, poise_damage = 35,
        direction = Vector3.BACK, source = "test_enemy"
    })
    
    assert_eq(_player.state, State.ATTACK_ACTIVE, "Hyper armor should prevent stagger during active frames")
    assert_lt(_player.health, _player.max_health, "HP damage should apply even with hyper armor")

func test_no_hyper_armor_outside_active_frames() -> void:
    _simulator.force_state(State.LOCOMOTION)
    _player._wam_active = 0.0  # Not attacking
    
    var state_before := _player.state
    _player.receive_hit_payload({
        damage = 30, stagger = 40, poise_damage = 35,
        direction = Vector3.BACK, source = "test_enemy"
    })
    
    assert_eq(_player.state, State.STAGGER, "No hyper armor outside active frames — should stagger")

# --- Guard State Tests ---

func test_guard_auto_cancels_on_state_change() -> void:
    _simulator.force_state(State.GUARD)
    assert_true(_player.guard_active, "Guard should be active in GUARD state")
    
    _player._change_state(State.ATTACK_WINDUP)
    assert_false(_player.guard_active, "Guard should cancel when leaving GUARD state")
```

## Helper: PlayerStateSimulator

```gdscript
# game/tests/unit/helpers/player_state_simulator.gd
class_name PlayerStateSimulator
extends RefCounted

var _player: CharacterBody3D

func _init(player: CharacterBody3D) -> void:
    _player = player

func force_state(state: int) -> void:
    """Directly set player state bypassing transition checks (for test setup)"""
    _player.state = state

func press_action(action: String) -> void:
    """Simulate player input action"""
    _player._try_buffer_action(action)

func simulate_dodge_complete() -> void:
    """Simulate dodge i-frame timer expiration"""
    _player._dodge_timer = 0
    _player._update_state(0.016)  # Simulate one physics frame

func simulate_parry_complete() -> void:
    """Simulate parry window expiration"""
    _player._parry_timer = 0
    _player._update_state(0.016)

func advance_buffer_timer(seconds: float) -> void:
    """Advance the input buffer decay timer"""
    _player._buffer_timer -= seconds
```

## Acceptance Criteria

- [ ] All 12+ test cases pass
- [ ] No illegal state transitions are possible
- [ ] DEAD state rejects ALL input (6+ action types verified)
- [ ] ATTACK chain is strictly WINDUP → ACTIVE → RECOVERY → LOCOMOTION
- [ ] Input buffer stores during recovery, executes on locomotion, decays at 150ms
- [ ] Hyper armor prevents stagger only during ATTACK_ACTIVE/LEAP_ACTIVE with active WAM
- [ ] Guard auto-cancels on leaving GUARD state
- [ ] Tests run headless: `godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/state_machines/ -gexit`

## Risk Assessment

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| `_player._ready()` requires tree/scene context | Medium | Use `auto_free()` and add to test scene tree; mock world reference |
| Private method access (`_try_buffer_action`) | Low | GUT allows calling "private" methods for testing; GDScript has no true private |
| State enum values change during refactoring | Low | Use `State.LOCOMOTION` enum references, not magic numbers |
