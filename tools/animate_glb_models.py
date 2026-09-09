"""Bake original action recipes through Blender's native Animation/NLA exporter.

blender --background --factory-startup --python-exit-code 1 --python tools/animate_glb_models.py -- <relative.glb> ...
Raw exports and editable action scenes stay separate from published GLBs.
"""
import argparse
import contextlib
import hashlib
import importlib
import io
import json
import math
from pathlib import Path
import shutil
import sys

import bpy
from mathutils import Euler, Matrix, Quaternion, Vector


sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / 'build/glb-models'
WORK = BASE / 'animation'
sys.path.insert(0, str(ROOT / 'tools'))


def prepare():
    for name in ('originals', 'raw', 'staged', 'blend', 'reports', 'screenshots'):
        (WORK / name).mkdir(parents=True, exist_ok=True)
    for source in sorted((BASE / 'out').rglob('*.glb')):
        dest = WORK / 'originals' / source.relative_to(BASE / 'out')
        if not dest.exists():
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, dest)


def validate_actions(actions, rig):
    if not actions or len({a['name'] for a in actions}) != len(actions):
        raise ValueError('Missing or duplicate actions: ' + rig['file'])
    for action in actions:
        if not action['name'] or not math.isfinite(action['duration']) or action['duration'] <= 0:
            raise ValueError('Invalid action duration/name')
        frames = action['frames']
        times = [frame['time'] for frame in frames]
        if len(frames) < 3 or times[0] != 0 or abs(times[-1] - action['duration']) > 1e-6 or any(a >= b for a, b in zip(times, times[1:])):
            raise ValueError('Invalid frame sequence: ' + action['name'])
        if action['loop'] and frames[0]['bones'] != frames[-1]['bones']:
            raise ValueError('Loop does not close: ' + action['name'])
        for frame in frames:
            for bone, pose in frame['bones'].items():
                if bone not in rig['bones'] or ('rotation' in pose and 'local_rotation' in pose):
                    raise ValueError('Invalid bone/rotation: ' + bone)
                for key, values in pose.items():
                    if key not in ('rotation', 'local_rotation', 'translation', 'scale') or len(values) != 3 or not all(math.isfinite(v) for v in values):
                        raise ValueError('Invalid pose values: ' + bone)
                    if key == 'scale' and min(values) <= .01:
                        raise ValueError('Singular animation scale: ' + bone)


def _read_scene(relative):
    path = BASE / 'rigging/blend' / Path(relative).with_suffix('.blend')
    with bpy.data.libraries.load(str(path), link=False) as (source, target):
        if len(source.scenes) != 1:
            raise ValueError('Expected one source rig scene: ' + relative)
        target.scenes = source.scenes
    scene = target.scenes[0]
    bpy.context.window.scene = scene
    bpy.context.view_layer.update()
    arms = [o for o in scene.objects if o.type == 'ARMATURE']
    meshes = [o for o in scene.objects if o.type == 'MESH']
    if len(arms) != 1 or not meshes:
        raise ValueError('Invalid saved rig: ' + relative)
    report = json.loads((BASE / 'rigging/reports' / (relative.replace('/', '__') + '.json')).read_text(encoding='utf8'))
    points = [o.matrix_world @ Vector(p) for o in meshes for p in o.bound_box]
    low = Vector([min(p[i] for p in points) for i in range(3)])
    high = Vector([max(p[i] for p in points) for i in range(3)])
    arm = arms[0]
    bones = {b.name: {'parent': b.parent.name if b.parent else '',
                      'head': list(arm.matrix_world @ b.head_local),
                      'tail': list(arm.matrix_world @ b.tail_local)} for b in arm.data.bones}
    rig = {'file': relative, 'family': report['family'], 'bones': bones,
           'size': max(high - low), 'height': high.z - low.z, 'parts': report['assignments']}
    return scene, arm, rig


