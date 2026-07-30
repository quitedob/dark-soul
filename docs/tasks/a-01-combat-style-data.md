# A-01 — Extract CombatStyleData as Custom Resource

**Priority:** P1 (critical)
**Status:** ✅ DONE
**Effort:** M (days)
**Depends On:** None
**Blocks:** A-02, A-03, A-04
**Source:** Audit document §1 "开源类魂生态解析与底层架构解耦"; §2 "动作帧数据与底层手感差异化重构"

---

## Current Result

`CombatStyleData` exists at `game/scripts/data/combat_style_data.gd`, and five resources exist under `game/resources/combat_styles/`. Ordinary light/heavy attacks read these Resources. Leap, dodge, and action armor still have legacy dictionary dependencies tracked by A-02; richer weapon chains and stance contexts belong to `AttackData` / `MovesetData` in A-03.

## Original Problem

All combat style configuration is a `const STYLE_TIMING` dictionary embedded in `player.gd` (~70 lines). This approach:
1. Requires code changes to tune combat values (no Inspector editing)
2. Cannot be shared across scenes without code duplication
3. Complicates future weapon-per-style data loading
4. Mixes data with logic — violates separation of concerns

## Target Architecture

Create a `CombatStyleData` custom `Resource` subclass with `class_name` for Godot's type registry. Each of the 5 combat styles becomes a `.tres` file editable in the Inspector.

### Benefits
- **Inspector-editable:** Tune frame data, stamina costs, damage values without touching code
- **Serializable:** `.tres` files survive engine restarts (Godot 4.x fixed the custom Resource serialization bug)
- **Shareable:** Same resource can be referenced by player, HUD, tutorial UI, and AI systems
- **Version-controllable:** `.tres` is text-based — diff-friendly
- **Type-safe:** `class_name` ensures `CombatStyleData` is a known type everywhere

## Implementation

### Step 1: Create CombatStyleData class

File: `game/scripts/data/combat_style_data.gd` (NEW)

```gdscript
class_name CombatStyleData
extends Resource

## Display name (localized key)
@export var style_id: String = ""
@export var display_name: String = ""

## — Light Attack —
@export var light_windup: float = 0.3
@export var light_active: float = 0.15
@export var light_recovery: float = 0.32
@export var light_damage: float = 20.0
@export var light_stagger: float = 25.0
@export var light_stamina_cost: float = 20.0
@export var light_focus_cost: float = 0.0

## — Heavy Attack —
@export var heavy_windup: float = 0.6
@export var heavy_active: float = 0.22
@export var heavy_recovery: float = 0.65
@export var heavy_damage: float = 38.0
@export var heavy_stagger: float = 45.0
@export var heavy_stamina_cost: float = 38.0
@export var heavy_focus_cost: float = 0.0

## — Dodge —
@export var dodge_stamina_cost: float = 26.0
@export var dodge_duration: float = 0.4
@export var dodge_invuln_start: float = 0.08
@export var dodge_invuln_end: float = 0.3

## — Parry (if applicable) —
@export var has_parry: bool = false
@export var parry_window_start: float = 0.06
@export var parry_window_end: float = 0.26

## — Hyper Armor / Poise —
@export var has_hyper_armor: bool = false
@export var wam_light: float = 0.0    # Weapon Attack Modifier during light active
@export var wam_heavy: float = 0.0    # WAM during heavy active
@export var wam_leap: float = 0.0     # WAM during leap active
@export var wam_guard: float = 0.0    # WAM during guard

## — Special / Weapon Art —
@export var special_attack_name: String = ""
@export var special_stamina_cost: float = 0.0
@export var special_focus_cost: float = 0.0
@export var special_damage: float = 0.0
@export var special_cooldown: float = 0.0

## — Leap Attack —
@export var has_leap_attack: bool = false
@export var leap_windup: float = 0.5
@export var leap_active: float = 0.25
@export var leap_recovery: float = 0.6
@export var leap_damage: float = 40.0
@export var leap_stagger: float = 55.0
@export var leap_stamina_cost: float = 35.0

## — Movement —
@export var move_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var dodge_distance: float = 5.0

## — Visual / Audio —
@export var weapon_material_color: Color = Color.WHITE
@export var trail_color: Color = Color.WHITE
@export var hit_vfx_scale: float = 1.0
```

### Step 2: Create .tres resource files

