# Blender Skinning Continuation: Batches 007 and 008

> Historical handoff. [The full library is now complete: 86/86](03-complete-skinned-library.md), including repair of the 19 normal-preservation failures described below.

Date: 2026-09-08. Status: **12 additional models published; 37/86 now contain embedded skins.**

This continues both September 6 logs. The first log's 6/86 and blocked-MCP status
are historical. The actual starting inventory was 25 published, 12 staged but
unpublished, and 49 not staged. All 12 unpublished models were rebuilt, inspected,
validated, and copied to `build/glb-models/out` in this session.

Per-model operations, bone counts, screenshots, validation errors, and remaining
art work are in [the publication table](02-blender-conversion-publications.md).

## Scope and Environment

- Blender 5.2.1 LTS, Godot 4.7.1, GDScript project, GL Compatibility renderer.
- Blender MCP was not exposed in this session. Used isolated background Blender
  processes with factory startup, not the raw MCP bridge. No interactive Blender
  or Godot process was running at reconnaissance; no user scene was closed/reset.
- Retained existing originals and backups. No game assets, runtime resolver,
  animation code, scene files, or import metadata were replaced.
- `MANIFEST.json` remains the old 85-model generation manifest, not evidence of
  conversion completion. Full manifest regeneration is deferred until the batch
  is complete, as specified by the previous work log.

## Rig Changes

The GLBs contain real Armature/Skeleton joints, inverse bind matrices, and
`JOINTS_0`/`WEIGHTS_0` vertex skinning. These are not runtime PartRig attachments.
Rigid hardware uses single-joint weights; continuous limbs, robes, hair, sashes,
and curved tails use blended weights.

The visual and isolated-joint checks exposed attachment errors in the old staged
files. Repairs include missing elbow/knee links, virtual hands where the source
has no separate hand mesh, connected weapon subtrees, numeric wing-side ancestry,
wing pivots, and a torso-derived waist fallback that excludes surrounding effects.
Back capes are skinned while rigid cape belts are not. Ground scorch and free wind
effects remain on root. Helmet cheek guards, shoulder ornaments, insignia, and
back-mounted banners follow their actual owners rather than misleading substrings.

The glaive source has visibly offset parts. This conversion preserves that rest
geometry; it does not claim to correct the original modeling/grip arrangement.

## Normal Preservation

The old validator checked vertex clouds and attribute coverage, but zeroed UVs,
negated normals, or reversed triangle winding could still pass. It now compares
oriented triangle corners, including world-rest positions, every UV set, normals,
material assignment, and multiplicity. Cyclic triangle order, vertex deduplication,
reindexing, and small floating-point differences remain supported.

The strengthened check initially found normal differences in nine of this
session's 12 models. Blender's imported custom corner normals differed around
capsule/cone poles even before skinning. A sampled pole changed from `(0,-1,0)`
to approximately `(0.019504,-0.999796,-0.005201)`, a 1.1566-degree deviation;
the sampled normals were not zero-length, and non-degenerate triangles were also
affected. `preserve_blender_normals.py` now retains
the importer's decoded normals in the mesh POINT attribute `_rig_source_normal`
before Blender's custom-normal storage step, and uses them during export with
the native skin/world/Y-up normal transforms. Installed Blender addon files are
not edited: temporary adapters are restored in `finally` blocks.

All 12 new exports then passed the strict comparison. The editable `.blend` files
retain the source-normal attribute. Use the workbench exporter for exact-normal
re-export; ordinary Blender export does not automatically use this attribute.
The adapter targets the observed Blender 5.2 importer/exporter API and rejects
morph-target use. These static source models do not have morph targets.

## Verification

Commands were run from `E:/godot/darksoul`:

```powershell
& 'E:/blender/blender.exe' --background --factory-startup --python-exit-code 1 --python tools/rig_glb_batch.py -- --prefix 007-summons-enemies characters/summons/03-RebirthLotus.glb characters/summons/04-ResentfulSpirit.glb characters/summons/05-WhiteCraneAttendant.glb enemies/01-spirit-ruins/01-Lost-Soul-Soldier.glb enemies/01-spirit-ruins/02-Temple-Guardian-Warrior.glb enemies/01-spirit-ruins/03-Mirror-Shade.glb
& 'E:/blender/blender.exe' --background --factory-startup --python-exit-code 1 --python tools/rig_glb_batch.py -- --prefix 008-blood-iron enemies/01-spirit-ruins/04-Furnace-Slag-Beast.glb enemies/02-blood-iron/01-Lost-Soldier-BattleWorn.glb enemies/02-blood-iron/02-War-Dog-Wraith.glb enemies/02-blood-iron/03-Camp-Guard-Wraith.glb enemies/02-blood-iron/04-Torture-Device-Spirit.glb enemies/02-blood-iron/05-Generals-Personal-Guard.glb
python tools/rig_glb_review_sheet.py build/glb-models/rigging/007-summons-enemies-evidence.json
python tools/rig_glb_review_sheet.py build/glb-models/rigging/008-blood-iron-evidence.json
& 'E:/blender/blender.exe' --background --factory-startup --python-exit-code 1 --python tools/test_blender_rig_anatomy.py
node tools/test_validate_skinned_glbs.mjs
python -B tools/test_publish_rigged_glbs.py
python -B -O tools/test_publish_rigged_glbs.py
node tools/validate_skinned_glbs.mjs --source build/glb-models/rigging/originals --output build/glb-models/rigging/staged --report build/glb-models/rigging/validation.json
python tools/verify_rigged_glb_batch.py --godot E:/godot/Godot_v4.7.1-stable_win64_console.exe
python -B tools/publish_rigged_glbs.py build/glb-models/rigging/007-008-review-20260908.json
```

