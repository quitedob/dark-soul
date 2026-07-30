extends SceneTree

const PoiseResolverScript = preload("res://scripts/combat/poise_resolver.gd")
const PlayerScene = preload("res://scenes/actors/player.tscn")

var _failures: Array[String] = []


func _init() -> void:
	_test_poise_math()
	_test_player_regen_gate()
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


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
