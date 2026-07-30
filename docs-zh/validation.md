# 验证 (Validation)

验证于 **2026-07-29**，使用精确要求的引擎二进制文件。

## 引擎 (Engine)

```text
D:\godot\Godot_v4.7.1-stable_win64.exe
D:\godot\Godot_v4.7.1-stable_win64_console.exe
```

报告的版本：

```text
4.7.1.stable.official.a13da4feb
```

## 自动化结果 (Automated Results)

### 脚本解析 (Script parsing)

命令模式：

```bash
for script in scripts/**/*.gd; do
  "D:/godot/Godot_v4.7.1-stable_win64_console.exe" \
    --headless --path "D:/godot/newproject" \
    --check-only --script "$script"
done
```

结果：`ALL_SCRIPTS_PARSE_OK`

### 编辑器导入 (Editor import)

```bash
"D:/godot/Godot_v4.7.1-stable_win64_console.exe" \
  --headless --editor --path "D:/godot/newproject" --quit
```

结果：成功完成，无脚本或资源错误。

### 有界运行时 (Bounded runtime)

```bash
"D:/godot/Godot_v4.7.1-stable_win64_console.exe" \
  --headless --path "D:/godot/newproject" --quit-after 180
```

结果：成功完成，无运行时错误。

### 游戏玩法烟雾路径 (Gameplay smoke path)

```bash
"D:/godot/Godot_v4.7.1-stable_win64_console.exe" \
  --headless --path "D:/godot/newproject" \
  --quit-after 600 -- --smoke-test
```

结果：`ASHEN_HOLLOW_SMOKE_OK`，干净退出。

烟雾路径验证了运行时构建、玩家烬火变化、玩家伤害和治疗、敌人伤害、交互提示可见性、守护者HUD可见性、死亡覆盖层可见性和清理，以及瞬时消息创建。有界运行时还额外测试了数秒的物理、相机设置、响应式UI处理和敌人状态更新。

### 核心合约测试 (Core contract tests)

```bash
"D:/godot/Godot_v4.7.1-stable_win64_console.exe" \
  --headless --path "D:/godot/newproject/game" \
  --script tests/smoke/core_contract_test.gd
```

结果：`ASHEN_CORE_CONTRACTS_OK`

合约测试验证了：运行状态序列化往返、无效数据拒绝、设置值清理以及宿主桥接协议消息解析。

## 手动测试清单 (Manual Test Checklist)

自动化无头测试无法判断游戏手感。在图形构建中，验证以下内容：

- `WASD` 移动跟随相机朝向。
- 鼠标旋转视角从玩家后方开始，弹簧臂避开墙壁。
- 轻/重攻击消耗不同耐力且每次挥砍仅命中一次。
- 闪避按预期方向移动，仅在其中心区间内躲避伤害。
- `Q` 或鼠标中键锁定附近的存活敌人，死亡/超出范围时解除。
- `E` 激活并在神坛处休息。
- 侧翼拉杆升起捷径大门。
- 死亡掉落烬火并在覆盖层播放后在神坛重生。
- 触碰失魂回声恢复掉落的数量。
- 守护者显示血条和胜利覆盖层。
- `Esc` 暂停，聚焦 `RESUME`，支持键盘导航。
- `F1` 以可读的动作/输入行显示准确操控，关闭后恢复先前的暂停状态。
- HUD在1280×720及至少一个更宽的桌面窗口尺寸下保持无裁剪且间距合理。
- 交互提示和守护者血条不重叠，锁定标记在可见目标上保持居中。
- 死亡表现重生后清除；死亡和胜利状态下提示和Boss表现为隐藏。
- 提示、消息、烬火、Boss、死亡和胜利的动态效果保持可读且不令人分心。

## 已知限制 (Known Limitations)

- 视觉和声音是生成的原始体，旨在验证系统而非最终制作资源。
- 单场景关卡是手动编写的，而非算法生成的。
- 暂无任务、NPC或对话基础设施。
- 游戏设置中的 `music_volume` 设置尚未连接到任何音频总线。
- 战斗平衡、前摇可读性、相机舒适度和无障碍仍需要人工游戏测试。
