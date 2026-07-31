extends SceneTree

const PoiseResolverScript = preload("res://scripts/combat/poise_resolver.gd")
const PlayerScene = preload("res://scenes/actors/player.tscn")
const CompatibilityMovesetFactory = preload("res://scripts/combat/data/compatibility_moveset_factory.gd")
const AttackDataScript = preload("res://scripts/combat/data/attack_data.gd")

var _failures: Array[String] = []


func _init() -> void:
	_test_poise_math()
	_test_phase_modifiers_owned_by_attack_data()
	_test_player_regen_gate()
	_test_player_reads_phase_wam()
	if _failures.is_empty():
		print("ASHEN_POISE_CONTRACTS_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_poise_math() -> void:
	# resolve(current, base, wam, pdr, incoming)
	var heavy := PoiseResolverScript.resolve(100.0, 100.0, 0.35, 0.30, 20.0)
	var standing := PoiseResolverScript.resolve(100.0, 100.0, 0.0, 0.05, 20.0)
	var depleted := PoiseResolverScript.resolve(5.0, 100.0, 0.0, 0.05, 20.0)
	var heavy_armor := PoiseResolverScript.resolve(100.0, 100.0, 0.35, 0.30, 40.0)
	var light_armor := PoiseResolverScript.resolve(100.0, 100.0, 0.35, 0.05, 40.0)
	_expect(bool(heavy["holds"]), "Twin Colossi heavy WAM did not hold a light hit.")
	_expect(bool(standing["holds"]), "Full standing poise incorrectly staggered on a light hit.")
	_expect(not bool(depleted["holds"]), "Depleted standing poise failed to break.")
	_expect(float(heavy_armor["reduced_damage"]) < float(light_armor["reduced_damage"]), "Heavy armor did not reduce poise damage.")
	# 低储备时动作护甲抬高容量，可扛一次轻击
	var wam_boost := PoiseResolverScript.resolve(10.0, 100.0, 0.35, 0.30, 20.0)
	_expect(bool(wam_boost["holds"]), "Action armor did not boost capacity over low reserve.")
	var broken := PoiseResolverScript.resolve(10.0, 100.0, 0.35, 0.30, 60.0)
	_expect(not bool(broken["holds"]), "Sufficient poise damage did not break action armor.")


func _test_phase_modifiers_owned_by_attack_data() -> void:
	# AttackData 拥有三阶段倍率；recovery 默认可打断
	var style: CombatStyleData = load("res://resources/combat_styles/twin_colossi.tres")
	var moveset: MovesetData = CompatibilityMovesetFactory.create(style, &"one_handed")
	var heavy: AttackData = moveset.neutral_heavy
	var light: AttackData = moveset.neutral_light
	_expect(heavy != null and light != null, "Moveset failed to build light/heavy AttackData.")
	_expect(heavy.poise_modifier_active > 0.0, "Heavy active WAM missing.")
	_expect(heavy.poise_modifier_windup > 0.0, "Heavy windup WAM missing.")
	_expect(is_zero_approx(heavy.poise_modifier_recovery), "Heavy recovery must have zero action armor.")
	_expect(is_zero_approx(light.poise_modifier_windup), "Light windup should not grant action armor.")
	_expect(heavy.poise_modifier_for_phase(&"active") == heavy.poise_modifier_active, "Phase helper active mismatch.")
	_expect(heavy.poise_modifier_for_phase(&"recovery") == 0.0, "Phase helper recovery mismatch.")
	# recovery 阶段：即使满储备被大削韧打穿后 holds=false 时由储备决定；WAM=0 不抬容量
	var recovery_hit := PoiseResolverScript.resolve(5.0, 100.0, heavy.poise_modifier_recovery, 0.05, 20.0)
	_expect(not bool(recovery_hit["holds"]), "Recovery WAM=0 must not boost depleted reserve.")


func _test_player_regen_gate() -> void:
	var player = PlayerScene.instantiate()
	root.add_child(player)
	player.poise_health = 20.0
	player._poise_delay_timer = 0.0
	player.state = player.State.ATTACK_ACTIVE
	player._update_poise(1.0)
	_expect(is_equal_approx(player.poise_health, 20.0), "Poise regenerated outside locomotion.")
	player.state = player.State.LOCOMOTION
	player._poise_delay_timer = 1.0
	player._update_poise(0.5)
	_expect(is_equal_approx(player.poise_health, 20.0), "Poise regenerated during delay.")
	player._update_poise(0.5)
	player._update_poise(1.0)
	_expect(player.poise_health > 20.0, "Poise did not regenerate after delay in locomotion.")
	player.free()


func _test_player_reads_phase_wam() -> void:
	# player 按状态阶段读取 AttackData 倍率，而非二值 hyper_armor
	var player = PlayerScene.instantiate()
	root.add_child(player)
	var attack := AttackDataScript.new()
	attack.action_id = &"test_phase"
	attack.poise_modifier_windup = 0.2
	attack.poise_modifier_active = 0.5
	attack.poise_modifier_recovery = 0.0
	player._current_attack = attack
	player.state = player.State.ATTACK_WINDUP
	_expect(is_equal_approx(player._action_armor_for_state(), 0.2), "Windup phase WAM not read.")
	player.state = player.State.ATTACK_ACTIVE
	_expect(is_equal_approx(player._action_armor_for_state(), 0.5), "Active phase WAM not read.")
	player.state = player.State.ATTACK_RECOVERY
	_expect(is_equal_approx(player._action_armor_for_state(), 0.0), "Recovery phase WAM not read.")
	# E-02：二值 hyper_armor 已移除
	_expect(player.get("hyper_armor") == null, "Player still exposes binary hyper_armor.")
	player.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
