# 2026-07-30 — Combat Tip Mode (default off) + Grip / Charge / Jump-Slash Spec

### Scope

Ship a dedicated **Combat Tip Mode** setting (default **off**) so teaching HUD for charge, grip, context attacks, jump-slash rules, and weapon arts stays quiet unless the player opts in. Document matching combat rules in the systems / controls specs.

### Runtime

- `game_settings.combat_tip_mode` / bridge `combatTipMode`, persisted in `user://ashen_hollow_settings_v1.json`
- Pause menu → **COMBAT TIP MODE** → `Show combat tips (charge / grip / context)`
- Player `_show_combat_tip` gates: `CHARGING`, `CHARGE T1–T3`, sprint/roll/backstep/jump/falling tips, jump-slash denial, grip labels / `GRIP LOCKED`, shield bash / pierce / leap arts
- Always-on feedback unchanged: stamina fail, parry/guard/poise, world events, hitbox debug

### Spec / docs

- Two-hand **×1.3 damage / ×1.5 stamina**; jump slash only when two-handing or left/right `weapon_type` matches
- Charge tiers **0.20 / 0.75 / 1.40s** (`ChargeProfile`); mid-air and sprint/roll/backstep contexts skip charge
- Updated: `docs/systems/combat-execution-guard-weapon-arts.md`, `docs/controls.md`, this log
- Contracts: `ASHEN_CORE_CONTRACTS_OK`, `ASHEN_GRIP_CHARGE_CONTRACTS_OK`

---
