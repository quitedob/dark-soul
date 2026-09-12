extends Node
## P0-2：Boss 专属流程主机（通用主机 Node）。
##
## 用途：让章节 Boss 内容 dict 通过可选 "flow" 字段挂载一段专属流程脚本。
## game_world 在 _spawn_content_enemy 生成 Boss 后调用 _attach_boss_flow → 本节点读取
## content["flow"] 并完成挂载 / 桥接。无 flow 字段或 script 无效时零行为改变，
## 现有 Boss（巨阙/刑天/九尾/玄霄/烛阴/盲钟）完全不受影响。
##
## ──────────────────────────────── 契约（wave2 三个 Boss 流程脚本用）───────────────────────────────
## 在对应章节 Boss 内容 dict 增加可选字段：
##   "flow": {
##       "script": "res://scripts/boss/flow/<xxx>_flow.gd",   # 必填：流程脚本 res:// 路径
##       "config": { ... }                                     # 可选：流程自定义配置
##   }
##
## 挂载时主机将：
##   1. script 非空且 ResourceLoader.exists(script) → 实例化该脚本为 Node，命名
##      "FlowController"，add_child 到 boss（随 boss 释放自动释放）。
##   2. 向流程节点写引用（脚本须声明以下属性）：
##        flow_boss   : Node       —— 所属 Boss（Enemy 节点）
##        flow_config : Dictionary —— flow.config 子字典；无 config 时即整 flow dict
##   3. 若流程节点声明 _on_phase(new_phase: int)：连接 boss.phase_changed → 它
##      （主机转发层只把 new_phase 传给流程节点，不传 enemy 节点）。
##   4. 若流程节点声明 _on_story_threshold(story_flag: String, health_ratio: float)：
##      连接 boss.story_threshold_reached → 它。
##
## 流程脚本最小骨架：
##   extends Node
##   var flow_boss: Node
##   var flow_config: Dictionary = {}
##   func _on_phase(new_phase: int) -> void: ...
##   func _on_story_threshold(story_flag: String, health_ratio: float) -> void: ...
## ──────────────────────────────────────────────────────────────────────────────────────

## 当前挂载的流程节点（"FlowController"；null = 未挂载）
var flow_node: Node = null
var encounter: Node


## 挂载流程。boss：Enemy 节点；content：章节内容 dict（含可选 "flow"）。
## 返回是否成功挂载流程节点。任一步骤不满足即返回 false（零副作用）。
func attach(boss: Node, content: Dictionary) -> bool:
	flow_node = null
	if boss == null or not is_instance_valid(boss):
		return false
	var raw_flow: Variant = content.get("flow")
	if not raw_flow is Dictionary:
		return false
	var flow: Dictionary = raw_flow
	var script_path := String(flow.get("script", ""))
	if script_path.is_empty():
		return false
	if not ResourceLoader.exists(script_path):
		return false
	var resource: Resource = load(script_path)
	if not resource is Script:
		return false
	var instance: Variant = resource.new()
	if not instance is Node:
		return false
	var node: Node = instance
	node.name = "FlowController"
	flow_node = node
	# 写引用（脚本未声明这些属性时安全跳过）
	if "flow_boss" in node:
		node.set("flow_boss", boss)
	if "flow_config" in node:
		var config: Variant = flow.get("config", flow)
		node.set("flow_config", config)
	boss.add_child(node)
	# 桥接信号：转发层处理参数映射（phase_changed 发 (enemy, new_phase) → flow._on_phase(int)）
	if node.has_method("_on_phase") and boss.has_signal("phase_changed"):
		boss.phase_changed.connect(_on_boss_phase_forwarded)
	if node.has_method("_on_story_threshold") and boss.has_signal("story_threshold_reached"):
		boss.story_threshold_reached.connect(_on_story_threshold_forwarded)
	return true


func bind_encounter(boundary: Node) -> void:
	encounter = boundary
	if not boundary.encounter_started.is_connected(_on_encounter_started):
		boundary.encounter_started.connect(_on_encounter_started)
		boundary.encounter_reset.connect(_on_encounter_reset)
		boundary.encounter_resolved.connect(_on_encounter_resolved)
	if is_instance_valid(flow_node) and flow_node.has_method("bind_encounter"):
		flow_node.bind_encounter(boundary)


func _on_encounter_started() -> void:
	if is_instance_valid(flow_node) and flow_node.has_method("_on_encounter_started"):
		flow_node._on_encounter_started()


func _on_encounter_reset() -> void:
	if is_instance_valid(flow_node) and flow_node.has_method("_on_encounter_reset"):
		flow_node._on_encounter_reset()


func _on_encounter_resolved() -> void:
	if is_instance_valid(flow_node) and flow_node.has_method("_on_encounter_resolved"):
		flow_node._on_encounter_resolved()


## 转发 boss.phase_changed → flow_node._on_phase(new_phase)
func _on_boss_phase_forwarded(_enemy: Node, new_phase: int) -> void:
	if flow_node != null and is_instance_valid(flow_node) and flow_node.has_method("_on_phase"):
		flow_node._on_phase(int(new_phase))


## 转发 boss.story_threshold_reached → flow_node._on_story_threshold(story_flag, health_ratio)
func _on_story_threshold_forwarded(story_flag: StringName, health_ratio: float) -> void:
	if flow_node != null and is_instance_valid(flow_node) and flow_node.has_method("_on_story_threshold"):
		flow_node._on_story_threshold(String(story_flag), float(health_ratio))
