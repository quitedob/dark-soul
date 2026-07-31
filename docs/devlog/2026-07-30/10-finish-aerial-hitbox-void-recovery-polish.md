# 2026-07-30 — Finish Aerial Hitbox / Void Recovery Polish

### Scope

Closed remaining jump/falling polish: weapon-tip socket follow, hitbox debug wiring, and automatic `last_safe_transform` recovery when falling out of the world.

### Changes

- Jump / leap hitboxes follow `weapon_pivot` tip via `CombatArea.set_socket_follow`
- Falling stays root-relative tall capsule until land
- `F3` / `combat_hitbox_debug` toggles debug capsule
- Void / deep drop → `recover_to_last_safe` (light HP penalty)
- Contracts updated (`weapon_tip`, void API)

---
