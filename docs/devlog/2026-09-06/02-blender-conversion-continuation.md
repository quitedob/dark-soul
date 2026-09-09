# Blender 86 模型续作逐项发布记录

记录时间（UTC）：2026-09-06T03:10:35.058118+00:00

原始 6 项完成记录见 01-blender-embedded-skeleton-rebuild.md。下表为本次独立验证与实际截图检查后发布的模型。

基础骨架与蒙皮完成不代表正式战斗动画或逐骨极限姿态美术验收。游戏 assets 未替换。

| 模型（相对 out） | 骨骼 / 混合网格 | 操作与截图判断 | 验证结果 | 后续改进 |
|---|---:|---|---|---|---|
| bosses/03-Jade-Faced-Fox-NineTails.glb | 72 / 18 | quadruped；九条尾按管状网格 UV 环中心恢复真实曲线，各六段，尾环刚性跟根、尾簇跟末段；正面与斜侧旋转检查尾链贴合，四足分支独立。 证据：003-fox-rest.png / 003-fox-posed.png。 | 已发布；静止误差 4.49e-07；非根骨位移 0.314；形状/材质/贴图校验通过。 | 补九尾大幅扫击、尾间碰撞及四足奔跑动画。 |
| bosses/sub-bosses/01-WrathFragment.glb | 20 / 3 | humanoid；按原部件建立躯干、头、双臂和可见腿骨，袍体使用两段混合链；正面及斜侧小幅姿态检查通过，悬浮法器保留独立位置。 证据：004-npcs-rest.png / 004-npcs-posed.png。 | 已发布；静止误差 1.38e-07；非根骨位移 0.0756；形状/材质/贴图校验通过。 | 后续做正式动画、极限关节姿态与碰撞避穿精修。 |
| bosses/sub-bosses/02-ObsessionFragment.glb | 14 / 2 | humanoid；按原部件建立躯干、头、双臂和可见腿骨，袍体使用两段混合链；正面及斜侧小幅姿态检查通过，悬浮法器保留独立位置。 证据：004-npcs-rest.png / 004-npcs-posed.png。 | 已发布；静止误差 2.89e-07；非根骨位移 0.367；形状/材质/贴图校验通过。 | 后续做正式动画、极限关节姿态与碰撞避穿精修。 |
| characters/npcs/01-Cloud-Wanderer.glb | 16 / 3 | humanoid；按原部件建立躯干、头、双臂和可见腿骨，袍体使用两段混合链；正面及斜侧小幅姿态检查通过，悬浮法器保留独立位置。 证据：004-npcs-rest.png / 004-npcs-posed.png。 | 已发布；静止误差 1.71e-07；非根骨位移 0.429；形状/材质/贴图校验通过。 | 后续做正式动画、极限关节姿态与碰撞避穿精修。 |
| characters/npcs/02-Iron-Heart.glb | 12 / 1 | humanoid；按原部件建立躯干、头、双臂和可见腿骨，袍体使用两段混合链；正面及斜侧小幅姿态检查通过，悬浮法器保留独立位置。 证据：004-npcs-rest.png / 004-npcs-posed.png。 | 已发布；静止误差 2.49e-07；非根骨位移 0.269；形状/材质/贴图校验通过。 | 后续做正式动画、极限关节姿态与碰撞避穿精修。 |
| characters/npcs/03-Lady-of-Memories.glb | 12 / 1 | humanoid；按原部件建立躯干、头、双臂和可见腿骨，袍体使用两段混合链；正面及斜侧小幅姿态检查通过，悬浮法器保留独立位置。 证据：004-npcs-rest.png / 004-npcs-posed.png。 | 已发布；静止误差 2.32e-07；非根骨位移 0.114；形状/材质/贴图校验通过。 | 后续做正式动画、极限关节姿态与碰撞避穿精修。 |
| characters/npcs/04-XuanXiao-Remnant.glb | 11 / 1 | humanoid；按原部件建立躯干、头、双臂和可见腿骨，袍体使用两段混合链；正面及斜侧小幅姿态检查通过，悬浮法器保留独立位置。 证据：004-npcs-rest.png / 004-npcs-posed.png。 | 已发布；静止误差 1.10e-07；非根骨位移 0.271；形状/材质/贴图校验通过。 | 后续做正式动画、极限关节姿态与碰撞避穿精修。 |
| characters/npcs/05-Silence-Bringer.glb | 14 / 2 | humanoid；按肩肘手和躯干链绑定，长袍混合权重；正面与斜侧前臂/袍摆小幅旋转检查通过，持械部件随手臂。 证据：005-npcs-players-rest.png / 005-npcs-players-posed.png。 | 已发布；静止误差 1.45e-07；非根骨位移 0.295；形状/材质/贴图校验通过。 | 后续做正式动画、极限关节姿态与碰撞避穿精修。 |
| characters/npcs/06-Tea-Soul.glb | 11 / 1 | humanoid；按肩肘手和躯干链绑定，长袍混合权重；正面与斜侧前臂/袍摆小幅旋转检查通过，持械部件随手臂。 证据：005-npcs-players-rest.png / 005-npcs-players-posed.png。 | 已发布；静止误差 6.50e-07；非根骨位移 0.19；形状/材质/贴图校验通过。 | 后续做正式动画、极限关节姿态与碰撞避穿精修。 |
| characters/npcs/07-Ember-Tea-Keeper.glb | 12 / 1 | humanoid；按肩肘手和躯干链绑定，长袍混合权重；正面与斜侧前臂/袍摆小幅旋转检查通过，持械部件随手臂。 证据：005-npcs-players-rest.png / 005-npcs-players-posed.png。 | 已发布；静止误差 3.86e-07；非根骨位移 0.277；形状/材质/贴图校验通过。 | 后续做正式动画、极限关节姿态与碰撞避穿精修。 |
| characters/player-classes/02-Frenzied-Warrior.glb | 18 / 1 | humanoid；按肩肘手和躯干链绑定，长袍混合权重；正面与斜侧前臂/袍摆小幅旋转检查通过，持械部件随手臂。 证据：005-npcs-players-rest.png / 005-npcs-players-posed.png。 | 已发布；静止误差 5.75e-07；非根骨位移 0.18；形状/材质/贴图校验通过。 | 后续做正式动画、极限关节姿态与碰撞避穿精修。 |
| characters/player-classes/03-Mystic-Mage.glb | 24 / 4 | humanoid；按肩肘手和躯干链绑定，长袍混合权重；正面与斜侧前臂/袍摆小幅旋转检查通过，持械部件随手臂。 证据：005-npcs-players-rest.png / 005-npcs-players-posed.png。 | 已发布；静止误差 1.61e-07；非根骨位移 0.0918；形状/材质/贴图校验通过。 | 后续做正式动画、极限关节姿态与碰撞避穿精修。 |
| characters/player-classes/04-Invocation-Master.glb | 20 / 2 | humanoid；按肩肘手和躯干链绑定，长袍混合权重；正面与斜侧前臂/袍摆小幅旋转检查通过，持械部件随手臂。 证据：005-npcs-players-rest.png / 005-npcs-players-posed.png。 | 已发布；静止误差 3.59e-07；非根骨位移 0.0983；形状/材质/贴图校验通过。 | 后续做正式动画、极限关节姿态与碰撞避穿精修。 |
| characters/player-classes/05-Yin-Yang-Master.glb | 22 / 3 | humanoid；沿现有肩肘枢轴建立双臂、持械关系及躯干腿链；袍摆/披风做混合蒙皮，正面与斜侧小幅关节姿态通过。 证据：006-players-summons-rest.png / 006-players-summons-posed.png。 | 已发布；静止误差 2.39e-07；非根骨位移 0.0927；形状/材质/贴图校验通过。 | 补职业专属持械动作、护甲抬臂和披风极限姿态避穿。 |
| characters/player-classes/06-War-Shaman.glb | 18 / 1 | humanoid；沿现有肩肘枢轴建立双臂、持械关系及躯干腿链；袍摆/披风做混合蒙皮，正面与斜侧小幅关节姿态通过。 证据：006-players-summons-rest.png / 006-players-summons-posed.png。 | 已发布；静止误差 2.77e-07；非根骨位移 0.282；形状/材质/贴图校验通过。 | 补职业专属持械动作、护甲抬臂和披风极限姿态避穿。 |
| characters/player-classes/07-Arcane-Archer.glb | 24 / 4 | humanoid；沿现有肩肘枢轴建立双臂、持械关系及躯干腿链；袍摆/披风做混合蒙皮，正面与斜侧小幅关节姿态通过。 证据：006-players-summons-rest.png / 006-players-summons-posed.png。 | 已发布；静止误差 7.01e-08；非根骨位移 0.19；形状/材质/贴图校验通过。 | 补职业专属持械动作、护甲抬臂和披风极限姿态避穿。 |
| characters/player-classes/08-Asura.glb | 30 / 7 | humanoid；沿现有肩肘枢轴建立双臂、持械关系及躯干腿链；袍摆/披风做混合蒙皮，正面与斜侧小幅关节姿态通过。 证据：006-players-summons-rest.png / 006-players-summons-posed.png。 | 已发布；静止误差 1.78e-07；非根骨位移 0.314；形状/材质/贴图校验通过。 | 补职业专属持械动作、护甲抬臂和披风极限姿态避穿。 |
| characters/summons/01-DharmaProtectingChildSpirit.glb | 14 / 2 | humanoid；沿现有肩肘枢轴建立双臂、持械关系及躯干腿链；袍摆/披风做混合蒙皮，正面与斜侧小幅关节姿态通过。 证据：006-players-summons-rest.png / 006-players-summons-posed.png。 | 已发布；静止误差 1.19e-07；非根骨位移 0.181；形状/材质/贴图校验通过。 | 补职业专属持械动作、护甲抬臂和披风极限姿态避穿。 |
| characters/summons/02-GoldenArmoredGuardian.glb | 14 / 1 | humanoid；沿现有肩肘枢轴建立双臂、持械关系及躯干腿链；袍摆/披风做混合蒙皮，正面与斜侧小幅关节姿态通过。 证据：006-players-summons-rest.png / 006-players-summons-posed.png。 | 已发布；静止误差 2.08e-07；非根骨位移 0.265；形状/材质/贴图校验通过。 | 补职业专属持械动作、护甲抬臂和披风极限姿态避穿。 |
