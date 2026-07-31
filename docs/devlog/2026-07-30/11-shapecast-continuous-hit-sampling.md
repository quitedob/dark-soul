# 2026-07-30 — ShapeCast Continuous Hit Sampling

### Scope

CombatArea now sweeps the active hitbox capsule along per-frame motion during swings, preventing tunneling on fast downward falling attacks. Optional `debug_draw` shows a semi-transparent capsule while the swing is active.

### Changes

- `combat_area.gd`: ShapeCast3D motion sampling via `_sample_motion_hits()`, shared `already_hit` dedupe, `debug_draw` capsule mesh
- `attack_data.gd`: `hitbox_until_land` included in `to_hit_metadata()`
- Contract tests updated for motion-cast capability and metadata fields

---
