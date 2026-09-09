"""Focused preservation contracts; no model files are changed."""
import copy
import unittest

from preserve_glb_samplers import restore_material_extensions


class MaterialPreservationContracts(unittest.TestCase):
    def test_identical_base_materials_disambiguated_by_mesh_usage(self):
        base = {'pbrMetallicRoughness': {'metallicFactor': .9, 'roughnessFactor': .3}}
        coated = {**copy.deepcopy(base), 'extensions': {'KHR_materials_clearcoat': {'clearcoatFactor': .5}}}
        source = {'materials': [coated, base], 'nodes': [{'name': 'blade', 'mesh': 0}, {'name': 'tip', 'mesh': 1}],
                  'meshes': [{'primitives': [{'material': 0}]}, {'primitives': [{'material': 1}]}]}
        output = {'materials': [copy.deepcopy(base), copy.deepcopy(base)],
                  'nodes': [{'name': 'tip.001', 'mesh': 0}, {'name': 'blade.002', 'mesh': 1}],
                  'meshes': [{'primitives': [{'material': 0}]}, {'primitives': [{'material': 1}]}]}
        restore_material_extensions(source, output, [], [])
        self.assertNotIn('extensions', output['materials'][0])
        self.assertEqual(output['materials'][1]['extensions'], coated['extensions'])

    def test_ambiguous_bindings_still_fail(self):
        source = {'materials': [{}, {'extensions': {'KHR_materials_clearcoat': {'clearcoatFactor': .5}}}]}
        with self.assertRaisesRegex(ValueError, 'Cannot uniquely restore'):
            restore_material_extensions(source, {'materials': [{}]}, [], [])

    def test_texture_free_materials(self):
        output = {'materials': [{}]}
        restore_material_extensions({'materials': [{}]}, output, [], [])
        self.assertEqual(output, {'materials': [{}]})


if __name__ == '__main__':
    unittest.main()
