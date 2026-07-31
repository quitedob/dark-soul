extends Area3D
## L-04 隐藏结局证物：天炉低语的红晶残片（5-1..5-4）。
## 拾取后由 game_world 置 furnace_memory_N 旗标并推进三真相任务。

signal memory_claimed(memory_key: String, crystal: Node)

var prompt_text := "Read the red crystal memory"
var memory_key := "furnace_memory_1"
var world_callback: Callable


func get_prompt() -> String:
	return prompt_text


func interact(interacting_player: Node = null) -> void:
	if world_callback.is_valid():
		world_callback.call(self, interacting_player)
	memory_claimed.emit(memory_key, self)
