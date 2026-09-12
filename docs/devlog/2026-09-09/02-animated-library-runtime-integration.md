# Animated Library Runtime Integration

Date: 2026-09-09. Status: **86 animated game models installed; 761 clips imported
and exercised in Godot; gameplay smoke and all 96 GUT tests pass.**

Continued from the requested [September 6 publication log](../2026-09-06/02-blender-conversion-continuation.md),
[September 8 skinning handoff](../2026-09-08/01-blender-skinning-continuation.md),
and [motion-pose prerequisites](../2026-09-08/05-motion-stitch-pose-prerequisites.md).
The later [86-model completion](../2026-09-08/03-complete-skinned-library.md) and
[September 9 recheck](01-model-conversion-recheck.md) supersede the earlier
conversion backlog. No models needed reconversion.

## Starting State and Delivered Work

The committed action recipes and runtime callers were ahead of their documentation.
`animation/raw`, `animation/staged`, `animation/blend`, and `animation/reports`
already contained all 86 models and 761 clips. However, `game/resources/model_actions.json`
was missing and the corresponding game GLBs were still static. The runtime driver's
manifest guard consequently left the new animation integration inactive.

This continuation installs the existing animated exports into
`game/assets/models/` and generates the manifest. All 86 game files match the
validated staged bytes and manifest SHA256 values. They total **50,532,700 bytes**.
The two legacy Manny/Minny models and the Manny animation library are unchanged.
`build/glb-models/out`, its conversion MANIFEST, original GLBs, saved rigs and
animation recipes/exports remain unchanged.

These are **original model-aware keyframe clips**, baked through the existing
Blender pipeline. They are in-place clips, not mocap, generated remote stitch
results, or a completed production animation art pass. Gameplay still supplies
character translation; the original Minny `root-retreat` example remains the
trajectory-preserving sampling example.

## Synchronization and Part Ownership

New `tools/sync_model_actions.mjs`:

- Checks complete source/raw/staged/recipe inventories before installation.
- Runs the independent `validateModel` preservation/motion checks on every model.
  Original mesh, material, image, node, Skin, accessor and buffer-view data must
  remain identical; the original binary buffer is an unchanged prefix.
- Confirms each animation source is the current published skinning baseline.
- Builds per-model action metadata and **124 extractable part definitions**.
  Part anchors use the original author group's accumulated transform, including
  parents, rather than a newly introduced bone's head or rest orientation.
- Captures and rechecks inputs/destinations, retains previous game bytes, writes
  files through temporary siblings, and checks installed hashes. Replacement is
  per-file, with rollback on a caught installation error. It is not an atomic
  multi-file transaction against process termination or concurrent game reads.
