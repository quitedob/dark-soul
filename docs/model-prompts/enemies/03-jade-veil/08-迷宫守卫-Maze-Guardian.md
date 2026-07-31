---
名称: 迷宫守卫（Maze Guardian）
类别: 敌人
目标格式: GLB (Godot 4.7.1)
参考尺寸: 约 2.4m 长的卧狮玉雕像(活物化)
源文档: ../bestiary/enemies-master.md
---

## 一句话概述

第三章九尾迷宫的"精"类精英,雕刻成卧狮形态、被幻烬唤醒的玉质雕像,守卫迷宫。HP 120、速度 2.0,靠近前静止不动,发动长距离重扫;连击 3 次后会失衡停 2s(输出窗口)。

## 视觉描述

- **体型/比例:** 约 2.4m 长的卧狮玉雕,四肢粗壮、身形敦实,剪影是"张口的中国石狮(狻猊)"。
- **服装/甲胄:** 无甲胄;通体为抛光青白玉石,鬃毛与鬣毛如翻卷的玉浪,表面带温润包浆。
- **武器/道具:** 无手持武器,攻击为扑扫与冲撞。
- **标志性特征:** 玉狮张口咆哮的姿态,眼窝处透出玉色辉光,石缝中缕缕烬火橙光。
- **配色:** 青白玉 + 月光银蓝 + 微弱烬火橙。
- **姿态参考:** 卧狮立起、前扑的猎杀姿态;静止时需有"盘踞卧狮"的待机形。

## 图片生成提示词

```
Maze Guardian, full body, side-front view, lunging guard pose, animate jade lion statue, carved guardian lion with flowing mane, polished pale green jade stone, jade patina highlights, moonlight silver and jade green palette, faint ember glow, polished jade and stone materials, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** LOD0 ~8k tris / LOD1 ~4k;鬃毛卷曲用低模块表现,贴图补细节。
- **挂点/Socket:** `ExecutionAnchor`(处决锚点)设胸口/颈部;精英建议独立 `CollisionShape3D`。
- **碰撞:** 四足盒/胶囊(BoxShape3D,约 1.6×1.2×0.9,卧狮俯仰)。
- **贴图:** 2K,玉质用 Roughness 低、Specular 高;眼窝与石缝烬光用 Emission。
- **动画/骨骼:** 约 20 根骨骼;重点是卧狮待机、前扑重扫、失衡后仰三态,保持 `enemy_factory.gd` 命名。

## 出处

- 设计文档:`../bestiary/enemies-master.md`
- 章节文档:`../chapters/03-jade-veil/chapter-overview.md`
- 代码挂点:`game/scripts/combat/chapter_3_enemy_factory.gd`
