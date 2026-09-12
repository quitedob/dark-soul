#!/usr/bin/env node
// Exercise the real sync transaction using copied fixtures; never write game assets.
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { existsSync, lstatSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, realpathSync, rmSync, unlinkSync, writeFileSync } from 'node:fs';
import { basename, dirname, isAbsolute, join, relative, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { apply, partDefinitions, prepare } from './sync_model_actions.mjs';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const WORK = 'build/glb-models/animation';
const FILE = 'weapons/templateweapons.glb';
const RECIPE = `${WORK}/reports/${FILE.replaceAll('/', '__')}.json`;
const SOURCE = `${WORK}/originals/${FILE}`;
const STAGED = `${WORK}/staged/${FILE}`;
const DESTINATION = `game/assets/models/${FILE}`;
const MANIFEST = 'game/resources/model_actions.json';
const sha256 = bytes => createHash('sha256').update(bytes).digest('hex');
const fixturePaths = [SOURCE, STAGED, `${WORK}/raw/${FILE}`, RECIPE,
  `build/glb-models/out/${FILE}`, `build/glb-models/rigging/originals/${FILE}`];
const fixtures = new Map(fixturePaths.map(file => [file, readFileSync(join(ROOT, file))]));
const recipe = JSON.parse(fixtures.get(RECIPE));
const jsonBytes = value => Buffer.from(JSON.stringify(value, null, 2) + '\n');
let passed = 0;

function inside(parent, child) {
  const path = resolve(child), rel = relative(resolve(parent), path);
  assert(rel && rel !== '..' && !rel.startsWith('..' + sep) && !isAbsolute(rel), `Outside controlled directory: ${path}`);
  return path;
}

// Refuse symlink/junction ancestors both before creating fixtures and before cleanup.
function noLinks(path) {
  for (let current = resolve(path); ; current = dirname(current)) {
    if (existsSync(current)) assert(!lstatSync(current).isSymbolicLink(), `Linked test directory: ${current}`);
    if (dirname(current) === current) break;
  }
}

const testParent = inside(join(ROOT, WORK), join(ROOT, WORK, 'sync-contracts'));
noLinks(testParent);
mkdirSync(testParent, { recursive: true });
const runRoot = mkdtempSync(join(testParent, 'run-'));

function write(root, file, bytes) {
  const path = inside(root, join(root, file));
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, bytes);
}

function fixture(name, existingDestinations = true) {
  const root = inside(runRoot, join(runRoot, name));
  mkdirSync(root);
  for (const [file, bytes] of fixtures) write(root, file, bytes);
  if (existingDestinations) {
    write(root, DESTINATION, fixtures.get(SOURCE));
    write(root, MANIFEST, jsonBytes({ previous_manifest: true }));
  }
  return root;
}

function snapshot(root) {
  const entries = {};
  function visit(dir) {
    for (const entry of readdirSync(dir, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))) {
      assert(!entry.isSymbolicLink(), 'Unexpected link in test tree');
      const path = join(dir, entry.name), file = relative(root, path).replaceAll('\\', '/');
      if (entry.isDirectory()) { entries[file + '/'] = null; visit(path); }
      else entries[file] = sha256(readFileSync(path));
    }
  }
  visit(root);
  return entries;
}

function test(name, run) {
  run();
  passed++;
  console.log(`PASS ${name}`);
}

function rejectWithoutMutation(root, action, expected) {
  const before = snapshot(root);
  assert.throws(action, expected);
  assert.deepEqual(snapshot(root), before, 'Rejected transaction mutated files or created evidence directories');
}

function document(bytes) {
  return JSON.parse(bytes.subarray(20, 20 + bytes.readUInt32LE(12)).toString('utf8'));
}

function changeAnimations(bytes, change) {
  const doc = document(bytes);
  change(doc.animations);
  const data = Buffer.from(JSON.stringify(doc));
  const json = Buffer.alloc(Math.ceil(data.length / 4) * 4, 0x20);
  data.copy(json);
  const remaining = bytes.subarray(20 + bytes.readUInt32LE(12));
  const header = Buffer.from(bytes.subarray(0, 20));
  header.writeUInt32LE(20 + json.length + remaining.length, 8);
  header.writeUInt32LE(json.length, 12);
  return Buffer.concat([header, json, remaining]);
}

