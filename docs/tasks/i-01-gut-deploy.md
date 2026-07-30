# I-01 — Deploy GUT 9.x Testing Framework

**Priority:** P0 (blocking)
**Status:** ✅ DONE
**Effort:** S (hours)
**Depends On:** None
**Blocks:** I-02, I-03, I-04, I-05, I-06, I-07, I-08
**Source:** Audit document §9 "核心玩法模块 GUT 自动化测试全覆盖体系"

---

## Problem

The project has **zero GUT framework deployment**. Current testing consists of:
- 4 manual contract test scripts in `tests/smoke/` (run via `--script` flag)
- 140 lines of embedded smoke test code in `game_world.gd` (production code pollution)
- ~10-15% logic-path coverage
- No CI-compatible test runner

This means every change to combat, AI, or state machines requires manual playtesting to catch regressions.

## Target State

GUT 9.x installed and configured for Godot 4.7.1 with:
- In-editor test panel functional
- Headless CLI execution with JUnit XML output
- Test directory structure organized by subsystem

## Godot 4.7.1 Compatibility

> **CRITICAL:** GUT has per-Godot-version branches. For Godot 4.7.x, ensure you use the **`godot_4_7`** branch or the latest 9.x release compatible with Godot 4.7. Using the wrong branch will cause plugin load failures.

## Implementation Steps

### Step 1: Install GUT

```bash
# Option A: Git clone (recommended for version control)
cd E:/godot/darksoul/game
git clone --branch godot_4_7 https://github.com/bitwes/Gut.git addons/gut

# Option B: Asset Library (if available in editor)
# Open Godot editor → AssetLib → search "GUT" → download

# Option C: Manual download
# Download ZIP from https://github.com/bitwes/Gut/releases
# Extract to game/addons/gut/
```

### Step 2: Enable plugin

1. Open `game/project.godot`
2. Add to `[editor_plugins]` section:
   ```ini
   [editor_plugins]
   enabled=PackedStringArray("res://addons/gut/plugin.cfg")
   ```
3. Or via editor: Project → Project Settings → Plugins → Enable "GUT"

### Step 3: Create test directory structure

```
game/tests/
├── unit/
│   ├── combat/
│   │   ├── test_guard_resolver.gd
│   │   ├── test_combat_area.gd
│   │   └── test_player_spells.gd
│   ├── systems/
│   │   ├── test_stamina_economy.gd
│   │   ├── test_poise_system.gd
│   │   └── test_focus_resource.gd
│   ├── state_machines/
│   │   ├── test_player_fsm.gd
│   │   └── test_enemy_fsm.gd
│   └── data/
│       ├── test_run_state.gd
│       ├── test_game_settings.gd
│       └── test_content_registry.gd
├── integration/
│   ├── test_death_recovery_loop.gd
│   ├── test_checkpoint_system.gd
│   └── test_save_load.gd
├── smoke/
│   ├── smoke_test.gd              # (extracted from game_world.gd)
│   ├── core_contract_test.gd      # (existing, move here)
│   ├── combat_contract_test.gd    # (existing, move here)
│   └── content_registry_contract_test.gd  # (existing)
└── gut_config.json
```

### Step 4: Create GUT configuration

File: `game/tests/gut_config.json`

```json
{
  "dirs": ["res://tests/unit/", "res://tests/integration/", "res://tests/smoke/"],
  "should_exit": true,
  "ignore_pause": true,
  "log_level": 2,
  "disable_colors": false,
  "junit_xml_file": "res://../test_results.xml",
  "prefix": "test_",
  "suffix": ".gd"
}
```

### Step 5: Configure headless CLI execution

Create `game/tests/run_tests.ps1`:

```powershell
$GODOT = "D:\godot\Godot_v4.7.1-stable_win64_console.exe"
$PROJECT = "D:\godot\newproject\game"

# Full suite with JUnit output
& $GODOT --headless --path $PROJECT `
  -s addons/gut/gut_cmdln.gd `
  -gconfig res://tests/gut_config.json `
  -glog=2 `
  -gexit `
  -gjunit_xml_file

