---
名称: 修罗（Asura）
类别: 玩家角色
目标格式: GLB (Godot 4.7.1)
参考尺寸: 1.0 × 玩家(身高 ~1.8m,胶囊高 ~1.8)
源文档: ../characters/classes/README.md
---

## 一句话概述

狂战士 + 神射手的混合职业(第三章后解锁),近中程凶残输出;以双刀逼近血刃,配合短弓补射追击,把刑天之怒与羿箭之准揉成一台不停机的杀戮机器。

## 视觉描述

- **体型/比例:** 精悍肌肉、身高中等偏上,战甲轻量化、四肢裸露,剪影紧凑锋利如猎豹。
- **服装/甲胄:** 鳞甲护心 + 皮甲肩带、战鬼面改半开(露口部便于狞笑)、铁腕甲,披兽皮肩披。
- **武器/道具:** 主手双持弯刀(修罗双刃,刃带血槽红纹)、背上短猎弓 + 箭袋;腰间挂刑天血石与羽饰。
- **标志性特征:** 近战血刃泛猩红;背弓与双刃并存的双重剪影;胸前轮回印微光。
- **配色:** 主色铁灰 + 血红,辉光烬火橙红 + 猩红。
- **姿态参考:** 站姿双刃交叉、重心前倾,随时扑击。

## 图片生成提示词

```
Asura, full body, front view, standing, close-range fighter in mid-heavy scale armor with fur and bone trophies, beast helm, twin curved blades, short hunting bow on back, faint rebirth seal on chest, blood red and iron gray with ember-orange accents, metal and leather materials, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** LOD0 ~8k tris / LOD1 ~4k;双弯刀与短弓为独立武器件。
- **挂点/Socket:** 左右手主手双刀挂点、刀尖 `weapon_tip`、背弓挂点(切换用)、`ExecutionAnchor`、`GrabProfile`。
- **碰撞:** 玩家胶囊 ~0.62m 半径 × 1.8m 高;双刀盒碰撞。
- **贴图:** 2K Base/Normal/Roughness/Metalness;刃槽红纹辉光用 Emission。
- **动画/骨骼:** 标准人形骨架;需双刃连段/跃击/收弓拔刀切换姿态。

## 出处

- 设计文档:`docs/characters/classes/README.md`(混合职业表,链接)
- 代码挂点:`game/scripts/character_meshes.gd` / `weapon_meshes.gd`(占位工厂,替换时保持挂点)
