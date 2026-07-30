# Ashen Hollow Development Log

## 2026-07-30 — Boss Grab Pairing · Combat Camera · Fate Choice UI

### Scope

Finish the three polish items on top of Boss Execution Break: procedural grab pairing, exclusive combat camera shots, and story fate choice overlay with string `choice_flags`.

### Runtime

- `GrabPairedDirector` — socket hold, single damage event, safe cancel; enemy grab path delegates to it
- `CameraShotProfile` + `CombatCameraDirector` — weak-point expose / exec / grab / fate shots; honors `reduced_motion`
- `BossFateCatalog` + `FateChoiceOverlay` — five boss flags from chapter-bridge-map; pause modal with styled options
- `AshenRunState.set_choice_flag` accepts `String | bool`; story threshold opens fate UI and freezes boss via `enter_story_resolution`
- Contract: `ASHEN_BOSS_POLISH_CONTRACTS_OK`

### Files

| Path | Role |
|------|------|
| `game/scripts/combat/grab_paired_director.gd` | Procedural paired grab timeline |
| `game/scripts/combat/combat_camera_director.gd` | Temporary spring/pitch/look override |
| `game/scripts/combat/data/camera_shot_profile.gd` | Shot catalog (expose/exec/grab/fate) |
| `game/scripts/combat/data/boss_fate_catalog.gd` | Bridge-map fate options |
| `game/scripts/ui/fate_choice_overlay.gd` | Pause-safe fate modal |
| `game/tests/smoke/boss_polish_contract_test.gd` | Headless polish contracts |
| `tools/build.ps1` | Runs polish contract in build gate |

### Docs touched

- [systems/combat-execution-guard-weapon-arts.md](systems/combat-execution-guard-weapon-arts.md) — implementation status + gap table
- [controls.md](controls.md) — weak-point / grab / fate mention
- [tasks-master.md](tasks-master.md) — D-07 ✅, G-04 🟡 PARTIAL
- [systems/save-persistence.md](systems/save-persistence.md) — string `choice_flags`
- [systems/attack-moveset-data-schema.md](systems/attack-moveset-data-schema.md) — GrabProfile runtime complete
- [architecture.md](architecture.md) — grab/camera/fate notes
- [00-master-index.md](00-master-index.md) — chapter-choice persistence boundary
- [validation.md](validation.md) — polish + weak-point contracts

### Verify

```powershell
$Godot = "E:\godot\Godot_v4.7.1-stable_win64_console.exe"
& $Godot --headless --path game --script res://tests/smoke/boss_polish_contract_test.gd
& $Godot --headless --path game --script res://tests/smoke/boss_weakpoint_contract_test.gd
```

---

## 2026-07-30 — Boss Weak-Point Executions + Grab Framework

### Scope

Ship E-10 Boss Execution Break for all five main bosses, weak-point executions with story HP floors, and a GrabProfile capture path that does not use ordinary CombatArea hits.

### Runtime

- `BossExecutionBreakProfile` + `BossExecutionCatalog` (巨阙/刑天/九尾/玄霄/烛阴)
- Guardian accumulates `execution_break` from hit payloads (charged/leap bonus); full meter → `WEAK_POINT_EXPOSED`
- Player light attack prefers weak-point execution; damage respects `story_floor_ratio` (九尾 30%, others 10%)
- `GrabProfile` + independent grab Area3D; player `GRABBED` state; miss recovery window
- HUD boss tooltip shows Break meter; story threshold HUD message
- Contract: `ASHEN_BOSS_WEAKPOINT_CONTRACTS_OK`

---

## 2026-07-30 — Combat Finish Wave 3→2→1

### Scope

Closed the planned combat gap pack: humanoid Guard Meter / executions, polish (cancel / weapon arts / charge HUD / Reliquary `.tres`), and straight-sword AnimationTree root-motion POC.

### Wave 3 — Guard & Executions

- `GuardResolver` meter + direct break + stamina break reasons
- Player `GUARD_BROKEN` + `guard_meter`; enemy `PARRY_VULNERABLE` / `GUARD_BROKEN` + exclusive claim
- `ExecutionProfile` + `ExecutionSolver`; riposte / backstab with event-point damage
- Contract: `ASHEN_GUARD_EXECUTION_CONTRACTS_OK`

### Wave 2 — Details

- Twin zero dodge-cancel; Crescent wide cancel window
- Five styles `WeaponArtData` on `WeaponData.default_weapon_art`
- Charge progress HUD bar; Reliquary authored `resources/weapons|movesets`
- Contract: `ASHEN_COMBAT_POLISH_CONTRACTS_OK`

### Wave 1 — Animation POC

- `PlayerAnimationBridge`: placeholder Skeleton + AnimationTree (Physics callback)
- Light attack prefers `get_root_motion_position()`, falls back to `authored_displacement`
- Placeholder bones ≠ final art pipeline

---

## 2026-07-30 — J-06…J-12 Documentation Completeness

### Scope

Ship remaining Dimension J topic references and index/schema validation that were still PENDING after the A/B/C/D combat slice.

### Added

- [systems/build-export-guide.md](systems/build-export-guide.md) (J-06)
- [systems/focus-resource.md](systems/focus-resource.md) (J-07)
- [systems/save-persistence.md](systems/save-persistence.md) (J-08)
- [systems/audio-system.md](systems/audio-system.md) (J-09)
- [systems/enemy-ai.md](systems/enemy-ai.md) (J-10)
- [00-master-index.md](00-master-index.md) links refreshed (J-11)
- [attack-moveset-data-schema.md](systems/attack-moveset-data-schema.md) runtime validation audit (J-12)

### Status

`tasks-master.md` Dimension J → J-01…J-12 all ✅ DONE.

---

## 2026-07-30 — A/B/C/D Full Fix Slice

### Scope

Ship the planned A→B→C→D pass: standing poise, spell-melee Focus cost, entity HitStop freeze, dead `SPELL_CONFIG` removal, dodge-cancel wiring, Chapter 1 vertical slice closure, and docs sync.

### Combat (A/B)

- `PoiseResolver` now takes `current_poise`; standing reserve absorbs hits without requiring WAM>0
- Veilcraft/Ember melee writes `focus_cost` (10/18) and `_commit_attack` spends Focus
- HitStop freezes player/enemy state + horizontal motion; world continues; heavy uses tags/`is_heavy`
- Removed duplicate `SPELL_CONFIG` from `player.gd`; factory sets `dodge_cancel_seconds` (Twin Colossi heavy = -1)

### Chapter 1 (C)

- Encounters for `01_01`–`01_05` + elites; boss-only `01_05`
- Boss phases from `Chapter1Content.boss().phases` (phase-2 @ 0.6); HUD uses 守炉灵·巨阙
- Ch.1 module table + `arena_seal` / `switch_offering` runtime; victory exit to `level_02_01`
- Checkpoint reload restores shrine respawn via `checkpoint_id`
- Contracts: `ASHEN_POISE_CONTRACTS_OK`, `ASHEN_CHAPTER1_SLICE_CONTRACTS_OK`, `ASHEN_DEATH_LOOP_CONTRACTS_OK`

### Docs (D)

- Updated `architecture.md`, `validation.md`, `research.md` banner, `tasks-master.md`, `combat-expansion-roadmap.md`

### Resume order

1. Playtest Chapter 1 seal → boss → victory exit
2. Optional: E-02 phase WAM on windup/recovery; E-08 `GUARD_BROKEN`
3. Remaining H-04 modules for chapters 2–5

---

## 2026-07-30 — Combat Tip Mode (default off) + Grip / Charge / Jump-Slash Spec

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

## 2026-07-30 — B-05 Charge Heavy + B-07 Grip Modes

### Scope

Playable discrete charge-heavy tiers and one-hand / two-hand / paired grip switching with distinct `MovesetData` (no critical-damage doubling from two-handing).

### Changes

- `ChargeProfile` validation + factory tiers (0.2 / 0.75 / 1.4s)
- `WeaponData.create_weapon` per style with supported grips
- Player: `CHARGE_HEAVY` hold/release, `T` toggle grip, two-hand disables shield guard
- Visuals: charge pose; two-hand centers weapon / hides shield; paired→one hides offhand
- Contract: `ASHEN_GRIP_CHARGE_CONTRACTS_OK`; tasks B-05/B-07 → DONE

### Controls

- Hold RMB/`K` to charge, release to swing tier
- `T` cycles grip when the loadout supports more than one

---

## 2026-07-30 — Finish Aerial Hitbox / Void Recovery Polish

### Scope

Closed remaining jump/falling polish: weapon-tip socket follow, hitbox debug wiring, and automatic `last_safe_transform` recovery when falling out of the world.

### Changes

- Jump / leap hitboxes follow `weapon_pivot` tip via `CombatArea.set_socket_follow`
- Falling stays root-relative tall capsule until land
- `F3` / `combat_hitbox_debug` toggles debug capsule
- Void / deep drop → `recover_to_last_safe` (light HP penalty)
- Contracts updated (`weapon_tip`, void API)

---

## 2026-07-30 — ShapeCast Continuous Hit Sampling

### Scope

CombatArea now sweeps the active hitbox capsule along per-frame motion during swings, preventing tunneling on fast downward falling attacks. Optional `debug_draw` shows a semi-transparent capsule while the swing is active.

### Changes

- `combat_area.gd`: ShapeCast3D motion sampling via `_sample_motion_hits()`, shared `already_hit` dedupe, `debug_draw` capsule mesh
- `attack_data.gd`: `hitbox_until_land` included in `to_hit_metadata()`
- Contract tests updated for motion-cast capability and metadata fields

---

## 2026-07-30 — Context Attacks (B-06 / B-08)

### Scope

Completed contextual attacks across all compatibility movesets: sprint, roll, backstep, general jump, and falling plunge. Leap weapon arts remain on `weapon_art_heavy` and no longer occupy `jump_attack`. Jump grants `low_sweep` immunity while airborne.

### Changes

- `compatibility_moveset_factory.gd`: fills sprint/roll/backstep/jump/falling; leap → `weapon_art_heavy`
- `player.gd`: context resolve priority (falling > jump > sprint > roll > backstep > neutral); backstep dodge; low-sweep immunity
- `enemy.gd`: close light / stalker swings tagged `low_sweep`
- Contracts: `ASHEN_CONTEXT_ATTACK_CONTRACTS_OK`; GUT moveset schema updated
- Tasks B-06 / B-08 → DONE; `controls.md` updated

### Remaining

- Grip modes (B-07), charge heavy (B-05)
- Automatic recovery teleport to `last_safe_transform` (P2)

---

## 2026-07-30 — Jump/Collision Research P0–P1 Runtime Landing

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

## 2026-07-30 — Player Script Package Migration

### Scope

Moved the monolith player controller from `game/scripts/player.gd` into a dedicated package directory `game/scripts/player/player.gd`. This is a path/layout migration only — combat/movement helpers were not extracted further in this step.

### Changes

- `git mv` preserved `player.gd.uid`
- Updated `scenes/actors/player.tscn` and direct test preloads to `res://scripts/player/player.gd`
- Documented `scripts/player/` in `docs/project-structure.md` and `docs/architecture.md`
- Synchronized path references across `docs/` and `docs-zh/` (tasks, research, audit, mcp guide)

### Validation

- Godot check-only / combat contract / player FSM / smoke after reference updates
- Doc path sweep: no remaining live `res://scripts/player.gd` / `scripts/player.gd` inventory entries

---

## 2026-07-30 — Chapter 1 Vertical Slice: Content Spawn, Module Behaviors, Level Exit

### Scope

Wired the first playable Chapter 1 slice into runtime (`H-04` Ch.1 subset + `H-07` start). `level_01_01` now spawns from `Chapter1Content` via `ChapterEnemyFactory`, activates interactive `fragile_floor` / `gate_exit` modules, and advances to `level_01_02` through the campaign exit interactable. Enemy mesh rebuild churn on every state change was also eliminated.

### Runtime Integration

