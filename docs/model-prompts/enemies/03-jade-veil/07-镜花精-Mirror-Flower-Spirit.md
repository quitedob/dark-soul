---
名称: 镜花精（Mirror Flower Spirit）
类别: 敌人
目标格式: GLB (Godot 4.7.1)
参考尺寸: 约 1.5m 的花与镜影融合人形
源文档: ../bestiary/enemies-master.md
---

## 一句话概述

第三章镜花水月亭的妖类敌人,花灵与亭台反射魔法融合的产物,出生即带 3 个模仿其动作的幻象分身。HP 45、速度 4.0;真身花瓣颜色略有差异(可观察的破绽),分身 1 HP、死亡时爆出刺目白光。

## 视觉描述

- **体型/比例:** 约 1.5m 的人形花灵,身形纤秀,剪影是"盛开花瓣托举的镜影人形"。
- **服装/甲胄:** 无甲胄;身体如舒展的玉色花瓣与藤蔓,四肢缀满镜片般的瓣面。
- **武器/道具:** 无手持武器,攻击为挥瓣与镜光。
- **标志性特征:** 花瓣表面如镜面般折射、反射周围景物;真身有一瓣颜色偏移(如朱红),分身纯色。
- **配色:** 玉青绿花瓣 + 银白镜光 + 微弱烬火橙点缀。
- **姿态参考:** 舒展双臂的舞动姿态;需要能同时生成 3 个镜像复刻的分身。

## 图片生成提示词

```
Mirror Flower Spirit, full body, front view, standing, elegant flower spirit fused with mirror magic, humanoid form with blooming petals, mirrored refracted petal surfaces, shimmering light, jade green and silver palette with faint ember glow, petal and mirror-glass materials, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** LOD0 ~5k tris / LOD1 ~2.5k;花瓣低模可复用为分身模型。
- **挂点/Socket:** 无武器;`ExecutionAnchor`(处决锚点)设花心核心;分身由工厂复制本模型并改花瓣材质。
- **碰撞:** 细胶囊(CapsuleShape3D,半径 0.3,高 1.5)。
- **贴图:** 2K,镜面瓣用 Metalness 高值 + 反射,真身朱红瓣用独立材质实例。
- **动画/骨骼:** 约 18 根骨骼;花瓣开合、镜光闪烁;分身完全复刻主模型动作,保持 `enemy_factory.gd` 命名。

## 出处

- 设计文档:`../bestiary/enemies-master.md`
- 章节文档:`../chapters/03-jade-veil/chapter-overview.md`
- 代码挂点:`game/scripts/combat/chapter_3_enemy_factory.gd`
