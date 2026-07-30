# Ashen Hollow Development Log

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
| `game/scripts/player.gd` | +`STYLE_TIMING` dict, `_style_value()`, hyper armor, healing signal, named constants, per-style timing in 7 functions |
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

Applied 9 fixes identified by the Dark Souls design research audit ([research-dark-souls-design.md](research-dark-souls-design.md)) across `game/scripts/enemy.gd`, `game/scripts/player.gd`, `game/scripts/game_world.gd`, `game/scripts/core/run_state.gd`, and `docs/game-design.md`.

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
