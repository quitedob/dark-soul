# K-01 — Fix Focus Resource Leak in Attack Commit Path

**Priority:** P0 (blocking)
**Status:** ✅ DONE
**Effort:** S (hours)
**Depends On:** None
**Blocks:** None
**Source:** Code review full audit 2026-07-30, finding H-1
**Authority:** `docs/systems/focus-resource.md`

---

## Problem

In `player.gd`, the `_commit_attack()` method deducts focus cost before some early-return paths that cancel the attack. If a spell-style melee attack is cancelled due to insufficient stamina or other guard conditions after focus has been deducted, the focus is not refunded.

**Location:** `game/scripts/player/player.gd:1053-1061`

```gdscript
# Current flow (simplified):
# 1. Guard checks (stamina, state, etc.)
if stamina < attack_cost:
    return  # ❌ focus may have already been deducted at this point

# 2. Focus deduction happens before some cancellations
focus -= focus_cost  # ❌ if any guard check below fails, focus is leaked

# 3. More guard checks...
```

The interleaving of resource deductions and guard checks is fragile and error-prone for future modifications.

## Target

Deduct all resources atomically after ALL guard checks pass, or implement a resource-transaction pattern that can be rolled back:

```gdscript
func _commit_attack(attack_data: AttackData) -> bool:
    # Phase 1: All guard checks (no mutation)
    if stamina < attack_data.stamina_cost:
        return false
    if state in [State.DEAD, State.STAGGER]:
        return false
    # ... all other guards ...

    # Phase 2: Atomic resource deduction (only after all guards pass)
    stamina -= attack_data.stamina_cost
    focus -= attack_data.focus_cost

    # Phase 3: State transition
    _change_state(State.ATTACK_WINDUP, ...)
    return true
```

Alternatively, extract a `_can_commit_attack(attack_data) -> bool` predicate that is called first dry, then `_deduct_attack_costs(attack_data)` only after the predicate passes.

## Acceptance Criteria

- [ ] No resource (stamina, focus) is deducted before ALL guard checks pass
- [ ] Focus is never consumed for a cancelled attack
- [ ] Attack cancellation path does not modify any resource values
- [ ] Existing stamina economy tests (`test_stamina_economy.gd`) continue to pass
- [ ] Spell-style melee attacks (Veilcraft/Ember Rite) refund focus correctly on cancel
- [ ] Smoke test passes (`ASHEN_HOLLOW_SMOKE_OK`)

## Risk Assessment

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Refactoring breaks attack flow | Low | Extract predicate first, verify with existing FSM tests |
| Hidden guard checks missed | Low | Grep all `return` statements in `_commit_attack()` before refactoring |
