"""Original-GLB CPU contracts; no exports or publication.

blender --background --factory-startup --python-exit-code 1 --python tools/test_blender_humanoid_rigs.py
Cases follow the corresponding enemies-ch1ch2/ch3/ch4ch5 generators.
"""
import importlib.util
from pathlib import Path
import re
import sys

sys.dont_write_bytecode = True

import bpy
import numpy as np

spec = importlib.util.spec_from_file_location('glb_rig', Path(__file__).with_name('rig_glb_models.py'))
rig = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rig)
checks = 0


def require(condition, description):
    global checks
    if not condition:
        raise AssertionError(description)
    checks += 1


def select(wb, selector):
    pattern, _, side = selector.partition(':')
    result = [o for o in wb.parts if
              (any(re.fullmatch(pattern[1:], wb.names[a]) for a in wb.chains[o][1:])
               if pattern.startswith('@') else re.fullmatch(pattern, wb.names[o]))
              and (not side or (wb.center[o][0] < 0) == (side == 'L'))]
    require(bool(result), wb.rel + ': missing ' + selector)
    return result


def owned(wb, objects, bone):
    for obj in objects:
        group = obj.vertex_groups.get(bone)
        require(group is not None and obj not in wb.blends and wb.assignment[obj] == bone,
                wb.rel + ': wrong owner ' + obj.name + ' -> ' + bone)
        require(all(len(v.groups) == 1 and v.groups[0].group == group.index
                    and abs(v.groups[0].weight - 1) < 1e-6 for v in obj.data.vertices),
                wb.rel + ': actual rigid weights ' + obj.name)


def head(wb, name):
    return np.asarray(wb.arm.matrix_world @ wb.arm.data.bones[name].head_local)


def branch(wb, name, moving_selector, fixed_selector, fixed_owner):
    moving, fixed = select(wb, moving_selector), select(wb, fixed_selector)
    owned(wb, moving, name)
    owned(wb, fixed, fixed_owner)
    bone = wb.arm.pose.bones[name]
    try:
        bone.rotation_euler.x = .3
        bpy.context.view_layer.update()
        for obj in moving + fixed:
            delta = float(np.linalg.norm(rig.world_points(obj, True) - wb.points[obj], axis=1).max())
            require(delta > wb.size * 1e-4 if obj in moving else delta < wb.size * 1e-5,
                    '%s: %s -> %s displacement %g' % (wb.rel, name, obj.name, delta))
    finally:
        bone.rotation_euler = (0, 0, 0)
        bpy.context.view_layer.update()
    for obj in moving + fixed:
        require(np.max(np.linalg.norm(rig.world_points(obj, True) - wb.points[obj], axis=1)) < wb.size * 1e-5,
                wb.rel + ': pose reset ' + obj.name)


# @ selects original ancestry, :L/:R selects the generator's negative/positive X side.
CASES = {
    '02-blood-iron/06-Beacon-Keeper-Wraith': [
        ('held.fireball', 'fireball.*|halo_outer|halo_inner', 'smoke.*|ground_shadow', 'root'),
        ('head', '@flame_spire', 'fireball.*|halo_outer|halo_inner', 'held.fireball')],
    '03-jade-veil/02-Memory-Thief': [
        ('hand.R', 'claw_tip|siphon_glow|hand_r', 'memory_orb|orb_halo|orb_orbit', 'root'),
        ('upper_arm.L', 'shoulder_spike|spike_tip:L', 'shoulder_spike|spike_tip:R', 'upper_arm.R')],
    '03-jade-veil/03-Echo-Spirit': [
        ('held.sword', 'blade.*|grip|guard', 'hand_l', 'hand.L'),
        ('hand.L', 'hand_l', 'blade.*|grip|guard', 'held.sword')],
    '03-jade-veil/05-Wedding-Gown-Ghost': [
        ('forearm.L', 'sleeve_cuff:L', 'sleeve_cuff:R', 'forearm.R'),
        ('head', 'crown.*|wail_aura', 'sash_belt|belt_tassel.*', 'hips')],
    '03-jade-veil/06-Water-Moon': [
        ('ornament.moon', 'moon_halo.*|moon_shard.*', 'ripple|pool_disc', 'root'),
        ('chest', 'moon_chest', 'splash|drop', 'root')],
    '03-jade-veil/07-Mirror-Flower-Spirit': [
        ('hips', r'skirt\d+', 'mirror_shard', 'root'),
        ('upper_arm.L', 'arm_l|mirror_arm_l', 'arm_r|mirror_arm_r', 'upper_arm.R')],
    '03-jade-veil/10-Ember-Greedy-Ghost': [
        ('head', 'maw|tooth|mask.*', 'ash_.*|back_trail', 'root'),
        ('hand.R', 'grab_claw:R', 'grab_claw:L', 'hand.L')],
    '04-celestial-fall/01-Stairway-Guard-Wraith': [
        ('hand.R', '@halberd', '@tower_shield', 'hand.L'),
        ('hand.L', '@tower_shield', 'wisp.*', 'root')],
    '04-celestial-fall/04-Alchemy-Fallen-Immortal': [
        ('hand.L', '@flask_l', '@flask_hand', 'hand.R'),
        ('hand.R', '@flask_hand', 'dan_qi.*|orbital_ring.*', 'root')],
    '04-celestial-fall/06-Library-Guardian-Spirit': [
        ('hand.R', '@weapon_tip', '@book_focus', 'held.book'),
        ('held.book', '@book_focus', 'orbit_page.*|orbit_ring|ground_halo', 'root')],
    '04-celestial-fall/07-Broken-Immortal-Body': [
        ('wing.R', '@stone_wing', 'energy_wisp.*', 'root'),
        ('head', '@cracked_halo', 'gauntlet_r', 'hand.R')],
    '05-throne-of-ashes/01-Ember-Shore-Drifter': [
        ('hand.L', 'hand_l|finger_l.*', 'hand_r|finger_r.*', 'hand.R'),
        ('chest', 'core_point|ember_glow', 'river_ripple.*|soul_mote.*', 'root')],
    '05-throne-of-ashes/02-Inverted-Guardian': [
        ('foot.L', '@foot_l', '@foot_r', 'foot.R'),
        ('hand.R', '@weapon_tip', '@helm', 'head')],
    '05-throne-of-ashes/04-Forked-Path-Guardian': [
        ('head', 'chant_ring', 'wisp.*|echo_ripple.*', 'root'),
        ('chest', 'core_point|echo_glow', 'wisp.*|echo_ripple.*', 'root')],
    '05-throne-of-ashes/05-Shadow-of-Possibility': [
        ('hand.R', 'axe_.*', 'bow_.*|seal_.*|bead.*', 'hand.L'),
        ('hand.L', 'bow_.*|seal_.*|bead.*', '@afterimages', 'root')],
}

