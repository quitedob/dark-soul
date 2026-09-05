"""Blender MCP workbench: real armatures + vertex skinning for the GLB library.

Load using importlib in Blender, then call prepare(), build(relative_path).
Staged exports and original backups are separate; publication is an explicit step.
All coordinates/weights are derived from imported geometry and named ancestry.
"""
from pathlib import Path
import contextlib
import io
import json
import re
import shutil
from collections import defaultdict

import bpy
import numpy as np
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / 'build/glb-models'
WORK = BASE / 'rigging'
ORIGINALS = WORK / 'originals'
STAGED = WORK / 'staged'
REPORTS = WORK / 'reports'
BLENDS = WORK / 'blend'
STATE = {'built': [], 'pages': []}


def prepare():
    paths = sorted((BASE / 'out').rglob('*.glb'))
    extra = ROOT / 'game/assets/models/weapons/templateweapons.glb'
    entries = [(p.relative_to(BASE / 'out').as_posix(), p) for p in paths]
    if not any(r == 'weapons/templateweapons.glb' for r, _ in entries):
        entries.append(('weapons/templateweapons.glb', extra))
    for rel, source in entries:
        dest = ORIGINALS / rel
        if not dest.exists():
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, dest)
    for p in (STAGED, REPORTS, BLENDS):
        p.mkdir(parents=True, exist_ok=True)
    return [r for r, _ in entries]


def norm(name):
    name = re.sub(r'\.\d{3}$', '', name)
    name = re.sub(r'([a-z])([A-Z])', r'\1_\2', name)
    return name.lower().replace('-', '_')


def ancestors(obj):
    result = [obj]
    while result[-1].parent is not None:
        result.append(result[-1].parent)
    return result


def has(name, pattern):
    return re.search(pattern, name) is not None


def world_points(obj, evaluated=False):
    source = obj.evaluated_get(bpy.context.evaluated_depsgraph_get()) if evaluated else obj
    mesh = source.to_mesh() if evaluated else source.data
    values = np.empty(len(mesh.vertices) * 3, dtype=np.float64)
    mesh.vertices.foreach_get('co', values)
    points = values.reshape(-1, 3)
    mat = np.asarray(source.matrix_world, dtype=float)
    points = points @ mat[:3, :3].T + mat[:3, 3]
    if evaluated:
        source.to_mesh_clear()
    return points


