extends Node3D

const PlayerScene = preload("res://scenes/actors/player.tscn")
const _ProcUtils = preload("res://scripts/core/procedural_utils.gd")
const EnemyScene = preload("res://scenes/actors/enemy.tscn")
const EnemyScript = preload("res://scripts/enemy.gd")
const HudScene = preload("res://scenes/ui/hud.tscn")
const CheckpointScene = preload("res://scenes/interactables/ember_shrine.tscn")
const ShortcutScene = preload("res://scenes/interactables/shortcut_lever.tscn")
const LostEchoScene = preload("res://scenes/interactables/lost_echo.tscn")
const AudioScene = preload("res://scenes/audio/procedural_audio.tscn")
const RunStateScript = preload("res://scripts/core/run_state.gd")
const SettingsScript = preload("res://scripts/core/game_settings.gd")
const HostBridgeScript = preload("res://scripts/app/game_host_bridge.gd")
const LocalizationScript = preload("res://scripts/core/localization.gd")

const SAVE_PATH := "user://ashen_hollow_run_v1.json"
const SETTINGS_PATH := "user://ashen_hollow_settings_v1.json"
const INTERACTABLE_LAYER := 1 << 3

var player
var hud
var audio
var host_bridge
var checkpoint
var shortcut
var shortcut_gate
var enemies: Array = []
var respawn_position := Vector3(0.0, 1.1, 8.0)
var lost_echo
var guardian
var victory := false
var materials: Dictionary = {}
var world_environment: WorldEnvironment
var run_state
var game_settings
var interaction_sensor: Area3D
var interaction_candidates: Array[Area3D] = []
var _interaction_refresh := 0.0
var _play_time_fraction_ms := 0.0


func _ready() -> void:
	_configure_inputs()
	_create_materials()
	_create_environment()
	_create_level()
	_create_systems()
	_load_initial_state()
	call_deferred("_generate_navigation")
	if "--smoke-test" in OS.get_cmdline_user_args():
		get_tree().create_timer(2.0).timeout.connect(_run_smoke_test)


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	_play_time_fraction_ms += delta * 1000.0
	var elapsed_whole_ms := int(_play_time_fraction_ms)
	if elapsed_whole_ms > 0:
		run_state.play_time_ms += elapsed_whole_ms
		_play_time_fraction_ms -= elapsed_whole_ms
	_interaction_refresh -= delta
	if _interaction_refresh > 0.0:
		return
	_interaction_refresh = 0.1
	_update_interaction_target()


func _update_interaction_target() -> void:
	var nearest: Node = null
	var nearest_distance := 3.0
	var valid_candidates: Array[Area3D] = []
	for interactable in interaction_candidates:
		if interactable is Node3D and is_instance_valid(interactable):
			valid_candidates.append(interactable)
			var distance: float = player.global_position.distance_to(interactable.global_position)
			if distance < nearest_distance:
				nearest = interactable
				nearest_distance = distance
	interaction_candidates = valid_candidates
	player.set_interaction(nearest)
	if hud != null:
		hud.set_prompt(nearest.get_prompt() if nearest != null and nearest.has_method("get_prompt") else "")


func _create_systems() -> void:
	run_state = RunStateScript.new()
	game_settings = SettingsScript.new()

	host_bridge = HostBridgeScript.new()
	host_bridge.name = "GameHostBridge"
	host_bridge.initialize_received.connect(_on_host_initialize_received)
	host_bridge.settings_received.connect(_on_host_settings_received)
	host_bridge.new_run_requested.connect(_on_host_new_run_requested)
	host_bridge.continue_run_requested.connect(_on_host_continue_run_requested)
	host_bridge.lifecycle_changed.connect(_on_host_lifecycle_changed)
	host_bridge.save_requested.connect(_on_host_save_requested)
	host_bridge.exit_requested.connect(_on_host_exit_requested)
	host_bridge.protocol_error.connect(_on_host_protocol_error)
	add_child(host_bridge)

	audio = AudioScene.instantiate()
	add_child(audio)

	hud = HudScene.instantiate()
	add_child(hud)
	hud.locale_requested.connect(_on_hud_locale_requested)
	hud.play_started.connect(_on_play_started)

	player = PlayerScene.instantiate()
	player.position = respawn_position
	player.setup(self, audio, hud)
	player.died.connect(_on_player_died)
	player.stats_changed.connect(hud.update_stats)
	player.focus_changed.connect(hud.update_focus)
	player.embers_changed.connect(hud.update_embers)
	player.lock_target_changed.connect(hud.set_lock_target)
	player.combat_style_changed.connect(hud.set_combat_style)
	player.hands_changed.connect(hud.set_hands)
	player.healing_started.connect(_on_player_healing)
	add_child(player)
	player.combat_area.hit_landed.connect(_on_player_hit_landed)
	hud.setup(player)
	_create_interaction_sensor()

	checkpoint = CheckpointScene.instantiate()
	checkpoint.position = Vector3(0.0, 0.0, 6.0)
	checkpoint.setup(self, "Ember Shrine")
	checkpoint.activated.connect(_on_checkpoint_activated)
	checkpoint.rested.connect(_on_checkpoint_rested)
	add_child(checkpoint)

	shortcut_gate = _create_gate(Vector3(0.0, 1.5, -5.6))
	shortcut = ShortcutScene.instantiate()
	shortcut.position = Vector3(-8.0, 0.0, -5.0)
	shortcut.setup(shortcut_gate, self)
	shortcut.opened.connect(_on_shortcut_opened)
	add_child(shortcut)

	_spawn_enemy(Vector3(-4.0, 0.95, -3.0), false)
	_spawn_enemy(Vector3(4.0, 0.95, -8.0), false)
	_spawn_enemy(Vector3(-3.0, 0.95, -10.0), false, EnemyScript.EnemyType.ASH_STALKER)
	_spawn_enemy(Vector3(4.0, 0.95, -14.0), false, EnemyScript.EnemyType.ASH_STALKER)
	_spawn_enemy(Vector3(-7.0, 0.95, -12.0), false)
	guardian = _spawn_enemy(Vector3(0.0, 1.15, -24.0), true)


