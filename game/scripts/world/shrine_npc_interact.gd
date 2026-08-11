# game/scripts/world/shrine_npc_interact.gd
extends Area3D
## 烬龛旁 NPC 交互：打开 DialogueRunner 台词

signal talk_requested(npc_id: StringName, player: Node)

var prompt_text := "与云游交谈"
var npc_id: StringName = &"npc_cloud_wanderer"
var world_callback: Callable
# 真模型特效层:ModelRoot 接地 base_y 只捕获一次,逐帧只绕其振荡。
var _model_base_y := 0.0
var _model_base_y_set := false


func _process(delta: float) -> void:
	# 真模型特效层:按 npc/<id> 档案施加专属运动 + 环境粒子/光环。
	# 宿主选在本节点(每 NPC 自驱):无需 game_world 逐帧轮询或登记 tea soul 引用,
	# 全局状态耦合最小;无 ModelRoot 的交互节点(如钟塔入口门洞)自动跳过。
	var model_root := get_node_or_null("ModelRoot") as Node3D
	if model_root == null:
		return
	if not _model_base_y_set:
		_model_base_y = model_root.position.y
		_model_base_y_set = true
	var profile := ModelMotionProfiles.profile_for("npc/%s" % String(npc_id))
	var vfx: Dictionary = profile.get("vfx", {})
	ModelFx.apply_movement(model_root, _model_base_y, profile.get("movement", {}), delta)
	ModelFx.ensure_ambient(self, vfx.get("ambient", {}))
	if vfx.has("aura"):
		ModelFx.ensure_aura(self, vfx["aura"])


func get_prompt() -> String:
	return prompt_text


func interact(interacting_player: Node = null) -> void:
	if world_callback.is_valid():
		world_callback.call(self, interacting_player)
	talk_requested.emit(npc_id, interacting_player)
