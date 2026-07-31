# 2026-07-30 — B-05 Charge Heavy + B-07 Grip Modes

### Scope

Playable discrete charge-heavy tiers and one-hand / two-hand / paired grip switching with distinct `MovesetData` (no critical-damage doubling from two-handing).

### Changes

- `ChargeProfile` validation + factory tiers (0.2 / 0.75 / 1.4s)
- `WeaponData.create_weapon` per style with supported grips
- Player: `CHARGE_HEAVY` hold/release, `T` toggle grip, two-hand disables shield guard
- Visuals: charge pose; two-hand centers weapon / hides shield; paired→one hides offhand
- Contract: `ASHEN_GRIP_CHARGE_CONTRACTS_OK`; tasks B-05/B-07 → DONE

### Controls

- Hold RMB/`K` to charge, release to swing tier
- `T` cycles grip when the loadout supports more than one

---
