# 29 关剧情场景、独立 Boss 判定与场景机制续作

工作方法详见 [Blender MCP、资产生产与问题排查复盘](02-blender-mcp-workflow-and-debugging-retrospective.md)，包含工具使用边界、建模取舍、失败反例与复现命令。

状态：已完成。本轮原生集成与最终 Chrome 验收已完成，具体操作范围和既有警告见下文。承接 [09-09 场景与装备改造](../2026-09-09/05-weapon-loadout-temple-redesign.md)。用户追加要求是全部 29 关有丰富道具和建筑、敌人摆放合理、符合 `docs/story`，以及每位 Boss 的独立隔离、判定、互动、破坏和阶段场景变化。本记录不以此前的通用八 Boss/十三阶段检查代替这次验收。

正史依据：[五章桥接图](../../story/chapter-bridge-map.md)、[世界观](../../story/lore.md)、[主线](../../story/main-story.md)。玩家没有传统前世；九座墓对应九位陨落铸魂者，另有三位活着的铸魂者。章节关卡详述和 Boss 文档提供具体玩法要求。

## 已接入的场景模型与位置

`tools/build_campaign_story_props.py` 创建五个 GLB、46 种独立几何部件，共 186 个材质网格、209,778 个三角形、10.55 MB。模型包含开放入口和独立导航代理；渲染器直接使用导入 ArrayMesh，按部件批量提交。已有 86 个角色/武器动画模型沿用之前的转换工作。

`campaign_scene_dressing.gd` 提供全部 29 个场景的 211 处静态剧情布置；Boss 的十二诱铃等可破坏对象由 Boss 控制器单独创建，不重复计入静态场景。`campaign_encounter_layout.gd` 为实际 86 个普通敌人按 content_id 和重复序号提供守卫、伏击、远程、精英及巡逻位置，重排生成列表不改变角色分工。镜湖复查后把一只回声灵替换成三只站在真实石路上的水月灵，场外精英保持独立。世界层消费位置、朝向、巡逻点、警戒距离；灰岸被动灵魂只在受到攻击后敌对。

| 关卡 | 剧情布置 |
|---|---|
| 01_01 | 苏醒石榻、跪像、正史壁画、寺院回廊 |
| 01_02 | 墓廊墙、石棺、陷阱通道 |
| 01_03 | 铜镜厅、反射碑墙 |
| 01_04 | 双侧炼丹房、材料炉、守炉符文 |
| 01_05 | 守炉台、四柱与监视火盆 |
| 02_01 | 攻城车残骸、路障、军旗 |
| 02_02 | 关墙、烽火楼、城防平台 |
| 02_03 | 三处囚笼、强制锻炉、刑具院与看守帐 |
| 02_04 | 分层烽火落点、信号塔、军令桌 |
| 02_05 | 军帐、地图桌、将军卫队 |
| 02_06 | 锁链角斗场、军魂看台 |
| 03_01 | 竹林回路、幻树与假狐火 |
| 03_02 | 苔壁记忆牢、真实记忆镜、忆姬与窃贼 |
| 03_03 | 花轿、迎亲灯笼、队列侧路 |
| 03_04 | 八角水亭、湖面、供茶、茶魂与钟塔侧道 |
| 03_05 | 花木迷宫、树魂谜门、真实之镜 |
| 03_06 | 九株幻花、九尾月庭 |
| 04_01 | 断裂登天梯、金玉尖塔、浮空落点 |
| 04_02 | 炼丹炉区与破碎天城建筑 |
| 04_03 | 多层藏书楼、仪式桌、原始实录 |
| 04_04 | 嗔念废墟、可击碎断柱 |
| 04_05 | 执念保存的仪式室 |
| 04_06 | 天城顶峰、游离残识、战后坠城断桥 |
| 05_01 | 灰岸、魂骨、炉忆证物 |
| 05_02 | 倒置炉城、引力锚与翻转通路 |
| 05_03 | 前四章建筑交错、真实因果回放 |
| 05_04 | 九座有名墓碑、三位生者敕印、寂灭门槛 |
| 05_05 | 烬座、炉心锁链、可操作星体 |
| 05_06 | 钟厅、十二次序明确的真实诱铃 |

## 已接入的判定和剧情条件

