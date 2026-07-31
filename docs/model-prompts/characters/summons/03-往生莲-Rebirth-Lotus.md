---
名称: 往生莲（Rebirth Lotus）
类别: 召唤物
目标格式: GLB (Godot 4.7.1)
参考尺寸: 约 0.6m(静止悬浮莲)
源文档: ../characters/classes/invocation-master.md
---

## 一句话概述

祝祷师以往生灵符召唤的静止莲花,佛门往生意象;不移动不攻击,只立于原地以莲心脉动对 6m 半径内群体回血,是固定治疗点型召唤物。

## 视觉描述

- **体型/比例:** 一朵盛开的莲花灵体,茎自下淡去隐入虚空,花盘约成人两掌大小,剪影圆润。
- **服装/甲胄:** 无衣物——多层莲瓣层叠绽放,外瓣半透、内瓣凝实。
- **武器/道具:** 花心托一炷往生香火(细烟袅袅);花瓣间渗金色功德微光。
- **标志性特征:** 莲心脉动发光如心跳;花瓣每层缓缓开合;淡淡金粉随脉动飘散。
- **配色:** 主色月白 + 莲粉,辉光烬火橙红 + 暖金功德光。
- **姿态参考:** 悬浮于空、花瓣舒张,花心朝上接受天光。

## 图片生成提示词

```
Rebirth Lotus, full body, front view, standing, blooming lotus flower spirit with layered luminous petals and gentle merit light, golden pollen motes, floating above ground, ember glow, pale gold and rose pink with ember-orange accents, translucent petal and luminous light materials, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** LOD0 ~3k tris / LOD1 ~2k;无骨骼,整朵莲可作单一网格 + 顶点动画。
- **挂点/Socket:** 召唤根节点(悬浮点)、花心 `weapon_tip`(回血光环特效原点)。
- **碰撞:** 淡胶囊 ~0.4m 半径 × 0.6m 高;可被敌方波及但无主动攻击。
- **贴图:** 2K Base/Normal/Roughness;花瓣用半透明 + 次表面散射感(Roughness 中),功德光用 Emission。
- **动画/骨骼:** 无骨架;用 Shader/顶点做莲瓣开合 + 花心脉动 + 金粉粒子。

## 出处

- 设计文档:`docs/characters/classes/invocation-master.md`(灵符召唤表,链接)
- 代码挂点:`game/scripts/enemy_factory.gd`(召唤物工厂参照)
