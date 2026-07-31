# D-01 — AnimationTree Root Motion Integration

**Priority:** P1 (critical)
**Status:** ✅ DONE (straight-sword AnimationTree + placeholder Skeleton root-motion POC; Physics callback; Strafe BlendSpace2D / leap / execution travel wired)
**Effort:** L (week)
**Depends On:** None
**Blocks:** D-02, D-03, D-04, D-05
**Source:** Audit document §3 "动画与根运动集成"; `research-dark-souls-mechanics-deep.md` §8

> **POC note:** `PlayerAnimationBridge` builds a minimal Root/Hips skeleton and Physics-callback AnimationTree. Gameplay timers still own hit windows; root motion drives light-attack and Twin Colossi leap displacement with `authored_displacement` / `leap_lunge` fallback. Placeholder bones are not the final art pipeline.

---

## Problem

All player movement is currently code-driven via `_physics_process` velocity manipulation. This causes:
- **Ice-skating:** Character slides during attack animations because velocity doesn't match visual foot placement
- **Inconsistent feel:** Attack lunges are hardcoded constants, not animation-driven
- **No physical weight:** Heavy weapon swings don't convey mass through character movement
- **Animation-movement disconnect:** Visual animation and physical position are independent systems

## Target Architecture

Use Godot 4's `AnimationTree.get_root_motion_position()` and `get_root_motion_rotation()` to extract bone-level displacement from animation data, then apply to `CharacterBody3D.move_and_slide()`.

### Key Principle

> "The animation drives the character — not the other way around."

Root bone tracks in Blender/3D software bake the character's world-space displacement into the skeleton. Godot extracts and applies this per-physics-frame.

## Implementation Steps

### Step 1: Set up AnimationTree with root motion support

File: `game/scenes/actors/player.tscn` (or create via code in `player.gd._ready()`)

```
AnimationTree (Process Callback = Physics)
├── AnimationNodeStateMachinePlayback (root)
│   ├── Idle → Walk → Run (BlendSpace2D)
│   ├── Attack_Light_1 → Attack_Light_2 → ... (chain)
│   ├── Attack_Heavy_1 → ...
│   ├── Dodge_Forward / Dodge_Back / Dodge_Left / Dodge_Right
│   ├── Parry
│   ├── Guard_Start → Guard_Loop → Guard_End
│   ├── Stagger
│   ├── Death
│   └── Leap_Attack
└── root_motion_track: NodePath to root bone
```

### Step 2: Configure root motion track

In the AnimationTree, set:
- `root_motion_track` → path to the root bone in the skeleton
- Ensure animation library has root bone position/rotation tracks

For procedural animations (current approach), this requires:
- Creating `Animation` resources programmatically with root bone tracks
- Or switching to imported `.glb` animations with pre-baked root motion

### Step 3: Extract root motion in `_physics_process`

File: `game/scripts/player/player.gd`

```gdscript
var _anim_tree: AnimationTree

func _ready() -> void:
    _anim_tree = $AnimationTree
    _anim_tree.active = true

func _physics_process(delta: float) -> void:
    # Get root motion delta from animation
    var root_motion_pos: Vector3 = _anim_tree.get_root_motion_position()
    var root_motion_rot: Quaternion = _anim_tree.get_root_motion_rotation()
    
    # Transform to world space
    var world_motion: Vector3 = global_transform.basis * root_motion_pos
    
    # Combine with existing velocity
    velocity.x = world_motion.x / delta
    velocity.z = world_motion.z / delta
    velocity.y -= gravity * delta  # Gravity still code-driven
    
    # Apply rotation
    if root_motion_rot.length() > 0.001:
        var y_rot := root_motion_rot.get_euler().y
        rotate_y(y_rot)
    
    move_and_slide()
```

### Step 4: CRITICAL — Force Physics process callback