- `boss_encounter_boundary.gd` 为八个竞技场控制入场、完整物理封界、玩家/攻击来源范围、重试和已通关载入。普通伤害、状态爆发和处决均遵守同一入场条件；重置不发奖励，已击败 Boss 不因休息再次复活。
- `campaign_story_progression.gd` 把符文、三把笼钥、三段真实记忆、真镜和天界实录做成实际房间内的交互物；验证玩家身份、距离和重复拾取，写入原有存档。
- 铁心要求三钥及实体牢门军印解除；忆姬要求三段记忆和实际精英窃贼死亡；玄霄残识要求读取记录并平息两种残念。条件满足后的真实对话结束才迁移角色。
- 主线 Boss 终止阈值由共同伤害入口限制；九尾无真镜时不能在 30% 直接获救。刑天先执行终礼，再进入场景裁决。终章结局由炉心、烬座等实际场景动作交给世界层校验。
- 玄霄的 90 秒坠城逃生发生在裁决之后；有高架庭台、连接坡道与跳跃缺口，实际禁用坠落平台碰撞。死亡、存档重载保留 Boss 已完成事实，重试逃生不重复发放战利品。

## 八个 Boss 的实际场景玩法

| Boss | 阶段与场景互动 |
|---|---|
| 巨阙 | 实际守炉符文解开入口；四柱挡伤，沿导航巡查四火盆并留下三秒进攻窗口；60% 依次燃炉、可扑灭；低血量重击留下永久裂缝，10% 场景裁决。 |
| 刑天 | 70% 锁链断裂；30% 左斧垂落并改用独斧荣誉招式；10% 先执行可躲避的三秒终礼，再允许裁决。 |
| 九尾 | 70% 三只一击消失、反伤十点的分身；50% 记忆凝视与阻路婚宴宾客，打破幻花移除对应宾客；15% 十秒诱惑；持镜也须实际操作真镜才能在 30% 以下解救，无镜战至 1 HP 封印。 |
| 嗔念 | 冲锋、重击实际击碎柱体并使 Boss 失衡；60% 火场与自损爆发，断柱揭露历史。 |
| 执念 | 三座祭坛按顺序执行可打断仪式；七秒周期含两秒预警，召唤实际可攻击敌人与防御护盾，后续阶段冰场。 |
| 玄霄 | 60% / 30% 阶段与二十秒人格轮换、可破坏心锚；10% 清醒裁决后启动九十秒逃生，十三庭台、四个实际跳跃缺口、坠落碰撞及重试。 |
| 烛阴 | 70% / 40% / 10% 阶段；五秒超新星受掩体遮挡，黑洞、引力锚、幻象与前章命运祝福作用于真实伤害；四种结局通过对应场景动作校验。 |
| 盲钟 | 十二枚有碰撞的诱铃，各可使用三次；按真实声源冲刺且不穿墙；三次击中钟口产生四秒失聪窗口，55% 黑暗遮板变化。 |

巨阙巡查使用实际 NavigationAgent 路径绕过柱体。检查发现烘焙路径点比角色脚底高约 0.5 米，旧 0.35 米容差使角色在路径首点抖动；敌人默认容差改为 0.7 米，且未交战巡逻使用自己的路线点。治疗反应遵守入场、视线和被动敌人规则，惩罚范围攻击只命中实际玩家，远程惩罚发射有世界碰撞的弹体。

## Chrome 实查发现并修正的问题