func _create_interaction_sensor() -> void:
	interaction_sensor = Area3D.new()
	interaction_sensor.name = "InteractionSensor"
	interaction_sensor.collision_layer = 0
	interaction_sensor.collision_mask = INTERACTABLE_LAYER
	interaction_sensor.monitoring = true
	interaction_sensor.monitorable = false
	var shape_node := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 3.0
	shape_node.shape = sphere
	shape_node.position.y = 0.8
	interaction_sensor.add_child(shape_node)
	interaction_sensor.area_entered.connect(_on_interaction_area_entered)
	interaction_sensor.area_exited.connect(_on_interaction_area_exited)
	player.add_child(interaction_sensor)


func _on_interaction_area_entered(area: Area3D) -> void:
	if area.is_in_group("interactable") and area not in interaction_candidates:
		interaction_candidates.append(area)
		_interaction_refresh = 0.0


func _on_interaction_area_exited(area: Area3D) -> void:
	interaction_candidates.erase(area)
	_interaction_refresh = 0.0


func _show_intro() -> void:
	hud.show_message(LocalizationScript.text("ASHEN HOLLOW\nReach the sealed guardian beyond the ruins."), 4.0)


func _on_play_started() -> void:
	_show_intro()


func _spawn_enemy(spawn_position: Vector3, is_guardian: bool, enemy_type = -1):
	var enemy = EnemyScene.instantiate()
	enemy.name = "HollowSentinel" if not is_guardian else "CinderGuardian"
	enemy.position = spawn_position
	var type_arg := enemy_type as int
	if type_arg >= 0:
		enemy.setup(self, player, audio, spawn_position, is_guardian, type_arg)
	else:
		enemy.setup(self, player, audio, spawn_position, is_guardian)
	enemy.defeated.connect(_on_enemy_defeated)
	enemy.engagement_changed.connect(_on_enemy_engagement_changed)
	enemy.health_changed.connect(_on_guardian_health_changed.bind(enemy))
	add_child(enemy)
	enemies.append(enemy)
	return enemy


func rest_at_checkpoint(shrine: Node3D, _interacting_player: Node = null) -> void:
	respawn_position = shrine.global_position + Vector3(0.0, 1.1, 2.0)
	run_state.checkpoint_id = "ember_shrine"
	player.heal_full()
	_try_shrine_upgrade()
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.reset_enemy()
	audio.play_cue("rest", -4.0)
	hud.show_message(LocalizationScript.text("EMBER RESTORED\nEnemies return to the hollow."), 2.5)
	_save_run("checkpoint_rest")


func _try_shrine_upgrade() -> void:
	if not player.has_method("try_upgrade_max_health"):
		return
	if player.try_upgrade_max_health():
		var tier: int = player.get_upgrade_tier()
		var cost := -1
		if player.has_method("get_upgrade_cost"):
			var next_cost: int = player.get_upgrade_cost()
			if next_cost < 0:
				cost = 0
		var msg := LocalizationScript.text("VITALITY FORGED +10 HP  (TIER %d)") % tier
		hud.show_message(msg, 2.5)
		audio.play_cue("recover", -5.0, 0.7)
		_save_run("shrine_upgrade")
		return
	var next_cost: int = -1
	if player.has_method("get_upgrade_cost"):
		next_cost = player.get_upgrade_cost()
	if next_cost > 0:
		hud.show_message(LocalizationScript.text("Need %d embers for next vitality upgrade") % next_cost, 2.0)


func _on_checkpoint_activated(_shrine: Node, _interacting_player: Node) -> void:
	run_state.checkpoint_id = "ember_shrine"
	_save_run("checkpoint_activated")


func _on_checkpoint_rested(shrine: Node, interacting_player: Node) -> void:
	rest_at_checkpoint(shrine, interacting_player)


func open_shortcut(gate: Node3D) -> void:
	hud.show_message(LocalizationScript.text("SHORTCUT OPENED"), 2.0)
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(gate, "position:y", gate.position.y + 4.5, 1.8)


func shortcut_opened(_shortcut: Node, _gate: Node3D, _interacting_player: Node) -> void:
	audio.play_cue("rest", -7.0, 0.75)
	hud.show_message(LocalizationScript.text("SHORTCUT OPENED"), 2.0)
	if "ancient_gate" not in run_state.activated_shortcuts:
		run_state.activated_shortcuts.append("ancient_gate")
	_save_run("shortcut_activated")


func _on_shortcut_opened(shortcut_node: Node, gate: Node3D, interacting_player: Node) -> void:
	shortcut_opened(shortcut_node, gate, interacting_player)


func recover_lost_echo(amount: int, _recovering_player: Node = null) -> void:
	lost_echo = null
	player.recover_embers(amount)
	audio.play_cue("recover", -3.0)
	hud.show_message(LocalizationScript.text("LOST EMBERS RECOVERED  +%d") % amount, 2.0)
	run_state.lost_echo_amount = 0
	run_state.lost_echo_position = Vector3.ZERO
	_save_run("lost_echo_recovered")


func _on_lost_echo_recovered(amount: int, recovering_player: Node) -> void:
	recover_lost_echo(amount, recovering_player)


func _on_player_died(death_position: Vector3) -> void:
	var lost_amount: int = int(player.lose_embers())
	if lost_echo != null and is_instance_valid(lost_echo):
		lost_echo.queue_free()
	if lost_amount > 0:
		_spawn_lost_echo(lost_amount, death_position + Vector3.UP * 0.35)
		run_state.lost_echo_amount = lost_amount
		run_state.lost_echo_position = lost_echo.global_position
	_save_run("player_death")
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.reset_enemy()
	hud.show_death()
	await get_tree().create_timer(2.2).timeout
	player.respawn_at(respawn_position)
	hud.clear_death()
	hud.show_message(LocalizationScript.text("RISE AGAIN"), 1.5)


