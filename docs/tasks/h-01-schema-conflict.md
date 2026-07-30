# H-01 — Campaign Level ID Schema Conflict Resolution

**Priority:** P0 (blocking)
**Status:** ✅ DONE
**Effort:** M (days)
**Depends On:** None
**Blocks:** H-02, H-03, H-04, H-07
**Source:** Audit document §8 "关卡拓扑集成、死亡循环与命名规范模式冲突"; devlog §5

---

## Problem

The worktree prototypes (`game/scripts/levels/ProceduralLevelModules`, `game/scripts/world/ProceduralLevelBuilder`, `game/scripts/bosses/BossController`) use **non-canonical level IDs** with simple hyphen format:

```
1-1, 1-2, 1-3, ..., 5-5
```

The canonical content registry (`game/scripts/data/campaign_content.gd`) and its validator (`game/scripts/core/content_validator.gd`) require **standard snake_case format**:

```
level_01_01, level_01_02, ..., level_05_05
```

### Impact

- `game_world.gd` cannot index campaign data when procedural level modules request levels by non-canonical ID
- Content registry lookups return null for non-canonical IDs
- 28-level campaign pipeline is blocked from integration into the main game loop
- All worktree prototype code is isolated and cannot be merged

## Target State

All level IDs use canonical snake_case format everywhere. A normalization adapter handles any legacy format references during the transition period.

## Implementation Strategy: Adapter-First Migration

### Phase A: Adapter Injection (immediate unblock — ~2 hours)

Create a normalization layer in `ContentRegistry` that accepts both formats during lookup:

```gdscript
# game/scripts/core/content_registry.gd

static func normalize_level_id(raw: String) -> String:
    # Already canonical
    if raw.begins_with("level_"):
        return raw
    
    # Legacy "1-1" format → "level_01_01"
    var parts := raw.split("-")
    if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
        var chapter := int(parts[0])
        var level := int(parts[1])
        return "level_%02d_%02d" % [chapter, level]
    
    # Unknown format — return as-is, let validator reject
    return raw

# In all lookup methods:
func get_level(level_id: String) -> Dictionary:
    var canonical_id := normalize_level_id(level_id)
    return _levels.get(canonical_id, {})
```

Add adapter to:
- `ContentRegistry.get_level()`
- `ContentRegistry.get_next_level()`
- `ContentRegistry.get_boss_for_level()`
- `ContentValidator.validate_level_references()`

### Phase B: Systematic Migration (H-02)

H-02 owns the one-shot migration/import tool. It must consume the normalizer defined by H-01, scan `.gd`, `.tscn`, and `.tres` files recursively, produce a machine-readable dry-run report, and detect collisions before writing. Source control and the report provide rollback; the tool must not create per-file `.bak` artifacts.

### Phase C: Validation Hardening

Add canonical format enforcement to `ContentValidator`:

```gdscript
# game/scripts/core/content_validator.gd

static func _validate_level_id_format(level_id: String) -> bool:
    var pattern := RegEx.new()
    pattern.compile("^level_\\d{2}_\\d{2}$")
    return pattern.search(level_id) != null
```

Add validation error for any non-canonical format IDs found during registry building.

## Implementation Steps

1. **Add `normalize_level_id()` to `ContentRegistry`** — 30 min
2. **Add adapter calls to all lookup methods** — 30 min
3. **Run content registry contract test** — verify `EMBER_ABYSS_CONTENT_REGISTRY_OK` still passes
4. **Add canonical format validation to `ContentValidator`** — 30 min
5. **Document the shared normalization contract for H-02**
6. **Run full contract and smoke tests**

## Acceptance Criteria

- [x] `ContentRegistry.get_level("1-1")` returns the same result as `ContentRegistry.get_level("level_01_01")`
- [x] All 28 levels are accessible via both old and new format (adapter phase)
- [x] `ContentValidator` rejects any future non-canonical format IDs
- [x] `EMBER_ABYSS_CONTENT_REGISTRY_OK` passes
- [x] `ASHEN_CORE_CONTRACTS_OK` passes
- [x] H-02 consumes the normalizer without duplicating mapping logic

## Alternative Considered: Manual Rename

**Rejected.** Manual search-and-replace across worktree files is error-prone, misses nested references in dictionaries and string interpolations, and doesn't prevent future regression.

## Risk Assessment

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Regex misses edge cases in string interpolation | Low | `normalize_level_id()` is simple hyphen-split logic; test with all 28 level IDs |
| Migration breaks worktree prototype behavior | Medium | Run full contract test suite after migration; keep worktree branches as backup |
| New contributors reintroduce non-canonical format | Medium | `ContentValidator` format enforcement catches this at build time |
