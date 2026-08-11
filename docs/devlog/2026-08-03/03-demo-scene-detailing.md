# 示范场景精雕：level_01_01 苏醒之庭（5 分工 agent）

**日期:** 2026-08-03（深夜续）
**范围:** 用户方向「禁止占位，用 subagent 多个子 agent 专门优化一个场景，写细节，禁止简单图形，需多种复杂几何雕刻，一个场景 5 个以上分工刻画小细节和灯光」落地到示范场景 level_01_01。

---

## 一、分工（5 并行 agent，各只写自己的切片文件）

| 切片 | agent 职责 | 交付容器数 | 雕刻技术 |
|---|---|---|---|
| 大形 | 北门组/墙浮雕/柱础柱冠/地面铭刻环 | 24 | bevelBox/lathe/extrude/torus/ring/rivetRing/spikeRing/capsule/cone |
| 道具 | 祭品陶罐/铜香炉/齿轮机关/锁链/石灯笼/水晶/线圈 | 13 | lathe/gear/bevelBox/chain/crystal/coil/torus/knurl/ico |
| 实体 | 两失魂士兵台位布景(焦痕/符文环/祭品/接触阴影) | 2 | lathe/ico/extrude/bevelBox/torus/ring |
| 灯光 | 氛围点光 + 发光信号点(冷火苗/烛台/门灯/熔光晶簇) | 8 | emissive 信号点 + PointLight 3-6/decay2 |
| 氛围 | 局部余烬/萤火/贴地雾/尘埃/苔藓藤蔓 | 5 | emberField/glowMotes/groundMist/tube(藤) |

切片为纯数据模块（只用 S 参数，不 import three），与场景模块一致；**主线程合并**进 ch1a.mjs 的 env 数组（`...detail_X(S)`），避免 5 agent 同改一文件。

## 二、穿模自检（每 agent mandatory）

新建 `build/scenes/_harness-detail.mjs`：单片 AABB 自检——切片 ↔ 既有 env + 切片内部，>0.12m 判重叠；沿用 audit 的跳过集（地面/粒子/灯/大气层/全透明）+ 攀爬装饰贴墙豁免 + 建筑分类。5 切片全部 ✓。

**agent 自纠案例**：铜香炉碰石棺（contactShadow 的 Group AABB）→ 移位；gear 默认 hub=0.5 巨盘 → 显式 hub/toothW；念珠名含 "ray" 被 ATM 正则误判 → 改名；断柱带 lean 旋转 AABB 横扫根地 → 熔光晶簇改到裂隙侧；台位 B 剑刃指向侵入断柱 → 重定向。

## 三、主线程合并 + 跨切片穿模修复

合并后 level_01_01：**顶层容器 95 / 展平 mesh 589**（原 ~30 顶层/不足）。harness 只查切片内，跨切片 2 处碰撞由 intersect-audit 总检抓出：
1. guardianBeastE(3.9,7.5) ↔ pedestalB_detail(4,6) 布景 → 东移至 (6.0,7.5)（距台位 2.5m/门柱 2.5m/香台 2.9m）。
2. 移动后撞 gateColumnE(4.2,9.2) → 再调，最终 (6.0,7.5) 三方全清。

**终态**：`intersect-audit --scene level_01_01` **0 深重叠**；`verify-scenes.mjs` 28 场景 ✓；`phase-check.mjs` 18 阶段 0 错误。全量审计 65 深候选（其余 27 场景设计使然，待 VLM 复核精雕）。

## 四、方法论沉淀（供后续 27 场景复制）

- 每场景精雕 = 5 分工 agent（大形/道具/实体/灯光/氛围）各产纯数据切片 → harness 自检 → 主线程合并 → intersect-audit 总检（跨切片碰撞主线程修）。
- 切片命名给 ASCII name（未命名显示 Mesh@(x,z)）；坐标越界 x∈[-13,13] z∈[-11,11] 检查；发光只做信号点强度 1.2–3；小件 castShadow=false；70/25/5 分区。
- 后续：27 场景逐个复制本流程（VLM 复核穿插）。
