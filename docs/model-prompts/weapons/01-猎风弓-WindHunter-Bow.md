---
名称: 猎风弓（Wind-Hunter Bow）
类别: 武器
目标格式: GLB (Godot 4.7.1)
参考尺寸: 全长约 1.35m(相对 1.8m 玩家),竖持时弓梢与肩齐平
源文档: ../../systems/weapons-compendium.md
---

## 一句话概述

> 神射手初始武器,骨木反曲长弓,弓梢缀后羿式白羽饰;DEX C 加成,基础伤害 18,远程平射主力。

## 视觉描述

- **造型:** 反曲长弓,弓臂为弧线双层结构,两端向上卷曲并各系一撮白色猎隼尾羽;握把处缠皮绳,弓臂外侧刻浅淡的猎风旋纹。
- **材质:** 深色骨木(牛角贴片夹层)+ 兽筋绞丝弓弦;羽饰为纯白翎毛,金属弓梢为暗铜。
- **辉光:** 微弱烬火橙红——仅握把接缝与两弓梢尖各一点,克制、不抢主体。
- **尺寸:** 全长约 1.35m,弓臂最宽约 0.75m,适合双手拉弓。
- **握持方式:** 左手持弓把(手部挂点),右手拉弦;箭矢备用时斜插于弓侧。

## 图片生成提示词

```
A single longbow weapon prop, front view, floating diagonally. Recurve composite bow of dark bone-wood with horn tips, white falcon feather ornament tied at each limb end, thin sinew bowstring, faint ember-orange glow along the grip and limb tips, weathered carvings of wind.
game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** LOD0 ~1.5k tris(两段弓臂弧 + 弦 + 羽饰);LOD1 ~0.8k。
- **挂点/Socket:** `weapon_tip` 置于弓梢前上方(箭矢与瞄准特效);握把处手部挂点(左手持弓);弓身碰撞用细长盒(Capsule 亦可)包住弓臂轮廓。
- **贴图:** 2K;Base/Normal/Roughness/Metalness;羽饰白+暗铜,辉光用 Emission(橙红,能量低)。
- **动画:** 弦沿弓臂法线做拉弦位移,弓臂可做轻微弯曲形变。

## 出处

- 设计文档:`docs/systems/weapons-compendium.md`(神射手起始武器)
- 代码挂点:`game/scripts/core/weapon_meshes.gd`(`bow` shape_id)
