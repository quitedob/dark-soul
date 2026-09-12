# 武器挥砍：握柄轴、刀光长度、动画时序与连击

承接 [Chrome 镜头与环境检查](03-browser-gameplay-camera-environment.md)。用户继续反馈“无法正确挥舞武器，视觉有偏差”。本轮使用真实 Chrome Web 游戏按键、慢动作连续截图，以及实际 Player / AnimationTree / CombatArea 运行检查定位问题。未重新转换 Blender 模型。

## 已复现的问题与修复

1. **Manny 持剑轴错误。** 旧手部 rest-delta 把武器长轴映到手掌法线，导致抬腕时剑身方向偏离握持姿势。Manny 的手骨 +Y 沿腕到指根，+Z 横过掌心指向拇指侧；现在武器 +Y 对齐手骨 +Z，握点位于局部 `(-0.012, 0.075, 0)`，左手镜像 x。八个内嵌职业保持自身手骨约定，盾牌保留独立握持校正。身体朝向仍为原先的 PI。
2. **刀光超过实际剑尖。** 旧实现固定使用 1.05m；当前实际 Sword 模板按 0.8 缩放后，装备坐标的尖端为约 0.54088m。现在更换装备时从可见网格顶点缓存尖端，刀光由真实握点和该尖端生成。
3. **动画挥砍晚于判定。** 原始 Manny 直剑 clip 长 1.166667s，主要抬腕到横劈发生在 0.525–0.700s；不能直接沿用占位 clip 的事件时间，也不能只统一缩放全片。桥接器将前摇、挥砍、收招三段映射到当前 `AttackData` 的对应时长，在分段边界插入原始插值姿态，缓存时序副本，保留源资源。命中结束与连击开放使用独立 method 轨，避免同时间的后一个 key 覆盖前一个。
4. **连击窗口和动画重播不一致。** 状态计时每阶段重置，而连击窗口从攻击开始计时；恢复绝对攻击经过时间，并让下一段真正重启 LightAttack。伤害、耐力和各招式时长继续由现有 AttackData 决定。
5. **时序副本又叠加了程序化转剑。** Chrome 慢动作发现收招切换瞬间剑尖跳动。副本存放在 `combat/light_attack_timed`，原有代码仅凭 `real/` 前缀识别真实动作，误加占位武器旋转。现在副本携带明确的真实骨骼姿态元数据；真实动作只跟随手骨，缺失真实动作才保留程序化动作。新增实际 FSM 检查在修复前触发 128 次握柄方向失败，修复后全程通过。
6. **K 重击仅在身体待机时转动武器。** Chrome 实测消耗耐力、进入重击前摇，身体却仍站立。Manny 现有库没有独立重击 clip；现在地面重击和蓄力释放复用真实直剑挥砍，使用各自 AttackData 的原时长。原生契约覆盖普通重击 0.58 / 0.22 / 0.62s 与二级蓄力释放 0.5336 / 0.22 / 0.62s；真实 Chrome K 键确认抬手、挥出、收回均有身体运动。暂未新增独立重击动作素材。
7. **真实 Skill 动作仍叠加占位握姿。** 突刺及曲刀跃击使用 Skill 状态，原装备判断只识别 LightAttack / ColossalLeap；现在识别正在驱动身体的真实 Skill 及其收招，保持原武器技时钟。
8. **默认 F 键选择了 T pose 占位。** `CompatibilityMovesetFactory` 生成的旧武器技没有填写 `stance_animation`，真实 F 路径选到了只动前臂的 `combat/skill_pose`。之前直接传入完整目录武器技的测试漏过了这个路径。现在空的旧武器技动画名按动作类型解析到已有完整身体动画：突刺用 `spear_charge_stance`（Stab1），曲刀跃击用 `curved_spin`；明确指定的动画仍优先。测试改为实际 `_try_style_skill()`，修复前 93 次 T pose 失败，修复后通过。Chrome F 连续画面确认完整突刺并回到待机。

## 已取得的运行证据

所有日志与截图位于 `build/browser-audit-20260909/`，导出中间版本保留以便比较。

