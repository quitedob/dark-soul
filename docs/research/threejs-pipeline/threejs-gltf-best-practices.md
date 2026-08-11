# Research — three.js GLTF/GLB 生产最佳实践（three r185）

> 2026-08-11 · Perplexity Research（`/perplexity-research`）。目标：为项目的 three.js 管线
> （`build/glb-models` 85 个 GLB 导出、`build/scenes` 查看器、`build/glb-test` 查看器）加固，
> 覆盖压缩/加载/动画/实例化/导出五项。

## Key Findings（按置信度）

### 高置信（与 three.js r185 文档一致，可复核）
1. **DRACO 几何压缩加载**（r185 正确 API）：
   ```js
   import { DRACOLoader } from 'three/addons/loaders/DRACOLoader.js';
   const draco = new DRACOLoader();
   draco.setDecoderPath('https://www.gstatic.com/draco/versioned/decoders/1.5.6/');
   gltfLoader.setDRACOLoader(draco);
   ```
   decoder 路径建议本地分发（`/draco/`）而非 CDN（离线/内网场景）。
2. **meshopt 加载**：
   ```js
   import { MeshoptDecoder } from 'three/addons/libs/meshopt_decoder.module.js';
   gltfLoader.setMeshoptDecoder(MeshoptDecoder);
   ```
3. **KTX2 纹理加载**（需先 `detectSupport(renderer)`）：
   ```js
   const ktx2 = new KTX2Loader();
   ktx2.setTranscoderPath('<path>/basis/');   // 如 unpkg three@0.x examples/jsm/libs/basis/
   ktx2.detectSupport(renderer);
   gltfLoader.setKTX2Loader(ktx2);
   ```
4. **GLTFExporter 有效选项**：`binary:true`、`animations`（AnimationClip 数组）、`embedImages`、
   `maxTextureSize`、`onlyVisible:true` 均为真实选项。
   **GLTFExporter 没有内置 meshopt/DRACO 编码选项** —— 几何压缩需走独立管线（`gltfpack` 或 Blender Draco 导出）。

### 中置信（方法/方向可信，数值需按本项目实测）
5. **本项目的 29MB 静态 GLB 值得压缩**：低模纯 PBR（少量程序化小纹理）→ **KTX2 收益低，跳过**；
   几何用 **DRACO 或 meshopt**。DRACO 在复杂网格上可减 40–80%，低模上较少；meshopt 对大量共享网格实例友好。
   推荐先用 `gltfpack -c`（meshoptimizer CLI）试压并量数。
6. **DRACO + meshopt 双编码可能反而变大** —— 选一为主。
7. **AnimationMixer 生产用法**：按 clip 名缓存/复用 action、`crossFadeFrom/to` 交叉淡入、
   root motion 显式处理、减骨/剪多余骨控制蒙皮预算；Mixamo FBX→GLB 在 Blender 里重定向并保持骨骼命名一致。
8. **多实例性能**：相同网格→`InstancedMesh`；完全静态批→`mergeGeometries`；距离细节→`THREE.LOD`；
   用 `renderer.info.render.calls` 量 draw calls；对象池复用。

## Project Documentation Reviewed（项目文档可靠性）

| 来源 | 结论 | 可靠度 |
|---|---|---|
| `build/glb-test/index.html:15-25,65` · `build/glb-models/index.html` · `build/scenes/_shared/scene-helpers.mjs:8-10` | 三个查看器均用裸 `GLTFLoader`，**无 DRACO/KTX2/meshopt/LoadingManager** | RELIABLE |
| `build/glb-models/_shared/helpers.mjs:214-226` | 导出仅 `binary:true, trs:true, onlyVisible:true`；`maxTextureSize` 未设（默认 Infinity） | RELIABLE（缺口：与参考文档建议矛盾） |
| `build/glb-models/MANIFEST.json` | 85 GLB，~28.8MB（devlog 基线 27.4MB 已过期） | RELIABLE（数值 STALE） |
| `build/glb-models/scripts/*` + `MANIFEST` | **零动画 clip 导出、零运行时 mixer** | RELIABLE |
| `.claude/.../references/glb-export-threejs.md:111` | "keep embedImages + maxTextureSize 上限" | CONTRADICTED（helpers.mjs 未设 cap） |
| `.claude/.../references/threejs-loaders/SKILL.md:235-238` | DRACO `setDecoderPath(gstatic 1.5.6)` 示例 | UNVERIFIED（仅参考，未实现） |
| `.claude/.../references/threejs-textures/SKILL.md:619-621` | 纹理上限 2048/移动 1024 | UNVERIFIED（未执行） |
| `build/scenes/_shared/scene-helpers.mjs:489-503` | `S.instanced`（InstancedMesh）已实现；`THREE.LOD`/`mergeGeometries` 未实现 | RELIABLE |

