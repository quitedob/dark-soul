// Deliberately independent of GLTFExporter/GLTFLoader. Only embedded GLB geometry.
import fs from 'node:fs';
import assert from 'node:assert/strict';

export function readGlb(path) {
  const bytes = fs.readFileSync(path);
  assert.equal(bytes.readUInt32LE(0), 0x46546c67, 'GLB magic');
  assert.equal(bytes.readUInt32LE(4), 2, 'GLB version');
  assert.equal(bytes.readUInt32LE(8), bytes.length, 'GLB length');
  let json, bin;
  for (let at = 12; at < bytes.length;) {
    const size = bytes.readUInt32LE(at), type = bytes.readUInt32LE(at + 4);
    assert.equal(size % 4, 0, 'chunk alignment');
    assert.ok(at + 8 + size <= bytes.length, 'chunk range');
    const chunk = bytes.subarray(at + 8, at + 8 + size);
    if (type === 0x4e4f534a) json = JSON.parse(chunk.toString('utf8'));
    if (type === 0x004e4942) bin = chunk;
    at += 8 + size;
  }
  assert.ok(json && bin, 'JSON and binary chunks');
  assert.equal(json.asset.version, '2.0');
  for (const item of [...(json.buffers ?? []), ...(json.images ?? [])])
    assert.ok(!item.uri, 'No external or data URI dependencies');
  assert.equal(json.buffers.length, 1);
  assert.ok(bin.length >= json.buffers[0].byteLength);
  return { json, bin, bytes };
}

export function readAccessor(glb, index) {
  const acc = glb.json.accessors[index];
  assert.ok(acc && !acc.sparse, 'Dense accessor');
  const view = glb.json.bufferViews[acc.bufferView];
  const width = { SCALAR: 1, VEC2: 2, VEC3: 3, VEC4: 4, MAT4: 16 }[acc.type];
  const item = {
    5121: [1, 'readUInt8'], 5123: [2, 'readUInt16LE'],
    5125: [4, 'readUInt32LE'], 5126: [4, 'readFloatLE'],
  }[acc.componentType];
  assert.ok(width && item && view, 'Supported accessor');
  const stride = view.byteStride ?? item[0] * width;
  const start = (view.byteOffset ?? 0) + (acc.byteOffset ?? 0);
  assert.ok(start + (acc.count - 1) * stride + item[0] * width <= (view.byteOffset ?? 0) + view.byteLength);
  const values = new Float64Array(acc.count * width);
  for (let i = 0; i < acc.count; ++i)
    for (let j = 0; j < width; ++j)
      values[i * width + j] = glb.bin[item[1]](start + i * stride + j * item[0]);
  return { values, width, count: acc.count, acc };
}
