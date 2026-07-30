extends SceneTree
## 跳跃/碰撞研究落地合约：弹体 mask、垂直坡道、安全落点

const Builder = preload("res://scripts/world/procedural_campaign_level_builder.gd")
const ContentRegistry = preload("res://scripts/core/content_registry.gd")
const ProjectileScript = preload("res://scripts/components/spell_projectile.gd")
const SafePlacement = preload("res://scripts/core/safe_placement.gd")
const PlayerVisuals = preload("res://scripts/core/player_visuals.gd")

var _failures: Array[String] = []


func _init() -> void:
	_test_projectile_query_mask()
	_test_vertical_ramps()
	_test_safe_placement_api()
	_test_character_body_defaults_via_visuals_constants()
	_test_void_recovery_api()
	if _failures.is_empty():
		print("ASHEN_JUMP_COLLISION_CONTRACTS_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_projectile_query_mask() -> void:
	_expect(ProjectileScript.QUERY_MASK == (1 | 4), "Projectile QUERY_MASK must include World|Enemies.")
	_expect(ProjectileScript.WORLD_LAYER == 1, "Projectile WORLD_LAYER must be 1.")


func _test_vertical_ramps() -> void:
	var registry = ContentRegistry.new()
	var level := registry.get_level(&"level_02_04")  # vertical_tower topology
	_expect(not level.is_empty(), "vertical tower level missing.")
	var root := Builder.build(level)
	var geometry := root.get_node_or_null("Geometry")
	_expect(geometry != null, "Geometry root missing.")
	var ramp_count := 0
	for child in geometry.get_children():
		if String(child.name).begins_with("HeightRamp") or child.name == "HeightRamp":
			ramp_count += 1
	_expect(ramp_count > 0, "Vertical topology produced no height ramps.")
	root.free()


func _test_safe_placement_api() -> void:
	_expect(SafePlacement.WORLD_MASK == 1, "SafePlacement must query World layer.")
	_expect(SafePlacement.DEFAULT_RADIUS > 0.0, "SafePlacement capsule radius missing.")


func _test_character_body_defaults_via_visuals_constants() -> void:
	# 烟测：PlayerVisuals 脚本可加载，显式参数在 build_nodes 内设置
	var visuals := PlayerVisuals.new()
	_expect(visuals != null, "PlayerVisuals failed to construct.")


func _test_void_recovery_api() -> void:
	const PlayerScript = preload("res://scripts/player/player.gd")
	_expect(PlayerScript.VOID_RECOVER_Y < 0.0, "VOID_RECOVER_Y must be below world floor.")
	_expect(PlayerScript.VOID_DROP_FROM_SAFE > 0.0, "VOID_DROP_FROM_SAFE must be positive.")
	var player = PlayerScript.new()
	_expect(player.has_method("recover_to_last_safe"), "Player must expose recover_to_last_safe.")
	player.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
