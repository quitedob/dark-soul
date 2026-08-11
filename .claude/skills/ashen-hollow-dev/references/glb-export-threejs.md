# Producing GLB models with Three.js GLTFExporter

Web-side GLB generation for the asset pipeline. Sits between the model prompts
(`docs/model-prompts/`) and Godot import (`res://assets/models/` → `RealModelResolver`
registry): build a scene programmatically in Three.js, export `.glb`, drop it into
`game/assets/models/...`, run Godot `--import`.

> **Why Three.js:** no Blender/TRELLIS/Hunyuan3D install needed — pure Node/browser JS,
> Y-up coordinate system matches glTF/Godot, textures embed, and it is the documented
> "Web 端实时导出" path. For batch/offline conversions of existing files (OBJ/FBX/STEP)
> use `trimesh` / `fbxloader` / `ComfyUI-3D-Convert` instead.
>
> **Building blocks:** the sibling `references/threejs-*` skills cover the API you need to
> *build* the scene before exporting — **threejs-fundamentals** (scene/camera/object
> hierarchy), **threejs-geometry** (building meshes), **threejs-materials** (PBR material
> setup), **threejs-lighting**, **threejs-textures**, **threejs-animation**, and
> **threejs-loaders** (importing sources). This file is the export/Godot-integration half.

## GLTFExporter API

Source: `three/addons/exporters/GLTFExporter.js` — see
<https://threejs.org/docs/#examples/en/exporters/GLTFExporter>

```js
import { GLTFExporter } from 'three/addons/exporters/GLTFExporter.js';

const exporter = new GLTFExporter();           // no constructor args

// Callback API
exporter.parse(scene, onDone, onError, options);

// Promise API (Node 18+ / modern browser)
const result = await exporter.parseAsync(scene, { binary: true });
```

| `parse` arg | Type | Notes |
|---|---|---|
| `input` | `Object3D` \| `Object3D[]` | scene or object(s) to export |
| `onDone` | `(gltf) => void` | `ArrayBuffer` when `binary:true`, else JSON object |
| `onError` | `(error) => void` | export failure |
| `options` | `object` | see below |

### Option keys

| Key | Default | Meaning |
|---|---|---|
| `binary` | `false` | `true` → single-file `.glb` (`ArrayBuffer`); `false` → `.gltf` JSON |
| `trs` | `false` | emit `translation`/`rotation`/`scale` instead of a `matrix` per node |
| `onlyVisible` | `true` | export only visible objects |
| `truncateDrawRange` | `true` | truncate geometry draw ranges |
| `embedImages` | `true` | embed textures in the GLB BIN chunk |
| `animations` | — | `Array<AnimationClip>` — skeletal / morph / node keyframe clips |
| `includeCustomExtensions` | `false` | export `object.userData.gltfExtensions` as glTF extensions |
| `maxTextureSize` | `Infinity` | cap embedded texture resolution |

## Minimal .glb export (works headless in Node)

```js
import * as THREE from 'three';
import { GLTFExporter } from 'three/addons/exporters/GLTFExporter.js';
import { writeFileSync } from 'node:fs';

const scene = new THREE.Scene();

// Build a mesh with a real material (MeshStandardMaterial exports cleanly)
const geo = new THREE.CylinderGeometry(0.35, 0.4, 1.8, 24);
const mat = new THREE.MeshStandardMaterial({ color: 0x6a4a2a, metalness: 0.2, roughness: 0.7 });
const mesh = new THREE.Mesh(geo, mat);
mesh.name = 'weapon/axe_right';                 // name matches the resolver key intent
scene.add(mesh);

// Node name survives into glTF → Godot's RealModelResolver sub_node lookup.
// Keep the top-level object name as BodyRoot / ModelRoot when the Godot factory
// expects those container names.

const exporter = new GLTFExporter();
exporter.parse(scene, (glb) => {
  writeFileSync('axe_right.glb', Buffer.from(glb));
  console.log('axe_right.glb written', glb.byteLength, 'bytes');
}, (err) => { console.error('Export failed:', err); process.exit(1); },
{ binary: true, trs: true, embedImages: true });
```

## Fit with the Godot import pipeline

1. Export `.glb` (Y-up, meters — matches Godot, no axis flip needed).
2. Copy to `game/assets/models/<category>/<name>.glb` (player / enemy / weapons / …).
3. Run Godot headless import:
   `"E:/godot/Godot_v4.7.1-stable_win64_console.exe" --headless --editor --path "e:/godot/darksoul/game" --quit`
   → generates `.import`.
4. Register in `RealModelResolver.REGISTRY` as `"category/key" → { path, sub_node, root_name, scale, scale_x, y_offset, yaw_deg, position }`. Misses fall back to procedural — wiring never breaks.
5. Keep `weapon_tip` / `ExecutionAnchor` / `GrabProfile` mount points aligned: match node names and orientations in the exported scene so weapon tips and hitboxes land correctly.

## Gotchas for this repo

- **Node has no `FileReader` (verified 2026-08-03):** the exporter's `binary:true` path calls `new FileReader().readAsArrayBuffer(blob)` unconditionally, which throws `ReferenceError: FileReader is not defined` under Node. Shim it before importing the exporter (the async `blob.arrayBuffer()` resolves after the exporter assigns `onloadend`, so this works):

  ```js
  if (typeof globalThis.FileReader === 'undefined') {
    globalThis.FileReader = class {
      readAsArrayBuffer(blob) {
        blob.arrayBuffer()
          .then((buf) => { this.result = buf; if (this.onloadend) this.onloadend(); })
          .catch((e) => { if (this.onerror) this.onerror(e); });
      }
    };
  }
  ```
- **Node names survive the export** — name objects to match the resolver `sub_node` / `root_name` (e.g. `BodyRoot`, `ModelRoot`, weapon grip origin) instead of generic `Object001`.
- **`owner` consistency:** after Godot re-parents GLB sub-nodes, set `target.owner = null` to avoid `owner inconsistent` warnings (see SKILL.md §7).
- **Embed textures:** keep `embedImages:true` and `maxTextureSize` capped — this project's CC0 assets are 0-texture pure-PBR; oversized embedded textures bloat the GLB and slow import.
- **Animations:** pass `animations` only for clip-bearing assets; for static weapon/prop meshes omit it to keep files minimal. Godot plays GLB animations natively, but this repo currently wires animation mid-state in `real_model_resolver.gd`.
- **Multiple meshes:** export a single scene with multiple objects → one `.glb` with multiple nodes (fine). For one-resolver-entry-one-file, export each mountable part separately.
- **Test after import:** run `tests/smoke/real_model_contract_test.gd` (expect `REAL_MODEL_CONTRACTS_OK`) and the smoke test.