def _apply_frame(arm, frame):
    for bone in arm.pose.bones:
        bone.matrix_basis = Matrix.Identity(4)
        bone.rotation_mode = 'QUATERNION'
    for name, pose in frame['bones'].items():
        bone = arm.pose.bones[name]
        rest = arm.matrix_world @ bone.bone.matrix_local
        if 'rotation' in pose:
            q = rest.to_quaternion()
            bone.rotation_quaternion = q.inverted() @ Euler(pose['rotation'], 'XYZ').to_quaternion() @ q
        elif 'local_rotation' in pose:
            bone.rotation_quaternion = Euler(pose['local_rotation'], 'XYZ').to_quaternion()
        if 'translation' in pose:
            bone.location = rest.to_3x3().inverted() @ Vector(pose['translation'])
        if 'scale' in pose:
            bone.scale = pose['scale']
    bpy.context.view_layer.update()
    # Legacy rigs have a few hand/foot bones parented directly to chest/hips.
    # Bake their missing follow relationship into channels, without editing the rig.
    for bone in arm.pose.bones:
        if not bone.name.startswith(('hand.', 'foot.')):
            continue
        hand = bone.name.startswith('hand.')
        suffix = bone.name.split('.', 1)[1]
        names = ('forearm.', 'upper_arm.') if hand else ('shin.', 'thigh.')
        driver = next((arm.pose.bones.get(prefix + suffix) for prefix in names if arm.pose.bones.get(prefix + suffix)), None)
        if driver is None:
            continue
        ancestors, parent = [], bone.parent
        while parent is not None:
            ancestors.append(parent.name)
            parent = parent.parent
        if driver.name in ancestors:
            continue
        desired = driver.matrix @ driver.bone.matrix_local.inverted() @ bone.bone.matrix_local @ bone.matrix_basis
        if not hand:
            _, rotation, scale = bone.matrix.decompose()
            desired = Matrix.LocRotScale(desired.translation, rotation, scale)
        bone.matrix = desired
        bpy.context.view_layer.update()


def bake(relative):
    scene, arm, rig = _read_scene(relative)
    family = 'humanoid' if rig['family'] == 'humanoid' else 'props' if rig['family'] == 'prop' else 'creature'
    actions = importlib.import_module('model_actions_' + family).build_actions(rig)
    validate_actions(actions, rig)
    for action in actions:
        duration = max(1, round(action['duration'] * 30)) / 30
        factor = duration / action['duration']
        for frame in action['frames']:
            frame['time'] *= factor
        action['duration'] = duration
        action['events'] = {key: value * factor for key, value in action['events'].items()}
    scene.render.fps = 30
    scene.render.fps_base = 1
    scene.frame_start = 0
    scene.frame_end = math.ceil(max(a['duration'] for a in actions) * 30)
    arm.animation_data_clear()
    arm.animation_data_create()
    for definition in actions:
        action = bpy.data.actions.new(Path(relative).stem + '__' + definition['name'])
        arm.animation_data.action = action
        for frame in definition['frames']:
            _apply_frame(arm, frame)
            number = frame['time'] * 30
            for bone in arm.pose.bones:
                bone.keyframe_insert('location', frame=number, group=bone.name)
                bone.keyframe_insert('rotation_quaternion', frame=number, group=bone.name)
                bone.keyframe_insert('scale', frame=number, group=bone.name)
        for layer in action.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for curve in bag.fcurves:
                        for key in curve.keyframe_points:
                            key.interpolation = 'LINEAR'
        track = arm.animation_data.nla_tracks.new()
        track.name = definition['name']
        strip = track.strips.new(definition['name'], 0, action)
        strip.action_slot = arm.animation_data.action_slot
        strip.extrapolation = 'NOTHING'
        track.mute = True
    arm.animation_data.action = None
    _apply_frame(arm, {'bones': {}})
    scene.frame_set(0)
    dest = WORK / 'raw' / relative
    dest.parent.mkdir(parents=True, exist_ok=True)
    with contextlib.redirect_stdout(io.StringIO()):
        bpy.ops.export_scene.gltf(filepath=str(dest), export_format='GLB', use_active_scene=True,
                                  export_skins=True, export_animations=True, export_animation_mode='NLA_TRACKS',
                                  export_force_sampling=True, export_frame_range=False,
                                  export_materials='NONE', export_normals=False, export_texcoords=False,
                                  export_extras=False)
    editable = WORK / 'blend' / Path(relative).with_suffix('.blend')
    editable.parent.mkdir(parents=True, exist_ok=True)
    bpy.data.libraries.write(str(editable), {scene}, fake_user=True, compress=True)
    report = {'file': relative, 'family': rig['family'], 'source': 'original_model_aware_keyframes',
              'source_sha256': hashlib.sha256((WORK / 'originals' / relative).read_bytes()).hexdigest(),
              'fps': 30, 'actions': [{k: v for k, v in a.items() if k != 'frames'} for a in actions]}
    (WORK / 'reports' / (relative.replace('/', '__') + '.json')).write_text(json.dumps(report, indent=2) + '\n', encoding='utf8')
    print('MODEL_ACTIONS_BAKED', relative, len(actions), flush=True)
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('files', nargs='+')
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
    prepare()
    for relative in args.files:
        if not (WORK / 'originals' / relative).resolve().is_relative_to((WORK / 'originals').resolve()):
            raise ValueError('Path escapes originals')
        bake(relative)
    print('MODEL_ACTION_BATCH_OK', len(args.files))


if __name__ == '__main__':
    main()
