# K-02 — Guard Player `_ready()` with Initialization Flag

**Priority:** P1 (critical)
**Status:** ✅ DONE
**Effort:** S (hours)
**Depends On:** None
**Blocks:** None
**Source:** Code review full audit 2026-07-30, finding H-2
**Authority:** `docs/architecture.md` §Player FSM

---

## Problem

`player.gd:_ready()` (line 262-268) re-initializes `_spells` and `_visuals` after `setup()` may have already done so. The player is composed by `game_world.gd` which calls `setup()` before adding the player to the scene tree — then `_ready()` fires and duplicates the initialization.

Additionally, `_spells.setup(self, world_node)` at line 265 passes `world_node` which is `null` if `setup()` was not called first (the `world_node` field is set by `setup()`). `PlayerSpells.setup()` stores this null silently.

```gdscript
# game_world.gd composition order:
player.setup(self)        # sets world_node, initializes _spells, _visuals
add_child(player)          # → triggers player._ready()
                            #   → _spells.setup(self, null) ❌ re-inits with null world_node
                            #   → _visuals.setup(self, null) ❌ same issue

# player.gd:
func _ready() -> void:
    _ensure_nodes()
    _spells.setup(self, world_node)    # world_node is null if setup() not called yet
    _visuals.setup(self, world_node)   # duplicate init
```

## Target

Guard `_ready()` with a `_initialized` flag to prevent double-initialization:

```gdscript
var _initialized := false

func setup(world: Node3D) -> void:
    if _initialized:
        return
    world_node = world
    _spells.setup(self, world_node)
    _visuals.setup(self, world_node)
    _initialized = true

func _ready() -> void:
    _ensure_nodes()
    if not _initialized:
        _spells.setup(self, world_node)
        _visuals.setup(self, world_node)
        _initialized = true
```

## Acceptance Criteria

- [ ] `_spells` and `_visuals` are initialized exactly once regardless of call order
- [ ] `world_node` is never passed as `null` to subsystem `setup()` calls
- [ ] Smoke test passes (`ASHEN_HOLLOW_SMOKE_OK`)
- [ ] Player subsystem tests (FSM, stamina) continue to pass
