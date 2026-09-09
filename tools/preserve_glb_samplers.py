"""Restore source samplers and material extension values after Blender export.

Only JSON material/texture metadata is changed; geometry, skins and image bytes
remain byte-for-byte untouched. Ambiguous image/sampler or material mappings fail.
"""
import argparse
import copy
import hashlib
import json
import math
from pathlib import Path
import re
import struct


def read_glb(path):
    data = path.read_bytes()
    if data[:4] != b'glTF' or struct.unpack_from('<II', data, 4) != (2, len(data)):
        raise ValueError('Invalid GLB header: ' + str(path))
    chunks = []
    offset = 12
    while offset < len(data):
        length, kind = struct.unpack_from('<II', data, offset)
        payload = data[offset + 8:offset + 8 + length]
        if len(payload) != length:
            raise ValueError('Truncated GLB chunk')
        chunks.append((kind, payload))
        offset += 8 + length
    if chunks[0][0] != 0x4E4F534A:
        raise ValueError('Missing JSON chunk')
    return json.loads(chunks[0][1]), chunks


def image_hashes(doc, chunks):
    binary = next(payload for kind, payload in chunks if kind == 0x004E4942)
    result = []
    for image in doc.get('images', []):
        view = doc['bufferViews'][image['bufferView']]
        start = view.get('byteOffset', 0)
        result.append(hashlib.sha256(binary[start:start + view['byteLength']]).hexdigest())
    return result


def material_identity(doc, material, hashes):
    """Match effective core values and image content, never Blender/index names."""
    pbr = material.get('pbrMetallicRoughness', {})
    strength = material.get('extensions', {}).get('KHR_materials_emissive_strength', {}).get('emissiveStrength', 1)
    textures = {}
    for key, info in {**material, **pbr}.items():
        if not key.endswith('Texture'):
            continue
        texture = doc['textures'][info['index']]
        effective = {k: v for k, v in info.items() if k != 'index'}
        effective.setdefault('texCoord', 0)
        if key == 'normalTexture':
            effective.setdefault('scale', 1)
        if key == 'occlusionTexture':
            effective.setdefault('strength', 1)
        effective['imageSha256'] = hashes[texture['source']]
        textures[key] = effective
    return {
        'baseColor': pbr.get('baseColorFactor', [1, 1, 1, 1]),
        'metallic': pbr.get('metallicFactor', 1),
        'roughness': pbr.get('roughnessFactor', 1),
        'emission': [v * strength for v in material.get('emissiveFactor', [0, 0, 0])],
        'alphaMode': material.get('alphaMode', 'OPAQUE'),
        'alphaCutoff': material.get('alphaCutoff', 0.5),
        'doubleSided': material.get('doubleSided', False),
        'textures': textures,
    }


def equivalent(left, right):
    if isinstance(left, bool) or isinstance(right, bool):
        return type(left) is type(right) and left == right
    if isinstance(left, (int, float)) and isinstance(right, (int, float)):
        return math.isclose(left, right, rel_tol=1e-5, abs_tol=1e-5)
    if isinstance(left, dict) and isinstance(right, dict):
        return left.keys() == right.keys() and all(equivalent(v, right[k]) for k, v in left.items())
    if isinstance(left, list) and isinstance(right, list):
        return len(left) == len(right) and all(equivalent(a, b) for a, b in zip(left, right))
    return left == right


def extension_values(material):
    def without_textures(value):
        if isinstance(value, dict):
            return {k: without_textures(v) for k, v in value.items() if not k.endswith('Texture')}
        if isinstance(value, list):
            return [without_textures(v) for v in value]
        return value

    # Blender may fold strength into emissiveFactor. Restoring the source strength
    # alone would multiply emission twice; effective emission is matched above.
    return {k: without_textures(v) for k, v in material.get('extensions', {}).items()
            if k != 'KHR_materials_emissive_strength'}