- 五套场景模型的 Floor / Bridge 曾有跨材质共面三角形，实际画面出现密集条纹。重新生成分层表面后，对最终 GLB POSITION/index 数据逐三角形检查，十个目标部件的跨材质水平重叠面积均为零；其余六类部件的几何与材质未变。证据：`chrome/kit-surface-after-audit.json`、`chrome/ramp-surface-after-v3.b64`。
- 地面上直接切换倒置重力曾把胶囊翻进地板。翻转现在保持胶囊中心，再由真实重力落向另一表面；原生回归 17 项，Chrome 四锚实际输入段完成 4/4，HP 100，最终恢复正常 up。该输入段开始前有一次明确的 inspection 定位，随后没有修改角色位置或速度。
- 镜头被棚顶或障碍压近时，身体曾堵满屏幕。按实际 Camera3D 到 rig 距离，低于 1m 仅隐藏身体组根节点，超过 1.25m 恢复各节点原有可见状态；装备、碰撞和动画继续运行。真实墙体、撤墙、倒置和职业换体检查共 76 项。测试初版移墙曾瞬间把镜头拉至 1.40m，错误期待仍隐藏；修正物理移墙方式并逐帧验证滞后区间，没有降低生产恢复阈值。
- 镜湖与迷宫的旧护栏、机关出口接回原岸的地面，以及 05_04 扩建内部残留护栏曾阻断实际行走。已修正物理连接；五关机关回归使用真实 E/WASD，覆盖湖路、九种迷宫配置的出口、四锚倒置、迎亲队伍和三座试炼庭台往返，共 687 项。
- 小窗口曾仍按拉伸后的固定 viewport 排版。现已关闭固定 viewport 拉伸，让实际小 viewport 进入 HUD 的紧凑布局；v4 实际 viewport 已确认 854×480 / 390×844。随后发现装备窗打开时缩窄会残留图标，已改为动态隐藏紧凑布局图标；新增 75 项原生回归通过；最终包保持装备窗打开完成 854→390→854 缩放，已目检竖屏与横屏恢复正常。
- 正常入口在 fresh context 曾因 ready 阶段申请 Pointer Lock 而产生用户手势错误。Web 启动不再自动捕获，改为未被 UI 消费的实际鼠标左键或 WASD 键输入时申请；新隔离会话 Enter 开始、W 移动后成功锁定，无 Promise rejection 或启动错误。

## 当前原生证据

以下文件位于 `build/story-campaign-20260910/`，除首行的独立模型基线外，均为本轮实际读取的最终或后续集成日志。六项 `integrated-v4` 已全部退出 0，扫描无 ERROR/WARNING。模型、单项剧情和战斗检查各有明确范围，不把标记通过等同于全流程人工通关。完整哈希、末尾标记及诊断见 [aggregate-native-final.json](../../../build/story-campaign-20260910/aggregate-native-final.json)。

| 检查 | 最近确认结果 | 日志 |
|---|---|---|
| 剧情 GLB 材质、导入边界、缩放/旋转碰撞、建筑入口 | PASS，1,487 项；独立模型基线 | `build/temple-redesign-20260909/story-props-contract.log` |
| 全 29 关地面、导航、换关和清理 | PASS，29 关 / 7,542 多边形 / 29 完整地形路线 / 120 坡道 / 零悬空敌人 | `campaign_environment_contract-integrated-v4.log` |
| 全关剧情布置、实际敌人、替换机关和物理支撑 | PASS，5,109 项 / 211 静态道具 / 86 普通敌人；水亭 8 个真实柱脚、64 个接地顶点 | `campaign_story_layout_contract-integrated-v4.log` |
| 八 Boss 场景互动、阈值、裁决及战后流程 | PASS，399 项 / 8 Boss | `boss_story_arena_contract-final.log` |
| Boss 入场、封界、伤害来源、重试与已通关重载 | PASS，568 项 / 8 Boss | `boss_encounter_boundary_contract-final.log` |
| 实际物证、牢门、NPC 迁移和重载 | PASS，82 项 | `campaign_story_progression_contract-final.log` |
| 地面直接倒置、胶囊移动/跳跃、相机与复活 | PASS，17 项 | `player_story_traversal_contract-integrated-v4.log` |
| 镜头受阻隐藏身体、滞后恢复、倒置及换体 | PASS，76 项 | `player_camera_occlusion_contract-browser-startup-final-v2.log` |
| 五关机关、湖路、九种迷宫的实际输入出口及试炼庭台连接 | PASS，687 项 / 5 关 / 9 迷宫配置 | `story-routes-regression-v1.log` |
| 武器栏切换与真实挥砍 | PASS，897 项 | `weapon_quickslot_contract-integrated-v4.log` |
| 真实武器握柄 | PASS，`ASHEN_PLAYER_WEAPON_GRIP_CONTRACTS_OK`；日志未给数字项数 | `player_weapon_grip_contract-final.log` |
| 内嵌装备和动作姿态 | PASS，1,539 项 | `embedded_equipment_pose_contract-final.log` |
| 锁定取景与障碍 | PASS，`ASHEN_LOCK_FRAMING_OK`；日志未给数字项数 | `lock_camera_framing_test-final.log` |
| 实际 HUD / 装备面板布局与打开状态缩窗 | PASS，75 项；最终包 854→390→854 实际缩窗已目检 | `hud_equipment_contract-responsive-final.log` |
| 世界装备接入 | PASS，63 项 | `world_equipment_contract-final.log` |
| 敌人落地、坡道、边缘及击退 | PASS，31 项 / 2 关 / 8 实际敌人 | `enemy_ground_traversal_contract-final.log` |
| 治疗视线/被动策略、惩罚目标、祝福倍率及加速刷新/重置 | PASS，69 项 / 10 次真实治疗信号 | `enemy_healing_reaction_contract-final.log` |
| 实际巡逻、守卫绕障追击和返回 | PASS，13 项；归位后无滑移 | `authored-navigation-v3.log` |
| 八类敌人实际命中与敌人/Boss 弹体遮挡 | PASS，62 项，含贴墙生成及初始重叠 | `authored-combat-v4.log` |
| 镜湖三水月灵真石站位/伤害门控与伏击安全落点 | PASS，125 项 | `lake-ambush-final.log` |
| 界面字体覆盖 | PASS，1,677 所需字符，零缺字 | `interface-font-check.json` |
| GUT 核心回归 | **PASS_WITH_WARNINGS**，96 测试 / 394 断言 / 13 套件；2,834 条既有动画轨道警告 | `gut-final.log`、`gut-results.xml` |

