#!/usr/bin/env node
// Independent preservation and sampled skin-motion contracts for native NLA exports.
import { readFileSync, readdirSync, writeFileSync, realpathSync, existsSync, lstatSync } from 'node:fs';
import { resolve, join, relative, dirname, basename, isAbsolute, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';
import { isDeepStrictEqual } from 'node:util';
import { Matrix4, Quaternion, Vector3 } from '../build/glb-models/node_modules/three/build/three.module.js';

const check = (ok, message) => { if (!ok) throw new Error(message); };
const uint = n => Number.isSafeInteger(n) && n >= 0;
const finite = a => a.every(Number.isFinite);
const TYPES = { 5121: [1, 'readUInt8', 255], 5123: [2, 'readUInt16LE', 65535], 5125: [4, 'readUInt32LE', 4294967295], 5126: [4, 'readFloatLE', 1] };
const WIDTHS = { SCALAR: 1, VEC2: 2, VEC3: 3, VEC4: 4, MAT4: 16 };
const FRACTIONS = [0, .2, .4, .6, .8, 1], TIME_TOLERANCE = 1e-4;

function readGlb(bytes) {
  check(bytes.length >= 28 && bytes.readUInt32LE(0) === 0x46546c67 && bytes.readUInt32LE(4) === 2 && bytes.readUInt32LE(8) === bytes.length, 'Invalid GLB header/length');
  let json, bin;
  for (let cursor = 12; cursor < bytes.length;) {
    check(cursor + 8 <= bytes.length, 'Truncated chunk header');
    const length = bytes.readUInt32LE(cursor), kind = bytes.readUInt32LE(cursor + 4);
    check(length % 4 === 0 && cursor + 8 + length <= bytes.length, 'Invalid chunk bounds/alignment');
    const chunk = bytes.subarray(cursor + 8, cursor + 8 + length);
    if (kind === 0x4e4f534a) { check(cursor === 12 && !json, 'Duplicate/misplaced JSON'); json = JSON.parse(chunk.toString('utf8')); }
    else { check(kind === 0x004e4942 && json && !bin, 'Unknown/duplicate BIN chunk'); bin = chunk; }
    cursor += 8 + length;
  }
  check(json?.asset?.version === '2.0' && bin && json.buffers?.length === 1 && !json.buffers[0].uri, 'Expected embedded glTF 2.0 buffer');
  const length = json.buffers[0].byteLength, cache = new Map();
  check(uint(length) && length <= bin.length && bin.length - length <= 3, 'Invalid buffer length');
  for (const v of json.bufferViews ?? []) {
    check(v.buffer === 0 && uint(v.byteOffset ?? 0) && uint(v.byteLength) && (v.byteOffset ?? 0) + v.byteLength <= length, 'Invalid bufferView bounds');
    if (v.byteStride !== undefined) check(uint(v.byteStride) && v.byteStride >= 4 && v.byteStride <= 252 && v.byteStride % 4 === 0, 'Invalid byteStride');
  }
  function accessor(index) {
    if (cache.has(index)) return cache.get(index);
    const a = json.accessors?.[index], type = TYPES[a?.componentType], width = WIDTHS[a?.type];
    check(uint(index) && a && type && width && uint(a.count) && a.count > 0 && !a.sparse, `Invalid/unsupported accessor ${index}`);
    const view = json.bufferViews[a.bufferView], offset = a.byteOffset ?? 0, stride = view?.byteStride ?? type[0] * width;
    check(uint(a.bufferView) && view && uint(offset) && offset % type[0] === 0 && ((view.byteOffset ?? 0) + offset) % type[0] === 0, `Misaligned accessor ${index}`);
    check(stride >= type[0] * width && stride % type[0] === 0 && offset + (a.count - 1) * stride + type[0] * width <= view.byteLength, `Accessor ${index} exceeds view/stride`);
    check(!a.normalized || [5121, 5123].includes(a.componentType), `Invalid normalization ${index}`);
    const values = new Float64Array(a.count * width);
    for (let i = 0; i < a.count; i++) for (let c = 0; c < width; c++) {
      const value = bin[type[1]]((view.byteOffset ?? 0) + offset + i * stride + c * type[0]);
      check(Number.isFinite(value), `Non-finite accessor ${index}`);
      values[i * width + c] = a.normalized ? value / type[2] : value;
    }
    const result = { ...a, width, values };
    cache.set(index, result); return result;
  }
  return { json, bin, accessor };
}

function preserved(source, output) {
  check(output.bin.length >= source.bin.length && output.bin.subarray(0, source.bin.length).equals(source.bin), 'Original BIN prefix changed');
  const before = structuredClone(source.json), after = structuredClone(output.json);
  for (const key of ['accessors', 'bufferViews']) {
    check(Array.isArray(after[key]) && after[key].length >= before[key].length, `Original ${key} prefix missing`);
    after[key] = after[key].slice(0, before[key].length);
  }
  delete before.animations; delete after.animations;
  after.buffers[0].byteLength = before.buffers[0].byteLength;
  check(isDeepStrictEqual(before, after), 'Original JSON changed (including mesh/skin/material/image/node/accessor/view data)');
}

function context(model) {
  const { json: d, accessor } = model, nodes = d.nodes ?? [], parents = Array(nodes.length).fill(-1), order = [], state = [];
  nodes.forEach((n, i) => (n.children ?? []).forEach(c => { check(uint(c) && nodes[c] && parents[c] < 0, 'Invalid child/multiple parents'); parents[c] = i; }));
  function visit(i) {
    check(state[i] !== 1, 'Cyclic node hierarchy'); if (state[i] === 2) return;
    state[i] = 1; if (parents[i] >= 0) visit(parents[i]); state[i] = 2; order.push(i);
  }
  nodes.forEach((_, i) => visit(i));
  const active = new Set(), activate = i => { check(uint(i) && nodes[i], 'Invalid scene node'); active.add(i); (nodes[i].children ?? []).forEach(activate); };
  check(d.scenes?.[d.scene ?? 0]?.nodes?.length, 'Missing default scene');
  d.scenes[d.scene ?? 0].nodes.forEach(activate);
  const rest = nodes.map(n => {
    if (n.matrix) { check(n.matrix.length === 16 && finite(n.matrix), 'Invalid rest matrix'); return new Matrix4().fromArray(n.matrix); }
    const t = n.translation ?? [0, 0, 0], q = n.rotation ?? [0, 0, 0, 1], s = n.scale ?? [1, 1, 1];
    check(t.length === 3 && q.length === 4 && s.length === 3 && finite([...t, ...q, ...s]) && Math.abs(Math.hypot(...q) - 1) < 1e-4 && s.every(v => v > 0), 'Invalid rest TRS');
    return new Matrix4().compose(new Vector3().fromArray(t), new Quaternion().fromArray(q), new Vector3().fromArray(s));
  });
  check(d.skins?.length, 'Missing skins');
  const joints = new Set(d.skins.flatMap(s => s.joints));
  check([...joints].every(j => uint(j) && nodes[j] && active.has(j)), 'Invalid/inactive skin joint');
  const nonroot = new Set([...joints].filter(j => { for (let p = parents[j]; p >= 0; p = parents[p]) if (joints.has(p)) return true; return false; }));
  check(nonroot.size, 'No non-root joints');
  const skins = d.skins.map(s => {
    check(s.joints.length >= 2 && new Set(s.joints).size === s.joints.length, 'Invalid skin joint list');
    const a = accessor(s.inverseBindMatrices);
    check(a.type === 'MAT4' && a.componentType === 5126 && a.count === s.joints.length, 'Invalid inverse bind matrices');
    const inverse = s.joints.map((_, i) => new Matrix4().fromArray(a.values, i * 16));
    check(inverse.every(m => Math.abs(m.determinant()) > 1e-20), 'Singular inverse bind matrix');
    return { joints: s.joints, inverse };
  });
  const probes = [], meshNodes = new Set(), usedMeshes = new Set();
  nodes.forEach((n, node) => {
    if (n.mesh === undefined) return;
    check(active.has(node) && uint(n.mesh) && d.meshes[n.mesh] && uint(n.skin) && skins[n.skin], 'Inactive/unskinned/invalid mesh');
    meshNodes.add(node); usedMeshes.add(n.mesh);
    for (const primitive of d.meshes[n.mesh].primitives) {
      check(!primitive.targets?.length && (primitive.mode ?? 4) === 4, 'Only native unmorphed triangles are supported');
      const attrs = primitive.attributes, positions = accessor(attrs.POSITION), sets = Object.keys(attrs).filter(k => /^JOINTS_\d+$/.test(k)).sort();
      check(positions.type === 'VEC3' && positions.componentType === 5126 && sets.length, 'Missing position/skin channels');
      const influences = sets.map(key => {
        const j = accessor(attrs[key]), w = accessor(attrs[key.replace('JOINTS_', 'WEIGHTS_')]);
        check(j.type === 'VEC4' && [5121, 5123].includes(j.componentType) && !j.normalized && w.type === 'VEC4' && (w.componentType === 5126 || w.normalized), 'Invalid joint/weight type');
        check(j.count === positions.count && w.count === positions.count, 'Skin/position counts differ'); return { j, w };
      });
      let vertices = Array.from({ length: positions.count }, (_, i) => i);
      if (primitive.indices !== undefined) {
        const index = accessor(primitive.indices);
        check(index.type === 'SCALAR' && [5121, 5123, 5125].includes(index.componentType) && !index.normalized, 'Invalid triangle index type');
        vertices = Array.from(index.values);
      }
      check(vertices.length % 3 === 0 && vertices.every(i => uint(i) && i < positions.count), 'Invalid triangle indices');
      vertices = [...new Set(vertices)];
      const count = Math.min(24, vertices.length);
      for (let k = 0; k < count; k++) {
        const vertex = vertices[Math.round(k * (vertices.length - 1) / Math.max(1, count - 1))], weights = [];
        for (const { j, w } of influences) for (let c = 0; c < 4; c++) {
          const slot = j.values[vertex * 4 + c], weight = w.values[vertex * 4 + c];
          check(uint(slot) && slot < skins[n.skin].joints.length && weight >= 0, 'Invalid vertex influence');
          if (weight > 0) weights.push({ slot, weight });
        }
        check(Math.abs(weights.reduce((sum, w) => sum + w.weight, 0) - 1) < 1e-3, 'Weights do not sum to one');
        probes.push({ skin: n.skin, position: new Vector3().fromArray(positions.values, vertex * 3), weights,
          nonroot: weights.some(w => nonroot.has(skins[n.skin].joints[w.slot])) });
      }
    }
  });
  check(probes.length && usedMeshes.size === d.meshes.length, 'Missing mesh sampling coverage');
  function worlds(locals) { const world = []; for (const i of order) world[i] = parents[i] < 0 ? locals[i].clone() : world[parents[i]].clone().multiply(locals[i]); return world; }
  function points(world) {
    const matrices = skins.map(s => s.joints.map((j, i) => world[j].clone().multiply(s.inverse[i])));
    // World-space skinning: meshWorld cancels inverse(meshWorld) in the glTF joint matrix.
    return probes.map(p => {
      const result = new Vector3();
      for (const w of p.weights) result.addScaledVector(p.position.clone().applyMatrix4(matrices[p.skin][w.slot]), w.weight);
      check(finite(result.toArray()), 'Non-finite skinned point'); return result;
    });
  }
  const basePoints = points(worlds(rest)), low = new Vector3(Infinity, Infinity, Infinity), high = new Vector3(-Infinity, -Infinity, -Infinity);
  basePoints.forEach(p => { low.min(p); high.max(p); });
  const size = Math.max(...high.sub(low).toArray(), .01);
  return { ...model, nodes, joints, nonroot, rest, probes, worlds, points, size, meshNodes: meshNodes.size };
}

function inspectClip(ctx, animation, recipe, source) {
  check(typeof recipe.loop === 'boolean' && typeof recipe.kind === 'string' && recipe.kind && Number.isFinite(recipe.duration) && recipe.duration > 0, 'Invalid recipe metadata');
  check(recipe.events && !Array.isArray(recipe.events) && Object.values(recipe.events).every(t => Number.isFinite(t) && t >= 0 && t <= recipe.duration + TIME_TOLERANCE), 'Invalid recipe events');
  for (const key of ['loop', 'kind', 'events']) check(isDeepStrictEqual(animation.extras?.[key], recipe[key]), `Metadata mismatch: ${key}`);
  check(animation.channels?.length && animation.samplers?.length, 'Empty animation channels/samplers');
  const seen = new Set(), used = new Set();
  const channels = animation.channels.map(c => {
    const node = c.target?.node, path = c.target?.path, key = `${node}:${path}`, sampler = animation.samplers[c.sampler];
    check(uint(node) && ctx.joints.has(node) && !ctx.nodes[node].matrix && ['translation', 'rotation', 'scale'].includes(path) && !seen.has(key), 'Invalid/duplicate animation target');
    check(uint(c.sampler) && sampler && ['LINEAR', 'STEP'].includes(sampler.interpolation ?? 'LINEAR'), 'Invalid sampler or unsupported interpolation');
    seen.add(key); used.add(c.sampler);
    for (const index of [sampler.input, sampler.output]) {
      const a = ctx.json.accessors[index], view = ctx.json.bufferViews[a?.bufferView];
      check(uint(index) && index >= source.json.accessors.length && a?.bufferView >= source.json.bufferViews.length && (view?.byteOffset ?? -1) >= source.bin.length, 'Animation stream is not appended');
    }
    const input = ctx.accessor(sampler.input), output = ctx.accessor(sampler.output), times = input.values;
    check(input.type === 'SCALAR' && input.componentType === 5126 && !input.normalized && input.count >= 2 && times[0] === 0, 'Invalid animation input times');
    check(times.every((t, i) => t >= 0 && (i === 0 || t > times[i - 1])), 'Non-monotonic animation times');
    check(Math.abs(times.at(-1) - recipe.duration) <= TIME_TOLERANCE, 'Animation duration differs from recipe');
    check(output.componentType === 5126 && !output.normalized && output.type === (path === 'rotation' ? 'VEC4' : 'VEC3') && output.count === input.count, 'Animation output count/type mismatch');
    if (path === 'rotation') for (let i = 0; i < output.count; i++) check(Math.abs(Math.hypot(...output.values.subarray(i * 4, i * 4 + 4)) - 1) < 1e-4, 'Non-normalized animation quaternion');
    if (path === 'scale') check(output.values.every(v => v > 0), 'Non-positive animation scale');
    return { node, path, times, output, interpolation: sampler.interpolation ?? 'LINEAR' };
  });
  check(used.size === animation.samplers.length, 'Unused animation samplers');
  // Native bake keys every joint's TRS. Missing constant tracks can expose stale playback state.
  for (const node of ctx.joints) for (const path of ['translation', 'rotation', 'scale']) check(seen.has(`${node}:${path}`), `Missing joint channel ${ctx.nodes[node].name}:${path}`);
  const duration = Math.max(...channels.map(c => c.times.at(-1)));
  function evaluate(time, freezeNonroot = false) {
    const transforms = new Map(), locals = ctx.rest.slice();
    for (const c of channels) {
      if (!transforms.has(c.node)) {
        const n = ctx.nodes[c.node]; transforms.set(c.node, { translation: new Vector3().fromArray(n.translation ?? [0, 0, 0]), rotation: new Quaternion().fromArray(n.rotation ?? [0, 0, 0, 1]), scale: new Vector3().fromArray(n.scale ?? [1, 1, 1]) });
      }
      const t = freezeNonroot && ctx.nonroot.has(c.node) ? 0 : time;
      let i = 0; while (i + 1 < c.times.length && c.times[i + 1] <= t) i++;
      const next = Math.min(i + 1, c.times.length - 1), alpha = c.interpolation === 'STEP' || i === next ? 0 : Math.min(1, Math.max(0, (t - c.times[i]) / (c.times[next] - c.times[i])));
      const value = c.path === 'rotation' ? new Quaternion() : new Vector3(), target = value.clone();
      value.fromArray(c.output.values, i * c.output.width); target.fromArray(c.output.values, next * c.output.width);
      transforms.get(c.node)[c.path] = c.path === 'rotation' ? value.slerp(target, alpha) : value.lerp(target, alpha);
    }
    for (const [node, trs] of transforms) locals[node] = new Matrix4().compose(trs.translation, trs.rotation, trs.scale);
    return ctx.points(ctx.worlds(locals));
  }
  const first = evaluate(0), tolerance = Math.max(1e-7, ctx.size * 1e-6), samples = [];
  let maxDisplacement = 0, maxNonrootDisplacement = 0, loopError = 0;
  for (const fraction of FRACTIONS) {
    const points = evaluate(duration * fraction), frozen = evaluate(duration * fraction, true);
    let motion = 0, contribution = 0;
    points.forEach((p, i) => { motion = Math.max(motion, p.distanceTo(first[i])); if (ctx.probes[i].nonroot) contribution = Math.max(contribution, p.distanceTo(frozen[i])); });
    maxDisplacement = Math.max(maxDisplacement, motion); maxNonrootDisplacement = Math.max(maxNonrootDisplacement, contribution);
    if (fraction === 1) loopError = motion;
    samples.push({ fraction, maxDisplacement: motion, maxNonrootDisplacement: contribution });
  }
  check(maxDisplacement > tolerance && maxNonrootDisplacement > tolerance, 'Static clip or no weighted non-root animation contribution');
  check(!recipe.loop || loopError <= Math.max(1e-6, ctx.size * 1e-5), `Loop geometry does not close: ${loopError}`);
  return { name: animation.name, ok: true, duration, channelCount: channels.length, loop: recipe.loop, kind: recipe.kind, events: recipe.events, maxDisplacement, maxNonrootDisplacement, loopError, motionTolerance: tolerance, samples };
}

export function validateModel(file, sourceBytes, outputBytes, recipe) {
  const source = readGlb(sourceBytes), output = readGlb(outputBytes); preserved(source, output);
  check(recipe.file === file && recipe.source_sha256 === createHash('sha256').update(sourceBytes).digest('hex'), 'Recipe file/source hash mismatch');
  check(recipe.actions?.length && new Set(recipe.actions.map(a => a.name)).size === recipe.actions.length && recipe.actions.every(a => typeof a.name === 'string' && a.name), 'Invalid/duplicate recipe names');
  const animations = output.json.animations;
  check(animations?.length === recipe.actions.length && new Set(animations.map(a => a.name)).size === animations.length, 'Missing/duplicate animation names/count');
  const definitions = new Map(recipe.actions.map(a => [a.name, a]));
  check(animations.every(a => definitions.has(a.name)), 'Unexpected animation name');
  const ctx = context(output), clips = animations.map(a => {
    try { return inspectClip(ctx, a, definitions.get(a.name), source); }
    catch (error) { return { name: a.name, ok: false, failures: [error.message], channelCount: a.channels?.length ?? 0 }; }
  });
  return { file, ok: clips.every(c => c.ok), preserved: true, sampledVertices: ctx.probes.length, meshNodes: ctx.meshNodes, clips };
}

function inventory(dir, suffix, root = dir, files = new Map()) {
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const path = join(dir, entry.name); check(!entry.isSymbolicLink(), 'Symlinks are unsupported in validation inputs');
    if (entry.isDirectory()) inventory(path, suffix, root, files);
    else if (entry.isFile() && entry.name.toLowerCase().endsWith(suffix)) files.set(relative(root, path).replaceAll('\\', '/'), path);
  }
  return files;
}

