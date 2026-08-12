extends SceneTree
## L-20：弱点骨骼锚点合约
## 1) 每个 Boss profile 的 weak_point_bone_name 落在真实 GLB 语义命名节点上（非 Bone_001 式空名）。
## 2) 有骨名且节点可解析 → get_execution_anchor 返回骨/节点 world 坐标，而非 weak_point_offset。
## 3) 最小 Skeleton3D + 骨 → 骨锚优先（get_bone_global_pose + to_global 换算）。
## 4) 无骨名 / 骨名不可解析 → 回退 weak_point_offset 虚拟偏移。
## 5) 非 Boss back / 默认前向偏移行为不变。

const Catalog = preload("res://scripts/combat/data/boss_execution_catalog.gd")
const EnemyScript = preload("res://scripts/enemy.gd")

# 真实玩法 game_world._spawn_content_enemy 会给 Boss 补 body_type（by_id 真模型优先加载）
const BOSS_CONTENT := {
	"boss_giant_gate": {"body_type": "armored_medium"},
	"boss_xing_tian": {"body_type": "elite_armored"},
	"boss_nine_tails": {"body_type": "beast_humanoid"},
	"boss_xuan_xiao": {"body_type": "celestial_guard"},
	"boss_zhu_yin": {"body_type": "ancient_giant"},
	"boss_blind_bell": {"body_type": "hanging_bell"},
}

var _failures: Array[String] = []


