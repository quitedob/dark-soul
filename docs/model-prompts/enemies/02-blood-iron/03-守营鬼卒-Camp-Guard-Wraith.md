---
名称: 守营鬼卒（Camp Guard Wraith）
类别: 敌人
目标格式: GLB (Godot 4.7.1)
参考尺寸: 约 1.85m 的魁梧重盾兵人形
源文档: ../bestiary/enemies-master.md
---

## 一句话概述

第二章俘虏营的失魂精英兵,负责看守俘虏营,纪律严明。HP 100、速度 2.5,举重盾正面推进、正面减伤,短暂放盾时是 1s 攻击窗口,重击破盾 8 次可破防。

## 视觉描述

- **体型/比例:** 约 1.85m 的魁梧人形,肩宽体厚,剪影是"举塔盾的守门武士"。
- **服装/甲胄:** 完整度较高的铁制札甲(lamellar),厚重兜鍪护头,肩披战旗布条,纪律感的整齐甲片。
- **武器/道具:** 左手持巨大塔盾,右手持短矛/钉头锤。
- **标志性特征:** 半透明游魂体,盾面刻有磨损的守军徽记,甲缝中泄出烬火橙红微光。
- **配色:** 幽蓝游魂 + 铁灰 + 烬火橙红辉光。
- **姿态参考:** 举盾缓慢推进、放盾挥击交替;盾面朝向即碰撞/减伤方向。

## 图片生成提示词

```
Camp Guard Wraith, full body, front view, standing guard, disciplined spectral soldier holding a heavy tower shield, robust iron lamellar armor, protective helmet, tattered banner cloth, weathered steel and dark leather materials, ghost-blue and iron gray palette with ember glow, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** LOD0 ~8k tris / LOD1 ~4k,盾+甲为体积主体。
- **挂点/Socket:** 左手 `shield_anchor`(塔盾挂点)、右手 `weapon_tip`(钉头锤),`ExecutionAnchor`(处决锚点)设胸腔/背甲。
- **碰撞:** 躯干胶囊 + 独立盾盒碰撞(CollisionShape3D 挂盾上),正面减伤以盾朝向判定。
- **贴图:** 2K,Base/Normal/Roughness/Metalness;盾面徽记与烬光用 Emission。
- **动画/骨骼:** 约 24 根骨骼;举盾/放盾两套攻击切换,保持 `enemy_factory.gd` 命名。

## 出处

- 设计文档:`../bestiary/enemies-master.md`
- 章节文档:`../chapters/02-blood-iron/chapter-overview.md`
- 代码挂点:`game/scripts/combat/chapter_2_enemy_factory.gd`
