# game/scripts/world/shrine_npc_interact.gd
extends Area3D
## 烬龛旁 NPC 交互：打开 DialogueRunner 台词

signal talk_requested(npc_id: StringName, player: Node)

var prompt_text := "与云游交谈"
var npc_id: StringName = &"npc_cloud_wanderer"
var world_callback: Callable


func get_prompt() -> String:
	return prompt_text


func interact(interacting_player: Node = null) -> void:
	if world_callback.is_valid():
		world_callback.call(self, interacting_player)
	talk_requested.emit(npc_id, interacting_player)
