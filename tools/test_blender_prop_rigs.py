"""CPU Blender contracts; run in a serialized, disposable background process.

blender --background --factory-startup --python-exit-code 1 --python tools/test_blender_prop_rigs.py
Reads retained originals only. Does not prepare, export, stage, or publish assets.
Preservation checks compare imported source data before/after bind, not GLB export.
"""
import sys

sys.dont_write_bytecode = True

from contextlib import contextmanager
import hashlib
import importlib.util
from pathlib import Path
import re

import bpy
import numpy as np


spec = importlib.util.spec_from_file_location('prop_contract_rig', Path(__file__).with_name('rig_glb_models.py'))
rig = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rig)
checks = 0
models = 0


def require(condition, message):
    global checks
    if not condition:
        raise AssertionError(message)
    checks += 1


def select(wb, pattern, group=None):
    result = [o for o in wb.parts if re.fullmatch(pattern, wb.names[o])
              and (group is None or any(wb.names[a] == group for a in wb.chains[o][1:]))]
    require(bool(result), '%s: missing %s in %s' % (wb.rel, pattern, group))
    return result


def one(wb, pattern, group=None):
    result = select(wb, pattern, group)
    require(len(result) == 1, '%s: ambiguous %s' % (wb.rel, pattern))
    return result[0]


def values(collection, property_name, width, dtype=np.float32):
    result = np.empty(len(collection) * width, dtype=dtype)
    collection.foreach_get(property_name, result)
    return result


def geometry_digest(obj):
    mesh = obj.data
    digest = hashlib.sha256()
    for collection, prop, width, dtype in (
            (mesh.vertices, 'co', 3, np.float32),
            (mesh.loops, 'vertex_index', 1, np.int32),
            (mesh.polygons, 'loop_start', 1, np.int32),
            (mesh.polygons, 'loop_total', 1, np.int32),
            (mesh.polygons, 'material_index', 1, np.int32),
            (mesh.corner_normals, 'vector', 3, np.float32)):
        digest.update(values(collection, prop, width, dtype).tobytes())
    for uv in mesh.uv_layers:
        digest.update(uv.name.encode('utf8'))
        digest.update(values(uv.data, 'uv', 2).tobytes())
    normals = mesh.attributes.get(rig._normals_tools.ATTRIBUTE)
    require(normals is not None, obj.name + ': missing captured source normals')
    digest.update(values(normals.data, 'vector', 3).tobytes())
    return digest.hexdigest()


def frozen(value):
    if isinstance(value, bpy.types.ID):
        return value.as_pointer()
    if isinstance(value, (str, int, float, bool)) or value is None:
        return value
    return tuple(value)


def material_state(material):
    state = [tuple(material.diffuse_color), material.metallic, material.roughness, material.use_nodes]
    tree = material.node_tree
    if tree:
        for node in tree.nodes:
            state.append((node.name, node.bl_idname,
                          tuple((p, frozen(getattr(node, p))) for p in
                                ('image', 'interpolation', 'extension', 'projection', 'operation', 'blend_type')
                                if hasattr(node, p)),
                          tuple((s.identifier, frozen(s.default_value)) for s in node.inputs
                                if hasattr(s, 'default_value'))))
            image = getattr(node, 'image', None)
            if image:
                state.append((image.name, tuple(image.size), image.colorspace_settings.name, image.alpha_mode,
                              hashlib.sha256(bytes(image.packed_file.data)).hexdigest() if image.packed_file else image.filepath))
        state.append(tuple((l.from_node.name, l.from_socket.identifier, l.to_node.name, l.to_socket.identifier)
                           for l in tree.links))
    return tuple(state)


def weights(obj):
    names = [g.name for g in obj.vertex_groups]
    result = np.zeros((len(obj.data.vertices), len(names)))
    for vertex in obj.data.vertices:
        for group in vertex.groups:
            result[vertex.index, group.group] = group.weight
    return names, result


def built(relative):
    global models
    source = rig.ORIGINALS / relative
    original_hash = hashlib.sha256(source.read_bytes()).digest()
    wb = rig.Workbench(relative)
    geometry = {o: geometry_digest(o) for o in wb.parts}
    slots = {o: tuple(o.data.materials) for o in wb.parts}
    materials = {m: material_state(m) for o in wb.parts for m in o.data.materials if m}
    wb.bind()
    require(wb.rest_error < wb.size * 1e-5, relative + ': changed rest geometry')
    require(not any(re.match(r'^(hips|chest|thigh|upper_arm|head|neck)(\.|$)', b) for b in wb.bones),
            relative + ': invented humanoid bones')
    for obj in wb.parts:
        require(geometry_digest(obj) == geometry[obj], obj.name + ': changed geometry/normals/UVs/material indices')
        require(tuple(obj.data.materials) == slots[obj], obj.name + ': changed material slots')
        require(any(m.type == 'ARMATURE' and m.object == wb.arm for m in obj.modifiers), obj.name + ': no skin modifier')
        names, skin = weights(obj)
        require(bool(names) and all(n in wb.arm.data.bones for n in names), obj.name + ': dangling weight bone')
        require(np.isfinite(skin).all() and (skin >= 0).all() and np.allclose(skin.sum(1), 1, atol=1e-5, rtol=0),
                obj.name + ': invalid weight sums')
        require(((skin > 1e-7).sum(1) <= 2).all(), obj.name + ': unexpected influence count')
        if obj in wb.blends:
            require(set(names) == set(wb.blends[obj][1]), obj.name + ': missing declared blend bones')
    require(all(material_state(m) == state for m, state in materials.items()), relative + ': changed materials/textures')
    require(hashlib.sha256(source.read_bytes()).digest() == original_hash, relative + ': changed original GLB')
    models += 1
    return wb


