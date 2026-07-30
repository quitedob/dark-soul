# H-02 — Automated Level ID Migration Tool

**Priority:** P0 (blocking)
**Status:** ✅ DONE
**Effort:** M (days)
**Depends On:** H-01 (canonical schema and normalization contract)
**Blocks:** H-03, H-04
**Source:** Audit document §8; devlog §5 "Integration blocker"

---

## Problem

Prototype campaign assets may contain legacy hyphen-format IDs such as `1-1` across `.gd`, `.tscn`, and `.tres` files. Manual replacement is unsafe because assets may be nested, unrelated numeric strings may resemble IDs, and canonical and legacy keys may coexist.

The prototype directories are not present in the current checkout, so production migration cannot run until those assets are imported or made available for inventory.

## Implemented Tooling

- `game/scripts/tools/level_id_migration.gd` provides the reusable migration engine.
- `game/scripts/tools/migrate_level_ids.gd` provides the editor entry point.
- The engine recursively scans `.gd`, `.tscn`, and `.tres` files.
- Only quoted legacy IDs that normalize to one of the 28 registered campaign levels are eligible.
- Dry-run mode is the default and can write a machine-readable JSON report.
- Apply mode performs a full preflight and writes nothing when a read error or potential canonical-key collision exists.
- H-01's `ContentRegistry.normalize_level_id()` is the only normalization implementation.
- Source control is the rollback mechanism; the tool does not create `.bak` files.

## Usage

Run the editor script without arguments for a dry run. It writes `res://level_id_migration_report.json` and does not modify assets.

```bash
Godot_v4.7.1-stable_win64_console.exe --editor --path game --script res://scripts/tools/migrate_level_ids.gd
```

After reviewing a collision-free report, run apply mode:

```bash
Godot_v4.7.1-stable_win64_console.exe --editor --path game --script res://scripts/tools/migrate_level_ids.gd -- --apply
```

Do not commit `level_id_migration_report.json`. Preserve it externally when an audit trail is required.

## Validation

```bash
Godot_v4.7.1-stable_win64_console.exe --headless --path game --editor --quit
Godot_v4.7.1-stable_win64_console.exe --headless --path game --script res://tests/smoke/content_registry_contract_test.gd
Godot_v4.7.1-stable_win64_console.exe --headless --path game --script res://tests/smoke/level_id_migration_contract_test.gd
```

`level_id_migration_contract_test.gd` verifies recursive scanning, supported extensions, dry-run immutability, JSON report output, apply behavior, use of registered campaign IDs, and collision-blocked writes.

## Remaining Work

1. Import or expose the prototype `scripts/levels/`, `scripts/world/`, `scripts/bosses/`, and related scene/resource directories.
2. Inventory their actual roots and add them to `DEFAULT_ROOTS` if they differ from the documented paths.
3. Run dry-run mode and review every changed file and potential collision.
4. Apply migration only after the report is clean and prototype ownership is confirmed.
5. Run parser/import, content registry, core, combat, migration, and gameplay smoke tests.
6. Confirm no quoted legacy campaign IDs remain in imported assets.

## Acceptance Criteria

- [x] Recursive `.gd`, `.tscn`, and `.tres` scanning is implemented.
- [x] Dry run produces a machine-readable report without modifying files.
- [x] Apply mode is blocked by detected canonical-key collisions.
- [x] The tool consumes H-01's shared normalizer.
- [x] Fixture-based migration contract passes.
- [x] Project import and content registry contract pass.
- [ ] Prototype campaign assets are available in the main checkout.
- [ ] Dry-run report for real prototype assets has been reviewed.
- [ ] Real prototype assets are migrated without ID-related parse or import errors.
- [ ] Zero quoted legacy campaign IDs remain in imported assets.
- [ ] Gameplay smoke test passes with the imported campaign code.

## Rollback

Before apply mode, commit or stash the imported prototype assets. If verification fails, restore those files from source control and keep the dry-run report for diagnosis. Do not downgrade or rewrite unrelated save data as part of this source migration.

## Risks

| Risk | Mitigation |
|------|------------|
| Numeric strings unrelated to campaign levels are rewritten | Replace only quoted IDs that resolve to a registered campaign level |
| Legacy and canonical keys coexist | Report potential collisions and block all writes |
| A nested asset is missed | Recursively scan all configured roots and supported extensions |
| Prototype paths differ from documentation | Inventory imported assets before applying migration |
| Partial writes leave the tree inconsistent | Full read/collision preflight precedes apply mode; source control provides rollback |
