#!/usr/bin/env node
// node tools/test_validate_skinned_glbs.mjs; writes only isolated contract fixtures under build/.
import assert from 'node:assert/strict';
import { mkdirSync, mkdtempSync, readFileSync, realpathSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const validator = join(root, 'tools/validate_skinned_glbs.mjs');
const allowed = join(root, 'build/glb-models/rigging/validator-contract-20260908');
mkdirSync(allowed, { recursive: true });
assert.equal(realpathSync(allowed).toLowerCase(), allowed.toLowerCase(), 'Fixture directory must not redirect outside its assigned path');
const run = mkdtempSync(join(allowed, 'run-'));
const identity = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1];

function fixture(skinned, options = {}) {
  const json = { asset: { version: '2.0' }, scene: 0, scenes: [{ nodes: skinned ? [0, 1] : [0] }],
    accessors: [], bufferViews: [], materials: [{ pbrMetallicRoughness: { baseColorFactor: [0.4, 0.7, 0.2, 1] } }] };
  const parts = [];
  let length = 0;
  function accessor(values, type, componentType = 5126) {
    const size = componentType === 5126 ? 4 : 2, bytes = Buffer.alloc(values.length * size);
    values.forEach((value, i) => componentType === 5126 ? bytes.writeFloatLE(value, i * size) : bytes.writeUInt16LE(value, i * size));
    const view = json.bufferViews.push({ buffer: 0, byteOffset: length, byteLength: bytes.length }) - 1;
    parts.push(bytes);
    length += bytes.length;
    const padding = (4 - length % 4) % 4;
    if (padding) { parts.push(Buffer.alloc(padding)); length += padding; }
    return json.accessors.push({ bufferView: view, componentType, type, count: values.length / { SCALAR: 1, VEC2: 2, VEC3: 3, VEC4: 4, MAT4: 16 }[type] }) - 1;
  }
  const points = [[0, 0, 0], [1, 0, 0], [1, 1, 0], [0, 1, 0]], uvs = [[0, 0], [1, 0], [1, 1], [0, 1]];
  const order = skinned ? [2, 0, 3, 1] : [0, 1, 2, 0, 2, 3];
  let positions = order.map((i) => [...points[i]]), normals = order.map(() => [0, 0.6, 0.8]);
  if (options.bakedTransform) {
    positions = positions.map(([x, y, z]) => [-y + 0.125, 2 * x + 0.25, z * 0.5 + 0.5]);
    normals = normals.map(([x, y, z]) => {
      const n = [-y, x * 0.5, z * 2], length = Math.hypot(...n);
      return n.map((v) => v / length);
    });
  }
  const noise = options.noise ?? 0;
  const attrs = { POSITION: accessor(positions.flat().map((v) => v + noise), 'VEC3'),
    NORMAL: accessor(normals.flat().map((v) => (options.negateNormals ? -v : v) + noise + (options.normalNoise ?? 0)), 'VEC3'),
    TEXCOORD_0: accessor(order.flatMap((i) => uvs[options.swapUvs ? 3 - i : i]).map((v) => options.zeroUvs ? 0 : v + noise), 'VEC2'),
    TEXCOORD_1: accessor(order.flatMap((i) => uvs[i].map((v) => v * 0.5 + 0.125)).map((v) => options.zeroSecondUvs ? 0 : v), 'VEC2') };
  const primitive = { attributes: attrs, material: 0 };
  if (skinned) {
    const joints = order.flatMap(() => [0, 1, 0, 0]), weights = order.flatMap(() => [0.25, 0.75, 0, 0]);
    if (options.invalidJoint) joints[1] = 2;
    if (options.duplicateJoint) joints[1] = 0;
    if (options.badWeightSum) weights[1] = 0.5;
    if (options.negativeWeight) { weights[0] = -0.25; weights[1] = 1.25; }
    if (options.nanWeight) weights[0] = NaN;
    if (options.rootOnly) for (let i = 0; i < weights.length; i += 4) { weights[i] = 1; weights[i + 1] = 0; }
    if (options.rigidChild) for (let i = 0; i < weights.length; i += 4) { weights[i] = 0; weights[i + 1] = 1; }
    attrs.JOINTS_0 = accessor(joints, 'VEC4', 5123);
    attrs.WEIGHTS_0 = accessor(weights, 'VEC4');
    if (options.missingWeights) delete attrs.WEIGHTS_0;
    let indices = [0, 2, 1, 3, 0, 1]; // Reordered faces and cyclic corners after 6-to-4 vertex deduplication.
    if (options.reverseWinding) indices = [0, 1, 2, 3, 1, 0];
    if (options.duplicateFace) indices = [0, 2, 1, 0, 2, 1];
    primitive.indices = accessor(indices, 'SCALAR', 5123);
    const matrices = [...identity, ...identity];
    if (options.singularBind) matrices.fill(0, 16);
    json.skins = [{ joints: [1, 2], skeleton: 1, inverseBindMatrices: accessor(matrices, 'MAT4') }];
  }
  const transform = { translation: [0.125, 0.25, 0.5], rotation: [0, 0, Math.SQRT1_2, Math.SQRT1_2], scale: [2, 1, 0.5] };
  json.nodes = skinned ? [{ name: 'surface', mesh: 0, skin: 0 }, { name: 'root', children: [2], ...(options.bakedTransform ? {} : transform) }, { name: 'joint' }]
    : [{ name: 'surface', mesh: 0, ...transform }];
  if (options.noSkin) { delete json.skins; delete json.nodes[0].skin; }
  if (options.materialChanged) json.materials[0].pbrMetallicRoughness.baseColorFactor = [1, 0, 0, 1];
  json.meshes = [{ primitives: [primitive] }];
  json.buffers = [{ byteLength: length }];
  return pack(json, Buffer.concat(parts));
}