func _spawn_lost_echo(amount: int, at: Vector3) -> void:
	if lost_echo != null and is_instance_valid(lost_echo):
		lost_echo.queue_free()
	lost_echo = LostEchoScene.instantiate()
	lost_echo.position = at
	lost_echo.setup(amount, self)
	lost_echo.recovered.connect(_on_lost_echo_recovered)
	add_child(lost_echo)


func _on_enemy_defeated(enemy, reward: int, is_guardian: bool) -> void:
	player.add_embers(reward)
	if is_guardian and not victory:
		victory = true
		hud.hide_boss()
		hud.show_victory()
		audio.play_cue("victory", -2.0)
		run_state.guardian_defeated = true
		_save_run("guardian_defeated")
	else:
		hud.show_message(LocalizationScript.text("EMBER CLAIMED  +%d") % reward, 1.2)


func _on_enemy_engagement_changed(enemy, is_guardian: bool, engaged: bool) -> void:
	if not is_guardian:
		return
	if engaged and enemy.is_targetable():
		hud.show_boss(LocalizationScript.text("CINDER GUARDIAN"), enemy.health, enemy.max_health)
	else:
		hud.hide_boss()


func _on_guardian_health_changed(current: float, maximum: float, enemy) -> void:
	if enemy == guardian and is_instance_valid(enemy) and enemy.engaged:
		hud.show_boss(LocalizationScript.text("CINDER GUARDIAN"), current, maximum)


func get_target_candidates() -> Array[Node]:
	var candidates: Array[Node] = []
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.is_targetable():
			candidates.append(enemy)
	return candidates


func is_position_in_sanctuary(at: Vector3) -> bool:
	return at.z >= 3.5


func _load_initial_state() -> void:
	var loaded_settings = SettingsScript.load_from_path(SETTINGS_PATH)
	if loaded_settings != null:
		game_settings = loaded_settings
	game_settings.apply_runtime_defaults(_is_mobile_runtime())
	_apply_settings()

	var is_smoke_test := "--smoke-test" in OS.get_cmdline_user_args()
	var force_new_run := "--new-run" in OS.get_cmdline_user_args()
	var host_controls_save: bool = (
		OS.has_feature("web")
		and host_bridge.is_connected_to_host()
	)
	if not host_controls_save and not is_smoke_test and not force_new_run:
		var loaded_state = RunStateScript.load_from_path(SAVE_PATH)
		if loaded_state != null:
			_apply_run_state(loaded_state)
	if not OS.has_feature("web"):
		host_bridge.send_ready(FileAccess.file_exists(SAVE_PATH))
	if not is_smoke_test:
		hud.show_title(FileAccess.file_exists(SAVE_PATH))


func _apply_run_state(state) -> void:
	if state == null:
		return
	run_state = state
	respawn_position = Vector3(0.0, 1.1, 8.0)
	if player.has_method("set_embers"):
		player.set_embers(run_state.embers)
	else:
		player.embers = run_state.embers
		player.embers_changed.emit(player.embers)
	player.set_focus(run_state.focus)
	if player.has_method("set_hand_loadout") and not player.set_hand_loadout(run_state.right_hand, run_state.left_hand):
		player.set_combat_style(run_state.combat_style)
	elif not player.has_method("set_hand_loadout"):
		player.set_combat_style(run_state.combat_style)
	if player.has_method("set_upgrade_tier"):
		player.set_upgrade_tier(run_state.upgrade_tier)
	checkpoint.activate()
	if "ancient_gate" in run_state.activated_shortcuts:
		shortcut.open_immediately()
	if run_state.lost_echo_amount > 0:
		_spawn_lost_echo(run_state.lost_echo_amount, run_state.lost_echo_position)
	if run_state.guardian_defeated and is_instance_valid(guardian):
		guardian.queue_free()
		victory = true
		run_state.guardian_defeated = true
	player.respawn_at(respawn_position)
	hud.show_message(LocalizationScript.text("THE HOLLOW REMEMBERS"), 1.8)


func _snapshot_run_state() -> Dictionary:
	run_state.embers = int(player.embers)
	run_state.focus = float(player.focus)
	run_state.combat_style = int(player.combat_style)
	if player.has_method("get_hand_loadout"):
		var hand_loadout: Dictionary = player.get_hand_loadout()
		run_state.right_hand = String(hand_loadout.get("right_hand", run_state.right_hand))
		run_state.left_hand = String(hand_loadout.get("left_hand", run_state.left_hand))
	if player.has_method("get_upgrade_tier"):
		run_state.upgrade_tier = player.get_upgrade_tier()
	run_state.guardian_defeated = victory
	if shortcut != null and shortcut.is_open:
		if "ancient_gate" not in run_state.activated_shortcuts:
			run_state.activated_shortcuts.append("ancient_gate")
	if lost_echo != null and is_instance_valid(lost_echo):
		run_state.lost_echo_amount = int(lost_echo.amount)
		run_state.lost_echo_position = lost_echo.global_position
	else:
		run_state.lost_echo_amount = 0
		run_state.lost_echo_position = Vector3.ZERO
	return run_state.to_dictionary()


func _save_run(reason: String) -> bool:
	_snapshot_run_state()
	var saved: bool = run_state.save_to_path(SAVE_PATH)
	if not saved:
		host_bridge.send_fatal_error("Could not persist the current run.")
		return false
	host_bridge.send_save(run_state.to_bridge_dictionary(), reason)
	return true


