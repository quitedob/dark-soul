# 2026-07-30 — Critical Bug Fixes: Locale Freeze, Voice Stealing, Mesh Churn, Phase Skip & Timer Leak

### Scope

Fixed 8 critical bugs identified during post-restructuring code review across 6 files: locale freeze at class-load (`localization.gd`), race condition between monitoring and collision-shape setup (`combat_area.gd`), double ember recovery from signal + direct call (`lost_echo.gd`), crash when node freed mid-tween await (`lost_echo.gd`), voice stealing always from index 0 (`procedural_audio.gd`), per-frame `SurfaceTool.commit()` GPU mesh allocation (`player_visuals.gd`), guardian phase transition skip on large hits (`enemy.gd`), and repeated timer creation without cancellation (`enemy.gd`).

### Bug #1 — Locale Frozen at Class-Load (`localization.gd:86`)

`TranslationServer.get_locale()` used as a GDScript default parameter value is evaluated once at class-load time, freezing the locale permanently. Changed `text()` signature from `locale: String = TranslationServer.get_locale()` to `locale: String = ""`, resolving the effective locale at call-time:

```gdscript
static func text(source: String, locale: String = "") -> String:
	var effective_locale: String = locale if not locale.is_empty() else TranslationServer.get_locale()
	if normalize_locale(effective_locale) == &"zh_CN":
		return String(ZH_CN.get(source, source))
	return source
```

### Bug #2 — Race Condition: Monitoring Before Collision Shape (`combat_area.gd:17`)

`_ready()` set `monitoring = true` before `configure()` had created the `CollisionShape3D`, causing `body_entered` to potentially fire against an unconfigured collision shape. Fixed by deferring `monitoring = true` to `begin_swing()` — `_ready()` now only sets `monitorable = false` and connects the signal. Monitoring is activated only after `configure()` has attached the shape.

### Bug #3 — Double Ember Recovery (`lost_echo.gd:54`)

`_recover()` both emitted the `recovered` signal AND directly called `player.recover_embers(amount)`, causing double recovery because `game_world.gd` already wired the signal to call `recover_embers`. Removed the direct call — only the signal is emitted now.

### Bug #4 — Tween Crash After Free (`lost_echo.gd:64`)

`await tween.finished` followed by `queue_free()` would crash if the node was freed externally during the await. Added `is_instance_valid(self)` guard both before the await (early return if already invalid) and before `queue_free()`.

### Bug #5 — Voice Stealing Always Index 0 (`procedural_audio.gd:35`)

When no idle `AudioStreamPlayer` voice was available, `play_cue()` always stole from `players[0]`, causing the first voice channel to be interrupted repeatedly while other channels sat idle after use. Added round-robin `_next_voice` counter that increments on each steal, distributing theft evenly across all 6 voice channels:

```gdscript
var player := players[_next_voice % players.size()]
for candidate in players:
	if not candidate.playing:
		player = candidate
		break
if player.playing:
	player.stop()
	_next_voice += 1
```

### Bug #6 — Per-Frame Mesh Allocation (`player_visuals.gd:258`)

`_build_trail_ribbon()` created a new `SurfaceTool` and called `st.commit()` (which allocates a new `ArrayMesh`) every frame the weapon trail was active — producing massive GPU allocation pressure. Fixed by caching both the `SurfaceTool` and an `ArrayMesh` as member variables (`_trail_surface_tool`, `_trail_array_mesh`), calling `clear()` / `clear_surfaces()` each frame, and reusing the same objects:

```gdscript
if _trail_surface_tool == null:
	_trail_surface_tool = SurfaceTool.new()
	_trail_array_mesh = ArrayMesh.new()
_trail_surface_tool.clear()
_trail_array_mesh.clear_surfaces()
_trail_surface_tool.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
# ... build geometry ...
_trail_surface_tool.commit(_trail_array_mesh)
_player.weapon_trail.mesh = _trail_array_mesh
```

### Bug #7 — Guardian Phase Skip on Large Hit (`enemy.gd:182`)

Phase transition checks used `_current_phase() == 2` and `_current_phase() == 3` with `elif` internally — a single hit reducing health from >50% to <25% would skip phase 2 entirely. Fixed by:

- **`receive_hit()`**: Threshold-based checks using `get_health_ratio() <= PHASE_TWO_THRESHOLD` / `PHASE_THREE_THRESHOLD` instead of exact phase equality, with both on independent `if` (not `elif`) so they cascade.
- **`_trigger_phase_transition()`**: Changed internal checks to `new_phase >= 2 and not _phase_transition_played` / `new_phase >= 3 and not _phase_two_played` with `if`/`if` (not `if`/`elif`), so both transitions fire in sequence when health crosses two thresholds in one hit.

### Bug #8 — Timer Leak on Repeated Healing (`enemy.gd:233`)

`on_player_healing()` called `get_tree().create_timer(1.8)` every time the player healed without cancelling any previous timer, accumulating timer callbacks that would all set `move_speed = original_speed` in reverse order (last timer wins, but all still fire). Fixed with a counter-based invalidation pattern:

```gdscript
var _heal_speed_id := 0

# In on_player_healing():
_heal_speed_id += 1
var current_id := _heal_speed_id
var restore_timer := get_tree().create_timer(1.8)
restore_timer.timeout.connect(func():
	if is_instance_valid(self) and _heal_speed_id == current_id:
		move_speed = original_speed
)
```

Only the most recently created timer's callback passes the ID check; all stale callbacks become no-ops. `_heal_speed_id` is incremented on `reset_enemy()` to invalidate any pending timers from the previous spawn cycle.

### Validation

- All 4 modified files parse cleanly with Godot 4.7.1 (`--check-only`).
- Headless editor import completes without script or resource errors.
- All global class names (`AshenLocalization`, `PlayerVisuals`, etc.) register successfully.

### Files Changed

| File | Change |
|------|--------|
| `game/scripts/core/localization.gd` | Bug #1 — call-time locale resolution via `effective_locale` |
| `game/scripts/combat_area.gd` | Bug #2 — deferred monitoring to `begin_swing()` |
| `game/scripts/lost_echo.gd` | Bug #3 — removed direct `recover_embers()` call; Bug #4 — `is_instance_valid` guards around `await` + `queue_free()` |
| `game/scripts/procedural_audio.gd` | Bug #5 — round-robin `_next_voice` counter for voice stealing |
| `game/scripts/core/player_visuals.gd` | Bug #6 — cached `SurfaceTool` + `ArrayMesh` for trail ribbon reuse |
| `game/scripts/enemy.gd` | Bug #7 — threshold-based phase checks with cascade; Bug #8 — counter-based timer invalidation |

### Coordination

- These fixes address all 8 items from the post-restructuring code review.
- Bug #6 (mesh churn) is the highest-impact fix — it eliminates a per-frame `ArrayMesh` allocation that caused continuous GPU memory pressure during combat.
- The `_heal_speed_id` pattern in Bug #8 is a lightweight alternative to `SceneTreeTimer` cancellation (Godot's `SceneTreeTimer` has no `stop()` method).

---
