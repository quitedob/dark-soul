# Complete Embedded Skeleton Library: 86/86

Date: 2026-09-08. Status: **all 86 GLBs published and independently verified**.

This completes the user's request to finish the remaining model conversions.
`build/glb-models/out` now contains 86 models with embedded skeletons and real
vertex skinning, including `weapons/templateweapons.glb`. The 49 previously
unconverted models are finished, and all 19 earlier normal-preservation failures
are repaired. There are no remaining conversion or strict-validation failures.

Per-model operations, rest/posed captures and follow-up animation work are listed
in [the publication table](04-complete-library-publications.md). The earlier
[37/86 handoff](01-blender-skinning-continuation.md) is historical.

## Delivered Scope

- 86 self-contained skinned GLBs in `build/glb-models/out`, totaling 36,864,236 bytes.
- 1,411 joints across the library; all mesh nodes have skin bindings.
- All 86 editable `.blend` files and per-model reports exist under `rigging/`.
- Original geometry, oriented triangle corners, UVs, normals, material assignments,
  embedded images and sampler settings pass comparison against the retained originals.
- Rigid objects use rigid vertex weights; limbs, robes, tails, cords, bow limbs,
  strings and suitable cloth use blended weights. Static props are not given
  artificial humanoid skeletons.
- The regenerated `MANIFEST.json` includes file hashes, skin/joint counts and
  skinned mesh-node counts. Every published hash matches staged bytes.

The game asset copies, resolver, gameplay scripts, import metadata, saved games and
animations were **not changed**. This is the complete embedded-skinning deliverable,
not production combat-animation or runtime-integration approval. The original
source modeling offsets are intentionally retained.

## Work Completed

### Earlier Normal Failures

`repair_rig_normals.py` transfers exact decoded original normals into saved Blender
rigs after proving per-vertex world-position and triangle-corner correspondence.
It fingerprints bone rest transforms and every vertex weight before/after the
transfer. **18 repairs preserve those fingerprints exactly**; backups are retained
in `rigging/pre-normal-repair-20260908/`.

Divine Marksman had no saved `.blend` from the first conversion. It was rebuilt
from its retained unskinned original, recaptured, and validated, retaining a
20-joint rig. It is not described as a fingerprint-preserving normal-only repair.

### Remaining Models

Exact-path refiners in `rig_glb_creatures.py` and `rig_glb_humanoids.py` correct
source-specific wing, tail, limb, equipment and effect ownership without changing
geometry. They are no-ops outside their assigned five and fifteen model paths.
Original GLB data takes precedence over generator comments, including source
capsules whose generator helper ignores passed rotation arguments and the upright
model named Inverted Guardian.

`rig_glb_props.py` now preserves coherent rigid weapon assemblies, item isolation,
authored hinges, flexible bow/string ownership, hanging cords, bead rows and
armor cloth. Source-specific limitations remain explicit: the open fan's offset
face/ribs are not remodeled, and bow string-length constraints require animation
logic beyond the skinning foundation.

Material preservation now handles texture-free GLBs and distinguishes equal base
PBR materials with different clearcoat using original named-mesh assignments.
Unresolved ambiguity still fails instead of guessing. No Blender installation
files were modified.

### Batches and Evidence

| Batches | Scope | Models |
|---|---|---:|
| 009-012 | Existing-rig normal-only repairs | 18 |
| 013 | Divine Marksman rebuild | 1 |
| 014 | Creature rigs | 5 |
| 015 | Equipment | 5 |
| 016 | Props 01-06 | 6 |
| 017 | Props 07-08 and three mechanical enemies | 5 |
| 018-020 | Weapons, including template collection | 13 |
| 021-023 | Remaining humanoid enemies | 15 |

The 68 changed models have 136 final 720x720 rest/posed renders, 68 individual
comparison images and 15 contact sheets. All final sheets were inspected.
Mechanical review poses translate gate slabs/lids and rotate actual hinge axes;
soft branches and rigid assemblies are exercised separately.

These are solid-shaded Blender geometry/pose captures with projections of actual
bone poses. They are not claims of textured/PBR visual acceptance. The independent
GLB comparison proves material/image preservation as data.

## Independent Verification

All commands below were run by the parent from the repository root. All final
commands exited **0**:

