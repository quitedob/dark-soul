"""Restore source normals in saved Blender rigs without rebuilding their skeletons."""
import hashlib
import json
from pathlib import Path
import shutil

import bpy
import numpy as np


def rig_fingerprint(arm, meshes):
    bones = [(b.name, b.parent.name if b.parent else None,
              [list(row) for row in b.matrix_local], list(b.head_local), list(b.tail_local))
             for b in arm.data.bones]
    weights = [(o.name, [g.name for g in o.vertex_groups],
                [[(g.group, g.weight) for g in v.groups] for v in o.data.vertices]) for o in meshes]
    return hashlib.sha256(json.dumps([bones, weights], separators=(',', ':')).encode()).hexdigest()


def repair(module, relative):
    blend = module.BLENDS / Path(relative).with_suffix('.blend')
    report_path = module.REPORTS / (relative.replace('/', '__') + '.json')
    old_report = json.loads(report_path.read_text(encoding='utf8'))
    wb = module.Workbench(relative)
    with bpy.data.libraries.load(str(blend), link=False) as (source, target):
        if len(source.scenes) != 1:
            raise RuntimeError('Expected one saved rig scene: ' + relative)
        target.scenes = source.scenes
    scene = target.scenes[0]
    bpy.context.window.scene = scene
    bpy.context.view_layer.update()
    meshes = [o for o in scene.objects if o.type == 'MESH']
    arms = [o for o in scene.objects if o.type == 'ARMATURE']
    if len(arms) != 1 or len(meshes) != len(wb.parts):
        raise RuntimeError('Saved rig inventory mismatch: ' + relative)
    arm = arms[0]
    before = rig_fingerprint(arm, meshes)
    pairs = {}
    for obj in meshes:
        points = module.world_points(obj)
        candidates = [o for o in wb.parts if module.norm(o.name) == module.norm(obj.name)
                      and len(wb.points[o]) == len(points)
                      and np.max(np.abs(wb.points[o] - points)) < wb.size * 1e-5]
        if len(candidates) != 1:
            raise RuntimeError('Ambiguous source vertex correspondence: ' + relative + '/' + obj.name)
        original = candidates[0]
        old_indices = [l.vertex_index for l in obj.data.loops]
        if old_indices != [l.vertex_index for l in original.data.loops]:
            raise RuntimeError('Saved rig corner order changed: ' + obj.name)
        attribute = original.data.attributes[module._normals_tools.ATTRIBUTE]
        values = np.empty(len(attribute.data) * 3, dtype=np.float32)
        attribute.data.foreach_get('vector', values)
        transform = obj.matrix_world.to_3x3().transposed() @ original.matrix_world.to_3x3().inverted().transposed()
        values = values.reshape(-1, 3) @ np.asarray(transform).T
        attribute = obj.data.attributes.get(module._normals_tools.ATTRIBUTE)
        if attribute is None:
            attribute = obj.data.attributes.new(module._normals_tools.ATTRIBUTE, 'FLOAT_VECTOR', 'POINT')
        attribute.data.foreach_set('vector', np.asarray(values, dtype=np.float32).reshape(-1))
        pairs[obj] = original
    after = rig_fingerprint(arm, meshes)
    if after != before:
        raise RuntimeError('Normal repair changed bones or weights: ' + relative)
    wb.scene, wb.arm, wb.parts = scene, arm, meshes
    wb.objects = list(scene.objects)
    wb.points = {o: wb.points[pairs[o]] for o in meshes}
    wb.center = {o: (p.min(0) + p.max(0)) / 2 for o, p in wb.points.items()}
    wb.bones = {name: {k: v if k == 'parent' else np.array(v) for k, v in bone.items()}
                for name, bone in old_report['bone_rest'].items()}
    wb.assignment, wb.blends = {}, {}
    for obj in meshes:
        mass = {g.index: 0. for g in obj.vertex_groups}
        for vertex in obj.data.vertices:
            positive = [g for g in vertex.groups if g.weight > 0]
            if len(positive) > 1:
                wb.blends[obj] = None
            for g in positive:
                mass[g.group] += g.weight
        wb.assignment[obj] = obj.vertex_groups[max(mass, key=mass.get)].name
    wb.rest_error = max(float(np.max(np.linalg.norm(module.world_points(o, True) - wb.points[o], axis=1))) for o in meshes)
    if wb.rest_error > wb.size * 1e-5:
        raise RuntimeError('Saved rig is not in the source rest pose: ' + relative)
    for bone in arm.pose.bones:
        bone.rotation_mode = 'XYZ'
        bone.rotation_euler.x = .1 if bone.name != 'root' else 0
    bpy.context.view_layer.update()
    wb.pose_move = max(float(np.max(np.linalg.norm(module.world_points(o, True) - wb.points[o], axis=1))) for o in meshes)
    for bone in arm.pose.bones:
        bone.rotation_euler = (0, 0, 0)
    bpy.context.view_layer.update()
    if wb.pose_move < wb.size * .0001:
        raise RuntimeError('Saved rig does not deform: ' + relative)
    for path in (blend, report_path, module.STAGED / relative):
        backup = module.WORK / 'pre-normal-repair-20260908' / path.relative_to(module.WORK)
        if not backup.exists():
            backup.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, backup)
    report = wb.export()
    report.update(normal_only_repair=True, rig_fingerprint_before=before, rig_fingerprint_after=after)
    report_path.write_text(json.dumps(report, indent=2) + '\n', encoding='utf8')
    bpy.data.libraries.write(str(blend), {scene}, fake_user=True, compress=True)
    return wb, report