function main() {
  const options = {}, allowed = ['--source', '--output', '--reports', '--report', '--expected-count'];
  for (let i = 2; i < process.argv.length; i += 2) {
    const key = process.argv[i], value = process.argv[i + 1];
    check(allowed.includes(key) && value && !value.startsWith('--') && options[key] === undefined, 'Usage: node tools/validate_model_actions.mjs --source DIR --output DIR --reports DIR --report JSON [--expected-count N]'); options[key] = value;
  }
  for (const key of allowed.slice(0, 4)) check(options[key], `Required: ${key}`);
  const expected = options['--expected-count'] === undefined ? null : Number(options['--expected-count']);
  check(expected === null || (uint(expected) && expected > 0), 'Invalid expected count');
  const roots = allowed.slice(0, 3).map(k => realpathSync(resolve(options[k]))), reportPath = resolve(options['--report']);
  const actualReport = join(realpathSync(dirname(reportPath)), basename(reportPath));
  check(reportPath.toLowerCase().endsWith('.json'), 'Report must be a JSON file');
  check(!existsSync(reportPath) || (lstatSync(reportPath).isFile() && lstatSync(reportPath).nlink === 1), 'Report must not be a symlink/hardlink');
  for (const dir of roots) { const r = relative(dir, actualReport); check(r === '..' || r.startsWith('..' + sep) || isAbsolute(r), 'Report must be outside source/output/recipe directories'); }
  const [sourceDir, outputDir, reportsDir] = roots, sources = inventory(sourceDir, '.glb'), outputs = inventory(outputDir, '.glb'), reports = inventory(reportsDir, '.json');
  const recipes = new Set([...sources.keys()].map(f => f.replaceAll('/', '__') + '.json'));
  const result = { source: sourceDir, output: outputDir, reports: reportsDir, expectedCount: expected, generatedAt: new Date().toISOString(), models: [],
    missingOutputs: [...sources.keys()].filter(f => !outputs.has(f)), extraOutputs: [...outputs.keys()].filter(f => !sources.has(f)),
    missingReports: [...recipes].filter(f => !reports.has(f)), extraReports: [...reports.keys()].filter(f => !recipes.has(f)), failures: [] };
  if (!sources.size || (expected !== null && sources.size !== expected)) result.failures.push('Source inventory is empty or differs from expected count');
  for (const file of [...sources.keys()].sort()) {
    const recipePath = reports.get(file.replaceAll('/', '__') + '.json');
    if (!outputs.has(file) || !recipePath) continue;
    let model;
    try { model = validateModel(file, readFileSync(sources.get(file)), readFileSync(outputs.get(file)), JSON.parse(readFileSync(recipePath, 'utf8'))); }
    catch (error) { model = { file, ok: false, failures: [error.message], clips: [] }; }
    result.models.push(model); console.log(`${model.ok ? 'PASS' : 'FAIL'} ${file}: ${model.ok ? model.clips.length + ' clips' : JSON.stringify(model.failures ?? model.clips.filter(c => !c.ok))}`);
  }
  const clips = result.models.flatMap(m => m.clips), passed = result.models.filter(m => m.ok).length;
  result.totals = { sourceModels: sources.size, outputModels: outputs.size, recipeReports: reports.size, checkedModels: result.models.length, passedModels: passed, failedModels: result.models.length - passed, clips: clips.length, passedClips: clips.filter(c => c.ok).length, channels: clips.reduce((s, c) => s + c.channelCount, 0), sampledVertices: result.models.reduce((s, m) => s + (m.sampledVertices ?? 0), 0) };
  result.ok = !result.failures.length && !result.missingOutputs.length && !result.extraOutputs.length && !result.missingReports.length && !result.extraReports.length && passed === sources.size;
  writeFileSync(reportPath, JSON.stringify(result, null, 2) + '\n');
  console.log(`${result.ok ? 'MODEL_ACTION_VALIDATION_OK' : 'MODEL_ACTION_VALIDATION_FAILED'} ${JSON.stringify(result.totals)}`); process.exitCode = result.ok ? 0 : 1;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try { main(); } catch (error) { console.error('MODEL_ACTION_VALIDATION_FAILED ' + error.message); process.exitCode = 1; }
}
