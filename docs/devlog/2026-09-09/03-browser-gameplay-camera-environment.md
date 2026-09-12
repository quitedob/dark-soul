# Chrome 实际游戏检查：玩家镜头与 29 关环境

用户反馈玩家视角和游戏环境不对，要求使用 Chrome DevTools 打开游戏验证。本次承接 `02-animated-library-runtime-integration.md` 明确未覆盖的浏览器与完整关卡层级；没有重新转换或替换模型库。

## 实际复现与修复

- `dist/web` 是 2026-07-30 的旧导出。本次从当前 `game/` 导出 Godot 4.7.1 Web debug，开启 GDExtension、关闭线程，包含 LimboAI 对应 WASM。使用新目录、HTTP 端口 8129 和独立 Chrome 存储上下文。
- 出生点在 z=2，隐形边界在 z=3，SpringArm 被挤入角色背部。隐形围栏加入 `camera_passthrough`，相机在创建与复活时刷新排除 RID；角色仍受围栏阻挡，可见墙仍阻挡镜头。实际相机测试验证两种碰撞与关卡替换。
- 锁敌俯仰符号反了。以真实 Camera3D 投影验证高、低、侧方目标和玩家头部取景；解锁后的臂长恢复持续进行，不再随短暂回正计时器或手动旋转中止。
- `game_world._generate_navigation()` 曾创建可见、无材质的 30×50 平面，y=0.01 覆盖正常地面。删除该辅助几何，逐关烘焙现有关卡的实际静态碰撞；等待初始地图注册迭代完成，再显式向 NavigationServer 发布烘焙网格，避免初始空快照覆盖它。
- 使用现有五章主题和光照档更新唯一的 WorldEnvironment，切关前取消旧相变 tween，死亡/休息恢复默认。F2 检查区使用局部 OmniLight，切关销毁检查区。
- 坡道沿上坡方向旋转，顶部两端对齐地块高度；为同高斜向连续地块添加有宽度的连接。原 25 个无地面支撑的敌人出生点改为依据实际地块与碰撞半径选择安全位置。
- 让敌人实际运行后，进一步确认走廊与高台的巡逻可自行走出边缘：修复前实测碰撞体 y=-11.116 / -6.139，并持续下落。主动移动增加前方胶囊脚印地面检查，斜向碰边时保留可通行分量；保留重力和受击击退。出生点射线通过不能代替这个移动检查。
- 跨章 NPC 改为有足够间距的受支撑位置；药罐移回地面，离开初始关卡时同时关闭隐藏药罐的碰撞；杠杆和门的地面高度跟随当前关卡。
- 逐关截图进一步复现第五章发光机关、第三章入口和 Boss 场地残留。章节交互物及 ArenaDirector 的石柱/药罐改挂所属关卡，切关清除旧模块、相变装饰、旧 Boss 控制器与临时 HUD 提示；测试覆盖已启动与尚未执行的 Boss 初始化、旧提示计时器和第五章返回第一章。
- 独立浏览器的可选宿主检查原先把 JavaScript 返回值传给 `String()`，触发启动错误。现在通过 `bool()` 处理实际 Web 模板返回的 0/1。
- 旧字体只覆盖 241 个码点，当前 UI 缺 1,407 个字符。基于本机 OFL Noto Sans SC 生成 521,080 字节静态 Regular 子集，当前所需 1,646 字符全部覆盖；锁敌标记使用字体支持的 `◇`，保留版权、许可证和可复现检查工具。
- Web HUD 原先混用显示器 1920×1080 与浏览器 1280×720，计算出数百像素的伪安全边距。Web 现在读取 CSS safe-area，按窗口/视口换算。
- 默认 ReliquaryGuard 使用 Manny 骨架，旧装备位置仍停留在 T pose 的手部位置。将同一装备跟随逻辑扩展到 `DEF-hand.R/L`；真实动画直接驱动手部，缺失动作才叠加旧握持动作，避免双重挥动。浏览器确认待机时剑盾随下垂的双手，契约同时覆盖八个原生职业和 Manny。

## 浏览器证据与运行方法

证据目录：`build/browser-audit-20260909/`。基线使用 `baseline/index.html`，真实截图 `evidence/02-gameplay-before.png`。中间版本 `review-v2` 的实际浏览器数据保存于 `browser-v2-29levels.json`：29 个关卡 ID 均匹配，每个出生点都有地面射线命中，镜头实际臂长均为 5.2m；Chrome 控制台无错误/警告。

环境修复最终导出为 `playtest/`。`browser-playtest-29levels.json` 及 `evidence/playtest-level_XX_XX.png` 保存再次逐关实际运行的结果：29/29 玩家站稳且有地面，29/29 镜头臂长 5.2m，5 个主题匹配，89/89 敌人在运行 1.5 秒后落地，所有章节机关只属于当前关卡；Chrome 控制台 0 error / warning。全部 29 张截图逐张查看，包含第五章返回第一章后的清理结果。随后用户反馈挥砍偏差，装备与攻击的后续修复见 [武器挥砍记录](04-weapon-swing-visual-timing.md)。