## 测试体内要 add_child 节点并读取 is_inside_tree()/global_position（含 get_bone_global_pose 等），
## 必须在树内运行，故从 _init 延后到首帧 idle（同 L-19 已修复的 deferred 模式）。
func _initialize() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	_test_catalog_bone_names_resolve_to_real_nodes()
	_test_skeleton3d_bone_anchor()
	_test_offset_fallback_when_bone_empty()
	_test_offset_fallback_when_bone_unresolvable()
	_test_non_boss_anchors_unchanged()
	if _failures.is_empty():
		print("ASHEN_BOSS_EXECUTION_ANCHOR_CONTRACTS_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _make_boss(boss_id: String):
	var enemy = EnemyScript.new()
	root.add_child(enemy)
	var content := {"id": boss_id, "max_health": 200.0}
	content.merge(BOSS_CONTENT.get(boss_id, {}), true)
	enemy.setup_from_content(null, null, null, Vector3.ZERO, content, true)
	return enemy


## 合约 1 + 2：每个 Boss 的骨名都要能在其真模型视觉树里解析到，且骨锚优先于 offset。
func _test_catalog_bone_names_resolve_to_real_nodes() -> void:
	for boss_id: String in BOSS_CONTENT.keys():
		var profile = Catalog.profile_for_boss_id(boss_id)
		_expect(profile != null, "Missing profile for %s" % boss_id)
		if profile == null:
			continue
		var bone_name: StringName = profile.weak_point_bone_name
		_expect(bone_name != &"", "%s: weak_point_bone_name 必须非空（GLB 有语义命名节点可锚）。" % boss_id)
		if bone_name == &"":
			continue
		var enemy = _make_boss(boss_id)
		var node := enemy.body_visual_root.find_child(String(bone_name), true, false) as Node3D
		_expect(node != null, "%s: 骨名 '%s' 未在视觉树解析到（真 GLB 是否加载？）。" % [boss_id, bone_name])
		var got := enemy.get_execution_anchor(profile.weak_point_anchor)
		var offset: Vector3 = enemy.global_position + enemy.global_transform.basis * profile.weak_point_offset
		if node != null:
			_expect(
				got.is_equal_approx(node.global_position),
				"%s: anchor 必须等于节点 world 坐标, got %s node %s。" % [boss_id, got, node.global_position]
			)
			_expect(
				not got.is_equal_approx(offset),
				"%s: 存在真节点时不得走虚拟 offset。" % boss_id
			)
		enemy.queue_free()


## 合约 3：最小 Skeleton3D + 骨 → 骨锚优先（get_bone_global_pose + to_global）。
func _test_skeleton3d_bone_anchor() -> void:
	var enemy = _make_boss("boss_giant_gate")
	var skel := Skeleton3D.new()
	skel.name = "TestSkeleton"
	skel.add_bone("ChestBone")
	skel.set_bone_rest(0, Transform3D(Basis.IDENTITY, Vector3(0.0, 1.7, 0.3)))
	enemy.body_visual_root.add_child(skel)
	enemy.boss_break_profile.weak_point_bone_name = &"ChestBone"
	var expected: Vector3 = skel.to_global(skel.get_bone_global_pose(0).origin)
	var got := enemy.get_execution_anchor(enemy.boss_break_profile.weak_point_anchor)
	var offset: Vector3 = enemy.global_position + enemy.global_transform.basis * enemy.boss_break_profile.weak_point_offset
	# got 必须等于骨位（若 Skeleton3D 路径未命中，got 会是 offset，与骨位不同 → 本断言失败）
	_expect(
		got.is_equal_approx(expected),
		"Skeleton3D: 骨锚 expected %s got %s（应走真骨而非 offset）。" % [expected, got]
	)
	# 骨位(0,1.7,0.3)≠ offset(0,1.85,0.55)：走真骨即不等于 offset 回退
	_expect(
		not got.is_equal_approx(offset),
		"Skeleton3D: 必须走真骨而非 offset 回退, got %s offset %s。" % [got, offset]
	)
	enemy.queue_free()


## 合约 4a：无骨名 → offset 回退。
func _test_offset_fallback_when_bone_empty() -> void:
	var enemy = _make_boss("boss_giant_gate")
	enemy.boss_break_profile.weak_point_bone_name = &""
	var expected: Vector3 = enemy.global_position + enemy.global_transform.basis * enemy.boss_break_profile.weak_point_offset
	var got := enemy.get_execution_anchor(enemy.boss_break_profile.weak_point_anchor)
	_expect(got.is_equal_approx(expected), "空骨名必须回退 offset, got %s expected %s。" % [got, expected])
	enemy.queue_free()


## 合约 4b：骨名不可解析 → offset 回退。
func _test_offset_fallback_when_bone_unresolvable() -> void:
	var enemy = _make_boss("boss_giant_gate")
	enemy.boss_break_profile.weak_point_bone_name = &"no_such_part"
	var expected: Vector3 = enemy.global_position + enemy.global_transform.basis * enemy.boss_break_profile.weak_point_offset
	var got := enemy.get_execution_anchor(enemy.boss_break_profile.weak_point_anchor)
	_expect(got.is_equal_approx(expected), "不可解析骨名必须回退 offset, got %s。" % got)
	enemy.queue_free()


## 合约 5：非 Boss（无 profile）back / 默认前向偏移行为不变。
func _test_non_boss_anchors_unchanged() -> void:
	var enemy = EnemyScript.new()
	root.add_child(enemy)
	enemy.setup(null, null, null, Vector3.ZERO)
	_expect(enemy.boss_break_profile == null, "非 Boss 不得有 break profile。")
	# global_position=(0,0,0), identity basis：back = (0,1.05,0.55), 默认前向 = (0,1.15,-0.35)
	_expect(
		enemy.get_execution_anchor(&"back").is_equal_approx(Vector3(0.0, 1.05, 0.55)),
		"非 Boss backstab 锚点被改动: %s" % enemy.get_execution_anchor(&"back")
	)
	_expect(
		enemy.get_execution_anchor(&"misc").is_equal_approx(Vector3(0.0, 1.15, -0.35)),
		"非 Boss 默认前向锚点被改动: %s" % enemy.get_execution_anchor(&"misc")
	)
	# 无 profile 时 legacy 弱点锚名落到默认前向偏移（行为不变）
	_expect(
		enemy.get_execution_anchor(&"furnace_core").is_equal_approx(Vector3(0.0, 1.15, -0.35)),
		"非 Boss legacy 弱点锚名行为被改动: %s" % enemy.get_execution_anchor(&"furnace_core")
	)
	enemy.queue_free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
