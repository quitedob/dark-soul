"""Source-backed enemy refinements, called after anatomy() and before armature creation.

Only bones, assignments and blends change, in imported Blender world/Z-up space.
The dispatch keys deliberately exclude every other model. Generator references
are relative to build/glb-models/scripts; helpers.mjs and original GLBs take
precedence over generator comments (capsule() ignores rotation arguments).
"""
import re

import numpy as np


def _parts(wb, pattern):
    return [obj for obj in wb.parts if re.fullmatch(pattern, wb.names[obj])]


def _one(wb, pattern):
    matches = _parts(wb, pattern)
    if len(matches) != 1:
        raise ValueError('%s: expected one %s, found %d' % (wb.rel, pattern, len(matches)))
    return matches[0]


def _origin(obj):
    return np.asarray(obj.matrix_world.translation, dtype=float).copy()


def _pin(wb, parts, bone):
    for obj in parts:
        wb.assignment[obj] = bone
        wb.blends.pop(obj, None)


def _rigid(wb, pattern, bone):
    _pin(wb, _parts(wb, pattern), bone)


def _subtree(wb, name):
    return [obj for obj in wb.parts
            if any(wb.names[a] == name for a in wb.chains[obj][1:])]


def _cloth(wb, pattern, parent, vertical=True):
    for obj in _parts(wb, pattern):
        name = 'cloth.' + re.sub(r'[^a-z0-9_]', '_', obj.name.lower())
        wb.chain(name, [obj], parent, 2, vertical=vertical)


def _same_skin(wb, pattern, source):
    for obj in _parts(wb, pattern):
        wb.assignment[obj] = wb.assignment[source]
        if source in wb.blends:
            wb.blends[obj] = wb.blends[source]
        else:
            wb.blends.pop(obj, None)


def _arm(wb, side, shoulder, elbow, wrist, tip=None):
    upper, lower, hand = (p + '.' + side for p in ('upper_arm', 'forearm', 'hand'))
    wb.add(upper, 'chest', shoulder, elbow)
    wb.add(lower, upper, elbow, wrist)
    wb.add(hand, lower, wrist, tip)
    return upper, lower, hand


def _capsule_arms(wb, arm_pattern=r'arm_[lr]', hand_pattern=r'(?:hand|fist)_[lr]'):
    # These source capsules are centered and upright, even where rx/rz was passed.
    for obj in _parts(wb, arm_pattern):
        side = wb.side(obj)
        endpoints = wb.endpoint(obj, wb.bones['chest']['head'])
        shoulder, end = sorted(endpoints, key=lambda p: -p[2])
        hands = [p for p in _parts(wb, hand_pattern) if wb.side(p) == side]
        wrist = wb.center[hands[0]].copy() if hands else end
        elbow = (shoulder + end) * .5
        names = _arm(wb, side, shoulder, elbow, wrist)
        wb.assignment[obj] = names[0]
        wb.blends[obj] = ('chain', list(names[:2]), shoulder, end)
        _pin(wb, hands, names[2])