浏览器使用 Chrome DevTools 的页面、快照、键盘、脚本、截图、控制台和网络工具。WebGL 2.0 Compatibility 成功加载；PCK、主/侧 WASM 和 LimboAI WASM 均返回 HTTP 200。按 Enter 开始、W 前进、Q 锁敌、J 攻击、Space 翻滚，并测试手动旋转、解锁、F2、相变后切关和死亡复活。W 850ms 的实测位置从 z=2 到 z=-2.493，镜头仍在玩家后方；锁敌展开至约 7.38m，解锁并旋转后恢复约 5.201m。

`game/tests/tools/browser_gameplay_audit.gd` 是显式启用的 debug Web 检查节点：启动参数 `-- --browser-audit --new-run`。它观察正常主场景，并暴露有限的关卡/镜头/相变检查命令。普通启动和 release 不安装接口。逐关静态截图先运行 1.5 秒真实物理与动画，再冻结敌人，避免把尚未落地的出生位置和导入静止姿态当成故障；这不代替实际战斗手感评估。

导出示例（目标目录须事先创建）：

```powershell
& E:/godot/Godot_v4.7.1-stable_win64_console.exe --headless --path game --export-debug Web E:/godot/darksoul/build/browser-audit-20260909/playtest/index.html
python -m http.server 8129 --bind 127.0.0.1 --directory E:/godot/darksoul/build/browser-audit-20260909
```

## 验证范围与边界

原生检查入口均位于 `game/tests/smoke/`，命令形如 `Godot --headless --path game --script res://tests/smoke/<filename>.gd`：

| 检查 | 结果与证据（`build/browser-audit-20260909/`） |
| --- | --- |
| `lock_camera_framing_test.gd` | `ASHEN_LOCK_FRAMING_OK`，实际投影、可见墙/隐形边界、手动旋转与臂长恢复；`camera-contract.log` |
| `campaign_environment_contract.gd` | 29 关、5 主题、29 基础地形路线、44 坡道/桥连接、2027 导航多边形、0 无支撑出生点；`environment-lifecycle.log` |
| 章节生命周期（同一环境契约） | `CAMPAIGN_TRANSITION_CLEANUP_OK`：旧机关、导演、全部石柱/药罐、倒计时与过期 HUD 定时器均清理 |
| `enemy_ground_traversal_contract.gd` | 29 项检查、2 个真实关卡的 8 名活动敌人、斜向边缘、上下坡及击退坠落；`enemy-ground-final.log` |
| `embedded_equipment_pose_contract.gd` | 1407 项检查，包含 Manny 与八个原生职业；`equipment-final.log` |
| `feedback_contract_test.gd` | 已释放参与者的 hit stop 结束/清理安全；`feedback.log` |
| 字体检查工具 | `INTERFACE_FONT_COVERAGE_OK`，1646 所需字符全部覆盖；`font-verified-check.json` |
| GUT / CI | 13 脚本、96/96 测试、394 断言；`ci-playtest.log`、`gut-playtest.xml` |
| 完整主线与可选关流程 | `ASHEN_PLAYTHROUGH_PROGRESSION_CONTRACTS_OK`；`progression-playtest.log` |

本轮证据以最终导出、原生契约和实际截图共同确认。`review-v2` / `review-final` / `review-verified` 是保留的中间版本，文件名中的 final 不代表已覆盖后来发现的切关或移动问题。

完整流程契约发现并修正两个独立问题：HitStopManager 在检查对象有效性前将已释放引用赋给 Node 类型；旧通关脚本在可选 Boss 关调用终关出口，没有先走实际返回路径。当前流程覆盖主线、八个 Boss、可选关返回及最终尾声，使用隔离 APPDATA/LOCALAPPDATA；不触碰普通用户存档。

地形路线可达不等于未解锁的任务门应该可以通过。导航检查区分基础地形连通性和带任务阻挡物的正常世界；未宣称所有机关状态下的动态寻路均已验收。现有关卡仍为程序化地块及低多边形素材组合，本次修复位置、镜头、光照和显示问题，没有重新制作场景美术。编辑器/导出退出仍有既有的 495 ObjectDB / 10 resources 释放告警，不能称为完全无告警导入。

API 参考：[Godot JavaScriptBridge](https://docs.godotengine.org/en/stable/classes/class_javascriptbridge.html)、[Web HTML shell](https://docs.godotengine.org/en/stable/tutorials/platform/web/customizing_html5_shell.html)、[NavigationRegion3D](https://docs.godotengine.org/en/stable/classes/class_navigationregion3d.html)。结论以本机运行和浏览器画面为依据。