- Preserves import UIDs and other options while selecting lossless embedded
  textures (`gltf/embedded_image_handling=3`). Godot documents this as
  [Embed as Uncompressed](https://docs.godotengine.org/en/latest/classes/class_gltfstate.html#enum-gltfstate-handlebinaryimagemode).

The existing resolver's skinned selection path now has the manifest data it
requires. Sword, Shield, both axes and the destructible `pillJar` retain their
entire shared skeleton while other meshes are hidden. All five selections were
checked against actual imported vertex weights and exercised with part-specific
clips. Their original empty grouping nodes are not used as skin containers.

Initial import extracted 270 duplicate embedded images plus import sidecars.
Their hashes were checked against embedded GLB image payloads, and all 540 newly
generated files were archived under `animation/extracted-import-backup-20260909/`.
Final import retains images within the imported scenes and creates no replacement
PNG set in the game source tree.

Commands, from repository root:

```powershell
node tools/sync_model_actions.mjs --check
node tools/sync_model_actions.mjs --apply
& 'E:/godot/Godot_v4.7.1-stable_win64_console.exe' --headless --path game --editor --quit
```

The first two commands print `MODEL_ACTION_SYNC_READY` and `MODEL_ACTION_SYNC_OK`
respectively. `--check` validates readiness; it does not claim that destination
files are already installed. The tool deliberately does not modify `out` or run
Godot concurrently. Keep editor/game import activity stopped during `--apply`.

Backups and hash receipts:

- `animation/runtime-sync-2026-09-09T09-38-48-111Z-c4a7a558-65f7-4e95-b7b3-cc37d900a9d1/`:
  previous 86 game GLBs, per-model validation, and initial installation receipt.
- `animation/runtime-sync-2026-09-09T09-40-18-281Z-d4050950-67e1-4bf5-8d88-e35271a81e7a/`:
  previous 86 import sidecars and texture-setting receipt.

Both paths are under ignored `build/glb-models/`; retain filesystem backups.

## Runtime Fixes

`embedded_model_actions.gd` now accepts an empty default action. Traps and puzzle
props have only mechanical one-shots: they remain at rest until explicitly
requested and hold a completed interaction instead of repeatedly opening.
The driver also checks metadata presence before reading the optional weak-ref
cache and avoids setting autoplay after tree entry. This removes the errors and
warnings exposed by the first actual activation run.

`player_visuals.gd` keeps equipment ownership under `BodyYaw` and follows the
evaluated `hand.R/L` poses of native class bodies, including the final skeleton
update signal. Positions convert from skeleton/world space into `BodyYaw`; bases
use the hand's pose relative to its rest orientation, preserving existing weapon
child corrections and the shield-axis adjustment. Native bodies skip competing
procedural weapon swings. Body rebuilds preserve equipment nodes, and returning
to Manny restores legacy anchors. Death animation still updates equipment.

Trail tips now include the weapon pivot's orientation. Actual animated movement
exposed a pre-existing call to triangle-only normal generation on a triangle-strip
ribbon; that call was removed because the ribbon is unshaded and uses vertex
colors. The contract checks the rendered mesh structure and material settings.

NPCs suppress procedural wrapper bob when a native driver is bound and request
the native `interact` action while preserving their callbacks/signals.
`EnemyRigHook` also reuses an imported skeleton when a model is directly under its
wrapper rather than under a specifically named `ModelRoot`.

Legacy tests were adapted to the changed assets: the rigid `PartRigBuilder` test
uses a deliberately unskinned synthetic humanoid, while imported-library tests
require original skeleton/Skin identity and real weighted deformation. The jar
test examines the selected visible meshes rather than empty former group nodes.
The root-motion test now supplies callback methods on its mock body, removing
deferred missing-method errors that previously appeared after its success marker.

## Pose Sampling on the New Rig

New `tools/stitch_pose_embedded.example.json` samples the warrior's actual `walk`
clip using automatic `hips` / `thigh.L` / `thigh.R` landmark resolution:

```powershell
& 'E:/godot/Godot_v4.7.1-stable_win64_console.exe' --headless --path game --script res://scripts/tools/sample_stitch_poses.gd -- --request E:/godot/darksoul/tools/stitch_pose_embedded.example.json --output E:/godot/darksoul/build/glb-models/animation/embedded-stitch-poses-20260909.json
python -B tools/test_stitch_pose_cli.py --godot E:/godot/Godot_v4.7.1-stable_win64_console.exe
```

Observed `ASHEN_STITCH_POSES_OK`: two motions, six temporal pose samples, exactly
1.0 meter between connecting pelvis samples and a 1.0-second requested duration.
The CLI suite now includes this newly animated model alongside the original
trajectory example and failure cases. It confirms the new pelvis changes over
time. This remains pose input JSON, not a synthesized transition or complete
provider request. In-place walking does not supply a traversed walking trajectory.

## Independent Verification

All final commands below exited **0** and printed their specified markers.
Godot commands use the executable above and `--headless --path game --script`.

| Check | Command or script | Observed result |
|---|---|---|
| Staged clip/preservation validation | `node tools/validate_model_actions.mjs --source build/glb-models/animation/originals --output build/glb-models/animation/staged --reports build/glb-models/animation/reports --report build/glb-models/animation/validation-continuation-20260909.json --expected-count 86` | `MODEL_ACTION_VALIDATION_OK`: 86/86 models, 761/761 clips, 41,241 channels, 107,336 sampled vertices |
| Sync failure/backup contracts | `node tools/test_sync_model_actions.mjs` | `MODEL_ACTION_SYNC_CONTRACTS_OK`: 21 contracts; inventories, corrupted clips, stale inputs/destinations, idempotence, backups and original nested part anchors |
| Actual imported action library | `res://tests/smoke/embedded_model_library_contract.gd` | `ASHEN_EMBEDDED_MODEL_LIBRARY_CONTRACTS_OK`: 86 models, 761 clips, 4,479 meshes; 175 representative CPU skin-deformation checks, 4 weapon/shield parts, jar, resource isolation |
| Native equipment/NPC behavior | `res://tests/smoke/embedded_equipment_pose_contract.gd` | `ASHEN_EMBEDDED_EQUIPMENT_POSE_CONTRACTS_OK`: 1,328 assertions, including 8 classes × 6 clips × 3 sample times |
| Player gameplay adapter | `res://tests/smoke/player_embedded_actions_contract.gd` | `ASHEN_PLAYER_EMBEDDED_ACTIONS_CONTRACTS_OK` |
| Enemy and summon gameplay adapters | `res://tests/smoke/enemy_summon_embedded_actions_contract.gd` | `ASHEN_ENEMY_SUMMON_EMBEDDED_ACTIONS_CONTRACTS_OK` |
| Destructible scene | `res://tests/smoke/glb_prop_scene_contract_test.gd` | `ASHEN_GLB_PROP_OK`; visibility, material, collision, impact, signal and shards |
| Legacy rigid rig | `res://tests/smoke/part_rig_contract_test.gd` | `ASHEN_PART_RIG_OK`, `ASHEN_PART_RIG_MOVE_OK` |
| Registered model rigs | `res://tests/smoke/rig_all_models_contract_test.gd` | `ASHEN_RIG_ALL_OK`: 82 unique registry paths, 4,252 meshes, all 6 enemy hooks |
| Imported enemy hook | `res://tests/smoke/enemy_rig_wired_test.gd` | `ASHEN_ENEMY_RIG_WIRED_OK`, `ASHEN_ENEMY_RIG_SKIP_OK` |
| Resolver and grounding | `res://tests/smoke/real_model_contract_test.gd` | `REAL_MODEL_CONTRACTS_OK` |
| Motion sampler | `res://tests/smoke/motion_pose_sampling_contract.gd` | `ASHEN_MOTION_POSE_SAMPLING_OK`: 73 checks |
| Sampler CLI | Python command above | `STITCH_POSE_CLI_CONTRACTS_OK`: 11 cases |
| Preserved Manny root motion | `res://tests/smoke/real_root_motion_contract.gd` | `REAL_ROOT_MOTION_CONTRACTS_OK`; synthetic forward displacement `(0,0,-0.8)` |
| Socket and trail contracts | `socket_follow_rotation_contract.gd`, `weapon_trail_contract_test.gd` | `ASHEN_SOCKET_FOLLOW_ROTATION_CONTRACTS_OK`, `ASHEN_WEAPON_TRAIL_CONTRACTS_OK` |
| Gameplay startup/combat smoke | `--headless --path game --quit-after 600 -- --smoke-test` | `ASHEN_HOLLOW_SMOKE_OK` |
| GUT unit/integration | `.\tools\ci.ps1 -Godot E:/godot/Godot_v4.7.1-stable_win64_console.exe -SkipImport -JUnitOut E:/godot/darksoul/build/glb-models/animation/gut-results-20260909.xml` | `ASHEN_HOLLOW_CI_OK`: 96/96 tests, 394 assertions, 13 scripts |
| Final editor parse/import | `--headless --path game --editor --quit` | Exit 0; no script/parse/load errors |

The registry census differs from the complete library census: some equipment
assets have no resolver entry, while Manny is separately registered. The 86-model
contract directly loads every manifest entry, so unregistered assets are still
covered by import and clip verification; it does not imply gameplay reachability
for all 761 clips.

Runtime contracts and the gameplay smoke finish without engine errors. Editor
shutdown still logs **495 ObjectDB instances / 10 resources in use**; the source
of these editor-only shutdown warnings was not established in this continuation.
The smoke process used isolated `APPDATA` and `LOCALAPPDATA` at
`animation/smoke-user-profile/`; production saves were not used.

## Rendered Evidence and Limits

`tools/capture_embedded_actions.gd` rendered six **1400×760** rest/action pairs
with Godot's actual OpenGL compatibility renderer on the local NVIDIA RTX 5060 Ti.
Command (requires a rendering display driver):

```powershell
& 'E:/godot/Godot_v4.7.1-stable_win64_console.exe' --path game --script E:/godot/darksoul/tools/capture_embedded_actions.gd --rendering-method gl_compatibility --resolution 1400x760 -- E:/godot/darksoul/build/glb-models/animation/screenshots/runtime-20260909
```

Observed exit 0, `ASHEN_EMBEDDED_ACTION_CAPTURES_OK 6`, no renderer errors. All six
final images were opened and inspected: player light attack, Cloud Wanderer
interaction, Nine Tails attack, eagle flight, bow draw and trap gate opening.
Captures and their hashes are in `screenshots/runtime-20260909/captures.json`.
They show textured imports and representative pose/mechanism changes. They also
retain visible source modeling offsets and stylized source geometry; the fox and
bow are not claimed to have received a modeling repair or final art approval.

Remaining stages:

- Production animation review for the full library, contacts/foot sliding,
  extreme poses, transitions, two-handed IK and class-specific grip corrections.
- Gameplay triggers for non-idle decorative prop/weapon actions. Their clips
  and exact-name driver API exist; all such actions are not yet gameplay-wired.
- A remote stitch integration requires the real provider endpoint, complete
  schema, credentials and source-use authorization. No service was called or
  asset uploaded. The Mixamo example plugin remains uninstalled.
- Full campaign playthrough, mobile/browser performance and all-clip GPU/art
  acceptance were **SKIPPED**; the reported gameplay coverage is the smoke and
  existing GUT suite.

## Ownership and References

Read the requested devlogs and later completion records, live project settings,
runtime model/animation/equipment callers, existing recipes/export/validation
tools, current smoke/GUT entry points and their success markers. Applied Godot
skill routing, conventions, orchestration, animation/assets/testing, skeletal
equipment and coordinate/runtime-evidence references, plus the official
[final skeleton-update signal](https://docs.godotengine.org/en/stable/classes/class_skeleton3d.html#class-skeleton3d-signal-skeleton-updated)
and texture import documentation.

Three bounded workers handled the runtime library contract, equipment/NPC fixes,
and sync/legacy-rig contracts in disjoint files. Parent reviewed changes and
independently ran all engine checks, imports, data validation and rendered
captures, and owned sync/manifest/asset writes and this handoff. The original dirty
`mcp` submodule was preserved. No reset, commit, external upload or deployment was
performed.