此前 6,023 单元拓扑、282 项机关、5,031 / 84 旧站位、397 项 Boss 和 46 项治疗结果是迭代历史，已由上表相应证据替代，不再作为最新验收数量。真实物理支撑与导航检查也不证明地图全部内容已由玩家手动通关。

五处机关拥有自己的重试状态和物理对象；退出时还原镜湖地板、旧护栏、重力、音量、HUD 色值与外部敌人进程。寂灭沉默术对术法、祷告及召唤使用同一锁定检查，普通弓箭保留物理攻击能力。HUD 显示当前机关目标与剩余时间。九尾记忆凝视冻结角色并改变现有森林表现，不另加载独立过场地图。

换关复查还定位了导航队列丢失：离开机关场景后，下一关可能停在 `refresh_queued=true / bake_requested=false`。共享 `physics_frame` 单次连接改为独立物理定时回调后，29 关导航重新通过。普通怪与 Boss 弹体改为在首次不安全接触点取重叠对象并处理初始重叠；此前在安全相切位置查询会漏掉玩家与掩体。

## Chrome 证据的操作范围

当前最终包正常入口：`http://127.0.0.1:8129/story-campaign-final/index.html`。独立 `audit.html` 用于带来源标记的调试观察，正常入口不启用该调试桥。截图和 JSON 均位于 `build/story-campaign-20260910/chrome/`。最终正常页面已保留供继续游玩；`final-source-export-hashes.json` 记录玩家、界面、机关、项目设置和最终 HTML/PCK 共八项 SHA-256，收尾时再次匹配当前文件。