@contextmanager
def posed(wb, bone_name, axis=0, translation=None):
    bpy.context.window.scene = wb.scene
    bone = wb.arm.pose.bones[bone_name]
    saved = bone.matrix_basis.copy()
    try:
        bone.rotation_mode = 'XYZ'
        if translation is None:
            bone.rotation_euler[axis] = .25
        else:
            bone.location = translation
        bpy.context.view_layer.update()
        yield
    finally:
        bone.matrix_basis = saved
        bpy.context.view_layer.update()


def movement(wb, moving, fixed):
    for obj in moving + fixed:
        distance = np.linalg.norm(rig.world_points(obj, True) - wb.points[obj], axis=1).max()
        require(distance > wb.size * 1e-4 if obj in moving else distance < wb.size * 1e-5,
                '%s: %s unexpected isolated displacement %g' % (wb.rel, obj.name, distance))


def rigid(wb, objects):
    owners = {wb.assignment[o] for o in objects}
    require(len(owners) == 1, wb.rel + ': rigid assembly split across owners')
    owner = next(iter(owners))
    for obj in objects:
        names, skin = weights(obj)
        require(obj not in wb.blends and names == [owner] and np.allclose(skin, 1), obj.name + ': nonrigid hardware')
    return owner


def ring_indices(obj, end):
    uv = obj.data.uv_layers.active
    require(uv is not None, obj.name + ': missing tube UVs')
    u = np.array([uv.data[l.index].uv.x for l in obj.data.loops])
    target = u.min() if end == 0 else u.max()
    return np.unique([l.vertex_index for l in obj.data.loops if abs(uv.data[l.index].uv.x - target) < 1e-6])


def follows(wb, obj, indices, owner):
    arm = wb.arm
    transform = np.asarray(arm.matrix_world @ arm.pose.bones[owner].matrix @
                           arm.data.bones[owner].matrix_local.inverted() @ arm.matrix_world.inverted())
    expected = wb.points[obj][indices] @ transform[:3, :3].T + transform[:3, 3]
    actual = rig.world_points(obj, True)[indices]
    require(np.linalg.norm(actual - expected, axis=1).max() < wb.size * 5e-5,
            '%s: %s endpoint detached from %s' % (wb.rel, obj.name, owner))


def bow(relative):
    wb = built(relative)
    string = one(wb, r'bowstring|fire_string')
    arrows = select(wb, r'arrow_(?:shaft|head|ember|fletch.*)')
    rigid(wb, arrows)
    grip = select(wb, r'grip.*|arrow_rest|ember_grip')
    rigid(wb, grip)
    endpoints = [ring_indices(string, i) for i in (0, 1)]
    names, skin = weights(string)
    for side, indices in zip(('up', 'dn'), endpoints):
        tip = 'bow.' + side + '.03'
        require(tip in names and np.min(skin[indices, names.index(tip)]) > .999, relative + ': wrong string-end weights')
        horn = select(wb, 'horn_' + side + '_curl')
        require(rigid(wb, horn) == tip, relative + ': wrong horn owner')
        limbs = select(wb, 'limb_' + side + r'(?:_[fb])?')
        require(all(wb.blends[o][1] == wb.blends[limbs[0]][1] for o in limbs), relative + ': inconsistent limb layers')
        other = select(wb, 'limb_' + ('dn' if side == 'up' else 'up') + r'(?:_[fb])?')
        with posed(wb, 'bow.' + side + '.02'):
            movement(wb, limbs + horn + [string], grip + arrows + other)
            follows(wb, string, indices, tip)
            follows(wb, string, endpoints[1 if side == 'up' else 0], 'bow.' + ('dn' if side == 'up' else 'up') + '.03')
    with posed(wb, 'bow.draw', translation=(wb.size * .04, 0, 0)):
        movement(wb, [string], grip + arrows)
        for side, indices in zip(('up', 'dn'), endpoints):
            follows(wb, string, indices, 'bow.' + side + '.03')


