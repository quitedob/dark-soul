---
名称: 战犬亡魂（War Dog Wraith）
类别: 敌人
目标格式: GLB (Godot 4.7.1)
参考尺寸: 肩高约 0.8m 的四足猎犬身形
源文档: ../bestiary/enemies-master.md
---

## 一句话概述

第二章铁啸关的鬼类猎犬,生前为关隘军队服役的狩猎犬。HP 40、速度 7.0,总是成对出现:一只绕圈牵制、另一只扑咬;若同伴被杀,剩余一只会狂暴(+30% 速度 +20% 伤害 15s)。

## 视觉描述

- **体型/比例:** 四足猎犬身形,肩高约 0.8m,身形精瘦修长,剪影是"压低俯冲的幽灵犬"。
- **服装/甲胄:** 残留的皮革战项圈与残破鞍鞯/披甲布片。
- **武器/道具:** 无手持武器,攻击为撕咬与利爪。
- **标志性特征:** 半透明幽蓝鬼体,口中泄出鬼火余烬,眼窝两点烬火橙红,口鼻处獠牙泛微光。
- **配色:** 幽蓝鬼体 + 灰烬灰 + 烬火橙红眼/口火。
- **姿态参考:** 前压扑咬姿态;需支持侧身绕圈跑动的动画状态。

## 图片生成提示词

```
War Dog Wraith, full body, side-front view, crouched hunting stance, spectral hunting hound, translucent ghost-blue body, tattered leather war collar and barding, glowing ember-orange eyes, sharp spectral fangs, ghost-blue and ash palette, semi-transparent wispy materials, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** LOD0 ~5k tris / LOD1 ~2.5k,四足低模,半透明 Blend 渲染。
- **挂点/Socket:** 无武器;`ExecutionAnchor`(处决锚点)设脖颈;四足地面锚点。
- **碰撞:** 四足胶囊/盒(CapsuleShape3D,长约 1.2,高 0.7,俯仰放置)。
- **贴图:** 2K,Alpha 半透明;口鼻/眼用 Emission(烬橙)。
- **动画/骨骼:** 约 18 根骨骼(四足+尾+颈+头);成对绕圈由 AI 控制,模型只需 idle/扑咬/绕圈三种状态,保持 `enemy_factory.gd` 命名。

## 出处

- 设计文档:`../bestiary/enemies-master.md`
- 章节文档:`../chapters/02-blood-iron/chapter-overview.md`
- 代码挂点:`game/scripts/combat/chapter_2_enemy_factory.gd`