| 证据 | 实际操作与结论边界 |
|---|---|
| `initial-29-scene-observations.json` 与每关 spawn / feature 图 | 29 关 inspection 加载、指定位置观察；不是逐关行走通关。它们记录修复前的问题，不能代替最终 v4 修复复查。 |
| `boss-phase-and-input-evidence-v2.json` | 八 Boss 的入场、场景互动和阶段观察。阶段由 `boss_hit` 伤害入口注入，部分技能由 `boss_skill` 触发；巨阙火盆与盲钟诱铃使用真实附近交互。不是手打击败八 Boss 的证据。 |
| `weapon-input-samples.json` | 真实输入后的武器、命中窗口、动画和镜头采样；位置来源仍以记录中的 inspection 标记为准。 |
| `trial-real-keyboard-victory-v3.json` | 先 inspection 到铸星者庭台附近，再真实 E 开始试炼、Q 及五次 J 攻击；开始后无伤害/位置注入。最终 HP 36，`trial_star_forger=true`。只证明该试炼输入段获胜，未证明磁盘重载。 |
| `inversion-four-anchors-input-success-v3.json` | 先定位到四锚入口 `(-12,8.05,-106)`，随后真实 E/WASD，无角色位置/速度重写；4/4 完成、HP 100、最终 up 正常。包含镜头观察调整，不称从关卡出生点完整通关。 |
| `maze-full-egress-input-success-v4.json` | 先 inspection 到机关入口，再真实 E/WASD；3/3 完成后实际走至原岸 z=-107.121，HP 100。覆盖本次配置的解谜与出口，不代表九种配置均在 Chrome 手动完成。 |
| `lake-full-egress-input-success-v4.json` | 明确分开 `unrevealedAttempt` 与 `completedRoute`。前者未读镜、进度 0；后者在入口定位后真实 E 读镜，再 WASD 完成 5/5 并走回原岸 z=-113.315，HP 100。只把后者记作完成路线。 |
| `equipment-portrait-resize-final.png`、`equipment-landscape-resize-final.png` | 实际 root 尺寸 854×480 / 390×844。装备窗保持打开，854→390→854 缩放已目检正常；紧凑模式图标随尺寸隐藏并恢复。 |
| `final-camera-and-weapon-input.json` 及 `camera-close-wall-final.png` / `camera-walk-away-restored-final.png` | inspection 置于障碍前，实际相机碰撞长度 0.416m、身体隐藏；随后 W 47 帧离开，恢复 5.2m 与身体可见。另一段真实 X 换斧、J 攻击采样包含实际活动命中窗口，截图 `axe-real-input-active-final.png`；动作采样有调试慢放，不称正常速度完整战斗。 |
| 最终包 audit 控制台 | 零 error/warn；近墙、装备和输入验证由主代理实际检查。 |
| `normal-fresh-start-pointer-lock-fixed.json`、`normal-final-console.json`、`normal-chinese-gameplay-final.png` | 全新隔离会话从正常 `index.html` 用 Enter 开始、实际 W 移动，`pointerLocked=true`，`rejections=[]`、`errors=[]`、参数 `[]`、`auditPresent=false`；实际 Chrome 控制台查询无 error/warn，正常中文游戏画面已保留。 |

## 验收范围与既有诊断

本轮已完成上述原生检查和 Chrome 验收，最终正常入口与独立 audit 页均已检查，控制台零 error/warn。29 关全景图属于 inspection；八 Boss 阶段预览包含伤害注入；真实键盘证据是明确标注起点的试炼、四锚、镜湖/迷宫出口、镜头恢复和武器操作段。因此完成的是本轮实现及所列验证范围，未声称手动从新存档连续通关全部 29 关、手打八 Boss 或穷尽所有结局。

最后一次启动修复的 `player_camera_occlusion_contract-browser-startup-final.log` 曾出现 bool 类型推导编译错误，仅保留作失败诊断历史；已修复并由 `player_camera_occlusion_contract-browser-startup-final-v2.log` 的 76 项干净回归、重新导出和 fresh-context 正常入口检查覆盖。相机恢复只引用最终 `camera-close-wall-final.png` / `camera-walk-away-restored-final.png`，不使用早期名称带 restored 但未证明恢复的 v3 截图。

GUT 的 2,834 条 `AnimationMixer` 未解析轨道警告与上一轮 `build/temple-redesign-20260909/ci-final.log`、`ci-final-v2.log` 的警告多重集完全一致。触发块位于 `test_player_fsm.test_active_wam_holds_light_hit_but_zero_wam_staggers` 和 `test_stamina_economy.test_target_style_costs_and_insufficient_block` 之后，涉及 `Visuals/BodyYaw/BodyRoot/mannyquin/godot_rig/Skeleton3D:DEF-*`。资源为 `res://assets/models/player/mannyquin.glb` 及 `res://resources/animations/mannyquin_lib.tres`；职业身体替换后旧动画绑定未更新是源码支持的推断，尚未在本轮修复。不能称 GUT 零警告。

编辑器导入和最终包 `export-web-final.log` 退出仍打印既有的 495 个 ObjectDB 对象 / 10 个资源释放诊断，退出码为 0；同样数量存在于更早的 `export-baseline.log`。这些编辑器诊断与上表干净的游戏契约日志分开记录，尚未精确归因到 MCP/GUT 插件清理。