```gdscript
func _ready() -> void:
    _anim_tree = $AnimationTree
    _anim_tree.process_callback = AnimationTree.ANIMATION_PROCESS_PHYSICS
    # IMPORTANT: Must be Physics, not Idle.
    # Godot issues #53752 & #65199: Idle callback causes
    # frame-rate-dependent root motion drift.
```

### Step 5: Separate code-driven vs animation-driven movement

```gdscript
enum MovementMode {
    CODE_DRIVEN,      # Dodge, knockback — velocity set directly
    ANIMATION_DRIVEN, # Attack lunges, walk cycles — root motion
    HYBRID            # Sprint — code speed + animation foot placement
}

var _movement_mode: int = MovementMode.CODE_DRIVEN

func _physics_process(delta: float) -> void:
    match _movement_mode:
        MovementMode.CODE_DRIVEN:
            _apply_code_driven_movement(delta)
        MovementMode.ANIMATION_DRIVEN:
            _apply_root_motion(delta)
        MovementMode.HYBRID:
            _apply_hybrid_movement(delta)
```

### Step 6: Map attack states to animation-driven movement

```gdscript
func _change_state(new_state: int) -> void:
    match new_state:
        State.ATTACK_WINDUP, State.ATTACK_ACTIVE, State.ATTACK_RECOVERY:
            _movement_mode = MovementMode.ANIMATION_DRIVEN
        State.DODGE:
            _movement_mode = MovementMode.CODE_DRIVEN  # Dodge is code-driven
        State.LOCOMOTION:
            _movement_mode = MovementMode.HYBRID
```

### Step 7: Transition path for procedural animations

Current project uses 100% procedural poses (no keyframed animations). Root motion requires animation data. Options:

**Option A: Imported animations (recommended for production)**
- Author animations in Blender with root bone displacement
- Export to `.glb` with `-bake_animations`
- Import into Godot as AnimationLibrary
- Assign to AnimationTree

**Option B: Code-generated animation tracks (transitional)**
```gdscript
func _create_attack_animation() -> Animation:
    var anim := Animation.new()
    anim.length = 1.2  # Total attack duration
    anim.loop_mode = Animation.LOOP_NONE
    
    # Root bone forward lunge
    var track_idx := anim.add_track(Animation.TYPE_POSITION_3D)
    anim.track_set_path(track_idx, "Skeleton3D:Root")
    anim.position_track_insert_key(track_idx, 0.0, Vector3.ZERO)
    anim.position_track_insert_key(track_idx, 0.4, Vector3(0, 0, 1.5))  # Lunge forward
    anim.position_track_insert_key(track_idx, 0.8, Vector3(0, 0, 2.0))  # Max reach
    anim.position_track_insert_key(track_idx, 1.2, Vector3(0, 0, 0.5))  # Recover
    
    return anim
```

This transitional approach allows root motion benefits without importing external assets, consistent with the project's self-contained philosophy.

## Acceptance Criteria

- [ ] Player attack animations drive physical displacement (no more code-driven lunge constants)
- [ ] Heavy weapon swing visibly moves the character forward during active frames
- [ ] Feet don't slide during walk/run cycles (animation speed matches movement speed)
- [ ] `AnimationTree.process_callback = Physics` is enforced
- [ ] Root motion works correctly on slopes (gravity still code-driven)
- [ ] Lock-on strafing blends correctly with root motion displacement
- [ ] Dodge remains code-driven (instant repositioning doesn't need animation baking)
- [ ] `ASHEN_HOLLOW_SMOKE_OK` passes with root motion active

## Risk Assessment

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Procedural animations lack root bone tracks | High | Use Option B (code-generated Animation tracks) as transitional approach |
| Root motion + collision causes tunneling | Medium | Enable continuous CD in CharacterBody3D; test on thin geometry |
| Frame rate affects root motion accuracy | High | Enforce Physics callback; test at 30/60/144 FPS |
| Significant refactor of movement code | High | Implement MovementMode enum for gradual migration; keep code-driven paths for dodge/knockback |
| No Blender-authored animations exist | High | Start with code-generated animation tracks; this project is 100% procedural by design |
