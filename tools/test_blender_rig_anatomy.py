"""Blender CPU contracts for attachment ownership and independent branch deformation.

blender --background --factory-startup --python-exit-code 1 --python tools/test_blender_rig_anatomy.py
Does not export GLBs, publish assets, or touch the user's interactive Blender scene.
"""
import importlib.util
from pathlib import Path

import bpy
import numpy as np
from io_scene_gltf2.blender.imp import mesh as gltf_importer
from io_scene_gltf2.blender.exp.primitive_extract import PrimitiveCreator


spec = importlib.util.spec_from_file_location('glb_rig', Path(__file__).with_name('rig_glb_models.py'))
rig = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rig)
checks = 0


def require(condition, description):
    global checks
    if not condition:
        raise AssertionError(description)
    checks += 1


def parts(wb, names):
    result = [o for o in wb.parts if wb.names[o] in names]
    require(len(result) >= len(names), 'Missing contract mesh: ' + str(names))
    return result


def branch(wb, bone_name, moving, fixed):
    bone = wb.arm.pose.bones[bone_name]
    bone.rotation_euler.x = .3
    bpy.context.view_layer.update()
    for obj in moving + fixed:
        displacement = float(np.linalg.norm(rig.world_points(obj, True) - wb.points[obj], axis=1).max())
        require(displacement > wb.size * .0001 if obj in moving else displacement < wb.size * .00001,
                '%s -> %s unexpected displacement %g' % (bone_name, obj.name, displacement))
    bone.rotation_euler = (0, 0, 0)
    bpy.context.view_layer.update()


def built(relative):
    import_method = gltf_importer.set_poly_smoothing
    wb = rig.Workbench(relative)
    require(gltf_importer.set_poly_smoothing is import_method, 'Importer hook was not restored')
    wb.bind()
    require(wb.rest_error < wb.size * 1e-5, 'Rest pose mismatch: ' + relative)
    for obj in wb.parts:
        normals = obj.data.attributes.get(rig._normals_tools.ATTRIBUTE)
        require(normals is not None and len(normals.data) == len(obj.data.vertices), obj.name + ' missing captured source normals')
        require(any(m.type == 'ARMATURE' and m.object == wb.arm for m in obj.modifiers), obj.name + ' missing modifier')
        for vertex in obj.data.vertices:
            total = sum(g.weight for g in vertex.groups)
            require(abs(total - 1) < 1e-5, obj.name + ' invalid vertex weight sum')
    return wb


crane = built('characters/summons/05-WhiteCraneAttendant.glb')
require(crane.bones['hips']['head'][2] < crane.bones['chest']['head'][2], 'Hips above chest')
fan = [o for o in crane.parts if crane.names[o].startswith('fan_')]
require(bool(fan), 'Missing fan')
require(all(crane.assignment[o] == 'hand.L' for o in fan), 'Fan not bound to hand.L')
require(crane.bones['hand.L']['parent'] == 'forearm.L', 'Hand detached from elbow')
fx = [o for o in crane.parts if crane.names[o].startswith(('wind_', 'lift_'))]
require(all(crane.assignment[o] == 'root' for o in fx), 'Free wind effects bound to anatomy')
branch(crane, 'forearm.L', fan, fx + parts(crane, {'head'}))
for side in ('L', 'R'):
    feathers = [o for o in crane.parts if crane.names[o].startswith('wingfeather') and crane.side(o) == side]
    require(len(feathers) == 8, 'Wing ancestry lost feathers: ' + side)
    require(all(crane.assignment[o] == 'wing.' + side for o in feathers), 'Cross-bound feather')
    other = [o for o in crane.parts if crane.names[o].startswith('wingfeather') and crane.side(o) != side]
    branch(crane, 'wing.' + side, feathers, other + fx)

