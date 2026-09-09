# Motion Stitch Pose Prerequisites

Date: 2026-09-08. Scope: verified Godot motion-pose sampling and local JSON export.
No remote stitch service was called, no example plugin was installed, and no
character model or animation library was modified.

## What the Example Provides

Read `example/Godot-Mixamo-Animation-Retargeter`, including its README, addon script,
and `mixamo_bone_map.tres`. It configures Godot's FBX importer, applies a
`SkeletonProfileHumanoid` BoneMap, triggers reimport, and saves animations as `.res`.
It is not a motion generator, a stitcher, or a pose-data API client.

The example assumes `PATH:Skeleton3D`, a target node named `Skeleton`, a source
animation called `mixamo_com`, and `mixamorig_*` bone names. Its Root mapping is
empty and unmapped tracks are removed. Do not apply those settings blindly to
the current `DEF-*` rigs or the new `hips`/`thigh.L`/`thigh.R` rigs. Match bones,
rest poses, hierarchy and scale first, and explicitly preserve required root motion.
Renaming tracks alone is not rest-pose retargeting.

The addon identifies its source license as GPLv3. This implementation uses Godot
APIs and the existing project's conventions; no addon source was copied into the
game. Animation-source licensing remains a separate prerequisite before upload
or distribution, as already noted in the project's animation research.

## Required Inputs

1. An actual animation clip on a compatible skeleton. The 86 completed GLBs have
   real skins but no motion clips; a static rig cannot supply temporal poses.
2. A motion loader that evaluates the unmodified trajectory. The CLI uses
   `GLTFDocument` directly on animated GLBs, with images retained in memory.
3. Explicit pelvis and left/right hip landmarks. Defaults recognize the new rig,
   Godot humanoid, DEF and common Mixamo names; ambiguous/missing mappings fail.
   Upper-leg bone heads are the hip landmarks, not arbitrary foot positions.
4. A fixed outer character-placement node, correct meter conversion, and finite
   positive trim/stitch durations. Animated root bones remain inside that wrapper.
5. For an eventual remote call: the actual provider endpoint, complete request
   schema, motion identifiers/formats, authentication and asset-use authorization.
   These were not supplied, so the tool does not invent them or send assets.

Human retarget profiles do not automatically apply to four-legged models, winged
models, or props. Models without usable left/right hip landmarks require a
separate provider-supported orientation convention; the sampler does not guess.

## Godot Mapping

| Supplied pose field | Implementation |
|---|---|
| `root_node_world_pos` | Outer character placement's `global_transform.origin`, converted to meters |
| `root_node_world_rot` | Placement world basis converted to a normalized quaternion |
| `pelvis_world_pos` | Origin of `skeleton.global_transform * skeleton.get_bone_global_pose(pelvis_index)` |
| `pelvis_world_rot` | Normalized quaternion from that world basis |
| `hips_forward_facing_world_yaw` | Horizontal hip axis, cross with world up, then `atan2(forward.x, forward.z)` |

Godot's bone **global pose is skeleton-relative**, not world-space. This is the
critical distinction from simply reading a Three.js object's world transform.
The character wrapper and the animated skeleton root bone are also different:
the wrapper is spatial placement, while root-bone motion contributes to the
sampled pelvis trajectory.

Positions use named `x/y/z` meter components. Quaternions use named `x/y/z/w`
components with `w` scalar; JSON object-key order has no semantic meaning.
World Y is not terrain-relative height unless the relevant ground is at Y=0.
These pose fields do not by themselves prove foot contact or prevent sliding.

### Yaw Correction

The supplied formula and its signed X-axis examples disagree. This implementation
follows the formula explicitly:

```text
axis = left_hip_world_position - right_hip_world_position
axis.y = 0
forward = normalize(cross(normalize(axis), world_up))
yaw = atan2(forward.x, forward.z)

0      -> +Z
+PI/2  -> +X
PI     -> -Z
-PI/2  -> -X
```

Thus `+PI/2 -> -X` and `-PI/2 -> +X` in the pasted examples are inconsistent with
that formula. Confirm the service's convention before mapping these values into
a real request. Swapping hip order flips heading by PI; it is not just a sign fix.
Godot's common character-facing `-Z` convention is not a reason to negate world Z
coordinates. Both engines can use right-handed Y-up world coordinates.

Degenerate horizontal hip axes, mirrored/singular transforms and nonfinite
results fail visibly. Active skeleton modifiers must be baked or disabled first.

## Sampling Behavior

`game/scripts/tools/motion_pose_sampler.gd` samples the three requested times:
`at_zero_time`, `at_lower_trim_time`, and `at_upper_trim_time`.

