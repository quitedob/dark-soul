# 2026-07-29 — Research Audit Fixes Applied

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