func _on_host_initialize_received(
	settings_data: Dictionary,
	save_data: Dictionary
) -> void:
	var parsed_settings = SettingsScript.from_dictionary(settings_data)
	var parsed_state = RunStateScript.from_dictionary(save_data)
	if parsed_settings == null:
		host_bridge.send_fatal_error("The initial settings payload is invalid.")
		return
	if parsed_state == null:
		host_bridge.send_fatal_error("The initial save payload is invalid.")
		return
	game_settings = parsed_settings
	game_settings.apply_runtime_defaults(_is_mobile_runtime())
	game_settings.save_to_path(SETTINGS_PATH)
	_apply_settings()
	_apply_run_state(parsed_state)
	var has_save := int(save_data.get("updatedAtEpochMs", 0)) > 0
	hud.show_title(has_save)
	host_bridge.send_ready(has_save)


func _on_host_settings_received(settings_data: Dictionary) -> void:
	var parsed = SettingsScript.from_dictionary(settings_data)
	if parsed == null:
		host_bridge.send_fatal_error("The settings payload is invalid.")
		return
	game_settings = parsed
	game_settings.apply_runtime_defaults(_is_mobile_runtime())
	game_settings.save_to_path(SETTINGS_PATH)
	_apply_settings()
	host_bridge.send_event("settings.applied", game_settings.to_bridge_dictionary())


func _on_hud_locale_requested(locale: String) -> void:
	game_settings.locale = String(LocalizationScript.normalize_locale(locale))
	game_settings.save_to_path(SETTINGS_PATH)
	_apply_settings()


func _on_player_hit_landed(is_heavy: bool) -> void:
	var pause_duration := 0.08 if is_heavy else 0.04
	var pause_scale := 0.02 if is_heavy else 0.05
	Engine.time_scale = pause_scale
	var timer := get_tree().create_timer(pause_duration, true, true)
	timer.timeout.connect(func():
		Engine.time_scale = 1.0
	)
	if is_heavy and player != null and is_instance_valid(player) and player.camera != null:
		player.camera.h_offset = randf_range(-0.08, 0.08)
		player.camera.v_offset = randf_range(-0.04, 0.04)
		var reset_timer := get_tree().create_timer(0.06, true, true)
		reset_timer.timeout.connect(func():
			if player != null and is_instance_valid(player) and player.camera != null:
				player.camera.h_offset = 0.0
				player.camera.v_offset = 0.0
		)


func _on_player_healing() -> void:
	if enemies == null:
		return
	for enemy in enemies:
		if enemy != null and is_instance_valid(enemy) and enemy.has_method("on_player_healing"):
			enemy.on_player_healing()


func _apply_settings() -> void:
	Engine.max_fps = game_settings.target_fps
	TranslationServer.set_locale(game_settings.locale)
	if player != null and player.has_method("apply_game_settings"):
		player.apply_game_settings(game_settings.to_dictionary())
	if hud != null and hud.has_method("apply_accessibility_settings"):
		hud.apply_accessibility_settings(game_settings.to_dictionary())
	var master_index := AudioServer.get_bus_index("Master")
	if master_index >= 0:
		var linear_volume: float = maxf(
			game_settings.master_volume * game_settings.effects_volume,
			0.0001
		)
		AudioServer.set_bus_volume_db(master_index, linear_to_db(linear_volume))
	# NOTE: game_settings.music_volume is stored and ready to wire.
	# When a Music audio bus is added (via project settings default_bus_layout),
	# wire it here: AudioServer.set_bus_volume_db(music_index, linear_to_db(game_settings.music_volume))
	if world_environment != null and world_environment.environment != null:
		var low_quality: bool = game_settings.quality_preset == &"low"
		world_environment.environment.glow_enabled = not low_quality
		world_environment.environment.fog_enabled = not low_quality


func _is_mobile_runtime() -> bool:
	return _ProcUtils.is_mobile_runtime()


func _on_host_new_run_requested() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_host_continue_run_requested(save_data: Dictionary) -> void:
	var state = RunStateScript.from_dictionary(save_data)
	if state == null:
		host_bridge.send_fatal_error("The selected save is corrupt or unsupported.")
		return
	_apply_run_state(state)
	_save_run("continue_loaded")


func _on_host_lifecycle_changed(active: bool) -> void:
	if not active:
		_save_run("lifecycle_paused")
	get_tree().paused = not active


func _on_host_save_requested() -> void:
	_save_run("host_requested")


func _on_host_exit_requested() -> void:
	_save_run("safe_exit")
	host_bridge.send_event("exitReady")
	if not OS.has_feature("web"):
		get_tree().quit(0)


func _on_host_protocol_error(message: String) -> void:
	push_warning("Host bridge: %s" % message)


func _create_environment() -> void:
	world_environment = WorldEnvironment.new()
	world_environment.name = "NightEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("07101a")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("52708a")
	environment.ambient_light_energy = 0.32
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.fog_enabled = true
	environment.fog_light_color = Color("28405a")
	environment.fog_light_energy = 0.35
	environment.fog_density = 0.012
	world_environment.environment = environment
	add_child(world_environment)

	var moon := DirectionalLight3D.new()
	moon.name = "Moonlight"
	moon.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	moon.light_color = Color("9db9d2")
	moon.light_energy = 1.15
	moon.shadow_enabled = true
	add_child(moon)

	var warm_light := OmniLight3D.new()
	warm_light.name = "ShrineGlow"
	warm_light.position = Vector3(0.0, 2.4, 6.0)
	warm_light.light_color = Color("ff7738")
	warm_light.light_energy = 5.0
	warm_light.omni_range = 9.0
	warm_light.shadow_enabled = true
	add_child(warm_light)


