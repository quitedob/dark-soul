extends SceneTree
## L-25 契约：three.js GLB（07-Pickups/pillJar）包装场景真的进了玩法。
## 验证：脚本+StaticBody3D 碰撞构建、分组裁剪（只留药罐）、材质导入、
## boss 冲击半径内破碎 / 半径外不碎、碎片刚体生成。


const PROP_SCENE := preload("res://scenes/props/destructible_jar.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	if condition:
		print("OK   %s" % label)
	else:
		failures.append(label)
		print("FAIL %s" % label)


func _run() -> void:
	var host := Node3D.new()
	host.name = "PropHost"
	root.add_child(host)
	var prop: Node3D = PROP_SCENE.instantiate() as Node3D
	prop.position = Vector3(0.0, 0.0, 0.0)
	host.add_child(prop)
	await process_frame
	await process_frame

	# 1) 结构：StaticBody3D + 脚本 + destructibles 组 + Model(拾取物 GLB 实例)
	_check(prop is StaticBody3D, "root is StaticBody3D")
	_check(prop.get_script() != null, "script attached")
	_check(prop.is_in_group("destructibles"), "in destructibles group")
	var model: Node3D = prop.get_node_or_null("Model")
	_check(model != null, "Model child (GLB instance) present")

	# 2) 分组裁剪：pillJar 保留可见，其余分组隐藏
	var jar_nodes: Array = model.find_children("pillJar", "Node3D", true, false)
	_check(not jar_nodes.is_empty(), "pillJar group found in GLB")
	var ember_nodes: Array = model.find_children("ember", "Node3D", true, false)
	var ember_hidden: bool = not ember_nodes.is_empty() and not (ember_nodes[0] as Node3D).visible
	_check(ember_hidden, "sibling group 'ember' hidden")

	# 3) 碰撞：代码构建的盒形 CollisionShape3D，尺寸合理（药罐 ~0.6m 高）
	var shapes: Array = prop.find_children("*", "CollisionShape3D", true, false)
	var has_valid_box := false
	for node in shapes:
		var collision := node as CollisionShape3D
		if collision.shape is BoxShape3D:
			var size: Vector3 = (collision.shape as BoxShape3D).size
			if size.y > 0.3 and size.y < 2.0 and size.x > 0.2:
				has_valid_box = true
	_check(has_valid_box, "BoxShape3D collision built with sane jar size")

	# 4) 材质导入：药罐网格至少一个表面带材质（glTF 材质已提取）
	var has_material := false
	if not jar_nodes.is_empty():
		var meshes: Array = (jar_nodes[0] as Node3D).find_children("*", "MeshInstance3D", true, false)
		for node in meshes:
			var mesh_instance := node as MeshInstance3D
			if mesh_instance.mesh == null or mesh_instance.mesh.get_surface_count() < 1:
				continue
			if mesh_instance.get_active_material(0) != null:
				has_material = true
				break
	_check(has_material, "imported material present on jar meshes")

	# 5) 破碎：信号 + 模型隐藏 + 碎片刚体 + 碰撞停用路径
	var signal_state := {"fired": false, "pos": Vector3.ZERO}
	(prop as StaticBody3D).connect("broken", func(source_position: Vector3):
		signal_state["fired"] = true
		signal_state["pos"] = source_position
	)
	(prop as StaticBody3D).call("smash", Vector3(1.0, 0.0, 0.0))
	_check(bool(signal_state["fired"]), "broken signal fired on smash")
	_check(bool(prop.call("is_broken")), "is_broken true after smash")
	_check(not model.visible, "model hidden after smash")
	await process_frame
	await process_frame
	var shards := 0
	for child in host.get_children():
		if child is RigidBody3D:
			shards += 1
	_check(shards >= 1, "rigid shards spawned under world host (got %d)" % shards)

	# 6) 半径判定：远处冲击不碎，近处 boss 冲击碎
	var far_prop: Node3D = PROP_SCENE.instantiate() as Node3D
	far_prop.position = Vector3(12.0, 0.0, 12.0)
	host.add_child(far_prop)
	var near_prop: Node3D = PROP_SCENE.instantiate() as Node3D
	near_prop.position = Vector3(20.0, 0.0, 20.0)
	host.add_child(near_prop)
	await process_frame
	await process_frame
	far_prop.call("apply_boss_impact", Vector3(30.0, 0.0, 30.0), 2.0)
	_check(not bool(far_prop.call("is_broken")), "out-of-radius impact does not break")
	near_prop.call("apply_boss_impact", Vector3(20.5, 0.0, 20.3), 1.5)
	_check(bool(near_prop.call("is_broken")), "in-radius boss impact breaks prop")

	if failures.is_empty():
		print("ASHEN_GLB_PROP_OK")
		quit(0)
	else:
		for failure in failures:
			printerr("GLB_PROP_FAIL: %s" % failure)
		quit(1)