def _tube_arms(wb, pattern):
    # The middle UV ring recovers the middle authored Catmull-Rom landmark.
    for obj in _parts(wb, pattern):
        curve = wb.tube_centers(obj)
        names = _arm(wb, wb.side(obj), curve[0], curve[len(curve) // 2], curve[-1])
        lengths = np.r_[0., np.cumsum(np.linalg.norm(np.diff(curve, axis=0), axis=1))]
        wb.assignment[obj] = names[0]
        wb.blends[obj] = ('curve', list(names[:2]), curve, lengths)


def _beacon(wb):
    # enemies-ch1ch2/06-Beacon-Keeper-Wraith.mjs
    _capsule_arms(wb)
    _rigid(wb, r'smoke.*|ground_shadow|spark\d+', 'root')
    _pin(wb, _subtree(wb, 'flame_spire'), 'head')
    _rigid(wb, r'tendril_top', 'head')
    _rigid(wb, r'flame_body|tongue\d+|tendril_[lr]', 'chest')
    # One central spell is cupped by both palms, not a left/right hand mesh.
    ball = _one(wb, 'fireball')
    wb.add('held.fireball', 'chest', wb.center[ball])
    _rigid(wb, r'fireball(?:_core|_hot)?|halo_(?:outer|inner)', 'held.fireball')


def _memory(wb):
    # enemies-ch3/02-Memory-Thief.mjs: right reach and raised left arm are tubes.
    _tube_arms(wb, r'arm_[lr]')
    _rigid(wb, r'claw_tip|siphon_glow', 'hand.R')
    _rigid(wb, r'hand_r', 'hand.R')
    _rigid(wb, r'hand_l', 'hand.L')
    for obj in _parts(wb, r'shoulder_spike|spike_tip'):
        _pin(wb, [obj], 'upper_arm.' + wb.side(obj))
    _rigid(wb, r'memory_orb|orb_halo|orb_orbit|wisp', 'root')
    _same_skin(wb, 'hem_tatter', _one(wb, 'robe'))
    _cloth(wb, r'sash(?:_end)?', 'chest')


def _echo(wb):
    # enemies-ch3/03-Echo-Spirit.mjs has no right arm and no legs, only rings.
    upper, lower, hand = (_one(wb, n) for n in ('arm_lu', 'arm_lf', 'hand_l'))
    shoulder = max(wb.endpoint(upper, wb.center[upper]), key=lambda p: p[2])
    elbow = max(wb.endpoint(lower, wb.center[lower]), key=lambda p: p[2])
    _arm(wb, 'L', shoulder, elbow, wb.center[hand])
    _pin(wb, [upper], 'upper_arm.L')
    _pin(wb, [lower], 'forearm.L')
    _pin(wb, [hand], 'hand.L')
    pauldron = _one(wb, 'pauldron_r')
    wb.add('upper_arm.R', 'chest', _origin(pauldron), wb.center[pauldron])
    _pin(wb, [pauldron], 'upper_arm.R')
    _rigid(wb, 'pauldron_l', 'upper_arm.L')
    wb.add('held.sword', 'root', wb.center[_one(wb, 'grip')])
    _rigid(wb, r'blade(?:_spine)?|grip|guard', 'held.sword')
    _rigid(wb, r'afterimage|spark\d+|foot_ring_[lr]', 'root')
    _rigid(wb, r'core(?:_ring\d+)?', 'chest')
    _cloth(wb, 'talisman_sash', 'chest')
    sash = _one(wb, 'talisman_sash')
    _rigid(wb, 'talisman_card', wb.blends[sash][1][-1])
    for name in ('hand.R', 'forearm.R', 'foot.L', 'foot.R'):
        wb.bones.pop(name, None)


def _wedding(wb):
    # enemies-ch3/05-Wedding-Gown-Ghost.mjs: cuffs are gold, sleeves are tubes.
    _tube_arms(wb, 'sleeve')
    for obj in _parts(wb, r'sleeve_cuff|hand|hand_tip'):
        bone = ('forearm.' if wb.names[obj] == 'sleeve_cuff' else 'hand.') + wb.side(obj)
        _pin(wb, [obj], bone)
    _same_skin(wb, 'skirt_pleat', _one(wb, 'skirt'))
    for name in list(wb.bones):
        if name.startswith('cloth.skirtpleat'):
            del wb.bones[name]
    _cloth(wb, 'train', 'hips', vertical=False)
    _cloth(wb, 'hem_wisp', 'hips', vertical=False)
    _cloth(wb, 'hair', 'head')
    _rigid(wb, r'sash_belt|belt_tassel(?:_tail)?', 'hips')
    _rigid(wb, r'crown.*|hair_back|wail_aura', 'head')


def _water(wb):
    # enemies-ch3/06-Water-Moon.mjs: a single body lathe, not a separate head.
    _tube_arms(wb, 'arm')
    _rigid(wb, r'ripple|pool_disc|splash|drop', 'root')
    _rigid(wb, 'moon_chest', 'chest')
    _cloth(wb, 'water_veil', 'chest')
    wb.add('ornament.moon', 'chest', wb.center[_one(wb, 'moon_halo')])
    _rigid(wb, r'moon_(?:halo|shard)\d*', 'ornament.moon')


def _flower(wb):
    # enemies-ch3/07-Mirror-Flower-Spirit.mjs: extruded petals, not fabric.
    hips = np.mean([_origin(p) for p in _parts(wb, r'skirt\d+')], axis=0)
    chest = wb.center[_one(wb, 'core')].copy()
    spine = hips + (chest - hips) * .4
    wb.add('hips', 'root', hips, spine)
    wb.add('spine', 'hips', spine, chest)
    wb.add('chest', 'spine', chest, wb.bones['neck']['head'])
    wb.bones['root']['head'][:2] = hips[:2]
    wb.bones['root']['tail'][:2] = hips[:2]
    _rigid(wb, r'skirt\d+', 'hips')
    _rigid(wb, r'bud_[lrb]|core|mirror_chest|tell_petal', 'chest')
    _rigid(wb, r'mirror_halo|halo\d+', 'head')
    _rigid(wb, 'mirror_shard', 'root')
    for side in ('L', 'R'):
        upper = _one(wb, 'arm_' + side.lower())
        lower = _one(wb, 'forearm_' + side.lower())
        shoulder, elbow = _origin(upper), _origin(lower)
        tip = wb.endpoint(lower, elbow)[1]
        _arm(wb, side, shoulder, elbow, tip)
        _pin(wb, [upper], 'upper_arm.' + side)
        _pin(wb, [lower], 'forearm.' + side)
        _rigid(wb, 'mirror_arm_' + side.lower(), 'upper_arm.' + side)
        _rigid(wb, 'vine_' + side.lower(), 'thigh.' + side)
    _rigid(wb, 'vine_leaf', 'thigh.L')
    for name in list(wb.bones):
        if name.startswith('cloth.skirt'):
            del wb.bones[name]


def _greedy(wb):
    # enemies-ch3/10-Ember-Greedy-Ghost.mjs
    # No body/torso mesh: the generic fallback collapses hips onto chest.
    robe = _one(wb, 'robe')
    hips = wb.center[robe].copy()
    chest = wb.center[_one(wb, 'core_ember')].copy()
    spine = hips + (chest - hips) * .4
    head = wb.bones['head']['head'].copy()
    neck = chest + (head - chest) * .7
    wb.add('hips', 'root', hips, spine)
    wb.add('spine', 'hips', spine, chest)
    wb.add('chest', 'spine', chest, neck)
    wb.add('neck', 'chest', neck, head)
    wb.bones['root']['head'][:2] = hips[:2]
    wb.bones['root']['tail'][:2] = hips[:2]
    _tube_arms(wb, 'arm')
    for obj in _parts(wb, 'grab_claw'):
        _pin(wb, [obj], 'hand.' + wb.side(obj))
    _rigid(wb, r'maw|tooth|mask.*', 'head')
    _cloth(wb, 'veil_ribbon', 'head')
    _rigid(wb, r'core_ember|core_ring|core_halo', 'chest')
    _rigid(wb, r'back_trail|ash_(?:trail|dust\d+|spark\d+)', 'root')
    _rigid(wb, 'hem_ember', wb.blends[robe][1][-1])
    _same_skin(wb, 'hem_tear', robe)


def _stairway(wb):
    # enemies-ch4ch5/01-Stairway-Guard-Wraith.mjs: halberd is one assembly.
    _capsule_arms(wb)
    _pin(wb, _subtree(wb, 'tower_shield'), 'hand.L')
    _pin(wb, _subtree(wb, 'halberd'), 'hand.R')
    _rigid(wb, 'cuirass', 'chest')
    _rigid(wb, r'body_lower|tasset\d+', 'hips')
    _cloth(wb, r'fauld\d+', 'hips')
    _rigid(wb, r'halo(?:_outer)?|helm.*', 'head')
    for obj in _parts(wb, r'pauldron.*'):
        _pin(wb, [obj], 'upper_arm.' + wb.side(obj))


def _alchemy(wb):
    # enemies-ch4ch5/04-Alchemy-Fallen-Immortal.mjs
    _capsule_arms(wb)
    _pin(wb, _subtree(wb, 'flask_l'), 'hand.L')
    _pin(wb, _subtree(wb, 'flask_hand'), 'hand.R')
    _pin(wb, _subtree(wb, 'belt_pouch'), 'hips')
    _rigid(wb, r'dan_qi\d+|orbital_ring\d*|wisp_ring\d+', 'root')
    _rigid(wb, r'core_point|core_halo', 'chest')
    _same_skin(wb, r'body_rot|body_spirit', _one(wb, 'body'))
    _same_skin(wb, r'torn_flap\d+', _one(wb, 'robe'))


def _library(wb):
    # enemies-ch4ch5/06-Library-Guardian-Spirit.mjs: zero-origin groups are
    # organizational, while each sleeve extrusion starts at its mesh origin.
    for side in ('L', 'R'):
        parts = _subtree(wb, 'sleeve_' + side.lower())
        sleeve = next(p for p in parts if wb.names[p] == 'sleeve')
        hand = next(p for p in parts if wb.names[p] == 'hand')
        shoulder, wrist = _origin(sleeve), wb.center[hand].copy()
        names = _arm(wb, side, shoulder, (shoulder + wrist) * .5, wrist)
        wb.assignment[sleeve] = names[0]
        wb.blends[sleeve] = ('chain', list(names[:2]), shoulder, wrist)
        _pin(wb, [hand], names[2])
    _pin(wb, _subtree(wb, 'weapon_tip'), 'hand.R')
    wb.add('held.book', 'root', wb.center[_one(wb, 'tome')])
    _pin(wb, _subtree(wb, 'book_focus'), 'held.book')
    _rigid(wb, r'orbit_page\d+|orbit_ring|ground_halo|aura_orb\d*', 'root')
    _cloth(wb, 'shawl', 'chest')
    _same_skin(wb, 'shawl_cloud', _one(wb, 'shawl'))


def _broken(wb):
    # enemies-ch4ch5/07-Broken-Immortal-Body.mjs
    _capsule_arms(wb, r'arm_[lr]_(?:energy|stone)', r'gauntlet_[lr]')
    _pin(wb, _subtree(wb, 'head_weakpoint'), 'head')
    _pin(wb, _subtree(wb, 'cracked_halo'), 'head')
    root = _one(wb, 'wing_root_rot')
    tip = _one(wb, 'wing_tip_rot')
    wb.add('wing.R', 'chest', wb.center[root], wb.center[tip])
    _pin(wb, _subtree(wb, 'stone_wing'), 'wing.R')
    _rigid(wb, r'energy_wisp\d+|ascend_halo', 'root')
    _rigid(wb, r'crack_chest|crack_belly|crack_glow', 'chest')
    _same_skin(wb, 'body_rot_half', _one(wb, 'body'))
    for side in ('l', 'r'):
        _same_skin(wb, 'leg_crack_' + side, _one(wb, 'leg_' + side))
    _cloth(wb, 'cloud_sash', 'chest')


def _drifter(wb):
    # enemies-ch4ch5/05-01-Ember-Shore-Drifter.mjs
    _capsule_arms(wb)
    for obj in _parts(wb, r'finger_[lr]\d+'):
        _pin(wb, [obj], 'hand.' + wb.side(obj))
    _rigid(wb, r'core_point|ember_glow', 'chest')
    _rigid(wb, 'soul_halo', 'head')
    _rigid(wb, r'river_ripple\d*|soul_mote\d+|mote_bright', 'root')
    _cloth(wb, 'robe_drapery', 'hips', vertical=False)


def _inverted(wb):
    # enemies-ch4ch5/05-02-Inverted-Guardian.mjs is upright with upward claws.
    # Do not flip the model or reinterpret its foot gripRuneband as a weapon.
    for side in ('L', 'R'):
        suffix = side.lower()
        arm = _one(wb, 'arm_' + suffix)
        elbow = _one(wb, 'elbow_' + suffix)
        fist = _one(wb, 'fist_' + suffix)
        shoulder = max(wb.endpoint(arm, wb.center[arm]), key=lambda p: p[2])
        _arm(wb, side, shoulder, wb.center[elbow], wb.center[fist])
        _pin(wb, [arm], 'upper_arm.' + side)
        _pin(wb, [elbow], 'forearm.' + side)
        _pin(wb, [fist], 'hand.' + side)
        _pin(wb, _subtree(wb, 'pauldron_' + suffix), 'upper_arm.' + side)
        feet = _subtree(wb, 'foot_' + suffix)
        ankle = next(p for p in feet if wb.names[p] == 'ankle_ring')
        foot = next(p for p in feet if wb.names[p] == 'foot')
        leg = _one(wb, 'leg_' + suffix)
        hip = max(wb.endpoint(leg, wb.center[leg]), key=lambda p: p[2])
        thigh, shin = 'thigh.' + side, 'shin.' + side
        wb.add(thigh, 'hips', hip, wb.center[leg])
        wb.add(shin, thigh, wb.center[leg], wb.center[ankle])
        wb.add('foot.' + side, shin, wb.center[ankle], wb.center[foot])
        wb.blends[leg] = ('chain', [thigh, shin], hip, wb.center[ankle])
        _pin(wb, feet, 'foot.' + side)
    _pin(wb, _subtree(wb, 'helm'), 'head')
    _pin(wb, _subtree(wb, 'anchor_spike'), 'chest')
    _pin(wb, _subtree(wb, 'weapon_tip'), 'hand.R')
    _rigid(wb, r'torso|core_point|core_seam', 'chest')


def _forked(wb):
    # enemies-ch4ch5/05-04-Forked-Path-Guardian.mjs
    _capsule_arms(wb)
    _rigid(wb, r'wisp(?:_head)?\d+|echo_ripple\d+', 'root')
    _rigid(wb, r'core_point|echo_glow', 'chest')
    _rigid(wb, 'chant_ring', 'head')
    _same_skin(wb, r'body_light_half|body_rot_half', _one(wb, 'body'))
    _cloth(wb, 'cloud_sash', 'chest')


def _shadow(wb):
    # enemies-ch4ch5/05-05-Shadow-of-Possibility.mjs puts BOTH hands' items in
    # weapon_tip. Split by the authored item names, not that common ancestry.
    _capsule_arms(wb)
    _rigid(wb, r'axe_.*', 'hand.R')
    _rigid(wb, r'bow_.*|seal_.*|bead\d+', 'hand.L')
    _pin(wb, _subtree(wb, 'afterimages'), 'root')
    _rigid(wb, r'flow_wisp.*|shard\d+|ground_shadow', 'root')
    _rigid(wb, r'core_point|core_halo', 'chest')


REFINERS = {
    'enemies/02-blood-iron/06-Beacon-Keeper-Wraith.glb': _beacon,
    'enemies/03-jade-veil/02-Memory-Thief.glb': _memory,
    'enemies/03-jade-veil/03-Echo-Spirit.glb': _echo,
    'enemies/03-jade-veil/05-Wedding-Gown-Ghost.glb': _wedding,
    'enemies/03-jade-veil/06-Water-Moon.glb': _water,
    'enemies/03-jade-veil/07-Mirror-Flower-Spirit.glb': _flower,
    'enemies/03-jade-veil/10-Ember-Greedy-Ghost.glb': _greedy,
    'enemies/04-celestial-fall/01-Stairway-Guard-Wraith.glb': _stairway,
    'enemies/04-celestial-fall/04-Alchemy-Fallen-Immortal.glb': _alchemy,
    'enemies/04-celestial-fall/06-Library-Guardian-Spirit.glb': _library,
    'enemies/04-celestial-fall/07-Broken-Immortal-Body.glb': _broken,
    'enemies/05-throne-of-ashes/01-Ember-Shore-Drifter.glb': _drifter,
    'enemies/05-throne-of-ashes/02-Inverted-Guardian.glb': _inverted,
    'enemies/05-throne-of-ashes/04-Forked-Path-Guardian.glb': _forked,
    'enemies/05-throne-of-ashes/05-Shadow-of-Possibility.glb': _shadow,
}


def refine(wb):
    """Refine exactly the scoped originals; all other paths are strict no-ops."""
    refiner = REFINERS.get(wb.rel)
    if refiner is None:
        return
    refiner(wb)
    # Existing hand bones can precede newly added forearms in dict insertion order.
    pending, ordered = dict(wb.bones), {}
    while pending:
        ready = [name for name, spec in pending.items()
                 if not spec['parent'] or spec['parent'] in ordered]
        if not ready:
            raise ValueError(wb.rel + ': missing or cyclic bone parents')
        for name in ready:
            ordered[name] = pending.pop(name)
    wb.bones = ordered
    for obj in wb.parts:
        names = wb.blends[obj][1] if obj in wb.blends else [wb.assignment[obj]]
        if wb.assignment[obj] not in ordered or any(name not in ordered for name in names):
            raise ValueError(wb.rel + ': missing bone for ' + obj.name)
