"""Live Blender contracts for the five source-refined creature rigs.

blender --background --factory-startup --python-exit-code 1 --python tools/test_blender_creature_rigs.py
Imports retained originals and binds in memory only; no prepare/export/publication.
"""
import hashlib
import importlib.util
from pathlib import Path
import sys

import bpy
import numpy as np


sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('creature_contract_rig', Path(__file__).with_name('rig_glb_models.py'))
rig = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rig)
checks = 0
branches = 0


def require(condition, message):
    global checks
    if not condition:
        raise AssertionError(message)
    checks += 1


def parts(wb, *names):
    found = [obj for obj in wb.parts if wb.names[obj] in names]
    require(set(names) <= {wb.names[obj] for obj in found}, wb.rel + ': missing ' + str(names))
    return found


def prefix(wb, *names):
    found = [obj for obj in wb.parts if wb.names[obj].startswith(names)]
    require(bool(found), wb.rel + ': missing prefixes ' + str(names))
    return found


def subtree(wb, name, count):
    found = [obj for obj in wb.parts if any(wb.names[a] == name for a in wb.chains[obj][1:])]
    require(len(found) == count, wb.rel + ': subtree count ' + name)
    return found


def pinned(wb, objects, bone):
    require(bool(objects), 'Empty pin contract: ' + bone)
    for obj in objects:
        require(wb.assignment[obj] == bone and obj not in wb.blends, obj.name + ': owner ' + bone)
        require({g.name for g in obj.vertex_groups} == {bone}, obj.name + ': unexpected rigid groups')


def mesh_state(obj):
    mesh = obj.data
    coordinates = np.empty(len(mesh.vertices) * 3, dtype=np.float64)
    mesh.vertices.foreach_get('co', coordinates)
    loops = np.empty(len(mesh.loops), dtype=np.int32)
    mesh.loops.foreach_get('vertex_index', loops)
    polygons = tuple((p.loop_start, p.loop_total) for p in mesh.polygons)
    uvs = []
    for layer in mesh.uv_layers:
        values = np.empty(len(layer.data) * 2, dtype=np.float64)
        layer.data.foreach_get('uv', values)
        uvs.append((layer.name, values.tobytes()))
    return coordinates.tobytes(), loops.tobytes(), polygons, tuple(uvs)


def rest(wb):
    tolerance = wb.size * 1e-5
    for obj in wb.parts:
        require(mesh_state(obj) == wb._contract_mesh[obj], obj.name + ': source geometry/UVs changed')
        require(np.allclose(obj.matrix_world, wb._contract_world[obj], atol=1e-6, rtol=0),
                obj.name + ': world matrix changed')
        require(np.array_equal(wb.points[obj], wb._contract_points[obj]), obj.name + ': reference points changed')
        distance = np.linalg.norm(rig.world_points(obj, True) - wb._contract_points[obj], axis=1)
        require(float(distance.max()) < tolerance, obj.name + ': evaluated rest pose changed')
    for bone in wb.arm.pose.bones:
        skin = bone.matrix @ bone.bone.matrix_local.inverted()
        require(np.allclose(skin, np.eye(4), atol=1e-5, rtol=0), bone.name + ': nonidentity rest skin matrix')