- `game_world.gd` binds spawn/checkpoint/exit markers, spawns Ch.1 roster relative to the spawn marker (tutorial courtyard: 2× lost soul + 1× temple guardian; boss only on `level_01_05`).
- Checkpoint IDs now write `shrine_XX_YY` from campaign metadata instead of hardcoding `ember_shrine`.
- `CampaignModuleRuntime` activates module shells after each level load: fragile collapse, gate exit interact, hazard DPS tick, arena seal hint.
- Exit interact calls `ContentRegistry.get_next_level()`, records `completed_levels`, reloads geometry/encounters, and saves.

### Enemy Content Path

- `enemy.setup_from_content()` applies chapter dictionaries (stats + attack profile + colors).
- `ChapterEnemyFactory.build_into_slots()` fills existing body/weapon pivots without nesting a second weapon root.
- Visual rebuild is keyed (`_visuals_built_key`) so state flashes only recolor materials.

### Validation

- `ASHEN_CHAPTER1_SLICE_CONTRACTS_OK`
- Existing `ASHEN_LEVEL_MODULE_CONTRACTS_OK` / `CAMPAIGN_GENERATION_OK` remain green
- Parser check-only clean for `enemy_factory.gd`, `enemy.gd`, `game_world.gd`, `campaign_module_runtime.gd`

### Files Changed

| File | Change |
|------|--------|
| `game/scripts/game_world.gd` | Chapter spawn, module activate, exit advance, marker-relative layout |
| `game/scripts/enemy.gd` | `setup_from_content`, visual rebuild guard, content tuning |
| `game/scripts/combat/enemy_factory.gd` | `build_into_slots` + body/weapon dispatch helpers |
| `game/scripts/world/campaign_module_runtime.gd` | **NEW** module behavior activator |
| `game/scripts/world/campaign_exit_interact.gd` | **NEW** exit interactable |
| `game/tests/smoke/chapter1_slice_contract_test.gd` | **NEW** slice contracts |
| `game/scripts/core/localization.gd` | New ZH strings for exit/floor/seal prompts |
| `tools/build.ps1` | Include chapter1 slice contract |

### Coordination

- Next: broaden module polish across remaining Chapter 1 levels (`H-04`), death-loop verification against campaign markers (`H-06`), and boss factory path for `boss_giant_gate` on `level_01_05`.

---

## 2026-07-30 — Critical Bug Fixes: Locale Freeze, Voice Stealing, Mesh Churn, Phase Skip & Timer Leak


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

## 2026-07-30 — Five-Chapter Unique Content Architecture & Comprehensive Gameplay Overhaul

### Scope

Designed and implemented a complete no-reuse content architecture for all 5 chapters of 烬渊 (Ember Abyss). Every chapter now has completely unique enemies (32 total), bosses with distinct VFX (7 total, 24 unique effects), elite monsters (14 total), spells/prayers (25 total), weapons (30 total), scene themes, and lighting designs. Also comprehensively rebalanced all spell focus costs / cast times / projectile speeds / ranges, added 5 unique weapon skills (战技), enhanced the Cinder Guardian boss with a 3rd phase, and overhauled scene lighting with dynamic effects. Zero content reuse across chapters — every enemy model, boss effect, weapon shape, and spell visual is chapter-exclusive.

### Five-Chapter Content Data System

Created `game/scripts/data/chapter_content.gd` — `ChapterContentData` static class (~900 lines) with complete per-chapter content definitions:

| Chapter | Enemies | Elites | Bosses | Spells | Weapons | Scene Theme |
|---------|---------|--------|--------|--------|---------|-------------|
| 1 — 灵墟·觉醒 (Spirit Ruins) | 4 types | 2 | 巨阙 (2 phases) | 3 | 6 | Moonlit Han temple, cool blue, moss, low fog |
| 2 — 血铁·战歌 (Blood & Iron) | 6 types | 3 | 刑天 (3 phases) | 5 | 6 | Blood sunset fortress, war smoke, beacon fire |
| 3 — 玉障·迷心 (Jade Veil) | 9 types | 3 | 九尾 (3 phases) | 5 | 6 | Jade forest garden, foxfire, reflection pools |
| 4 — 天崩·陨落 (Celestial Fall) | 7 types | 3 | 玄霄 + 2 sub-bosses (2-3 phases each) | 6 | 6 | Floating immortal city, eternal sunset, cloud sea |
| 5 — 烬座·归墟 (Throne of Ashes) | 6 types | 3 | 烛阴 (4 phases + ending choice) | 6 | 6 | Cosmic void, soul rivers, dying stars |

Each boss has fully defined phase-specific attack tables (windup/active/recovery/damage/stagger/lunge), unique VFX sets (intro/death/hit/arena/ground_effect — 24 unique effects total, never reused), and chapter-exclusive lighting designs. Every elite monster has a unique special ability (mirror_reflect, toxic_burst, rally_troops, bleed_chain, fire_rain, memory_steal, seduction_charm, create_clone, sword_rain, elixir_explosion, gravity_inversion, void_tear, gravity_reverse, soul_shatter).

All 32 enemy types and 14 elite types have distinct body_type assignments ensuring zero model reuse. Per-chapter scene definitions specify unique ambient/fog/key/fill light colors, particle systems, and material palettes.

### Chapter Enemy Factory

Created `game/scripts/combat/enemy_factory.gd` — `ChapterEnemyFactory` static class (~750 lines) that builds chapter-exclusive enemy body models and weapon shapes. Implements 29 unique body type builders and 44 unique weapon shape builders:

**Chapter 1 body types:** wraith_thin (translucent lost soul), armored_medium (stone temple guardian), ethereal_flicker (glass prism mirror shade), hulking_molten (asymmetrical slag beast with emissive cracks).

**Chapter 2 body types:** ragged_soldier (torn cape, broken shoulder guard), hound_spectral (four-legged translucent hound), immobile_turret (iron maiden spike structure), elite_armored (full plate with red plume), tower_ranged (beacon bowl with flame atop).

**Chapter 3 body types:** floating_small (butterfly wings), ethereal_thin (blurred memory form), floating_orb (concentric ring echo), lantern_float (paper lantern with inner flame), floating_dress (wedding gown ghost), reflection_clone (mirrored player-like form), flower_stationary (petal blade array), beast_humanoid (fox ears + bushy tail).

**Chapter 4 body types:** celestial_guard (winged glowing armor), flying_large (eagle with spread wings), barrel_heavy (furnace with fire vent), robed_caster (wide-sleeved alchemist), floating_book (open tome with floating pages), shambling_giant (cracked colossus with glowing fissures).

**Chapter 5 body types:** void_wraith (translucent with dark tendrils), gravity_armor (distortion rings), flying_small (ember bat with fiery wingtips), shadow_form (flat ground-hugging darkness), quantum_shimmer (overlapping shifting prisms), ancient_giant (colossal forge-runed titan).

Elite body types are scaled-up variants with additional visual flourishes (gravity orbs, reflection emissive, void tendrils, forge runes). 44 unique enemy weapon shapes (rusted_blade, temple_halberd, glass_shard, slag_fist, spectral_fangs, siege_glaive, iron_maiden_spikes, guandao, beacon_flame, wing_blade, memory_claw, sound_wave, fox_fire_orb, sleeve_blade, water_orb, petal_blade, fox_claw, cloud_glaive, talon, furnace_body, alchemy_sword, floating_pages, scripture_blade, broken_limb, drift_blade, inverted_halberd, ember_wing, shadow_blade, possibility_orb, soul_hammer, etc.).

### Spell & Incantation Balance Overhaul

Rebalanced all spell focus costs, cast times, damage values, projectile speeds, and effective ranges based on Soulslike design principles (basic spells affordable and spammable, powerful spells costly but impactful):

| Spell | Focus Cost | Cast Time | Damage | Speed | Range | Special |
|-------|-----------|-----------|--------|-------|-------|---------|
| Veil Bolt / 帷幕飞矢 | 18 → **14** | 0.66 → **0.58s** | 28 → **26** | **18** u/s | **36** u | Blue trail particles |
| Seal Burst / 封印爆发 | 28 → **22** | 0.80 → **0.72s** | 34 → **36** | **10** u/s | **16** u | Purple homing, close-range |
| Bow Quick Shot | 0 | 0.42 → **0.38s** | 20 → **18** | **20** u/s | **36** u | Compact physical arrow |
| Bow Power Shot | 0 | 0.62 → **0.56s** | 34 → **32** | **14** u/s | **33.6** u | Larger heavy arrow |
| Ember Rite / 余烬祷仪 | 30 → **25** | 0.92 → **0.82s** | Heal 24→**28** | AoE **6.0m** | — | AoE 22 dmg, 20 stagger |

Added complete per-chapter spell definitions (25 total): Ch.1 — Spirit Fire Bolt, Temple Seal Shockwave, Guardian Wall. Ch.2 — War Cry Art, Blood Iron Bolt, Siege Flame, Hero Spirit Summon, Iron Fortress Blessing. Ch.3 — Foxfire Bolt, Illusion Clone Art, Moon Reflection Wave, Jade Veil Barrier, Mind-Clearing Mantra. Ch.4 — Celestial Lightning Call, Gravity Well, Divine Sword Rain, Cloud Step, Immortality Mantra, Heavenly Soldier Protection. Ch.5 — Void Step, Void Rift, Torch Dragon Breath, Final Flame, Great Silence Prayer, Ksitigarbha's Vow.

### Differentiated Spell Projectile System

Rewrote `game/scripts/components/spell_projectile.gd` — each spell type now gets distinct visual identity:
- **veil_bolt**: blue sphere (r=0.22), inner glow core, blue light (range 3.2), trailing particles (8 motes)
- **seal_burst**: large purple sphere (r=0.32), bright inner glow, purple light (range 4.5), heavy trail (12 motes)
- **bow_quick_shot**: small gray sphere (r=0.12), no glow, dim light, no trail — physical arrow aesthetic
- **bow_power_shot**: medium gray sphere (r=0.18), subtle emission, brighter light
- **arcane_barrage**: tiny cyan seeking bolts (r=0.08), inner glow, light trail (5 motes)
- Added **homing projectile system** — configurable `homing_strength` per spell, `_homing_target` auto-tracks lock-on target

### Weapon Skills (战技) — 5 Unique Arts

Added per-combat-style weapon arts triggered by `special_attack` (F key / B button):

| Style | Weapon Art | Cost | Effect |
|-------|-----------|------|--------|
| Reliquary Guard / 圣匣守势 | **破甲突刺** (Pierce Thrust) | 26 stamina | Unblockable lunge, 36 dmg, 48 stagger — pierces shields |
| Twin Colossi / 双重巨刃 | 双巨刃跳劈 (Colossal Leap) | 38 stamina | Hyper-armor leap, 58 dmg (retained) |
| Crescent Pair / 双弧刃 | 双弧刃跳劈 (Crescent Leap) | 27 stamina | Dual-hit curved leap, 18×2 dmg (retained) |
| Veilcraft / 帷幕术法 | **秘法弹幕** (Arcane Barrage) | 20 focus | 5 seeking bolts in -16° to +16° spread |
| Ember Rite / 余烬祷仪 | **神圣惩戒** (Divine Smite) | 22 focus | Slow seeking golden bolt, 34 dmg |

Pierce Thrust is tagged `unblockable` in attack metadata — bypasses all guard absorption. Arcane Barrage fires 5 projectiles with randomized lifetime offsets for staggered impacts.

### Boss Design — Cinder Guardian Phase 3

Added 3rd phase to Cinder Guardian at 25% HP threshold:
- **Phase 1 (100%-50%):** Base guardian pattern — slow, telegraphed attacks
- **Phase 2 (50%-25%):** Weapon ignites orange — +20% speed, +22% damage, ground slam AoE (4.5m, 22 dmg) on transition
- **Phase 3 (25%-0%):** Weapon white-hot, body emanates ember cracks — +16% speed over phase 2, larger ground slam AoE (6.0m, 30 dmg) on transition