function pack(json, bin) {
  const text = Buffer.from(JSON.stringify(json)), padding = (4 - text.length % 4) % 4;
  const header = Buffer.alloc(20);
  header.writeUInt32LE(0x46546c67, 0);
  header.writeUInt32LE(2, 4);
  header.writeUInt32LE(28 + text.length + padding + bin.length, 8);
  header.writeUInt32LE(text.length + padding, 12);
  header.writeUInt32LE(0x4e4f534a, 16);
  const binHeader = Buffer.alloc(8);
  binHeader.writeUInt32LE(bin.length, 0);
  binHeader.writeUInt32LE(0x004e4942, 4);
  return Buffer.concat([header, text, Buffer.alloc(padding, 0x20), binHeader, bin]);
}

function corruptCopy(bytes, kind) {
  const buffer = Buffer.from(bytes), json = JSON.parse(buffer.subarray(20, 20 + buffer.readUInt32LE(12)).toString('utf8'));
  const bin = 28 + buffer.readUInt32LE(12), seen = new Set();
  let changed = 0;
  for (const mesh of json.meshes) for (const primitive of mesh.primitives) {
    const index = kind === 'winding' ? primitive.indices : primitive.attributes[kind === 'uv' ? 'TEXCOORD_0' : 'NORMAL'];
    if (index === undefined || seen.has(index)) continue;
    seen.add(index);
    const a = json.accessors[index], view = json.bufferViews[a.bufferView];
    const size = { 5121: 1, 5123: 2, 5125: 4, 5126: 4 }[a.componentType];
    const components = { SCALAR: 1, VEC2: 2, VEC3: 3 }[a.type], stride = view.byteStride ?? size * components;
    const start = bin + (view.byteOffset ?? 0) + (a.byteOffset ?? 0);
    if (kind === 'winding') {
      for (let i = 0; i < a.count; i += 3) {
        const x = start + (i + 1) * stride, y = start + (i + 2) * stride, saved = Buffer.from(buffer.subarray(x, x + size));
        buffer.copy(buffer, x, y, y + size);
        saved.copy(buffer, y);
        changed++;
      }
    } else {
      assert.equal(a.componentType, 5126);
      for (let i = 0; i < a.count; i++) for (let c = 0; c < components; c++) {
        const offset = start + i * stride + c * size;
        buffer.writeFloatLE(kind === 'uv' ? 0 : -buffer.readFloatLE(offset), offset);
        changed++;
      }
    }
  }
  assert.ok(changed > 0, `${kind} corruption must exercise real data`);
  return buffer;
}

