---
名称: 檀香念珠与往生符（Sandalwood Beads and Talisman）
类别: 武器
目标格式: GLB (Godot 4.7.1)
参考尺寸: 珠串长约 0.6m,下垂符纸长约 0.4m
源文档: ../../systems/weapons-compendium.md
---

## 一句话概述

> 祝祷师初始武器,檀香念珠 + 往生符,诵经祝祷法器;FTH C 加成,施法时珠串悬于掌前、符纸随之轻扬。

## 视觉描述

- **造型:** 一串深色檀香木念珠(主珠 108 粒),串口缀一枚小青铜法器(金刚杵式);串尾系两张窄长黄符纸(往生符),朱砂符文朝下。
- **材质:** 檀木(哑光)+ 红绳 + 黄纸符 + 暗铜法器;珠粒颗粒感明显,使用多年已磨圆。
- **辉光:** 符文与法器尖端泛极淡烬火橙红;念珠本身无光。
- **尺寸:** 珠串总长约 0.6m,符纸下垂约 0.4m。
- **握持方式:** 单手持珠(手部挂点于串口),珠串自然垂挂或悬于掌前,施法时符纸无风自扬。

## 图片生成提示词

```
A single prayer tool prop, front view, hanging vertically. A strand of sandalwood prayer beads with dark round beads, a red rebirth charm paper and a small bronze pendant at the bottom, faint ember glow on the charm characters, worn cloth tassel.
game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** LOD0 ~2k tris(108 珠以少量高面珠 + 实例化替代,或降为 27 珠做视觉近接);LOD1 ~1k。
- **挂点/Socket:** `weapon_tip` 置于串口法器前方(祝祷特效);手部挂点于串口;符纸与珠串做轻微摆动动画(次级绑定)。
- **碰撞:** 念珠串用细盒/胶囊;符纸无碰撞。
- **贴图:** 2K;檀木哑光粗糙,符文 Emission(低);黄纸 Base/Normal。
- **动画:** 珠串随动作摆动、符纸飘动;保持现有手部姿势挂点。

## 出处

- 设计文档:`docs/systems/weapons-compendium.md`(祝祷师起始武器)
- 代码挂点:`game/scripts/core/weapon_meshes.gd`(`prayer_beads` / `talisman_papers` shape_id)