def bundle():
    wb = built('weapons/12-Weapon-Types.glb')
    groups = {name: select(wb, '.*', name) for name in ('straight_sword', 'spear', 'war_hammer')}
    owners = {}
    for name, objects in groups.items():
        owners[name] = rigid(wb, [o for o in objects if not wb.names[o].startswith('spear_tassel')])
        others = [o for group, parts in groups.items() if group != name for o in parts]
        with posed(wb, owners[name]):
            movement(wb, objects, others)
    require(len(set(owners.values())) == 3, 'Weapon bundle shared an item bone')
    for tip in select(wb, 'weapon_tip'):
        expected = min(owners.values(), key=lambda n: abs(wb.center[tip][0] - wb.bones[n]['head'][0]))
        require(rigid(wb, [tip]) == expected, 'Bundle socket left behind')
    with posed(wb, 'spear.tassel.01'):
        movement(wb, select(wb, r'spear_tassel2?'), select(wb, r'spear_shaft|spear_head') + groups['straight_sword'] + groups['war_hammer'])


def armor():
    wb = built('equipment/01-LightArmor.glb')
    plinth = select(wb, 'plinth')
    require(rigid(wb, plinth) == 'root', 'Armor plinth is not fixed')
    cloth = select(wb, r'cloak_(?:front|back)')
    fixed = plinth + select(wb, r'belt|buckle|brooch') + select(wb, '.*', 'hood')
    with posed(wb, 'armor.cloak.01'):
        movement(wb, cloth, fixed)
        for obj in cloth:
            upper = wb.points[obj][:, 2] >= wb.blends[obj][2][2]
            require(upper.any(), 'Missing upper-cloak sample')
            require(np.linalg.norm(rig.world_points(obj, True)[upper] - wb.points[obj][upper], axis=1).max() < wb.size * 1e-5,
                    obj.name + ': upper cloak detached from belt')


def mechanisms():
    wb = built('props/04-Traps.glb')
    platform = select(wb, 'platform')
    with posed(wb, 'trap.pressure_top', translation=(0, -wb.size * .015, 0)):
        movement(wb, select(wb, r'plate_top|glow_seam|glyph_ring'), platform + select(wb, 'plate_base'))
    with posed(wb, 'trap.gate_slab', translation=(0, wb.size * .025, 0)):
        movement(wb, select(wb, r'gate_slab|band|ratchet_tooth', 'falling_gate'),
                 platform + select(wb, r'frame_post_[lr]|lintel|guide_rail|pulley_wheel', 'falling_gate'))
    with posed(wb, 'trap.pulley', axis=1):
        movement(wb, select(wb, r'pulley_wheel|pulley_spoke'), platform + select(wb, r'gate_slab|guide_rail', 'falling_gate'))
    wb = built('props/03-ForgeAndAnvil.glb')
    hinge = one(wb, 'door_hinge')
    require(np.allclose(wb.bones['forge.door']['head'], wb.center[hinge], atol=wb.size * 1e-6), 'Forge hinge pivot moved')
    door = select(wb, r'forge_door|door_latch')
    require(rigid(wb, door) == 'forge.door', 'Forge latch detached from door')
    with posed(wb, 'forge.door', axis=1):
        movement(wb, door, select(wb, r'furnace|furnace_rim|furnace_mouth|door_hinge|pedestal|anvil_body|anvil_face'))


def accessories():
    wb = built('equipment/04-Accessories.glb')
    board = select(wb, r'base|backboard|hang_rod|hook')
    require(rigid(wb, board) == 'root', 'Accessory board is not fixed')
    groups = ('jade_pendant', 'war_talisman', 'charm_bag')
    for group in groups:
        cord = one(wb, 'cord', group)
        require(cord in wb.blends, group + ': rigid cord')
        names, skin = weights(cord)
        require(np.count_nonzero(skin.sum(0) > 1e-6) >= 2, group + ': cord has no effective blend')
        require(group + '.cord.02' in names and np.max(skin[:, names.index(group + '.cord.02')]) > .99, group + ': unweighted distal chain')
        with posed(wb, group + '.cord.01'):
            movement(wb, select(wb, '.*', group), board + [o for other in groups if other != group for o in select(wb, '.*', other)])


def beads():
    wb = built('weapons/04-Sandalwood-Beads-Talisman.glb')
    cords = select(wb, r'cord_[lr]')
    require(wb.blends[cords[0]][1] == wb.blends[cords[1]][1], 'Bead-loop strands have independent terminal owners')
    for i in (0, 5, 11):
        require(rigid(wb, select(wb, 'bead_[lr]' + str(i))) == 'beads.row.%02d' % i, 'Bead row ownership changed')
    with posed(wb, 'beads.row.05'):
        movement(wb, cords + select(wb, r'bead_[lr]11|guru_bead|vajra_dn'), select(wb, r'clasp|vajra_top|bead_[lr]0'))
    with posed(wb, 'beads.paper.1.01'):
        movement(wb, select(wb, 'paper', 'talisman1'), select(wb, 'paper', 'talisman2') + select(wb, 'vajra_dn'))


def main():
    require(bpy.app.background, 'Run contracts in a disposable --background --factory-startup process')
    bow('weapons/01-WindHunter-Bow.glb')
    bow('weapons/05-Sun-Falling-Bow.glb')
    bundle()
    armor()
    mechanisms()
    accessories()
    beads()
    require(models == 8, 'Representative fixture inventory changed')
    print('BLENDER_PROP_RIGS_OK', checks, 'checks;', models, 'models; CPU skin/pose and imported-source preservation')


if __name__ == '__main__':
    main()