Observed results:

| Check | Result and evidence level |
|---|---|
| Blender conversion | Both batches exit 0, `RIG_BATCH_OK 6`; real modifiers and skin weights, bind-rest preservation and non-root deformation |
| Rest/posed captures | Both exit 0, `RIG_REVIEW_SHEET_OK 6`; 24 nonblank 720x720 renders, 12 per-model comparisons, two contact sheets inspected |
| Isolated anatomy contracts | Exit 0, `BLENDER_RIG_ANATOMY_OK 33483`; six models, mostly per-vertex assertions, plus branch ownership and adapter-restoration checks |
| GLB negative/positive contracts | Exit 0, `SKINNED_GLBS_CONTRACTS_OK`, 28 passed/0 failed |
| Publisher contracts | Exit 0, `PUBLISHER_CONTRACTS_OK`, 31 tests passed in both ordinary and optimized Python |
| Selected 12 strict GLB comparisons | 12/12 passed; geometry, oriented corners, normals, UVs, materials, image payloads, samplers, skins and non-root deformation |
| Whole staged strict comparison | Exit 1: 37 checked, 18 passed, **19 older normal failures**, 49 missing; not a full-library pass |
| Godot direct import | Exit 0, `ASHEN_BLENDER_GLB_IMPORT_OK`: 37 passed/0 failed, 37 skeletons, 2,389 mesh instances, 297,984 vertices; `cpu_imported_skin` |
| Hash-bound Godot wrapper | Exit 0, `GODOT_RIG_BATCH_EVIDENCE_OK`; exact staged inventory and before/after hashes checked |
| Publication | Exit 0, 12 `PUBLISHED` entries; ledger 31 entries plus six legacy publications |
| Published-file audit | Exit 0, `PUBLISHED_RIGS_VERIFIED`; all 12 output hashes match reviewed/staged/ledger bytes, originals retain their publication-time hashes, all selected meshes have skin attributes |
| Parse/scope | Eight Python sources parsed; Node syntax and `git diff --check` exit 0 |

Screenshots are Blender Workbench **solid-shaded geometry/pose evidence**, with
projected actual pose bones. They do not prove textured/PBR rendering equivalence.
Material/image preservation is covered by the independent GLB data comparison.
Godot uses imported Skin/Skeleton data for CPU deformation in headless mode.
Godot rendering-server mesh baking, gameplay/GUT regression, full combat animations,
IK, extreme joint poses, and final art acceptance remain **SKIPPED**.

## Artifacts

All large artifacts below are under ignored `build/glb-models/rigging/`; retain a
filesystem backup rather than relying on Git alone.

- `007-summons-enemies-evidence.json`, `008-blood-iron-evidence.json`: hashes and
  projected bone/pose metadata for the final captures.
- `007-008-review-20260908.json`: explicit per-model visual reviews and exact hashes.
- `godot-20260908T111244023379Z-evidence.json` and matching `.log`: final Godot run.
- `validation.json`: final strict corpus report; `validation-strict-20260908.json`
  preserves the pre-normal-repair failures for comparison.
- `screenshots/007-summons-enemies-*`, `screenshots/008-blood-iron-*`: reviewed images.
- `blend/`, `reports/`, `staged/`: per-model editable scenes and exports.
- `pre-publish-20260908-continuation/`: previous output bytes for the 12 publications.
- `publication.json`: per-model hashes, screenshot hashes, Godot evidence, original
  hashes, strict validation records, notes, and dated-devlog ownership.

The publisher requires fresh uniquely allocated validator reports, explicit
exceptions rather than Python assertions, nonempty per-model screenshots, and
review/Godot/staged hash agreement. It rechecks inputs and copies captured bytes.
Publication remains serialized and is not an atomic multi-file transaction;
an I/O failure during copying would still require a ledger/output reconciliation.

## Remaining Work

There are **49 unconverted models**: blood-iron 06 (1), jade-veil (10),
celestial-fall (7), throne-of-ashes (5), equipment (5), props (8), and weapons (13,
including `templateweapons.glb`, still absent from `out`). `out` contains 85 files:
37 skinned and 48 unskinned. Originals contain 86 unskinned files.

The strict validator additionally identifies normal-preservation debt in these
**19 previously published models**, which this bounded continuation did not change:

- Bosses 02, 03, 04, 05; sub-bosses 01, 02.
- NPCs 01, 02, 03, 05, 06, 07.
- Player classes 01, 04, 05, 06, 07.
- Summons 01, 02.

Their skeletons still import and deform. Their previous normal-preservation claims
are superseded by the strict report. Do not count them as passing the new appearance
gate or automatically republish them without repair and fresh visual/hash evidence.

Next continuation should address that normal debt using the retained originals,
then proceed to at most six new models per reviewed batch. Never rebuild from
already-skinned `out` files. Do not infer completion from `current-batch.json`:
that historical file still records only the old second batch, not library status.
Before any game-assets synchronization, handle the resolver's subtree extraction
and skeleton lifetime dependency documented in the September 6 log.

## References and Ownership

Read the requested September 6 logs, current workbench/prop/sampler/publisher and
Node/Godot verifiers, project settings, original generator scripts for the repaired
attachments, and Blender 5.2's actual glTF normal import/export implementation.
Used the Godot skill's routing, conventions, orchestration, asset/animation,
verification, coordinate-space and runtime-evidence sections.

Parent owned Blender, rigging, capture/evidence, publication, and devlogs. One
bounded worker independently audited inventory and hardened triangle validation;
another owned publication hardening and its synthetic tests. Parent reviewed and
reran both suites. Existing dirty work in tools, September 6 docs, bytecode, and
the unrelated `mcp` submodule was preserved; no reset or commit was performed.