Write-Host "Test results: test_results.xml"
```

Create `game/tests/run_tests.sh` (Linux/Mac):

```bash
#!/bin/bash
GODOT="/path/to/Godot_v4.7.1-stable_linux.x86_64"
PROJECT="/path/to/game"

$GODOT --headless --path "$PROJECT" \
  -s addons/gut/gut_cmdln.gd \
  -gconfig res://tests/gut_config.json \
  -glog=2 \
  -gexit \
  -gjunit_xml_file

echo "Test results: test_results.xml"
```

### Step 6: Verify installation

```bash
# Quick smoke test — create a minimal GUT test
cat > game/tests/unit/test_gut_works.gd << 'EOF'
extends GutTest

func test_gut_is_loaded() -> void:
    assert_true(true, "GUT framework is operational")

func test_godot_version() -> void:
    var version := Engine.get_version_info()
    assert_eq(version.major, 4, "Godot 4.x required")
EOF
```

```bash
godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ -gprefix=test_gut_works -gexit
```

Expected output:
```
res://tests/unit/test_gut_works.gd
* test_gut_is_loaded
    passed
* test_godot_version
    passed
2 passed 0 failed
```

### Step 7: Create `.gutconfig.json` at project root (optional shorthand)

File: `game/.gutconfig.json`

```json
{
  "dirs": ["res://tests/unit/", "res://tests/integration/", "res://tests/smoke/"],
  "should_exit": true,
  "ignore_pause": true,
  "junit_xml_file": "test_results.xml"
}
```

This allows shorthand: `godot --headless --path game -s addons/gut/gut_cmdln.gd -gexit`

## GUT Test Template

All new test scripts must follow this template:

```gdscript
extends GutTest

# --- Setup / Teardown ---

func before_each() -> void:
    # Run before each test
    pass

func after_each() -> void:
    # Run after each test
    pass

# --- Tests ---

func test_example() -> void:
    # Arrange
    var expected := 42
    
    # Act
    var actual := 6 * 7
    
    # Assert
    assert_eq(actual, expected, "Basic arithmetic should work")
```

## Assertion Reference (GUT 9.x)

| Assertion | Purpose |
|-----------|---------|
| `assert_eq(actual, expected)` | Exact equality |
| `assert_ne(actual, unexpected)` | Not equal |
| `assert_almost_eq(actual, expected, tolerance)` | Float comparison |
| `assert_true(condition)` | Boolean true |
| `assert_false(condition)` | Boolean false |
| `assert_null(value)` | Is null |
| `assert_not_null(value)` | Is not null |
| `assert_called(double, method, args)` | Spy verification |
| `assert_signal_emitted(obj, signal_name)` | Signal fired |
| `assert_has_method(obj, method)` | Duck-typing check |

## Acceptance Criteria

- [ ] GUT panel visible in Godot editor (Project Settings → Plugins → GUT enabled)
- [ ] `test_gut_works.gd` passes (2/2)
- [ ] Headless CLI execution prints test results
- [ ] JUnit XML file generated (`test_results.xml`)
- [ ] `tests/run_tests.ps1` script functional
- [ ] Test directory structure created with `unit/`, `integration/`, `smoke/`
- [ ] Existing contract tests still pass (run via GUT or standalone)
- [ ] `gut_config.json` committed to repository

## Risk Assessment

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Wrong GUT branch for Godot 4.7.1 | Medium | Explicitly use `godot_4_7` branch; verify engine version first |
| GUT conflicts with existing Autoload-free architecture | Low | GUT runs in its own SceneTree context; doesn't interfere |
| Test directory structure too deep for GUT discovery | Low | Configure `dirs` in config; GUT recurses by default |
| CI environment lacks Godot console executable | Medium | Document Godot download path; use --headless flag |