func _create_materials() -> void:
	materials["stone"] = _material(Color("27303a"), 0.92, 0.05)
	materials["stone_dark"] = _material(Color("121922"), 0.98, 0.02)
	materials["metal"] = _material(Color("303a43"), 0.46, 0.72)
	materials["ember"] = _material(Color("ff5a24"), 0.35, 0.0, Color("ff3a12"), 3.2)
	materials["moss"] = _material(Color("203a31"), 0.95, 0.0)
	materials["void"] = _material(Color("05070c"), 1.0, 0.0)
	materials["rubble"] = _material(Color("1a1f28"), 0.95, 0.03)
	materials["wood"] = _material(Color("2a1f14"), 0.85, 0.02)
	materials["ember_vein"] = _material(Color("ff3a12"), 0.4, 0.0, Color("ff5a24"), 2.5)


func _create_level() -> void:
	_create_block(Vector3(0.0, -0.5, -6.5), Vector3(24.0, 1.0, 43.0), "stone_dark")
	_create_block(Vector3(0.0, -0.2, -27.0), Vector3(18.0, 0.6, 14.0), "stone")
	_create_block(Vector3(-9.0, 2.0, -6.5), Vector3(1.0, 5.0, 43.0), "stone")
	_create_block(Vector3(9.0, 2.0, -6.5), Vector3(1.0, 5.0, 43.0), "stone")
	_create_block(Vector3(0.0, 2.0, 15.0), Vector3(19.0, 5.0, 1.0), "stone")
	_create_block(Vector3(-5.5, 1.1, 2.0), Vector3(5.0, 2.7, 1.0), "stone")
	_create_block(Vector3(5.5, 1.1, 2.0), Vector3(5.0, 2.7, 1.0), "stone")
	_create_block(Vector3(-3.6, 1.2, -5.5), Vector3(6.0, 3.0, 1.0), "stone")
	_create_block(Vector3(5.0, 1.2, -5.5), Vector3(5.0, 3.0, 1.0), "stone")
	_create_block(Vector3(-5.25, 1.6, -18.5), Vector3(6.5, 3.8, 1.0), "stone")
	_create_block(Vector3(5.25, 1.6, -18.5), Vector3(6.5, 3.8, 1.0), "stone")
	for z_position in [-2.0, -10.0, -17.0, -28.0]:
		_create_pillar(Vector3(-7.4, 1.7, z_position))
		_create_pillar(Vector3(7.4, 1.7, z_position))
	_create_block(Vector3(-7.0, 0.2, -7.8), Vector3(3.0, 0.5, 2.5), "moss")
	_create_block(Vector3(6.5, 0.2, -14.0), Vector3(2.6, 0.5, 3.5), "moss")
	for brazier_position in [
		Vector3(-6.4, 0.0, 4.0),
		Vector3(6.4, 0.0, -4.0),
		Vector3(-6.4, 0.0, -15.5),
		Vector3(5.4, 0.0, -22.0),
	]:
		_create_ember_brazier(brazier_position)
	_create_landmark()
	_create_boundary_fog()
	_create_ground_detail()
	_create_wall_detail()
	_create_ceiling_beams()
	_create_atmospheric_particles()


func _create_landmark() -> void:
	var spire := MeshInstance3D.new()
	spire.name = "BrokenSpire"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.3
	mesh.bottom_radius = 1.4
	mesh.height = 13.0
	mesh.radial_segments = 8
	mesh.material = materials["stone"]
	spire.mesh = mesh
	spire.position = Vector3(0.0, 6.0, -37.0)
	spire.rotation_degrees.z = -7.0
	add_child(spire)
	# Broken top fragment — tilted block on top
	var fragment := MeshInstance3D.new()
	fragment.name = "SpireTopFragment"
	var frag_mesh := BoxMesh.new()
	frag_mesh.size = Vector3(1.1, 1.4, 1.8)
	frag_mesh.material = materials["stone"]
	fragment.mesh = frag_mesh
	fragment.position = Vector3(0.3, 8.5, -36.2)
	fragment.rotation_degrees = Vector3(-22.0, 18.0, 5.0)
	add_child(fragment)
	# Rubble at base
	for i in range(4):
		var rubble := MeshInstance3D.new()
		var rubble_mesh := BoxMesh.new()
		rubble_mesh.size = Vector3(0.8 + float(i) * 0.3, 0.4, 0.8 + float(i) * 0.2)
		rubble_mesh.material = materials["stone_dark"]
		rubble.mesh = rubble_mesh
		var angle := float(i) / 4.0 * TAU + 0.3
		var dist := 2.2 + float(i) * 0.6
		rubble.position = Vector3(sin(angle) * dist, 0.15, -37.0 + cos(angle) * dist * 0.4)
		rubble.rotation_degrees = Vector3(randf() * 20.0, randf() * 60.0, randf() * 15.0)
		add_child(rubble)
	# Beacon light
	var beacon := OmniLight3D.new()
	beacon.position = Vector3(0.0, 9.5, -37.0)
	beacon.light_color = Color("f14b28")
	beacon.light_energy = 7.0
	beacon.omni_range = 18.0
	add_child(beacon)


func _create_boundary_fog() -> void:
	for side in [-1.0, 1.0]:
		var veil := MeshInstance3D.new()
		var plane := QuadMesh.new()
		plane.size = Vector2(14.0, 5.0)
		plane.material = _material(Color(0.08, 0.14, 0.2, 0.55), 1.0, 0.0, Color("1d3852"), 0.6, true)
		veil.mesh = plane
		veil.position = Vector3(side * 10.0, 2.0, -26.0)
		veil.rotation_degrees.y = 90.0
		add_child(veil)