def built(relative, bone_count, mesh_count, blend_count):
    wb = rig.Workbench(relative)
    wb._contract_points = {obj: points.copy() for obj, points in wb.points.items()}
    wb._contract_world = {obj: np.asarray(obj.matrix_world).copy() for obj in wb.parts}
    wb._contract_mesh = {obj: mesh_state(obj) for obj in wb.parts}
    wb.bind()
    require(len(wb.bones) == len(wb.arm.data.bones) == bone_count, relative + ': bone count')
    require(len(wb.parts) == mesh_count and len(wb.blends) == blend_count, relative + ': mesh/blend counts')
    require(wb.rest_error < wb.size * 1e-5 and wb.pose_move > wb.size * 1e-4, relative + ': bind/deform summary')
    seen = set()
    for name, definition in wb.bones.items():
        parent = definition['parent']
        require(not parent or parent in seen, name + ': parent must precede child')
        bone = wb.arm.data.bones[name]
        require((bone.parent.name if bone.parent else '') == parent, name + ': actual parent mismatch')
        require(np.allclose(bone.head_local, definition['head'], atol=wb.size * 1e-5, rtol=0), name + ': head mismatch')
        require(np.allclose(bone.tail_local, definition['tail'], atol=wb.size * 1e-5, rtol=0), name + ': tail mismatch')
        matrix = np.asarray(bone.matrix_local)
        require(np.isfinite(matrix).all() and abs(np.linalg.det(matrix)) > 1e-8, name + ': singular rest matrix')
        seen.add(name)
    for obj in wb.parts:
        require(obj.parent == wb.arm, obj.name + ': missing armature parent')
        modifiers = [m for m in obj.modifiers if m.type == 'ARMATURE']
        require(len(modifiers) == 1 and modifiers[0].object == wb.arm, obj.name + ': armature modifier')
        expected = set(wb.blends[obj][1]) if obj in wb.blends else {wb.assignment[obj]}
        groups = {g.index: g.name for g in obj.vertex_groups}
        require(set(groups.values()) == expected and expected <= seen, obj.name + ': weight targets')
        used = set()
        for vertex in obj.data.vertices:
            weights = [g.weight for g in vertex.groups]
            require(bool(weights) and np.isfinite(weights).all() and min(weights) >= 0
                    and max(weights) <= 1 and abs(sum(weights) - 1) < 1e-5,
                    obj.name + ': invalid weights at vertex ' + str(vertex.index))
            used.update(groups[g.group] for g in vertex.groups if g.weight > 1e-7)
        require(bool(used) and used <= expected, obj.name + ': invalid effective weight targets')
        if obj in wb.blends:
            require(len(used) > 1, obj.name + ': continuous mesh has only rigid weights')
    rest(wb)
    return wb


def branch(wb, name, moving, fixed):
    global branches
    require(bool(moving) and bool(fixed) and not set(moving).intersection(fixed), name + ': invalid branch selection')
    rest(wb)
    bone = wb.arm.pose.bones[name]
    try:
        bone.rotation_mode = 'XYZ'
        bone.rotation_euler.x = .3
        bpy.context.view_layer.update()
        for obj in moving + fixed:
            actual = rig.world_points(obj, True)
            distance = float(np.linalg.norm(actual - wb._contract_points[obj], axis=1).max())
            require(distance > wb.size * 1e-4 if obj in moving else distance < wb.size * 1e-5,
                    '%s: %s -> %s displacement %g' % (wb.rel, name, obj.name, distance))
            require(np.allclose(obj.matrix_world, wb._contract_world[obj], atol=1e-6, rtol=0),
                    obj.name + ': object moved instead of skin')
            if obj in moving and obj not in wb.blends:
                owner = wb.arm.pose.bones[wb.assignment[obj]]
                transform = np.asarray(wb.arm.matrix_world @ owner.matrix @ owner.bone.matrix_local.inverted()
                                       @ wb.arm.matrix_world.inverted())
                expected = wb._contract_points[obj] @ transform[:3, :3].T + transform[:3, 3]
                require(np.allclose(actual, expected, atol=wb.size * 1e-5, rtol=0), obj.name + ': incoherent rigid attachment')
    finally:
        bone.rotation_euler = (0, 0, 0)
        bpy.context.view_layer.update()
    rest(wb)
    branches += 1


def wing_cases(wb, count, landmark):
    wings = {side: subtree(wb, 'wing_' + side.lower(), count) for side in ('L', 'R')}
    for side in ('L', 'R'):
        objects = wings[side]
        pinned(wb, objects, 'wing.' + side)
        roots = [obj for obj in objects if wb.names[obj] == landmark]
        require(len(roots) == 1, side + ': missing wing landmark')
        require(np.allclose(wb.bones['wing.' + side]['head'], wb._contract_world[roots[0]][:3, 3],
                            atol=wb.size * 1e-5, rtol=0), side + ': wing pivot is not authored root')
        branch(wb, 'wing.' + side, objects, wings['R' if side == 'L' else 'L'] + parts(wb, 'head', 'body'))
    return wings['L'] + wings['R']