| 检查 | 结果 / 证据 |
| --- | --- |
| 初始错误握持截图 | `evidence/swing-before-0.png` 至 `swing-before-3.png`，真实 J 按键 |
| 解剖轴与实际剑尖 | `weapon-grip-anatomy.log`、`equipment-grip-v1.log`；装备契约 1539 检查 |
| 实际 FSM / 物理 AnimationTree | `weapon-timing-grip-contract.log`；69 帧、两次有效挥砍、双手在前摇/命中/收招/连击/待机均匹配骨骼 |
| 时序副本误叠加的反例 | `weapon-retiming-overlay-before.json`、`weapon-timing-grip-before.log` |
| Chrome 单次轻攻击慢动作 | `weapon-chrome-light-slow.json`；真实引擎 time_scale=0.15，未 seek 或手工设置动画姿态；`evidence/weapon-accepted-single-*.png` |
| Chrome 正常速度连续轻攻击 | `weapon-chrome-light-combo.json`；J 后 290ms 再按 J，实际第二段 chain_index=1 且动画位置重新归零；`evidence/weapon-accepted-combo-*.png` |
| 职业替换契约 | `player-embedded-actions-weapon.log`；保留节点身份、相机/命中体/刀光变换，装备跟随新骨架，而非错误要求换身体后装备变换不变 |
| 重击、蓄力与武器技原生契约 | `weapon-heavy-art-contract.log`、`weapon-heavy-art-equipment-regression.log`、`weapon-heavy-art-skill-regression.log`；真实动作、握柄 1539 项、施法/技能真实 clip 回归通过 |
| Chrome K 重击 | `weapon-chrome-heavy-slow.json`、`evidence/weapon-heavy-before.png`、`weapon-heavy-windup.png`、`weapon-heavy-sweep.png`、`weapon-heavy-recovery.png`；真实 time_scale=0.2，7305ms 已返回待机 |
| 默认 F 实际出招路径 | `weapon-default-art-body-before.log` / `weapon-default-art-body-contract.log`：失败反例与通过结果；同时重测轻击、重击、蓄力、三类武器技及显式缺失动画的回退 |
| Chrome 默认 F | `weapon-chrome-default-f.json`、`evidence/weapon-art-tpose-before.png`、`evidence/weapon-f-fixed-*.png`；真实引擎 0.2 倍速，进入突刺、收招并回到待机 |
| 最终 GUT | `ci-gameplay.log`、`gut-gameplay.xml`：96/96 测试，394 断言 |
| 最终完整流程 | `progression-gameplay.log`：`ASHEN_PLAYTHROUGH_PROGRESSION_CONTRACTS_OK` |

Chrome 当前世界的起始轻攻击实际时长为 0.28 / 0.16 / 0.38s。正常速度连击记录中，第二段约 476ms 重启、716ms 再次进入命中、890ms 收招、1204ms 返回待机；这是按键和观察采样时间，非引擎逐帧精确边界。慢动作观察的剑尖到握点长度为 0.5402–0.5419m，差异来自坐标记录的毫米量化。已查看后方与侧后方实际连续画面，控制台无 error / warning。

## 复查边界

最终集成导出为 `gameplay/`；`weapon-review-v1`、`weapon-playtest`、`weapon-final`、`weapon-gameplay` 是保留的中间版本，不代表修完之后发现的问题。普通入口为 `http://127.0.0.1:8129/gameplay/index.html`，检查入口为同目录 `audit.html`。最终普通入口再次按 J / K / F 检查，未安装 AshenAudit，Chrome 控制台 0 error / warning。

默认 Manny 的突刺已在浏览器实际验证；Manny 三类武器技均有原生实际 FSM 姿态检查。Chrome 数字 3 会同时换装为 marksman，并非保留 Manny 后只更换曲刀招式；`weapon-chrome-native-style3-f.json` 记录的是正常职业切换路径，不能当作 Manny 曲刀动作的渲染证据。重击目前复用现有直剑动作，没有独立重击素材。

`browser_gameplay_audit.gd` 的 time_scale 命令仅存在于显式 `--browser-audit` debug 检查入口；普通启动不安装接口。慢动作快照按未缩放时间更新，记录实际攻击状态、动画时间、剑尖与握点、命中体状态，不直接操纵姿态。

GUT 职业切换仍会输出部分 Manny AnimationMixer 轨道解析警告。旧 `animation_root_motion_contract_test.gd` 在 `_init()` 中过早访问全局变换且有未释放的匿名 fixture；该测试及相关导演实现均与 HEAD 一致，其 OK 标记不能作为无警告通过。编辑器/导出的既有资源退出告警见环境记录。本轮不将这些运行范围外问题标成已修复。
