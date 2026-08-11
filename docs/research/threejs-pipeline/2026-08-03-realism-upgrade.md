# 真实感升级：游戏角色 / 物品 / 场景

**日期:** 2026-08-03
**研究方式:** Perplexity pro 一次合并搜索 + 一次 follow_up（backend_uuid `d05e8b55-...` → `bcf9b818-...`）
**主题:** 用 three.js 程序化生成魂类游戏全部资产（角色/怪物/武器/护甲为纯程序化几何，场景为 three.js 环境）时，如何让角色/物品/场景"更真实"。魂系审美 = **风格化写实**，非照片级写实。
**用途:** 驱动 `build/glb-models/`（85 个程序化 GLB）+ `build/scenes/`（28 场景）真实感升级，落地为 SCENE-SPECS「真实感」章节。

---

## Key Findings（按置信度排序）

### 高置信度

1. **程序化管线的现实预期：能达到"风格化写实"，达不到照片级写实——而这正是魂类的正确路线。** 纯程序化（几何 + 噪声纹理）足以做出质感、体量、氛围；但真实皮肤皮层、微观皮纹、真实体积散射做不到，需接受风格化表达。对以剪影和氛围为主的魂类，**低模风格化写实是最优解**，别追高清写实。

2. **角色/怪物（剪影之外）的真实感来源**：
   - **PBR 参数真实区间**（各材质 roughness/metalness 按真实材质取值，而非随意）：skin 低 roughness + SSS 近似；fabric 高 roughness（0.8–1.0）；leather 中（0.6–0.9）；bone 中高（0.7–0.9）；metal 高 metalness（≈0.9）+ 低 roughness（0.1–0.5）。
   - **程序化贴图**：曲率 → AO，噪声 → 粗糙度/法线变化（多尺度噪声），分区遮罩（skin/fabric/metal 各一张噪声层）。
   - **SSS 廉价替代**：透光率（transmission）+ 边缘光（rim）+ 浅色腔面渐变，模拟次表面散射；对 ghost/皮肤类尤其有效。
   - **磨损与肌理**：程序化磨损/老化分层（按区域叠加噪声），微细节（织物经纬/鳞片/划痕）走噪声纹理而非几何。
   - **姿态与重心**：几何之外，扭转/重心/不对称（dynamic pose）让角色"活"。

### 中高置信度

3. **武器/护甲/物品真实感**：
   - 金属 = metalness≈1.0 + roughness 0.1–0.5 + **clearcoat**（清漆层增强高光）+ **边缘倒角 bevel**（几何倒角对金属感提升巨大）。
   - 程序化痕迹：划痕/锈蚀/淬火色/包浆走**边缘加强**的噪声叠加（渐变贴图），禁止全覆盖。
   - 发光部件：低强度受控 emissive，绝不整件泛辉光。
   - 皮革/布料：编织纹理（噪声扰动）+ 几何褶皱结合。

4. **场景后期取舍**：
   - **真提升**：轻量 Bloom（强度 0.6–1.0、阈值适中、只吃高光）+ 适度体积雾（密度 0.03–0.08、贴近主色）+ 弱色差（0.5–1.5，暖边冷边）+ 微颗粒（氛围，过量伤可读性）。
   - **廉价掩盖**：过强辉光、强烈色彩分离、过量 DOF、全屏粒子——禁止用来遮丑。
   - **构图**：leading lines 引导线 + 剪影对比 + 焦点清晰（背景不过度抢戏）——与剪影优先一脉相承。

### 中置信度

5. **场景光照/PBR 正确性**：PMREM/IBL 反射一致性（环境贴图强度与材质匹配）；月光/火光/黄昏的比例与色温以情绪为导向（避免过冷/过热）；无缝平铺 + 合理 tiling（防明显重复）。

6. **Godot 4 迁移对照**：
   - **直接等价**：PBR 参数（metalness/roughness）→ SpatialMaterial；IBL → WorldEnvironment（HDRI）；SSAO → Godot 内置 SSAO；雾 → Fog。
   - **要换实现**：自定义后处理链（Godot 用后处理节点/Shader）、节点化材质（多层清漆需自定义 ShaderMaterial）、体积雾（Godot 用体积材质/雾体积，思路不同）。

