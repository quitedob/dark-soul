#!/usr/bin/env node
// Independent GLB skin and rest-geometry verification; no Blender/Godot dependency.
// node tools/validate_skinned_glbs.mjs --source <originals> --output <exports> [--report <json>]
import { readFileSync, readdirSync, writeFileSync } from 'node:fs';
import { resolve, relative, join } from 'node:path';
import { createHash } from 'node:crypto';
import { Matrix3, Matrix4, Quaternion, Vector3 } from '../build/glb-models/node_modules/three/build/three.module.js';

const COMPONENTS = { SCALAR: 1, VEC2: 2, VEC3: 3, VEC4: 4, MAT2: 4, MAT3: 9, MAT4: 16 };
const TYPES = {
  5120: [1, 'getInt8', 127], 5121: [1, 'getUint8', 255],
  5122: [2, 'getInt16', 32767], 5123: [2, 'getUint16', 65535],
  5125: [4, 'getUint32', 4294967295], 5126: [4, 'getFloat32', 1],
};
const check = (condition, message) => { if (!condition) throw new Error(message); };
const integer = (n) => Number.isInteger(n) && n >= 0;
const finite = (values) => values.every(Number.isFinite);
const cleanName = (name) => name.replace(/\.\d{3,}$/, '');
const newBounds = () => [Infinity, Infinity, Infinity, -Infinity, -Infinity, -Infinity];
function extend(bounds, p) {
  for (let axis = 0; axis < 3; axis++) {
    bounds[axis] = Math.min(bounds[axis], p[axis]);
    bounds[axis + 3] = Math.max(bounds[axis + 3], p[axis]);
  }
}
function listGlbs(dir, root = dir, files = new Map()) {
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const path = join(dir, entry.name);
    if (entry.isDirectory()) listGlbs(path, root, files);
    else if (entry.isFile() && /\.glb$/i.test(entry.name)) files.set(relative(root, path).replaceAll('\\', '/'), path);
  }
  return files;
}

