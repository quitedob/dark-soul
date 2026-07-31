---
名称: 金甲力士（Golden-Armored Guardian）
类别: 召唤物
目标格式: GLB (Godot 4.7.1)
参考尺寸: 约 2.2m(巨体守卫,高于玩家)
源文档: ../characters/classes/invocation-master.md
---

## 一句话概述

祝祷师以金甲灵符召唤的护法力士,金刚护法形象;高防御肉盾,以巨大塔盾挡弹幕、拦敌路,是替主人吃伤害的铜墙铁壁型召唤物。

## 视觉描述

- **体型/比例:** 魁梧高大的力士,体宽约为玩家两倍,敦实如庙宇金刚,剪影厚重。
- **服装/甲胄:** 亮金鳞甲 + 护心镜,兽首肩吞,束腰革带,头戴翼冠兜鍪,赤膊下臂缠铁腕。
- **武器/道具:** 左手巨塔盾(镶兽面,盾面泛金光)、右手长柄金瓜锤。
- **标志性特征:** 全身金光灌注的甲胄微光;盾立时如一堵金墙;胸口护心镜燃着一团烬火。
- **配色:** 主色亮金 + 古铜,辉光烬火橙红 + 金光。
- **姿态参考:** 站姿持盾护前、举锤戒备,纹丝不动如金刚怒目。

## 图片生成提示词

```
Golden Armored Guardian, full body, front view, standing, massive muscular protector in gleaming gold lamellar armor with winged helmet, holding a huge tower shield and long staff, glowing golden aura, gold and bronze with ember-orange accents, polished metal and leather materials, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** LOD0 ~4k tris / LOD1 ~2k;塔盾与锤为独立道具件。
- **挂点/Socket:** 召唤根节点(脚下)、左手盾挂点 + 盾面 `weapon_tip`(格挡/光盾特效)、右手锤挂点。
- **碰撞:** 胶囊 ~0.7m 半径 × 2.2m 高;盾可作独立阻挡盒(挡弹)。
- **贴图:** 2K Base/Normal/Roughness/Metalness;金甲高 Metalness,护心镜烬火用 Emission。
- **动画/骨骼:** 人形骨架(略放大);需站定举盾/格挡/挥锤/被击退循环。

## 出处

- 设计文档:`docs/characters/classes/invocation-master.md`(灵符召唤表,链接)
- 代码挂点:`game/scripts/enemy_factory.gd`(召唤物工厂参照)