try {
  test('nested original group transforms, synthetic groups, and repeated skin joints', () => {
    const original = { nodes: [
      { translation: [10, 20, 30], rotation: [0, 0, Math.SQRT1_2, Math.SQRT1_2], scale: [2, 3, 4], children: [1] },
      { matrix: [1, 0, 0, 0, 0, 2, 0, 0, 0, 0, 3, 0, 4, 5, 6, 1], children: [2] },
      { name: 'Sword', translation: [1, 2, 3], scale: [.5, 2, 1] },
    ] };
    const animated = { nodes: [{ name: 'part.Sword', translation: [99, 99, 99] }, { name: 'part.base.001' }, { name: 'spine' }],
      skins: [{ joints: [0, 1, 2] }, { joints: [0] }] };
    const parts = partDefinitions(original, animated);
    assert.deepEqual(Object.keys(parts), ['Sword']);
    assert.equal(parts.Sword.bone, 'part.Sword');
    // Analytic result of root TRS * intermediate matrix * Sword TRS, column major.
    const expected = [0, 1, 0, 0, -12, 0, 0, 0, 0, 0, 12, 0, -17, 30, 90, 1];
    parts.Sword.transform.forEach((value, i) => assert(Math.abs(value - expected[i]) < 1e-10, `Transform component ${i}`));
    const ambiguous = structuredClone(original);
    ambiguous.nodes.push({ name: 'Sword' });
    assert.throws(() => partDefinitions(ambiguous, animated), /Ambiguous original part: Sword/);
    const duplicate = structuredClone(animated);
    duplicate.nodes.push({ name: 'part.Sword' });
    duplicate.skins[0].joints.push(3);
    assert.throws(() => partDefinitions(original, duplicate), /Duplicate part bone: Sword/);
    const cyclic = structuredClone(original);
    cyclic.nodes[2].children = [0];
    assert.throws(() => partDefinitions(cyclic, animated), /Cyclic source nodes/);
    const singular = structuredClone(original);
    singular.nodes[2].scale = [0, 1, 1];
    assert.throws(() => partDefinitions(singular, animated), /Invalid part anchor/);
  });

  test('prepare is read-only; apply preserves exact bytes, metadata, backups, and idempotence', () => {
    const root = fixture('install'), before = snapshot(root), plan = prepare(root, 1);
    assert.deepEqual(snapshot(root), before);
    assert.equal(plan.validation.length, 1);
    assert.equal(plan.validation[0].ok, true);
    const result = apply(plan);
    assert.equal(result.models, 1);
    assert.equal(result.clips, recipe.actions.length);
    assert.equal(result.changedFiles, 2);
    assert.deepEqual(readFileSync(join(root, DESTINATION)), fixtures.get(STAGED));
    const manifest = JSON.parse(readFileSync(join(root, MANIFEST)));
    assert.equal(manifest.version, 1);
    assert.equal(manifest.source, 'original_model_aware_keyframes');
    assert.equal(manifest.in_place, true);
    assert.deepEqual(Object.keys(manifest.models), [FILE]);
    const model = manifest.models[FILE];
    assert.equal(model.sha256, sha256(fixtures.get(STAGED)));
    assert.equal(model.source_sha256, sha256(fixtures.get(SOURCE)));
    assert.equal(model.family, recipe.family);
    assert.equal(model.default_action, 'idle');
    assert.equal(model.special_action, 'sword_slash');
    assert.deepEqual(model.actions, recipe.actions);
    for (const part of ['Sword', 'Shield']) {
      assert.equal(model.parts[part].bone, 'part.' + part);
      assert.equal(model.parts[part].transform.length, 16);
      assert(model.parts[part].transform.every(Number.isFinite));
    }
    const backup = dirname(result.evidence), record = JSON.parse(readFileSync(result.evidence));
    inside(join(root, WORK), backup);
    assert.equal(record.status, 'installed');
    assert.deepEqual(readFileSync(join(backup, DESTINATION)), fixtures.get(SOURCE));
    assert.deepEqual(readFileSync(join(backup, MANIFEST)), jsonBytes({ previous_manifest: true }));
    assert.deepEqual(JSON.parse(readFileSync(join(backup, 'validation.json'))), plan.validation);
    for (const entry of record.files) {
      assert.equal(entry.before_sha256, before[entry.file]);
      assert.equal(entry.sha256, sha256(readFileSync(join(root, entry.file))));
    }
    for (const [file, bytes] of fixtures) assert.deepEqual(readFileSync(join(root, file)), bytes);
    const installedBytes = [DESTINATION, MANIFEST].map(file => readFileSync(join(root, file)));
    assert.equal(apply(prepare(root, 1)).changedFiles, 0);
    [DESTINATION, MANIFEST].forEach((file, i) => assert.deepEqual(readFileSync(join(root, file)), installedBytes[i]));
  });

  test('initial installation records absent destinations without inventing backup bytes', () => {
    const root = fixture('new-install', false), result = apply(prepare(root, 1));
    assert.equal(result.changedFiles, 2);
    const record = JSON.parse(readFileSync(result.evidence));
    for (const entry of record.files) {
      assert.equal(entry.before_sha256, null);
      assert(!existsSync(join(dirname(result.evidence), entry.file)));
      assert.equal(entry.sha256, sha256(readFileSync(join(root, entry.file))));
    }
  });

  test('one-shot-only action library has no automatic default', () => {
    const root = fixture('no-loop'), oneShots = structuredClone(recipe);
    oneShots.actions = oneShots.actions.filter(action => !action.loop);
    write(root, RECIPE, jsonBytes(oneShots));
    write(root, STAGED, changeAnimations(fixtures.get(STAGED), animations => {
      for (let i = animations.length - 1; i >= 0; i--) if (animations[i].extras.loop) animations.splice(i, 1);
    }));
    const plan = prepare(root, 1);
    assert.equal(plan.manifest.models[FILE].default_action, '');
    assert.equal(plan.manifest.models[FILE].special_action, 'sword_slash');
    assert.deepEqual(plan.manifest.models[FILE].actions, oneShots.actions);
  });

  for (const [index, file] of [SOURCE, STAGED, RECIPE, `build/glb-models/out/${FILE}`, `build/glb-models/rigging/originals/${FILE}`].entries()) {
    test(`stale captured input rejects before mutation: ${file}`, () => {
      const root = fixture(`stale-input-${index}`), plan = prepare(root, 1);
      write(root, file, Buffer.concat([readFileSync(join(root, file)), Buffer.from('changed')]));
      rejectWithoutMutation(root, () => apply(plan), /Input changed:/);
    });
  }

  for (const [index, file] of [DESTINATION, MANIFEST].entries()) {
    test(`changed destination rejects before mutation: ${file}`, () => {
      const root = fixture(`changed-destination-${index}`), plan = prepare(root, 1);
      write(root, file, Buffer.from('user change'));
      rejectWithoutMutation(root, () => apply(plan), /Destination changed:/);
    });
  }

  test('destination created after preparation rejects before mutation', () => {
    const root = fixture('appeared-destination', false), plan = prepare(root, 1);
    write(root, MANIFEST, Buffer.from('user-created manifest'));
    rejectWithoutMutation(root, () => apply(plan), /Destination changed:/);
  });

  test('destination removed after preparation rejects before mutation', () => {
    const root = fixture('removed-destination'), plan = prepare(root, 1);
    unlinkSync(join(root, MANIFEST));
    rejectWithoutMutation(root, () => apply(plan), /Destination changed:/);
  });

  for (const [index, file] of [SOURCE, `${WORK}/raw/${FILE}`, STAGED, RECIPE].entries()) {
    test(`missing inventory rejects before mutation: ${file}`, () => {
      const root = fixture(`missing-${index}`);
      unlinkSync(join(root, file));
      rejectWithoutMutation(root, () => prepare(root, 1), /inventory/i);
    });
  }

  test('extra staged inventory rejects before mutation', () => {
    const root = fixture('extra-staged');
    write(root, `${WORK}/staged/extra.glb`, fixtures.get(STAGED));
    rejectWithoutMutation(root, () => prepare(root, 1), /Incomplete staged inventory/);
  });

  test('invalid action metadata rejects before mutation', () => {
    const root = fixture('invalid-validation'), invalid = structuredClone(recipe);
    invalid.actions[0].duration += 1;
    write(root, RECIPE, jsonBytes(invalid));
    rejectWithoutMutation(root, () => prepare(root, 1), /Action validation failed:.*Animation duration differs from recipe/);
  });

  test('corrupt staged GLB rejects before mutation', () => {
    const root = fixture('corrupt-staged');
    write(root, STAGED, fixtures.get(STAGED).subarray(0, 24));
    rejectWithoutMutation(root, () => prepare(root, 1), /Invalid GLB header\/length/);
  });

  test('changed published skin baseline rejects before mutation', () => {
    const root = fixture('baseline-mismatch');
    write(root, `build/glb-models/out/${FILE}`, Buffer.from('different baseline'));
    rejectWithoutMutation(root, () => prepare(root, 1), /Skin baseline changed:/);
  });
} finally {
  // Delete only this unique, resolved run directory; retain any other test runs.
  noLinks(runRoot);
  const realParent = realpathSync(testParent), realRun = realpathSync(runRoot);
  inside(realParent, realRun);
  assert.equal(dirname(realRun), realParent);
  assert(basename(realRun).startsWith('run-'));
  rmSync(realRun, { recursive: true });
}

console.log(`MODEL_ACTION_SYNC_CONTRACTS_OK ${passed} contracts`);