soldier = built('enemies/01-spirit-ruins/01-Lost-Soul-Soldier.glb')
require(soldier.bones['hand.R']['parent'] == 'forearm.R', 'Soldier hand chain')
require(soldier.bones['forearm.R']['parent'] == 'upper_arm.R', 'Soldier elbow chain')
sword = [o for o in soldier.parts if soldier.names[o].startswith('sword')]
branch(soldier, 'forearm.R', sword + parts(soldier, {'hand_r'}), parts(soldier, {'head', 'arm_l'}))
rivets = [o for o in soldier.parts if soldier.names[o].startswith('pauldron_rivet')]
require(all(soldier.assignment[o] == 'upper_arm.R' for o in rivets), 'Shoulder rivet crossed to opposite arm')
branch(soldier, 'upper_arm.L', parts(soldier, {'arm_l'}), rivets)
require(parts(soldier, {'back_cape'})[0] in soldier.blends, 'Back cape missing skin blend')
require(parts(soldier, {'cape_belt'})[0] not in soldier.blends, 'Rigid cape belt made into cloth')
for name in ('arm_l', 'arm_r', 'leg_l', 'leg_r'):
    require(parts(soldier, {name})[0] in soldier.blends, 'Continuous limb has rigid-only weights: ' + name)

quad = built('enemies/02-blood-iron/02-War-Dog-Wraith.glb')
for suffix, short in [('front.L', 'fl'), ('front.R', 'fr'), ('hind.L', 'bl'), ('hind.R', 'br')]:
    shin, foot = 'shin.' + suffix, 'foot.' + suffix
    require(quad.bones[foot]['parent'] == shin, 'Foot detached from knee: ' + suffix)
    require(quad.bones[shin]['parent'] == 'thigh.' + suffix, 'Knee detached from thigh: ' + suffix)
    moving = parts(quad, {'leg_' + short, 'leg_' + short + 'paw'})
    branch(quad, shin, moving, parts(quad, {'body', 'head'}))

slag = built('enemies/01-spirit-ruins/04-Furnace-Slag-Beast.glb')
scorch = parts(slag, {'scorch_ring'})
require(slag.assignment[scorch[0]] == 'root', 'Scorch bound to foot')
branch(slag, 'forearm.L', parts(slag, {'fist_l'}), scorch + parts(slag, {'fist_r'}))

guard = built('enemies/02-blood-iron/05-Generals-Personal-Guard.glb')
glaive = [o for o in guard.parts if any(guard.names[a] == 'war_glaive' for a in guard.chains[o])]
require(len(glaive) == 6, 'Glaive subtree incomplete')
require(all(guard.assignment[o] == 'hand.R' for o in glaive), 'Glaive split across bones')
ornaments = [o for o in guard.parts if guard.names[o].startswith('beast_')]
require(all(guard.assignment[o] == 'upper_arm.' + guard.side(o) for o in ornaments), 'Shoulder ornaments bound to head')
banner = [o for o in guard.parts if any(guard.names[a] == 'banner' for a in guard.chains[o])]
require(all(guard.assignment[o] == 'chest' for o in banner), 'Back banner bound to head')
branch(guard, 'forearm.R', glaive, banner + ornaments)
branch(guard, 'head', parts(guard, {'head'}), ornaments + banner)

battle = built('enemies/02-blood-iron/01-Lost-Soldier-BattleWorn.glb')
spear = [o for o in battle.parts if any(battle.names[a] == 'iron_spear' for a in battle.chains[o])]
require(len(spear) == 5, 'Spear subtree incomplete')
owners = {battle.assignment[o] for o in spear}
require(len(owners) == 1 and next(iter(owners)).startswith('hand.'), 'Spear tassel split off weapon')
branch(battle, next(iter(owners)), spear, parts(battle, {'head', 'torso'}))
normal_method = PrimitiveCreator._PrimitiveCreator__get_normals
try:
    with rig._normals_tools.exact_export():
        require(PrimitiveCreator._PrimitiveCreator__get_normals is not normal_method, 'Exporter hook not installed')
        raise RuntimeError('intentional restoration test')
except RuntimeError as error:
    require(str(error) == 'intentional restoration test', 'Unexpected export-hook failure')
require(PrimitiveCreator._PrimitiveCreator__get_normals is normal_method, 'Exporter hook not restored after failure')
print('BLENDER_RIG_ANATOMY_OK', checks, 'checks; 6 models; isolated attachment and deformation contracts')
