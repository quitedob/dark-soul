---
名称: 嫁衣女鬼（Wedding Gown Ghost）
类别: 敌人
目标格式: GLB (Godot 4.7.1)
参考尺寸: 约 1.8m 的红嫁衣新娘鬼(悬浮)
源文档: ../bestiary/enemies-master.md
---

## 一句话概述

第三章狐嫁道的鬼类精英,婚礼当天死去的新娘,永恒地披红嫁衣在森林中行进。HP 90、速度 6.0(仅送亲时),嚎哭声能使听到的玩家麻痹 5s,随后扑上来施加毁灭性的拥抱;只能靠潜行躲避。

## 视觉描述

- **体型/比例:** 约 1.8m 的新娘鬼,身形修长漂浮,剪影是"长发覆面的红嫁衣女鬼"。
- **服装/甲胄:** 鲜红嫁衣(秀禾/凤冠霞帔),宽袖广摆,拖曳长后摆,衣角如烟飘散。
- **武器/道具:** 无手持武器,攻击为扑抱与嚎哭。
- **标志性特征:** 长黑发完全覆面,发缝中露出一点惨白与幽蓝鬼火眼;嫁衣血红、边缘半透明。
- **配色:** 血红嫁衣 + 幽蓝鬼火 + 微弱烬火橙点缀。
- **姿态参考:** 双臂前伸、漂浮前行的姿态;嚎哭时头部上扬、张口状态需单独做形变。

## 图片生成提示词

```
Wedding Gown Ghost, full body, front view, floating, spectral bride in a red wedding gown, long black hair shrouding her face, wailing open mouth, red bridal veil and tassels, blood red and ghost-blue palette with faint ember glow, silk and translucent spirit materials, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** LOD0 ~7k tris / LOD1 ~3.5k;嫁衣与长发做飘摆动画或布料模拟。
- **挂点/Socket:** `ExecutionAnchor`(处决锚点)设胸腔;嚎哭 VFX 挂 `wail_aura` 空节点(口部)。
- **碰撞:** 细胶囊(CapsuleShape3D,半径 0.35,高 1.8);精英建议独立 `CollisionShape3D`。
- **贴图:** 2K,Alpha 半透明衣摆;嫁衣红用深色丝绸,幽蓝鬼火用 Emission。
- **动画/骨骼:** 约 20 根骨骼;重点：送亲行进、嚎哭(口部形变)、扑抱三态,保持 `enemy_factory.gd` 命名。

## 出处

- 设计文档:`../bestiary/enemies-master.md`
- 章节文档:`../chapters/03-jade-veil/chapter-overview.md`
- 代码挂点:`game/scripts/combat/chapter_3_enemy_factory.gd`
