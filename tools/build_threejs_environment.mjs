#!/usr/bin/env node
/** Reproducible Y-up metre-scale architecture for the five story chapters.
 * Run from any directory: node tools/build_threejs_environment.mjs
 * Dependency: npm --prefix tools/threejs install (Three.js pinned at 0.185.1).
 * Existing build/glb-models/node_modules/three is a supported local fallback.
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { createHash } from 'node:crypto';
import assert from 'node:assert/strict';
import { readGlb, readAccessor } from './threejs/glb_reader.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, '..');
const output = path.join(root, 'game/assets/environment/threejs_campaign');
const dependency = [path.join(here, 'threejs/node_modules/three'), path.join(root, 'build/glb-models/node_modules/three')]
  .find(candidate => fs.existsSync(path.join(candidate, 'package.json')));
assert.ok(dependency, 'Run npm --prefix tools/threejs install');
assert.equal(JSON.parse(fs.readFileSync(path.join(dependency, 'package.json'))).version, '0.185.1');
const T = await import(pathToFileURL(path.join(dependency, 'build/three.module.js')));
const { GLTFExporter } = await import(pathToFileURL(path.join(dependency, 'examples/jsm/exporters/GLTFExporter.js')));
const { mergeGeometries, mergeVertices } = await import(pathToFileURL(path.join(dependency, 'examples/jsm/utils/BufferGeometryUtils.js')));
const { ConvexGeometry } = await import(pathToFileURL(path.join(dependency, 'examples/jsm/geometries/ConvexGeometry.js')));

globalThis.FileReader = class {
  readAsArrayBuffer(blob) {
    blob.arrayBuffer().then(buffer => { this.result = buffer; this.onloadend?.({ target: this }); });
  }
};

const hash = value => createHash('sha256').update(value).digest('hex');
const TAU = Math.PI * 2;
const themes = {
  spirit_ruins: { stone: '#49564e', pale: '#6b7566', dark: '#26332f', metal: '#857044', roof: '#28544f', organic: '#43543b', glow: '#60b5a8', accent: '#614333', story: 'Abandoned ancestral shrine: eroded prayer tablets, fluted stone, bronze temple eaves and climbing roots.' },
  blood_iron: { stone: '#59483d', pale: '#82705b', dark: '#292c2c', metal: '#967350', roof: '#393b3a', organic: '#654533', glow: '#ef813b', accent: '#6f2922', story: 'Iron Howl Pass: massive riveted fortress, firing slits, furnace vents, battered crenellations and torn red standards.' },
  jade_veil: { stone: '#697b68', pale: '#a3b39a', dark: '#294b42', metal: '#a29354', roof: '#397768', organic: '#3d5944', glow: '#9ccdb0', accent: '#a38049', story: 'Illusion garden: elegant moon openings, twisted exposed roots, jade tile eaves and amber votive cages.' },
  celestial_fall: { stone: '#788276', pale: '#959c87', dark: '#444f50', metal: '#a08b53', roof: '#496762', organic: '#697d75', glow: '#a1d1d6', accent: '#947e50', story: 'Falling immortal city: weathered grey-green sanctuaries with worn gold, orbital instruments, broken suspended spires and fractured astral masonry.' },
  ember_abyss: { stone: '#37373b', pale: '#55545a', dark: '#242429', metal: '#a56e4f', roof: '#403838', organic: '#58413c', glow: '#e98344', accent: '#92573c', story: 'Broken Furnace core: charred basalt, copper binding ribs, forged suspension chains, restrained ember fissures.' },
};
const partNames = ['Floor', 'Bridge', 'Rail', 'Column', 'Gate', 'Landmark', 'Rock', 'ArenaCover', 'Wall', 'Arcade', 'Watchtower', 'Lantern', 'Roof'];

function randomFor(seed) {
  let state = seed >>> 0;
  return () => { state = (1664525 * state + 1013904223) >>> 0; return state / 4294967296; };
}
function materials(theme) {
  const result = {};
  for (const key of ['stone', 'pale', 'dark', 'metal', 'roof', 'organic', 'glow', 'accent']) {
    const opts = { name: `${theme}_${key}`, color: themes[theme][key], roughness: key === 'metal' ? .55 : .91, metalness: key === 'metal' ? .68 : .03 };
    if (key === 'glow') Object.assign(opts, { emissive: themes[theme][key], emissiveIntensity: .35, roughness: .72 });
    result[key] = new T.MeshStandardMaterial(opts);
  }
  return result;
}

function chamferBox(size, radius) {
  // 44 triangles: broad flat faces, twelve bevel strips and eight corner cuts.
  // RoundedBoxGeometry spends 108 triangles on this same distant masonry block.
  const points = [], half = size.map(n => n * .5);
  for (let axis = 0; axis < 3; axis++) for (const x of [-1, 1]) for (const y of [-1, 1]) for (const z of [-1, 1]) {
    const signs = [x, y, z];
    points.push(new T.Vector3(...half.map((h, i) => signs[i] * (h - (i === axis ? 0 : radius)))));
  }
  return new ConvexGeometry(points);
}

class Part {
  constructor(name, theme, mats, seed = 703) { this.name = name; this.theme = theme; this.mats = mats; this.entries = new Map(); this.rng = randomFor(seed); }
  add(geometry, material = 'stone', at = [0, 0, 0], rotation = [0, 0, 0], scale = [1, 1, 1]) {
    const matrix = new T.Matrix4().compose(new T.Vector3(...at), new T.Quaternion().setFromEuler(new T.Euler(...rotation)), new T.Vector3(...scale));
    geometry.applyMatrix4(matrix);
    if (geometry.index) { const indexed = geometry; geometry = geometry.toNonIndexed(); indexed.dispose(); }
    // Every merged surface carries the same portable attribute contract.
    for (const name of Object.keys(geometry.attributes)) if (!['position', 'normal', 'uv'].includes(name)) geometry.deleteAttribute(name);
    if (!geometry.attributes.normal) geometry.computeVertexNormals();
    if (!geometry.attributes.uv) geometry.setAttribute('uv', new T.Float32BufferAttribute(new Float32Array(geometry.attributes.position.count * 2), 2));
    if (!this.entries.has(material)) this.entries.set(material, []);
    this.entries.get(material).push(geometry);
  }
  box(at, size, mat = 'stone', bevel = .04, rot = [0, 0, 0]) {
    this.add(bevel > 0 ? chamferBox(size, Math.min(bevel, ...size.map(n => n / 3))) : new T.BoxGeometry(...size), mat, at, rot);
  }
  cylinder(at, bottom, top, height, mat = 'stone', sides = 12, rot = [0, 0, 0]) {
    this.add(new T.CylinderGeometry(top, bottom, height, sides), mat, at, rot);
  }
  lathe(profile, mat = 'stone', at = [0, 0, 0], sides = 16) {
    this.add(new T.LatheGeometry(profile.map(([y, r]) => new T.Vector2(r, y)), sides), mat, at);
  }
  beam(a, b, radius, mat = 'metal', sides = 6) {
    const begin = new T.Vector3(...a), end = new T.Vector3(...b), vector = end.clone().sub(begin);
    const mesh = new T.CylinderGeometry(radius, radius, vector.length(), sides);
    mesh.applyQuaternion(new T.Quaternion().setFromUnitVectors(new T.Vector3(0, 1, 0), vector.normalize()));
    this.add(mesh, mat, begin.add(end).multiplyScalar(.5).toArray());
  }
  ring(at, radius, tube = .05, mat = 'metal', rotation = [Math.PI / 2, 0, 0], arc = TAU) {
    this.add(new T.TorusGeometry(radius, tube, radius < .2 ? 4 : 5, Math.max(8, Math.round((radius < .2 ? 10 : 24) * arc / TAU)), arc), mat, at, rotation);
  }
  curve(points, radius = .08, mat = 'organic', segments = 18) {
    const spline = new T.CatmullRomCurve3(points.map(p => new T.Vector3(...p)));
    this.add(new T.TubeGeometry(spline, segments, radius, 6, false), mat);
  }
  absorb(part, at = [0, 0, 0], scale = [1, 1, 1], yaw = 0) {
    for (const [mat, geometries] of part.entries) for (const geometry of geometries) this.add(geometry.clone(), mat, at, [0, yaw, 0], scale);
  }
  fit(width, height, depth, bottom = 0) {
    const bounds = new T.Box3();
    for (const list of this.entries.values()) for (const g of list) { g.computeBoundingBox(); bounds.union(g.boundingBox); }
    const size = bounds.getSize(new T.Vector3()), center = bounds.getCenter(new T.Vector3());
    const scale = new T.Vector3(width ? width / size.x : 1, height ? height / size.y : 1, depth ? depth / size.z : 1);
    const matrix = new T.Matrix4().makeScale(...scale.toArray());
    matrix.setPosition(-center.x * scale.x, bottom - bounds.min.y * scale.y, -center.z * scale.z);
    for (const list of this.entries.values()) for (const g of list) g.applyMatrix4(matrix);
  }
  finish() {
    const group = new T.Group(); group.name = this.name;
    group.userData = { units: 'metres', origin: 'identity Y-up', chapter: this.theme };
    for (const [mat, list] of this.entries) {
      const merged = mergeGeometries(list, false);
      const geometry = mergeVertices(merged, .000001); merged.dispose();
      assert.ok(geometry, `${this.theme}/${this.name}/${mat} merged`);
      const mesh = new T.Mesh(geometry, this.mats[mat]); mesh.name = `${this.name}_${mat}`; group.add(mesh);
    }
    assert.ok(group.children.length <= (['Landmark', 'Watchtower', 'Rock'].includes(this.name) ? 11 : 7), 'Part draw budget');
    return group;
  }
}

function floor(p, bridge = false) {
  p.box([0, bridge ? -.08 : -.41, 0], [6, bridge ? .12 : .38, 6], 'dark', .025);
  if (bridge) {
    for (let row = 0; row < 12; row++) p.box([0, .032, -2.75 + row * .5], [5.98, .176, .468], p.theme === 'blood_iron' ? 'roof' : 'stone', .014);
    for (const x of [-2.71, 2.71]) for (let z = -2.75; z <= 2.75; z += .5) p.cylinder([x, .128, z], .055, .055, .024, 'metal', 6);
    p.fit(6, .28, 6, -.14); return;
  }
  // The art surface is recessed below Y=0; thin inlays alone meet the walking datum.
  for (let row = 0; row < 4; row++) for (let col = 0; col < 4; col++)
    p.box([-2.25 + col * 1.5, -.13, -2.25 + row * 1.5], [1.465, .23, 1.465], (row + col * 2) % 5 === 0 ? 'pale' : 'stone', .032);
  for (const side of [-1, 1]) p.box([side * 2.91, -.008, 0], [.045, .016, 5.84], 'metal', 0);
  if (['spirit_ruins', 'jade_veil', 'celestial_fall'].includes(p.theme)) {
    p.ring([0, -.01, 0], 1.3, .01, 'metal');
    for (let i = 0; i < 8; i++) { const a = i * TAU / 8; p.box([Math.cos(a) * 1.65, -.008, Math.sin(a) * 1.65], [.35, .016, .045], 'metal', 0, [0, -a, 0]); }
  } else if (p.theme === 'ember_abyss') {
    for (const end of [[-2.4, -.01, -2.1], [2.6, -.01, 1.4], [-1, -.01, 2.7]]) p.beam([.3, -.01, -.4], end, .01, 'glow', 6);
  } else for (const z of [-2.9, 2.9]) p.box([0, -.008, z], [5.8, .016, .06], 'metal', 0);
  p.fit(6, .6, 6, -.6);
}

function column(p, h = 6) {
  const iron = p.theme === 'blood_iron', abyss = p.theme === 'ember_abyss';
  if (iron) {
    p.box([0, .2, 0], [1.65, .4, 1.65], 'dark', .08);
    for (let row = 0; row < 8; row++) p.box([0, .7 + row * .62, 0], [1.1, .58, 1.1], row % 3 ? 'stone' : 'pale', .05);
    for (const y of [.72, 2.45, 4.6]) {
      p.box([0, y, 0], [1.18, .14, 1.18], 'dark', .018);
      for (const x of [-.4, .4]) p.cylinder([x, y, -.606], .063, .063, .046, 'metal', 6, [Math.PI / 2, 0, 0]);
    }
    p.box([0, 5.68, 0], [1.8, .64, 1.8], 'dark', .065);
  } else {
    p.lathe([[0, .92], [.18, .94], [.36, .75], [.55, .6], [4.9, abyss ? .36 : .48], [5.03, .61], [5.25, .72], [5.45, .88], [5.75, .9], [6, .65]], 'stone', [0, 0, 0], abyss ? 7 : 18);
    for (let i = 0; i < (abyss ? 7 : 12); i++) {
      const a = i * TAU / (abyss ? 7 : 12), x = Math.cos(a), z = Math.sin(a);
      p.beam([x * .56, .65, z * .56], [x * .49, 4.88, z * .49], abyss ? .035 : .045, abyss ? 'metal' : 'pale');
    }
    for (const y of [.52, 1.1, 4.6, 5.35]) p.ring([0, y, 0], y > 5 ? .77 : .565, .047, 'metal');
    if (p.theme === 'jade_veil') p.curve([[.55, .4, 0], [-.2, 1.6, .57], [-.56, 3.1, -.1], [.25, 4.5, -.52], [.48, 5, .2]], .075);
    if (p.theme === 'celestial_fall') p.ring([0, 5.1, 0], .8, .035, 'metal', [.35, .2, 0], Math.PI * 1.65);
  }
  if (h !== 6) p.fit(null, h, null);
}

function roof(p) {
  const iron = p.theme === 'blood_iron', abyss = p.theme === 'ember_abyss';
  if (iron) {
    p.box([0, 5.2, 0], [6, .4, 6], 'dark', .06);
    for (const side of [-1, 1]) for (let i = 0; i < 7; i++) {
      p.box([side * 2.75, 6, -2.6 + i * .87], [.5, 1.45, .54], 'stone', .03);
      p.box([-2.6 + i * .87, 6, side * 2.75], [.54, 1.45, .5], 'stone', .03);
    }
    for (const x of [-1.7, 1.7]) { p.box([x, 6.45, .7], [1.2, 2.35, 1.25], 'stone', .07); p.box([x, 7.8, .7], [1.55, .4, 1.55], 'metal', .045); }
    for (const x of [-1.7, 1.7]) for (let i = 0; i < 4; i++) p.box([x - .4 + i * .27, 7.15, -.01], [.075, .8, .07], 'dark', 0);
  } else if (abyss) {
    for (let i = -3; i <= 3; i++) {
      const x = i * .84, top = 8 - Math.abs(i) * .36;
      p.curve([[x, 5, -2.9], [x * .83, top - .65, -1.4], [x * .75, top, 0], [x * .83, top - .65, 1.4], [x, 5, 2.9]], .13, 'metal');
      if (i !== 0) p.curve([[x, 5.25, -2.7], [x * .85, top - .45, -1.15], [x * .77, top - .12, 0], [x, 5.25, 2.7]], .21, 'dark');
    }
    chain(p, [-2.5, 5.4, -2.55], [2.5, 5.4, -2.55], 17, .14);
  } else {
    // Curved hip roof, solid edge fascia, clay-tile seams and raised corner ribs.
    const n = 16, pos = [], idx = [];
    const height = (x, z) => { const t = Math.max(Math.abs(x), Math.abs(z)) / 3; return 5 + 3 * (1 - t) ** 2 + .5 * t ** 8; };
    for (let layer = 0; layer < 2; layer++) for (let z = 0; z <= n; z++) for (let x = 0; x <= n; x++) pos.push(-3 + x * 6 / n, height(-3 + x * 6 / n, -3 + z * 6 / n) - layer * .14, -3 + z * 6 / n);
    const area = (n + 1) ** 2;
    for (let layer = 0; layer < 2; layer++) for (let z = 0; z < n; z++) for (let x = 0; x < n; x++) {
      const a = layer * area + z * (n + 1) + x, b = a + 1, c = a + n + 1, d = c + 1;
      if (!layer) idx.push(a, c, b, b, c, d); else idx.push(a, b, c, b, d, c);
    }
    const edges = [];
    for (let i = 0; i <= n; i++) edges.push(i);
    for (let i = 1; i <= n; i++) edges.push(i * (n + 1) + n);
    for (let i = n - 1; i >= 0; i--) edges.push(n * (n + 1) + i);
    for (let i = n - 1; i >= 1; i--) edges.push(i * (n + 1));
    for (let i = 0; i < edges.length; i++) { const a = edges[i], b = edges[(i + 1) % edges.length]; idx.push(a, b, a + area, b, b + area, a + area); }
    const g = new T.BufferGeometry(); g.setAttribute('position', new T.Float32BufferAttribute(pos, 3)); g.setIndex(idx); g.computeVertexNormals(); p.add(g, 'roof');
    for (let s = -5; s <= 5; s++) for (const axis of [0, 1]) {
      const points = [];
      for (let i = 0; i <= 10; i++) { const a = -2.95 + i * 5.9 / 10, b = s * .54; points.push(axis ? [a, height(a, b) + .025, b] : [b, height(b, a) + .025, a]); }
      p.curve(points, .023, 'roof', 10);
    }
    for (const sx of [-1, 1]) for (const sz of [-1, 1]) {
      const points = []; for (let i = 0; i <= 10; i++) { const t = i * .285; points.push([sx * t, height(t, t) + .05, sz * t]); } p.curve(points, .055, 'metal');
    }
    p.lathe([[7.85, .22], [8.18, .19], [8.32, .3], [8.48, .08]], 'metal', [0, 0, 0], 10);
  }
  p.fit(6, 3, 6, 5);
}

function rail(p) {
  p.box([0, .09, 0], [6, .18, .46], 'stone', .022);
  for (const x of [-2.8, -.95, .95, 2.8]) {
    p.lathe([[0, .2], [.2, .21], [.32, .12], [1.14, .12], [1.27, .22], [1.4, .08]], 'stone', [x, 0, 0], 8);
  }
  if (p.theme === 'blood_iron') {
    for (let i = 0; i < 8; i++) { p.box([-2.6 + i * .75, .55, 0], [.7, .84, .39], 'stone', .025); p.box([-2.6 + i * .75, 1.23, 0], [.36, .34, .46], 'dark', .018); }
  } else if (p.theme === 'ember_abyss') {
    for (let i = 0; i < 11; i++) p.cylinder([-2.5 + i * .5, .7, 0], .15, .015, 1.35, 'stone', 5, [0, 0, i % 2 ? .15 : -.15]);
    chain(p, [-2.85, 1.05, 0], [2.85, 1.05, 0], 24, .105);
  } else {
    p.box([0, 1.16, 0], [6, .16, .32], 'metal', .03);
    p.box([0, .34, 0], [6, .12, .24], 'stone', .02);
    for (const x of [-1.86, 0, 1.86]) {
      if (p.theme === 'jade_veil') p.ring([x, .75, 0], .32, .055, 'roof', [0, 0, 0]);
      else for (const dx of [-.56, -.28, 0, .28, .56]) p.box([x + dx, .72, 0], [.07, .67, .14], 'pale', .012, [0, 0, p.theme === 'celestial_fall' ? .3 : 0]);
    }
  }
  p.fit(6, 1.4, .48);
}

function chain(p, a, b, count = 16, radius = .13) {
  for (let i = 0; i < count; i++) {
    const t = i / (count - 1), at = a.map((x, j) => x + (b[j] - x) * t);
    at[1] -= Math.sin(t * Math.PI) * .38;
    p.ring(at, radius, radius * .2, 'metal', i % 2 ? [Math.PI / 2, 0, .2] : [0, .15, 0]);
  }
}

function gate(p) {
  for (const x of [-4.8, 4.8]) { const c = new Part('support', p.theme, p.mats); column(c); p.absorb(c, [x, 0, 0]); }
  p.box([0, 6.12, 0], [12, .45, 1.55], 'dark', .08);
  const r = new Part('canopy', p.theme, p.mats); roof(r); p.absorb(r, [0, 2.87, 0], [1.99, .62, .56]);
  for (const x of [-3.6, 3.6]) p.box([x, 5.54, 0], [.3, 1.1, 1.2], 'metal', .04, [0, 0, x < 0 ? -.55 : .55]);
  p.box([0, 6.1, -.85], [2.2, .62, .17], 'metal', .025);
  for (let i = 0; i < 5; i++) p.box([-.74 + i * .37, 6.1, -.96], [.08, .35 - (i % 2) * .12, .025], 'pale', 0);
  if (p.theme === 'blood_iron') for (const x of [-3.15, 3.15]) banner(p, x, 5.8, -.45, .8, 2.05);
}

function arch(p, at = [0, 0, 0], radius = 2.4, thickness = .6, spring = 4, depth = 1, mat = 'stone') {
  const n = 20;
  for (let i = 0; i < n; i++) {
    const a = i * Math.PI / n + .009, b = (i + 1) * Math.PI / n - .009;
    const shape = new T.Shape();
    shape.moveTo(Math.cos(a) * radius, Math.sin(a) * radius);
    shape.lineTo(Math.cos(a) * (radius + thickness), Math.sin(a) * (radius + thickness));
    shape.lineTo(Math.cos(b) * (radius + thickness), Math.sin(b) * (radius + thickness));
    shape.lineTo(Math.cos(b) * radius, Math.sin(b) * radius); shape.closePath();
    p.add(new T.ExtrudeGeometry(shape, { depth, bevelEnabled: false, steps: 1 }), i % 4 ? mat : 'pale', [at[0], at[1] + spring, at[2] - depth / 2]);
  }
  for (const side of [-1, 1]) for (let row = 0; row < 8; row++) p.box([at[0] + side * (radius + thickness / 2), at[1] + (row + .5) * spring / 8, at[2]], [thickness, spring / 8 - .02, depth], mat, .025);
}

function arcade(p) {
  arch(p);
  for (const side of [-1, 1]) for (const y of [.22, 3.9]) p.box([side * 2.7, y, 0], [.58, .28, 1], 'metal', .018);
  if (p.theme === 'jade_veil') for (const side of [-1, 1]) p.curve([[side * 2.91, .15, .41], [side * 2.63, 2.3, .49], [side * 2.78, 4, .43], [side * 1.72, 6.35, .42]], .065);
  else if (p.theme === 'celestial_fall') p.ring([0, 6.5, -.48], .32, .035, 'metal', [0, 0, 0], Math.PI * 1.6);
  else if (p.theme === 'blood_iron') for (const side of [-1, 1]) for (let y = .65; y < 4; y += .65) p.cylinder([side * 2.72, y, -.49], .07, .07, .045, 'metal', 6, [Math.PI / 2, 0, 0]);
  else if (p.theme === 'ember_abyss') chain(p, [-2.8, 6.2, -.42], [2.8, 6.2, -.42], 24, .105);
  // Only depth and sub-centimetre base/top correction; X aperture stays 4.8m.
  p.fit(null, 7, 1);
}

function banner(p, x, top, z, w = 1, h = 3) {
  p.beam([x - w * .65, top, z], [x + w * .65, top, z], .045, 'metal');
  const s = new T.Shape(); s.moveTo(-w / 2, 0); s.lineTo(w / 2, 0); s.lineTo(w / 2, -h * .8); s.lineTo(w * .26, -h); s.lineTo(w * .1, -h * .88); s.lineTo(-w * .2, -h); s.lineTo(-w / 2, -h * .83); s.closePath();
  p.add(new T.ExtrudeGeometry(s, { depth: .035, bevelEnabled: false }), 'accent', [x, top - .08, z]);
  for (let i = 0; i < 3; i++) p.box([x, top - .5 - i * .27, z - .018], [w * (.65 - i * .1), .05, .02], 'metal', 0);
}

function wall(p) {
  p.box([0, 5, 0], [6, 10, .68], 'dark', .02);
  // Mortar courses, staggered blocks and vertical buttresses cast layered shadows.
  for (let row = 0; row < 15; row++) {
    const count = row % 2 ? 5 : 4, span = 6 / count;
    for (let col = 0; col < count; col++) p.box([-3 + span * (col + .5), (row + .5) * .64 + .06, 0], [span - .035, .60, .8], (col * 3 + row) % 7 === 0 ? 'pale' : 'stone', .035);
  }
  for (const x of [-2.67, 2.67]) {
    p.box([x, 3.9, 0], [.48, 7.8, 1.42], 'stone', .07);
    p.box([x, 8.05, 0], [.6, .48, 1.48], 'metal', .026);
  }
  p.box([0, 9.75, 0], [6, .5, 1.1], 'pale', .03);
  if (p.theme === 'blood_iron') {
    for (const x of [-1.65, 0, 1.65]) { p.box([x, 6.8, -.426], [.27, 1.7, .075], 'dark', .02); p.box([x, 6.8, -.472], [.65, .13, .06], 'dark', 0); }
    for (const y of [1.4, 4.7]) { p.box([0, y, -.455], [5.7, .14, .12], 'metal', .02); for (let x = -2.5; x <= 2.5; x += .5) p.cylinder([x, y, -.54], .045, .045, .05, 'metal', 6, [Math.PI / 2, 0, 0]); }
    banner(p, 0, 9.3, -.54, 1.25, 3.1);
  } else if (p.theme === 'ember_abyss') {
    for (let i = -2; i <= 2; i++) { p.curve([[i * 1.2, .1, -.57], [i * 1.06, 3.6, -.64], [i * 1.2 + .15, 6.4, -.57], [i * 1.2, 9.6, -.47]], .055, 'metal'); }
    chain(p, [-2.6, 8.8, -.56], [2.6, 8.8, -.56], 22, .14);
    p.ring([0, 4.3, -.53], 1.06, .045, 'glow', [0, 0, 0], Math.PI * 1.7);
  } else {
    p.box([0, 5.2, -.47], [2.95, 4.7, .17], 'dark', .06);
    for (const x of [-1.5, 1.5]) p.box([x, 5.2, -.57], [.15, 4.8, .17], 'metal', .03);
    if (p.theme === 'celestial_fall') {
      for (const radius of [.7, 1.12]) p.ring([0, 5.3, -.59], radius, .045, 'metal', [0, 0, radius], TAU * .87);
      for (let i = 0; i < 8; i++) { const a = i * TAU / 8; p.beam([Math.cos(a) * .3, 5.3 + Math.sin(a) * .3, -.59], [Math.cos(a) * 1.4, 5.3 + Math.sin(a) * 1.4, -.59], .025, 'pale'); }
    } else {
      // Eroded stelae: carved broken strokes, not fake readable text.
      for (let col = -1; col <= 1; col++) for (let row = 0; row < 7; row++) {
        p.box([col * .67, 3.7 + row * .46, -.576], [.28 - p.rng() * .1, .048, .027], 'pale', 0, [0, 0, .13]);
        if ((row + col) % 3) p.box([col * .67 + .03, 3.73 + row * .46, -.579], [.042, .2, .026], 'pale', 0);
      }
      p.curve([[-2.8, .1, -.53], [-2.55, 2.4, -.57], [-1.95, 4.7, -.55], [-2.35, 7.2, -.51], [-1.95, 9.2, -.5]], p.theme === 'jade_veil' ? .13 : .075);
    }
  }
}

function lantern(p) {
  p.lathe([[0, .35], [.1, .39], [.23, .27], [.8, .14], [.91, .3]], 'stone', [0, 0, 0], 8);
  p.box([0, 1.14, 0], [.42, .45, .42], 'glow', .05);
  for (const x of [-.24, .24]) for (const z of [-.24, .24]) p.beam([x, .91, z], [x, 1.42, z], .035, 'metal');
  if (p.theme === 'ember_abyss') {
    for (let i = 0; i < 6; i++) { const a = i * TAU / 6; p.beam([Math.cos(a) * .3, .88, Math.sin(a) * .3], [Math.cos(a) * .17, 1.7, Math.sin(a) * .17], .045, 'dark'); }
  } else { p.cylinder([0, 1.48, 0], .41, .17, .22, 'roof', p.theme === 'blood_iron' ? 4 : 8, [0, Math.PI / 4, 0]); p.cylinder([0, 1.66, 0], .12, .02, .2, 'metal', 8); }
  p.fit(.84, 1.85, .84);
}

function jagged(p, at, width, height, mat = 'stone', seed = 1) {
  const rng = randomFor(seed), sides = 9, rings = 6, pos = [], idx = [];
  for (let row = 0; row <= rings; row++) for (let i = 0; i < sides; i++) {
    const a = i * TAU / sides + row * .1, t = row / rings, r = width * (.45 + rng() * .2) * (1 - t * .92);
    pos.push(Math.cos(a) * r + Math.sin(t * 4) * width * .14, t * height + (row > 0 && row < rings ? rng() * height * .055 : 0), Math.sin(a) * r);
  }
  for (let row = 0; row < rings; row++) for (let i = 0; i < sides; i++) { const a = row * sides + i, b = row * sides + (i + 1) % sides; idx.push(a, b + sides, b, a, a + sides, b + sides); }
  for (let i = 1; i < sides - 1; i++) { idx.push(0, i, i + 1); idx.push(rings * sides, rings * sides + i + 1, rings * sides + i); }
  const g = new T.BufferGeometry(); g.setAttribute('position', new T.Float32BufferAttribute(pos, 3)); g.setIndex(idx); g.computeVertexNormals(); p.add(g, mat, at);
}

function stratifiedCliff(p, at, width, height, mat, seed) {
  const rng = randomFor(seed);
  // Persistent near-rectangular mass through the full height. Alternating
  // overhang/recession creates actual geological strata instead of cone teeth.
  const footprint = [[-.50, -.30], [-.33, -.50], [.25, -.45], [.50, -.19], [.42, .42], [.07, .50], [-.45, .39], [-.53, .06]];
  const layers = [[0, 1], [.15, 1.07], [.18, .97], [.36, .96], [.40, 1.04], [.59, .91], [.64, .98], [.78, .82], [.81, .92], [1, .71]];
  const positions = [], triangles = [], strata = [];
  for (let row = 0; row < layers.length; row++) {
    const [t, spread] = layers[row], shiftX = Math.sin(row * .8) * .065, shiftZ = Math.cos(row * .67) * .045;
    for (let i = 0; i < footprint.length; i++) {
      const [x, z] = footprint[i], edge = .95 + rng() * .1;
      const elevation = t * height + (row === 0 ? 0 : ((i + row * 2) % 3 - 1) * height * .023);
      positions.push((x * spread * edge + shiftX) * width, elevation, (z * spread * edge + shiftZ) * width);
    }
  }
  const sides = footprint.length;
  for (let row = 0; row < layers.length - 1; row++) for (let i = 0; i < sides; i++) {
    const a = row * sides + i, b = row * sides + (i + 1) % sides;
    const target = row === 1 || row === 5 ? strata : triangles;
    target.push(a, b + sides, b, a, a + sides, b + sides);
  }
  for (let i = 1; i < sides - 1; i++) {
    triangles.push(0, i, i + 1);
    const top = (layers.length - 1) * sides; triangles.push(top, top + i + 1, top + i);
  }
  for (const [indices, material] of [[triangles, mat], [strata, 'dark']]) {
    const vertices = []; for (const i of indices) vertices.push(...positions.slice(i * 3, i * 3 + 3));
    const g = new T.BufferGeometry(); g.setAttribute('position', new T.Float32BufferAttribute(vertices, 3));
    // Flat fractured facets are intentional; smoothing produced the old tooth silhouette.
    g.computeVertexNormals(); p.add(g, material, at);
  }
}

function rock(p) {
  // Unequal buttressed blocks have broad broken summits and intersecting talus.
  // Four geological masses replace six equally tapered vertical needles.
  stratifiedCliff(p, [-1.2, 0, -.7], 7.5, 20, 'stone', 721);
  stratifiedCliff(p, [2.3, 0, 1.3], 6, 14.5, 'stone', 885);
  stratifiedCliff(p, [-2.6, 0, 2.4], 5.5, 9.5, 'dark', 1027);
  stratifiedCliff(p, [2.5, 0, -2.4], 4.2, 7.4, 'pale', 1203);
  if (p.theme === 'jade_veil' || p.theme === 'spirit_ruins') for (let i = 0; i < (p.theme === 'jade_veil' ? 3 : 2); i++)
    p.curve([[-3 + i * 1.2, .1, -2.8], [-3.2 + i, 3, -3], [-2.9 + i * .8, 6, -2.7], [-2.4 + i * .7, 10, -2.55]], .12, 'organic', 12);
  if (p.theme === 'ember_abyss') for (let i = 0; i < 3; i++)
    p.beam([-3 + i * 2, 1, -2.8], [-2.6 + i * 1.5, 11, -2.55], .045, 'metal');
  p.fit(10, 20, 10);
}

function cover(p) {
  column(p, 3);
  if (p.theme === 'celestial_fall') p.ring([0, 2.4, 0], .76, .035, 'metal', [.4, 0, .3], Math.PI * 1.6);
  p.fit(2, 3, 2);
}

function tower(p) {
  p.box([0, .5, 0], [11.8, 1, 11.8], 'dark', .12);
  const iron = p.theme === 'blood_iron', abyss = p.theme === 'ember_abyss';
  if (abyss) {
    for (let i = 0; i < 8; i++) {
      const a = i * TAU / 8, x = Math.cos(a), z = Math.sin(a);
      jagged(p, [x * 3.2, .5, z * 3.2], 3, 22 + (i % 3) * 2, i % 2 ? 'dark' : 'stone', 434 + i);
      p.curve([[x * 5.1, 1, z * 5.1], [x * 3.5, 10, z * 3.5], [x * 1.9, 20, z * 1.9], [x * .75, 27.5, z * .75]], .22, 'metal');
    }
    for (const y of [5, 13, 21]) p.ring([0, y, 0], 4.9 - y * .085, .13, 'metal');
    for (let i = 0; i < 4; i++) { const a = i * Math.PI / 2; chain(p, [Math.cos(a) * 4.2, 24, Math.sin(a) * 4.2], [Math.cos(a + Math.PI / 2) * 4.2, 24, Math.sin(a + Math.PI / 2) * 4.2], 22, .22); }
    p.lathe([[3, .8], [17, .6], [25, .2], [28, .015]], 'glow', [0, 0, 0], 7);
  } else if (iron) {
    for (let row = 0; row < 25; row++) for (let side = 0; side < 4; side++) for (let col = 0; col < 6; col++) {
      const q = side * Math.PI / 2, along = -4.3 + col * 1.72;
      p.box([Math.cos(q) * along + Math.sin(q) * 4.75, .7 + row * .73, -Math.sin(q) * along + Math.cos(q) * 4.75], [1.67, .69, .82], (row + col) % 9 === 0 ? 'pale' : 'stone', .045, [0, q, 0]);
    }
    for (const y of [5.2, 12.5, 18.8]) p.box([0, y, 0], [10.8, .3, 10.8], 'metal', .05);
    for (const x of [-4.9, 4.9]) for (const z of [-4.9, 4.9]) p.box([x, 10.5, z], [1.05, 20, 1.05], 'dark', .045);
    const r = new Part('battlement', p.theme, p.mats); roof(r); p.absorb(r, [0, 9.8, 0], [1.9, 2.2, 1.9]);
    for (const x of [-2.5, 2.5]) { banner(p, x, 18, -5.23, 1.7, 7.4); p.box([x, 16, -5.24], [.35, 1.55, .1], 'dark', .01); }
  } else {
    for (let tier = 0; tier < 3; tier++) {
      const scale = 1 - tier * .2, base = 1 + tier * 7.5;
      p.box([0, base + .16, 0], [9.2 * scale, .32, 9.2 * scale], 'pale', .06);
      for (const x of [-3.2, 3.2]) for (const z of [-3.2, 3.2]) {
        const c = new Part('tower_column', p.theme, p.mats); column(c); p.absorb(c, [x * scale, base, z * scale], [.8 * scale, 1.03, .8 * scale]);
      }
      const r = new Part('tower_roof', p.theme, p.mats); roof(r); p.absorb(r, [0, base + 1.1, 0], [1.95 * scale, .75, 1.95 * scale]);
      for (const side of [-1, 1]) p.box([side * 3.2 * scale, base + 3, 0], [.2, 5.8, 6.4 * scale], 'dark', .03);
      if (tier === 0) for (let col = -2; col <= 2; col++) p.box([col * 1.15, 2.2, 3.2], [1.1, 2.35 + p.rng() * .5, .48], 'stone', .045);
    }
    p.lathe([[23.8, .35], [25, .2], [25.3, .56], [25.6, .22], [28, .01]], 'metal', [0, 0, 0], 12);
    if (p.theme === 'jade_veil') for (let i = 0; i < 4; i++) { const a = i * TAU / 4; p.curve([[Math.cos(a) * 5.3, .1, Math.sin(a) * 5.3], [Math.cos(a + .25) * 4, 7, Math.sin(a + .25) * 4], [Math.cos(a + .8) * 3, 14, Math.sin(a + .8) * 3], [Math.cos(a + .9) * 2, 21, Math.sin(a + .9) * 2]], .24, 'organic'); }
    if (p.theme === 'celestial_fall') {
      for (const y of [15, 21, 25]) p.ring([0, y, 0], 3.2 - (y - 15) * .17, .085, 'metal', [.3, -.2, y * .25], TAU * .81);
      for (let i = 0; i < 4; i++) { const a = i * TAU / 4; jagged(p, [Math.cos(a) * 4.7, 17 + i, Math.sin(a) * 4.7], .95, 4.8, 'pale', 840 + i); }
    }
  }
  p.fit(12, 28, 12);
}

function retainedLandmark(theme, mats) {
  // These established meshes already match the collision/navigation proxies.
  // Reconstruct into Three.js and export unchanged; ownership stays in the old kit.
  const source = path.join(root, 'game/assets/environment/campaign_kits', `${theme}.glb`);
  const glb = readGlb(source), part = new Part('Landmark', theme, mats);
  const nodes = glb.json.nodes, index = nodes.findIndex(n => n.name === 'Landmark'); assert.ok(index >= 0);
  function visit(nodeIndex, parent) {
    const node = nodes[nodeIndex], local = node.matrix ? new T.Matrix4().fromArray(node.matrix) : new T.Matrix4().compose(new T.Vector3(...(node.translation ?? [0, 0, 0])), new T.Quaternion(...(node.rotation ?? [0, 0, 0, 1])), new T.Vector3(...(node.scale ?? [1, 1, 1])));
    const matrix = parent.clone().multiply(local);
    if (node.mesh !== undefined) for (const primitive of glb.json.meshes[node.mesh].primitives) {
      const geo = new T.BufferGeometry();
      for (const [semantic, attr] of Object.entries({ POSITION: 'position', NORMAL: 'normal', TEXCOORD_0: 'uv' })) if (primitive.attributes[semantic] !== undefined) {
        const a = readAccessor(glb, primitive.attributes[semantic]); geo.setAttribute(attr, new T.Float32BufferAttribute(a.values, a.width));
      }
      if (primitive.indices !== undefined) geo.setIndex(Array.from(readAccessor(glb, primitive.indices).values));
      geo.applyMatrix4(matrix);
      const desc = glb.json.materials[primitive.material], key = `retained_${primitive.material}`;
      if (!mats[key]) {
        const rgb = desc.pbrMetallicRoughness?.baseColorFactor ?? [1, 1, 1, 1];
        mats[key] = new T.MeshStandardMaterial({ name: desc.name, color: new T.Color().setRGB(...rgb.slice(0, 3), T.LinearSRGBColorSpace), metalness: desc.pbrMetallicRoughness?.metallicFactor ?? 0, roughness: desc.pbrMetallicRoughness?.roughnessFactor ?? .8, emissive: new T.Color().setRGB(...(desc.emissiveFactor ?? [0, 0, 0]), T.LinearSRGBColorSpace) });
      }
      part.add(geo, key);
    }
    for (const child of node.children ?? []) visit(child, matrix);
  }
  visit(index, new T.Matrix4());
  return { part, source: path.relative(root, source).replaceAll('\\', '/'), sha256: hash(glb.bytes) };
}

fs.mkdirSync(output, { recursive: true });
const sources = ['tools/build_threejs_environment.mjs', 'tools/threejs/glb_reader.mjs', 'tools/threejs/package.json'];
const manifest = { schema_version: 1, generator: 'Three.js GLTFExporter', three_version: '0.185.1', coordinates: 'Godot Y-up metres; each part and exported root identity, no presentation scale', material_contract: 'MeshStandardMaterial core metallic/roughness PBR; embedded geometry; no textures, runtime lights or animations', source_files: Object.fromEntries(sources.map(f => [f, hash(fs.readFileSync(path.join(root, f)))])), parts: partNames, themes: {}, acceptance: { glb_structure: 'pending independent verify_environment.mjs', target_godot_renderer: 'parent integration required', navigation_and_collision: 'parent production-physics verification required', performance: 'surface budgets bounded; device timings required' } };
manifest.source_sha256 = hash(JSON.stringify(manifest.source_files));
for (const [theme, config] of Object.entries(themes)) {
  const scene = new T.Scene(); scene.name = `${theme}_architecture`; const mats = materials(theme), summaries = {};
  const retained = retainedLandmark(theme, mats);
  for (const name of partNames) {
    const p = name === 'Landmark' ? retained.part : new Part(name, theme, mats, 3347 + partNames.indexOf(name) * 137);
    const builders = { Floor: p => floor(p), Bridge: p => floor(p, true), Rail: rail, Column: column, Gate: gate, Rock: rock, ArenaCover: cover, Wall: wall, Arcade: arcade, Watchtower: tower, Lantern: lantern, Roof: roof };
    if (builders[name]) builders[name](p);
    const object = p.finish(); scene.add(object);
    const bounds = new T.Box3().setFromObject(object), size = bounds.getSize(new T.Vector3());
    let triangles = 0; object.traverse(o => { if (o.isMesh) triangles += (o.geometry.index?.count ?? o.geometry.attributes.position.count) / 3; });
    summaries[name] = { min: bounds.min.toArray(), max: bounds.max.toArray(), size: size.toArray(), triangles, material_count: object.children.length, mesh_count: object.children.length };
  }
  const data = await new GLTFExporter().parseAsync(scene, { binary: true, onlyVisible: true, animations: [], trs: false });
  const bytes = Buffer.from(data), file = `${theme}.glb`; fs.writeFileSync(path.join(output, file), bytes);
  manifest.themes[theme] = { file, sha256: hash(bytes), bytes: bytes.length, story: config.story, retained_landmark: { file: retained.source, sha256: retained.sha256, reason: 'Preserves exact existing gameplay landmark collision/navigation geometry' }, parts: summaries };
  console.log(`THREEJS_KIT_EXPORTED ${theme} parts=${partNames.length} triangles=${Object.values(summaries).reduce((n, p) => n + p.triangles, 0)} bytes=${bytes.length}`);
  scene.traverse(o => { if (o.isMesh) o.geometry.dispose(); });
  for (const material of Object.values(mats)) material.dispose();
}
fs.writeFileSync(path.join(output, 'manifest.json'), JSON.stringify(manifest, null, 2) + '\n');
console.log('THREEJS_CAMPAIGN_ASSETS_BUILT themes=5 parts=65');
