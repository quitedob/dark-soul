# 2026-07-30 — Jump/Collision Research P0–P1 Runtime Landing

### Scope

Implemented prioritized recommendations from `docs/research-godot-jump-collision.md`: projectile world sweep, vertical topology ramps, safe spawn/Lost Echo projection, explicit CharacterBody3D parameters, and basic grounded jump.

### Changes

- `spell_projectile.gd`: `QUERY_MASK = World|Enemies`, `cast_motion` sweep, nearest-hit resolve
- `procedural_campaign_level_builder.gd`: `_add_height_ramps()` for 1-cell height steps; pillars become colliding `StaticBody3D`
- `safe_placement.gd`: capsule overlap + downward floor projection with deterministic ring fallback
- `player.gd`: `jump` (`V` / D-pad up), landing speed sample, `last_safe_transform`, safe `respawn_at`
- `player_visuals.gd`: explicit motion/floor/wall/safe_margin parameters
- Contract: `ASHEN_JUMP_COLLISION_CONTRACTS_OK`

### Remaining

- Automatic recovery teleport to `last_safe_transform` (P2)

---