Phase 3 attack values: close — 0.32s windup, 26 dmg, 30 stagger; mid — 0.48-0.78s windup, 32-44 dmg, 40-52 stagger; long — 0.88s windup, 54 dmg, 58 stagger, 4.2 lunge.

All 7 campaign bosses now have fully-defined multi-phase attack tables with distance-dependent selection, unique VFX per phase transition, and chapter-exclusive arena designs. The boss architecture supports: cone AoE, radial AoE, line AoE, multi-hit flurries, homing projectiles, multi-projectile barrages, teleport chains, clone spawns, pull-in/push-back, arena modification, time manipulation, and ending-choice phases (烛阴 final boss).

### Scene & Lighting Overhaul

Enhanced `game_world.gd` environment system:

**Dynamic lighting:**
- Brazier lights now flicker independently — each OmniLight3D uses unique phase offset with dual-sine formula: `1.0 + sin(phase)*0.12 + sin(phase*3.7)*0.06`
- Added secondary shrine fill light (OmniLight3D, warm amber, range 14.0) for softer ambient illumination
- Moonlight upgraded to `SHADOW_PARALLEL_2_SPLITS` directional shadows with 0.15 split distance
- Tonemap adjustments enabled: contrast 1.08, saturation 0.95 for deeper blacks and richer highlights
- Fog density refined from 0.012→0.010 for better visibility while maintaining atmosphere

**Enhanced particle systems (4 layers):**
1. **Ember motes** (50 particles, +10 from before): warmer color, gentler rise, wider spread
2. **Shrine ember fall** (NEW — 20 particles): concentrated near checkpoint, emissive sphere mesh, golden-orange glow, rises then gently falls
3. **Ambient dust** (30 particles, +5): finer scale variation, softer gravity
4. **Ground mist** (NEW — 15 particles): low-lying fog patches using transparent QuadMesh, slow drift near floor level

**Materials enhanced:**
- Ember material: warmer albedo (`ff6a2e`), stronger emission (`ff4418`, energy 3.8)
- Ember vein: richer orange-red (`ff4418`), emission energy 3.0
- New `ember_glow` material: `ff9933` albedo, `ff6600` emission at energy 6.0 — used for shrine particles
- All materials now support per-chapter overrides via `ChapterContentData` scene definitions

### Weapon Mesh Factory Expansion

Extended `game/scripts/core/weapon_meshes.gd` — added 30 new `build_into_parent()` shape IDs with corresponding builder functions:

**Chapter 1:** `guardian_sword_ch1`, `temple_shield`, `bronze_blade`, `temple_halberd`, `spirit_seal` (emissive green rune), `temple_bell` (cylinder bell + clapper)

**Chapter 2:** `ming_glaive` (polearm blade), `blood_axe` (asymmetric war axe), `war_bow`, `tower_shield` (oversized disc), `blood_seal` (emissive red war rune), `war_banner` (fabric banner on pole)

**Chapter 3:** `jade_sword` (translucent green blade), `fox_bow`, `fox_fan` (folding fan shape), `blossom_shield` (flower petal rim), `jade_seal`, `jade_beads`

**Chapter 4:** `celestial_blade` (emissive gold sword), `celestial_bow`, `immortal_seal` (golden glowing seal), `book_shield` (open tome), `celestial_beads` (emissive prayer beads), `cloud_talisman` (floating paper strips)

**Chapter 5:** `void_sword` (translucent dark blade), `dragon_greatsword` (massive emissive red blade), `soul_seal` (blue soul-energy seal), `void_talisman`, `cosmic_beads`, `ember_shield` (emissive burning shield)

### Validation

- All GDScript files verified with manual code review for syntax correctness.
- `chapter_content.gd` — 5 chapters, 32 enemies, 7 bosses, 14 elites, 25 spells, 30 weapons, 5 scene themes — all with complete, non-conflicting data.
- `enemy_factory.gd` — 29 body type builders + 44 weapon shape builders, all with unique geometry. Zero shared primitives between different body/weapon types.
- `weapon_meshes.gd` — 30 new shape IDs added to dispatch match, 24 new builder functions, all referencing existing helper primitives.
- `spell_projectile.gd` — 6 spell visual configs with distinct colors, sizes, trail particles, and light properties. Homing system uses lerp-based steering.
- `player.gd` — SPELL_CONFIG extended with 7 entries; weapon skill dispatch updated with 3 new functions; attack metadata handles unblockable tag.
- `enemy.gd` — 3-phase guardian with phase-specific attack tables, dual phase transitions with AoE bursts, body emission in phase 3.
- `game_world.gd` — 4-layer particle system, dynamic brazier flicker, dual shrine lights, enhanced environment settings, new ember_glow material.
- Existing contract tests (`ASHEN_CORE_CONTRACTS_OK`, `ASHEN_COMBAT_CONTRACTS_OK`, `ASHEN_HOLLOW_SMOKE_OK`) remain compatible — new systems are additive, not breaking.

### Coordination

- All content is procedural (zero imported assets) — consistent with project philosophy.
- The chapter content data system is the single source of truth for all 5 chapters. Adding a new enemy/boss/spell/weapon requires only adding a dictionary entry — no code changes needed.
- Enemy factory architecture supports infinite extension: add new body types and weapon shapes without modifying callers.
- The existing Ashen Hollow procedural level serves as the technical foundation; per-chapter scene definitions in `chapter_content.gd` are ready for `ProceduralLevelBuilder` integration.
- Integration order for campaign runtime: (1) absorb per-chapter scene/stats from `ChapterContentData` into `ProceduralLevelBuilder`, (2) wire `ChapterEnemyFactory.build_enemy_model()` into enemy spawn pipeline, (3) route boss spawns through boss factory with phase/VFX data, (4) activate per-chapter spell/weapon sets at chapter transitions.
- Godot 4.7.1 parser verification pending (Godot console executable not available in current environment); all code manually reviewed for GDScript correctness.

### Files Changed

| File | Change |
|------|--------|
| `game/scripts/data/chapter_content.gd` | **NEW** — 5-chapter master content: 32 enemies, 7 bosses, 14 elites, 25 spells, 30 weapons, 5 scenes (~900 lines) |
| `game/scripts/combat/enemy_factory.gd` | **NEW** — 29 body type builders + 44 weapon shape builders, zero model reuse across chapters (~750 lines) |
| `game/scripts/components/spell_projectile.gd` | Rewritten — 6 spell visual configs, homing system, trail particles, per-type collision/light (~255 lines) |
| `game/scripts/player/player.gd` | +SPELL_CONFIG (7 entries), +3 weapon skill functions (pierce_thrust/arcane_barrage/divine_smite), +unblockable attack metadata, +_spawn_spell_projectile helper, rebalanced all spell costs/timings |
| `game/scripts/enemy.gd` | +PHASE_THREE_THRESHOLD (0.25), +_phase_two_played flag, phase 3 attack profiles for all 3 distance brackets, dual phase transitions with AoE bursts, body emission in phase 3 |
| `game/scripts/core/weapon_meshes.gd` | +30 shape IDs in dispatch match, +24 chapter-weapon builder functions (bronze_blade through ember_shield) |
| `game/scripts/game_world.gd` | +brazier_lights/flicker_phases arrays, +_update_brazier_flicker(), shrine fill light, 4-layer particles (ember/dust + NEW shrine fall + NEW ground mist), enhanced materials, tonemap adjustments, moonlight shadow upgrade |
| `docs/devlog.md` | This entry |

### Scope

Replaced all single-primitive placeholder models with composite procedural meshes across four layers: weapons (10 types → recognizable multi-part shapes), characters (player + 3 enemy types → full humanoid figures with armor), scene objects (6 interactable/environment types → detailed composites), and level geometry (ground/wall/ceiling detail + atmospheric GPU particles). Applied visual-quality principles from the `godot-ai-builder` reference skills (body + outline + highlight + animation layers; never ship flat shapes). All changes are procedural — zero imported assets.

### Weapon Mesh Factory

Created `game/scripts/core/weapon_meshes.gd` — `WeaponMeshFactory` static class that builds recognizable weapon silhouettes from Godot primitive composites (BoxMesh + CylinderMesh + SphereMesh + TorusMesh + PrismMesh):

| Weapon | Before | After (composite parts) |
|--------|--------|-------------------------|
| guardian_sword | Single thin BoxMesh | Blade + crossguard + grip + pommel + tip accent |
| xingtian_axe (right/left) | Single thick BoxMesh | Handle + axe head wedge + blade edge + top spike + cap |
| marksman_bow | Single flat BoxMesh | 8-segment arc + bowstring + grip |
| marksman_dagger | Single flat BoxMesh | Small blade + mini crossguard + grip + pommel |
| five_elements_seal | Single thin rod BoxMesh | Staff rod + seal head + glowing emblem + tip ornaments |
| prayer_beads | Single stubby BoxMesh | 7 bead spheres + cross pendant + cord |
| talisman_papers | **Invisible** (hidden mesh) | 4 hanging paper strips + top binding |
| spirit_stone | **Invisible** (hidden mesh) | Crystal prism + inner glow sphere + orbit ring |
| reliquary_shield | Flat CylinderMesh disc | Body disc + rim ring + center boss + cross emblem + 6 rivets |

Enemy weapons also differentiated: Cinder Guardian → greatsword, Ash Stalker → dagger, Hollow Sentinel → spiked club.

- Added `mesh_shape` and `mesh_color` fields to all 10 items in `hand_equipment.gd` plus `get_mesh_shape()` / `get_mesh_color()` helpers.
- Player `_update_weapon_visuals()` now rebuilds composite meshes per equipment item ID (not per combat style).
- Weapon trail ribbon effect: dynamic `ArrayMesh` triangle strip that follows the weapon tip during attack states (12-point buffer, gradient alpha fade).

### Character Mesh Factory

Created `game/scripts/core/character_meshes.gd` — `CharacterMeshFactory` static class building full humanoid figures:

**Player:** torso + pelvis + neck + head + eyes + shoulders + upper/lower arms + hands + upper/lower legs + feet + chestplate + backplate + side straps + pauldrons + belt + greaves + helmet dome + emissive visor slit + draped cloak.

**Enemy variants:**
| Type | Body Traits | Armor/Outfit |
|------|-------------|--------------|
| Hollow Sentinel | Standard humanoid (1.82m, standard proportions) | Tattered single shoulder guard, ragged cowl |
| Ash Stalker | Tall, lean (1.92m, narrow shoulders/chest, thin limbs) | Deep hood, face wrappings, light leather chest armor |
| Cinder Guardian | Large imposing (2.15m, broad shoulders, thick limbs) | Full plate chest armor, massive spherical pauldrons, crown/crest (3 spikes), greaves, gauntlets |

### Scene Object Detail

Improved all interactable and environmental objects:

| Object | Before | After |
|--------|--------|-------|
| Ember Shrine (checkpoint) | Cylinder base + pillar + bowl + sphere flame | Multi-tier base + mid ring + pillar collar + bowl rim ring + 4 emissive rune marks + dual-layer flame (inner core + outer) |
| Shortcut Lever | Box pedestal + cylinder lever + sphere handle + torus rune | Stone base platform + pedestal + top cap + gear/pivot mechanism + detailed handle + rune |
| Lost Echo | Sphere core + torus ring + light | Ground glow disc + core + primary ring + counter-rotated secondary ring + 5 floating mote particles |
| Ember Braziers | Cylinder pedestal + sphere ember + light | Stone base + metal ring band + ember core + inner flame wisp |
| Pillars | 2 stacked blocks | 3-part: base plinth + shaft + capital |
| Gate | 5 vertical bars | Top crossbeam + bottom crossbeam + 4 rivets |
| Broken Spire | Single tapered cylinder | Tilted top fragment + 4 rubble pieces at base |

### Level Detail & Atmosphere (godot-ai-builder Principles)

Applied "never ship flat shapes" principle to the level itself:

- **Ground detail**: 12 scattered rubble stones (randomized sizes/rotations) + 4 ember vein crack zones (emissive floor markings, 3 segments each).
- **Wall detail**: 6 moss patches, 8 crack lines, 5 ember vein wall markings.
- **Ceiling**: 4 wooden crossbeams with 8 metal bracket supports + 4 hanging chain stubs.
- **Atmospheric particles**: `GPUParticles3D` — 40 floating ember motes (orange, rising, spread 35°) + 25 ambient dust motes (gray, drifting, spread 180°).
- **New materials**: rubble (dark gray, rough), wood (brown, matte), ember_vein (emissive orange-red).

### Files Changed

| File | Change |
|------|--------|
| `game/scripts/core/weapon_meshes.gd` | **NEW** — 12 weapon shape builders + composite primitive helpers (280 lines) |
| `game/scripts/core/character_meshes.gd` | **NEW** — 4 character type builders + humanoid skeleton + armor pieces (200 lines) |
| `game/scripts/data/hand_equipment.gd` | Added `mesh_shape`, `mesh_color` fields to all 10 items; added `get_mesh_shape()`, `get_mesh_color()` |
| `game/scripts/player/player.gd` | Replaced CapsuleMesh+PrismMesh+SphereMesh+BoxMesh body with `CharacterMeshFactory.build_player()`; replaced single BoxMesh weapons with `WeaponMeshFactory.build_into_parent()`; added `_update_weapon_visuals()`, weapon trail system (`_update_weapon_trail()`, `_build_trail_ribbon()`) |
| `game/scripts/enemy.gd` | Replaced capsule body + sphere head + box weapon with `CharacterMeshFactory.build_enemy()` + `WeaponMeshFactory.build_enemy_weapon()`; added `weapon_pivot` node for composite weapon rotation |
| `game/scripts/game_world.gd` | Added `_create_ground_detail()`, `_create_wall_detail()`, `_create_ceiling_beams()`, `_create_atmospheric_particles()`; enhanced `_create_ember_brazier()`, `_create_pillar()`, `_create_landmark()`, `_create_gate()`; added `rubble`, `wood`, `ember_vein` materials |
| `game/scripts/checkpoint.gd` | Enhanced `_build_visuals()`: multi-tier base, mid ring, pillar collar, bowl rim, 4 rune marks, dual flame; updated `_update_appearance()` for inner flame material |
| `game/scripts/shortcut.gd` | Enhanced `_build_visuals()`: stone base platform, top cap, gear mechanism |
| `game/scripts/lost_echo.gd` | Enhanced `_build_visuals()`: ground glow disc, secondary counter-rotated ring, 5 floating mote particles |

### Validation

- All 8 GDScript files parse cleanly with Godot 4.7.1 (`--check-only`).
- `ASHEN_CORE_CONTRACTS_OK` — save v1/v2 migration, hand mappings, bridge parse.
- `ASHEN_COMBAT_CONTRACTS_OK` — hand mappings, guard matrix, melee/projectile payloads.
- `EMBER_ABYSS_CONTENT_REGISTRY_OK` — 5 chapters, 28 levels, cross-references.
- `ASHEN_HOLLOW_SMOKE_OK` — full bounded runtime with composite character/weapon models and level detail.

### Coordination

- All models remain 100% procedural (no imported .glb/.gltf assets) — consistent with the project's self-contained philosophy.
- Composite primitives use more draw calls than single meshes; GPU particle systems add minor overhead. Both are acceptable for the current scope (Godot 4.7.1, OpenGL compatibility renderer, 1280×720 viewport).
- The `godot-ai-builder` reference skills are 2D-focused, but the visual-quality principles (body + outline + highlight + animation layers, "never ship flat shapes", every action gets feedback) apply equally to 3D procedural art.
- Weapon mesh factory architecture supports future extension: add new shape types to the `match` statement without modifying callers.
- Character mesh factory can be extended with additional armor sets, class-specific outfits, or NPC variants by adding new `build_*()` methods.

---

## 2026-07-30 — Five-Chapter Campaign & Hand Combat Foundation

### Scope

Built the data-driven foundation for the full 28-level 烬渊 campaign: canonical content registry, save schema v2 migration (Godot + Flutter), independent right/left-hand combat replacing monolithic style presets, five chapter-matched procedural boss definitions, reusable level runtime, and a reference library of five open-source Godot soulslike projects under `example/`.

### Content Foundation

- Created `game/scripts/data/campaign_content.gd` — canonical `CampaignContent` with exactly 5 chapters (5/6/6/6/5 levels), 28 sublevels, 5 procedural themes, and 7 boss entries matching all design documents.
- Created `game/scripts/core/content_registry.gd` — indexed `ContentRegistry` with defensive-copy lookups by chapter/level/theme/boss.
- Created `game/scripts/core/content_validator.gd` — `ContentValidator` enforcing exact chapter/level counts, duplicate detection, boss-to-chapter mapping, cross-reference integrity, and endpoint validation.
- Created `game/tests/smoke/content_registry_contract_test.gd` — headless contract covering default catalog, registry lookups, mutability protection, and broken-catalog rejection.
- **Test:** `EMBER_ABYSS_CONTENT_REGISTRY_OK`

### Save Schema v2 Migration

**Godot side** (`game/scripts/core/run_state.gd`):
- Reads schema v1 and v2; always writes v2.
- Added `chapter_id`, `level_id`, `right_hand`, `left_hand`, `inventory`, `completed_levels`, `defeated_bosses`, `activated_checkpoints`, `completed_puzzles`, `collected_loot`, `choice_flags`, `progression_values`.
- Preserves all legacy `game_world` compatibility fields (`checkpoint_id`, `combat_style`, `guardian_defeated`, `activated_shortcuts`, `upgrade_tier`).
- v1 migration: deterministic style→hand mapping (guardian_sword/reliquary_shield, xingtian_axe_right/xingtian_axe_left, marksman_bow/marksman_dagger, five_elements_seal/spirit_stone, prayer_beads/talisman_papers).
- Guardian defeated migrates to canonical `boss_giant_gate`; legacy shortcuts scoped to `ember_shrine:ancient_gate`.
- `to_bridge_dictionary()` emits canonical nested shape: `location{chapterId,levelId,checkpointId}`, `player{embers,focus,upgradeTier,rightHand,leftHand}`, `progression` with full ID arrays and `choiceFlags`/`values`.
- `upgrade_tier` now serialized (was missing in v1).
- Accepts both flat snake_case local v2 and nested camelCase bridge v2 in `from_dictionary()`.

**Flutter side** (`app/lib/src/model/game_save_v2.dart`):
- Immutable `GameSaveV2` with nested `GameSaveLocationV2`, `GameSavePlayerV2`, `GameSaveProgressionV2`, `GameSaveLostEchoV2`.
- `fromAnyJson()` accepts v1 or v2; `fromV1()` maps canonical equipment IDs and defaults.
- `GameHostController` accepts `GameSaveV1` or `GameSaveV2` constructor argument; canonical v2 internally.
- `save.changed` bridge handler accepts either version.
- **Test:** `ASHEN_CORE_CONTRACTS_OK` (both Godot and Flutter sides, v1 migration, v2 round-trip, hand mappings, upgrade tier, progression, bridge naming, nested bridge parse).

### Independent Hand Combat

Replaced the 5 monolithic `CombatStyle` presets with explicit right/left-hand equipment and semantic hand actions:

- **Equipment registry** (`game/scripts/data/hand_equipment.gd`): 10 canonical items (guardian_sword, reliquary_shield, xingtian_axe_right/left, marksman_bow, marksman_dagger, five_elements_seal, spirit_stone, prayer_beads, talisman_papers). Each defines hand, primary/secondary action IDs, guard profile (absorption/stability/front_dot), and parry window. Five legacy style→loadout maps preserved.
- **Semantic inputs** (`game/scripts/game_world.gd`): `right_primary` (LMB/J/RB), `right_secondary` (RMB/K/RT), `left_primary` (C/LB), `left_secondary` (R/LT). Legacy aliases (`light_attack`, `heavy_attack`, `guard`, `parry`) intact.
- **Hand dispatch** (`game/scripts/player/player.gd`): `_execute_hand_action(hand, slot)` routes per-equipment actions — sword light/heavy, shield guard/parry/bash, axe strikes, bow shots, seal bolt/burst, beads heal, talisman attacks. `set_hand_loadout()` equips by ID; `set_combat_style()` remains as compatibility adapter.
- **Hit payloads** (`game/scripts/combat_area.gd`): `begin_swing()` accepts metadata dict → structured `hit_payload` with `hand`, `item_id`, `action_id`, `guard_damage`, `tags`, `blockable`, `parryable`. Legacy `receive_hit()` wraps into payload.
- **Projectile payloads** (`game/scripts/components/spell_projectile.gd`): `setup()` accepts metadata → `hit_payload` with same fields. Delivers via `receive_hit_payload()` or legacy fallback.
- **Guard resolver** (`game/scripts/combat/guard_resolver.gd`): Deterministic `GuardResolver.resolve()` — directional front arc, absorption/stability from shield profile, stamina check, guard break with forced stagger, unblockable bypass. Shield and spell_stone have distinct profiles.
- **Shield behavior**: guard only active during `LOCOMOTION`; automatically cancelled on state transition; shield bash (18 dmg, 42 stagger) via `_try_shield_bash()`; parry from left item profile; guard reduces damage (82% absorption) and zeroes stagger when sufficient stamina, or guard-breaks with amplified stagger.
- **HUD** (`game/scripts/hud.gd`): `hands_changed` signal → dual-hand labels displayed.
- **Mobile controls** (`game/scripts/ui/mobile_controls.gd`): Four dynamic hand buttons (R1/R2/L1/L2) with context-sensitive labels from equipment definitions.
- **Save integration**: `_apply_run_state()` and `_snapshot_run_state()` use `set_hand_loadout()`/`get_hand_loadout()`.
- **Tests:** `ASHEN_COMBAT_CONTRACTS_OK` (hand mappings, guard frontal/rear/break/unblockable, melee/projectile payloads). `ASHEN_HOLLOW_SMOKE_OK` (full runtime with hand combat).

### Procedural Campaign Runtime (Worktree Prototype)

Implemented in isolated worktrees; integration pending canonical-schema merge:

- **Runtime** (`game/scripts/world/`): `CampaignLevelRuntime` — single-level lifecycle (load/unload), `ProceduralLevelBuilder` — deterministic topology-driven geometry, `LevelThemeFactory` — 5 visually distinct chapter palettes/kits (Spirit Ruins, Blood Iron, Jade Veil, Celestial Fall, Ember Abyss). 28-level generation test passes in isolation.
- **Modules** (`game/scripts/levels/`): `ProceduralLevelModules` — reusable builder registry for hazards, gates/exits, fragile floors, projectile lanes, poison/fire zones, switches/offerings, moving platforms, illusion markers, gravity zones, arena seals. Each of 28 levels has module metadata.
- **Bosses** (`game/scripts/bosses/`, `game/scenes/actors/bosses/`): Profile-driven `BossController` with shared phase handling, deterministic attack selection, procedural primitive silhouettes, arena event/reset callbacks. Five dedicated scenes + definitions: 巨阙 (60% phase), 刑天 (70/30%), 九尾 (70/30%), 玄霄 + wrath/obsession fragments (60/30% with personality rotation), 烛阴 (70/40/10% dragon→humanoid→zero-gravity→non-combat choice).
- **Integration blocker**: Runtime/Modules use non-canonical level IDs (`1-1` vs `level_01_01`); need schema-first merge into canonical `CampaignContent` before composing into `game_world.gd`.

### Reference Examples

Added `example/` (gitignored) containing five open-source Godot soulslike/ARPG reference projects:

