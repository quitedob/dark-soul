---
名称: 贪烬鬼（Ember-Greedy Ghost）
类别: 敌人
目标格式: GLB (Godot 4.7.1)
参考尺寸: 约 2.0m(比玩家高的鬼类精英,可悬浮)
源文档: ../../chapters/03-jade-veil/chapter-supplement.md
---

## 一句话概述

第三章镜花水月亭(3-4)断桥的鬼类精英,出自支线 4「桥头的供茶」——以"爱"为饵、专榨孤独灵魂的掠食者,披着偷来的"挚爱面容"当作面具,把猎物的烬一点点吸干直到空壳。现身时先以镜面幻影与"爱之饵"诱骗玩家,随后用吸烬之爪抓取榨取;需真相视觉看穿幻影,命中胸口烬核可令其暴露硬直。

## 视觉描述

- **体型/比例:** 约 2.0m 的高瘦悬浮鬼影,身形拉长飘浮,剪影是"披面长袍的浮空鬼"。
- **服装/甲胄:** 残破的嫁衣红/暗色长袍,衣角与半边身躯正溶解成灰烬;脸上罩着一片柔软丝绸面具/面纱,绘着一张美丽的"挚爱面容"。
- **武器/道具:** 无手持武器,双手即武器——修长抓握的利爪;身后拖曳着被吸干的烬灰烟迹。
- **标志性特征:** 温柔美丽的面具与面具下空洞獠牙的饕餮巨口形成强烈反差;胸口一枚烬核若隐若现、随吸蚀逐渐暗淡。
- **配色:** 灰烬灰/虚空黑的半透明躯干 + 一抹骗人的暖玫瑰红(面具) + 濒死的烬橙内核辉光。
- **姿态参考:** 双臂前伸如拥抱、再转为抓握,身体前倾飘浮逼近;面具卸下/换脸的咬噬态需单独做形变。

## 图片生成提示词

```
Ember-Greedy Ghost, full body, front view, floating, tall specter in dissolving dark tattered robes, elegant silk mask with a beautiful serene face, beneath the mask a hollow ravenous maw, long grasping claws, drained ember ashes trailing, faint dying ember glow in the chest, ash-grey and void-black with a deceptive rose-red mask and ember-orange accents, translucent spirit materials, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** LOD0 ~7k tris / LOD1 ~3.5k(精英预算);长袍与灰烬烟迹做飘摆动画或粒子。
- **挂点/Socket:** `ExecutionAnchor`(处决锚点)设胸腔;弱点击破锚点 `core_ember`(胸口烬核——命中可使其暴露硬直);`grab_anchor`(右手——吸烬抓取的 VFX 与判定挂点)。
- **碰撞:** 细胶囊(CapsuleShape3D,半径 0.4,高 2.0);精英建议独立 `CollisionShape3D`。
- **贴图:** 2K,身体用半透明材质(Alpha 溶解),烬核与面具辉光用 Emission。
- **动画/骨骼:** 约 22 根骨骼;重点:漂移待机、拥抱-抓取、吸蚀(躯干前倾+手部抓握),面具可选"换脸"形变;保持 `enemy_factory.gd` 命名。

## 出处

- 设计文档:`../../chapters/03-jade-veil/chapter-supplement.md`(支线 4 · 桥头的供茶)
- 章节文档:`../../chapters/03-jade-veil/chapter-overview.md`
- 代码挂点:`game/scripts/combat/enemy_factory.gd`(精英 id `elite_ember_greed_ghost`,出没于 `level_03_04` 镜花水月亭)
