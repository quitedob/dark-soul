#!/usr/bin/env node
// Validate the complete local action library, then install it into Godot with backups.
import { readFileSync, writeFileSync, readdirSync, mkdirSync, existsSync, lstatSync, renameSync, unlinkSync } from 'node:fs';
import { resolve, join, dirname, relative, isAbsolute, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash, randomUUID } from 'node:crypto';
import { Matrix4, Quaternion, Vector3 } from '../build/glb-models/node_modules/three/build/three.module.js';
import { validateModel } from './validate_model_actions.mjs';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const check = (ok, message) => { if (!ok) throw new Error(message); };
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
const jsonBytes = data => Buffer.from(JSON.stringify(data, null, 2) + '\n');

function safePath(root, name) {
  const path = resolve(root, name), rel = relative(root, path);
  check(rel && rel !== '..' && !rel.startsWith('..' + sep) && !isAbsolute(rel), 'Path escapes root: ' + name);
  for (let current = path; ; current = dirname(current)) {
    if (existsSync(current)) check(!lstatSync(current).isSymbolicLink(), 'Symlink path: ' + current);
    if (dirname(current) === current) break;
  }
  return path;
}

function inventory(root, suffix, dir = root, found = []) {
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    check(!entry.isSymbolicLink(), 'Symlink in inventory');
    const path = join(dir, entry.name);
    if (entry.isDirectory()) inventory(root, suffix, path, found);
    else if (entry.isFile() && entry.name.endsWith(suffix)) found.push(relative(root, path).replaceAll('\\', '/'));
  }
  return found.sort();
}

function document(bytes) {
  check(bytes.length >= 28 && bytes.readUInt32LE(0) === 0x46546c67 && bytes.readUInt32LE(4) === 2 && bytes.readUInt32LE(8) === bytes.length, 'Invalid GLB');
  const length = bytes.readUInt32LE(12);
  check(bytes.readUInt32LE(16) === 0x4e4f534a && length + 20 <= bytes.length, 'Invalid GLB JSON');
  return JSON.parse(bytes.subarray(20, 20 + length).toString('utf8'));
}

// Original group transforms define the existing game grip, not the new bone head.
export function partDefinitions(original, animated) {
  const parents = new Map();
  original.nodes.forEach((node, index) => (node.children ?? []).forEach(child => {
    check(!parents.has(child), 'Multiple node parents'); parents.set(child, index);
  }));
  function world(index, seen = new Set()) {
    check(!seen.has(index), 'Cyclic source nodes'); seen.add(index);
    const node = original.nodes[index]; check(node, 'Missing source node');
    const local = node.matrix ? new Matrix4().fromArray(node.matrix) : new Matrix4().compose(
      new Vector3().fromArray(node.translation ?? [0, 0, 0]),
      new Quaternion().fromArray(node.rotation ?? [0, 0, 0, 1]).normalize(),
      new Vector3().fromArray(node.scale ?? [1, 1, 1]));
    return parents.has(index) ? world(parents.get(index), seen).multiply(local) : local;
  }
  const parts = {};
  for (const index of new Set(animated.skins.flatMap(skin => skin.joints))) {
    const bone = animated.nodes[index].name;
    if (!bone?.startsWith('part.')) continue;
    const part = bone.slice(5), matches = original.nodes.flatMap((node, i) => node.name === part ? [i] : []);
    // Some helper branches are synthetic (for example part.base.001), with no
    // corresponding author group. They are not extractable runtime parts.
    if (matches.length === 0) continue;
    check(matches.length === 1, 'Ambiguous original part: ' + part);
    const anchor = world(matches[0]);
    check(anchor.elements.every(Number.isFinite) && Math.abs(anchor.determinant()) > 1e-8, 'Invalid part anchor');
    check(!parts[part], 'Duplicate part bone: ' + part);
    parts[part] = { bone, transform: anchor.toArray() };
  }
  return parts;
}

