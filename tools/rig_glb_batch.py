"""Run the existing Blender rig workbench in an isolated background process.

blender --background --factory-startup --python-exit-code 1 --python tools/rig_glb_batch.py --
    --prefix 007-summons-enemies <relative-original.glb> ...
Exports stay staged. Solid-shaded renders and projected actual pose bones are review
evidence, not a substitute for material validation or explicit publication.
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import sys

import bpy
import numpy as np
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector


def load_workbench():
    sys.dont_write_bytecode = True
    path = Path(__file__).with_name('rig_glb_models.py')
    spec = importlib.util.spec_from_file_location('glb_rig', path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def pose(wb, enabled):
    selected = []
    prefixes = ('forearm.', 'upper_arm.', 'wing.', 'tail', 'cloth.', 'book.cover.',
                'torture.door', 'torture.chain.', 'lantern.tassel.', 'furnace.lid',
                'part.petal_', 'trap.', 'puzzle.', 'forge.door', 'ambient.',
                'bow.', 'armor.', 'beads.', 'seal.', 'sword.tassel', 'sword.talisman',
                'fan.tassel', 'axe_left.', 'axe_right.', 'spear.tassel',
                'jade_pendant.cord.', 'war_talisman.cord.', 'charm_bag.cord.', 'pickup.cork')
    for bone in wb.arm.pose.bones:
        bone.rotation_mode = 'XYZ'
        bone.rotation_euler = (0, 0, 0)
        bone.location = (0, 0, 0)
        if enabled and bone.name.startswith(prefixes):
            angle = .06 if bone.name.startswith('beads.row.') else .10 if bone.name.startswith(('tail', 'cloth.', 'bow.')) else .22
            axis = 1 if bone.name.startswith(('torture.door', 'book.cover.', 'forge.door', 'puzzle.mirror', 'trap.pulley')) else 0
            translations = {'trap.pressure_top': -.025, 'trap.gate_slab': .08,
                            'furnace.lid': .04, 'puzzle.cauldron_lid': .04,
                            'pickup.cork': .035, 'ambient.coffin_lid': .04}
            if bone.name in translations:
                bone.location.y = wb.size * translations[bone.name]
            else:
                bone.rotation_euler[axis] = angle
            selected.append(bone.name)
    if enabled and not selected:
        weighted = set(wb.assignment.values()) - {'root', 'body', 'hips', 'spine', 'chest'}
        if not weighted:
            weighted = set(wb.assignment.values()) - {'root'}
        if not weighted:
            raise RuntimeError('No weighted non-root review bone: ' + wb.rel)
        name = sorted(weighted)[0]
        wb.arm.pose.bones[name].rotation_euler.x = .22
        selected.append(name)
    bpy.context.view_layer.update()
    return selected


def setup_camera(wb):
    scene = wb.scene
    data = bpy.data.cameras.new('RigReviewCamera')
    camera = bpy.data.objects.new('RigReviewCamera', data)
    scene.collection.objects.link(camera)
    data.type = 'ORTHO'
    data.clip_start = max(wb.size * .001, .00001)
    data.clip_end = wb.size * 50
    scene.camera = camera
    scene.render.engine = 'BLENDER_WORKBENCH'
    scene.render.resolution_x = 720
    scene.render.resolution_y = 720
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode = 'RGBA'
    scene.render.film_transparent = False
    shading = scene.display.shading
    shading.light = 'STUDIO'
    shading.color_type = 'MATERIAL'
    shading.show_shadows = True
    shading.show_cavity = True
    shading.cavity_type = 'BOTH'
    shading.background_type = 'WORLD'
    scene.world = bpy.data.worlds.new('RigReviewWorld')
    scene.world.color = (.12, .14, .16)
    scene.view_settings.view_transform = 'Standard'
    for obj in wb.parts:
        for material in obj.data.materials:
            if material and material.use_nodes:
                shader = next((n for n in material.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'), None)
                if shader:
                    material.diffuse_color = shader.inputs['Base Color'].default_value
    return camera


def render(wb, module, camera, path, posed):
    selected = pose(wb, posed)
    points = np.concatenate([module.world_points(o, True) for o in wb.parts])
    all_points = np.concatenate([points, *wb.points.values()])
    center = Vector((all_points.min(0) + all_points.max(0)) / 2)
    direction = Vector((.65 if posed else 0, -1, .30 if posed else .12)).normalized()
    camera.location = center + direction * wb.size * 4
    camera.rotation_euler = (-direction).to_track_quat('-Z', 'Y').to_euler()
    bpy.context.view_layer.update()
    inverse = np.asarray(camera.matrix_world.inverted())
    view_points = all_points @ inverse[:3, :3].T + inverse[:3, 3]
    camera.data.ortho_scale = float(max(np.ptp(view_points[:, 0]), np.ptp(view_points[:, 1]))) * 1.20
    bounds = (view_points.min(0) + view_points.max(0)) / 2
    camera.location += camera.matrix_world.to_quaternion() @ Vector((bounds[0], bounds[1], 0))
    bpy.context.view_layer.update()
    wb.scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)

    def project(value):
        p = world_to_camera_view(wb.scene, camera, wb.arm.matrix_world @ value)
        return [float(p.x * 720), float((1 - p.y) * 720)]

    bones = [{'name': b.name, 'parent': b.parent.name if b.parent else None,
              'head': project(b.head), 'tail': project(b.tail)} for b in wb.arm.pose.bones]
    move = max(float(np.linalg.norm(module.world_points(o, True) - wb.points[o], axis=1).max())
               for o in wb.parts)
    if posed and move < wb.size * .0001:
        raise RuntimeError('Review pose did not deform vertices: ' + wb.rel)
    return {'image': path.name, 'bones': bones, 'posed_bones': selected, 'max_displacement': move}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--prefix', required=True)
    parser.add_argument('--repair-normals', action='store_true')
    parser.add_argument('files', nargs='+')
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
    if not re.fullmatch(r'[A-Za-z0-9_-]+', args.prefix):
        parser.error('prefix must be a simple filename')
    module = load_workbench()
    module.prepare()
    screenshots = module.WORK / 'screenshots'
    screenshots.mkdir(exist_ok=True)
    evidence_path = module.WORK / (args.prefix + '-evidence.json')
    evidence = {'prefix': args.prefix, 'blender': bpy.app.version_string,
                'render_method': 'Blender Workbench solid; actual pose bone projection', 'models': []}
    for index, relative in enumerate(args.files):
        source = module.ORIGINALS / relative
        if not source.resolve().is_relative_to(module.ORIGINALS.resolve()) or not source.is_file():
            raise ValueError('Not an original GLB: ' + relative)
        if args.repair_normals:
            spec = importlib.util.spec_from_file_location('repair_rig_normals', Path(__file__).with_name('repair_rig_normals.py'))
            repair_module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(repair_module)
            wb, report = repair_module.repair(module, relative)
        else:
            wb, report = module.build(relative)
        camera = setup_camera(wb)
        stem = '%s-%02d' % (args.prefix, index + 1)
        rest = render(wb, module, camera, screenshots / (stem + '-rest.png'), False)
        posed = render(wb, module, camera, screenshots / (stem + '-posed.png'), True)
        pose(wb, False)
        evidence['models'].append({'file': relative, 'bones': report['bones'],
                                   'blended_meshes': report['blended_meshes'],
                                   'sha256': hashlib.sha256((module.STAGED / relative).read_bytes()).hexdigest(),
                                   'rest': rest, 'posed': posed})
        evidence_path.write_text(json.dumps(evidence, indent=2) + '\n', encoding='utf8')
        print('RIG_BATCH_MODEL_OK', relative, flush=True)
    print('RIG_BATCH_OK', len(evidence['models']), str(evidence_path), flush=True)


if __name__ == '__main__':
    main()