def butterfly():
    wb = built('enemies/03-jade-veil/01-Illusion-Butterfly.glb', 16, 38, 0)
    wings = parts(wb, 'wing')
    require(len(wings) == 4, 'Butterfly wing count')
    for side, sign in (('L', -1), ('R', 1)):
        pair = sorted([o for o in wings if wb._contract_world[o][0, 3] * sign > 0],
                      key=lambda o: -wb._contract_world[o][2, 3])
        require(len(pair) == 2, side + ': fore/hind wing pair')
        spots = [o for o in prefix(wb, 'eye_spot') if wb.center[o][0] * sign > 0]
        require(len(spots) == 2, side + ': eye spot pair')
        for index, obj in enumerate(pair, 1):
            name = 'wing.%s.%02d' % (side, index)
            pinned(wb, [obj], name)
            require(np.allclose(wb.bones[name]['head'], wb._contract_world[obj][:3, 3], atol=1e-6, rtol=0), name + ': pivot')
        pinned(wb, spots, 'wing.' + side + '.01')
        branch(wb, 'wing.' + side + '.01', [pair[0]] + spots,
               [o for o in wings if o != pair[0]] + parts(wb, 'thorax', 'antenna'))
        if side == 'L':
            branch(wb, 'wing.L.02', [pair[1]], [pair[0]] + spots + parts(wb, 'thorax'))
    head = parts(wb, 'head', 'antenna', 'antenna_tip', 'proboscis')
    pinned(wb, head, 'head')
    pinned(wb, parts(wb, 'thorax'), 'chest')
    branch(wb, 'head', head, wings + parts(wb, 'thorax'))
    legs = parts(wb, 'leg')
    require(len(legs) == 6, 'Butterfly leg count')
    for obj in legs:
        require(wb.bones[wb.assignment[obj]]['parent'] == 'chest', obj.name + ': thoracic leg parent')
    left = sorted([o for o in legs if wb.center[o][0] < 0], key=lambda o: -wb.center[o][2])
    pinned(wb, [left[0]], 'thigh.L.01')
    branch(wb, 'thigh.L.01', [left[0]], [o for o in legs if o != left[0]] + wings)


def guardian():
    wb = built('enemies/03-jade-veil/08-Maze-Guardian.glb', 22, 46, 1)
    base = parts(wb, 'plinth', 'rune_ring', 'stone_ball', 'ball_ring')
    pinned(wb, base, 'root')
    pinned(wb, prefix(wb, 'back_spike', 'crack_'), 'chest')
    for end in ('front', 'hind'):
        for side in ('L', 'R'):
            suffix = end + '.' + side
            require(wb.bones['shin.' + suffix]['parent'] == 'thigh.' + suffix, suffix + ': knee parent')
            require(wb.bones['foot.' + suffix]['parent'] == 'shin.' + suffix, suffix + ': paw parent')
            for segment, code in (('thigh', 'u'), ('shin', 'f'), ('foot', 'paw')):
                pinned(wb, parts(wb, end + '_' + side.lower() + code), segment + '.' + suffix)
    branch(wb, 'shin.front.L', parts(wb, 'front_lf', 'front_lpaw'), parts(wb, 'hind_lf', 'hind_lpaw', 'front_rf', 'head') + base)
    branch(wb, 'shin.hind.R', parts(wb, 'hind_rf', 'hind_rpaw'), parts(wb, 'front_rf', 'front_rpaw', 'hind_lf', 'body') + base)
    pinned(wb, parts(wb, 'tail_tuft'), 'tail.04')
    require(wb.blends[parts(wb, 'tail')[0]][1] == ['tail.%02d' % i for i in range(1, 5)], 'Guardian tail chain')
    branch(wb, 'tail.01', parts(wb, 'tail', 'tail_tuft'), parts(wb, 'body', 'head', 'hind_lpaw', 'hind_rpaw') + base)
    mane = parts(wb, 'mane_curl')
    require(len(mane) == 7, 'Guardian mane count')
    pinned(wb, mane, 'neck')
    branch(wb, 'neck', mane + parts(wb, 'head', 'jaw_upper', 'jaw_lower'), parts(wb, 'body') + base)


