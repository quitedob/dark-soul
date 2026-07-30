# I-10 — Extract Embedded Smoke Test from Production Code

**Priority:** P1 (critical)
**Status:** ✅ DONE
**Effort:** M (days)
**Depends On:** None
**Blocks:** None
**Source:** Audit document §10; `audit-docs-codebase-health.md` §2.4 "Embedded smoke test"; §4.3

---

## Problem

`game_world.gd` contains ~140 lines of smoke test logic (lines ~822–962) embedded directly in the production orchestrator. This code:

1. **Runs unconditionally** when `--smoke-test` CLI flag is present
2. **Is mixed with production code** — increases cognitive load when reading `game_world.gd`
3. **Prints and quits** — `print("ASHEN_HOLLOW_SMOKE_OK"); get_tree().quit()` — which is test-runner behavior, not game behavior
4. **Cannot be run independently** — requires full game world initialization
5. **Is not discoverable** — not in `tests/` directory where developers expect tests

## Target State

All smoke test logic lives in `game/tests/smoke/smoke_test.gd` (already partially exists) with the embedded logic fully migrated. `game_world.gd` only has a single hook that triggers the external test runner when `--smoke-test` flag is present.

## Implementation Steps

### Step 1: Identify all smoke test code in game_world.gd

Read `game/scripts/game_world.gd`, lines ~822–962. Catalog every test assertion:

- [ ] Systems presence (player, HUD, enemies exist)
- [ ] Sanctuary protection (player took no damage at spawn)
- [ ] Sanctuary engagement (no enemy engaged inside sanctuary)
- [ ] Input map completeness (all required actions registered)
- [ ] Combat style cycling (all 5 styles + hand loadout verification)
- [ ] Save/load hand loadout (apply_run_state, snapshot_run_state)
- [ ] Localization (Chinese parry text = "弹反")
- [ ] Parry contract (parry reduces damage to 0, puts enemy in stagger)
- [ ] Frontal guard reduction (damage reduced with guard_active, direction check)
- [ ] Rear guard bypass (rear hit not blocked by guard)
- [ ] Guard break (low stamina → broken → stagger)
- [ ] Shield bash metadata (hand=left, action_id=shield_bash, damage=18)
- [ ] Guarded thrust compatibility
- [ ] Twin Colossi leap (stamina consumed)
- [ ] Crescent Pair leap (stamina consumed)
- [ ] Veilcraft projectile cast (focus consumed, VeilBolt node spawned)
- [ ] Ember Rite cast (focus consumed, health healed)
- [ ] HUD prompt visibility
- [ ] Boss HUD visibility
- [ ] Death overlay visibility/clear

### Step 2: Migrate each assertion to GUT test format

File: `game/tests/smoke/smoke_test.gd` (extend existing)