class Workbench:
    def __init__(self, rel):
        self.rel = rel
        self.scene = bpy.data.scenes.new(Path(rel).stem)
        bpy.context.window.scene = self.scene
        with contextlib.redirect_stdout(io.StringIO()):
            bpy.ops.import_scene.gltf(filepath=str(ORIGINALS / rel))
        bpy.context.view_layer.update()
        self.objects = list(self.scene.objects)
        if any(o.type == 'ARMATURE' for o in self.objects):
            raise RuntimeError('Source already has an armature: ' + rel)
        self.parts = [o for o in self.objects if o.type == 'MESH']
        self.points = {o: world_points(o) for o in self.parts}
        self.center = {o: (p.min(0) + p.max(0)) / 2 for o, p in self.points.items()}
        all_points = np.concatenate(list(self.points.values()))
        self.low, self.high = all_points.min(0), all_points.max(0)
        self.size = max(float(np.max(self.high - self.low)), 0.01)
        self.names = {o: norm(o.name) for o in self.objects}
        self.chains = {o: ancestors(o) for o in self.objects}
        self.bones = {}
        self.assignment = {}
        self.blends = {}
        self.family = ('quadruped' if any(x in rel for x in ('NineTails.glb', 'War-Dog', 'Maze-Guardian'))
                       else 'insect' if 'Illusion-Butterfly' in rel
                       else 'bird' if any(x in rel for x in ('Cloud-Sky-Eagle', 'Ember-Bat'))
                       else 'mechanism' if any(x in rel for x in ('Blind-Bell', 'Torture-Device', 'Foxfire-Lantern', 'Elixir-Furnace', 'Book-Spirit', 'RebirthLotus'))
                       else 'prop' if rel.startswith(('props/', 'weapons/', 'equipment/'))
                       else 'humanoid')
        self.side_sign = -1
        samples = [self.center[o][0] for o in self.parts if has(self.names[o], r'(?:^l_|_l$)')]
        if samples and np.mean(samples) > 0:
            self.side_sign = 1

    def add(self, name, parent, head, tail=None):
        head = np.asarray(head, dtype=float)
        if tail is None or np.linalg.norm(np.asarray(tail) - head) < self.size * 0.005:
            tail = head + np.array([0, 0, self.size * .045])
        self.bones[name] = {'parent': parent, 'head': head, 'tail': np.asarray(tail, dtype=float)}
        return name

    def side(self, obj):
        for item in self.chains[obj]:
            n = self.names[item]
            if has(n, r'^(?:l_|left_)|_(?:l|left)(?:_|$)|(?:arm|leg)l[uf]$'):
                return 'L'
            if has(n, r'^(?:r_|right_)|_(?:r|right)(?:_|$)|(?:arm|leg)r[uf]$'):
                return 'R'
        p = self.center.get(obj, np.asarray(obj.matrix_world.translation))
        return 'L' if p[0] * self.side_sign > 0 else 'R'

    def label(self, obj):
        """Specific anatomy first; whole ancestor groups inherit before decoration."""
        chain = self.chains[obj]
        combined = ' '.join(self.names[o] for o in chain)
        n = self.names[obj]
        s = self.side(obj)
        if self.family == 'insect' and n in ('leg', 'wing'):
            similar = [o for o in self.parts if self.names[o] == n and self.side(o) == s]
            return ('wing.' if n == 'wing' else 'thigh.') + s + '.%02d' % (similar.index(obj) + 1)
        if self.family == 'quadruped':
            quad = re.search(r'(?:leg|paw|claw|joint_cap)_?(fl|fr|hl|hr|bl|br)', combined)
            alt = re.search(r'(front|hind)_?([lr])', combined)
            if quad or alt:
                q = quad.group(1) if quad else ('f' if alt.group(1) == 'front' else 'h') + alt.group(2)
                q = q.replace('b', 'h')
                suffix = ('front' if q[0] == 'f' else 'hind') + '.' + q[1].upper()
                part = 'foot' if has(n, r'paw|claw|flame') else 'shin' if has(n, r'leg_?[fhb][lr]_l|(?:front|hind)_?[lr]f|joint_cap') else 'thigh'
                return part + '.' + suffix
        # An entire wing subtree, including generic arm/vein/membrane/feathers.
        if has(combined, r'wing') and 'GoldenArmoredGuardian' not in self.rel and 'Furnace-Keeper' not in self.rel:
            return 'wing.' + s
        # Whole hand/weapon ancestry overrides a child called arrow_head etc.
        for ancestor in chain[1:-1]:
            a = self.names[ancestor]
            if has(a, r'quiver|hunter_knife'):
                return 'hips'
            if has(a, r'^(?:hand|fist)(?:_|$)'):
                return 'hand.' + s
            if has(a, r'head|helmet|crown|hair|hood'):
                return 'head'
        if has(n, r'skull_trophy|skull_cord|quiver|hip_|belt|waist|pelvis|tasset'):
            return 'hips'
        if has(n, r'axe|sword|blade|weapon|grip|pommel|haft|shaft|spear|shield|mace|hammer|staff|sceptre|fan_|(?:^|_)bow|arrow|knife|tome|scroll|whisk'):
            return 'held.' + s
        if has(n, r'foot|boot|ankle|toe|paw'):
            return 'foot.' + s
        if has(n, r'shin|calf|greave|knee|leg_lower|leg_[lr]f|leg[lr]f'):
            return 'shin.' + s
        if has(n, r'thigh|leg|haunch'):
            return 'thigh.' + s
        if has(n, r'hand|fist|palm|claw|wrist'):
            return 'hand.' + s
        if has(n, r'forearm|fore_arm|vambrace|elbow|bracer|arm_lower|arm_[lr]f|arm[lr]f'):
            return 'forearm.' + s
        if has(n, r'upperarm|upper_arm|shoulder|pauldron|(?:^|_)arm|sleeve'):
            return 'upper_arm.' + s
        if 'Blood-General' in self.rel and has(n, r'eye|mouth|tooth|tattoo|face'):
            return 'chest'
        if has(n, r'head|mask|face|skull|muzzle|helm|snout|nose|(?:^|_)eye|(?:^|_)ear|whisker|hair|bun|crown|hood|beard|fang|forehead|urna'):
            return 'head'
        if has(n, r'neck|throat|collar'):
            return 'neck'
        if has(n, r'chest|breast|torso|body|belly|rib|harness|strap_rivet'):
            return 'chest'
        for ancestor in chain[1:-1]:
            a = self.names[ancestor]
            if has(a, r'arm|sleeve|elbow|hand'):
                return ('forearm.' if 'elbow' in a else 'upper_arm.') + s
            if has(a, r'waist|hip|belt'):
                return 'hips'
        return None

    def endpoint(self, obj, near):
        """Use the mesh major axis, avoiding diagonal AABB corners on bent arms."""
        pts = self.points[obj]
        center = pts.mean(0)
        _, _, vh = np.linalg.svd(pts - center, full_matrices=False)
        axis = vh[0]
        projected = (pts - center) @ axis
        a, b = center + axis * projected.min(), center + axis * projected.max()
        return (a, b) if np.linalg.norm(a - near) < np.linalg.norm(b - near) else (b, a)

    def anchor(self, candidates, fallback):
        matches = [o for o in self.parts if any(re.fullmatch(p, self.names[o]) for p in candidates)]
        return np.mean([self.center[o] for o in matches], axis=0) if matches else np.asarray(fallback)

    def anatomy(self):
        mid = (self.low + self.high) / 2
        bottom = np.array([mid[0], mid[1], self.low[2]])
        self.add('root', '', bottom)
        hips = self.anchor([r'pelvis', r'hips', r'waist', r'belt', r'rump'], mid)
        chest = self.anchor([r'torso', r'body', r'chest', r'body_bulk', r'thorax'], mid)
        self.add('hips', 'root', hips, chest)
        self.add('spine', 'hips', hips + (chest - hips) * .4, chest)
        self.bones['root']['head'][:2] = hips[:2]
        self.bones['root']['tail'][:2] = hips[:2]
        self.bones['hips']['tail'] = self.bones['spine']['head'].copy()
        self.add('chest', 'spine', chest)
        labels = {o: self.label(o) for o in self.parts}
        headparts = [o for o, label in labels.items() if label == 'head']
        if headparts and 'Blood-General' not in self.rel:
            head = self.anchor([r'head', r'skull', r'head_mask', r'face', r'hood'], np.mean([self.center[o] for o in headparts], 0))
            neck = self.anchor([r'neck'], chest + (head - chest) * .7)
            self.add('neck', 'chest', neck, head)
            self.add('head', 'neck', head, head + np.array([0, 0, self.size * .09]))
            self.bones['chest']['tail'] = neck.copy()
        grouped = defaultdict(list)
        for obj, label in labels.items():
            if label:
                grouped[label].append(obj)
        ordered = sorted([b for b in grouped if '.' in b and not b.startswith('held.')],
                         key=lambda b: (['upper_arm', 'forearm', 'hand', 'thigh', 'shin', 'foot', 'wing'].index(b.split('.')[0]), b))
        for label in ordered:
            segment, suffix = label.split('.', 1)
            parent = {'upper_arm': 'chest', 'forearm': 'upper_arm.' + suffix, 'hand': 'forearm.' + suffix,
                      'thigh': 'hips', 'shin': 'thigh.' + suffix, 'foot': 'shin.' + suffix, 'wing': 'chest'}[segment]
            if parent not in self.bones:
                parent = 'chest' if segment in ('hand', 'forearm', 'wing') else 'hips'
            # Prefer the actual limb, not a large pauldron or weapon decoration.
            def quality(o):
                n = self.names[o]
                core = has(n, r'^(upper_arm|upperarm|forearm|arm|thigh|shin|leg|front|hind|hand|fist|foot|boot|paw|wing)(?:_|[lrfhub]|$)')
                return (core, -len(n), len(self.points[o]))
            primary = max(grouped[label], key=quality)
            near = self.bones[parent]['head']
            start, end = self.endpoint(primary, near)
            # Authored empties are exact shoulder/elbow/hand pivot landmarks.
            landmarks = [o for o in self.objects if o.type == 'EMPTY' and self.side(o) == suffix and
                         ((segment == 'upper_arm' and has(self.names[o], r'^(?:[lr]_)?arm$')) or
                          (segment == 'forearm' and self.names[o] == 'elbow') or
                          (segment == 'hand' and self.names[o] == 'hand'))]
            if landmarks:
                start = np.asarray(landmarks[0].matrix_world.translation)
            self.add(label, parent, start, end)
            if segment in ('forearm', 'hand', 'shin') and parent in self.bones:
                self.bones[parent]['tail'] = np.asarray(start)
        for obj, label in labels.items():
            if label and label.startswith('held.'):
                hands = [b for b in self.bones if b.startswith('hand.')]
                label = min(hands, key=lambda b: np.linalg.norm(self.center[obj] - self.bones[b]['head'])) if hands else 'chest'
            if label not in self.bones:
                # Fine trim follows the closest anatomical part; effects stay on root.
                n = self.names[obj]
                if has(n, r'ground|pool|ripple|dust|spark|mote|aura|glow_ring|hover|lift_|afterimage|wisp'):
                    label = 'root'
                else:
                    anchors = [p for p in self.parts if labels[p] in self.bones]
                    nearest = min(anchors, key=lambda p: np.linalg.norm(self.center[p] - self.center[obj])) if anchors else None
                    label = labels[nearest] if nearest else 'chest'
            self.assignment[obj] = label
        self.soft_parts()

    def soft_parts(self):
        # Independent tails retain the original numbered ancestor; never merge nine tails.
        tailsets = defaultdict(list)
        for obj in self.parts:
            names = [self.names[o] for o in self.chains[obj]]
            root = next((n for n in names if re.fullmatch(r'tail_root_\d+', n)), None)
            n = names[0]
            if root:
                tailsets[root].append(obj)
            elif re.fullmatch(r'tail\d*', n) and self.family in ('quadruped', 'humanoid'):
                tailsets[n].append(obj)
        for name, parts in tailsets.items():
            self.chain(name.replace('tail_root_', 'tail.'), parts, 'hips', 3)
        # Robes/capes and elongated single-piece limbs receive real blended weights.
        for obj in self.parts:
            n = self.names[obj]
            if has(n, r'^(?:robe|skirt|cape|cloak|streamer|sash_tail|hair_strand)') and not has(n, r'ring|trim|brooch|plate|buckle'):
                parent = 'head' if n.startswith('hair') and 'head' in self.bones else 'chest' if has(n, r'^cape|^cloak') else 'hips'
                self.chain('cloth.' + re.sub(r'[^a-z0-9_]', '_', obj.name.lower()), [obj], parent, 2, vertical=True)
            elif n in ('torso', 'body') and self.family == 'humanoid':
                zs = self.points[obj][:, 2]
                lo, hi = float(zs.min()), float(zs.max())
                self.blends[obj] = ('vertical', ['spine', 'chest'], lo, hi)

    def chain(self, name, parts, parent, count, vertical=False):
        pts = np.concatenate([self.points[o] for o in parts])
        near = self.bones[parent]['head']
        center = pts.mean(0)
        _, _, vh = np.linalg.svd(pts - center, full_matrices=False)
        axis = vh[0]
        projected = (pts - center) @ axis
        a, b = center + axis * projected.min(), center + axis * projected.max()
        if np.linalg.norm(b - near) < np.linalg.norm(a - near):
            a, b = b, a
        if vertical:
            a, b = center.copy(), center.copy()
            a[2], b[2] = pts[:, 2].max(), pts[:, 2].min()
        bone_names = []
        for i in range(count):
            bn = name + '.%02d' % (i + 1)
            self.add(bn, parent, a + (b - a) * i / count, a + (b - a) * (i + 1) / count)
            bone_names.append(bn)
            parent = bn
        for obj in parts:
            self.assignment[obj] = bone_names[0]
            self.blends[obj] = ('chain', bone_names, a, b)

    def props(self):
        mid = (self.low + self.high) / 2
        self.add('root', '', [mid[0], mid[1], self.low[2]])
        self.add('body', 'root', mid)
        # Preserve separately modelled asset groups and mechanical pivots.
        group_bones = {}
        for obj in self.parts:
            chain = self.chains[obj]
            group = chain[-2] if len(chain) > 2 else obj
            if group not in group_bones:
                name = 'part.' + re.sub(r'[^A-Za-z0-9_.-]', '_', group.name)
                head = np.asarray(group.matrix_world.translation) if group.type == 'EMPTY' else self.center[obj]
                self.add(name, 'body', head)
                group_bones[group] = name
            self.assignment[obj] = group_bones[group]

    def bind(self):
        if self.family in ('prop', 'mechanism'):
            self.props()
        else:
            self.anatomy()
        armdata = bpy.data.armatures.new('Skeleton')
        arm = bpy.data.objects.new('Skeleton', armdata)
        self.scene.collection.objects.link(arm)
        bpy.ops.object.select_all(action='DESELECT')
        arm.select_set(True)
        bpy.context.view_layer.objects.active = arm
        bpy.ops.object.mode_set(mode='EDIT')
        for name, spec in self.bones.items():
            bone = armdata.edit_bones.new(name)
            bone.head = spec['head']
            bone.tail = spec['tail']
            if spec['parent']:
                bone.parent = armdata.edit_bones[spec['parent']]
        bpy.ops.object.mode_set(mode='OBJECT')
        arm.show_in_front = True
        armdata.display_type = 'OCTAHEDRAL'
        for obj in self.parts:
            transform = obj.matrix_world.copy()
            obj.parent = arm
            obj.matrix_world = transform
            # Mesh datablocks may be instanced; vertex groups are object-local.
            obj.data = obj.data.copy()
            modifier = obj.modifiers.new('Skin', 'ARMATURE')
            modifier.object = arm
            if obj not in self.blends:
                vg = obj.vertex_groups.new(name=self.assignment[obj])
                vg.add(list(range(len(obj.data.vertices))), 1.0, 'REPLACE')
            else:
                mode, names, a, b = self.blends[obj]
                if mode == 'vertical':
                    t = np.clip((self.points[obj][:, 2] - a) / max(b - a, 1e-8), 0, 1)
                else:
                    axis = b - a
                    t = np.clip((self.points[obj] - a) @ axis / max(float(axis @ axis), 1e-8), 0, 1)
                t *= len(names) - 1
                weights = {name: obj.vertex_groups.new(name=name) for name in names}
                for vi, value in enumerate(t):
                    lower = min(int(value), len(names) - 1)
                    upper = min(lower + 1, len(names) - 1)
                    fraction = float(value - lower)
                    weights[names[lower]].add([vi], 1 - fraction, 'REPLACE')
                    if upper != lower and fraction > 1e-7:
                        weights[names[upper]].add([vi], fraction, 'REPLACE')
        bpy.context.view_layer.update()
        self.arm = arm
        self.rest_error = max(float(np.max(np.linalg.norm(world_points(o, True) - self.points[o], axis=1))) for o in self.parts)
        if self.rest_error > self.size * 1e-5:
            raise RuntimeError('Bind pose changed: %g' % self.rest_error)
        # Pose all weighted branches, with root unchanged, to prove vertex deformation.
        for bone in arm.pose.bones:
            if bone.name != 'root':
                bone.rotation_mode = 'XYZ'
                bone.rotation_euler.x = .10
        bpy.context.view_layer.update()
        self.pose_move = max(float(np.max(np.linalg.norm(world_points(o, True) - self.points[o], axis=1))) for o in self.parts)
        for bone in arm.pose.bones:
            bone.rotation_euler = (0, 0, 0)
        bpy.context.view_layer.update()
        if self.pose_move < self.size * .0001:
            raise RuntimeError('No actual skinned vertex movement')

    def export(self):
        dest = STAGED / self.rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        with contextlib.redirect_stdout(io.StringIO()):
            bpy.ops.export_scene.gltf(filepath=str(dest), export_format='GLB', use_active_scene=True,
                                      export_skins=True, export_animations=False, export_extras=True,
                                      export_yup=True, export_image_format='AUTO', export_materials='EXPORT')
        report = {'file': self.rel, 'family': self.family, 'bones': len(self.bones), 'meshes': len(self.parts),
                  'blended_meshes': len(self.blends), 'vertices': sum(len(o.data.vertices) for o in self.parts),
                  'bind_error': self.rest_error, 'pose_displacement': self.pose_move,
                  'bone_names': list(self.bones),
                  'bone_rest': {name: {key: value if key == 'parent' else value.tolist() for key, value in spec.items()} for name, spec in self.bones.items()},
                  'assignments': {o.name: self.assignment[o] for o in self.parts}}
        rp = REPORTS / (self.rel.replace('/', '__') + '.json')
        rp.write_text(json.dumps(report, indent=2), encoding='utf8')
        return report