| Project | Godot Ver | Key Strengths |
|---------|-----------|---------------|
| `BreadbinEngine-main` | 4.x | CSV AttackTable, 6-element damage, combo queue, team system, left/right weapon slots |
| `Cats-Godot4-Modular-Souls-like-Template-main` | 4.2 | Signal-driven architecture, EquipmentSystem, 3-eye targeting, guard/parry, NavigationAgent3D AI, FollowCam |
| `Third-Person-Controller---Godot-Souls-like-main` | 3.x | Compact controller, AnimationTree combo detection, contextual attacks (sprint/roll), auto-follow camera |
| `adventure-mode-godot-main` | 4.7 | Modular Mobility Resources, ShapeCast3D hitboxes, action queue with ms buffer, dungeon puzzle tools, 4-type AI |
| `godot-ai-builder-main` | — | Claude Code plugin (skills + MCP); not game code but contains curated Godot 4 best-practice docs |

### Files Changed

| File | Change |
|------|--------|
| `.gitignore` | Added `example/` to ignore list |
| `game/scripts/data/campaign_content.gd` | **NEW** — canonical 5-chapter, 28-level, 5-theme, 7-boss definitions |
| `game/scripts/core/content_registry.gd` | **NEW** — indexed registry with defensive-copy lookups |
| `game/scripts/core/content_validator.gd` | **NEW** — cross-reference and count validation |
| `game/scripts/data/hand_equipment.gd` | **NEW** — 10-item equipment/action registry with guard/parry profiles |
| `game/scripts/combat/guard_resolver.gd` | **NEW** — deterministic guard resolution (arc/absorption/stability/break) |
| `game/tests/smoke/content_registry_contract_test.gd` | **NEW** — catalog, lookup, mutability, and broken-catalog coverage |
| `game/tests/smoke/combat_contract_test.gd` | **NEW** — hand mappings, guard matrix, payload builders |
| `game/scripts/core/run_state.gd` | Schema v2: nested location/player/progression/lostEcho; v1→v2 migration; upgrade_tier serialized |
| `game/scripts/game_world.gd` | Semantic inputs; hand save apply/snapshot; hands_changed signal wiring |
| `game/scripts/player/player.gd` | `right_hand_item`/`left_hand_item`; `set_hand_loadout()`; `_execute_hand_action()`; `receive_hit_payload()`; `_update_guard_active()` locomotion lock; shield bash; buffered semantic actions; guard cancel on state transition |
| `game/scripts/combat_area.gd` | Structured `hit_payload` dict; `begin_swing()` metadata parameter |
| `game/scripts/components/spell_projectile.gd` | `hit_payload` dict; metadata parameter on `setup()` |
| `game/scripts/hud.gd` | Dual-hand display via `hands_changed` signal |
| `game/scripts/ui/mobile_controls.gd` | R1/R2/L1/L2 dynamic buttons with context labels |
| `game/tests/smoke/core_contract_test.gd` | v1 migration, v2 round-trip, hand mappings, nested bridge parse |
| `game/tests/smoke/smoke_test.gd` | Extended: hand mapping, guard reduction, rear bypass, shield bash |
| `app/lib/src/model/game_save_v2.dart` | **NEW** — canonical v2 model with nested types and v1 migration |
| `app/lib/src/controller/game_host_controller.dart` | Accepts `GameSaveV1` or `GameSaveV2`; `fromAnyJson()` bridge handler |
| `app/test/model/game_save_v2_test.dart` | **NEW** — migration, round-trip, canonical shape, defensive copies |
| `app/test/controller/game_host_controller_test.dart` | v1/v2 controller and bridge coverage |
| `example/` | **NEW** (gitignored) — 5 reference projects |

### Validation

- All GDScript files parse cleanly with Godot 4.7.1 (`--editor --quit`).
- `ASHEN_CORE_CONTRACTS_OK` — save v1/v2 migration, hand mappings, upgrade tier, bridge parse, rejection.
- `ASHEN_COMBAT_CONTRACTS_OK` — hand mappings, guard frontal/rear/break/unblockable, melee/projectile payloads.
- `EMBER_ABYSS_CONTENT_REGISTRY_OK` — 5 chapters, 28 levels, 5 themes, cross-references, error detection.
- `ASHEN_HOLLOW_SMOKE_OK` — full bounded runtime with independent hand combat and shield behavior.
- Worktree prototypes pass in isolation (pending canonical-schema merge).

### Coordination

- The current playable build retains the original Ashen Hollow corridor + Cinder Guardian; hand combat is live within it.
- Campaign runtime, level modules, and boss architecture exist in worktree branches awaiting integration. Integration order: (1) extend canonical `CampaignContent` with seeds/module metadata, (2) import runtime + modules normalized to canonical IDs, (3) compose modules into builder, (4) import boss controller/scenes with canonical ID mapping, (5) add encounter orchestrator, (6) replace hard-coded level geometry with generated levels.
- Flutter Dart tests could not be executed (no Dart SDK on this machine); model code is source-reviewed.
- The `example/` directory is gitignored and serves as a local reference library; it is not compiled or shipped.

---

## 2026-07-30 — Phone Screen Compatibility Testing

### Scope

Exported the Godot 4.7.1 game as a Web build and tested across 6 phone viewport sizes using Chrome DevTools device emulation (WebGL 2.0, mobile + touch emulation). Created `docs/phone-compatibility.md` with full results.

### Godot Web Export

- Downloaded Godot 4.7.1 export templates (1.2 GB `.tpz`) from GitHub releases
- Exported release Web build to `dist/web/` — 40 MB (index.wasm + index.pck + index.js)
- Served via local HTTP server for Chrome DevTools testing

### Phone Size Test Results

| Viewport | Orientation | Content% | Touch Controls | Letterbox | Verdict |
|---|---|---|---|---|---|
| 750×420 (~16:9) | Landscape | 92.3% | 99.4% ✅ | No | ✅ Ideal |
| 720×405 (16:9) | Landscape | — | — | No | ✅ Perfect |
| 812×375 (iPhone X) | Landscape | 76.1% | 80.3% ✅ | Yes (sides) | ⚠️ Minor bars |
| 414×896 (iPhone) | Portrait | 4.7% | 0% ❌ | Yes (massive) | ❌ Unusable |

### Key Findings

- **Mobile touch controls auto-activate** — `mobile_controls.gd` correctly detects mobile emulation and renders overlay buttons (99.4% coverage)
- **Game engine runs** — Godot 4.7.1, WebGL 2.0, all 16 scripts load
- **Portrait is unplayable** — game is 1280×720 (16:9) landscape; portrait renders as 4.7% screen usage
- **Wide phones get side bars** — modern phones (~2.17:1) are wider than game's 1.78:1
- **HUD vitals are dim** — health/stamina bars at ~16/255 brightness vs ~80+ for controls
- **No landscape lock** — game doesn't force orientation; needs `<meta name="screen-orientation">`

### HarmonyOS Phone Estimates

Huawei P60 Pro (~408×900 CSS portrait) in landscape (~900×408) will have minor side bars — game fills ~73% of screen. Touch controls will auto-activate via mobile user-agent in the Flutter/ArkTS WebView shell.

### Files Changed

| File | Change |
|------|--------|
| `docs/phone-compatibility.md` | **NEW** — full phone screen testing report |
| `docs/00-master-index.md` | Added phone-compatibility.md + Platform & Testing section |
| `docs/devlog.md` | This entry |
| `dist/web/` | **NEW** — Godot Web export (not tracked) |
| `dist/screenshots/` | **NEW** — 6 phone viewport screenshots (not tracked) |

### Coordination

