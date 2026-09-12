# Three.js campaign architecture

These five kits support the larger authored Godot campaign spaces. Authoring and
GLB export use Three.js 0.185.1, with embedded geometry and standard metallic /
roughness PBR materials. There is no browser or JavaScript runtime dependency in
the game assets.

From the repository root:

```powershell
npm --prefix tools/threejs install
node tools/build_threejs_environment.mjs
node tools/threejs/verify_environment.mjs
```

The first command can be skipped when the pinned Three.js package is already at
`build/glb-models/node_modules/three`. The generator checks the installed version.
It writes only `game/assets/environment/threejs_campaign/`. `manifest.json` records
source hashes, source landmark hashes, final GLB SHA-256, bounds, triangle counts,
and merged material counts. `verification.json` binds independent binary checks
to the manifest, assets, and verifier source hashes.

The verifier's success marker is `THREEJS_ENVIRONMENT_CONTRACTS_OK themes=5 parts=65`.
It reads actual binary accessors, normals, indices and exported hierarchy without
importing Three.js or the generator. Godot import, target-renderer appearance,
walking/camera collision and measured runtime costs remain integration checks.

## Parts and integration

Each GLB scene has the following **direct** root children. Coordinates are Y-up
metres; all part roots remain identity. Artwork transforms are baked into vertices.
Runtime batchers can share one mesh per material per part.

| Part | Geometry contract |
| --- | --- |
| Floor | 6 × 0.6 × 6, base Y=-0.6, top Y=0; recessed chamfered slabs and flush inlays |
| Bridge | 6 × 0.28 × 6, centered at Y=0; layered deck with rivets |
| Rail | 6 × 1.4 × 0.48, base Y=0; X axis runs along rail |
| Column | Approximately 1.8–1.9 wide × 6 tall; actual triangles serve collision |
| Gate | Pillars centered X=±4.8 at Y=0, 6m tall, clear central passage; 12m lintel and curved canopy |
| Landmark | Exact established source-kit triangle geometry; see preservation below |
| Rock | 10 × 20 × 10, base Y=0; jagged distant formations |
| ArenaCover | 2 × 3 × 2, base Y=0; actual triangles serve collision |
| Wall | 6 × 10, base Y=0, 0.8m masonry core with total articulated depth ≤1.5m |
| Arcade | 6 × 7 × 1, base Y=0, verified clear central 4 × 4m aperture |
| Watchtower | 12 × 28 × 12, centered X/Z, base Y=0; vista silhouette architecture |
| Lantern | 0.84 × 1.85 × 0.84, base Y=0; emissive cage, no embedded light |
| Roof | 6 × 3 × 6, lowest geometry Y=5, highest Y=8; no floor |

`Watchtower` is scenic architecture placed outside walkable routes. Interior
spaces do not contain a navigable stair system. `Arcade` provides an open arch;
collision should retain that aperture. `Roof` represents a canopy, so a whole-part
bounding box must not block the space below it. Emissive materials do not provide
actual environment lighting; Godot owns exposure, fog, lighting, VFX and movement.

Gate pillar widths are 1.80m for Blood & Iron and about 1.85–1.88m for other themes.
Existing navigation proxies that use slightly different collars should be checked
against the target-renderer collision observations.

## Story and silhouettes

Art references: `docs/story/main-story.md`, plus each chapter's
`docs/chapters/*/chapter-overview.md`.

- **Spirit Ruins:** aged grey stone, fluted shrine columns, bronze hip-roof ribs,
  eroded prayer-stela reliefs, sparse climbing roots and carved stone balustrades.
- **Blood & Iron:** deep fortress masonry, iron braces and hexagonal rivets,
  recessed firing slits, twin furnace chimneys, crenellations and torn red standards.
- **Jade Veil:** moon-ring balustrades and garden arches, twisting exposed roots,
  jade tile eaves, amber metalwork and overgrown pagoda silhouettes.
- **Celestial Fall:** pale and gold masonry, engraved orbital instruments,
  interrupted astral rings and detached spire fragments suspended around the tower.
- **Ember Abyss:** faceted black basalt, forged copper ribs, open skeletal canopies,
  actual alternating chain links and restrained ember fissures.

The existing `Landmark` is intentionally retained from each corresponding
`game/assets/environment/campaign_kits/*.glb`: existing gameplay has detailed
landmark navigation proxies. The builder reconstructs this geometry as Three.js
meshes and exports it in the new GLB. Independent oriented triangle signatures
prove that its world-space surface geometry is unchanged to 0.00001m. The source
GLB files remain required when rebuilding, and their checksums are recorded.

## Static cost

The five kits together occupy approximately 16.9MB. Common parts use 2–6 merged
surfaces, within the contract of fewer than 8; no part exceeds 6. Repeated floor
tiles use 796–1,108 triangles, bridge decks 1,148, rails 1,068–2,504. Larger towers
use 24,630–37,226 triangles. The largest retained landmark has 39,116 triangles.
Detailed per-theme costs are in the manifest. These are geometry/storage counts,
not claims about visible draw calls or target-device frame rate. The game must
measure the assembled scene with its actual instance distribution and renderer.

New masonry uses 44-triangle chamfered solids instead of 108-triangle rounded boxes.
Indexed merging preserves separate flat/bevel normals and reduces duplicate
vertices; tiny chain links use fewer radial segments than large architectural rings.
