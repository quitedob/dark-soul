# game/scripts/enemy/heal_react.gd
extends RefCounted
class_name EnemyHealReact
## 非 Boss 治疗反应：短时加速追击（与 Boss punish 变体分离）

const SPEED_MULT := 1.5
const DURATION_SEC := 1.8


## 对普通敌人施加治疗追击加速；返回用于失效校验的 token
static func apply_chase_boost(enemy: Node, heal_speed_id: int) -> int:
	if enemy == null or not is_instance_valid(enemy):
		return heal_speed_id
	if not ("move_speed" in enemy):
		return heal_speed_id
	var original_speed: float = float(enemy.get_meta("heal_react_base_speed", enemy.move_speed))
	enemy.set_meta("heal_react_base_speed", original_speed)
	enemy.move_speed = original_speed * SPEED_MULT
	var next_id: int = heal_speed_id + 1
	var tree: SceneTree = enemy.get_tree()
	if tree == null:
		enemy.move_speed = original_speed
		enemy.remove_meta("heal_react_base_speed")
		return next_id
	var restore_timer := tree.create_timer(DURATION_SEC)
	var enemy_ref: WeakRef = weakref(enemy)
	restore_timer.timeout.connect(func():
		var receiver: Node = enemy_ref.get_ref()
		if is_instance_valid(receiver) and int(receiver.get("_heal_speed_id")) == next_id:
			receiver.move_speed = original_speed
			receiver.remove_meta("heal_react_base_speed")
	)
	return next_id
