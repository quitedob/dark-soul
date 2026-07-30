# F-02 — Screen-Space Dot-Product Lock-On Target Scoring

**Priority:** P2 (high)
**Status:** ✅ DONE
**Effort:** M (days)
**Depends On:** None
**Blocks:** F-03, F-04
**Source:** Audit document §6 "视角控制与目标锁定的多维解算"

---

## Problem

Current lock-on target selection uses simple distance-based detection (`_collect_lock_candidates()` returns all enemies in range, `_cycle_lock_target()` iterates through them). This approach:

1. **Ignores camera intent:** Player looks at an enemy but locks onto a closer enemy behind them
2. **No soft prioritization:** All candidates within range are equally weighted
3. **Chaotic in group fights:** Cycling through targets has no predictable order based on screen position

## Target Architecture

Screen-space dot-product scoring: candidates are ranked by how close they are to the center of the screen (camera forward vector).

### Scoring Formula

$$Score = (1.0 - \frac{Angle}{Max\_Angle}) \times Distance\_Factor$$

Where:
- `Angle` = angle between camera forward vector and direction to target
- `Max_Angle` = half the horizontal FOV (~40° for default camera)
- `Distance_Factor` = `1.0 / (1.0 + distance \times 0.1)` — slight distance penalty (closer targets preferred at equal angle)

### Selection Algorithm

1. **Acquire:** `Area3D` sensor collects all living enemies within lock-on range
2. **Score:** Each candidate gets a score from 0.0–1.0 based on screen-center proximity
3. **Sort:** Candidates sorted by score descending
4. **Select top N:** Primary lock = highest score; cycle goes down the list
5. **Min threshold:** Reject candidates with score < 0.2 (too far off-screen)
6. **Distance cap:** Reject candidates beyond `LOCK_ON_MAX_DISTANCE`

## Implementation

### Step 1: Replace `_collect_lock_candidates()` with scoring

File: `game/scripts/player/player.gd`

```gdscript
func _collect_lock_candidates() -> Array[Dictionary]:
    var candidates: Array[Dictionary] = []
    var sensor := $LockOnSensor as Area3D  # Large sphere Area3D
    var camera_forward := $CameraPivot/SpringArm3D/Camera3D.global_transform.basis.z.normalized()
    var camera_pos := $CameraPivot/SpringArm3D/Camera3D.global_position
    
    for body in sensor.get_overlapping_bodies():
        if not body.is_in_group("enemies") or not body.is_alive():
            continue
        
        var to_target := body.global_position - camera_pos
        var distance := to_target.length()
        
        if distance > LOCK_ON_MAX_DISTANCE:
            continue
        
        # Dot product with camera forward
        var to_target_norm := to_target.normalized()
        var dot_product := camera_forward.dot(to_target_norm)
        
        # Angle from camera center (0 = center, 1 = edge of FOV)
        var angle := acos(clampf(dot_product, -1.0, 1.0))
        var max_angle := deg_to_rad(40.0)  # Half FOV
        
        if angle > max_angle:
            continue  # Off-screen
        
        # Score: 1.0 at center, 0.0 at edge
        var angle_score := 1.0 - (angle / max_angle)
        
        # Slight distance preference (closer = higher score at equal angle)
        var distance_factor := 1.0 / (1.0 + distance * 0.1)
        var final_score := angle_score * distance_factor
        
        candidates.append({
            "body": body,
            "score": final_score,
            "angle": angle,
            "distance": distance,
        })
    
    # Sort by score descending
    candidates.sort_custom(func(a, b): return a.score > b.score)
    return candidates

func _acquire_lock_target() -> Node3D:
    var candidates := _collect_lock_candidates()
    if candidates.is_empty():
        return null
    _lock_candidates = candidates
    _lock_index = 0
    return candidates[0].body

func _cycle_lock_target() -> Node3D:
    if _lock_candidates.is_empty():
        return _acquire_lock_target()
    _lock_index = (_lock_index + 1) % _lock_candidates.size()
    return _lock_candidates[_lock_index].body
```

### Step 2: Add Quaternion Slerp for smooth tracking

```gdscript
func _update_lock_on_camera(delta: float) -> void:
    if not lock_target or not is_instance_valid(lock_target):
        return
    
    var target_pos := lock_target.global_position + Vector3.UP * 1.5  # Aim at chest
    var camera := $CameraPivot/SpringArm3D/Camera3D
    var spring_arm := $CameraPivot/SpringArm3D
    
    # Calculate desired look direction
    var pivot_pos := spring_arm.global_position
    var desired_dir := (target_pos - pivot_pos).normalized()
    
    # Slerp rotation for smooth tracking (NOT look_at which is instant/snappy)
    var current_rot := spring_arm.global_transform.basis.get_rotation_quaternion()
    var target_rot := Quaternion(Vector3.FORWARD, desired_dir)
    var slerp_speed := 8.0
    var new_rot := current_rot.slerp(target_rot, slerp_speed * delta)
    
    spring_arm.global_transform.basis = Basis(new_rot)
```

### Step 3: Add lock-on reticle UI

File: `game/scripts/hud.gd`

Draw a small diamond/chevron marker at the locked target's screen position. Use `camera.unproject_position(target.global_position)` to get screen coordinates.

### Step 4: Visual debug (development only)

```gdscript
# In _collect_lock_candidates() — debug visualization
if OS.is_debug_build():
    for c in candidates:
        var score_color := Color.GREEN.lerp(Color.RED, 1.0 - c.score)
        DebugDraw3D.draw_line(camera_pos, c.body.global_position, score_color)
        DebugDraw3D.draw_string(c.body.global_position + Vector3.UP * 3.0,
            "%.2f" % c.score)
```

## Acceptance Criteria

- [ ] Lock-on selects the enemy closest to screen center, not the physically nearest enemy
- [ ] Target cycling goes through candidates in screen-space order (left-to-right or clockwise)
- [ ] Enemies beyond the screen FOV are excluded from lock-on
- [ ] Camera smoothly tracks locked target via slerp (no snapping)
- [ ] Lock-on breaks correctly when target moves beyond max distance
- [ ] Performance: scoring loop handles 20+ enemies without frame drops
- [ ] Debug visualization toggle available for development

## Risk Assessment

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| `acos()` performance on many enemies | Very Low | 20 enemies × 1 acos = negligible; pre-filter by distance |
| Camera slerp feels laggy in fast combat | Medium | Make slerp speed configurable (8.0 default, higher = snappier) |
| Lock-on sensor Area3D too small for large arenas | Low | Sensor radius = LOCK_ON_MAX_DISTANCE × 1.2 to capture borderline candidates |