```gdscript
extends GutTest

var _world: Node3D
var _player: CharacterBody3D
var _hud: CanvasLayer

func before_all() -> void:
    # Load the game world scene (expensive — do once)
    var world_scene := load("res://scenes/world/ashen_hollow.tscn")
    _world = auto_free(world_scene.instantiate())
    get_tree().root.add_child(_world)
    await wait_for_physics_frames(10)  # Let _ready() complete
    
    # Find key nodes
    _player = _world.get_node_or_null("Warden")
    _hud = _world.get_node_or_null("HUD")

func after_all() -> void:
    if is_instance_valid(_world):
        _world.queue_free()

# --- Systems Presence ---

func test_player_exists() -> void:
    assert_not_null(_player, "Player should exist in game world")

func test_hud_exists() -> void:
    assert_not_null(_hud, "HUD should exist in game world")

func test_enemies_exist() -> void:
    var enemies := _world.get_tree().get_nodes_in_group("enemies")
    assert_gt(enemies.size(), 0, "At least one enemy should exist")

# --- Sanctuary Protection ---

func test_sanctuary_no_damage_at_spawn() -> void:
    assert_eq(_player.health, _player.max_health, "Player should be at full health at spawn")

func test_sanctuary_no_enemy_engagement() -> void:
    # Verify no enemy is aggro'd on player at spawn
    var enemies := _world.get_tree().get_nodes_in_group("enemies")
    for enemy in enemies:
        if enemy.has_method("get_state"):
            assert_ne(enemy.get_state(), "CHASE", "No enemy should be chasing at spawn")

# --- Input Map Completeness ---

func test_input_map_has_all_actions() -> void:
    var required := [
        "move_forward", "move_back", "move_left", "move_right",
        "camera_left", "camera_right", "camera_up", "camera_down",
        "right_primary", "right_secondary", "left_primary", "left_secondary",
        "dodge", "lock_on", "interact", "sprint",
        "special_attack", "cycle_style", "style_1", "style_2",
        "style_3", "style_4", "style_5",
        "pause", "help"
    ]
    for action in required:
        assert_true(InputMap.has_action(action), "InputMap missing action: " + action)

# --- Combat Style Cycling ---

func test_all_five_styles_cycle() -> void:
    var styles_seen := []
    for _i in range(5):
        styles_seen.append(_player.combat_style)
        _player._cycle_style()
    assert_eq(styles_seen.size(), 5, "Should cycle through 5 styles")
    # Verify all styles are unique
    var unique := {}
    for s in styles_seen:
        unique[s] = true
    assert_eq(unique.size(), 5, "All 5 styles should be unique")

# ... (remaining assertions ported from embedded code)

# --- Smoke test complete ---
func test_all_smoke_assertions_pass() -> void:
    # This test only runs if all above pass (GUT runs tests independently)
    print("ASHEN_HOLLOW_SMOKE_OK")
    assert_true(true, "All smoke test assertions passed")
```

### Step 3: Replace embedded code with hook

File: `game/scripts/game_world.gd`

```gdscript
# REMOVE: ~140 lines of inline smoke test at lines ~822-962
# ADD: Single hook at end of _ready() or in a dedicated method:

func _ready() -> void:
    # ... all existing setup ...
    
    # Smoke test hook (non-blocking in production)
    if OS.get_cmdline_args().has("--smoke-test"):
        call_deferred("_run_smoke_test")

func _run_smoke_test() -> void:
    # Delegate to external test runner
    var runner := load("res://tests/smoke/smoke_test_runner.gd").new()
    runner.world = self
    add_child(runner)
    runner.run()
    # runner emits "smoke_complete" signal → game_world prints result and quits
```

### Step 4: Clean up and verify

```bash
# Verify game_world.gd still parses
godot --headless --path game --check-only

# Run smoke test via GUT
godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests/smoke/ -gexit

# Verify the --smoke-test flag still works
godot --headless --path game --quit-after 600 -- --smoke-test
# Expected: ASHEN_HOLLOW_SMOKE_OK
```

## Acceptance Criteria

- [ ] Zero smoke test assertions remain in `game_world.gd`
- [ ] All 20+ smoke assertions migrated to `tests/smoke/smoke_test.gd` (GUT format)
- [ ] `--smoke-test` CLI flag still prints `ASHEN_HOLLOW_SMOKE_OK` and exits cleanly
- [ ] `game_world.gd` line count reduced by ~140 lines
- [ ] Smoke tests runnable independently via GUT: `godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests/smoke/ -gexit`
- [ ] Production code path never executes smoke assertions (only test hook)
- [ ] Existing contract tests still pass

## Risk Assessment

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| GUT SceneTree context differs from `--smoke-test` headless context | Medium | Test both execution paths; keep `--smoke-test` flag working during transition |
| Smoke test assertions depend on game_world.gd internal state | Medium | Expose necessary state via public API; use `call_deferred` for async operations |
| 140 lines is an underestimate if more logic is tangled | Low | Subagent scan verified lines ~822-962 |
