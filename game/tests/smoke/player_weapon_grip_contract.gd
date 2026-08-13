extends SceneTree
## 武器握持合约（坐标系分离统一回归守卫）：
## 修复前，身体是 BodyRoot（resolver 里带 yaw_deg 180）的子节点，而武器/盾是
## visual_root 的直接子节点（yaw 0、写死位置）——两套坐标系分离，武器永远对不上手。
## 修复后，朝向统一到一个 BodyYaw（yaw 180）公共父节点，身体/武器都挂其下。
## 本合约直接复现该结构并断言：挂在 HAND_RIGHT_REST 的武器 pivot 与真实右手骨
## DEF-hand.R 的世界位置重合（且该世界位置等于 yaw-180 变换后的 (-0.739,1.441,-0.065)），
## 同时验证「常量正确」与「yaw 确实应用到公共父节点」两件事。
## 注意（引擎实测）：add_child 后 global_transform 需 await process_frame 才传播，
## 故这里 await 两帧再读，避免读到陈旧值。

const CharacterMeshFactory = preload("res://scripts/core/character_meshes.gd")
const PlayerVisualsScript = preload("res://scripts/core/player_visuals.gd")

const SUCCESS_MARKER := "ASHEN_PLAYER_WEAPON_GRIP_CONTRACTS_OK"
const EPS := 0.05

var _failures: Array[String] = []


func _initialize() -> void:
	# SceneTree 启动阶段：_init() 时树尚未 inside，global_transform 不真实；延迟到循环内。
	call_deferred("_run")


func _run() -> void:
	var body_yaw := Node3D.new()
	body_yaw.name = "BodyYaw"
	body_yaw.rotation.y = PlayerVisualsScript.BODY_YAW
	root.add_child(body_yaw)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("26384a")
	# 无职业 id → 走 player/body（mannyquin.glb，含 Skeleton3D + DEF-* 骨）。
	CharacterMeshFactory.build_player(body_yaw, mat, mat, "")

	var weapon_pivot := Node3D.new()
	weapon_pivot.name = "WeaponPivot"
	weapon_pivot.position = PlayerVisualsScript.HAND_RIGHT_REST
	body_yaw.add_child(weapon_pivot)

	# 等待变换传播（见文件头注释）。
	await process_frame
	await process_frame

	var skel := _first_skeleton(body_yaw)
	_expect(skel != null, "body must contain a Skeleton3D (mannyquin real model).")
	if skel == null:
		_finish()
		return

	var bone_idx := skel.find_bone("DEF-hand.R")
	_expect(bone_idx >= 0, "skeleton must contain bone 'DEF-hand.R'.")
	if bone_idx < 0:
		_finish()
		return

	var hand_rest := skel.get_bone_global_rest(bone_idx)
	var hand_world := skel.to_global(hand_rest.origin)

	# 1) 武器 pivot 必须落在右手骨上（坐标系统一的直接断言）。
	_expect(
		_vec3_approx(weapon_pivot.global_position, hand_world),
		"weapon pivot must sit on DEF-hand.R (got %s, want %s)" % [weapon_pivot.global_position, hand_world]
	)
	# 2) yaw 确实应用到公共父节点：手骨 model rest (-0.739,1.441,-0.065) 绕 Y 转 180° → (+0.739,1.441,+0.065)。
	var expected_world := Vector3(0.739, 1.441, 0.065)
	_expect(
		_vec3_approx(weapon_pivot.global_position, expected_world),
		"weapon pivot world position must reflect yaw-180 (got %s, want %s)" % [weapon_pivot.global_position, expected_world]
	)

	weapon_pivot.free()
	body_yaw.free()
	_finish()


func _first_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var hit := _first_skeleton(child)
		if hit != null:
			return hit
	return null


func _vec3_approx(a: Vector3, b: Vector3) -> bool:
	return absf(a.x - b.x) <= EPS and absf(a.y - b.y) <= EPS and absf(a.z - b.z) <= EPS


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print(SUCCESS_MARKER)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