def restore_material_extensions(original, exported, original_hashes, output_hashes):
    originals = [(i, material_identity(original, material, original_hashes), extension_values(material))
                 for i, material in enumerate(original.get('materials', []))]
    restored_extensions = set()

    def usages(doc):
        result = {}
        for node in doc.get('nodes', []):
            if 'mesh' not in node or not node.get('name'):
                continue
            name = re.sub(r'\.\d{3,}$', '', node['name'])
            for primitive in doc['meshes'][node['mesh']]['primitives']:
                if 'material' in primitive:
                    result.setdefault(name, set()).add(primitive['material'])
        return result

    original_uses, output_uses = usages(original), usages(exported)

    def merge(target, source):
        for key, value in source.items():
            if isinstance(value, dict):
                if key not in target:
                    target[key] = {}
                if not isinstance(target[key], dict):
                    raise ValueError('Incompatible exported extension property: ' + key)
                merge(target[key], value)
            else:
                target[key] = copy.deepcopy(value)

    for index, material in enumerate(exported.get('materials', [])):
        identity = material_identity(exported, material, output_hashes)
        matches = [(i, values) for i, signature, values in originals if equivalent(identity, signature)]
        if matches and any(not equivalent(matches[0][1], values) for _, values in matches[1:]):
            # Equal base PBR factors do not identify materials with different coats.
            # Every exported usage must agree with the original named mesh bindings.
            allowed = {i for i, _ in matches}
            for name, indices in output_uses.items():
                if index in indices and name in original_uses:
                    allowed.intersection_update(original_uses[name])
            matches = [(i, values) for i, values in matches if i in allowed]
        candidates = [values for _, values in matches]
        if not candidates or any(not equivalent(candidates[0], values) for values in candidates[1:]):
            raise ValueError('Cannot uniquely restore extension values for exported material ' + str(index))
        if candidates[0]:
            merge(material.setdefault('extensions', {}), candidates[0])
            restored_extensions.update(candidates[0])
    if restored_extensions:
        exported['extensionsUsed'] = sorted(set(exported.get('extensionsUsed', [])) | restored_extensions)


def preserve(source, target):
    original, _source_chunks = read_glb(Path(source))
    exported, chunks = read_glb(Path(target))
    original_hashes = image_hashes(original, _source_chunks)
    output_hashes = image_hashes(exported, chunks)
    choices = {}
    for texture in original.get('textures', []):
        digest = original_hashes[texture['source']]
        sampler = original.get('samplers', [])[texture['sampler']] if 'sampler' in texture else {}
        choices.setdefault(digest, set()).add(json.dumps(sampler, sort_keys=True))
    restored = []
    updates = []
    for texture in exported.get('textures', []):
        options = choices.get(output_hashes[texture['source']], set())
        if len(options) != 1:
            raise ValueError('Cannot uniquely restore the sampler for ' + str(target))
        sampler = json.loads(next(iter(options)))
        if sampler not in restored:
            restored.append(sampler)
        updates.append(restored.index(sampler))
    for texture, index in zip(exported.get('textures', []), updates):
        texture['sampler'] = index
    if updates:
        exported['samplers'] = restored
    restore_material_extensions(original, exported, original_hashes, output_hashes)
    encoded = json.dumps(exported, separators=(',', ':'), ensure_ascii=False).encode('utf8')
    encoded += b' ' * (-len(encoded) % 4)
    output_chunks = [(0x4E4F534A, encoded)] + chunks[1:]
    payload = b''.join(struct.pack('<II', len(block), kind) + block for kind, block in output_chunks)
    result = b'glTF' + struct.pack('<II', 2, 12 + len(payload)) + payload
    # Complete validation above precedes the single destination write.
    Path(target).write_bytes(result)
    return True


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    count = 0
    for target in sorted(args.output.rglob('*.glb')):
        source = args.source / target.relative_to(args.output)
        if preserve(source, target):
            count += 1
    print('GLB_SAMPLERS_RESTORED', count)
