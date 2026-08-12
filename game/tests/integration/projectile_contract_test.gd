extends SceneTree
## L-23 合约：投射物（spell_projectile.gd / scenes/components/spell_projectile.tscn）。
## 1) 脚本可实例化且继承 Area3D。
## 2) setup 契约：方向归一化、伤害/硬直保留、hit_payload 携带 hand/item_id/action_id/
##    tags/blockable/parryable，proj_speed / proj_lifetime 从 metadata 应用。
## 3) _ready 构建真实表现树：清空物理层、禁用 monitoring、碰撞球(0.24)、
##    mesh / light / trail 子节点齐全（veil_bolt）。
## 4) 场景文件可实例化（根节点 Area3D）。
## 完整飞行碰撞（PhysicsDirectSpaceState sweep）需真实物理帧；smoke 的 veilcraft cast
## 已在 headless 跑通 spawn+_ready 路径。

const ProjectileScript = preload("res://scripts/components/spell_projectile.gd")
const ProjectileScene = preload("res://scenes/components/spell_projectile.tscn")

var _failures: Array[String] = []


func _initialize() -> void:
	# L-19 模式：MainLoop._initialize 在树运行后触发；再推迟到首帧 idle 执行全部断言，
	# 此时 root.add_child 会自然触发 _ready（_init 阶段不会）。
	call_deferred("_run_all")


func _run_all() -> void:
	_test_script_instantiates()
	_test_setup_payload_contract()
	_test_ready_builds_projectile()
	_test_scene_loads()
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("ASHEN_PROJECTILE_CONTRACTS_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_script_instantiates() -> void:
	var projectile = ProjectileScript.new()
	_expect(projectile != null, "Spell projectile script must instantiate.")
	_expect(projectile is Area3D, "Spell projectile must extend Area3D.")
	projectile.free()


func _test_setup_payload_contract() -> void:
	var projectile = ProjectileScript.new()
	projectile.setup(null, Vector3(2.0, 0.0, 0.0), 20.0, 10.0, {
		"hand": "right",
		"item_id": "marksman_bow",
		"action_id": "bow_quick_shot",
		"tags": ["projectile", "physical"],
		"blockable": true,
		"parryable": false,
		"proj_speed": 20.0,
		"proj_lifetime": 1.8,
		"spell_type": "bow_quick_shot",
	})
	_expect(projectile.direction == Vector3.RIGHT, "Projectile must normalize its direction.")
	_expect(projectile.damage == 20.0 and projectile.stagger == 10.0, "Projectile must retain damage/stagger.")
	_expect(is_equal_approx(projectile.speed, 20.0), "Projectile must apply proj_speed from metadata.")
	_expect(is_equal_approx(projectile.lifetime, 1.8), "Projectile must apply proj_lifetime from metadata.")
	_expect(projectile.hit_payload["hand"] == "right", "Payload lost origin hand.")
	_expect(projectile.hit_payload["item_id"] == "marksman_bow", "Payload lost item id.")
	_expect(projectile.hit_payload["action_id"] == "bow_quick_shot", "Payload lost action id.")
	_expect(projectile.hit_payload["tags"].has("projectile"), "Payload must carry the projectile tag.")
	_expect(bool(projectile.hit_payload["blockable"]), "Payload must default blockable true.")
	_expect(not bool(projectile.hit_payload["parryable"]), "Payload must default parryable false.")
	projectile.free()


func _test_ready_builds_projectile() -> void:
	var source := Node3D.new()
	var projectile = ProjectileScript.new()
	# 关键前置：_spell_type 默认是 "default"，只在 setup() 里写入。必须在 add_child（触发
	# _ready）之前 setup，_ready 才能命中 veil_bolt 完整 config（含 has_trail）。
	projectile.setup(source, Vector3.FORWARD, 24.0, 14.0, {
		"hand": "right",
		"item_id": "five_elements_seal",
		"action_id": "veil_bolt",
		"spell_type": "veil_bolt",
		"proj_speed": 18.0,
		"proj_lifetime": 2.0,
	})
	_expect(
		String(projectile.get("_spell_type")) == "veil_bolt",
		"setup must set _spell_type before _ready."
	)
	# 树已运行（_run_all 在首帧 idle），add_child 会自然触发 _ready 构建表现树
	root.add_child(projectile)
	# 兜底：若 harness 未自动触发 _ready（collision_layer 仍为默认 1），手动触发一次；
	# _ready 已跑过时 collision_layer==0，跳过以免重复构建
	if projectile.collision_layer != 0:
		projectile._ready()
	_expect(projectile.collision_layer == 0 and projectile.collision_mask == 0, "Projectile must clear physics layers.")
	_expect(not projectile.monitoring, "Projectile must disable Area monitoring.")
	# Godot 4.7 给代码 XXX.new() 创建的节点名自动加 @Name@N 后缀（@CollisionShape3D@3 等），
	# 固定名 get_node_or_null 查不到 → 按类型查找（owned=false 匹配运行时子节点）。
	var collisions := projectile.find_children("*", "CollisionShape3D", true, false)
	_expect(not collisions.is_empty(), "Projectile _ready must build a collision shape.")
	if not collisions.is_empty():
		var collision := collisions[0] as CollisionShape3D
		var shape := collision.shape as SphereShape3D
		_expect(shape != null, "Projectile collision shape must be a sphere.")
		if shape != null:
			_expect(is_equal_approx(shape.radius, 0.24), "Veil bolt collision radius must be 0.24, got %s." % shape.radius)
	_expect(
		not projectile.find_children("*", "MeshInstance3D", true, false).is_empty(),
		"Projectile must build a visual mesh."
	)
	_expect(
		not projectile.find_children("*", "OmniLight3D", true, false).is_empty(),
		"Projectile must build a light."
	)
	_expect(
		not projectile.find_children("*", "GPUParticles3D", true, false).is_empty(),
		"Veil bolt must build a trail."
	)
	projectile.queue_free()
	source.free()


func _test_scene_loads() -> void:
	var scene = ProjectileScene.instantiate()
	_expect(scene != null, "Projectile scene must instantiate.")
	_expect(scene is Area3D, "Projectile scene root must be an Area3D.")
	if scene != null:
		scene.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