let passed = 0, failed = 0;
function test(name, source, output, expectedFailure = null, options = {}) {
  try {
    const dir = join(run, name), sourceDir = join(dir, 'source'), outputDir = join(dir, 'output'), reportPath = join(dir, 'validation.json');
    mkdirSync(sourceDir, { recursive: true });
    mkdirSync(outputDir, { recursive: true });
    writeFileSync(join(sourceDir, 'model.glb'), source);
    writeFileSync(join(outputDir, 'model.glb'), output);
    if (options.missing) writeFileSync(join(sourceDir, 'missing.glb'), source);
    if (options.extra) writeFileSync(join(outputDir, 'extra.glb'), output);
    const child = spawnSync(process.execPath, [validator, '--source', sourceDir, '--output', outputDir, '--report', reportPath],
      { cwd: root, encoding: 'utf8', timeout: 120000, maxBuffer: 16 * 1024 * 1024, windowsHide: true });
    assert.ifError(child.error);
    assert.equal(child.signal, null);
    const partial = !!(options.missing || options.extra), expectedExit = expectedFailure || partial ? 1 : 0;
    assert.equal(child.status, expectedExit, child.stdout + child.stderr);
    assert.ok(child.stdout.includes(expectedExit ? 'SKINNED_GLBS_VALIDATION_FAILED ' : 'SKINNED_GLBS_VALIDATION_OK '), child.stdout);
    const report = JSON.parse(readFileSync(reportPath, 'utf8')), model = report.models[0];
    assert.equal(report.summary.checked, 1);
    assert.equal(model.ok, !expectedFailure, JSON.stringify(model.failures));
    if (expectedFailure) assert.match(model.failures.join('; '), expectedFailure);
    if (options.dedup) assert.ok(model.source.vertices > model.output.vertices, 'Positive fixture must really deduplicate vertices');
    if (options.missing) { assert.equal(report.summary.missing, 1); assert.equal(report.summary.passed, 1); }
    if (options.extra) { assert.equal(report.summary.extra, 1); assert.equal(report.summary.passed, 1); }
    passed++;
    console.log(`PASS ${name}`);
  } catch (error) {
    failed++;
    console.error(`FAIL ${name}: ${error.stack}`);
  }
}

const original = fixture(false), valid = fixture(true), corners = /Oriented rest triangle\/corner data changed/;
test('dedup-reindex-cyclic-triangle-order', original, valid, null, { dedup: true });
test('minor-float-roundoff', original, fixture(true, { noise: 1e-7 }));
test('minor-normal-roundoff', original, fixture(true, { normalNoise: 1e-4 }));
test('world-rest-normal-transform', original, fixture(true, { bakedTransform: true }));
test('valid-rigid-child-weights', original, fixture(true, { rigidChild: true }));
for (const [name, options] of [
  ['zero-uvs', { zeroUvs: true }], ['negated-normals', { negateNormals: true }], ['reversed-winding', { reverseWinding: true }],
  ['secondary-uv-corruption', { zeroSecondUvs: true }], ['duplicate-face-preserves-count-and-cloud', { duplicateFace: true }],
  ['uvs-assigned-to-wrong-corners', { swapUvs: true }], ['normal-error-beyond-tolerance', { normalNoise: 0.01 }],
]) test(name, original, fixture(true, options), corners);
for (const [name, options, expected] of [
  ['joint-out-of-range', { invalidJoint: true }, /joint index .* out of range/],
  ['duplicate-positive-joint', { duplicateJoint: true }, /repeats a nonzero joint influence/],
  ['weight-sum', { badWeightSum: true }, /weight sum/],
  ['negative-weight', { negativeWeight: true }, /weight outside/],
  ['non-finite-weight', { nanWeight: true }, /Non-finite value/],
  ['root-only-weighting', { rootOnly: true }, /no weighted non-root joint/],
  ['missing-weight-attribute', { missingWeights: true }, /lacks JOINTS_0\/WEIGHTS_0/],
  ['missing-skin', { noSkin: true }, /No skins/],
  ['singular-inverse-bind', { singularBind: true }, /Invalid inverse bind matrix/],
  ['material-regression', { materialChanged: true }, /Material properties/],
]) test(name, original, fixture(true, options), expected);
test('partial-inventory-exit-one', original, valid, null, { missing: true });
test('extra-inventory-exit-one', original, valid, null, { extra: true });

test('copied-valid-dedup', original, Buffer.from(valid), null, { dedup: true });
for (const kind of ['uv', 'normal', 'winding']) test(`copied-corrupt-${kind}`, original, corruptCopy(valid, kind), corners);
console.log(`${failed ? 'SKINNED_GLBS_CONTRACTS_FAILED' : 'SKINNED_GLBS_CONTRACTS_OK'} ${JSON.stringify({ passed, failed, fixtures: run })}`);
process.exitCode = failed ? 1 : 0;