```powershell
& 'E:/blender/blender.exe' --background --factory-startup --python-exit-code 1 --python tools/test_blender_rig_anatomy.py
& 'E:/blender/blender.exe' --background --factory-startup --python-exit-code 1 --python tools/test_blender_creature_rigs.py
& 'E:/blender/blender.exe' --background --factory-startup --python-exit-code 1 --python tools/test_blender_prop_rigs.py
& 'E:/blender/blender.exe' --background --factory-startup --python-exit-code 1 --python tools/test_blender_humanoid_rigs.py
node tools/test_validate_skinned_glbs.mjs
python -B tools/test_publish_rigged_glbs.py
python -B tools/test_preserve_glb_materials.py
node tools/validate_skinned_glbs.mjs --source build/glb-models/rigging/originals --output build/glb-models/rigging/staged --report build/glb-models/rigging/validation.json
python tools/verify_rigged_glb_batch.py --godot E:/godot/Godot_v4.7.1-stable_win64_console.exe --expected-count 86
python -B tools/publish_rigged_glbs.py build/glb-models/rigging/014-023-final-review.json
node tools/validate_skinned_glbs.mjs --source build/glb-models/rigging/originals --output build/glb-models/out --report build/glb-models/rigging/validation-published-86.json
python tools/verify_rigged_glb_batch.py --godot E:/godot/Godot_v4.7.1-stable_win64_console.exe --published --expected-count 86
node build/glb-models/verify-glbs.mjs --require-skins
```

| Check | Final observation |
|---|---|
| Prior anatomy regression | `BLENDER_RIG_ANATOMY_OK`: 33,483 assertions, six models |
| Creature contracts | `BLENDER_CREATURE_RIGS_OK`: 53,798 assertions, five models, 24 isolated branches |
| Prop contracts | `BLENDER_PROP_RIGS_OK`: 3,574 assertions, eight models |
| Humanoid contracts | `BLENDER_HUMANOID_RIGS_OK`: 3,143 assertions, 15 models, 30 isolated branches |
| Validator contracts | `SKINNED_GLBS_CONTRACTS_OK`: 28 positive/negative cases passed |
| Publisher contracts | `PUBLISHER_CONTRACTS_OK`: 31 cases passed |
| Material contracts | Three tests passed, including disambiguation and rejection of unresolved ambiguity |
| Strict staged and published comparisons | `SKINNED_GLBS_VALIDATION_OK`: 86 checked/86 passed/0 failed/0 missing/0 extra |
| Godot staged and published imports | 86 models, 86 skeletons, 4,479 mesh instances, 576,896 vertices; zero failures |
| Published census/hash audit | `RIG_LIBRARY_FINAL_OK`: 86 skinned models, 1,411 joints; all staged/output/manifest hashes agree |

Assertion totals include per-vertex checks, not that many independent test cases.
One draft humanoid test incorrectly expected a descendant head ring to remain
fixed when its chest ancestor rotated. The test was corrected to compare against
root-owned effects; no production behavior was changed to satisfy that assertion.

Godot's headless checks use `cpu_imported_skin`, with complete inventory and hashes
checked before/after each run. Godot rendering-server/GPU baking, gameplay/GUT,
full locomotion/combat animation, IK and extreme-pose art approval remain
**SKIPPED**. No conversion failures remain hidden by those exclusions.

## Completion Artifacts

- `build/glb-models/MANIFEST.json`: current 86-model inventory and hashes.
- `rigging/completion.json`: completion scope, counts and evidence hashes.
- `rigging/validation-published-86.json`: strict checks of actual published files.
- `rigging/godot-20260908T131004168623Z-evidence.json`: actual published Godot run.
- `rigging/godot-20260908T125920862882Z-evidence.json`: staged Godot run used for publication.
- `rigging/009-013-repair-review.json` and `014-023-final-review.json`: explicit
  per-model reviews, screenshots and exact GLB hashes supplied to the publisher.
- `rigging/screenshots/009-*` through `023-*`: inspected evidence.
- `rigging/publication.json`: 84 entries. The two unchanged first-batch models,
  Furnace Keeper and Blind Bell Hearer, retain their original September 6 records;
  both are covered by the final 86-file manifest and independent validation.

All large artifacts are under ignored `build/`; retain a filesystem backup.
`current-batch.json` is a historical working selection, not the completion marker.
Publication logs for earlier dates were preserved rather than rewritten as new
work. Existing dirty changes and the unrelated `mcp` submodule were not reverted.

Used Godot skill routing/conventions, asset/animation and runtime-evidence
references. Three bounded workers owned the creature, prop and humanoid profiles
and their tests; parent owned imports, repairs, integration, captures, validation,
publication and documentation. All worker results were rerun in actual Blender.

The next separate task is runtime synchronization: retain skeleton dependencies
when extracting weapon/prop subtrees, then wire animations and equipment controls.
It is not part of this completed `out` conversion.
