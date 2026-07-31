# game/scripts/boss/boss_macro_controller.gd
class_name BossMacroController
extends RefCounted
## G-01：Boss 宏决策控制器（挂接黑板 + BT；微执行仍走 FSM）

const BlackboardScript = preload("res://scripts/enemy/ai/boss_macro_blackboard.gd")
const MacroBTScript = preload("res://scripts/enemy/ai/boss_macro_bt.gd")
const LimboPathScript = preload("res://scripts/enemy/ai/limboai_plugin_path.gd")

var blackboard: BossMacroBlackboard
var tree: BossMacroBT
## 后端标记（compat_macro 或 limboai）
var backend: StringName = &"compat_macro"


func _init() -> void:
	blackboard = BlackboardScript.new()
	tree = MacroBTScript.new()
	backend = LimboPathScript.backend_id()


## 同步敌人体感知并刷新意图
func tick_from_enemy(enemy: Node) -> StringName:
	blackboard.sync_from_enemy(enemy)
	return tree.tick(blackboard)


## 直接驱动黑板（合约 / 无敌人体场景）
func tick_blackboard() -> StringName:
	return tree.tick(blackboard)


## 标记玩家开奶（下一 tick 可抢占 heal_punish）
func set_player_healing(active: bool) -> void:
	blackboard.player_healing = active


## 重置宏层
func reset() -> void:
	blackboard.reset()
	backend = LimboPathScript.backend_id()


## 当前意图
func current_intent() -> StringName:
	return blackboard.intent