function readGlb(path) {
  const bytes = readFileSync(path);
  check(bytes.length >= 20, 'GLB header is truncated');
  check(bytes.readUInt32LE(0) === 0x46546c67, 'Invalid GLB magic');
  check(bytes.readUInt32LE(4) === 2, 'GLB version must be 2');
  check(bytes.readUInt32LE(8) === bytes.length, 'GLB declared length differs from file length');
  let cursor = 12, json, bin;
  while (cursor < bytes.length) {
    check(cursor + 8 <= bytes.length, 'Truncated chunk header');
    const length = bytes.readUInt32LE(cursor), type = bytes.readUInt32LE(cursor + 4);
    check(length % 4 === 0 && cursor + 8 + length <= bytes.length, 'Misaligned or out-of-bounds GLB chunk');
    const chunk = bytes.subarray(cursor + 8, cursor + 8 + length);
    if (type === 0x4e4f534a) {
      check(cursor === 12 && !json, 'JSON must be the first and only JSON chunk');
      json = JSON.parse(chunk.toString('utf8'));
    } else if (type === 0x004e4942) {
      check(json && !bin, 'BIN must follow JSON and occur only once');
      bin = chunk;
    }
    cursor += 8 + length;
  }
  check(json?.asset?.version === '2.0' && bin, 'Missing glTF 2.0 JSON or BIN');
  check(json.buffers?.length === 1 && !json.buffers[0].uri, 'Expected one self-contained binary buffer');
  const bufferLength = json.buffers[0].byteLength;
  check(integer(bufferLength) && bufferLength <= bin.length && bin.length - bufferLength <= 3, 'Invalid embedded buffer length');
  for (const [i, view] of (json.bufferViews ?? []).entries()) {
    check(view.buffer === 0 && integer(view.byteLength) && integer(view.byteOffset ?? 0), `Invalid bufferView ${i}`);
    check((view.byteOffset ?? 0) + view.byteLength <= bufferLength, `bufferView ${i} exceeds the BIN buffer`);
    if (view.byteStride !== undefined) check(integer(view.byteStride) && view.byteStride >= 4 && view.byteStride <= 252 && view.byteStride % 4 === 0, `Invalid byteStride in bufferView ${i}`);
  }
  const data = new DataView(bin.buffer, bin.byteOffset, bin.byteLength), cache = new Map();
  function accessor(index) {
    if (cache.has(index)) return cache.get(index);
    const a = json.accessors?.[index], type = TYPES[a?.componentType], size = COMPONENTS[a?.type];
    check(a && type && size && integer(a.count) && a.count > 0, `Invalid accessor ${index}`);
    check(!a.sparse, `Sparse accessor ${index} is unsupported by this verifier`);
    check(!(a.type === 'MAT2' || a.type === 'MAT3') || type[0] === 4, `Packed small-integer matrix accessor ${index} is unsupported`);
    const view = json.bufferViews?.[a.bufferView];
    check(view, `Missing bufferView for accessor ${index}`);
    const offset = a.byteOffset ?? 0, stride = view.byteStride ?? type[0] * size;
    check(integer(offset) && offset % type[0] === 0 && stride >= type[0] * size && stride % type[0] === 0, `Misaligned accessor ${index}`);
    check(offset + (a.count - 1) * stride + type[0] * size <= view.byteLength, `Accessor ${index} exceeds its bufferView`);
    const result = { ...a, size, values: new Float64Array(a.count * size) };
    for (let row = 0; row < a.count; row++) {
      for (let col = 0; col < size; col++) {
        let value = data[type[1]]((view.byteOffset ?? 0) + offset + row * stride + col * type[0], true);
        if (a.normalized) {
          check(a.componentType !== 5126 && a.componentType !== 5125, `Invalid normalization on accessor ${index}`);
          value = Math.max(-1, value / type[2]);
        }
        check(Number.isFinite(value), `Non-finite value in accessor ${index}`);
        result.values[row * size + col] = value;
      }
    }
    cache.set(index, result);
    return result;
  }
  for (let i = 0; i < (json.accessors?.length ?? 0); i++) accessor(i);
  for (const [i, image] of (json.images ?? []).entries()) {
    check(image.bufferView !== undefined && json.bufferViews[image.bufferView] && /^image\//.test(image.mimeType ?? ''), `Image ${i} must be embedded with a MIME type`);
  }
  const nodes = json.nodes ?? [], parents = Array(nodes.length).fill(-1), local = [];
  for (const [i, node] of nodes.entries()) {
    for (const child of node.children ?? []) {
      check(integer(child) && child < nodes.length && parents[child] === -1, `Invalid child or multiple parents at node ${i}`);
      parents[child] = i;
    }
    if (node.matrix) {
      check(node.matrix.length === 16 && finite(node.matrix), `Invalid matrix at node ${i}`);
      local.push(new Matrix4().fromArray(node.matrix));
    } else {
      const t = node.translation ?? [0, 0, 0], q = node.rotation ?? [0, 0, 0, 1], s = node.scale ?? [1, 1, 1];
      check(t.length === 3 && q.length === 4 && s.length === 3 && finite([...t, ...q, ...s]), `Invalid TRS at node ${i}`);
      check(Math.abs(Math.hypot(...q) - 1) < 1e-4, `Non-unit node quaternion ${i}`);
      local.push(new Matrix4().compose(new Vector3(...t), new Quaternion(...q), new Vector3(...s)));
    }
    check(Math.abs(local[i].determinant()) > 1e-20, `Singular node transform ${i}`);
  }
  function worldMatrices(overrides = new Map()) {
    const visiting = new Set(), world = [];
    function visit(i) {
      if (world[i]) return world[i];
      check(!visiting.has(i), `Cyclic node/joint hierarchy at ${i}`);
      visiting.add(i);
      const transform = overrides.get(i) ?? local[i];
      world[i] = parents[i] < 0 ? transform.clone() : visit(parents[i]).clone().multiply(transform);
      visiting.delete(i);
      return world[i];
    }
    nodes.forEach((_, i) => visit(i));
    return world;
  }
  const world = worldMatrices();
  const scene = json.scenes?.[json.scene ?? 0];
  check(scene?.nodes?.length, 'Missing default scene roots');
  const active = new Set();
  function activate(index) {
    check(integer(index) && nodes[index], `Invalid scene node ${index}`);
    if (active.has(index)) return;
    active.add(index);
    for (const child of nodes[index].children ?? []) activate(child);
  }
  scene.nodes.forEach(activate);
  return { path, bytes: bytes.length, json, bin, accessor, nodes, parents, local, world, worldMatrices, active };
}

function point(values, index, matrix) {
  const p = new Vector3(values[index * 3], values[index * 3 + 1], values[index * 3 + 2]).applyMatrix4(matrix);
  return [p.x, p.y, p.z];
}
function skinPoint(primitive, vertex, matrices) {
  const result = [0, 0, 0];
  for (const { joints, weights } of primitive.influences) {
    for (let c = 0; c < 4; c++) {
      const w = weights.values[vertex * 4 + c];
      if (!w) continue;
      const p = point(primitive.positions.values, vertex, matrices[joints.values[vertex * 4 + c]]);
      for (let axis = 0; axis < 3; axis++) result[axis] += w * p[axis];
    }
  }
  return result;
}
function geometry(model, requireSkin) {
  const { json, nodes, accessor } = model;
  check(json.meshes?.length, 'No meshes');
  if (requireSkin) check(json.skins?.length, 'No skins: GLB has no real skeleton binding');
  const skins = (json.skins ?? []).map((skin, index) => {
    check(skin.joints?.length >= 2, `Skin ${index} needs a root and at least one child joint`);
    check(new Set(skin.joints).size === skin.joints.length, `Skin ${index} contains duplicate joints`);
    for (const joint of skin.joints) check(integer(joint) && nodes[joint] && model.active.has(joint), `Skin ${index} contains invalid/inactive joint ${joint}`);
    if (skin.skeleton !== undefined) check(nodes[skin.skeleton], `Skin ${index} has invalid skeleton root`);
    check(skin.inverseBindMatrices !== undefined, `Skin ${index} has no inverse bind matrices`);
    const ibm = accessor(skin.inverseBindMatrices);
    check(ibm.type === 'MAT4' && ibm.componentType === 5126 && ibm.count === skin.joints.length, `Skin ${index} inverse bind matrix count/type mismatch`);
    const inverse = skin.joints.map((_, i) => {
      const m = new Matrix4().fromArray(ibm.values, i * 16), e = m.elements;
      check(Math.abs(m.determinant()) > 1e-20 && Math.abs(e[3]) < 1e-5 && Math.abs(e[7]) < 1e-5 && Math.abs(e[11]) < 1e-5 && Math.abs(e[15] - 1) < 1e-5, `Invalid inverse bind matrix ${i} in skin ${index}`);
      return m;
    });
    return { ...skin, inverse, mass: Array(skin.joints.length).fill(0), blendedMass: Array(skin.joints.length).fill(0), matrices: skin.joints.map((joint, i) => model.world[joint].clone().multiply(inverse[i])) };
  });
  const meshPrimitives = json.meshes.map((mesh, meshIndex) => {
    check(mesh.primitives?.length, `Mesh ${meshIndex} has no primitives`);
    return mesh.primitives.map((primitive, primitiveIndex) => {
      const label = `Mesh ${meshIndex} primitive ${primitiveIndex}`, attrs = primitive.attributes ?? {};
      check((primitive.mode ?? 4) === 4, `${label} is not triangles`);
      check(attrs.POSITION !== undefined, `${label} has no POSITION`);
      const positions = accessor(attrs.POSITION);
      check(positions.type === 'VEC3' && positions.componentType === 5126, `${label} has invalid positions`);
      for (const [semantic, index] of Object.entries(attrs)) check(accessor(index).count === positions.count, `${label} ${semantic} count differs from POSITION`);
      let indices;
      if (primitive.indices !== undefined) {
        indices = accessor(primitive.indices);
        check(indices.type === 'SCALAR' && [5121, 5123, 5125].includes(indices.componentType) && !indices.normalized, `${label} has invalid index type`);
        for (const index of indices.values) check(integer(index) && index < positions.count, `${label} index out of range`);
      }
      const corners = indices?.count ?? positions.count;
      check(corners % 3 === 0, `${label} triangle index count is not divisible by three`);
      if (attrs.NORMAL !== undefined) check(accessor(attrs.NORMAL).type === 'VEC3', `${label} has invalid normals`);
      for (const [semantic, index] of Object.entries(attrs)) if (semantic.startsWith('TEXCOORD_')) check(accessor(index).type === 'VEC2', `${label} has invalid UVs`);
      if (primitive.material !== undefined) check(json.materials?.[primitive.material], `${label} references invalid material`);
      const influences = [];
      if (requireSkin) {
        check(attrs.JOINTS_0 !== undefined && attrs.WEIGHTS_0 !== undefined, `${label} lacks JOINTS_0/WEIGHTS_0`);
        const sets = Object.keys(attrs).filter((key) => /^JOINTS_\d+$/.test(key)).map((key) => Number(key.slice(7))).sort((a, b) => a - b);
        for (const [expected, set] of sets.entries()) {
          check(set === expected && attrs[`WEIGHTS_${set}`] !== undefined, `${label} has incomplete influence sets`);
          const joints = accessor(attrs[`JOINTS_${set}`]), weights = accessor(attrs[`WEIGHTS_${set}`]);
          check(joints.type === 'VEC4' && [5121, 5123].includes(joints.componentType) && !joints.normalized, `${label} has invalid joint accessor`);
          check(weights.type === 'VEC4' && (weights.componentType === 5126 || ([5121, 5123].includes(weights.componentType) && weights.normalized)), `${label} has invalid weight accessor`);
          influences.push({ joints, weights });
        }
      }
      return { ...primitive, positions, influences, corners, label };
    });
  });
  const result = { meshes: json.meshes.length, meshNodes: 0, primitives: 0, vertices: 0, triangles: 0, normalTriangles: 0, uvTriangles: 0, materialTriangles: 0, multiInfluenceVertices: 0, minWeight: Infinity, maxWeight: -Infinity, maxWeightSumError: 0, bones: new Set(skins.flatMap((s) => s.joints)).size, skins: skins.length, bounds: newBounds(), groups: new Map(), records: [], skinData: skins };
  for (const [nodeIndex, node] of nodes.entries()) {
    if (node.mesh === undefined) continue;
    check(meshPrimitives[node.mesh], `Node ${nodeIndex} references invalid mesh`);
    if (requireSkin) check(node.skin !== undefined && skins[node.skin], `Mesh node ${nodeIndex} (${node.name ?? ''}) is unskinned`);
    if (!model.active.has(nodeIndex)) continue;
    result.meshNodes++;
    const name = cleanName(node.name ?? json.meshes[node.mesh].name ?? `mesh_${node.mesh}`);
    if (!result.groups.has(name)) result.groups.set(name, []);
    for (const primitive of meshPrimitives[node.mesh]) {
      const skin = requireSkin ? skins[node.skin] : null, rest = [];
      result.primitives++;
      result.vertices += primitive.positions.count;
      result.triangles += primitive.corners / 3;
      if (primitive.attributes.NORMAL !== undefined) result.normalTriangles += primitive.corners / 3;
      if (primitive.attributes.TEXCOORD_0 !== undefined) result.uvTriangles += primitive.corners / 3;
      if (primitive.material !== undefined) result.materialTriangles += primitive.corners / 3;
      for (let vertex = 0; vertex < primitive.positions.count; vertex++) {
        if (skin) {
          let sum = 0, nonzero = 0;
          const positiveJoints = new Map();
          for (const { joints, weights } of primitive.influences) for (let c = 0; c < 4; c++) {
            const joint = joints.values[vertex * 4 + c], weight = weights.values[vertex * 4 + c];
            check(integer(joint) && joint < skin.joints.length, `${primitive.label} joint index ${joint} out of range`);
            check(weight >= 0 && weight <= 1, `${primitive.label} weight outside [0, 1]`);
            result.minWeight = Math.min(result.minWeight, weight);
            result.maxWeight = Math.max(result.maxWeight, weight);
            sum += weight;
            if (weight > 0) {
              check(!positiveJoints.has(joint), `${primitive.label} vertex ${vertex} repeats a nonzero joint influence`);
              positiveJoints.set(joint, weight);
              nonzero++;
              skin.mass[joint] += weight;
            }
          }
          check(nonzero > 0 && Math.abs(sum - 1) <= 1e-4, `${primitive.label} vertex ${vertex} has weight sum ${sum}`);
          result.maxWeightSumError = Math.max(result.maxWeightSumError, Math.abs(sum - 1));
          if (nonzero > 1) {
            result.multiInfluenceVertices++;
            for (const [joint, weight] of positiveJoints) skin.blendedMass[joint] += weight;
          }
        }
        const p = skin ? skinPoint(primitive, vertex, skin.matrices) : point(primitive.positions.values, vertex, model.world[nodeIndex]);
        check(finite(p), `${primitive.label} produces non-finite world coordinates`);
        rest.push(p);
        result.groups.get(name).push(p);
        extend(result.bounds, p);
      }
      result.records.push({ primitive, nodeIndex, groupName: name, skinIndex: node.skin, rest });
    }
  }
  check(result.vertices > 0, 'Default scene has no visible mesh vertices');
  return result;
}

// A spatial hash permits vertex splits/deduplication while detecting displaced interior geometry.
function cloudError(source, target, tolerance) {
  const grid = new Map(), cell = (p) => p.map((v) => Math.floor(v / tolerance));
  for (const p of target) {
    const key = cell(p).join(',');
    if (!grid.has(key)) grid.set(key, []);
    grid.get(key).push(p);
  }
  let max = 0, missing = 0;
  for (const p of source) {
    const c = cell(p);
    let best = Infinity;
    for (let x = -1; x <= 1; x++) for (let y = -1; y <= 1; y++) for (let z = -1; z <= 1; z++) {
      for (const q of grid.get(`${c[0] + x},${c[1] + y},${c[2] + z}`) ?? []) best = Math.min(best, Math.hypot(p[0] - q[0], p[1] - q[1], p[2] - q[2]));
    }
    if (best > tolerance) missing++;
    if (Number.isFinite(best)) max = Math.max(max, best);
  }
  return { maxMatchedError: max, unmatchedVertices: missing };
}

function restTriangles(model, stats, materialSignatures) {
  const groups = new Map();
  for (const record of stats.records) {
    const { primitive, nodeIndex, rest, groupName } = record;
    const attrs = primitive.attributes;
    const normal = attrs.NORMAL === undefined ? null : model.accessor(attrs.NORMAL);
    const uvNames = Object.keys(attrs).filter((key) => /^TEXCOORD_\d+$/.test(key)).sort();
    const uvSets = uvNames.map((key) => model.accessor(attrs[key]));
    const material = primitive.material === undefined ? null : materialSignatures[primitive.material];
    const key = JSON.stringify([groupName, material, !!normal, uvNames]);
    if (!groups.has(key)) groups.set(key, { name: groupName, triangles: [] });
    const skin = primitive.influences.length ? stats.skinData[record.skinIndex] : null;
    const nodeNormal = new Matrix3().getNormalMatrix(model.world[nodeIndex]);
    const corners = rest.map((position, vertex) => {
      let worldNormal = null;
      if (normal) {
        let transform = nodeNormal;
        if (skin) {
          // Normals use the inverse transpose of the same blended rest transform as positions.
          const blended = new Matrix4();
          blended.elements.fill(0);
          for (const { joints, weights } of primitive.influences) for (let c = 0; c < 4; c++) {
            const offset = vertex * 4 + c, weight = weights.values[offset];
            if (!weight) continue;
            const matrix = skin.matrices[joints.values[offset]].elements;
            for (let i = 0; i < 16; i++) blended.elements[i] += weight * matrix[i];
          }
          check(Math.abs(blended.determinant()) > 1e-20, `${primitive.label} has singular rest normal transform`);
          transform = new Matrix3().getNormalMatrix(blended);
        }
        worldNormal = new Vector3().fromArray(normal.values, vertex * 3).applyMatrix3(transform).normalize().toArray();
        check(finite(worldNormal), `${primitive.label} produces non-finite rest normals`);
      }
      return { position, normal: worldNormal, uvs: uvSets.flatMap((uv) => Array.from(uv.values.subarray(vertex * 2, vertex * 2 + 2))) };
    });
    const indices = primitive.indices === undefined ? null : model.accessor(primitive.indices).values;
    const triangles = groups.get(key).triangles;
    for (let i = 0; i < primitive.corners; i += 3) {
      const triangle = [0, 1, 2].map((c) => corners[indices ? indices[i + c] : i + c]);
      triangles.push({ corners: triangle, center: [0, 1, 2].map((axis) => triangle.reduce((sum, c) => sum + c.position[axis] / 3, 0)) });
    }
  }
  return groups;
}

function matchTriangles(source, target, tolerance) {
  const cell = (p) => p.map((v) => Math.floor(v / tolerance.position));
  const grid = new Map();
  target.forEach((triangle, i) => {
    const key = cell(triangle.center).join(',');
    if (!grid.has(key)) grid.set(key, []);
    grid.get(key).push(i);
  });
  const near = (a, b, limit) => Math.hypot(...a.map((v, i) => v - b[i])) <= limit;
  const sameCorner = (a, b) => near(a.position, b.position, tolerance.position)
    && (a.normal === null ? b.normal === null : b.normal !== null && near(a.normal, b.normal, tolerance.normal))
    && a.uvs.length === b.uvs.length && a.uvs.every((v, i) => Math.abs(v - b.uvs[i]) <= tolerance.uv);
  const sameTriangle = (a, b) => [0, 1, 2].some((rotation) =>
    a.corners.every((corner, i) => sameCorner(corner, b.corners[(i + rotation) % 3])));
  const candidates = new Map();
  function choices(index) {
    if (!candidates.has(index)) {
      const triangle = source[index], c = cell(triangle.center), matches = [];
      for (let x = -1; x <= 1; x++) for (let y = -1; y <= 1; y++) for (let z = -1; z <= 1; z++) {
        for (const other of grid.get(`${c[0] + x},${c[1] + y},${c[2] + z}`) ?? []) {
          if (sameTriangle(triangle, target[other])) matches.push(other);
        }
      }
      candidates.set(index, matches);
    }
    return candidates.get(index);
  }
  const sourceMatch = new Int32Array(source.length).fill(-1), targetMatch = new Int32Array(target.length).fill(-1);
  let matched = 0;
  // Augmenting paths preserve multiplicity without greedy failures near tolerance boundaries.
  for (let start = 0; start < source.length; start++) {
    const queue = [start], visitedSources = new Set(queue), parent = new Map();
    let found = false;
    for (let cursor = 0; cursor < queue.length && !found; cursor++) {
      const index = queue[cursor];
      for (const other of choices(index)) {
        if (parent.has(other)) continue;
        parent.set(other, index);
        const owner = targetMatch[other];
        if (owner < 0) {
          let targetIndex = other;
          while (targetIndex >= 0) {
            const sourceIndex = parent.get(targetIndex), previous = sourceMatch[sourceIndex];
            sourceMatch[sourceIndex] = targetIndex;
            targetMatch[targetIndex] = sourceIndex;
            targetIndex = previous;
          }
          matched++;
          found = true;
          break;
        }
        if (!visitedSources.has(owner)) { visitedSources.add(owner); queue.push(owner); }
      }
    }
  }
  return matched;
}

function compareRestTriangles(source, output, tolerance) {
  const comparisons = new Map();
  for (const key of new Set([...source.keys(), ...output.keys()])) {
    const before = source.get(key), after = output.get(key), name = (before ?? after).name;
    if (!comparisons.has(name)) comparisons.set(name, { name, sourceTriangles: 0, outputTriangles: 0, unmatchedSourceTriangles: 0, unmatchedOutputTriangles: 0 });
    const original = before?.triangles ?? [], exported = after?.triangles ?? [];
    const matched = matchTriangles(original, exported, tolerance), result = comparisons.get(name);
    result.sourceTriangles += original.length;
    result.outputTriangles += exported.length;
    result.unmatchedSourceTriangles += original.length - matched;
    result.unmatchedOutputTriangles += exported.length - matched;
  }
  return [...comparisons.values()];
}

function poseProof(model, output, scale) {
  return output.skinData.map((skin, skinIndex) => {
    const jointSet = new Set(skin.joints);
    const hasJointAncestor = (joint) => {
      for (let parent = model.parents[joint]; parent >= 0; parent = model.parents[parent]) if (jointSet.has(parent)) return true;
      return false;
    };
    const candidates = skin.joints.map((joint, slot) => ({ joint, slot, mass: skin.mass[slot], blendedMass: skin.blendedMass[slot] }))
      .filter(({ joint, mass }) => mass > 0 && hasJointAncestor(joint)).sort((a, b) => b.blendedMass - a.blendedMass || b.mass - a.mass);
    check(candidates.length, `Skin ${skinIndex} has no weighted non-root joint`);
    const selected = candidates[0], rotation = new Matrix4().makeRotationAxis(new Vector3(1, 0.7, 0.3).normalize(), 0.3);
    const worlds = model.worldMatrices(new Map([[selected.joint, model.local[selected.joint].clone().multiply(rotation)]]));
    const matrices = skin.joints.map((joint, i) => worlds[joint].clone().multiply(skin.inverse[i]));
    let displacement = 0, movedVertices = 0, multiInfluenceMovedVertices = 0;
    for (const record of output.records.filter((r) => r.skinIndex === skinIndex)) {
      for (let vertex = 0; vertex < record.primitive.positions.count; vertex++) {
        const p = skinPoint(record.primitive, vertex, matrices), rest = record.rest[vertex];
        check(finite(p), `Skin ${skinIndex} produces non-finite posed positions`);
        const distance = Math.hypot(...p.map((v, axis) => v - rest[axis]));
        displacement = Math.max(displacement, distance);
        if (distance > scale * 1e-7) {
          movedVertices++;
          const positive = record.primitive.influences.reduce((total, set) => total + Array.from(set.weights.values.subarray(vertex * 4, vertex * 4 + 4)).filter((w) => w > 0).length, 0);
          if (positive > 1) multiInfluenceMovedVertices++;
        }
      }
    }
    check(movedVertices > 0 && displacement > scale * 1e-6, `Skin ${skinIndex} fails non-root joint deformation proof`);
    if (skin.blendedMass.some((mass) => mass > 0)) check(multiInfluenceMovedVertices > 0, `Skin ${skinIndex} has blended vertices but none moved in the pose proof`);
    return { skin: skinIndex, joint: model.nodes[selected.joint].name ?? selected.joint, jointNode: selected.joint, rotationRadians: 0.3, movedVertices, multiInfluenceMovedVertices, maxDisplacement: displacement };
  });
}

function materialSummary(model) {
  const { json, bin } = model;
  const images = (json.images ?? []).map((image) => {
    const view = json.bufferViews[image.bufferView];
    return { mimeType: image.mimeType, bytes: view.byteLength, sha256: createHash('sha256').update(bin.subarray(view.byteOffset ?? 0, (view.byteOffset ?? 0) + view.byteLength)).digest('hex') };
  });
  const textureProperties = (info, slot) => {
    const texture = json.textures?.[info.index];
    check(texture && images[texture.source], `Invalid material texture ${info.index}`);
    if (texture.sampler !== undefined) check(integer(texture.sampler) && json.samplers?.[texture.sampler], `Invalid sampler ${texture.sampler} for texture ${info.index}`);
    const sampler = json.samplers?.[texture.sampler] ?? {};
    return { ...info, ...(/normalTexture$/i.test(slot) ? { scale: info.scale ?? 1 } : {}),
      ...(slot === 'occlusionTexture' ? { strength: info.strength ?? 1 } : {}),
      index: undefined, texCoord: info.texCoord ?? 0,
      imageSha256: images[texture.source].sha256,
      sampler: { wrapS: sampler.wrapS ?? 10497, wrapT: sampler.wrapT ?? 10497,
        magFilter: sampler.magFilter ?? null, minFilter: sampler.minFilter ?? null } };
  };
  const extensionProperties = (value) => {
    if (Array.isArray(value)) return value.map(extensionProperties);
    if (!value || typeof value !== 'object') return value;
    return Object.fromEntries(Object.entries(value).map(([key, item]) => [key,
      key.endsWith('Texture') ? textureProperties(item, key) : extensionProperties(item)]));
  };
  return {
    materials: json.materials?.length ?? 0, images: images.length, textures: json.textures?.length ?? 0,
    materialExtensions: [...new Set((json.materials ?? []).flatMap((m) => Object.keys(m.extensions ?? {})))].sort(),
    imagePayloads: images,
    // Effective values expose re-export changes without confusing renamed materials with lost materials.
    properties: (json.materials ?? []).map((m, i) => ({ index: i, name: m.name ?? null,
      baseColor: m.pbrMetallicRoughness?.baseColorFactor ?? [1, 1, 1, 1],
      metallic: m.pbrMetallicRoughness?.metallicFactor ?? 1, roughness: m.pbrMetallicRoughness?.roughnessFactor ?? 1,
      emission: (m.emissiveFactor ?? [0, 0, 0]).map((v) => v * (m.extensions?.KHR_materials_emissive_strength?.emissiveStrength ?? 1)),
      alphaMode: m.alphaMode ?? 'OPAQUE', alphaCutoff: m.alphaCutoff ?? 0.5, doubleSided: m.doubleSided ?? false,
      textureSlots: Object.keys(m).filter((key) => key.endsWith('Texture')).concat(Object.keys(m.pbrMetallicRoughness ?? {}).filter((key) => key.endsWith('Texture'))).sort(),
      textureProperties: Object.fromEntries(Object.entries({ ...m, ...m.pbrMetallicRoughness }).filter(([key]) => key.endsWith('Texture')).map(([key, info]) => [key, textureProperties(info, key)])),
      extensions: extensionProperties(m.extensions ?? {}),
    })),
  };
}
function publicStats(stats) {
  const { groups, records, skinData, ...publicFields } = stats;
  if (!Number.isFinite(publicFields.minWeight)) publicFields.minWeight = null;
  if (!Number.isFinite(publicFields.maxWeight)) publicFields.maxWeight = null;
  return publicFields;
}
function inspectPair(file, sourcePath, outputPath) {
  const report = { file, sourcePath, outputPath, failures: [], semanticChanges: [] };
  try {
    const sourceModel = readGlb(sourcePath), outputModel = readGlb(outputPath);
    const source = geometry(sourceModel, false), output = geometry(outputModel, true);
    report.source = publicStats(source);
    report.output = publicStats(output);
    const scale = Math.max(1e-6, ...source.bounds.slice(0, 3).map((v, axis) => source.bounds[axis + 3] - v));
    report.positionTolerance = scale * 1e-4;
    report.maxRestBoundsError = Math.max(...source.bounds.map((v, axis) => Math.abs(v - output.bounds[axis])));
    if (report.maxRestBoundsError > report.positionTolerance) report.failures.push('Rest skinned world bounds differ from original bounds');
    report.missingMeshGroups = [...source.groups.keys()].filter((key) => !output.groups.has(key));
    report.extraMeshGroups = [...output.groups.keys()].filter((key) => !source.groups.has(key));
    if (report.missingMeshGroups.length || report.extraMeshGroups.length) report.failures.push('Named mesh groups changed');
    report.restMeshComparisons = [];
    for (const [name, originalPoints] of source.groups) {
      const outputPoints = output.groups.get(name);
      if (!outputPoints) continue;
      const forward = cloudError(originalPoints, outputPoints, report.positionTolerance), reverse = cloudError(outputPoints, originalPoints, report.positionTolerance);
      const comparison = { name, sourceVertices: originalPoints.length, outputVertices: outputPoints.length, maxMatchedError: Math.max(forward.maxMatchedError, reverse.maxMatchedError), missingSourceVertices: forward.unmatchedVertices, extraOutputVertices: reverse.unmatchedVertices };
      report.restMeshComparisons.push(comparison);
      if (forward.unmatchedVertices || reverse.unmatchedVertices) report.failures.push(`Rest vertex cloud changed: ${name} (missing ${forward.unmatchedVertices}, extra ${reverse.unmatchedVertices})`);
    }
    for (const field of ['meshes', 'meshNodes', 'primitives', 'vertices', 'triangles', 'normalTriangles', 'uvTriangles', 'materialTriangles']) {
      if (source[field] !== output[field]) report.semanticChanges.push({ field, source: source[field], output: output[field] });
    }
    for (const field of ['triangles', 'normalTriangles', 'uvTriangles', 'materialTriangles']) {
      if (source[field] !== output[field]) report.failures.push(`${field} changed from ${source[field]} to ${output[field]}`);
    }
    report.materials = { source: materialSummary(sourceModel), output: materialSummary(outputModel) };
    for (const field of ['materials', 'images', 'textures', 'materialExtensions']) {
      if (JSON.stringify(report.materials.source[field]) !== JSON.stringify(report.materials.output[field])) report.semanticChanges.push({ field, source: report.materials.source[field], output: report.materials.output[field] });
    }
    const canonical = (value) => {
      if (typeof value === 'number') return Number(value.toFixed(5));
      if (Array.isArray(value)) return value.map(canonical);
      if (value && typeof value === 'object') return Object.fromEntries(Object.keys(value).sort().map((key) => [key, canonical(value[key])]));
      return value;
    };
    const stable = (properties) => properties.map(({ index, name, extensions, ...p }) => JSON.stringify(canonical({ ...p,
      // Emissive strength is already folded into the effective emission above.
      extensions: Object.fromEntries(Object.entries(extensions).filter(([key]) => key !== 'KHR_materials_emissive_strength').map(([key, value]) => [key,
        key === 'KHR_materials_sheen' ? { sheenColorFactor: [0, 0, 0], sheenRoughnessFactor: 0, ...value } :
          key === 'KHR_materials_clearcoat' ? { clearcoatFactor: 0, clearcoatRoughnessFactor: 0, ...value } : value])),
    })));
    const sourceSignatures = stable(report.materials.source.properties), outputSignatures = stable(report.materials.output.properties);
    // Unit-normal distance 1e-3 is about 0.057 degrees, allowing export quantization.
    report.triangleTolerances = { position: report.positionTolerance, uv: 1e-5, normal: 1e-3 };
    report.restTriangleComparisons = compareRestTriangles(
      restTriangles(sourceModel, source, sourceSignatures), restTriangles(outputModel, output, outputSignatures), report.triangleTolerances);
    for (const comparison of report.restTriangleComparisons) {
      if (comparison.unmatchedSourceTriangles || comparison.unmatchedOutputTriangles) {
        report.failures.push(`Oriented rest triangle/corner data changed: ${comparison.name} (missing ${comparison.unmatchedSourceTriangles}, extra ${comparison.unmatchedOutputTriangles})`);
      }
    }
    const before = new Set(sourceSignatures), after = new Set(outputSignatures);
    const lost = [...before].filter((p) => !after.has(p)), added = [...after].filter((p) => !before.has(p));
    if (lost.length || added.length) {
      report.semanticChanges.push({ field: 'materialProperties', missing: lost.map(JSON.parse), added: added.map(JSON.parse) });
      report.failures.push('Material properties, texture mapping or samplers changed');
    }
    // Reindexing/deduplication is harmless; assigning an unchanged material to another
    // mesh is not. Compare effective materials on the actual named mesh geometry.
    const assignments = (stats, signatures) => {
      const groups = new Map();
      for (const record of stats.records) {
        if (!groups.has(record.groupName)) groups.set(record.groupName, new Map());
        const materials = groups.get(record.groupName), signature = record.primitive.material === undefined ? null : signatures[record.primitive.material];
        if (!materials.has(signature)) materials.set(signature, { triangles: 0, points: [] });
        const assigned = materials.get(signature);
        assigned.triangles += record.primitive.corners / 3;
        for (const p of record.rest) assigned.points.push(p);
      }
      return groups;
    };
    const sourceAssignments = assignments(source, sourceSignatures), outputAssignments = assignments(output, outputSignatures);
    report.changedMaterialMeshGroups = [];
    for (const [name, originalMaterials] of sourceAssignments) {
      const outputMaterials = outputAssignments.get(name);
      if (!outputMaterials) continue; // Already reported as a missing mesh group.
      let changed = originalMaterials.size !== outputMaterials.size;
      for (const [signature, original] of originalMaterials) {
        const exported = outputMaterials.get(signature);
        if (!exported || exported.triangles !== original.triangles) { changed = true; continue; }
        if (originalMaterials.size > 1 && (cloudError(original.points, exported.points, report.positionTolerance).unmatchedVertices || cloudError(exported.points, original.points, report.positionTolerance).unmatchedVertices)) changed = true;
      }
      if (changed) report.changedMaterialMeshGroups.push(name);
    }
    if (report.changedMaterialMeshGroups.length) report.failures.push(`Material assignment changed in mesh groups: ${report.changedMaterialMeshGroups.join(', ')}`);
    const beforeImages = new Set(report.materials.source.imagePayloads.map((i) => i.sha256)), afterImages = new Set(report.materials.output.imagePayloads.map((i) => i.sha256));
    if ([...beforeImages].some((hash) => !afterImages.has(hash)) || [...afterImages].some((hash) => !beforeImages.has(hash))) {
      report.semanticChanges.push({ field: 'imagePayloads', sourceUniqueImages: beforeImages.size, outputUniqueImages: afterImages.size, note: 'Encoded image bytes changed; visual equivalence requires image/viewport inspection.' });
      report.failures.push('Embedded image payloads changed');
    }
    report.poseProofs = poseProof(outputModel, output, scale);
    report.maxPoseDisplacement = Math.max(...report.poseProofs.map((proof) => proof.maxDisplacement));
  } catch (error) {
    report.failures.push(error.message);
  }
  report.ok = report.failures.length === 0;
  return report;
}

function main() {
  const options = {};
  for (let i = 2; i < process.argv.length; i += 2) {
    const key = process.argv[i];
    check(['--source', '--output', '--report'].includes(key) && process.argv[i + 1] && !process.argv[i + 1].startsWith('--'), 'Usage: node tools/validate_skinned_glbs.mjs --source <directory> --output <directory> [--report <file.json>]');
    check(!options[key], `Duplicate option ${key}`);
    options[key] = resolve(process.argv[i + 1]);
  }
  check(options['--source'] && options['--output'], '--source and --output are required');
  const sources = listGlbs(options['--source']), outputs = listGlbs(options['--output']);
  check(sources.size > 0, 'Source directory has no GLBs');
  const report = { generatedAt: new Date().toISOString(), source: options['--source'], output: options['--output'], missingPaths: [...sources.keys()].filter((key) => !outputs.has(key)).sort(), extraPaths: [...outputs.keys()].filter((key) => !sources.has(key)).sort(), models: [] };
  for (const file of [...sources.keys()].sort()) {
    if (!outputs.has(file)) continue;
    const result = inspectPair(file, sources.get(file), outputs.get(file));
    report.models.push(result);
    console.log(`${result.ok ? 'PASS' : 'FAIL'} ${file}${result.ok ? `: ${result.output.bones} bones, ${result.output.vertices} vertices, rest error ${result.maxRestBoundsError.toExponential(2)}, pose ${result.maxPoseDisplacement.toExponential(2)}` : `: ${result.failures.join('; ')}`}`);
  }
  const failed = report.models.filter((model) => !model.ok).length;
  report.summary = { sourceFiles: sources.size, outputFiles: outputs.size, checked: report.models.length, passed: report.models.length - failed, failed, missing: report.missingPaths.length, extra: report.extraPaths.length, modelsWithSemanticChanges: report.models.filter((model) => model.semanticChanges.length).length };
  report.ok = failed === 0 && report.missingPaths.length === 0 && report.extraPaths.length === 0;
  if (options['--report']) {
    check(![...sources.values(), ...outputs.values()].some((path) => resolve(path).toLowerCase() === options['--report'].toLowerCase()), 'Report path must not overwrite a model');
    writeFileSync(options['--report'], JSON.stringify(report, null, 2) + '\n');
  }
  console.log(`${report.ok ? 'SKINNED_GLBS_VALIDATION_OK' : 'SKINNED_GLBS_VALIDATION_FAILED'} ${JSON.stringify(report.summary)}`);
  process.exitCode = report.ok ? 0 : 1;
}
try { main(); } catch (error) { console.error(`SKINNED_GLBS_VALIDATION_FAILED ${error.message}`); process.exitCode = 1; }