func _create_ground_detail() -> void:
	# Scattered rubble stones on the floor
	var rubble_positions := [
		Vector3(-5.2, 0.05, 3.5), Vector3(4.8, 0.05, -1.2), Vector3(-3.5, 0.05, -8.0),
		Vector3(6.0, 0.05, -10.5), Vector3(-6.5, 0.05, -20.0), Vector3(3.2, 0.05, -24.0),
		Vector3(-2.0, 0.05, -14.5), Vector3(7.2, 0.05, -18.0), Vector3(-4.8, 0.05, 8.0),
		Vector3(1.5, 0.05, -3.5), Vector3(-7.0, 0.05, -12.0), Vector3(5.5, 0.05, 6.0),
	]
	for pos in rubble_positions:
		var rubble := MeshInstance3D.new()
		var size := Vector3(randf_range(0.2, 0.6), randf_range(0.08, 0.18), randf_range(0.2, 0.55))
		var box := BoxMesh.new()
		box.size = size
		box.material = materials["rubble"]
		rubble.mesh = box
		rubble.position = pos + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3))
		rubble.rotation_degrees = Vector3(randf_range(0, 15), randf_range(0, 60), randf_range(0, 15))
		add_child(rubble)
	# Ember vein cracks on the floor (emissive lines)
	var vein_positions := [
		Vector3(-3.0, 0.02, -12.0),
		Vector3(4.0, 0.02, -20.0),
		Vector3(-5.5, 0.02, -25.0),
		Vector3(2.0, 0.02, 5.0),
	]
	for pos in vein_positions:
		for k in range(3):
			var vein := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(randf_range(0.3, 0.8), 0.015, randf_range(0.03, 0.06))
			box.material = materials["ember_vein"]
			vein.mesh = box
			vein.position = pos + Vector3(randf_range(-1.0, 1.0), 0, randf_range(-0.5, 0.5))
			vein.rotation_degrees.y = randf_range(0, 90)
			add_child(vein)


func _create_wall_detail() -> void:
	# Moss patches on walls
	var moss_positions := [
		Vector3(-8.95, 0.6, -3.0), Vector3(8.95, 0.8, -8.0),
		Vector3(-8.95, 1.2, -15.0), Vector3(8.95, 0.5, -22.0),
		Vector3(-8.95, 0.7, -25.0), Vector3(8.95, 1.1, -4.0),
	]
	for pos in moss_positions:
		var moss := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.06, randf_range(0.5, 1.2), randf_range(0.8, 2.0))
		box.material = materials["moss"]
		moss.mesh = box
		moss.position = pos
		add_child(moss)
	# Wall crack marks (thin dark lines)
	for i in range(8):
		var crack := MeshInstance3D.new()
		var box := BoxMesh.new()
		var side := -1.0 if i % 2 == 0 else 1.0
		var z := float(i) * 5.5 - 15.0
		box.size = Vector3(0.03, randf_range(0.6, 1.6), randf_range(0.02, 0.04))
		box.material = materials["stone_dark"]
		crack.mesh = box
		crack.position = Vector3(side * 8.5, randf_range(0.4, 2.2), z)
		crack.rotation_degrees.z = randf_range(-15, 15)
		add_child(crack)
	# Ember vein markings on walls
	for i in range(5):
		var vein := MeshInstance3D.new()
		var box := BoxMesh.new()
		var side := -1.0 if i % 2 == 0 else 1.0
		box.size = Vector3(0.015, randf_range(0.4, 0.9), randf_range(0.03, 0.05))
		box.material = materials["ember_vein"]
		vein.mesh = box
		vein.position = Vector3(side * 8.51, randf_range(0.5, 2.5), float(i) * 7.0 - 18.0)
		add_child(vein)


func _create_ceiling_beams() -> void:
	# Overhead beams crossing the corridor
	for z_pos in [-3.0, -10.0, -18.0, -26.0]:
		var beam := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(18.5, 0.2, 0.35)
		box.material = materials["wood"]
		beam.mesh = box
		beam.position = Vector3(0, 4.3, z_pos)
		add_child(beam)
		# Beam end supports
		for side in [-1.0, 1.0]:
			var bracket := MeshInstance3D.new()
			var bracket_mesh := BoxMesh.new()
			bracket_mesh.size = Vector3(0.25, 0.5, 0.35)
			bracket_mesh.material = materials["metal"]
			bracket.mesh = bracket_mesh
			bracket.position = Vector3(side * 8.6, 4.0, z_pos)
			add_child(bracket)
	# Hanging chain stubs from beams
	for z_pos in [-3.0, -18.0]:
		for x_off in [-3.0, 3.0]:
			var chain := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.03
			cyl.bottom_radius = 0.03
			cyl.height = randf_range(0.5, 1.2)
			cyl.material = materials["metal"]
			chain.mesh = cyl
			chain.position = Vector3(x_off, 3.7, z_pos + randf_range(-0.3, 0.3))
			add_child(chain)


func _create_atmospheric_particles() -> void:
	# Floating ember motes
	var ember_particles := GPUParticles3D.new()
	ember_particles.name = "EmberParticles"
	ember_particles.emitting = true
	ember_particles.amount = 40
	ember_particles.lifetime = 4.0
	ember_particles.position = Vector3(0, 2.2, -10.0)
	var ember_box := BoxMesh.new()
	ember_box.size = Vector3(16.0, 3.5, 30.0)
	ember_particles.draw_pass_1 = ember_box
	ember_particles.draw_pass_1.material = materials["ember"]
	var ember_mat := ParticleProcessMaterial.new()
	ember_mat.direction = Vector3(0, 0.5, 0)
	ember_mat.spread = 35.0
	ember_mat.initial_velocity_min = 0.3
	ember_mat.initial_velocity_max = 1.5
	ember_mat.gravity = Vector3(0, 0.15, 0)
	ember_mat.scale_min = 0.08
	ember_mat.scale_max = 0.25
	ember_mat.color = Color(1.0, 0.4, 0.08, 0.7)
	ember_particles.process_material = ember_mat
	add_child(ember_particles)
	# Fog dust motes
	var dust_particles := GPUParticles3D.new()
	dust_particles.name = "DustParticles"
	dust_particles.emitting = true
	dust_particles.amount = 25
	dust_particles.lifetime = 6.0
	dust_particles.position = Vector3(0, 1.0, -10.0)
	var dust_sphere := SphereMesh.new()
	dust_sphere.radius = 0.02
	dust_sphere.height = 0.04
	var dust_mesh_mat := _material(Color(0.5, 0.55, 0.6, 0.4), 0.0, 0.0)
	dust_sphere.material = dust_mesh_mat
	dust_particles.draw_pass_1 = dust_sphere
	var dust_mat := ParticleProcessMaterial.new()
	dust_mat.direction = Vector3(0, 0, 0)
	dust_mat.spread = 180.0
	dust_mat.initial_velocity_min = 0.05
	dust_mat.initial_velocity_max = 0.3
	dust_mat.gravity = Vector3(0, -0.02, 0)
	dust_mat.scale_min = 0.5
	dust_mat.scale_max = 1.5
	dust_mat.color = Color(0.6, 0.65, 0.7, 0.25)
	dust_particles.process_material = dust_mat
	add_child(dust_particles)


