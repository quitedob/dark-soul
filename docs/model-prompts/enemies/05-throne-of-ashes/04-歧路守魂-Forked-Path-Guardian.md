---
名称: 歧路守魂（Forked Path Guardian）
类别: 敌人
目标格式: GLB (Godot 4.7.1)
参考尺寸: 各变体约为对应原 Boss 的 60%:巨阙 4.8m / 刑天 7m / 九尾大型狐 3.5m / 玄霄 1.9m
源文档: ../bestiary/enemies-master.md, ../chapters/05-throne-of-ashes/chapter-overview.md
---

## 一句话概述

鬼类精英,5-3 轮回歧路"可能性交叉口"现身的**前四章 Boss 的幽灵回声**——巨阙/刑天/九尾/玄霄的弱化换皮版。AI 沿用原 Boss 核心招式但数值约 60%、韧性约 50%;4 个变体共享"半透明、嚎泣、回声"的鬼类视觉语言。

## 视觉描述

四个变体均为**原 Boss 的半透明幽灵回声版**:体型为原型的 60%,保留标志性轮廓,但整体褪色成青白魂色、边缘带嚎泣波纹,烬火辉光仍在但变冷变弱。基础姿态参考原 Boss,但动作"回放感"强(像残留影像),是"未走之路"的记忆投影。

- **歧路·巨阙(守炉灵回声):** 缩小到约 4.8m 的石甲炉神,胸口炉门、面具独眼、巨型门刀俱在但半透明化,甲缝火光转冷。
- **歧路·刑天(血将军回声):** 约 7m 无头巨神,乳为目、脐为口,双持链斧但锁链已虚化,血煞纹路褪成灰色,鬼哭如战嚎。
- **歧路·九尾(玉面狐回声):** 约 3.5m 的九尾青狐,九尾各色幻彩全部褪成同一青白色,眼为月光但幽冷,狐火转阴绿。
- **歧路·玄霄(堕仙回声):** 约 1.9m 半神半朽修士,右半辉光、左半腐肉但均半透明化,白袍云纹、三缕意识流萦绕,嚎泣是诵经残响。

## 图片生成提示词

四个变体各自独立生成。生成后用 TRELLIS/Hunyuan3D 转 3D 时,统一做 60% 缩放 + 半透明 Alpha 处理。

**变体 1 · 歧路·巨阙:**

```
Spectral Furnace-Keeper Echo, full body, front view, standing, translucent stone-and-bronze colossus at sixty percent scale, temple-roof shoulders, sealed furnace-door chest with dying ember glow, single glowing eye mask, colossal spectral gate blade held low, fading wailing ghost wisps, pale grey stone and cold blue-white color palette, translucent stone and fading ember materials, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

**变体 2 · 歧路·刑天:**

```
Spectral Blood General Echo, full body, front view, standing, translucent headless giant at sixty percent scale, eyes on chest and mouth on abdomen, faded ritual scarification in cold grey, spectral twin battle axes chained to wrists, phantom wailing echoes, pale ash grey and fading blood red color palette, translucent flesh and spectral iron materials, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

**变体 3 · 歧路·九尾:**

```
Spectral Nine-Tails Echo, full body, front view, standing, translucent jade fox with nine tails at sixty percent scale, nine tails faded into identical pale blue-white, moonlight eyes turned cold, dim foxfire motes, phantom wailing howl echoes, jade green and moonlit silver fading color palette, translucent fur and spectral mist materials, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

**变体 4 · 歧路·玄霄:**

```
Spectral Fallen Immortal Echo, full body, front view, standing, translucent cultivator half divine light half rotting flesh, white cloud-embroidered robes, three faint consciousness wisps orbiting, cold reciting-echo glow, pale white and fading rot color palette, translucent light and spectral silk materials, game asset, low-poly stylized PBR, Chinese dark fantasy soulslike, ember fire glow accents, single subject, centered, plain neutral background, no text, no watermark, no extra objects
```

## 建模备注

- **低模目标:** 每变体 LOD0 8k tris / LOD1 4k;优先复用原 Boss 网格做**半透明+褪色**换皮,减少新建面数。
- **挂点/Socket:** 各变体继承原 Boss 挂点(`weapon_tip` / `ExecutionAnchor` / `GrabProfile`),以保证幽灵版沿用原招式绑定。
- **弱点击破锚点:** 继承原 Boss 破绽(刑天=胸口之眼与腕链、玄霄=半神半朽接缝、巨阙=胸口炉门、九尾=真实本体),但均需半透明化提示"这是回声"。
- **碰撞:** 按缩放后的 60% 尺寸重建胶囊/盒碰撞;`ghost` 标志允许 10% 概率穿墙以强化鬼类特质。
- **贴图:** 2K Base + Alpha(半透明全局约 55–65%);魂色褪色走 Roughness/Color 偏移;烬火辉光保留但降饱和。
- **动画/骨骼:** 直接继承原 Boss 骨架与动画,额外加"回放/颤动"层级(整体 Alpha 脉动 + 轮廓波纹)。

## 出处

- 设计文档:`../bestiary/enemies-master.md`(Chapter 5 歧路守魂 四变体)、`../chapters/05-throne-of-ashes/chapter-overview.md`(5-3 轮回歧路)、原 Boss:`../bestiary/bosses-master.md`(巨阙/刑天/九尾/玄霄)
- 代码挂点:替换 `enemy_factory.gd` 时保持原 Boss 挂点命名,`ghost` 标志复用
