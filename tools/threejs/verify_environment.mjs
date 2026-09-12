#!/usr/bin/env node
// Independent exported-byte verification. Does not import Three.js or the builder.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';
import assert from 'node:assert/strict';
import { readGlb, readAccessor } from './glb_reader.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const directory = path.join(root, 'game/assets/environment/threejs_campaign');
const manifestPath = path.join(directory, 'manifest.json');
const manifest = JSON.parse(fs.readFileSync(manifestPath));
const sha = bytes => createHash('sha256').update(bytes).digest('hex');
const required = ['Floor', 'Bridge', 'Rail', 'Column', 'Gate', 'Landmark', 'Rock', 'ArenaCover', 'Wall', 'Arcade', 'Watchtower', 'Lantern', 'Roof'];
const themes = ['spirit_ruins', 'blood_iron', 'jade_veil', 'celestial_fall', 'ember_abyss'];
const identity = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1];
const close = (a, b, message, tolerance = .0002) => assert.ok(Math.abs(a - b) <= tolerance, `${message}: ${a} vs ${b}`);
const mul = (a, b) => Array.from({ length: 16 }, (_, index) => {
  const row = index % 4, column = Math.floor(index / 4);
  return [0, 1, 2, 3].reduce((n, i) => n + a[i * 4 + row] * b[column * 4 + i], 0);
});
function nodeMatrix(node) {
  if (node.matrix) return node.matrix;
  const [x, y, z, w] = node.rotation ?? [0, 0, 0, 1], s = node.scale ?? [1, 1, 1], t = node.translation ?? [0, 0, 0];
  return [(1 - 2 * y * y - 2 * z * z) * s[0], (2 * x * y + 2 * z * w) * s[0], (2 * x * z - 2 * y * w) * s[0], 0,
    (2 * x * y - 2 * z * w) * s[1], (1 - 2 * x * x - 2 * z * z) * s[1], (2 * y * z + 2 * x * w) * s[1], 0,
    (2 * x * z + 2 * y * w) * s[2], (2 * y * z - 2 * x * w) * s[2], (1 - 2 * x * x - 2 * y * y) * s[2], 0, ...t, 1];
}
const point = (m, p) => [0, 1, 2].map(r => m[r] * p[0] + m[4 + r] * p[1] + m[8 + r] * p[2] + m[12 + r]);

function inspectPart(glb, index, retainedSource = false) {
  const bounds = { min: [Infinity, Infinity, Infinity], max: [-Infinity, -Infinity, -Infinity] }, triangles = [], mats = new Set();
  let meshes = 0, primitives = 0;
  function visit(i, parent) {
    const n = glb.json.nodes[i], matrix = mul(parent, nodeMatrix(n));
    if (n.mesh !== undefined) {
      meshes++;
      for (const p of glb.json.meshes[n.mesh].primitives) {
        primitives++; assert.equal(p.mode ?? 4, 4, 'Triangle primitives');
        mats.add(p.material); assert.ok(glb.json.materials[p.material]?.pbrMetallicRoughness, 'Portable PBR surface');
        const a = readAccessor(glb, p.attributes.POSITION), normals = readAccessor(glb, p.attributes.NORMAL);
        assert.equal(a.width, 3); assert.equal(normals.count, a.count);
        if (!retainedSource || p.attributes.TEXCOORD_0 !== undefined) assert.equal(readAccessor(glb, p.attributes.TEXCOORD_0).count, a.count);
        const positions = [];
        for (let j = 0; j < a.count; j++) {
          const xyz = point(matrix, Array.from(a.values.subarray(j * 3, j * 3 + 3)));
          assert.ok(xyz.every(Number.isFinite), 'Finite position');
          const normal = Array.from(normals.values.subarray(j * 3, j * 3 + 3));
          assert.ok(normal.every(Number.isFinite), 'Finite normal');
          close(Math.hypot(...normal), 1, 'Unit normal', .015);
          for (let axis = 0; axis < 3; axis++) { bounds.min[axis] = Math.min(bounds.min[axis], xyz[axis]); bounds.max[axis] = Math.max(bounds.max[axis], xyz[axis]); }
          positions.push(xyz);
        }
        const indices = p.indices !== undefined ? readAccessor(glb, p.indices).values : Array.from({ length: a.count }, (_, j) => j);
        assert.equal(indices.length % 3, 0, 'Complete triangle index triplets');
        assert.ok(Array.from(indices).every(j => Number.isInteger(j) && j >= 0 && j < a.count), 'Index ranges');
        for (let j = 0; j < indices.length; j += 3) triangles.push([positions[indices[j]], positions[indices[j + 1]], positions[indices[j + 2]]]);
      }
    }
    for (const child of n.children ?? []) visit(child, matrix);
  }
  visit(index, identity);
  return { ...bounds, size: bounds.max.map((v, i) => v - bounds.min[i]), triangles, materials: mats.size, meshes, primitives };
}