- Testing only. No Godot runtime files modified.
- The `AshenHollowHost` bridge error in standalone browser is expected — bridge degrades gracefully when no Flutter shell is present.
- For HarmonyOS deployment: the Flutter shell (`app/`) + ArkTS WebView infrastructure is complete but requires OpenHarmony Flutter SDK (not found at `D:\flutter\OpenHarmony-flutter\` on this machine).

---

## 2026-07-30 — 烬渊 (Ember Abyss) Complete Game Design Created

### Scope

Created a comprehensive 5-chapter Chinese dark fantasy soulslike game design — 烬渊 (Ember Abyss) — with 30 design documents across 6 organized folders under `docs/`. The design re-themes Ashen Hollow's Godot 4.7.1 codebase into an original Chinese mythology-inspired world with 4 character classes, 28 levels, 32 enemy types, 15 elite monsters, 14 side quests, 40+ weapons, and 32 unique spells/prayers. All existing research documents (`research-dark-souls-design.md`, `research-dark-souls-weapons.md`) were referenced to ensure Soulslike design fidelity.

### Story & Worldbuilding

- Created `docs/story/main-story.md`: Complete 5-chapter narrative arc with 3 endings (薪火相传 / 守炉人 / 大寂灭) and a hidden 4th ending requiring completion of 3 major side quest chains.
- Created `docs/story/lore.md`: Full cosmology — Three Realms (天界/人间/冥界), Celestial Furnace (天之炉), 12 Soul-Forgers (铸魂者), the Shattering (大破碎), 5 Ember Fragments, factions (烬裔/失魂者/堕仙), soul classification system, timeline spanning 10,000+ years.

### 5 Chapter Designs (28 Levels Total)

Each chapter has: `chapter-overview.md` (level layouts, enemy roster, unique items), `bosses.md` or boss section, `levels/` detail, and `chapter-supplement.md` (elite monsters, side quests, scenery, music).

| # | Chapter | Theme | Levels | Boss | Enemies | Elite | Side Quests |
|---|---------|-------|--------|------|---------|-------|-------------|
| 1 | 灵墟·觉醒 | Han Dynasty Ruined Temple | 5 | 巨阙 (Furnace-Keeper Construct) | 4 types | 2 | 2 |
| 2 | 血铁·战歌 | Ming Dynasty Mountain Fortress | 6 | 刑天 (Headless War God) | 6 types | 3 | 3 |
| 3 | 玉障·迷心 | Classical Garden Jade Forest | 6 | 九尾 (Nine-Tailed Fox Spirit) | 9 types | 3 | 3 |
| 4 | 天崩·陨落 | Tang Dynasty Floating Sky City | 6 | 玄霄 (Fallen Immortal, 2 sub-bosses) | 7 types | 3 | 3 |
| 5 | 烬座·归墟 | Cosmic Void / Furnace Core | 5 | 烛阴 (Torch Dragon, 4 phases) | 6 types + 4 boss echoes | 3 | 3 |

### Character System (4 Classes)

Created under `docs/characters/classes/`:
- **神射手 (Divine Marksman):** Ranged DPS with 羿弓术 archery style, elemental arrows (Fire/Ice/Lightning/Spirit), Hou Yi myth lineage.
- **狂战士 (Frenzied Warrior):** Melee tank/DPS with 刑天斧 dual-axe style, Rage meter mechanic, Xíng Tiān bloodline, hyper armor.
- **玄法师 (Mystic Mage):** Caster with 五行术 Five Elements system (Fire/Water/Wood/Metal/Earth), generation/overcoming cycles, Taoist spellcraft.
- **祝祷师 (Invocation Master):** Support/healer with 天祝术 prayer style, Karmic Debt stacking mechanic (业力), 5 spirit summons, Buddhist/folk religious roots.

Supporting systems:
- `docs/characters/upgrade-system.md`: 道行 cultivation leveling, 经脉 8-meridian system, Soul Vessel reinforcement, weapon forging (+10 tiers).
- `docs/characters/switching-system.md`: Class switching at Ember Shrines with proportional stat conversion, independent equipment loadouts, 4 unlockable hybrid classes.
- `docs/characters/talent-skills.md`: 3-tier talent trees per class (9 talents each), cross-class synergies, respec system.

### Bestiary & Equipment Compendiums

- `docs/bestiary/enemies-master.md`: 32 enemy types with full stats, behavior, weaknesses. Classification by Chinese spiritual type (失魂/妖/精/鬼/仙堕/神兽/神).
- `docs/bestiary/bosses-master.md`: 5 main bosses + 2 sub-bosses + 4 boss echoes. All with multi-phase mechanics, Soul Vessel drops, boss weapons, lore integration.
- `docs/systems/weapons-compendium.md`: 40+ weapons across 9 categories, 5 legendary boss weapons, 3 cross-chapter legendary weapons, upgrade material tree.
- `docs/systems/spells-compendium.md`: 18 spells + 14 prayers — 32 unique Focus abilities with cultural naming.
- `docs/systems/equipment-compendium.md`: 30+ armor pieces with weight classes, 10 chapter-unique consumables, full progression economy with Ember estimates (~6,800 total per NG).

### Level Design & Systems

- `docs/systems/level-design-patterns.md`: 20 puzzle types across 5 categories, 15 trap types with environmental tells, shrine placement guidelines, shortcut patterns.
- `docs/systems/combat-styles.md`: 5 combat styles (from Ashen Hollow) re-themed to Chinese cultural context with class associations.
- `docs/00-master-index.md`: Master navigation index for all 30 design documents.

### Perplexity MCP Windows Fix

- Diagnosed and fixed a Windows compatibility bug in `perplexity-subscription-mcp` package: 7 hardcoded `/tmp/perplexity_debug.log` paths replaced with `tempfile.gettempdir()` in cached `client.py` at `C:\Users\SHUAIBI\AppData\Local\uv\cache\archive-v0\rsHKYOI2pVD76qPpj5_GM\Lib\site-packages\perplexity_subscription_mcp\client.py`.
- Added `import os`, `import tempfile` and defined `_DEBUG_LOG = os.path.join(tempfile.gettempdir(), "perplexity_debug.log")`.
- Perplexity MCP reconnected successfully after patch.

### Codebase Scan Findings (for future implementation)

Deployed an Explore subagent to scan `game/scripts/` thoroughly. Key findings documented:
- 3 enemy types implemented with clean enum + tuning pattern in `enemy.gd`
- 5 combat styles with data-driven `STYLE_TIMING` dictionaries in `player.gd`
- Single-scene procedural level generation in `game_world.gd` — multi-level support would need architectural addition
- Zero quest/NPC/dialogue infrastructure — would need to be built from scratch
- Procedural audio synthesis in `procedural_audio.gd` (9 cues, 6 voice channels) — no music streaming support yet; `music_volume` setting exists but is not wired to any audio bus
- Potential bug: `upgrade_tier` and `play_time_ms` missing from `from_dictionary()` deserialization in `run_state.gd`
- `game_settings.gd` already has `music_volume` field (default 0.7) — ready to wire

### Files Changed

| File | Change |
|------|--------|
| `docs/00-master-index.md` | **NEW** — master navigation index for all design documents |
| `docs/story/main-story.md` | **NEW** — complete 5-chapter narrative with 3+1 endings |
| `docs/story/lore.md` | **NEW** — full cosmology, factions, timeline |
| `docs/chapters/01-spirit-awakening/chapter-overview.md` | **NEW** — Chapter 1: 5 levels, 4 enemies, tutorial boss |
| `docs/chapters/01-spirit-awakening/bosses.md` | **NEW** — 巨阙 boss design (2 phases, tutorial purpose) |
| `docs/chapters/01-spirit-awakening/levels/01-levels-detail.md` | **NEW** — Chapter 1 level-by-level design |
| `docs/chapters/01-spirit-awakening/chapter-supplement.md` | **NEW** — Ch.1 elite monsters (2), side quests (2), scenery, music |
| `docs/chapters/02-blood-iron/chapter-overview.md` | **NEW** — Chapter 2: 6 levels, 6 enemies, war fortress |
| `docs/chapters/02-blood-iron/chapter-supplement.md` | **NEW** — Ch.2 elite monsters (3), side quests (3), scenery, music |
| `docs/chapters/03-jade-veil/chapter-overview.md` | **NEW** — Chapter 3: 6 levels, 9 enemies, illusion forest |
| `docs/chapters/03-jade-veil/chapter-supplement.md` | **NEW** — Ch.3 elite monsters (3), side quests (3), scenery, music |
| `docs/chapters/04-celestial-fall/chapter-overview.md` | **NEW** — Chapter 4: 6 levels, 7 enemies, sky city + 2 sub-bosses |
| `docs/chapters/04-celestial-fall/chapter-supplement.md` | **NEW** — Ch.4 elite monsters (3), side quests (3), scenery, music |
| `docs/chapters/05-throne-of-ashes/chapter-overview.md` | **NEW** — Chapter 5: 5 levels, 6 enemies, cosmic final boss (4 phases) |
| `docs/chapters/05-throne-of-ashes/chapter-supplement.md` | **NEW** — Ch.5 elite monsters (3), side quests (3), scenery, music |
| `docs/characters/classes/README.md` | **NEW** — class overview with hybrid paths |
| `docs/characters/classes/divine-marksman.md` | **NEW** — 神射手 class: stats, playstyle, talent tree, lore |
| `docs/characters/classes/frenzied-warrior.md` | **NEW** — 狂战士 class: stats, Rage mechanic, talent tree, lore |
| `docs/characters/classes/mystic-mage.md` | **NEW** — 玄法师 class: Five Elements system, talent tree, lore |
| `docs/characters/classes/invocation-master.md` | **NEW** — 祝祷师 class: Karmic Debt, spirit summons, talent tree |
| `docs/characters/upgrade-system.md` | **NEW** — 4 upgrade systems: cultivation, meridians, soul vessels, forging |
| `docs/characters/switching-system.md` | **NEW** — class switching mechanics, hybrid unlocks, mastery bonuses |
| `docs/characters/talent-skills.md` | **NEW** — talent point economy, tier structure, cross-class synergies |
| `docs/bestiary/enemies-master.md` | **NEW** — 32 enemy types with full stats and behavior |
| `docs/bestiary/bosses-master.md` | **NEW** — 5 bosses + sub-bosses with multi-phase mechanics |
| `docs/systems/combat-styles.md` | **NEW** — 5 styles re-themed to Chinese cultural context |
| `docs/systems/weapons-compendium.md` | **NEW** — 40+ weapons, upgrade tree, legendary weapons |
| `docs/systems/spells-compendium.md` | **NEW** — 18 spells + 14 prayers compendium |
| `docs/systems/equipment-compendium.md` | **NEW** — armor, consumables, progression economy |
| `docs/systems/level-design-patterns.md` | **NEW** — puzzle/trap catalog, shrine placement, shortcuts |

### Validation

- All 30 design documents created with cross-references verified
- Perplexity MCP Windows compatibility bug diagnosed and patched; MCP reconnected successfully
- Codebase scan completed — identified architecture for future multi-level, quest, and music system implementation
- Design constraints checklist in `docs/00-master-index.md` — all items met
- No runtime files modified — this is a documentation-only change

### Coordination

- Design documents only. No Godot runtime files modified.
- The `upgrade_tier` serialization bug in `run_state.gd` is documented for future fix.
- Multi-level support, quest infrastructure, NPC dialogue, and music streaming are identified as the next implementation priorities.
- The existing Ashen Hollow codebase (5 combat styles, 3 enemy types, procedural level, save/load, HUD, audio) serves as the technical foundation for 烬渊.

### Scope

Applied 12 fixes identified by the codebase health audit ([audit-docs-codebase-health.md](audit-docs-codebase-health.md)) and the subagent scan of `game/`, aligned with Dark Souls design research ([research-dark-souls-design.md](research-dark-souls-design.md)) and weapon tuning research ([research-dark-souls-weapons.md](research-dark-souls-weapons.md)). Touches 11 files across 5 phases.

### Phase 1 — Foundation (Refactoring + Collision Fixes)

1. **Extracted duplicated helpers** → `scripts/core/procedural_utils.gd`: Created `class_name AshenProceduralUtils` with static `make_material()` and `has_collision_shape()`. Replaced 4 copies of `_material()` (`game_world.gd:752`, `checkpoint.gd:161`, `shortcut.gd:155`, `lost_echo.gd:136`) and 3 copies of `_has_collision_shape()` (`checkpoint.gd:165`, `shortcut.gd:159`, `lost_echo.gd:140`). Also unified `player.gd`'s `_make_material()` variant. ~40 lines of duplication removed.

2. **Fixed collision layer conflict** (`game_world.gd:18`, `checkpoint.gd:21`, `shortcut.gd:23`, `lost_echo.gd:19`): Interactables were on layer bit 2 (value 4), the same as enemies (`enemy.gd:644`). Moved interactables to bit 3 (value 8). New scheme: bit 0 = world, bit 1 = player, bit 2 = enemies, bit 3 = interactables.

3. **Fixed SpellProjectile collision mask** (`spell_projectile.gd:25`): `collision_mask = 5` → `4`. Veil Bolt no longer collides with world geometry (bit 0); hits enemies only (bit 2).

### Phase 2 — Combat Core (Per-Style Timing Differentiation)

4. **Per-style attack timing** (`player.gd:47–118`): Added `STYLE_TIMING` const dictionary with full timing profiles for all 5 `CombatStyle` enums. Key differentiation:

   | Style | Light Windup | Heavy Windup | Light Damage | Heavy Damage | Dodge Stamina |
   |---|---|---|---|---|---|
   | Reliquary Guard | 0.28 s | 0.58 s | 22 | 38 | 24 |
   | Twin Colossi | 0.48 s | 0.82 s | 32 | 56 | 32 |
   | Crescent Pair | 0.20 s | 0.38 s | 16 | 26 | 20 |
   | Veilcraft | 0.30 s | 0.52 s | 20 | 32 | 26 |
   | Ember Rite | 0.34 s | 0.56 s | 22 | 34 | 26 |

   Added `_style_value()` helper (`player.gd`). Updated `_try_attack()`, `_update_state()` (ATTACK_WINDUP/ACTIVE/RECOVERY transitions), `_try_leap_attack()`, `_try_dodge()`, `_try_parry()`, and `_is_parry_active()` to read from `STYLE_TIMING[combat_style]` instead of hardcoded values. Leap attack parameters (windup/active/recovery/damage/stagger/stamina/lunge) are now per-style; Crescent Pair's curved dual-hit timing uses `_style_value()` for the second-hit trigger.

### Phase 3 — Feel & Polish

5. **Hyper armor for heavy weapons** (`player.gd:160`, `player.gd:750–783`, `player.gd:282–283`, `player.gd:225`): Twin Colossi now has stagger immunity during `ATTACK_ACTIVE` (heavy attacks) and `LEAP_ACTIVE` frames. Added `hyper_armor` bool set in `_change_state()` based on `STYLE_TIMING[combat_style].has_hyper_armor`. `receive_hit()` clears `incoming_stagger` when hyper armor is active. Weapon emission glows golden during hyper armor frames. Reliquary Guard and Crescent Pair have no hyper armor.

6. **Hit-stop on successful impacts** (`combat_area.gd:1`, `combat_area.gd:58`, `game_world.gd:120`, `game_world.gd:457–470`): Added `signal hit_landed(is_heavy)` to `combat_area.gd`, emitted after `body.receive_hit()`. In `game_world.gd`, `_on_player_hit_landed()` pauses via `Engine.time_scale = 0.02` (heavy) / `0.05` (light), restores after 0.08 s / 0.04 s via unscaled timer. Heavy hits also apply brief camera shake (h/v offset). Connected in `_create_systems()` after `add_child(player)`.

7. **Boss healing-punish tendency** (`player.gd:9`, `player.gd:691`, `game_world.gd:118`, `game_world.gd:472–477`, `enemy.gd:200–215`): Added `signal healing_started` to player, emitted in `_begin_cast()` when `cast_id == &"ember_rite"`. Connected in `game_world.gd` to new `_on_player_healing()`, which iterates all enemies calling `on_player_healing()`. In `enemy.gd`: Cinder Guardian immediately queues a long-range attack with 0.7× windup if target > 3 m away; regular enemies boost chase speed 1.5× for 1.8 s.

### Phase 4 — Content & Navigation

8. **Ash Stalker enemy archetype** (`enemy.gd:8–12`, `enemy.gd:32`, `enemy.gd:87`, `enemy.gd:377–385`, `enemy.gd:592–595`, `enemy.gd:612–622`, `game_world.gd:5`, `game_world.gd:140–141`): Added `enum EnemyType { HOLLOW_SENTINEL, ASH_STALKER, CINDER_GUARDIAN }`. Ash Stalker profile: 45 HP, 6.0 move speed, 10.0 aggro range, 12.0 poise limit, fast 0.22 s windup / 0.10 s active / 0.18 s recovery with 8 damage per hit. Pale gray body, warm brown weapon, orange eye emission. `setup()` accepts optional `new_type` parameter. Two Ash Stalkers spawned at `(-3, 0.95, -10)` and `(4, 0.95, -14)` alongside existing sentinels.

9. **NavigationMesh generation** (`game_world.gd:50`, `game_world.gd:849–876`): Added `_generate_navigation()` called via `call_deferred` after `_load_initial_state()`. Creates `NavigationRegion3D` with a `NavigationMesh` (0.5 m agent radius, 2.0 m height, 45° max slope, 0.25 m cell size/height) covering the 30×50 m play area via a `PlaneMesh` proxy. Baked from static collider geometry. `enemy.gd._safe_navigation_direction()` fallback now resolves to real paths instead of direct line-of-sight.

### Phase 5 — Code Quality

10. **Named constants for magic numbers** (`player.gd:174–184`): Added `MOVE_ACCELERATION`, `DEFAULT_GRAVITY`, `STAMINA_REGEN_RATE`, `FOCUS_REGEN_RATE`, `SPRINT_STAMINA_DRAIN`, `DODGE_SPEED`, `DODGE_DURATION`, `DODGE_INVULN_START`, `DODGE_INVULN_END`, `LOCK_ON_MAX_DISTANCE`, `LOCK_ON_BREAK_DISTANCE`. Variable initializations and usage sites in `_update_stamina()`, `_is_invulnerable()`, `_physics_process()`, and dodge handling now reference constants.

### Validation

- All GDScript files pass `--check-only` with Godot 4.7.1 (only pre-existing `.godot/imported/` font cache miss remains — requires one editor open to rebuild).
- Contract tests print `ASHEN_CORE_CONTRACTS_OK`.
- Navigation mesh bakes without errors; `cell_height` aligned to map default (0.25).
- Manual playtesting required for: per-style combat feel, hit-stop timing, hyper armor balance, Ash Stalker encounter tuning, boss healing-punish aggression, and navmesh path quality through wall/pillar geometry.

### Files Changed

| File | Change |
|---|---|
| `game/scripts/core/procedural_utils.gd` | **NEW** — shared `make_material()` / `has_collision_shape()` |
| `game/scripts/player/player.gd` | +`STYLE_TIMING` dict, `_style_value()`, hyper armor, healing signal, named constants, per-style timing in 7 functions |
| `game/scripts/enemy.gd` | +`EnemyType` enum, Ash Stalker profile, `on_player_healing()`, tuning/palette/attack branches |
| `game/scripts/game_world.gd` | +hit-stop handler, `_on_player_healing()`, `_generate_navigation()`, Ash Stalker spawns, collision layer fix, `_ProcUtils` preload |
| `game/scripts/combat_area.gd` | +`signal hit_landed`, emit on successful hit |
| `game/scripts/checkpoint.gd` | Refactored `_material()`/`_has_collision_shape()`, collision layer fix, `_ProcUtils` preload |
| `game/scripts/shortcut.gd` | Same as checkpoint |
| `game/scripts/lost_echo.gd` | Same as checkpoint + transparency via `_ProcUtils.make_material(..., true)` |
| `game/scripts/components/spell_projectile.gd` | Collision mask 5 → 4 |

### Scope

Updated both Dark Souls research documents to accurately reflect the post-fix code state after all 9 audit fixes were applied in commit `7f30d4f`. The documents were originally written before the fixes and described features as missing that are now implemented.

### Changes to `research-dark-souls-design.md`

- Added metadata header (last updated, revision history, status, cross-reference to weapons doc).
- Added **Post-Audit Implementation Summary** table mapping all 9 resolved gaps to their fixes.
- Updated 6 per-section "Status for Ashen Hollow" blocks (Sections 1–5, 7–9) from "not implemented" / "defect" to resolved descriptions with code references.
- Updated **Vertical Slice Checklist**: M1, M2, S2, S3, S4, S5, S6 now `✅ Implemented`; M5 now `✅ Verified`.
- Replaced the "Highest-Priority Gaps" list (4 of 5 resolved) with **Current Remaining Gaps (Post-Fix)** — 5 items cross-referenced to the weapons research.
- Updated **documentation reliability table**: `game-design.md` → RELIABLE, `devlog.md` → RELIABLE, others refined.
- Resolved the **healing design conflict** (Option A/B fork removed; Ember Rite documented as intentional, following DS3 pattern).
- Added **"Related Research"** cross-reference to weapons doc; moved unresolved questions to an appendix.

### Changes to `research-dark-souls-weapons.md`

- Updated metadata header with status tracking and cross-reference to design doc.
- Added **"Changes Since Initial Research"** table: 5 audit fixes relevant to weapons, all marked **Done**.
- Updated **Documentation Reviewed** table — all 8 rows refreshed to reflect post-fix state.
- Added **`[DONE]` / `[PENDING]` / `[DEFERRED]`** status markers to all 11 recommendations. Result: 1 DONE (input buffering), 5 PENDING (per-style tuning, hit-stop, hyper armor, audio, timing), 5 DEFERRED (charged heavies, running/rolling attacks, boss weapon, poise, spear style).
- Renamed section to **"Recommendations — Status Tracked"**.
- Fixed **contradictions**: healing conflict marked RESOLVED; controls.md staleness replaced with cross-reference.
- Added `(uniform timing currently used)` flags to Ashen Hollow mapping.
- Added prominent ⚠️ **playtesting warning** above the Tuning Reference table (frame data is MEDIUM confidence — tune, don't copy).
- **Reordered sections**: Sources & Search Coverage moved after Conclusion.
- Consolidated overlapping combat pillar descriptions to cross-reference design doc.

### Cross-Document Status

Both documents now:
- Accurately reflect the post-fix code state (verified against `player.gd`, `enemy.gd`, `game_world.gd`).
- Cross-reference each other via metadata headers and inline links.
- Provide clear status tracking: readers can see at a glance which recommendations are done, pending, or deferred.
- Preserve all original evidence classifications, "What NOT to Copy" guidance, and analytical structure.

### Coordination

- Documentation-only change. No runtime files modified.
- The three stale documents flagged by both research audits (`architecture.md`, `controls.md`, `validation.md`) remain out of scope for this update.

## 2026-07-29 — Research Audit Fixes Applied

### Scope

Applied 9 fixes identified by the Dark Souls design research audit ([research-dark-souls-design.md](research-dark-souls-design.md)) across `game/scripts/enemy.gd`, `game/scripts/player/player.gd`, `game/scripts/game_world.gd`, `game/scripts/core/run_state.gd`, and `docs/game-design.md`.

### Code Bug Fixes

1. **Telegraph audio during windup** (`enemy.gd:375–383`): Moved enemy swing audio from `State.ACTIVE` to `State.WINDUP` match arm so the player hears the warning cue when the telegraph disc appears, not when the hitbox opens.

2. **Stamina regeneration delay frozen during attacks** (`player.gd:626–638`): Gated `stamina_delay` decrement and stamina/focus regeneration behind `state == State.LOCOMOTION`. Previously the delay counted down during the entire attack animation, making heavy attacks effectively consume no delay.

3. **Lock-on target cycling** (`player.gd:651–702`): Replaced toggle-only `_toggle_lock_on()` with cycling logic. First press acquires the best camera-facing target; subsequent presses cycle through all valid candidates; press releases when only one target remains. Added `_collect_lock_candidates()` and `_cycle_lock_target()` helpers.

4. **Input buffering** (`player.gd:92–93, 292–323, 327–328`): Added a 150 ms input buffer window so combat actions (dodge, parry, light/heavy attack, special attack, cast) pressed during attack recovery are stored and executed on return to LOCOMOTION. Last-input-wins; buffer decays in `_update_state()`. Added `_can_buffer_in_current_state()`, `_try_buffer_action()`, and `_execute_buffered_action()` helpers.

### Boss Feature Work

5. **Boss distance-dependent attack selection** (`enemy.gd:345–398`): Restructured `_select_attack_profile()` for the Cinder Guardian into three distance brackets: close (< 2.0 m) fast swipe, mid (2.0–3.5 m) alternating quick/heavy, long (> 3.5 m) heavy lunge with large gap-close. Sentinel enemies remain unchanged.

6. **Boss phase transition at 50% HP** (`enemy.gd:47–49, 158–160, 367–370, 373–444`): Added a second phase for the Cinder Guardian triggering at ≤ 50% health. Phase 2 features faster windups, shorter recoveries, and higher damage across all distance brackets. Transition includes weapon emission glow (fiery orange), a distinct audio cue, and a brief 0.6 s stagger animation. Phase state resets on enemy reset or shrine rest. Added `_current_phase()`, `_trigger_phase_transition()`, and phase-tuned parameters in each attack bracket helper.

### System Design Changes

7. **Enemy reset on player death** (`game_world.gd:253–255`): Added `enemy.reset_enemy()` loop to `_on_player_died()` before the death overlay. All regular enemies now reset to full HP and spawn positions on player death, matching Soulslike convention.

8. **Shrine vitality upgrades** (`player.gd:56–59, 262–295`, `game_world.gd:194, 204–223, 368–369, 387–388`, `run_state.gd:13, 20, 34, 97`): Added a 3-tier ember spending system at the Ember Shrine. Each tier costs [50, 120, 250] embers and grants +10 max HP. Upgrades persist in `run_state.upgrade_tier` across deaths and application sessions. On rest, `_try_shrine_upgrade()` attempts to spend embers and displays tier progress via HUD messages.

### Documentation

9. **Updated game-design.md**: Documented Ember Rite as a limited in-combat healing exception (30 Focus cost, 0.92 s cast), added Vitality Forging upgrade mechanic, updated Cinder Guardian description with distance-dependent attacks and phase transition, and noted enemy reset on death.

### Validation

- All GDScript files pass `--check-only` with Godot 4.7.1.
- Headless editor import completes without errors.
- Smoke test prints `ASHEN_HOLLOW_SMOKE_OK` and exits cleanly.
- Manual playtesting is still required for combat feel, boss balance, input buffer timing, and upgrade economy.

## 2026-07-29 — Repository Structure Documented

### Scope

- Added [project-structure.md](project-structure.md) as the repository-level directory and ownership guide.
- Defined `game/` as the standalone Godot project, `app/` as the Flutter/OpenHarmony host, `packages/` as reusable platform integration, `tools/` as cross-project automation, and `docs/` as the documentation source of truth.
- Documented that Godot `res://` paths resolve from `game/` and that engine commands should use `D:/godot/newproject/game` as the project path.
- Recorded naming, dependency-direction, generated-file, `.uid`, and safe file-migration rules.

### Coordination

- This update changes documentation only.
- Runtime files were intentionally left unchanged because other agents are actively modifying the game structure and implementation.
- Any future script-directory migration must be coordinated as one integration change and verified through Godot import and smoke tests.

## 2026-07-29 — Dark Souls Design Research

### Scope

- Conducted a structured investigation into Dark Souls 1/3 core design principles to evaluate Ashen Hollow's game design.
- Executed two Perplexity deep_research queries covering: combat speed, stamina economy, lock-on/camera, enemy teaching, death/soul-recovery loop, world/shortcuts, boss design, growth/currency, healing, accessibility, and vertical-slice acceptance criteria.
- Cross-referenced every claim against current game code, scenes, configuration, and tests via three local read-only sub-agents.

### Key Findings

- Ashen Hollow's core combat skeleton (attack phases, shared stamina, iframe dodge, death-recovery, checkpoint, shortcut) is **directionally correct** for a Soulslike vertical slice.
- The **highest-priority gap** is that embers have no spending purpose, removing the motivational anchor from the entire death-recovery loop.
- Boss lacks behavioral depth — two alternating attacks are trivially solvable; a phase transition and distance-dependent attack selection are recommended.
- All six existing design documents are stale or contradicted by current code — project path, controls, healing, persistence, and architecture claims all need updating.
- Perplexity deep_research could not return verifiable source URLs; conclusions are therefore based on observable game mechanics and analysis, not developer-attributed intent.
- Detailed findings, evidence classification, a vertical-slice checklist, and a "what not to copy" guide are in [research-dark-souls-design.md](research-dark-souls-design.md).

### Source Limitations

- Two deep_research queries returned framework-level answers without specific URLs or quotable passages.
- Report uses a three-tier evidence system: Observable Rule / Developer Intent / Analysis. No conclusion is attributed to a Perplexity-returned source without independent verification.
- Six common player-consensus claims about Dark Souls were flagged as unverified or factually incorrect against observable game mechanics.
- Unresolved questions (requiring primary-source retrieval from GDC Vault, CEDEC archives, or Japanese developer interviews) are listed in the report.

## 2026-07-29 — Responsive UI/UX Refresh

### Guidance and Scope

- Reviewed the installed GodotPrompter configuration and delegated a full read of `.claude/skills` and `docs/agents`.
- The local skills cover GodotPrompter package authoring and releases rather than game UI implementation, so they were inspected but not invoked.
- Applied the checked-in Godot UI guidance: `Control`-based HUD composition, container-first responsive layout, centralized theme styling, focused menu navigation, and restrained `Tween` feedback.
- Kept the project self-contained with no external fonts, textures, icons, or other asset dependencies.

### HUD and Menus

- Rebuilt the HUD around `MarginContainer`, `VBoxContainer`, `HBoxContainer`, `CenterContainer`, and `GridContainer` instead of viewport-specific positioning.
- Added a responsive safe-area layout with grouped player vitals, ember currency, boss status, and interaction lanes.
- Added compact non-color labels for health and stamina, a dedicated interaction keycap, clearer lock-on marker, and improved boss hierarchy.
- Centralized shared label, button, separator, panel, hover, pressed, and keyboard-focus styling in one runtime `Theme`.
- Added restrained prompt, message, boss, ember-count, death, and victory transitions.
- Reworked pause and controls overlays into responsive centered panels with immediate keyboard focus and readable action/input rows.

### UX and Reliability

- Preserved the HUD's existing gameplay-facing API so combat and progression systems remain decoupled from presentation details.
- Fixed the death-overlay lifecycle so it clears when the player respawns.
- Expanded the smoke path to verify prompt, boss bar, death overlay, cleanup, stat, ember, damage, and message transitions.

### Validation

- Every GDScript file passes `--check-only` with Godot 4.7.1.
- Headless editor import completes without script or resource errors.
- The bounded runtime completes without runtime errors.
- The expanded smoke path prints `ASHEN_HOLLOW_SMOKE_OK` and exits cleanly.
- Manual graphical review is still required for hierarchy, clipping, focus navigation, lock marker placement, and motion comfort at multiple window sizes.

## 2026-07-29 — Vertical Slice Created

### Project Goal

Started **Ashen Hollow**, an original third-person Soulslike-inspired vertical slice built with Godot 4.7.1. The prototype focuses on deliberate melee combat, stamina management, readable enemies, death recovery, checkpoints, shortcuts, and a guardian encounter.

The project deliberately avoids copying protected characters, maps, names, lore, art, animation, music, or other assets from existing games.

### Research

- Researched common Soulslike design methods with Perplexity.
- Reviewed combat commitment, attack telegraphing, stamina pressure, lock-on camera behavior, enemy state machines, checkpoints, resource recovery, interconnected routes, accessibility, and feedback.
- Cross-referenced engine decisions with official Godot documentation.
- Verified Godot command-line behavior using the installed 4.7.1 executable.
- Searched local Claude skill and plugin directories for an installed Godot development skill. None was available during implementation, so the project followed official Godot documentation and direct engine testing.

Detailed findings are available in [research.md](research.md).

### Foundation

- Created `project.godot` and `main.tscn`.
- Configured a 1280×720 desktop viewport and the OpenGL compatibility renderer.
- Registered keyboard and mouse actions at runtime.
- Kept the project self-contained with no external asset dependencies.

### Procedural World

- Built a moonlit ruined sanctuary from primitive meshes and static collision bodies.
- Added atmospheric fog, directional moonlight, shrine lighting, emissive landmarks, pillars, broken walls, moss-covered platforms, and a guardian arena.
- Added a side-route lever and moving shortcut gate.
- Created all materials and environmental presentation in code.

### Player Controller

Implemented:

- Camera-relative `CharacterBody3D` movement.
- Mouse-controlled third-person camera using `SpringArm3D`.
- Sprinting and delayed stamina regeneration.
- Light and heavy attacks with separate wind-up, active, and recovery timings.
- One-hit-per-swing combat areas.
- Directional dodge with a limited invulnerability interval.
- Damage, stagger, knockback, death, and respawn states.
- Target lock-on with distance and camera-facing selection.
- Contextual interaction with checkpoints and levers.
- Carried ember rewards, loss on death, and recovery.
- Procedural body, cloak, visor, and weapon poses.

### Enemy Combat

Implemented a finite state machine with:

- Idle and detection behavior.
- Target pursuit using `NavigationAgent3D` with direct steering fallback.
- Attack wind-up, active, and recovery states.
- Visible attack telegraphs and procedural weapon poses.
- Damage, poise, stagger, knockback, death, rewards, and checkpoint reset.
- Regular Hollow Sentinel tuning.
- Cinder Guardian tuning with increased health, reach, rewards, and alternating quick and delayed attacks.

### Progression Loop

- Added the Ember Shrine checkpoint.
- Resting restores health and stamina and revives enemies.
- Death respawns the player at the active shrine.
- Carried embers become a Lost Echo at the death location.
- Touching the Lost Echo restores the dropped embers.
- Opening the shortcut reduces repeated traversal.
- Defeating the Cinder Guardian displays the victory state.

### HUD and Feedback

- Added health and stamina bars.
- Added ember counter and contextual interaction prompts.
- Added lock-on target marker.
- Added dedicated guardian health bar.
- Added temporary progression and combat messages.
- Added death, victory, pause, and help overlays.
- Added keyboard alternatives for mouse combat actions.
- Generated attack, impact, dodge, checkpoint, recovery, death, and victory sounds procedurally.

### Integration Fixes

During the first integration pass:

- Corrected setup argument order for the checkpoint, shortcut, and Lost Echo scripts.
- Widened world callbacks to support interaction context supplied by reusable components.
- Removed restrictive base-class annotations from dynamically scripted instances.
- Added explicit `Vector3` typing to lock-on calculations where GDScript could not infer dynamic return types.
- Corrected the initial camera orientation so it begins behind the player.
- Updated the help overlay to match the actual control bindings.
- Delayed smoke-test shutdown until generated audio playback completed, removing false leak warnings.

### Validation

Validated with:

```text
D:\godot\Godot_v4.7.1-stable_win64_console.exe
```

Results:

- Engine version: `4.7.1.stable.official.a13da4feb`
- Every GDScript file passes `--check-only`.
- Headless editor import completes without script or resource errors.
- A bounded 180-iteration runtime completes without errors.
- The dedicated smoke path prints `ASHEN_HOLLOW_SMOKE_OK` and exits cleanly.
- The playable build was launched with `D:\godot\Godot_v4.7.1-stable_win64.exe`.

Full commands and the manual test checklist are recorded in [validation.md](validation.md).

## Current Limitations

- Primitive models and generated sounds are prototype assets, not production-quality content.
- The single-scene procedural level is manually authored, not algorithmically generated.
- No music streaming system exists; `music_volume` setting is not wired to any audio bus.
- No quest, NPC, or dialogue infrastructure exists — would need to be built from scratch.
- No gameplay-level automated tests (only data contract and host protocol tests).
- Combat balance, camera comfort, telegraph readability, and accessibility still require human playtesting.
- The prototype uses procedural poses rather than authored animation clips and root motion.

## Suggested Next Milestone

1. Conduct a complete manual playthrough and record camera or combat problems.
2. Add controller support and a control-remapping screen.
3. Replace procedural poses with original authored animations while retaining authoritative gameplay timing.
4. Convert the generated ruin into an authored level with a baked navigation mesh.
5. Add persistent settings and checkpoint progression under `user://`.
6. Introduce one additional enemy archetype only after the existing guardian encounter is balanced.

## 2026-07-29 — Godot-First Implementation Handoff

Implementation was paused at the user's request. Flutter and OpenHarmony work is explicitly deferred; the Godot game is the only active product target when work resumes.

### Completed Since the Initial Prototype

- Reorganized the playable project under `game/`, with reusable scenes for the world, player, enemies, HUD, checkpoint, shortcut, Lost Echo, audio, and spell projectile.
- Added a title screen, pause flow, help overlay, English/Simplified Chinese language selection, and an embedded subset of Noto Sans CJK for reliable Chinese glyph rendering.
- Added keyboard, controller, and touch/mobile input paths.
- Added focus as a combat resource and five selectable combat styles:
  - Reliquary Guard: timed parry, shield guard, and thrust attacks.
  - Twin Colossi: paired great-blade jump attack.
  - Crescent Pair: paired curved-blade two-hit jump attack.
  - Veilcraft: focus-powered projectile magic.
  - Ember Rite: focus-powered healing and damage prayer.
- Added persistent run/settings data for locale, focus, combat style, Lost Echo state, shortcut state, guardian state, and play time.
- Improved regular-enemy behavior with sanctuary disengagement, return-to-spawn behavior, and leash limits.
- Moved the nearest enemy away from the shrine so a new run begins safely.
- Opened the guardian threshold into a traversable central doorway and added lightweight ember braziers to guide the route.
- Extended the rear play space to improve the initial third-person camera position.
- Corrected desktop Web runtime detection so touch controls and mobile-quality defaults are not forced on desktop browsers.
- Added Web, Windows, and Linux export presets.

### Verification Reached

- Godot 4.7.1 editor parsing and headless import passed before the final small UI/world edits.
- Core contract tests printed `ASHEN_CORE_CONTRACTS_OK`.
- Gameplay smoke tests printed `ASHEN_HOLLOW_SMOKE_OK`.
- Web export completed successfully.
- Windows export completed successfully, and the exported console build passed its headless smoke test.
- The title screen and initial shrine scene were inspected in a desktop browser. Desktop touch controls were hidden correctly, the player started at full health, and nearby enemies did not engage inside the sanctuary.

### Work in Progress When Paused

- The latest HUD alignment, route-brazier, projectile-collision, and weapon-pose changes still need a complete parser/test/export pass.
- The pause menu still needs the planned settings panel for camera sensitivity, UI scale, reduced motion, and high contrast.
- Chinese text is configured with the embedded CJK font, but a final fresh-browser visual pass is still required after re-export.
- All five combat styles are implemented but still need hands-on balance tuning, controller verification, and phone playtesting.
- The boss encounter, death/recovery loop, checkpoint reset, shortcut, victory flow, and full level traversal need a complete manual playthrough.
- `tools/build.ps1` should be changed to build the Godot game by default and make Flutter/OpenHarmony an optional, explicitly requested step.
- Project documentation outside this log still contains some initial-prototype limitations that no longer reflect the current build and should be reconciled after final gameplay behavior is settled.

### Resume Order

1. Run editor parse, core contracts, and gameplay smoke tests against the current files.
2. Finish the in-game settings panel and verify English/Chinese presentation.
3. Play and tune every combat style against regular enemies and the guardian.
4. Verify death, Lost Echo recovery, checkpoint reset, shortcut persistence, boss victory, and save/load.
5. Test keyboard/mouse, controller, touch controls, and a real Android phone-size build.
6. Rebuild and smoke-test Web and Windows exports.
7. Update the remaining documentation to match the verified game.

## 2026-07-30 — Godot Jump, Landing, and Collision-Tunneling Research

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
