# 2026-07-30 — Godot Jump, Landing, and Collision-Tunneling Research

### Scope

Researched common Godot 4.x solutions for jump/landing detection, slopes, vertical steps, wall-corner sticking, high-speed movement, projectile tunneling, safe respawn, collision-shape setup, debugging, and headless regression coverage. The complete report is archived at [research-godot-jump-collision.md](research-godot-jump-collision.md).

Research used one consolidated Perplexity deep-research thread, a follow-up verification attempt, direct reads of identified Godot official documentation, and a read-only scan of the current repository. No runtime code was changed.

### High-Confidence Findings

- `floor_snap_length` handles downward ground adhesion; it does not climb upward vertical steps.
- Automatic floor snap stops while velocity points along `up_direction`. `apply_floor_snap()` ignores velocity and is an on-demand override, not a method to call unconditionally every frame.
- Godot's built-in stair-stepping proposal remains open. Visual stairs should prefer ramp colliders; custom step-up requires bounded upward/forward/downward motion tests.
- Current projectiles use `Area3D`, move through direct `global_position` updates, and have `collision_mask = 4`. They detect enemies but intentionally ignore world layer 1. `Area3D` documents overlap monitoring, not continuous swept collision.
- Current vertical campaign topologies place floors at 2 m height increments while the player has no general jump. Navigation `agent_max_climb` does not grant the player step-up or jumping behavior.
- Player respawn, enemy reset, and Lost Echo placement currently assign positions without overlap, floor-angle, or reachability validation.
- `RigidBody3D.continuous_cd` is specific to rigid bodies and does not solve CharacterBody3D or Area3D transform movement.
- CharacterBody3D/moving-body colliders should use unscaled primitive or convex shapes; concave shapes belong to static level geometry.

### Corrections to Initial Research Claims

The first Perplexity answer overclaimed two points and was not adopted verbatim:

- **Rejected:** “Always call `apply_floor_snap()` after `move_and_slide()`.” This can interfere with intentional upward movement. Use automatic snap normally and force snap only in an explicitly validated recovery case.
- **Rejected:** “8.4 m/s dodge definitely tunnels.” `move_and_slide()` performs collision-aware motion; tunneling must be demonstrated against thin geometry, extreme per-step displacement, initial overlap, direct transform changes, or multi-contact edge cases.
- **Rejected:** “`body_test_motion()` is the highest-performance option.” Official documentation does not make that performance claim.

### Confirmed Project Risks

1. **Projectile world penetration — P0:** add world blocking and explicit ray/shape sweep; nearest collision wins.
2. **Vertical topology reachability — P0:** generate ramps/lifts/legal connectors until general jump exists; test Spawn→Checkpoint→Exit reachability.
3. **Unsafe respawn and Lost Echo placement — P0:** validate capsule overlap, floor angle, and deterministic fallback positions.
4. **Missing general jump/landing contract — P1:** add airborne/landing semantics, preserve upward detachment from snap, sample pre-landing vertical velocity, and handle ceilings.
5. **Implicit CharacterBody defaults — P1:** explicitly set motion mode, up direction, floor angle, floor/wall behavior, safe margin, max slides, and ceiling behavior.
6. **Missing movement diagnostics — P1:** record previous position, requested/actual motion, floor transitions, slide count/normals, stuck frames, and last safe transform.
7. **No stair/edge regression scenes — P2:** test slopes, step thresholds, concave corners, thin walls, 30/60/120 physics ticks, projectile sweeps, and occupied spawn points.

### Recommended API Boundaries

| Problem | Recommended API |
|---|---|
| Character proposed motion | `PhysicsBody3D.test_move()` or `PhysicsServer3D.body_test_motion()` |
| Target spawn overlap | `PhysicsDirectSpaceState3D.intersect_shape()` |
| Thin projectile | `intersect_ray()` |
| Projectile with radius | `cast_motion()` or `ShapeCast3D` |
| Current-position overlap | `intersect_shape()`; it ignores query motion |
| Physical rigid projectile | `RigidBody3D` with `continuous_cd`, only when force/mass/ricochet are required |

### Validation Status

- Official CharacterBody3D parameter defaults and floor-snap semantics were verified against Godot 4.4/stable documentation.
- Official ShapeCast, direct-space query, Area3D, RigidBody3D CCD, collision-shape, and test-motion semantics were reviewed.
- Markdown report links and project code references still require final documentation validation.
- No Godot parser, physics scene, smoke, or export test was run for this research-only entry.
