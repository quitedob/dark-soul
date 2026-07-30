# G-01 — LimboAI Behavior Tree Integration for Boss Macro Decisions

**Priority:** P2 (high)
**Status:** ⬜ PENDING
**Effort:** XL (weeks)
**Depends On:** None
**Blocks:** G-06
**Source:** Audit document §7 "敌人与 Boss 行为 AI 的深层博弈逻辑优化"

---

## Problem

Current enemy AI uses a monolithic finite state machine (`enemy.gd`, 8 states) that handles both:
- **Micro execution:** Attack windup/active/recovery timing, collision mask switching, gravity physics
- **Macro decisions:** Patrol, aggro, disengage, distance bracket selection, phase transitions, healing-punish

As enemy variety grows (32 enemy types, 7 bosses), this monolith will become unmaintainable. The audit identifies this as the critical architectural risk for the campaign expansion.

## Target Architecture: "Macro Decision + Micro Execution" Separation

```
┌─────────────────────────────────────┐
│  Behavior Tree (LimboAI / Beehave)  │  ← Macro layer
│  - Patrol / Wander                  │
│  - Aggro evaluation                 │
│  - Distance bracket selection       │
│  - Phase transition triggers        │
│  - Healing-punish override          │
│  - Combo chain selection            │
│  - Retreat / regroup logic          │
│  - Environmental threat assessment  │
└──────────────┬──────────────────────┘
               │ Blackboard variables
               ▼
┌─────────────────────────────────────┐
│  Finite State Machine (GDScript)    │  ← Micro layer
│  - Attack windup/active/recovery    │
│  - Collision mask switching          │
│  - Hitbox activation timing          │
│  - Gravity / physics                 │
│  - Animation playback                │
│  - Damage application                │
└─────────────────────────────────────┘
```

## Plugin Selection: LimboAI

**Why LimboAI over Beehave:**
- Written in C++ (GDExtension) — significantly faster than GDScript behavior trees
- Native Godot 4 integration with inspector-based tree editing
- Blackboard system for data sharing between BT and FSM
- Active maintenance and Godot 4.7 compatibility
- Better suited for complex boss phase scripting

**Installation:**
```bash
# Download from: https://github.com/limbonaut/limboai
# Or Asset Library: search "LimboAI"
# Install to: game/addons/limboai/
```

## Behavior Tree Design: Cinder Guardian Example

```
Root (Selector)
├── Sequence: "Death Check"
│   └── Condition: health <= 0 → Trigger death sequence
├── Sequence: "Healing Punish"
│   ├── Condition: blackboard.player_healing == true
│   ├── Condition: distance_to_player < 8.0 meters
│   ├── Condition: punish_skill_cooldown <= 0
│   └── Action: ForceState("QUICK_PUNISH")
├── Sequence: "Phase 3 Behavior"
│   ├── Condition: health_ratio <= 0.25
│   └── Selector: "Phase 3 Attacks"
│       ├── Sequence: "Long Range"
│       │   ├── Condition: distance > 3.5
│       │   └── Action: SelectAttack("PHASE3_LONG")
│       ├── Sequence: "Mid Range"
│       │   ├── Condition: distance > 2.0
│       │   └── Action: SelectAttack("PHASE3_MID")
│       └── Action: SelectAttack("PHASE3_CLOSE")
├── Sequence: "Phase 2 Behavior"
│   ├── Condition: health_ratio <= 0.50
│   └── [Distance bracket selector — same structure]
├── Sequence: "Phase 1 Behavior"
│   └── [Distance bracket selector]
└── Sequence: "Patrol"
    ├── Action: Wander()
    └── Action: Wait(2.0)
```

## Blackboard Variables (Shared BT ↔ FSM)

```gdscript
# Blackboard keys
var bb := {
    "target": null,              # Node3D — current aggro target
    "target_distance": 0.0,      # float — updated each tick
    "target_in_sanctuary": false,# bool — disengage trigger
    "health_ratio": 1.0,         # float — 0.0-1.0
    "current_phase": 1,          # int — 1/2/3
    "player_healing": false,     # bool — set by healing_started signal
    "punish_skill_cooldown": 0.0,# float — countdown
    "selected_attack": "",       # String — passed to FSM
    "last_attack_time": 0,       # float — for combo variety
    "nearby_allies_count": 0,    # int — crowd behavior
    "threat_level": 0.0,         # float — accumulated from player actions
}
```

## Implementation Phases

### Phase 1: LimboAI Setup (2 days)
1. Install LimboAI plugin
2. Create `BTTaskCustom` subclass for FSM communication
3. Wire blackboard to existing `enemy.gd` state variables
4. Create first simple behavior tree (IDLE → CHASE → ATTACK → RETURN)

### Phase 2: Guardian Migration (3 days)
1. Port Cinder Guardian macro decisions to behavior tree
2. Keep attack execution in GDScript FSM
3. Run parallel: BT decides which attack; FSM executes it
4. Verify existing guardian behavior is preserved

### Phase 3: Healing-Punish Rewrite (1 day)
1. Replace current `on_player_healing()` callback with BT sequence
2. Add cooldown, distance threshold, and interrupt priority in BT nodes
3. Test: player heals at various distances; verify punish behavior

### Phase 4: Generic Enemy Template (2 days)
1. Create reusable `enemy_bt_template` for non-boss enemies
2. Parameterize via blackboard: aggro_range, leash_range, attack_patterns
3. Test with Hollow Sentinel and Ash Stalker

## Acceptance Criteria

- [ ] LimboAI plugin installed and functional in Godot 4.7.1
- [ ] Cinder Guardian behavior tree handles phase transitions, distance brackets, and healing-punish
- [ ] GDScript FSM only handles attack execution timing (windup/active/recovery)
- [ ] Blackboard correctly shares state between BT and FSM
- [ ] Behavior tree visual debugging works in editor
- [ ] Existing `ASHEN_HOLLOW_SMOKE_OK` still passes
- [ ] No performance regression with BT active (C++ GDExtension ensures this)

## Risk Assessment

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| LimboAI not compatible with Godot 4.7.1 | Low | Check LimboAI releases for 4.7 support; fallback to Beehave (pure GDScript) |
| Behavior tree debugging complexity | Medium | Start with simple trees; use LimboAI's built-in debugger |
| Migration effort underestimated | High | Phase approach — only migrate bosses first, keep regular enemies on pure FSM |
| Performance: BT tick overhead | Low | LimboAI is C++; BT tick is < 1ms for simple trees |