- Validates `0 <= lower_trim < upper_trim <= clip.length`.
- Requires prefix upper trim to precede the end by at least 0.051 seconds by
  default. The library exposes an explicit margin option; the CLI keeps that default.
- Clones the clip, disables looping, and removes non-transform tracks, so method,
  audio and gameplay-event tracks cannot execute during sampling.
- Validates transform targets instead of silently dropping missing root/bone tracks.
- Normalizes quaternion keys on the copy before interpolation; source keys remain unchanged.
- Resets sparse channels, seeks synchronously, updates skeleton transforms, then
  samples world-space data. Quaternion signs remain continuous between samples.
- Restores original bone poses and animated node transforms on success or sampled
  validation failure. The temporary AnimationPlayer is freed.

Use this on isolated character instances. It is not a replacement for evaluating
a complete live gameplay/physics timeline with dynamic IK and external movement.

## Local Example

[Request configuration](../../../tools/stitch_pose_request.example.json) uses the
existing `minnyquinn.glb` **`root-retreat`** clip. Unlike the game-ready retarget
library, that source retains root translation. The existing
`retarget_oal_to_mannyquin.gd` intentionally removes most Root/Hips translation
for gameplay movement; sampling that stripped library cannot recover the original
trajectory.

Run from the repository root:

```powershell
& 'E:/godot/Godot_v4.7.1-stable_win64_console.exe' --headless --log-file E:/godot/darksoul/build/glb-models/rigging/stitch-sample.log --path game --script res://scripts/tools/sample_stitch_poses.gd -- --request E:/godot/darksoul/tools/stitch_pose_request.example.json --output E:/godot/darksoul/build/glb-models/rigging/stitch-pose-demo.json
```

Observed exit 0 and `ASHEN_STITCH_POSES_OK`: two motions, six samples, a 1.0-meter
connection gap and 1.0-second requested stitch duration.

| Connecting pose | Pelvis world Y | Pelvis world Z |
|---|---:|---:|
| Prefix at upper trim, t=0.5 | 0.833436 m | -0.708721 m |
| Suffix at lower trim, t=0.5 | 0.833436 m | 0.291279 m |

These are sampled values, not hardcoded pelvis coordinates or an assumed 0.95 m
height. The example uses the same connecting frame for both instances and moves
the suffix wrapper by one meter. For different clips/connecting times, sample
first, adjust the actual suffix placement to the desired pelvis gap, then resample;
adding one meter to the root alone does not always give a one-meter pelvis gap.

The [generated JSON](../../../build/glb-models/rigging/stitch-pose-demo.json) contains
`poses.prefix` and `poses.suffix`, each with the supplied root and three pelvis-state
fields. `sampling` contains source hashes, exact times, resolved bones, forward
vectors and the chosen yaw convention. This is **pose input data, not a complete
`StitchParamsInput` request or a synthesized transition**. The distance/duration
ratio is diagnostic, not a measured or guaranteed transition velocity.

## Verification

```powershell
& 'E:/godot/Godot_v4.7.1-stable_win64_console.exe' --headless --log-file E:/godot/darksoul/build/glb-models/rigging/stitch-contract.log --path game --script res://tests/smoke/motion_pose_sampling_contract.gd
python -B tools/test_stitch_pose_cli.py --godot E:/godot/Godot_v4.7.1-stable_win64_console.exe
```

- Exit 0, `ASHEN_MOTION_POSE_SAMPLING_OK`: 73 checks. Covers nested world transforms,
  interpolated quaternions, four yaw directions, loop boundaries, sparse-state and
  failure restoration, event suppression, meter conversion/overflow, bone mapping,
  invalid trims and the actual root-retreat source trajectory.
- Exit 0, `STITCH_POSE_CLI_CONTRACTS_OK`: 10 cases, including a static newly rigged
  model, missing clips/bones, duplicate hip landmarks, invalid JSON/durations,
  boundary times, units and quaternions. Failed requests leave existing output
  untouched. Consumers must check the exit/marker, not merely file existence.
- Godot 4.7.1 scoped parser check passed. The actual source GLB remains byte-identical.
- No 86-model action generation/retargeting, remote API call, live AnimationTree/IK,
  rendered transition, foot-contact correction or full gameplay regression was
  performed. Those are separate stages, not implied by the passing sampler tests.

Read the requested example plus the local retarget baker, animation bridge,
research record, and Godot skill animation/coordinate/runtime-test references.
A bounded read-only worker independently checked the example and sampler risks;
parent reproduced the proposed input-normalization/overflow cases in engine tests.
Existing dirty rigging work, models, import settings and the `mcp` submodule were
preserved. No plugin source or animation asset was uploaded or copied for distribution.
