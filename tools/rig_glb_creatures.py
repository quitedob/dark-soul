"""Source-backed refinements for five original creature GLBs, before armature creation.

Only bones, assignments and blends change. Landmarks are imported world positions
in Blender Z-up, not the generators' Three.js Y-up coordinates. No bpy dependency.
"""
import re

import numpy as np


def _origin(obj):
    return np.asarray(obj.matrix_world.translation, dtype=float).copy()


def _pin(wb, obj, bone):
    wb.assignment[obj] = bone
    wb.blends.pop(obj, None)


def _subtree(wb, name):
    return [obj for obj in wb.parts
            if any(wb.names[a] == name for a in wb.chains[obj][1:])]


def _one(wb, parts, name):
    matches = [obj for obj in parts if wb.names[obj] == name]
    if len(matches) != 1:
        raise ValueError('%s: expected one %s, found %d' % (wb.rel, name, len(matches)))
    return matches[0]


def _butterfly(wb):
    # enemies-ch3/01: four extrusions have mesh-local roots; no wing empties.
    wings = [obj for obj in wb.parts if wb.names[obj] == 'wing']
    for side, sign in (('L', -1), ('R', 1)):
        pair = sorted([obj for obj in wings if _origin(obj)[0] * sign > 0],
                      key=lambda obj: -_origin(obj)[2])
        if len(pair) != 2:
            raise ValueError(wb.rel + ': expected fore/hind wing pair on ' + side)
        for index, obj in enumerate(pair, 1):
            head = _origin(obj)
            pts = wb.points[obj]
            tip = pts[np.argmax(np.linalg.norm(pts - head, axis=1))]
            bone = 'wing.%s.%02d' % (side, index)
            wb.add(bone, 'chest', head, tip)
            _pin(wb, obj, bone)
        for obj in wb.parts:
            if wb.names[obj].startswith('eye_spot') and wb.center[obj][0] * sign > 0:
                _pin(wb, obj, 'wing.' + side + '.01')
    for obj in wb.parts:
        name = wb.names[obj]
        if name == 'thorax':
            _pin(wb, obj, 'chest')
        elif name in ('antenna', 'antenna_tip', 'proboscis'):
            _pin(wb, obj, 'head')
        elif name == 'leg':
            # Six authored tubes originate at thoracic segments, not the pelvis.
            curve = wb.tube_centers(obj)
            wb.add(wb.assignment[obj], 'chest', curve[0], curve[-1])


def _guardian(wb):
    # enemies-ch3/08: keep front/hind U/F/Paw chains and the curved tail intact.
    for obj in wb.parts:
        name = wb.names[obj]
        if name in ('plinth', 'rune_ring', 'stone_ball', 'ball_ring'):
            _pin(wb, obj, 'root')
        elif name.startswith(('back_spike', 'crack_glow', 'crack_ring')):
            _pin(wb, obj, 'chest')
        elif name == 'mane_curl':
            _pin(wb, obj, 'neck')
        elif name.startswith(('jaw_', 'brow_')):
            _pin(wb, obj, 'head')


def _fox(wb):
    # enemies-ch3/09: two independent tails already use UV-derived centerlines.
    for obj in wb.parts:
        name = wb.names[obj]
        if name.startswith('torn_sash'):
            _pin(wb, obj, 'hips')
        elif name.startswith('fur_tuft'):
            _pin(wb, obj, 'chest')
        elif name == 'confusion_orb' or name.startswith('orb_'):
            # Orb sparks belong to the raised-hand spell, not free ground dust.
            _pin(wb, obj, 'hand.R')
        elif name == 'jade_halo_ring':
            _pin(wb, obj, 'head')


def _wing(wb, side, landmark):
    parts = _subtree(wb, 'wing_' + side.lower())
    root = _one(wb, parts, landmark)
    tip = _one(wb, parts, 'wing_tip')
    bone = 'wing.' + side
    # Both generators leave the group at zero; use the authored root mesh.
    wb.add(bone, 'chest', _origin(root), wb.center[tip])
    for obj in parts:
        # Even unmirrored membranes/feathers must stay on their authored branch.
        _pin(wb, obj, bone)


def _eagle(wb):
    # enemies-ch4ch5/02: rootRing marks the shoulder of each feather assembly.
    for side in ('L', 'R'):
        _wing(wb, side, 'root_ring')
        leg = _one(wb, _subtree(wb, 'leg_' + side.lower()), 'leg')
        upper, lower = 'thigh.' + side, 'shin.' + side
        wb.blends[leg] = ('chain', [upper, lower],
                          wb.bones[upper]['head'].copy(), wb.bones[lower]['tail'].copy())

    # The five tail feathers form a fan, not a serial three-joint tube. Keep
    # the separately authored charred tips with the fan despite source offsets.
    tail = _subtree(wb, 'tail')
    feathers = [obj for obj in tail if re.fullmatch(r'tail_feather\d+', wb.names[obj])]
    if len(feathers) != 5:
        raise ValueError(wb.rel + ': expected five tail feathers')
    head = np.mean([_origin(obj) for obj in feathers], axis=0)
    tip = np.mean([wb.center[obj] for obj in feathers], axis=0)
    wb.add('tail.01', 'hips', head, tip)
    for obj in tail:
        _pin(wb, obj, 'tail.01')
    del wb.bones['tail.02']
    del wb.bones['tail.03']

    for obj in wb.parts:
        name = wb.names[obj]
        if name == 'cloud_trail' or name.startswith('trail_mote'):
            _pin(wb, obj, 'root')
        elif name in ('back_halo', 'halo_core'):
            _pin(wb, obj, 'chest')


def _bat(wb):
    # enemies-ch4ch5/05-03: membrane starts at the wing root; veins are siblings.
    for side in ('L', 'R'):
        _wing(wb, side, 'membrane')
        feet = _subtree(wb, 'foot_' + side.lower())
        ankle = _one(wb, feet, 'ankle')
        claws = [obj for obj in feet if wb.names[obj].startswith('foot_claw')]
        if len(claws) != 3:
            raise ValueError(wb.rel + ': expected three foot claws on ' + side)
        bone = 'foot.' + side
        wb.add(bone, 'hips', _origin(ankle), np.mean([wb.center[obj] for obj in claws], axis=0))
        for obj in feet:
            _pin(wb, obj, bone)
    for obj in wb.parts:
        name = wb.names[obj]
        if name in ('weapon_tip', 'glow_ring'):
            _pin(wb, obj, 'head')
        elif name.startswith('ash_crumb'):
            _pin(wb, obj, 'root')


_REFINERS = {
    'enemies/03-jade-veil/01-Illusion-Butterfly.glb': _butterfly,
    'enemies/03-jade-veil/08-Maze-Guardian.glb': _guardian,
    'enemies/03-jade-veil/09-MindLost-Fox-Demon.glb': _fox,
    'enemies/04-celestial-fall/02-Cloud-Sky-Eagle.glb': _eagle,
    'enemies/05-throne-of-ashes/03-Ember-Bat.glb': _bat,
}


def refine(wb):
    """Call after wb.anatomy(), before creating Armature edit bones.

    Unlisted paths are strict no-ops, including all 37 previously published rigs.
    """
    handler = _REFINERS.get(wb.rel)
    if handler is not None:
        handler(wb)
