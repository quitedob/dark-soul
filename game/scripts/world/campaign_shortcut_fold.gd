class_name CampaignShortcutFold
extends RefCounted
## H-05：shortcut 空间折叠——单向门 + 升降梯回 Ember Shrine（数据驱动，程序化几何）

const TILE_SIZE := 6.0
const FLOOR_HEIGHT := 0.6


static func should_build(level_data: Dictionary) -> bool:
	var fold: Dictionary = level_data.get("shortcut_fold", {})
	return bool(fold.get("enabled", false))


static func build(level_data: Dictionary, cells: Array[Vector3i], material: Material) -> Node3D:
	# 在关卡中段/末段布置折叠拓扑节点
	if cells.is_empty() or not should_build(level_data):
		return null
	var fold: Dictionary = level_data.get("shortcut_fold", {})
	var ids: Dictionary = fold.get("shortcut_ids", {})
	var root := Node3D.new()
	root.name = "ShortcutFold"
	root.set_meta("shortcut_fold", true)
	root.set_meta("one_way_id", String(ids.get("one_way", "one_way_door")))
	root.set_meta("elevator_id", String(ids.get("elevator", "elevator")))
	var shrine_cell: Vector3i = cells[mini(1, cells.size() - 1)]
	var mid_cell: Vector3i = cells[clampi(int(cells.size() * 0.4), 1, cells.size() - 1)]
	var deep_cell: Vector3i = cells[clampi(int(cells.size() * 0.75), 1, cells.size() - 1)]
	if bool(fold.get("one_way_door", true)):
		root.add_child(_build_one_way_door(mid_cell, deep_cell, material))
	if bool(fold.get("elevator", true)):
		root.add_child(_build_elevator(deep_cell, shrine_cell, material))
	return root


static func _cell_position(cell: Vector3i) -> Vector3:
	return Vector3(cell.x * TILE_SIZE, cell.y * 2.0 - FLOOR_HEIGHT * 0.5, -cell.z * TILE_SIZE)


static func _build_one_way_door(door_cell: Vector3i, far_cell: Vector3i, material: Material) -> Node3D:
	# 近祠堂侧门体 + 远端激活点（打开后门体升起，形成回祠堂捷径）
	var node := Node3D.new()
	node.name = "OneWayDoor"
	node.set_meta("fold_kind", &"one_way_door")
	node.position = _cell_position(door_cell) + Vector3(0.0, FLOOR_HEIGHT * 0.5, 0.0)
	var door := StaticBody3D.new()
	door.name = "DoorBody"
	door.collision_layer = 1
	var door_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(4.2, 3.2, 0.45)
	if material is StandardMaterial3D:
		var copy := (material as StandardMaterial3D).duplicate() as StandardMaterial3D
		copy.albedo_color = Color(0.35, 0.28, 0.18, 0.95)
		box.material = copy
	else:
		box.material = material
	door_mesh.mesh = box
	door_mesh.position.y = 1.6
	door.add_child(door_mesh)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box.size
	col.shape = shape
	col.position.y = 1.6
	door.add_child(col)
	node.add_child(door)
	var far := Marker3D.new()
	far.name = "FarSideMarker"
	far.position = _cell_position(far_cell) - node.position + Vector3(0.0, 1.0, 0.0)
	node.add_child(far)
	return node


static func _build_elevator(far_cell: Vector3i, shrine_cell: Vector3i, material: Material) -> Node3D:
	# 远端升降梯：激活后平台往返祠堂停靠点
	var node := Node3D.new()
	node.name = "ElevatorLift"
	node.set_meta("fold_kind", &"elevator")
	var far_pos := _cell_position(far_cell) + Vector3(TILE_SIZE * 0.55, FLOOR_HEIGHT * 0.5, 0.0)
	var shrine_pos := _cell_position(shrine_cell) + Vector3(-TILE_SIZE * 0.55, FLOOR_HEIGHT * 0.5, 0.0)
	node.position = far_pos
	node.set_meta("shrine_dock_local", shrine_pos - far_pos)
	var platform := AnimatableBody3D.new()
	platform.name = "LiftPlatform"
	platform.collision_layer = 1
	var mesh_inst := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(3.6, 0.35, 3.6)
	if material is StandardMaterial3D:
		var copy := (material as StandardMaterial3D).duplicate() as StandardMaterial3D
		copy.albedo_color = Color(0.22, 0.24, 0.28, 0.9)
		mesh.material = copy
	else:
		mesh.material = material
	mesh_inst.mesh = mesh
	platform.add_child(mesh_inst)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = mesh.size
	col.shape = shape
	platform.add_child(col)
	node.add_child(platform)
	var dock := Marker3D.new()
	dock.name = "ShrineDock"
	dock.position = shrine_pos - far_pos
	node.add_child(dock)
	var tip := Marker3D.new()
	tip.name = "ActivateMarker"
	tip.position = Vector3(0.0, 1.2, 0.0)
	node.add_child(tip)
	return node