export function prepare(root = ROOT, expectedCount = 86) {
  const work = join(root, 'build/glb-models/animation');
  const files = inventory(join(work, 'originals'), '.glb');
  check(files.length === expectedCount, 'Unexpected source inventory');
  for (const folder of ['raw', 'staged']) check(JSON.stringify(inventory(join(work, folder), '.glb')) === JSON.stringify(files), 'Incomplete ' + folder + ' inventory');
  check(JSON.stringify(inventory(join(work, 'reports'), '.json')) === JSON.stringify(files.map(file => file.replaceAll('/', '__') + '.json').sort()), 'Recipe inventory mismatch');
  const manifest = { version: 1, source: 'original_model_aware_keyframes', in_place: true, models: {} };
  const writes = [], inputs = [], validation = [];
  function capture(path) { const bytes = readFileSync(path); inputs.push({ path, sha256: hash(bytes) }); return bytes; }
  for (const file of files) {
    const source = capture(safePath(join(work, 'originals'), file));
    const output = capture(safePath(join(work, 'staged'), file));
    const published = capture(safePath(join(root, 'build/glb-models/out'), file));
    check(source.equals(published), 'Skin baseline changed: ' + file);
    const recipe = JSON.parse(capture(safePath(join(work, 'reports'), file.replaceAll('/', '__') + '.json')));
    const result = validateModel(file, source, output, recipe);
    check(result.ok, 'Action validation failed: ' + file + ' ' + JSON.stringify(result.clips.filter(clip => !clip.ok)));
    validation.push(result);
    const original = document(capture(safePath(join(root, 'build/glb-models/rigging/originals'), file)));
    const actions = recipe.actions;
    const idle = actions.find(action => action.name === 'idle' && action.loop) ?? actions.find(action => action.loop);
    const special = actions.find(action => action.kind === 'special') ?? actions.find(action => !action.loop);
    manifest.models[file] = { sha256: hash(output), source_sha256: hash(source), family: recipe.family,
      default_action: idle?.name ?? '', special_action: special?.name ?? '', actions,
      parts: partDefinitions(original, document(output)) };
    const destination = safePath(join(root, 'game/assets/models'), file);
    writes.push({ path: destination, bytes: output });
    // Keep self-contained textures lossless without extracting a second set of
    // PNGs beside each GLB. Preserve all other authored import options and UIDs.
    const importPath = destination + '.import';
    if (existsSync(importPath)) {
      const metadata = readFileSync(importPath, 'utf8');
      check(/^gltf\/embedded_image_handling=\d+\r?$/m.test(metadata), 'Missing glTF texture import setting: ' + file);
      writes.push({ path: importPath, bytes: Buffer.from(metadata.replace(/^gltf\/embedded_image_handling=\d+(\r?)$/m, 'gltf/embedded_image_handling=3$1')) });
    }
  }
  if (expectedCount === 86) for (const [file, parts] of Object.entries({
    'weapons/templateweapons.glb': ['Sword', 'Shield'],
    'weapons/02-XingTian-Twin-Axes.glb': ['axe_left', 'axe_right'],
    'props/07-Pickups.glb': ['pillJar'],
  })) for (const part of parts) check(manifest.models[file]?.parts[part], 'Missing required runtime part: ' + part);
  writes.push({ path: safePath(root, 'game/resources/model_actions.json'), bytes: jsonBytes(manifest) });
  for (const item of writes) {
    if (existsSync(item.path)) check(lstatSync(item.path).isFile() && lstatSync(item.path).nlink === 1, 'Unsafe destination: ' + item.path);
    item.before = existsSync(item.path) ? readFileSync(item.path) : null;
  }
  return { root, work, manifest, writes, inputs, validation };
}

function replace(path, bytes) {
  mkdirSync(dirname(path), { recursive: true });
  const temporary = path + '.' + randomUUID() + '.tmp';
  try { writeFileSync(temporary, bytes, { flag: 'wx' }); renameSync(temporary, path); }
  finally { if (existsSync(temporary)) unlinkSync(temporary); }
}

export function apply(plan) {
  // Recheck all captured inputs/destinations before the first replacement.
  for (const input of plan.inputs) check(hash(readFileSync(input.path)) === input.sha256, 'Input changed: ' + input.path);
  for (const item of plan.writes) {
    safePath(plan.root, relative(plan.root, item.path));
    const current = existsSync(item.path) ? readFileSync(item.path) : null;
    check(item.before === null ? current === null : current?.equals(item.before), 'Destination changed: ' + item.path);
  }
  const backup = safePath(plan.work, 'runtime-sync-' + new Date().toISOString().replaceAll(/[:.]/g, '-') + '-' + randomUUID());
  mkdirSync(backup);
  const changes = plan.writes.filter(item => !item.before?.equals(item.bytes));
  const record = { status: 'prepared', models: Object.keys(plan.manifest.models).length,
    clips: Object.values(plan.manifest.models).reduce((sum, model) => sum + model.actions.length, 0),
    inputs: plan.inputs, files: plan.writes.map(item => ({ file: relative(plan.root, item.path).replaceAll('\\', '/'),
      before_sha256: item.before === null ? null : hash(item.before), sha256: hash(item.bytes) })) };
  for (const item of changes) if (item.before !== null) {
    const path = safePath(backup, relative(plan.root, item.path));
    mkdirSync(dirname(path), { recursive: true }); writeFileSync(path, item.before, { flag: 'wx' });
  }
  writeFileSync(join(backup, 'validation.json'), jsonBytes(plan.validation), { flag: 'wx' });
  writeFileSync(join(backup, 'sync.json'), jsonBytes(record), { flag: 'wx' });
  const installed = [];
  try {
    for (const item of changes) { replace(item.path, item.bytes); installed.push(item); }
    for (const item of plan.writes) check(hash(readFileSync(item.path)) === hash(item.bytes), 'Installed hash mismatch');
    record.status = 'installed';
  } catch (error) {
    const rollbackErrors = [];
    for (const item of installed.reverse()) {
      try { if (item.before === null) unlinkSync(item.path); else replace(item.path, item.before); }
      catch (rollbackError) { rollbackErrors.push(String(rollbackError)); }
    }
    record.status = rollbackErrors.length ? 'rollback_failed' : 'rolled_back';
    record.error = String(error); record.rollback_errors = rollbackErrors;
    writeFileSync(join(backup, 'sync.json'), jsonBytes(record));
    throw error;
  }
  writeFileSync(join(backup, 'sync.json'), jsonBytes(record));
  return { models: record.models, clips: record.clips, changedFiles: changes.length, evidence: join(backup, 'sync.json') };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    check(process.argv.length === 3 && ['--check', '--apply'].includes(process.argv[2]), 'Usage: node tools/sync_model_actions.mjs --check|--apply');
    const plan = prepare();
    if (process.argv[2] === '--apply') console.log('MODEL_ACTION_SYNC_OK', JSON.stringify(apply(plan)));
    else console.log('MODEL_ACTION_SYNC_READY', JSON.stringify({ models: Object.keys(plan.manifest.models).length,
      clips: plan.validation.reduce((sum, model) => sum + model.clips.length, 0) }));
  } catch (error) { console.error('MODEL_ACTION_SYNC_FAILED', error.message); process.exitCode = 1; }
}
