extends Area3D
## 5-3 轮回歧路·因果回放交互：逐章回顾四章命运选择，接受或悔（samsara_stance 段旗）。
## 交互由 game_world 的 world_callback 触发链式 FateChoiceOverlay 回放。

var prompt_text := "回望往昔的选择"
var world_callback: Callable


func get_prompt() -> String:
	return prompt_text


func interact(interacting_player: Node = null) -> void:
	if world_callback.is_valid():
		world_callback.call(self, interacting_player)
