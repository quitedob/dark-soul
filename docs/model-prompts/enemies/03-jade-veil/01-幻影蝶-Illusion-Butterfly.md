---
名称: 幻影蝶（Illusion Butterfly）
类别: 敌人
目标格式: GLB (Godot 4.7.1)
参考尺寸: 翅展约 1m 的大型蝶
源文档: ../bestiary/enemies-master.md
---

## 一句话概述

第三章翠微林的妖类敌人,玉青绿翅的幻蝶,会抖落致幻粉尘。HP 25、速度 3.0,单个无害,成群后危险——死亡时爆出 3m 粉尘云使玩家操作反转 5s。

## 视觉描述

- **体型/比例:** 翅展约 1m 的大型蝶,身形纤细妖冶,剪影是"展开玉翅的蝶"。
- **服装/甲胄:** 无甲胄;身体为纤细的精灵般虫身。
- **武器/道具:** 无武器,攻击为抖落的致幻粉尘。
- **标志性特征:** 玉青绿半透明翅,翅脉发光如镂空玉石;飞行时拖出荧荧的粉尘光带。
- **配色:** 月光银蓝 + 玉青绿 + 微弱烬火橙光点缀。
- **姿态参考:** 悬停展翅姿态;死亡时需粉尘爆散 VFX 挂点。

## 图片生成提示词

```
Illusion Butterfly, full body, front view, hovering, large elegant butterfly with translucent jade-green wings, luminous wing vein patterns, glowing pollen dust trailing, slender ethereal body, moonlight silver and jade green palette, faint ember glow, translucent iridescent wing materials, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** LOD0 ~4k tris / LOD1 ~2k;翅面用半透明材质,粉尘为粒子系统。
- **挂点/Socket:** 无武器;翅根摆动用骨骼,死亡粉尘 VFX 挂 `dust_burst` 空节点。
- **碰撞:** 小盒碰撞(BoxShape3D,约 0.5×0.3×0.1),实体极小。
- **贴图:** 2K,Alpha 半透明;翅脉用 Emission(玉青绿),粉尘粒子用自发光材质。
- **动画/骨骼:** 约 10 根骨骼(翅扇动);悬停/扑飞/死亡爆尘三种状态,保持 `enemy_factory.gd` 命名。

## 出处

- 设计文档:`../bestiary/enemies-master.md`
- 章节文档:`../chapters/03-jade-veil/chapter-overview.md`
- 代码挂点:`game/scripts/combat/chapter_3_enemy_factory.gd`
