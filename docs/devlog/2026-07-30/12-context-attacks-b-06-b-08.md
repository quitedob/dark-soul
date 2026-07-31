# 2026-07-30 — Context Attacks (B-06 / B-08)

### Scope

Completed contextual attacks across all compatibility movesets: sprint, roll, backstep, general jump, and falling plunge. Leap weapon arts remain on `weapon_art_heavy` and no longer occupy `jump_attack`. Jump grants `low_sweep` immunity while airborne.

### Changes

- `compatibility_moveset_factory.gd`: fills sprint/roll/backstep/jump/falling; leap → `weapon_art_heavy`
- `player.gd`: context resolve priority (falling > jump > sprint > roll > backstep > neutral); backstep dodge; low-sweep immunity
- `enemy.gd`: close light / stalker swings tagged `low_sweep`
- Contracts: `ASHEN_CONTEXT_ATTACK_CONTRACTS_OK`; GUT moveset schema updated
- Tasks B-06 / B-08 → DONE; `controls.md` updated

### Remaining

- Grip modes (B-07), charge heavy (B-05)
- Automatic recovery teleport to `last_safe_transform` (P2)

---
