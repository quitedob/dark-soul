"""Preserve glTF normals through Blender's lossy custom-normal representation.

Blender 5.2's custom corner normals can drift near degenerate capsule/cone poles.
Keep the importer's decoded POINT normals in the editable mesh and use those for
static skinned exports. Patches are scoped to one synchronous import/export and
always restored; the installed glTF addon is never edited.
"""
from contextlib import contextmanager

import numpy as np


ATTRIBUTE = '_rig_source_normal'


@contextmanager
def capture_import():
    from io_scene_gltf2.blender.imp import mesh as importer
    original = importer.set_poly_smoothing

    def capture(gltf, pymesh, mesh, normals, indices):
        original(gltf, pymesh, mesh, normals, indices)
        if len(normals) == len(mesh.vertices):
            attribute = mesh.attributes.new(ATTRIBUTE, 'FLOAT_VECTOR', 'POINT')
            attribute.data.foreach_set('vector', np.asarray(normals, dtype=np.float32).reshape(-1))

    importer.set_poly_smoothing = capture
    try:
        yield
    finally:
        importer.set_poly_smoothing = original


@contextmanager
def exact_export():
    from io_scene_gltf2.blender.exp.primitive_extract import PrimitiveCreator
    method = '_PrimitiveCreator__get_normals'
    original = getattr(PrimitiveCreator, method)

    def get_normals(creator):
        original(creator)
        attribute = creator.blender_mesh.attributes.get(ATTRIBUTE)
        if attribute is None:
            raise RuntimeError('Exact source normals missing: ' + creator.blender_mesh.name)
        if creator.key_blocks:
            raise RuntimeError('Exact source normal export does not support morph targets')
        values = np.empty(len(attribute.data) * 3, dtype=np.float32)
        attribute.data.foreach_get('vector', values)
        indices = np.empty(len(creator.blender_mesh.loops), dtype=np.int32)
        creator.blender_mesh.loops.foreach_get('vertex_index', indices)
        normals = values.reshape(-1, 3)[indices].copy()
        if creator.armature and creator.blender_object:
            matrix = creator.armature.matrix_world.inverted_safe() @ creator.blender_object.matrix_world
            normal_matrix = creator.armature.matrix_world.to_3x3() @ matrix.to_3x3().inverted_safe().transposed()
            normals[:] = PrimitiveCreator.apply_mat_to_all(normal_matrix, normals)
        PrimitiveCreator.normalize_vecs(normals)
        if creator.export_settings['gltf_yup']:
            PrimitiveCreator.zup2yup(normals)
        creator.normals = normals

    setattr(PrimitiveCreator, method, get_normals)
    try:
        yield
    finally:
        setattr(PrimitiveCreator, method, original)