File: `game/resources/combat_styles/relicary_guard.tres`
```ini
[gd_resource type="Resource" script_class="CombatStyleData" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/data/combat_style_data.gd" id="1"]

[resource]
script = ExtResource("1")
style_id = "reliquary_guard"
display_name = "护卫之道"
light_windup = 0.28
light_active = 0.15
light_recovery = 0.32
light_damage = 22.0
light_stagger = 28.0
light_stamina_cost = 22.0
heavy_windup = 0.58
heavy_active = 0.22
heavy_recovery = 0.65
heavy_damage = 38.0
heavy_stagger = 48.0
heavy_stamina_cost = 40.0
dodge_stamina_cost = 24.0
has_parry = true
parry_window_start = 0.06
parry_window_end = 0.26
has_hyper_armor = false
wam_guard = 0.40
special_attack_name = "破甲突刺"
special_stamina_cost = 26.0
special_damage = 36.0
```

File: `game/resources/combat_styles/twin_colossi.tres`
```ini
[gd_resource type="Resource" script_class="CombatStyleData" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/data/combat_style_data.gd" id="1"]

[resource]
script = ExtResource("1")
style_id = "twin_colossi"
display_name = "刑天斧法"
light_windup = 0.48
light_active = 0.22
light_recovery = 0.52
light_damage = 32.0
light_stagger = 42.0
light_stamina_cost = 38.0
heavy_windup = 0.82
heavy_active = 0.28
heavy_recovery = 0.90
heavy_damage = 56.0
heavy_stagger = 68.0
heavy_stamina_cost = 65.0
dodge_stamina_cost = 32.0
has_hyper_armor = true
wam_light = 0.211
wam_heavy = 0.35
wam_leap = 0.50
has_leap_attack = true
leap_windup = 0.65
leap_active = 0.30
leap_recovery = 0.75
leap_damage = 58.0
leap_stagger = 72.0
leap_stamina_cost = 38.0
special_attack_name = "巨刃跳劈"
special_stamina_cost = 38.0
special_damage = 58.0
move_speed = 4.2
sprint_speed = 7.0
weapon_material_color = Color(0.8, 0.3, 0.1)
trail_color = Color(0.9, 0.4, 0.1)
hit_vfx_scale = 1.5
```

(Similar `.tres` files for Crescent Pair, Veilcraft, Ember Rite.)

### Step 3: Load resources in player.gd

File: `game/scripts/player/player.gd`

```gdscript
# Replace const STYLE_TIMING dictionary with:
var _style_data: Dictionary = {}  # CombatStyle enum → CombatStyleData

func _ready() -> void:
    _load_style_data()

func _load_style_data() -> void:
    var style_dir := "res://resources/combat_styles/"
    _style_data[CombatStyle.RELIQUARY_GUARD] = load(style_dir + "reliquary_guard.tres")
    _style_data[CombatStyle.TWIN_COLOSSI] = load(style_dir + "twin_colossi.tres")
    # ... etc

func _style_value(key: String, default = null):
    var data: CombatStyleData = _style_data[combat_style]
    return data.get(key) if data else default
```

### Step 4: Add validation in ContentValidator

```gdscript
static func validate_combat_style_resources() -> bool:
    var ids := ["reliquary_guard", "twin_colossi", "crescent_pair", "veilcraft", "ember_rite"]
    for id in ids:
        var res := load("res://resources/combat_styles/" + id + ".tres")
        if res == null:
            printerr("Missing combat style resource: ", id)
            return false
        if not res is CombatStyleData:
            printerr("Invalid resource type for: ", id)
            return false
    return true
```

## Acceptance Criteria

- [x] `CombatStyleData` class defined with `class_name` and registered globally
- [x] 5 `.tres` resource files created in `resources/combat_styles/`
- [x] Resources are Inspector-serializable with grouped fields
- [x] Ordinary light/heavy attacks read combat data from Resources
- [x] Existing `_style_value()` helper works with Resource-based data
- [x] Resources reload through the combat-style Resource contract test
- [ ] A-02 removes remaining leap/dodge/action-armor legacy dictionary reads
- [ ] A-05 adds full schema validation to the validation pipeline

## Known Godot 4.x Caveat

> **Historical issue:** Early Godot 4.x versions had a bug where custom `Resource` subclasses would silently fail to serialize or revert to base `Resource` on reload. This was fixed in Godot 4.2+. With Godot 4.7.1, the fix is stable. The `class_name` declaration is the critical guard against this — without it, the engine treats the resource as a generic `Resource` and drops custom properties.

## Risk Assessment

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Resource serialization fails silently | Low | Godot 4.7.1 has this fixed; `class_name` is the safety net |
| `.tres` merge conflicts in git | Low | `.tres` is text-based, diff-friendly; one file per style minimizes conflicts |
| Performance: `load()` during gameplay | Very Low | Load once in `_ready()`, cache in dictionary |
