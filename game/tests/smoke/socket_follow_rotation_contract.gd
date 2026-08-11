extends SceneTree
## 挂点跟随命中盒合约（Finding 6 运行时验证）：
## _sync_socket_follow 现在用 `_follow_socket.global_transform.translated_local(_socket_local_offset)`
## 同步 —— 该赋值把挂点整套 Transform（basis + origin）复制到命中盒，
## 因此 capsule 不再只跟位置，而是完整跟随武器挂点的朝向（旋转）与位姿。
## 本合约只做确定性状态调用，不依赖物理帧：关闭 _physics_process 后直接调用
## _sync_socket_follow() 复核同步结果。
##
## 注意（引擎实测）：Godot 4.7.1 的 Transform3D.translated_local() 把 offset 放在挂点
## 局部系内应用 —— origin += basis * offset（用挂点 basis 旋转偏移）且返回结果的 basis
## 完全继承挂点 basis。故旋转跟随既由 basis 断言证明，也由「旋转后的 origin」断言证明；
## 单位朝向挂点下 basis * offset == offset，退化为纯平移，旧位置跟随语义不变。

const CombatAreaScript = preload("res://scripts/combat_area.gd")

const SUCCESS_MARKER := "ASHEN_SOCKET_FOLLOW_ROTATION_CONTRACTS_OK"
const LOCAL_OFFSET := Vector3(0.0, 1.0, -1.0)
var _failures: Array[String] = []


func _initialize() -> void:
	# SceneTree 启动阶段：_init() 时树尚未 inside，_ready() 不触发；必须延迟到循环内，
	# 这样 combat_area/socket 的 global_transform 才真实可读。
	call_deferred("_run")


func _run() -> void:
	# ---- 准备非单位朝向的挂点 socket：既有位移又有绕 Y 与绕 X 的旋转 ----
	var socket := Node3D.new()
	socket.name = "TestWeaponSocket"
	root.add_child(socket)
	socket.global_position = Vector3(3.0, 2.0, 1.0)
	socket.basis = Basis.IDENTITY.rotated(Vector3.UP, deg_to_rad(45.0))
	socket.basis = socket.basis.rotated(Vector3.RIGHT, deg_to_rad(-30.0))

	# ---- 构建共享命中体积并开启挂点跟随 ----
	var area = CombatAreaScript.new()
	area.name = "TestCombatArea"
	root.add_child(area)
	area.configure(socket, 1.0)
	# 本合约只做确定性状态调用，不需要物理帧；关掉避免 _physics_process 引入时序歧义。
	area.set_physics_process(false)

	area.set_socket_follow(socket, LOCAL_OFFSET)

	# ---- (d) 断言旋转跟随：命中盒 basis 继承挂点旋转（Finding 6 的核心） ----
	_expect(
		_basis_approx(area.global_transform.basis, socket.global_transform.basis),
		"socket follow must inherit socket rotation into hitbox basis (got %s, want %s)" % [area.global_transform.basis, socket.global_transform.basis]
	)
	# 旧实现（仅跟位置）会把 basis 留在单位阵；非单位断言直接挡住该回归。
	_expect(
		not area.global_transform.basis.is_equal_approx(Basis.IDENTITY),
		"socket follow must yield a non-identity hitbox basis when the socket is rotated (got %s)" % area.global_transform.basis
	)
	# origin：translated_local() 在挂点局部系应用 offset —— 用挂点 basis 旋转 offset 后再
	# 加到挂点位置（world-space basis-rotated）。非单位朝向下该值与裸 +offset 不同，直接
	# 挡住「offset 按世界系加」的回归。
	var expected_origin := socket.global_position + socket.global_transform.basis * LOCAL_OFFSET
	_expect(
		_vec3_approx(area.global_position, expected_origin),
		"socket follow must place hitbox at socket pos + basis-rotated offset (got %s, want %s)" % [area.global_position, expected_origin]
	)

	# ---- 位移 + 旋转挂点后手动 re-sync：命中盒必须持续跟随新位姿（非单帧快照） ----
	socket.global_position = Vector3(-2.0, 4.0, 3.0)
	socket.basis = socket.basis.rotated(Vector3.FORWARD, deg_to_rad(20.0))
	area._sync_socket_follow()
	_expect(
		_basis_approx(area.global_transform.basis, socket.global_transform.basis),
		"socket follow must re-sync rotation after socket rotates (got %s, want %s)" % [area.global_transform.basis, socket.global_transform.basis]
	)
	expected_origin = socket.global_position + socket.global_transform.basis * LOCAL_OFFSET
	_expect(
		_vec3_approx(area.global_position, expected_origin),
		"socket follow must re-sync to basis-rotated position after socket moves (got %s, want %s)" % [area.global_position, expected_origin]
	)

	# ---- (e) 清除跟随：_use_socket_follow 复位且不再追踪挂点位姿 ----
	var pos_before_clear: Vector3 = area.global_position
	area.clear_socket_follow()
	_expect(area._use_socket_follow == false, "clear_socket_follow must reset _use_socket_follow to false")
	_expect(area._follow_socket == null, "clear_socket_follow must null the follow socket")
	socket.global_position = Vector3(100.0, 0.0, 0.0)
	area._sync_socket_follow()
	_expect(
		_vec3_approx(area.global_position, pos_before_clear),
		"after clear_socket_follow, hitbox must stop tracking the socket (got %s)" % area.global_position
	)

	# ---- (f) 单位朝向挂点回归：旧的位置跟随语义仍成立（identity basis 退化为纯平移） ----
	var flat_socket := Node3D.new()
	flat_socket.name = "TestFlatSocket"
	root.add_child(flat_socket)
	flat_socket.global_position = Vector3(1.0, -1.0, 2.0)
	area.set_socket_follow(flat_socket, LOCAL_OFFSET)
	_expect(
		_vec3_approx(area.global_position, flat_socket.global_position + LOCAL_OFFSET),
		"identity socket must keep old position-follow semantics (got %s)" % area.global_position
	)
	_expect(
		_basis_approx(area.global_transform.basis, Basis.IDENTITY),
		"identity socket must leave hitbox basis at identity (got %s)" % area.global_transform.basis
	)
	area.clear_socket_follow()

	socket.free()
	flat_socket.free()
	area.free()

	if _failures.is_empty():
		print(SUCCESS_MARKER)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _vec3_approx(a: Vector3, b: Vector3) -> bool:
	return is_equal_approx(a.x, b.x) and is_equal_approx(a.y, b.y) and is_equal_approx(a.z, b.z)


func _basis_approx(a: Basis, b: Basis) -> bool:
	return _vec3_approx(a.x, b.x) and _vec3_approx(a.y, b.y) and _vec3_approx(a.z, b.z)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
