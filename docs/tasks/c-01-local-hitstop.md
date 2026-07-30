# C-01 — Local AnimationTree Hit-Stop (Replace Engine.time_scale)

**Priority:** P0 (blocking)
**Status:** ✅ DONE
**Effort:** M (days)
**Depends On:** None
**Blocks:** C-02, C-03
**Source:** Audit document §4 "命中停顿与视听物理创伤反馈"; Godot engine issues

---

## Problem

The current hit-stop implementation in `game_world.gd` uses `Engine.time_scale = 0.02` (heavy) / `0.05` (light), which is architecturally incorrect:

1. **Physics tick collapse:** `time_scale` multiplies engine delta — at 0.02×, physics ticks drop to near-zero, causing rigid body instability
2. **Timer corruption:** `SceneTreeTimer` and `Tween` callbacks fire at wrong times or not at all
3. **Global freeze:** ALL entities freeze, not just the combatants — particles, UI animations, environmental effects all stutter
4. **Godot community consensus:** This approach is explicitly warned against for action games

## Target Architecture

Freeze ONLY the player and hit enemy's `AnimationTree` time scale nodes, leaving the physics engine running at full speed. This creates the visual "impact freeze" while maintaining physics integrity.

### Approach A: AnimationTree TimeScale Node (Recommended)

```gdscript
# On hit confirmed:
func _apply_hit_stop(target: Node3D, duration: float, intensity: float):
    # 1. Freeze player animation
    var player_tree: AnimationTree = _player.get_node("AnimationTree")
    player_tree.set("parameters/TimeScale/scale", 0.0)  # freeze
    
    # 2. Freeze hit target animation
    if target.has_node("AnimationTree"):
        var target_tree: AnimationTree = target.get_node("AnimationTree")
        target_tree.set("parameters/TimeScale/scale", 0.0)
    
    # 3. Restore after duration using physics-frame counter (NOT timer)
    _hit_stop_frames = int(duration / get_physics_process_delta_time())
    _hit_stop_target = target
```

### Approach B: Delta Isolation Network (Alternative)

If AnimationTree nodes don't have a TimeScale parameter exposed, build an independent delta counter network that passes a decoupled `delta` to specific nodes, allowing them to ignore global time progression.

## Implementation Steps

### Step 1: Add TimeScale parameter to AnimationTree

File: `game/scripts/player/player.gd`

In `_ready()`, ensure the AnimationTree has a `TimeScale` parameter node at the root of the blend tree:

```gdscript
# Ensure root motion and timescale nodes exist in AnimationTree
var tree_root := anim_tree.tree_root
# Add TimeScale node if not present (may need to be done in .tscn or code)
```

### Step 2: Create HitStopManager component

File: `game/scripts/combat/hit_stop_manager.gd` (NEW)

```gdscript
class_name HitStopManager
extends Node

var _active_stops: Array[HitStopInstance] = []

class HitStopInstance:
    var player_tree: AnimationTree
    var target_tree: AnimationTree
    var remaining_frames: int
    var restore_scale: float = 1.0

func trigger(player: Node3D, target: Node3D, duration_sec: float, intensity: float = 0.02):
    # intensity reserved for future use (screen shake, audio duck)
    var instance := HitStopInstance.new()
    instance.player_tree = player.get_node_or_null("AnimationTree")
    instance.target_tree = target.get_node_or_null("AnimationTree")
    instance.remaining_frames = ceili(duration_sec / get_physics_process_delta_time())
    
    if instance.player_tree:
        instance.player_tree.set("parameters/TimeScale/scale", 0.0)
    if instance.target_tree:
        instance.target_tree.set("parameters/TimeScale/scale", 0.0)
    
    _active_stops.append(instance)

func _physics_process(_delta: float):
    for i in range(_active_stops.size() - 1, -1, -1):
        var stop := _active_stops[i]
        stop.remaining_frames -= 1
        if stop.remaining_frames <= 0:
            if is_instance_valid(stop.player_tree):
                stop.player_tree.set("parameters/TimeScale/scale", 1.0)
            if is_instance_valid(stop.target_tree):
                stop.target_tree.set("parameters/TimeScale/scale", 1.0)
            _active_stops.remove_at(i)
```

### Step 3: Replace time_scale manipulation in game_world.gd

File: `game/scripts/game_world.gd` — `_on_player_hit_landed()` (~line 457)

```gdscript
# BEFORE (remove this):
func _on_player_hit_landed(is_heavy: bool) -> void:
    Engine.time_scale = 0.02 if is_heavy else 0.05
    await get_tree().create_timer(0.08 if is_heavy else 0.04).timeout
    Engine.time_scale = 1.0

# AFTER:
func _on_player_hit_landed(target: Node3D, is_heavy: bool) -> void:
    var duration := 0.08 if is_heavy else 0.04
    _hit_stop_manager.trigger(_player, target, duration)
    if is_heavy:
        _trauma_shake.inject(0.8)  # C-02 integration point
    else:
        _trauma_shake.inject(0.3)
```

### Step 4: Update `hit_landed` signal to pass target reference

File: `game/scripts/combat_area.gd`

```gdscript
# Current:
signal hit_landed(is_heavy: bool)

# Updated:
signal hit_landed(target: Node3D, is_heavy: bool)
```

Emitter in `_on_body_entered()` passes `body` as target.

### Step 5: Add time_scale guard

In `game_world.gd._ready()`, add assertion:

```gdscript
assert(Engine.time_scale == 1.0, "Engine.time_scale must remain 1.0; use HitStopManager for local freezes")
```

### Step 6: Validation

```bash
godot --headless --path game --check-only
godot --headless --path game --quit-after 600 -- --smoke-test
```

Manual test: attack an enemy — the player and enemy should freeze briefly on impact, but particles, UI, and other enemies should continue animating normally.

## Acceptance Criteria

- [ ] `Engine.time_scale` is never modified (remains 1.0 at all times)
- [ ] Heavy hit freezes player + target animation for 0.08s
- [ ] Light hit freezes player + target animation for 0.04s
- [ ] Environmental particles (ember motes, dust) continue during hit-stop
- [ ] HUD animations (health bar, stamina bar) continue during hit-stop
- [ ] Other enemies in the scene continue animating during hit-stop
- [ ] No physics instability or collision tunneling
- [ ] `ASHEN_HOLLOW_SMOKE_OK` passes

## Risk Assessment

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| AnimationTree has no TimeScale parameter exposed | Medium | Add it in code via `AnimationNodeAddon` or use delta isolation (Approach B) |
| AnimationTree freeze prevents state machine transitions | Low | State machine is code-driven; animation is visual only |
| Multiple rapid hits cause overlapping stop/restore | Low | HitStopInstance stack handles concurrent stops correctly |
