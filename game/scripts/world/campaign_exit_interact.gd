extends Area3D
## 关卡出口交互点：玩家按交互键后通知世界推进下一关

signal exit_used(player: Node)

var prompt_text := "Advance to the next ruin"
var world_callback: Callable


func get_prompt() -> String:
	return prompt_text


func interact(interacting_player: Node = null) -> void:
	# 执行出口回调
	if world_callback.is_valid():
		world_callback.call(self, interacting_player)
	exit_used.emit(interacting_player)