def build(rel):
    wb = Workbench(rel)
    wb.bind()
    report = wb.export()
    blend_path = BLENDS / Path(rel).with_suffix('.blend')
    blend_path.parent.mkdir(parents=True, exist_ok=True)
    bpy.data.libraries.write(str(blend_path), {wb.scene}, fake_user=True, compress=True)
    STATE['built'].append(wb)
    # Keep scenes in Blender for MCP screenshot review. No original scene is removed.
    return wb, report


def batch(paths, columns=3):
    built = []
    reports = []
    for rel in paths:
        wb, report = build(rel)
        built.append(wb)
        reports.append({k: report[k] for k in ('file', 'family', 'bones', 'meshes', 'blended_meshes', 'bind_error', 'pose_displacement')})
    show_grid(built, columns)
    STATE['current'] = built
    return reports


def show_grid(workbenches, columns=3, pose=False):
    """MCP screenshot layout; only preview transforms change, staged exports do not."""
    scene = bpy.data.scenes.new('Skeleton_Review')
    STATE['pages'].append(scene)
    bpy.context.window.scene = scene
    scene.world = bpy.data.worlds.new('ReviewWorld')
    for i, wb in enumerate(workbenches):
        container = bpy.data.objects.new('Review_' + Path(wb.rel).stem, None)
        scene.collection.objects.link(container)
        for obj in list(wb.scene.objects):
            scene.collection.objects.link(obj)
        for obj in list(wb.scene.objects):
            if obj.parent is None:
                obj.parent = container
        container.scale = (2.5 / wb.size,) * 3
        container.location = ((i % columns) * 3.2, 0, -(i // columns) * 3.2)
        # Center the model in its preview cell.
        center = (wb.low + wb.high) / 2
        container.location -= Vector(center * (2.5 / wb.size))
        textdata = bpy.data.curves.new('Label', 'FONT')
        textdata.body = '%d. %s' % (i + 1, Path(wb.rel).stem)
        textdata.size = .12
        textobj = bpy.data.objects.new('Label', textdata)
        scene.collection.objects.link(textobj)
        textobj.location = ((i % columns) * 3.2 - 1.35, -.6, -(i // columns) * 3.2 - 1.55)
        textobj.rotation_euler = (1.5707963, 0, 0)
        if pose:
            for bone in wb.arm.pose.bones:
                if bone.name.startswith(('forearm.', 'wing.', 'tail.')):
                    bone.rotation_euler.x = .25
        for obj in wb.parts:
            for mat in obj.data.materials:
                if mat and mat.use_nodes:
                    shader = next((n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'), None)
                    if shader:
                        mat.diffuse_color = shader.inputs['Base Color'].default_value
    bpy.ops.object.select_all(action='DESELECT')
    for wb in workbenches:
        wb.arm.select_set(True)
    bpy.context.view_layer.objects.active = workbenches[0].arm
    bpy.context.view_layer.update()
    for area in bpy.context.screen.areas:
        if area.type == 'VIEW_3D':
            space = area.spaces.active
            space.shading.type = 'MATERIAL'
            space.shading.type = 'SOLID'
            space.shading.color_type = 'MATERIAL'
            space.shading.light = 'STUDIO'
            space.overlay.show_floor = False
            space.overlay.show_axis_x = False
            space.overlay.show_axis_y = False
            space.overlay.show_relationship_lines = False
            space.overlay.show_extras = False
            space.shading.show_cavity = True
            space.region_3d.view_rotation = (0.70710678, 0.70710678, 0, 0)
            space.region_3d.view_perspective = 'ORTHO'
            space.region_3d.view_location = ((columns - 1) * 1.6, 0, -((len(workbenches) - 1) // columns) * 1.6)
            space.region_3d.view_distance = max(columns * 3.7, ((len(workbenches) + columns - 1) // columns) * 4.5)
    return scene
