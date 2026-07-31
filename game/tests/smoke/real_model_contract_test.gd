extends SceneTree
## Real-model swap pipeline contract:
## 1) Every REGISTRY path must resolve to a loadable GLB.
## 2) Registered player body / weapon / shield and enemy body+weapon slots must
##    swap to real GLB models (BodyRoot / ModelRoot present under the parent).
## 3) Unregistered keys must fall back to procedural geometry (no ModelRoot,
##    children present).

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
	_test_fallback_when_no_model()
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
	_expect(weapon.get_node_or_null("ModelRoot") != null, "Enemy weapon swap: ModelRoot not created for rusted_blade.")
	body.free()
	weapon.free()


func _test_fallback_when_no_model() -> void:
	var weapon_parent := Node3D.new()
	WeaponMeshFactory.build_into_parent(weapon_parent, "dagger", StandardMaterial3D.new())
	_expect(weapon_parent.get_node_or_null("ModelRoot") == null, "Fallback: dagger unexpectedly resolved a real model.")
	_expect(weapon_parent.get_child_count() > 0, "Fallback: dagger produced no procedural geometry.")
	weapon_parent.free()

	var body := Node3D.new()
	var weapon := Node3D.new()
	ChapterEnemyFactory.build_into_slots(
		body, weapon,
		{"body_type": "ethereal_flicker", "weapon_shape": "memory_claw"},
		StandardMaterial3D.new(), StandardMaterial3D.new()
	)
	_expect(body.get_node_or_null("ModelRoot") == null, "Fallback: ethereal_flicker unexpectedly resolved a real model.")
	_expect(weapon.get_node_or_null("ModelRoot") == null, "Fallback: memory_claw unexpectedly resolved a real model.")
	_expect(body.get_child_count() > 0, "Fallback: ethereal_flicker produced no procedural body.")
	_expect(weapon.get_child_count() > 0, "Fallback: memory_claw produced no procedural weapon.")
	body.free()
	weapon.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
