extends Node

## Smoke test extracted from game_world.gd to keep production code lean.
## Called by game_world.gd._run_smoke_test() when --smoke-test flag is present.
##
## Tests: systems presence, sanctuary protection, combat style cycling,
## parry contract, guarded thrust, twin-colossi leap, crescent-pair leap,
## veilcraft projectile cast, ember rite cast, HUD prompt/boss/death.


static func run(world: Node) -> void:
	var player: CharacterBody3D = world.get("player") if world.get("player") else world.player
	var hud: CanvasLayer = world.get("hud") if world.get("hud") else world.hud
	var enemies: Array = world.get("enemies") if world.get("enemies") else world.enemies
	var campaign_runtime = world.get("campaign_runtime")

	if player == null or hud == null or enemies.is_empty():
		push_error("Smoke test failed: systems missing")
		world.get_tree().quit(1)
		return
	if campaign_runtime == null or campaign_runtime.current_level_id != &"level_01_01":
		push_error("Smoke test failed: canonical Chapter 1 runtime is not active")
		world.get_tree().quit(1)
		return
	if campaign_runtime.current_level == null or campaign_runtime.current_level.get_meta("level_id", &"") != &"level_01_01":
		push_error("Smoke test failed: Chapter 1 level metadata is missing")
		world.get_tree().quit(1)
		return
	if not is_equal_approx(player.health, player.max_health):
		push_error(
			"Smoke test failed: sanctuary did not protect spawn; health %.1f / %.1f"
			% [player.health, player.max_health]
		)
		world.get_tree().quit(1)
		return
	for initial_enemy in enemies:
		if initial_enemy.engaged:
			push_error(
				"Smoke test failed: %s engaged inside sanctuary at %s"
				% [initial_enemy.name, initial_enemy.global_position]
			)
			world.get_tree().quit(1)
			return
	for required_action in [
		&"right_primary",
		&"right_secondary",
		&"left_primary",
		&"left_secondary",
		&"guard",
		&"parry",
		&"special_attack",
		&"cast_spell",
		&"cycle_style",
	]:
		if not InputMap.has_action(required_action):
			push_error("Smoke test failed: missing action %s" % required_action)
			world.get_tree().quit(1)
			return
	var expected_hands := [
		{"right_hand": "guardian_sword", "left_hand": "reliquary_shield"},
		{"right_hand": "xingtian_axe_right", "left_hand": "xingtian_axe_left"},
		{"right_hand": "marksman_bow", "left_hand": "marksman_dagger"},
		{"right_hand": "five_elements_seal", "left_hand": "spirit_stone"},
		{"right_hand": "prayer_beads", "left_hand": "talisman_papers"},
	]
	for style_id in range(5):
		player.set_combat_style(style_id)
		if int(player.combat_style) != style_id:
			push_error("Smoke test failed: combat style %d unavailable" % style_id)
			world.get_tree().quit(1)
			return
		var actual_loadout: Dictionary = player.get_hand_loadout()
		if actual_loadout != expected_hands[style_id]:
			push_error("Smoke test failed: style %d hand mapping changed" % style_id)
			world.get_tree().quit(1)
			return

	var SaveStateScript = load("res://scripts/core/run_state.gd")
	var hand_state = SaveStateScript.new()
	hand_state.right_hand = "marksman_bow"
	hand_state.left_hand = "marksman_dagger"
	hand_state.combat_style = 0
	world.call("_apply_run_state", hand_state)
	if player.right_hand_item != "marksman_bow" or player.left_hand_item != "marksman_dagger":
		push_error("Smoke test failed: save hand loadout was not applied")
		world.get_tree().quit(1)
		return
	var hand_snapshot: Dictionary = world.call("_snapshot_run_state")
	if hand_snapshot.get("right_hand") != "marksman_bow" or hand_snapshot.get("left_hand") != "marksman_dagger":
		push_error("Smoke test failed: save hand loadout was not snapshotted")
		world.get_tree().quit(1)
		return

	var LocalizationScript = load("res://scripts/core/localization.gd")
	if LocalizationScript.text("PARRY", "zh_CN") != "弹反":
		push_error("Smoke test failed: Simplified Chinese combat text unavailable")
		world.get_tree().quit(1)
		return

	player.set_combat_style(0)
	player.stamina = player.max_stamina
	player.call("_try_parry")
	var HandEquipmentScript = load("res://scripts/data/hand_equipment.gd")
	var parry_profile: Dictionary = HandEquipmentScript.get_item(player.left_hand_item).get("parry", {})
	await world.get_tree().create_timer(float(parry_profile.get("startup", 0.266)) + 0.02).timeout
	var health_before_parry: float = player.health
	var parried_enemy = enemies[0]
	var enemy_state_before: int = int(parried_enemy.state)
	player.receive_hit(12.0, 20.0, Vector3.FORWARD, parried_enemy)
	if (
		not is_equal_approx(player.health, health_before_parry)
		or int(parried_enemy.state) == enemy_state_before
	):
		push_error("Smoke test failed: parry contract did not resolve")
		world.get_tree().quit(1)
		return

	player.call("_change_state", 0)
	player.set_combat_style(0)
	player.set_guard_active(true)
	player.stamina = player.max_stamina
	var frontal_health: float = player.health
	player.receive_hit_payload({
		"damage": 40.0, "stagger": 30.0, "guard_damage": 40.0,
		"direction": player.global_transform.basis.z, "source": null,
		"blockable": true, "parryable": true,
	})
	if frontal_health - player.health >= 10.0 or player.state == 10:
		push_error("Smoke test failed: real frontal guard reduction did not resolve")
		world.get_tree().quit(1)
		return
	player.call("_change_state", 0)
	player.health = frontal_health
	player.set_guard_active(true)
	player.receive_hit_payload({
		"damage": 20.0, "stagger": 0.0, "direction": -player.global_transform.basis.z,
		"source": null, "blockable": true, "parryable": true,
	})
	if frontal_health - player.health < 19.0:
		push_error("Smoke test failed: rear hit did not bypass real guard")
		world.get_tree().quit(1)
		return
	player.call("_change_state", 0)
	player.health = frontal_health
	player.stamina = 1.0
	player.set_guard_active(true)
	player.receive_hit_payload({
		"damage": 20.0, "stagger": 10.0, "guard_damage": 100.0,
		"direction": player.global_transform.basis.z, "source": null,
		"blockable": true, "parryable": true,
	})
	if player.guard_active or player.state != 10:
		push_error("Smoke test failed: real guard break did not stagger")
		world.get_tree().quit(1)
		return

	player.call("_change_state", 0)
	player.set_combat_style(0)
	player.stamina = player.max_stamina
	player.set_guard_active(true)
	player.call("_try_shield_bash")
	if (
		player.combat_area.hit_payload.get("hand") != "left"
		or player.combat_area.hit_payload.get("action_id") != "shield_bash"
		or not is_equal_approx(float(player.combat_area.hit_payload.get("damage", 0.0)), 18.0)
	):
		push_error("Smoke test failed: shield bash metadata changed")
		world.get_tree().quit(1)
		return

	player.call("_change_state", 0)
	player.set_combat_style(0)
	player.stamina = player.max_stamina
	player.call("_try_guarded_thrust")
	if player.stamina >= player.max_stamina or not player.combat_area.active:
		push_error("Smoke test failed: shield bash compatibility action was not committed")
		world.get_tree().quit(1)
		return

	player.call("_change_state", 0)
	player.set_combat_style(1)
	player.stamina = player.max_stamina
	player.call("_try_style_skill")
	if player.stamina >= player.max_stamina:
		push_error("Smoke test failed: twin-colossi leap was not committed")
		world.get_tree().quit(1)
		return

	player.call("_change_state", 0)
	player.set_combat_style(2)
	player.stamina = player.max_stamina
	player.call("_try_style_skill")
	if player.stamina >= player.max_stamina:
		push_error("Smoke test failed: crescent-pair leap was not committed")
		world.get_tree().quit(1)
		return

	player.call("_change_state", 0)
	player.set_combat_style(3)
	player.set_focus(player.max_focus)
	player.call("_try_cast_for_style")
	player.call("_resolve_cast")
	await world.get_tree().process_frame
	if (
		player.focus >= player.max_focus
		or world.find_child("VeilBolt", true, false) == null
	):
		push_error("Smoke test failed: veilcraft projectile was not cast")
		world.get_tree().quit(1)
		return

	player.call("_change_state", 0)
	player.set_combat_style(4)
	player.set_focus(player.max_focus)
	player.health = 40.0
	player.call("_try_cast_for_style")
	player.call("_resolve_cast")
	if player.focus >= player.max_focus or player.health <= 40.0:
		push_error("Smoke test failed: ember rite was not resolved")
		world.get_tree().quit(1)
		return

	player.call("_change_state", 0)
	player.add_embers(3)
	player.receive_hit(5.0, 0.0, Vector3.FORWARD, null)
	player.heal_full()
	enemies[0].receive_hit(5.0, 0.0, Vector3.BACK, player)
	hud.set_prompt("Smoke interaction")
	if not hud.is_prompt_visible():
		push_error("Smoke test failed: interaction prompt did not appear")
		world.get_tree().quit(1)
		return
	hud.set_prompt("")
	hud.show_boss("Smoke Guardian", 50.0, 100.0)
	if not hud.is_boss_visible():
		push_error("Smoke test failed: boss HUD did not appear")
		world.get_tree().quit(1)
		return
	hud.hide_boss()
	hud.show_death()
	if not hud.is_death_visible():
		push_error("Smoke test failed: death overlay did not appear")
		world.get_tree().quit(1)
		return
	hud.clear_death()
	if hud.is_death_visible():
		push_error("Smoke test failed: death overlay did not clear")
		world.get_tree().quit(1)
		return
	hud.show_message("HUD SMOKE", 0.35)
	print("ASHEN_HOLLOW_SMOKE_OK")
	await world.get_tree().create_timer(1.2).timeout
	world.get_tree().quit(0)