## Sources

- three.js 文档：https://threejs.org/docs/index.html#examples/en/loaders/DRACOLoader ·
  …/loaders/GLTFLoader · …/loaders/KTX2Loader · …/libs/meshopt_decoder.module.js ·
  …/exporters/GLTFExporter
- Khronos glTF：https://www.khronos.org/gltf/ · https://github.com/KhronosGroup/glTF
- Blender FBX 导出：https://docs.blender.org/manual/en/latest/files/flipping/FBX/export.html
- （Perplexity pro 两次检索，2026-08-11；工具返回无逐条内联 URL，来源为 threejs.org 文档页与 Khronos 官方资源）

## Contradictions & Gaps

- **maxTextureSize**：参考文档建议设置上限，`helpers.mjs:225` 未设置（默认 Infinity）—— 待补。
- **压缩**：技能参考声称 DRACO/KTX2 应使用，但 85 个 GLB 全部未压缩导出，运行时也无对应 loader —— 全绿到全灰的缺口。
- **动画**：导出零 clip；`glb-export-threejs.md:112` 提到动画"应在导出时省略"用于静态资产，但查看器/模型均无动画 —— 与 three.js 动画能力未接线。
- **exact decoder CDN 版本**：Perplexity 未给出与 r185 完全锁定的 gstatic DRACO 版本号与 KTX2 transcoder 路径；需按部署自验。
- **GLTFExporter meshopt**：无此选项（正确）；项目若要 meshopt 需引入 `gltfpack` 或 Draco 导出管线。

## Recommendations（对本项目可执行）

1. **若要把 85 个 GLB 真正"发货"**：用 `gltfpack`（meshoptimizer CLI）对 `build/glb-models/out/` 批量做 meshopt + 可选 DRACO 压缩（`gltfpack -i in.glb -o out.glb -c`），量尺寸收益；加载端补 `setMeshoptDecoder`（低模+多实例场景，meshopt 解码快、足够）。
2. **跳过 KTX2**：GLB 多为纯 PBR + 程序化 64–128px DataTexture，KTX2 解码开销大于收益。
3. **导出端补 `maxTextureSize` 上限**（如 1024/2048），对齐 `glb-export-threejs.md` 建议。
4. **动画**：若要让敌人/首领有骨骼动画，走 Blender Mixamo FBX→GLB 重定向（保持骨骼命名），导出 clips；运行时按 clip 缓存 + `AnimationMixer`。`build/real-models` 查看器已示范该模式。
5. **性能**：`build/scenes` 已用 `S.instanced`；对远程/大型场景补 `THREE.LOD`，并用 `renderer.info.render.calls` 建 draw-call 预算。
6. **稳定性**：保持节点命名（`BodyRoot`/`ModelRoot`）与 Godot `RealModelResolver` 契约一致（已满足）。

## Search Coverage

- 检索 1（pro）：三项加载压缩 + 纹理 + 动画 + 实例化 + 导出五大项 —— 返回方向正确但 API 签名有误、无 URL。
- 检索 2（follow-up，pro）：修正 DRACO/meshopt/KTX2 精确 API + GLTFExporter 真实选项 + Blender 重定向步骤 + 官方 URL。
- 未做：逐 URL WebFetch 复核（Perplexity 结果为工具生成，置信中高；建议按需直接读 threejs.org 文档页复核具体版本）。

## 关联

- 项目 three.js 管线：`build/glb-models/` · `build/scenes/` · `build/glb-test/`
- 资产源：`docs/model-prompts/` · 真模型迁移：[devlog 2026-08-11](../devlog/2026-08-11/01-85-glb-into-game-real-model-milestone.md)