function triangleSignature(triangles) {
  // Each triangle's cyclic vertex order is preserved; reindexing alone is ignored.
  return sha(triangles.map(t => {
    const keys = t.map(p => p.map(v => Math.round(v * 100000)).join(','));
    return [keys.join('|'), [keys[1], keys[2], keys[0]].join('|'), [keys[2], keys[0], keys[1]].join('|')].sort()[0];
  }).sort().join('\n'));
}

assert.deepEqual(manifest.parts, required);
assert.deepEqual(Object.keys(manifest.themes), themes);
assert.equal(manifest.three_version, '0.185.1');
for (const [file, checksum] of Object.entries(manifest.source_files)) assert.equal(sha(fs.readFileSync(path.join(root, file))), checksum, `Current source ${file}`);
assert.equal(sha(JSON.stringify(manifest.source_files)), manifest.source_sha256);
const report = { schema_version: 1, evidence: 'independent GLB bytes and geometry', manifest_sha256: sha(fs.readFileSync(manifestPath)), generator_source_sha256: manifest.source_sha256, verifier_sources: Object.fromEntries(['tools/threejs/verify_environment.mjs', 'tools/threejs/glb_reader.mjs'].map(f => [f, sha(fs.readFileSync(path.join(root, f)))])), themes: {}, limitations: ['No Godot import, renderer, collision gameplay or target-device timing claims. Parent integration owns those checks.'] };