def fox():
    wb = built('enemies/03-jade-veil/09-MindLost-Fox-Demon.glb', 26, 51, 5)
    spell = parts(wb, 'confusion_orb') + prefix(wb, 'orb_')
    require(len(spell) == 6, 'Fox spell count')
    pinned(wb, spell, 'hand.R')
    pinned(wb, prefix(wb, 'torn_sash'), 'hips')
    for side in ('L', 'R'):
        require(wb.bones['hand.' + side]['parent'] == 'forearm.' + side, side + ': wrist parent')
        require(wb.bones['forearm.' + side]['parent'] == 'upper_arm.' + side, side + ': elbow parent')
        pinned(wb, prefix(wb, 'claw_' + side.lower()), 'hand.' + side)
    branch(wb, 'forearm.R', parts(wb, 'arm_rf', 'hand_r') + prefix(wb, 'claw_r') + spell,
           parts(wb, 'head', 'hand_l') + prefix(wb, 'claw_l', 'tail'))
    branch(wb, 'hand.L', parts(wb, 'hand_l') + prefix(wb, 'claw_l'), parts(wb, 'head', 'arm_lf') + spell)
    tails = {}
    for name, sign in (('tail1', 1), ('tail2', -1)):
        tails[name] = parts(wb, name) + [o for o in parts(wb, 'tail_tip', 'tail_tuft') if wb.center[o][0] * sign > 0]
        require(len(tails[name]) == 3, name + ': base/tip/tuft count')
        chain = [name + '.%02d' % i for i in range(1, 5)]
        require(wb.bones[chain[0]]['parent'] == 'hips', name + ': independent tail root')
        for obj in tails[name]:
            if wb.names[obj] == 'tail_tuft':
                pinned(wb, [obj], chain[-1])
            else:
                require(wb.blends[obj][0] == 'curve' and wb.blends[obj][1] == chain, obj.name + ': tail curve crossed')
    for name, other in (('tail1', 'tail2'), ('tail2', 'tail1')):
        branch(wb, name + '.01', tails[name], tails[other] + parts(wb, 'head') + spell)
    branch(wb, 'shin.R', parts(wb, 'leg_rf', 'foot_r'), parts(wb, 'leg_lf', 'foot_l', 'torso') + spell)


def eagle():
    wb = built('enemies/04-celestial-fall/02-Cloud-Sky-Eagle.glb', 15, 77, 2)
    wings = wing_cases(wb, 19, 'root_ring')
    tail = subtree(wb, 'tail', 10)
    pinned(wb, tail, 'tail.01')
    require([name for name in wb.bones if name.startswith('tail.')] == ['tail.01'], 'Eagle fan has serial joints')
    pinned(wb, parts(wb, 'cloud_trail') + prefix(wb, 'trail_mote'), 'root')
    pinned(wb, parts(wb, 'back_halo', 'halo_core'), 'chest')
    branch(wb, 'tail.01', tail, wings + parts(wb, 'body', 'head'))
    legs = {side: subtree(wb, 'leg_' + side.lower(), 5) for side in ('L', 'R')}
    for side, objects in legs.items():
        pinned(wb, [o for o in objects if wb.names[o].startswith('claw')], 'foot.' + side)
        leg = next(o for o in objects if wb.names[o] == 'leg')
        require(wb.blends[leg][1] == ['thigh.' + side, 'shin.' + side], side + ': continuous leg weights')
    branch(wb, 'shin.L', [o for o in legs['L'] if wb.names[o] != 'leg_ring'],
           [o for o in legs['L'] if wb.names[o] == 'leg_ring'] + legs['R'] + tail)
    branch(wb, 'head', parts(wb, 'head') + prefix(wb, 'beak', 'crest'), wings + parts(wb, 'back_halo', 'halo_core'))


def bat():
    wb = built('enemies/05-throne-of-ashes/03-Ember-Bat.glb', 10, 36, 0)
    wings = wing_cases(wb, 6, 'membrane')
    feet = {side: subtree(wb, 'foot_' + side.lower(), 4) for side in ('L', 'R')}
    ash = prefix(wb, 'ash_crumb')
    require(len(ash) == 5, 'Bat ash count')
    pinned(wb, ash, 'root')
    for side, objects in feet.items():
        pinned(wb, objects, 'foot.' + side)
        ankle = next(o for o in objects if wb.names[o] == 'ankle')
        require(np.allclose(wb.bones['foot.' + side]['head'], wb._contract_world[ankle][:3, 3],
                            atol=1e-6, rtol=0), side + ': foot pivot is not ankle')
        branch(wb, 'foot.' + side, objects, feet['R' if side == 'L' else 'L'] + wings + ash)
    mouth = parts(wb, 'head', 'weapon_tip', 'glow_ring') + prefix(wb, 'fang', 'ear_', 'eye_')
    pinned(wb, mouth, 'head')
    branch(wb, 'head', mouth, wings + feet['L'] + feet['R'] + ash)


def main():
    sources = {path: hashlib.sha256(path.read_bytes()).digest() for path in rig.ORIGINALS.rglob('*.glb')}
    for test in (butterfly, guardian, fox, eagle, bat):
        test()
    require(branches == 24, 'Unexpected isolated branch case count')
    require(bool(sources) and all(hashlib.sha256(path.read_bytes()).digest() == digest
                                 for path, digest in sources.items()), 'Original GLB bytes changed')
    print('BLENDER_CREATURE_RIGS_OK', checks, 'checks; 5 models;', branches, 'isolated branches', flush=True)


if __name__ == '__main__':
    main()
