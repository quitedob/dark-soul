# G-07 — Route All Enemy Hits Through `receive_hit_payload()`

**Priority:** P1 (critical)
**Status:** ✅ DONE
**Effort:** S (hours)
**Depends On:** None
**Blocks:** None
**Source:** Code review full audit 2026-07-30, finding H-3
**Authority:** `docs/systems/combat-execution-guard-weapon-arts.md`

---

## Problem

`enemy.gd:297` has a thin adapter `receive_hit()` that hardcodes `execution_break_damage` at `stagger * 0.35`, bypassing the authored `AttackData.execution_break_damage` values in `.tres` resources:

```gdscript
# enemy.gd line 297 — adapter path
func receive_hit(damage: float, stagger: float, ...) -> void:
    # constructs minimal payload with hardcoded formula
    payload.execution_break_damage = stagger * 0.35  # ❌ ignores AttackData
    receive_hit_payload(payload)

# enemy.gd line 311 — canonical handler
func receive_hit_payload(payload: Dictionary) -> void:
    # expects full payload from AttackData.to_hit_metadata()
```

The canonical handler `receive_hit_payload()` receives the full payload from `AttackData.to_hit_metadata()` which includes the authored `execution_break_damage`, but the adapter path loses this information.

## Target

Route all hit reception through `receive_hit_payload()` and remove the thin adapter, OR ensure the adapter extracts all fields from the full `AttackData` payload:

**Option A (preferred):** Remove `receive_hit()` and update all callers to construct full payloads via `AttackData.to_hit_metadata()`.

**Option B:** Have `receive_hit()` delegate to `AttackData.to_hit_metadata()` for payload construction.

## Acceptance Criteria

- [ ] `execution_break_damage` on enemy hits comes from authored `AttackData`, not a hardcoded formula
- [ ] All hit paths use consistent payload structure
- [ ] Boss execution break accumulation matches authored values
- [ ] Existing combat contract tests continue to pass
- [ ] Smoke test passes
