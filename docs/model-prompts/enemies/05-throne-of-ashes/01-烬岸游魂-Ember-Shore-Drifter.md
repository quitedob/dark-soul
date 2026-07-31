---
名称: 烬岸游魂（Ember Shore Drifter）
类别: 敌人
目标格式: GLB (Godot 4.7.1)
参考尺寸: 约 1.8m,与玩家相近
源文档: ../bestiary/enemies-master.md, ../chapters/05-throne-of-ashes/chapter-overview.md
---

## 一句话概述

失魂类无害游魂,5-1 烬海之岸上无尽无声漂向烬座的灵魂河流。AI 完全不主动攻击,被攻击才变敌对;血量 50、伤害 0;误杀无辜灵魂会累积**业报**(终局 Boss 额外谴责对白)。

## 视觉描述

- **体型/比例:** 人形、约 1.8m,半透明,剪影柔和模糊,无实体感。
- **服装/甲胄:** 破旧的素色布衣/麻袍,飘散如入水织物,无甲;衣料被风吹向身后。
- **武器/道具:** 无;双手自然垂落、十指微张。
- **标志性特征:** 全身泛柔和青白魂光,胸口一点烬火橙光(未熄的余烬);面容安详、无攻击性。
- **配色:** 烬灰 + 魂河青白荧光,胸口一点烬橙;整体低饱和、克制的"将熄"气质。
- **姿态参考:** 正面微飘、脚不沾地,缓缓顺流漂移;受击时应呈现悲怆而非暴怒。

## 图片生成提示词

```
Ember Shore Drifter, full body, front view, hovering, peaceful translucent soul drifting forward, wearing tattered grey funeral robes, calm empty expression, arms loosely at sides, soft ember-orange glow in chest, faint soul-river motes trailing behind, ash grey and pale blue-white color palette, translucent spirit and ember-glow materials, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** LOD0 3k tris / LOD1 1.5k;半透明角色面数从简。
- **挂点/Socket:** 胸口 `core_point`(烬火辉光);可加 `GrabbedAnchor`(若被抓投表现)。
- **碰撞:** 胶囊(0.35m × 1.75m),偏小以降低"误触误杀"风险。
- **贴图:** 1K Base/Normal/Roughness + 强 Alpha(半透明);胸口烬火用 Emission。
- **动画/骨骼:** 单人形骨架,浮空漂移动画(无走路);被攻击有受击/消散两段,替代死亡。

## 出处

- 设计文档:`../bestiary/enemies-master.md`(Chapter 5 烬岸游魂)、`../chapters/05-throne-of-ashes/chapter-overview.md`(5-1 烬海之岸)
- 代码挂点:替换 `enemy_factory.gd` 时保持 `core_point` 命名
