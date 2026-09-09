"""Original model-aware keyframe recipes; Blender performs animation evaluation.

rig: file/family/bones (rest definitions)/size/height/parts (mesh assignments).
Each frame maps existing bone names to pose offsets. rotation and translation
use model-rest axes: X right, Z up, -Y forward (Blender coordinates). local_rotation
instead uses the bone's local axes, where Y is its hinge/length axis. Angles are
radians; translations are meters; scale defaults to one. Omitted bones rest.
"""
import copy
import math


def put(pose, rig, bone, rotation=None, translation=None, scale=None, local_rotation=None):
    if bone not in rig['bones']:
        return False
    value = pose.setdefault(bone, {})
    for name, data in [('rotation', rotation), ('translation', translation),
                       ('scale', scale), ('local_rotation', local_rotation)]:
        if data is not None:
            value[name] = [float(component) for component in data]
    return True


def sampled_action(name, duration, loop, pose_at, kind, steps=32, events=None):
    frames = [{'time': float(duration * i / steps), 'bones': pose_at(i / steps)}
              for i in range(steps + 1)]
    if loop:
        frames[-1]['bones'] = copy.deepcopy(frames[0]['bones'])
    return {'name': name, 'duration': float(duration), 'loop': bool(loop),
            'kind': kind, 'frames': frames, 'events': events or {}}


def envelope(phase):
    return math.sin(math.pi * phase) ** 2


def curve(phase, knots):
    for (ta, a), (tb, b) in zip(knots, knots[1:]):
        if phase <= tb:
            t = max(0.0, min(1.0, (phase - ta) / (tb - ta)))
            return a + (b - a) * t
    return knots[-1][1]
