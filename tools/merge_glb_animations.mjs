// Graft native Blender animation streams onto the unchanged published skin/geometry.
import { readFileSync, writeFileSync, mkdirSync, readdirSync } from 'node:fs';
import { resolve, dirname, join, relative as relativePath, isAbsolute, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { Matrix4, Quaternion, Vector3 } from '../build/glb-models/node_modules/three/build/three.module.js';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const WORK = join(ROOT, 'build/glb-models/animation');
const check = (value, message) => { if (!value) throw new Error(message); };
function read(path) {
  const bytes = readFileSync(path);
  check(bytes.toString('ascii', 0, 4) === 'glTF' && bytes.readUInt32LE(4) === 2 && bytes.readUInt32LE(8) === bytes.length, 'Bad GLB: ' + path);
  let json, bin;
  for (let offset = 12; offset < bytes.length;) {
    const length = bytes.readUInt32LE(offset), kind = bytes.readUInt32LE(offset + 4);
    const data = bytes.subarray(offset + 8, offset + 8 + length);
    check(data.length === length, 'Truncated chunk');
    if (kind === 0x4e4f534a) json = JSON.parse(data.toString('utf8'));
    else if (kind === 0x004e4942) bin = data;
    offset += 8 + length;
  }
  check(json && bin && json.buffers.length === 1, 'Expected self-contained GLB');
  return { json, bin };
}
function local(node) {
  return node.matrix ? new Matrix4().fromArray(node.matrix) : new Matrix4().compose(
    new Vector3().fromArray(node.translation ?? [0, 0, 0]), new Quaternion().fromArray(node.rotation ?? [0, 0, 0, 1]),
    new Vector3().fromArray(node.scale ?? [1, 1, 1]));
}
function skeleton(doc) {
  const joints = new Set(doc.skins.flatMap(s => s.joints)), byName = new Map(), parents = new Map();
  doc.nodes.forEach((n, i) => (n.children ?? []).forEach(c => parents.set(c, i)));
  const world = i => parents.has(i) ? world(parents.get(i)).multiply(local(doc.nodes[i])) : local(doc.nodes[i]);
  for (const index of joints) {
    const name = doc.nodes[index].name;
    check(name && !byName.has(name), 'Ambiguous joint name: ' + name);
    byName.set(name, { index, local: local(doc.nodes[index]), world: world(index) });
  }
  return byName;
}
function equalMatrix(a, b) { return a.elements.every((v, i) => Math.abs(v - b.elements[i]) < 2e-5); }

export function merge(relative) {
  const checked = relativePath(join(WORK, 'originals'), resolve(WORK, 'originals', relative));
  check(checked !== '..' && !checked.startsWith('..' + sep) && !isAbsolute(checked), 'Unsafe model path');
  const base = read(join(WORK, 'originals', relative)), raw = read(join(WORK, 'raw', relative));
  const report = JSON.parse(readFileSync(join(WORK, 'reports', relative.replaceAll('/', '__') + '.json')));
  const original = skeleton(base.json), exported = skeleton(raw.json), nodeMap = new Map();
  for (const [name, joint] of exported) {
    const target = original.get(name);
    check(target && equalMatrix(joint.local, target.local) && equalMatrix(joint.world, target.world), 'Animation rest basis mismatch: ' + relative + ' / ' + name);
    nodeMap.set(joint.index, target.index);
  }
  check(raw.json.animations?.length === report.actions.length, 'Animation export count mismatch: ' + relative);
  const definitions = new Map(report.actions.map(a => [a.name, a]));
  const chunks = [base.bin];
  let length = base.bin.length;
  const accessorMap = new Map(), viewMap = new Map();
  function copyAccessor(index) {
    if (accessorMap.has(index)) return accessorMap.get(index);
    const accessor = structuredClone(raw.json.accessors[index]);
    check(accessor && !accessor.sparse, 'Unsupported animation accessor');
    if (!viewMap.has(accessor.bufferView)) {
      const view = structuredClone(raw.json.bufferViews[accessor.bufferView]);
      check(view.buffer === 0, 'External animation buffer');
      const data = raw.bin.subarray(view.byteOffset ?? 0, (view.byteOffset ?? 0) + view.byteLength);
      check(data.length === view.byteLength, 'Truncated animation stream');
      view.byteOffset = length;
      chunks.push(data);
      length += data.length;
      const padding = (4 - length % 4) % 4;
      if (padding) { chunks.push(Buffer.alloc(padding)); length += padding; }
      viewMap.set(accessor.bufferView, base.json.bufferViews.push(view) - 1);
    }
    accessor.bufferView = viewMap.get(accessor.bufferView);
    const dest = base.json.accessors.push(accessor) - 1;
    accessorMap.set(index, dest);
    return dest;
  }
  base.json.animations = raw.json.animations.map(source => {
    const animation = structuredClone(source), definition = definitions.get(source.name);
    check(definition, 'Unexpected animation name: ' + source.name);
    definitions.delete(source.name);
    for (const channel of animation.channels) {
      check(nodeMap.has(channel.target.node), 'Animation targets a non-joint node');
      check(['translation', 'rotation', 'scale'].includes(channel.target.path), 'Unsupported animation channel');
      channel.target.node = nodeMap.get(channel.target.node);
    }
    for (const sampler of animation.samplers) {
      sampler.input = copyAccessor(sampler.input);
      sampler.output = copyAccessor(sampler.output);
    }
    animation.extras = { loop: definition.loop, kind: definition.kind, events: definition.events,
      source: 'original_model_aware_keyframes', in_place: true };
    return animation;
  });
  check(definitions.size === 0, 'Missing animation exports');
  base.json.buffers[0].byteLength = length;
  const text = Buffer.from(JSON.stringify(base.json)), padding = (4 - text.length % 4) % 4;
  const json = Buffer.concat([text, Buffer.alloc(padding, 0x20)]), binary = Buffer.concat(chunks);
  const header = Buffer.alloc(20), binHeader = Buffer.alloc(8);
  header.writeUInt32LE(0x46546c67); header.writeUInt32LE(2, 4); header.writeUInt32LE(28 + json.length + binary.length, 8);
  header.writeUInt32LE(json.length, 12); header.writeUInt32LE(0x4e4f534a, 16);
  binHeader.writeUInt32LE(binary.length); binHeader.writeUInt32LE(0x004e4942, 4);
  const dest = join(WORK, 'staged', relative);
  mkdirSync(dirname(dest), { recursive: true });
  writeFileSync(dest, Buffer.concat([header, json, binHeader, binary]));
  console.log('GLB_ACTIONS_MERGED', relative, base.json.animations.length);
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const files = process.argv.slice(2);
  check(files.length, 'Pass relative GLB paths');
  for (const relative of files) merge(relative);
}