func _create_pillar(at: Vector3) -> void:
	# Pillar shaft
	_create_block(at, Vector3(1.1, 3.4, 1.1), "stone")
	# Capital (top)
	_create_block(at + Vector3(0.0, 1.9, 0.0), Vector3(1.6, 0.35, 1.6), "stone")
	# Base plinth
	_create_block(at + Vector3(0.0, -1.55, 0.0), Vector3(1.4, 0.25, 1.4), "stone_dark")


func _create_ember_brazier(at: Vector3) -> void:
	var brazier := Node3D.new()
	brazier.name = "EmberBrazier"
	brazier.position = at
	add_child(brazier)

	# Base stone
	var base := MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 0.28
	base_mesh.bottom_radius = 0.38
	base_mesh.height = 0.15
	base_mesh.radial_segments = 10
	base_mesh.material = materials["stone"]
	base.mesh = base_mesh
	base.position.y = 0.07
	brazier.add_child(base)

	var pedestal := MeshInstance3D.new()
	var pedestal_mesh := CylinderMesh.new()
	pedestal_mesh.top_radius = 0.24
	pedestal_mesh.bottom_radius = 0.34
	pedestal_mesh.height = 1.15
	pedestal_mesh.radial_segments = 10
	pedestal_mesh.material = materials["metal"]
	pedestal.mesh = pedestal_mesh
	pedestal.position.y = 0.64
	brazier.add_child(pedestal)

	# Metal ring band
	var band := MeshInstance3D.new()
	var band_mesh := CylinderMesh.new()
	band_mesh.top_radius = 0.28
	band_mesh.bottom_radius = 0.28
	band_mesh.height = 0.06
	band_mesh.radial_segments = 10
	band_mesh.material = materials["metal"]
	band.mesh = band_mesh
	band.position.y = 1.0
	brazier.add_child(band)

	var ember_core := MeshInstance3D.new()
	var ember_mesh := SphereMesh.new()
	ember_mesh.radius = 0.22
	ember_mesh.height = 0.42
	ember_mesh.radial_segments = 10
	ember_mesh.rings = 6
	ember_mesh.material = materials["ember"]
	ember_core.mesh = ember_mesh
	ember_core.position.y = 1.28
	brazier.add_child(ember_core)

	# Inner flame wisp
	var wisp := MeshInstance3D.new()
	var wisp_mesh := SphereMesh.new()
	wisp_mesh.radius = 0.12
	wisp_mesh.height = 0.24
	wisp_mesh.radial_segments = 8
	wisp_mesh.rings = 4
	var wisp_mat := _material(Color(1.0, 0.95, 0.5), 0.15, 0.0, Color(1.0, 0.6, 0.1), 5.0)
	wisp.mesh = wisp_mesh
	wisp.position.y = 1.32
	wisp.material_override = wisp_mat
	brazier.add_child(wisp)

	var light := OmniLight3D.new()
	light.position.y = 1.38
	light.light_color = Color("ff7338")
	light.light_energy = 2.8
	light.omni_range = 7.0
	light.shadow_enabled = false
	brazier.add_child(light)


func _create_gate(at: Vector3) -> Node3D:
	var gate := Node3D.new()
	gate.name = "ShortcutGate"
	gate.position = at
	add_child(gate)
	# Vertical bars
	for offset: float in [-1.6, -0.8, 0.0, 0.8, 1.6]:
		var bar := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.22, 3.0, 0.3)
		mesh.material = materials["metal"]
		bar.mesh = mesh
		bar.position = Vector3(offset, 0.0, 0.0)
		gate.add_child(bar)
	# Top crossbeam
	var beam := MeshInstance3D.new()
	beam.name = "GateBeam"
	var beam_mesh := BoxMesh.new()
	beam_mesh.size = Vector3(3.8, 0.22, 0.35)
	beam_mesh.material = materials["metal"]
	beam.mesh = beam_mesh
	beam.position = Vector3(0.0, 1.55, 0.0)
	gate.add_child(beam)
	# Bottom crossbeam
	var bot_beam := MeshInstance3D.new()
	bot_beam.name = "GateBottomBeam"
	var bot_mesh := BoxMesh.new()
	bot_mesh.size = Vector3(3.8, 0.18, 0.3)
	bot_mesh.material = materials["metal"]
	bot_beam.mesh = bot_mesh
	bot_beam.position = Vector3(0.0, -1.55, 0.0)
	gate.add_child(bot_beam)
	# Rivets on crossbeam
	for rivet_x in [-1.5, -0.5, 0.5, 1.5]:
		var rivet := MeshInstance3D.new()
		var rivet_mesh := SphereMesh.new()
		rivet_mesh.radius = 0.06
		rivet_mesh.height = 0.10
		rivet_mesh.material = materials["metal"]
		rivet.mesh = rivet_mesh
		rivet.position = Vector3(rivet_x, 1.66, 0.18)
		gate.add_child(rivet)

	var body := StaticBody3D.new()
	body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.0, 3.0, 0.5)
	shape.shape = box
	body.add_child(shape)
	gate.add_child(body)
	return gate


