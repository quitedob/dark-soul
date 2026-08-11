extends SceneTree
## Real-model swap pipeline contract:
## 1) Every REGISTRY path must resolve to a loadable GLB.
## 2) Registered player body / weapon / shield swap to real GLB models
##    (BodyRoot / ModelRoot present under the parent).
## 3) A real enemy body carries its weapon baked into the GLB — the separate
##    weapon slot stays EMPTY (no double weapon). Unregistered keys fall back
##    to procedural geometry (no ModelRoot, children present).
## 4) Live models (enemy/boss/summon/npc) ground-align: lowest mesh ≈ y 0.

const CharacterMeshFactory = preload("res://scripts/core/character_meshes.gd")
const WeaponMeshFactory = preload("res://scripts/core/weapon_meshes.gd")
const ChapterEnemyFactory = preload("res://scripts/combat/enemy_factory.gd")
const RealModelResolver = preload("res://scripts/core/real_model_resolver.gd")

var _failures: Array[String] = []


func _init() -> void:
	_test_registry_paths_load()
	_test_player_body_swap()
	_test_player_weapon_swap()
	_test_player_shield_swap()
	_test_enemy_body_weapon_swap()
	_test_enemy_by_id_swap()
	_test_fallback_when_no_model()
	_test_ground_alignment()
	if _failures.is_empty():
		print("REAL_MODEL_CONTRACTS_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_registry_paths_load() -> void:
	for id: String in RealModelResolver.REGISTRY:
		var entry: Dictionary = RealModelResolver.REGISTRY[id]
		var path := String(entry.get("path", ""))
		_expect(not path.is_empty(), "Registry entry '%s' missing path." % id)
		_expect(ResourceLoader.exists(path), "Registry path missing for '%s': %s" % [id, path])
		_expect(load(path) != null, "Registry path failed to load for '%s': %s" % [id, path])


func _test_player_body_swap() -> void:
	var parent := Node3D.new()
	CharacterMeshFactory.build_player(parent, StandardMaterial3D.new(), StandardMaterial3D.new())
	var body_root := parent.get_node_or_null("BodyRoot")
	_expect(body_root != null, "Player body swap: BodyRoot not created after build_player.")
	_expect(body_root != null and body_root.get_child_count() > 0, "Player body swap: BodyRoot has no child model.")
	parent.free()


func _test_player_weapon_swap() -> void:
	var parent := Node3D.new()
	WeaponMeshFactory.build_into_parent(parent, "sword", StandardMaterial3D.new())
	_expect(parent.get_node_or_null("ModelRoot") != null, "Player weapon swap: ModelRoot not created for sword.")
	parent.free()


func _test_player_shield_swap() -> void:
	var parent := Node3D.new()
	WeaponMeshFactory.build_shield(parent, StandardMaterial3D.new())
	_expect(parent.get_node_or_null("ModelRoot") != null, "Player shield swap: ModelRoot not created for shield.")
	parent.free()


func _test_enemy_body_weapon_swap() -> void:
	var body := Node3D.new()
	var weapon := Node3D.new()
	ChapterEnemyFactory.build_into_slots(
		body, weapon,
		{"body_type": "armored_medium", "weapon_shape": "rusted_blade"},
		StandardMaterial3D.new(), StandardMaterial3D.new()
	)
	_expect(body.get_node_or_null("ModelRoot") != null, "Enemy body swap: ModelRoot not created for armored_medium.")
	# Real bodies bake their weapon into the GLB → weapon slot stays empty.
	_expect(weapon.get_child_count() == 0, "Enemy body swap: real body must NOT double-build a separate weapon.")
	body.free()
	weapon.free()


func _test_enemy_by_id_swap() -> void:
	# Per-enemy-id resolution: bespoke GLB wins over body_type.
	var body := Node3D.new()
	var weapon := Node3D.new()
	ChapterEnemyFactory.build_into_slots(
		body, weapon,
		{"id": "lost_soul_soldier", "body_type": "wraith_thin", "weapon_shape": "rusted_blade"},
		StandardMaterial3D.new(), StandardMaterial3D.new()
	)
	_expect(body.get_node_or_null("ModelRoot") != null, "Enemy by-id swap: lost_soul_soldier ModelRoot missing.")
	_expect(weapon.get_child_count() == 0, "Enemy by-id swap: real body must NOT double-build a separate weapon.")
	body.free()
	weapon.free()


func _test_fallback_when_no_model() -> void:
	var weapon_parent := Node3D.new()
	WeaponMeshFactory.build_into_parent(weapon_parent, "dagger", StandardMaterial3D.new())
	_expect(weapon_parent.get_node_or_null("ModelRoot") == null, "Fallback: dagger unexpectedly resolved a real model.")
	_expect(weapon_parent.get_child_count() > 0, "Fallback: dagger produced no procedural geometry.")
	weapon_parent.free()

	# Unregistered body type → procedural body + procedural weapon.
	var body := Node3D.new()
	var weapon := Node3D.new()
	ChapterEnemyFactory.build_into_slots(
		body, weapon,
		{"body_type": "unregistered_test_type", "weapon_shape": "memory_claw"},
		StandardMaterial3D.new(), StandardMaterial3D.new()
	)
	_expect(body.get_node_or_null("ModelRoot") == null, "Fallback: unregistered body_type unexpectedly resolved a real model.")
	_expect(weapon.get_node_or_null("ModelRoot") == null, "Fallback: memory_claw unexpectedly resolved a real model.")
	_expect(body.get_child_count() > 0, "Fallback: unregistered body produced no procedural body.")
	_expect(weapon.get_child_count() > 0, "Fallback: memory_claw produced no procedural weapon.")
	body.free()
	weapon.free()


func _test_ground_alignment() -> void:
	# Every live model (enemy/boss/summon/npc) must have its lowest mesh at ≈ y 0
	# after align_ground, so models don't sink into the floor.
	for id: String in RealModelResolver.REGISTRY:
		if not (
			id.begins_with("enemy/body/by_id/")
			or id.begins_with("summon/")
			or id.begins_with("npc/")
		):
			continue
		var parent := Node3D.new()
		if not RealModelResolver.try_instance(id, parent):
			_expect(false, "Ground-align: try_instance failed for '%s'." % id)
			parent.free()
			continue
		# Measure in parent space (includes the container's ground lift).
		var min_y := _min_y_relative(parent)
		_expect(min_y >= -0.06, "Ground-align: '%s' lowest mesh at y=%.3f (sinks into floor)." % [id, min_y])
		parent.free()


## Min Y of all mesh AABBs relative to `top`'s local space.
func _min_y_relative(top: Node) -> float:
	var min_y := INF
	for mi in _collect(top):
		if mi.mesh == null:
			continue
		var xf := Transform3D()
		var p: Node3D = mi
		while p != top and p != null:
			xf = p.transform * xf
			p = p.get_parent() as Node3D
		min_y = minf(min_y, (xf * mi.mesh.get_aabb()).position.y)
	return min_y if min_y != INF else 0.0


func _collect(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		out.append_array(_collect(c))
	return out


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
