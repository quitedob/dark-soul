---
名称: 守阁仙魂（Library Guardian Spirit）
类别: 敌人
目标格式: GLB (Godot 4.7.1)
参考尺寸: 约 2.2m,高于玩家
源文档: ../bestiary/enemies-master.md, ../chapters/04-celestial-fall/chapter-overview.md
---

## 一句话概述

仙堕精英,4-3 藏经阁守护者——藏书修士之魂,吸收了无数武学典籍。AI 每 20s 切换一次镜像四职业的打法(狂战士/玄法师/神射手/祝祷师),对该职业抗性、对另一类增伤;血量 130、伤害 32。

## 视觉描述

- **体型/比例:** 人形、约 2.2m,身形修长挺拔,如饱读经卷的修士立于书阁之间。
- **服装/甲胄:** 墨蓝长袍外罩半透明云纹帔巾,广袖、束带,袍面浮动经文;无甲。
- **武器/道具:** 常持竹简卷轴/青玉拂尘,随当前镜像职业切换显现对应武器虚影(双斧/法印/弓/念珠)。
- **标志性特征:** 头顶悬浮一册发光典籍,随职业切换改变辉光色;切换时周身书页环绕闪现。
- **配色:** 墨蓝袍 + 宣纸白,辉光烬橙;职业切换辉光:红(狂战士)/青(玄法师)/金(神射手)/白(祝祷师)。
- **姿态参考:** 正面端立、广袖微张;职业切换是动画分镜的高光时刻。

## 图片生成提示词

```
Library Guardian Spirit, full body, front view, standing, tall spectral scholar-cultivator in flowing ink-blue librarian robes, hooded translucent head with glowing ember eyes, long bamboo scroll staff, floating weapon auras shifting between twin axes bow and spell seal, drifting glowing scripture ribbons, ink-blue and parchment-white color palette, spectral cloth and paper materials, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** LOD0 7k tris / LOD1 3.5k;四种武器虚影各 400–600 tris(可复用玩家武器库模型)。
- **挂点/Socket:** 右手 `weapon_tip`(当前武器虚影挂点,随切换换装);头顶 `book_focus`(发光典籍)。
- **弱点击破锚点:** 切换职业瞬间(约 0.8s)周身书页散去,是该镜像抗性窗口,建模需保留书页环绕的换装层。
- **碰撞:** 胶囊(0.4m × 2.1m)。
- **贴图:** 2K Base/Normal/Roughness/Metalness;袍面经文与辉光用 Emission,按职业切换色。
- **动画/骨骼:** 单人形骨架;需额外 4 套武器持握姿势与"书页环绕→散开"的切换过渡动画。

## 出处

- 设计文档:`../bestiary/enemies-master.md`(Chapter 4 守阁仙魂)、`../chapters/04-celestial-fall/chapter-overview.md`(4-3 藏经阁)
- 代码挂点:替换 `enemy_factory.gd` 时保持 `weapon_tip` / `book_focus` 命名