func _create_block(at: Vector3, size: Vector3, material_name: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	body.collision_layer = 1
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = materials[material_name]
	visual.mesh = mesh
	body.add_child(visual)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	add_child(body)
	return body


func _material(color: Color, roughness: float, metallic: float, emission := Color.BLACK, emission_energy := 0.0, transparent := false) -> StandardMaterial3D:
	return _ProcUtils.make_material(color, roughness, metallic, emission, emission_energy, transparent)


func _configure_inputs() -> void:
	_add_key_action("move_forward", KEY_W)
	_add_key_action("move_back", KEY_S)
	_add_key_action("move_left", KEY_A)
	_add_key_action("move_right", KEY_D)
	_add_key_action("sprint", KEY_SHIFT)
	_add_key_action("dodge", KEY_SPACE)
	_add_key_action("lock_on", KEY_Q)
	_add_key_action("interact", KEY_E)
	_add_key_action("right_primary", KEY_J)
	_add_key_action("right_secondary", KEY_K)
	_add_key_action("left_primary", KEY_C)
	_add_key_action("left_secondary", KEY_R)
	_add_key_action("light_attack_alt", KEY_J)
	_add_key_action("heavy_attack_alt", KEY_K)
	_add_key_action("help", KEY_F1)
	_add_key_action("pause", KEY_ESCAPE)
	_add_key_action("guard", KEY_C)
	_add_key_action("parry", KEY_R)
	_add_key_action("special_attack", KEY_F)
	_add_key_action("cast_spell", KEY_G)
	_add_key_action("cycle_style", KEY_TAB)
	_add_key_action("style_1", KEY_1)
	_add_key_action("style_2", KEY_2)
	_add_key_action("style_3", KEY_3)
	_add_key_action("style_4", KEY_4)
	_add_key_action("style_5", KEY_5)
	_add_mouse_action("right_primary", MOUSE_BUTTON_LEFT)
	_add_mouse_action("right_secondary", MOUSE_BUTTON_RIGHT)
	_add_mouse_action("light_attack", MOUSE_BUTTON_LEFT)
	_add_mouse_action("heavy_attack", MOUSE_BUTTON_RIGHT)
	_add_mouse_action("lock_on", MOUSE_BUTTON_MIDDLE)
	_add_joy_axis_action("move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_joy_axis_action("move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_joy_axis_action("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_add_joy_axis_action("move_back", JOY_AXIS_LEFT_Y, 1.0)
	_add_joy_axis_action("look_left", JOY_AXIS_RIGHT_X, -1.0)
	_add_joy_axis_action("look_right", JOY_AXIS_RIGHT_X, 1.0)
	_add_joy_axis_action("look_up", JOY_AXIS_RIGHT_Y, -1.0)
	_add_joy_axis_action("look_down", JOY_AXIS_RIGHT_Y, 1.0)
	_add_joy_button_action("dodge", JOY_BUTTON_A)
	_add_joy_button_action("interact", JOY_BUTTON_Y)
	_add_joy_button_action("right_primary", JOY_BUTTON_RIGHT_SHOULDER)
	_add_joy_axis_action("right_secondary", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_add_joy_button_action("left_primary", JOY_BUTTON_LEFT_SHOULDER)
	_add_joy_axis_action("left_secondary", JOY_AXIS_TRIGGER_LEFT, 1.0)
	_add_joy_button_action("light_attack", JOY_BUTTON_RIGHT_SHOULDER)
	_add_joy_axis_action("heavy_attack", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_add_joy_button_action("lock_on", JOY_BUTTON_RIGHT_STICK)
	_add_joy_button_action("sprint", JOY_BUTTON_LEFT_STICK)
	_add_joy_button_action("pause", JOY_BUTTON_START)
	_add_joy_button_action("help", JOY_BUTTON_BACK)
	_add_joy_button_action("special_attack", JOY_BUTTON_B)
	_add_joy_button_action("parry", JOY_BUTTON_X)
	_add_joy_button_action("cycle_style", JOY_BUTTON_DPAD_RIGHT)


func _add_key_action(action: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	_add_input_event_once(action, event)


func _add_mouse_action(action: StringName, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventMouseButton.new()
	event.button_index = button
	_add_input_event_once(action, event)


func _add_joy_button_action(action: StringName, button: JoyButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventJoypadButton.new()
	event.button_index = button
	_add_input_event_once(action, event)


func _add_joy_axis_action(action: StringName, axis: JoyAxis, axis_value: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.22)
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = axis_value
	_add_input_event_once(action, event)


func _add_input_event_once(action: StringName, event: InputEvent) -> void:
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)


func _generate_navigation() -> void:
	var nav_region := NavigationRegion3D.new()
	nav_region.name = "NavRegion"
	add_child(nav_region)

	var nav_mesh := NavigationMesh.new()
	nav_mesh.agent_radius = 0.5
	nav_mesh.agent_height = 2.0
	nav_mesh.agent_max_climb = 0.5
	nav_mesh.agent_max_slope = 45.0
	nav_mesh.cell_size = 0.25
	nav_mesh.cell_height = 0.25
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nav_region.navigation_mesh = nav_mesh

	var walkable_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30.0, 50.0)
	walkable_mesh.mesh = plane
	walkable_mesh.position = Vector3(0.0, 0.01, -12.0)
	nav_region.add_child(walkable_mesh)

	await get_tree().process_frame
	nav_region.bake_navigation_mesh(false)


func _run_smoke_test() -> void:
	var SmokeTest = load("res://tests/smoke/smoke_test.gd")
	SmokeTest.run(self)
