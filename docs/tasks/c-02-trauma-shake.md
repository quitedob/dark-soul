# C-02 — FastNoiseLite Trauma-Based Screen Shake

**Priority:** P1 (critical)
**Status:** ✅ DONE
**Effort:** M (days)
**Depends On:** C-01 (local hit-stop)
**Blocks:** C-03
**Source:** Audit document §4 "命中停顿与视听物理创伤反馈"

---

## Problem

The current camera shake in `game_world.gd._on_player_hit_landed()` uses simple random X/Y offset — this produces mechanical, robotic-feeling camera movement that can cause motion sickness. Random displacement lacks the continuous, organic turbulence of real physical impact.

## Target Architecture

FastNoiseLite Perlin/Simplex noise-driven **trauma model**:

1. Camera maintains a `trauma` value (0.0–1.0)
2. Each hit injects trauma proportional to weapon weight
3. Each frame, actual shake intensity = `trauma^2.0` (exponential curve)
4. FastNoiseLite samples 3 independent noise seeds for X offset, Y offset, and Roll rotation
5. Trauma decays smoothly each frame

### Why This Works

- **Exponential curve:** `trauma^2.0` means high trauma = violent shake; as trauma decays, shake fades rapidly without lingering jitter
- **Perlin noise:** Produces smooth, continuous movement unlike `randf()` which jumps discontinuously each frame
- **3 independent seeds:** Prevents visible correlation between X/Y/Roll axes

## Implementation Steps

### Step 1: Create TraumaShake component

File: `game/scripts/components/trauma_shake.gd` (NEW)

```gdscript
class_name TraumaShake
extends Node

var _trauma: float = 0.0
var _trauma_power: float = 2.0
var _max_offset: Vector2 = Vector2(0.6, 0.4)    # X, Y in units
var _max_roll: float = 0.08                       # Radians
var _decay_rate: float = 0.8                      # Per-second decay
var _noise: FastNoiseLite
var _noise_speed: float = 30.0
var _seed_x: float
var _seed_y: float
var _seed_roll: float
var _camera: Camera3D
var _original_camera_transform: Transform3D

func _init(camera: Camera3D) -> void:
    _camera = camera
    _original_camera_transform = camera.transform
    
    # Initialize noise with 3 distant seeds
    _noise = FastNoiseLite.new()
    _noise.noise_type = FastNoiseLite.TYPE_PERLIN
    _noise.frequency = 0.5
    
    # Three seeds spaced far apart to prevent correlation
    _seed_x = 0.0
    _seed_y = 1000.0
    _seed_roll = 2000.0

func inject(amount: float) -> void:
    _trauma = clampf(_trauma + amount, 0.0, 1.0)

func reset_camera() -> void:
    _trauma = 0.0
    _camera.transform = _original_camera_transform

func _process(delta: float) -> void:
    if _trauma <= 0.001:
        if _trauma > 0:
            _trauma = 0.0
            _camera.transform = _original_camera_transform
        return
    
    # Decay
    _trauma = maxf(_trauma - _decay_rate * delta, 0.0)
    
    # Exponential shake amount
    var shake := pow(_trauma, _trauma_power)
    
    # Sample noise at current time position
    var time_pos := Time.get_ticks_msec() / 1000.0 * _noise_speed
    
    var offset_x := _noise.get_noise_2d(_seed_x, time_pos) * shake * _max_offset.x
    var offset_y := _noise.get_noise_2d(_seed_y, time_pos) * shake * _max_offset.y
    var roll := _noise.get_noise_2d(_seed_roll, time_pos) * shake * _max_roll
    
    # Apply to camera
    _camera.transform = _original_camera_transform
    _camera.translate(Vector3(offset_x, offset_y, 0))
    _camera.rotate_z(roll)  # Roll in camera-local space
```

### Step 2: Integrate into game_world.gd

File: `game/scripts/game_world.gd`

```gdscript
# In _ready() or _create_systems():
var _trauma_shake: TraumaShake

func _create_systems() -> void:
    # ... existing setup ...
    _trauma_shake = TraumaShake.new(_player.camera)
    add_child(_trauma_shake)

# Updated hit-stop handler (replaces Engine.time_scale approach):
func _on_player_hit_landed(target: Node3D, is_heavy: bool) -> void:
    var hitstop_duration := 0.08 if is_heavy else 0.04
    _hit_stop_manager.trigger(_player, target, hitstop_duration)
    
    # Inject trauma based on weight
    if is_heavy:
        _trauma_shake.inject(0.8)
    else:
        _trauma_shake.inject(0.3)

# On player taking damage:
func _on_player_damaged(_amount: float, _source: Node3D) -> void:
    _trauma_shake.inject(0.5)  # Getting hit is jarring

# On boss ground slam or explosion:
func _on_boss_aoe() -> void:
    _trauma_shake.inject(1.0)  # Maximum trauma
```

### Step 3: Configure per-weapon trauma values

Add to `STYLE_TIMING` or weapon metadata:

```gdscript
# Trauma injection table
const TRAUMA_TABLE := {
    "light_attack": 0.3,
    "heavy_attack": 0.8,
    "leap_attack": 1.0,
    "guard_break": 0.6,
    "spell_impact": 0.4,
    "prayer_impact": 0.35,
    "boss_ground_slam": 1.0,
    "player_hit": 0.5,
    "parry_success": 0.2,
    "death": 1.0,
}
```

### Step 4: Add accessibility toggle

File: `game/scripts/core/game_settings.gd`

```gdscript
var screen_shake_enabled: bool = true   # NEW
var screen_shake_intensity: float = 1.0 # NEW (0.0-2.0 multiplier)
```

In `TraumaShake.inject()`:
```gdscript
func inject(amount: float) -> void:
    if not _settings.screen_shake_enabled:
        return
    _trauma = clampf(_trauma + amount * _settings.screen_shake_intensity, 0.0, 1.0)
```

Wire to settings panel (pause menu → settings → screen shake toggle + intensity slider).

## Acceptance Criteria

- [ ] Heavy attack produces smooth, organic camera shake (not random jitter)
- [ ] Shake intensity decays smoothly — no sudden stops
- [ ] Three axes (X, Y, Roll) move independently (no visible pattern)
- [ ] Boss ground slam (trauma=1.0) is appropriately violent without causing nausea
- [ ] Accessibility toggle disables all camera shake
- [ ] Intensity slider scales shake proportionally
- [ ] FastNoiseLite uses Perlin noise (not Value noise) for smoothness
- [ ] Performance: noise sampling < 0.1ms per frame

## Risk Assessment

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Perlin noise causes motion sickness | Medium | Default trauma_power=2.0 ensures quick decay; accessibility toggle disables entirely |
| FastNoiseLite not available in Godot 4.7.1 | Very Low | FastNoiseLite is a built-in Godot 4 class since 4.0 |
| Performance hit from noise sampling | Very Low | 3× get_noise_2d() per frame is trivial |
| Camera transform drift over time | Low | Reset to `_original_camera_transform` each frame before applying offset |
