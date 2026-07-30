# I-04 — Stamina Economy Invariant Tests

**Priority:** P0 (blocking)
**Status:** ✅ DONE
**Effort:** M (days)
**Depends On:** I-01 (GUT deploy)
**Blocks:** None
**Source:** Audit document §9; `audit-docs-codebase-health.md` §4.3 "Test Coverage"

---

## Problem

The stamina economy is the central resource loop governing all combat actions. It has zero automated tests. A single error in regen timing, cooldown reset, or max-value clamping breaks the entire game's difficulty curve.

## Core Invariants

1. **Max clamp:** `stamina ≤ max_stamina` at all times
2. **Regen gating:** stamina regenerates ONLY in `State.LOCOMOTION`
3. **Cooldown reset:** any stamina spend resets the 1.5s recovery delay
4. **Cooldown freeze:** the delay countdown freezes during non-LOCOMOTION states
5. **Sprint drain:** sprinting drains stamina continuously
6. **Zero floor:** stamina cannot go negative (action blocked before reaching 0)
7. **Full recovery:** resting at shrine sets stamina to max
8. **Death reset:** dying and respawning restores full stamina

## Test Cases

### File: `game/tests/unit/systems/test_stamina_economy.gd`

```gdscript
extends GutTest

var _player: CharacterBody3D
var _simulator: PlayerStateSimulator

func before_each() -> void:
    _player = auto_free(CharacterBody3D.new())
    _player.set_script(load("res://scripts/player/player.gd"))
    _player._ready()
    _simulator = PlayerStateSimulator.new(_player)

# --- Max Clamp ---

func test_stamina_never_exceeds_max() -> void:
    _player.stamina = _player.max_stamina
    _player._update_stamina(10.0)  # Try to regen above max
    assert_le(_player.stamina, _player.max_stamina, "Stamina should never exceed max")

func test_stamina_clamped_after_shrine_rest() -> void:
    _player.stamina = _player.max_stamina
    _player._rest()  # Full restore
    assert_eq(_player.stamina, _player.max_stamina, "Rest should set stamina to exactly max")

# --- Regen Gating ---

func test_stamina_regen_only_in_locomotion() -> void:
    _player.stamina = 50.0
    _simulator.force_state(State.ATTACK_ACTIVE)
    var stamina_before := _player.stamina
    _player._update_stamina(1.0)  # 1 second worth of updates
    assert_eq(_player.stamina, stamina_before, "Stamina should not regen during ATTACK_ACTIVE")

func test_stamina_regen_in_locomotion() -> void:
    _player.stamina = 50.0
    _player._stamina_delay = 0  # No delay
    _simulator.force_state(State.LOCOMOTION)
    var stamina_before := _player.stamina
    _player._update_stamina(0.1)  # 100ms of regen
    assert_gt(_player.stamina, stamina_before, "Stamina should regen in LOCOMOTION")

func test_stamina_no_regen_in_dodge() -> void:
    _player.stamina = 50.0
    _simulator.force_state(State.DODGE)
    var before := _player.stamina
    _player._update_stamina(0.5)
    assert_eq(_player.stamina, before, "Stamina should not regen during DODGE")

func test_stamina_no_regen_in_stagger() -> void:
    _player.stamina = 50.0
    _simulator.force_state(State.STAGGER)
    var before := _player.stamina
    _player._update_stamina(0.5)
    assert_eq(_player.stamina, before, "Stamina should not regen during STAGGER")

func test_stamina_no_regen_while_dead() -> void:
    _player.stamina = 50.0
    _simulator.force_state(State.DEAD)
    var before := _player.stamina
    _player._update_stamina(1.0)
    assert_eq(_player.stamina, before, "Stamina should not regen while DEAD")

# --- Cooldown Reset ---

func test_stamina_cooldown_resets_on_attack() -> void:
    _player.stamina = 100.0
    _player._stamina_delay = 0.1  # Almost ready to regen
    var delay_before := _player._stamina_delay
    _player._try_attack(false)  # Light attack — spends stamina
    assert_gt(_player._stamina_delay, delay_before, "Attack should reset stamina delay")

func test_stamina_cooldown_resets_on_dodge() -> void:
    _player.stamina = 100.0
    _player._stamina_delay = 0.1
    _simulator.force_state(State.LOCOMOTION)
    _player._try_dodge(Vector3.FORWARD)
    assert_gt(_player._stamina_delay, 1.4, "Dodge should reset stamina delay to ~1.5s")

func test_stamina_cooldown_resets_on_sprint_start() -> void:
    _player.stamina = 100.0
    _player._stamina_delay = 0.1
    # Simulate sprint start
    _player._try_sprint(true)
    assert_gt(_player._stamina_delay, 0.1, "Sprinting should reset stamina delay")

# --- Cooldown Freeze ---

func test_stamina_delay_frozen_during_attack() -> void:
    _player.stamina = 50.0
    _player._stamina_delay = 1.0
    _simulator.force_state(State.ATTACK_ACTIVE)
    _player._update_stamina(0.5)  # 500ms passes
    assert_almost_eq(_player._stamina_delay, 1.0, 0.01, "Stamina delay should freeze during attack")

func test_stamina_delay_decrements_in_locomotion() -> void:
    _player._stamina_delay = 1.0
    _simulator.force_state(State.LOCOMOTION)
    _player._update_stamina(0.5)  # 500ms of LOCOMOTION
    assert_lt(_player._stamina_delay, 1.0, "Stamina delay should count down in LOCOMOTION")

# --- Sprint Drain ---

func test_sprint_drains_stamina() -> void:
    _player.stamina = 100.0
    _simulator.force_state(State.LOCOMOTION)
    _player.sprinting = true
    var before := _player.stamina
    _player._update_stamina(0.5)  # 500ms of sprinting
    assert_lt(_player.stamina, before, "Sprinting should drain stamina")

func test_sprint_stops_when_stamina_empty() -> void:
    _player.stamina = 1.0
    _simulator.force_state(State.LOCOMOTION)
    _player.sprinting = true
    _player._update_stamina(0.5)
    assert_eq(_player.sprinting, false, "Sprint should stop when stamina reaches 0")

# --- Per-Style Cost Verification ---

func test_twin_colossi_heavy_costs_65() -> void:
    _player.combat_style = CombatStyle.TWIN_COLOSSI
    _player.stamina = 100.0
    var before := _player.stamina
    _player._try_attack(true)  # Heavy attack
    var cost := before - _player.stamina
    assert_almost_eq(cost, 65.0, 1.0, "Twin Colossi heavy should cost ~65 stamina")

func test_crescent_pair_light_costs_16() -> void:
    _player.combat_style = CombatStyle.CRESCENT_PAIR
    _player.stamina = 100.0
    var before := _player.stamina
    _player._try_attack(false)  # Light attack
    var cost := before - _player.stamina
    assert_almost_eq(cost, 16.0, 1.0, "Crescent Pair light should cost ~16 stamina")

func test_insufficient_stamina_blocks_attack() -> void:
    _player.combat_style = CombatStyle.TWIN_COLOSSI
    _player.stamina = 30.0  # Not enough for heavy (65)
    _simulator.force_state(State.LOCOMOTION)
    var state_before := _player.state
    _player._try_attack(true)
    assert_eq(_player.state, state_before, "Attack should be blocked by insufficient stamina")

# --- Death / Respawn ---

func test_stamina_resets_on_respawn() -> void:
    _player.stamina = 10.0
    _player._stamina_delay = 1.5
    _player._respawn()  # World-level respawn
    assert_eq(_player.stamina, _player.max_stamina, "Respawn should restore full stamina")
    assert_eq(_player._stamina_delay, 0.0, "Respawn should reset stamina delay")

# --- Focus Resource (separate but parallel to stamina) ---

func test_focus_never_exceeds_max() -> void:
    _player.focus = _player.max_focus
    _player._update_stamina(10.0)
    assert_le(_player.focus, _player.max_focus, "Focus should never exceed max")

func test_focus_regenerates_in_all_states() -> void:
    # Unlike stamina, focus regenerates in any state
    _player.focus = 50.0
    _simulator.force_state(State.ATTACK_ACTIVE)
    var before := _player.focus
    _player._update_stamina(0.1)
    # Focus regen is independent of stamina gating
    assert_gt(_player.focus, before, "Focus should regen in any state (unlike stamina)")
```

## Acceptance Criteria

- [ ] All 18+ test cases pass
- [ ] Stamina never exceeds `max_stamina` under any simulation
- [ ] Stamina regenerates only in LOCOMOTION (verified across 4+ non-LOCOMOTION states)
- [ ] Stamina cooldown resets to 1.5s on every spend action
- [ ] Stamina cooldown freezes during non-LOCOMOTION states
- [ ] Per-style stamina costs match target table (B-01)
- [ ] Insufficient stamina blocks actions
- [ ] Sprint auto-disengages at 0 stamina
- [ ] Respawn restores full stamina

## Risk Assessment

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| `_update_stamina()` is a private method subject to refactor | Low | Test the public behavior contract, not internal implementation |
| Float comparison precision in stamina values | Low | Use `assert_almost_eq` with 0.01 tolerance |
| Tests depend on B-01 stamina values being correct | Medium | Run B-01 first; tests verify CURRENT values, then update after B-01 |