for (const theme of themes) {
  const entry = manifest.themes[theme], glb = readGlb(path.join(directory, entry.file));
  assert.equal(sha(glb.bytes), entry.sha256); assert.equal(glb.bytes.length, entry.bytes);
  assert.equal(glb.json.scenes.length, 1); assert.ok(!(glb.json.animations?.length), 'Static kit');
  const nodes = glb.json.scenes[glb.json.scene ?? 0].nodes;
  assert.deepEqual(nodes.map(i => glb.json.nodes[i].name), required, 'Direct named root children');
  const measured = {};
  for (const i of nodes) {
    const n = glb.json.nodes[i], name = n.name, s = inspectPart(glb, i), expected = entry.parts[name];
    nodeMatrix(n).forEach((v, j) => close(v, identity[j], `${theme}/${name} identity root`));
    assert.ok(s.triangles.length > 0);
    assert.ok(s.primitives < (['Landmark', 'Watchtower', 'Rock'].includes(name) ? 12 : 8), `${name} submission budget`);
    for (let axis = 0; axis < 3; axis++) {
      close(s.min[axis], expected.min[axis], `${name} min`); close(s.max[axis], expected.max[axis], `${name} max`); close(s.size[axis], expected.size[axis], `${name} size`);
    }
    assert.equal(s.triangles.length, expected.triangles); assert.equal(s.materials, expected.material_count); assert.equal(s.meshes, expected.mesh_count);
    measured[name] = { min: s.min, max: s.max, triangles: s.triangles.length, surfaces: s.primitives };
    if (name === 'Floor' || name === 'Bridge') {
      close(s.size[0], 6, `${name} 6m width`); close(s.size[2], 6, `${name} 6m depth`);
      close(s.min[1], name === 'Floor' ? -.6 : -.14, `${name} base`); close(s.max[1], name === 'Floor' ? 0 : .14, `${name} walk datum`);
      assert.ok(s.triangles.length < 2000, `${name} repeating triangle budget`);
    }
    if (name === 'Rail') { close(s.size[0], 6, 'Rail width'); close(s.size[1], 1.4, 'Rail height'); close(s.size[2], .48, 'Rail thickness'); close(s.min[1], 0, 'Rail base'); }
    if (name === 'Gate') {
      // Passage between fixed ±4.8m pillars stays clear; no artwork at player head height.
      for (const t of s.triangles) for (const v of t) if (v[1] < 3.5) assert.ok(Math.abs(v[0]) > 3.7, 'Gate clear passage');
      for (const side of [-1, 1]) assert.ok(s.triangles.some(t => t.some(v => Math.abs(v[0] - side * 4.8) < .8 && v[1] > 5.7)), 'Gate pillar at ±4.8');
    }
    if (name === 'ArenaCover') [2, 3, 2].forEach((v, a) => close(s.size[a], v, 'Cover dimensions'));
    if (name === 'Rock') [10, 20, 10].forEach((v, a) => close(s.size[a], v, 'Rock dimensions'));
    if (name === 'Wall') { close(s.size[0], 6, 'Wall width'); close(s.min[1], 0, 'Wall base'); close(s.max[1], 10, 'Wall height'); assert.ok(s.size[2] <= 1.501, 'Wall buttress depth'); }
    if (name === 'Arcade') {
      [6, 7, 1].forEach((v, a) => close(s.size[a], v, 'Arcade dimensions'));
      // The central 4x4m aperture must contain no triangle bounds at any depth.
      for (const t of s.triangles) {
        const xmin = Math.min(...t.map(v => v[0])), xmax = Math.max(...t.map(v => v[0]));
        const ymin = Math.min(...t.map(v => v[1])), ymax = Math.max(...t.map(v => v[1]));
        assert.ok(xmax <= -2 || xmin >= 2 || ymin >= 4 || ymax <= 0, 'Arcade clear 4m width x4m height aperture');
      }
    }
    if (name === 'Watchtower') { [12, 28, 12].forEach((v, a) => close(s.size[a], v, 'Watchtower dimensions')); close(s.min[1], 0, 'Watchtower base'); }
    if (name === 'Lantern') assert.ok(s.size[0] < 1 && s.size[1] < 2 && s.size[2] < 1, 'Lantern scale');
    if (name === 'Roof') { [6, 3, 6].forEach((v, a) => close(s.size[a], v, 'Roof dimensions')); close(s.min[1], 5, 'Roof minimum clear height'); close(s.max[1], 8, 'Roof maximum height'); }
    if (name === 'Landmark') {
      const old = readGlb(path.join(root, entry.retained_landmark.file)); assert.equal(sha(old.bytes), entry.retained_landmark.sha256);
      const oldIndex = old.json.nodes.findIndex(n => n.name === 'Landmark');
      const oldPart = inspectPart(old, oldIndex, true);
      assert.equal(triangleSignature(s.triangles), triangleSignature(oldPart.triangles), 'Landmark ordered world triangles unchanged');
    }
  }
  report.themes[theme] = { sha256: entry.sha256, parts: measured, retained_landmark_triangles: 'exact', root_contract: 'identity direct children', portable_materials: 'core PBR', embedded_dependencies: 'none external' };
  console.log(`THREEJS_GLB_VERIFIED ${theme} parts=13 bytes=${glb.bytes.length}`);
}
report.result = 'THREEJS_ENVIRONMENT_CONTRACTS_OK';
fs.writeFileSync(path.join(directory, 'verification.json'), JSON.stringify(report, null, 2) + '\n');
console.log('THREEJS_ENVIRONMENT_CONTRACTS_OK themes=5 parts=65');