---

## Project Documentation Reviewed

| 文件 | 相关发现 | 可靠性 |
|---|---|---|
| `build/scenes/_shared/SCENE-SPECS.md` | 已有剪影优先/材质分区/emissive 克制/三灯栈，但无 PBR 真实取值/SSS/磨损/后期取舍/构图 | RELIABLE |
| `build/glb-models/_shared/helpers.mjs` | 37 个材质/纹理工厂；材质以语义命名（ember/steel/jade…），roughness/metalness 已是合理区间；**无** AO/粗糙度变化贴图、无边缘倒角辅助、无磨损辅助 | RELIABLE |
| `.claude/skills/ashen-hollow-dev/references/` | glb-batch-export：低模风格化占位/剪影/人形脚底 y=0；viewer-and-vlm：VLM 比对剪影/配色 | RELIABLE |

**结论：材质基础已合理，缺的是"真实感增量"——程序化 AO/粗糙度变化/磨损、金属倒角+清漆、SSS 近似、后期克制、构图纪律。**

---

## Sources

Perplexity 两轮回答内嵌引用（无独立可点击 URL 明细，置信度标注在回答中）：三维材质工作原理、SSS 近似、程序化噪声与环境贴图、金属/清漆/边缘倒角、划痕磨损、后期 Bloom/DOF/体积雾/色差实务、魂系审美取向、Godot 4 渲染管线与材质体系。

---

## Contradictions & Gaps

- **"风格化写实"与"真实感"的边界**：研究强调魂类应走风格化写实，与"更真实"的字面需求有张力——本报告将"真实感"定义为**材质响应正确 + 质感细节 + 克制后期**，而非照片级。
- **normal map 程序化**：回答建议"噪声→法线"，但 DataTexture 程序化烘焙切线空间法线对 GLTFExporter 可行度未验证——落地时先用 AO/粗糙度变化（安全），法线变化次之。
- **Godot 侧**：本次聚焦 three.js 资产/场景管线，Godot 移植为预留方向，未深挖 Shader 实现。

---

## Recommendations（落地清单）

1. **SCENE-SPECS 新增「真实感」章节**（精雕 agent 强制执行）：
   - 材质 PBR 真实取值表（skin/fabric/leather/bone/metal/glass/ghost 的 roughness/metalness/clearcoat/transmission）。
   - SSS 廉价替代（ghost/皮肤：transmission + 边缘光）。
   - 金属边缘倒角 + clearcoat；划痕/锈蚀只做边缘加强。
   - 后期参数（Bloom 0.6–1.0/高阈值、微颗粒、弱晕影、禁过量 DOF）；构图 leading lines + 焦点。
2. **scene-helpers.mjs**：新增 `texAO`/`texRoughVar`（噪声粗糙度变化，配合 roughnessMap）、金属 `clearcoat` 材质工厂、`bevel` 边缘倒角辅助。
3. **glb-models/_shared/helpers.mjs**：为角色/物品新增 AO 变化 + 磨损分层纹理工厂 + bevel 辅助（下一轮 GLB 迭代用）。
4. **精雕 agent 提示词**：每模型/场景按真实感清单自检（材质真实取值、SSS 近似、磨损、后期克制、构图）。
5. **后续**：真实感升级与穿模纪律（`docs/research/2026-08-03-procedural-placement-interpenetration.md`）一起编入 SCENE-SPECS，作为精雕阶段的双重纪律。

---

## Search Coverage

- **查询 1**（pro, zh）：5 题——角色/怪物、物品、场景、程序化管线预期、Godot 迁移。
- **follow_up**（同线程）：补齐 3b（后期取舍+构图）、4（程序化预期+取舍）、5（Godot 对照）。
- **Phase 0**：项目扫描确认已有材质/光照基础与缺失项（见上表）。
- 未做 deep_research（实操综述，pro+follow_up 已够）。
