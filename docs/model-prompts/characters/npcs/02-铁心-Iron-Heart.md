---
名称: 铁心（Iron Heart）
类别: NPC
目标格式: GLB (Godot 4.7.1)
参考尺寸: 约 1.6m(矮于玩家,半透明灵体)
源文档: ../chapters/02-blood-iron/chapter-overview.md
---

## 一句话概述

Ch.2 俘虏营中被救出的灵体铁匠,唯一清醒的魂匠,解救后经烬龛网络迁移,成为常驻的武器锻造 NPC;持锤驻守各烬龛,为玩家强化与打造兵器。

## 视觉描述

- **体型/比例:** 矮壮敦实、微微佝偻,半透明幽蓝灵体隐现骨相,剪影厚重如铁砧。
- **服装/甲胄:** 烧焦的皮围裙 + 破旧铁匠短褂、臂戴护腕皮套,腰间挂钳与量具。
- **武器/道具:** 巨大锻造锤(独眼锤头,锤面泛余烬热光)、脚边悬浮熔炉炭火与铁砧。
- **标志性特征:** 胸口一团炽热烬火核心(燃着不熄);敲击时火星四溅;半透明灵体带铁锈纹理。
- **配色:** 主色铁灰 + 炭黑,辉光烬火橙红(核心) + 幽蓝灵光。
- **姿态参考:** 站姿持锤拄地、微微前倾审视来客;锻造时挥锤姿态。

## 图片生成提示词

```
Iron Heart, full body, front view, standing, gaunt spectral spirit-smith with translucent smoke body and glowing ember core, scorched leather apron, heavy forge hammer over shoulder, faint spectral chains, iron and cinder gray with ember-orange forge glow, rusted metal and soot leather materials, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** LOD0 ~5k tris / LOD1 ~3k;锻造锤为独立道具件。
- **挂点/Socket:** 锤柄手部挂点 + 锤头 `weapon_tip`(锻造火星特效)、对话聚焦点(头部/胸口核心)。
- **碰撞:** 胶囊 ~0.6m 半径 × 1.6m 高;静态 NPC。
- **贴图:** 2K Base/Normal/Roughness;胸口核心与锤面用强 Emission;灵体用半透明材质 + 噪点细节。
- **动画/骨骼:** 人形骨架;需站姿/挥锤锻造/点头对话循环。

## 出处

- 设计文档:`docs/chapters/02-blood-iron/chapter-overview.md`(链接)、`docs/story/main-story.md`
- 代码挂点:`game/scripts/character_meshes.gd`(NPC 复用玩家骨架挂点)
