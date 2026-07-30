# 架构 (Architecture)

## 运行时构成 (Runtime Composition)

`main.tscn` 包含一个脚本化的 `Node3D`。`game_world.gd` 在运行时创建完整的可玩场景。这使项目保持自包含，并使每个视觉效果都可以在不依赖导入资源的情况下重现。

```text
AshenHollow (Node3D, game_world.gd)
├── WorldEnvironment
├── DirectionalLight3D / OmniLight3D / 地标火盆
├── StaticBody3D 废墟几何体（墙壁、柱子、平台）
├── ProceduralAudio (procedural_audio.gd) — 9种音效提示，6声道音频池
├── HUD (hud.gd, CanvasLayer)
│   ├── 标题画面 / 暂停 / 死亡 / 胜利覆盖层
│   ├── 状态条（生命、耐力、灵力） + 烬火计数
│   ├── Boss血条、交互提示、锁定标记
│   ├── 帮助覆盖层、消息面板
│   └── MobileControls (mobile_controls.gd) — 触屏覆盖层
├── Warden (CharacterBody3D, player.gd) — 12状态FSM
│   ├── 碰撞体和原始视觉模型（身体、斗篷、面甲）
│   ├── CombatArea (combat_area.gd) — 每次挥砍单次命中
│   ├── 相机旋转轴 / SpringArm3D / Camera3D
│   └── 法术飞弹生成点
├── EmberShrine (Area3D, checkpoint.gd)
├── AncientLever (Area3D, shortcut.gd)
├── ShortcutGate (Node3D + StaticBody3D)
├── HollowSentinel ×3 (CharacterBody3D, enemy.gd)
├── AshStalker ×2 (CharacterBody3D, enemy.gd)
├── CinderGuardian (CharacterBody3D, enemy.gd) — 有二阶段的Boss
├── LostEcho (Area3D, lost_echo.gd) — 死亡时生成
├── GameHostBridge (game_host_bridge.gd) — Web ↔ 应用协议
├── NavigationRegion3D — 烘焙导航网格（0.5m半径，45°坡度）
└── 数据类：AshenRunState, AshenGameSettings, AshenLocalization
```

## 职责划分 (Responsibilities)

- `game_world.gd`：集成根节点，关卡生成，输入注册，敌人注册表，检查点/死亡循环，捷径和胜利推进流程。
- `player.gd`：权威玩家状态，移动，相机，锁定，耐力，攻击，无敌帧，伤害，死亡和烬火。
- `enemy.gd`：敌人有限状态机，导航，攻击前摇，攻击时序，伤害，重置和奖励。
- `combat_area.gd`：可复用的 `Area3D` 伤害窗口，记录挥砍中已命中的实体。
- `hud.gd`：生命/耐力/烬火显示，提示，锁定标记，守护者血条，消息，暂停和帮助。
- `checkpoint.gd`、`shortcut.gd`、`lost_echo.gd`：带过程化视觉的小型世界交互。
- `procedural_audio.gd`：运行时生成的PCM音效提示和池化播放。

## 碰撞层 (Collision Layers)

| 层 | 含义 |
|---:|---|
| 1 | 静态世界 |
| 2 | 玩家实体 |
| 3 / 值 4 | 敌人实体 |
| 4 / 值 8 | 可交互物 |

玩家攻击区域检测敌人实体。敌人攻击区域检测玩家。攻击区域没有自身的碰撞层，仅为监控模式。

## 状态机 (State Machines)

### 玩家 (Player)

```text
LOCOMOTION -> ATTACK_WINDUP -> ATTACK_ACTIVE -> ATTACK_RECOVERY -> LOCOMOTION
LOCOMOTION -> DODGE -> LOCOMOTION
LOCOMOTION -> PARRY -> LOCOMOTION
LOCOMOTION -> GUARD -> LOCOMOTION
LOCOMOTION -> CAST -> LOCOMOTION
LOCOMOTION -> LEAP_WINDUP -> LEAP_ACTIVE -> LEAP_RECOVERY -> LOCOMOTION
ANY_DAMAGEABLE -> STAGGER -> LOCOMOTION
ANY_DAMAGEABLE -> DEAD -> RESPAWN -> LOCOMOTION
```

### 敌人 (Enemy)

```text
IDLE -> CHASE -> WINDUP -> ACTIVE -> RECOVERY -> CHASE
CHASE -> RETURN -> IDLE
ANY_DAMAGEABLE -> STAGGER -> CHASE
ANY_DAMAGEABLE -> DEAD -> RESET -> IDLE
Boss (Cinder Guardian)：阶段1 → 阶段2 于生命≤50%（更快前摇，更高伤害，视觉/音频转换）
```

游戏性计时器决定伤害窗口和无敌帧。过程化姿态用于可视化这些状态，但不决定命中是否有效。

## 数据流 (Data Flow)

玩家发出属性、烬火、锁定目标和死亡信号。世界层拥有进度结果并将表现层更新转发给HUD。敌人发出生命值、交战和击败信号。可交互物调用狭义的世界方法而非拥有全局进度。

## 无头验证 (Headless Validation)

传入 `--smoke-test` 作为用户参数会执行构建、玩家属性变化、玩家伤害/治疗和敌人伤害的测试，然后打印 `ASHEN_HOLLOW_SMOKE_OK` 并退出。标准的有界无头运行还会额外检查数秒的物理和AI更新。