for relative, cases in CASES.items():
    wb = rig.Workbench('enemies/' + relative + '.glb')
    wb.bind()
    require(wb.rest_error < wb.size * 1e-5, wb.rel + ': bind rest mismatch')
    seen = set()
    for bone in wb.arm.data.bones:
        parent = bone.parent.name if bone.parent else ''
        require((not parent or parent in seen) and parent == wb.bones[bone.name]['parent'], wb.rel + ': hierarchy ' + bone.name)
        require(bone.length > wb.size * 1e-6 and np.allclose(head(wb, bone.name), wb.bones[bone.name]['head'], atol=wb.size * 1e-5, rtol=0), wb.rel + ': local rest ' + bone.name)
        if bone.name.startswith('hand.'):
            require(parent == bone.name.replace('hand.', 'forearm.'), wb.rel + ': detached hand')
        seen.add(bone.name)
    for obj in wb.parts:
        require(any(m.type == 'ARMATURE' and m.object == wb.arm for m in obj.modifiers), obj.name + ': missing modifier')
        require(all(v.groups and all(np.isfinite(g.weight) and g.weight >= 0 for g in v.groups)
                    and abs(sum(g.weight for g in v.groups) - 1) < 1e-5 for v in obj.data.vertices), obj.name + ': invalid weights')
        if obj in wb.blends and wb.blends[obj][0] == 'curve' and wb.blends[obj][1][0].startswith('upper_arm.'):
            curve, side = wb.tube_centers(obj), wb.blends[obj][1][0].split('.')[-1]
            for bone, point in [('upper_arm.', curve[0]), ('forearm.', curve[len(curve) // 2]), ('hand.', curve[-1])]:
                require(np.linalg.norm(head(wb, bone + side) - point) < wb.size * 1e-5, obj.name + ': authored tube pivot')
    if not any(re.fullmatch(r'(?:foot|boot)(?:_[lr])?', wb.names[o]) for o in wb.parts):
        require(not any(n.startswith('foot.') for n in seen), wb.rel + ': fabricated feet')
    for name in ('held.sword', 'held.book'):
        if name in seen:
            require(wb.arm.data.bones[name].parent.name == 'root', wb.rel + ': floating control attached to anatomy')
    if 'Echo-Spirit' in relative:
        require(not {'hand.R', 'forearm.R'} & seen, wb.rel + ': fabricated right arm')
    if 'Inverted-Guardian' in relative:
        require(head(wb, 'head')[2] > head(wb, 'hips')[2], wb.rel + ': source flipped')
        for side in ('L', 'R'):
            require(np.linalg.norm(head(wb, 'foot.' + side) - wb.center[select(wb, 'ankle_ring:' + side)[0]]) < wb.size * 1e-5, wb.rel + ': ankle pivot')
            owned(wb, select(wb, '@pauldron_' + side.lower()), 'upper_arm.' + side)
    for case in cases:
        branch(wb, *case)
print('BLENDER_HUMANOID_RIGS_OK', checks, 'checks; 15 originals; 30 isolated branches')
