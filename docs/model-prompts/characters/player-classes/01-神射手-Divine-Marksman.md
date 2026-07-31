---
名称: 神射手（Divine Marksman）
类别: 玩家角色
目标格式: GLB (Godot 4.7.1)
参考尺寸: 1.0 × 玩家(身高 ~1.8m,胶囊高 ~1.8)
源文档: ../characters/classes/divine-marksman.md
---

## 一句话概述

玻璃大炮型远程输出职业,以羿弓术(后羿射日)进行中远距离精确射击;轻皮甲脆弱身板,猎风弓 + 猎刀,元素箭赋予火焰/冰霜/雷电/灵属性伤害,近身依赖闪避与猎刀应急。

## 视觉描述

- **体型/比例:** 中等偏瘦、身高略高于平均,四肢修长、剪影纤细,强调敏捷而非厚重。
- **服装/甲胄:** 轻皮甲(多层束带皮衣 + 肩片)、羽冠(饰羽长翎)、弓手护腕(前臂皮质护腕,绘羽纹)。
- **武器/道具:** 主手猎风弓(木质复合弓,弓弦泛烬火微光)、副手猎刀(腰间短刀);腰间挂后羿羽饰(羽毛符坠)。
- **标志性特征:** 烬火橙红的弓弦与箭镞辉光;胸前淡淡的轮回印微光烙印;羽冠拖曳长翎形成上扬剪影。
- **配色:** 主色灰棕皮甲 + 骨白,辉光烬火橙红。
- **姿态参考:** 站姿持弓侧身、拉弦待发;挂点用弓体 pivot 与箭镞 `weapon_tip`。

## 图片生成提示词

```
Divine Marksman, full body, front view, standing, agile archer in light layered leather armor with feather crown, glowing ember bowstring on drawn longbow, hunter dagger at hip, rebirth seal on chest, ash gray and leather brown with ember-orange accents, worn leather and bone materials, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** LOD0 ~8k tris / LOD1 ~4k;弓与猎刀可并入主网格或独立低模件。
- **挂点/Socket:** 弓体 `weapon_tip`(箭镞/元素箭特效)、右手主手挂点、左手副手猎刀挂点、`ExecutionAnchor`(处决)、`GrabProfile` 捕获形状。
- **碰撞:** 玩家胶囊 ~0.6m 半径 × 1.8m 高;武器盒碰撞。
- **贴图:** 2K Base/Normal/Roughness/Metalness;弓弦与箭镞烬火辉光用 Emission;轮回印用低强度自发光贴花。
- **动画/骨骼:** 标准人形骨架(替换 `character_meshes.gd` 时保持挂点命名);需拉弓/蓄力/翻滚/后退射击姿势。

## 出处

- 设计文档:`docs/characters/classes/divine-marksman.md`(链接)
- 代码挂点:`game/scripts/character_meshes.gd` / `weapon_meshes.gd`(占位工厂,替换时保持挂点)
