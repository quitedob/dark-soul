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
const InputConfigScript = preload("res://scripts/core/input_config.gd")
const WorldEnvScript = preload("res://scripts/core/world_environment.gd")
const LevelBuilderScript = preload("res://scripts/core/level_builder.gd")

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
var brazier_lights: Array[OmniLight3D] = []
var brazier_flicker_phases: Array[float] = []
var world_environment: WorldEnvironment
var run_state
var game_settings
var interaction_sensor: Area3D
var interaction_candidates: Array[Area3D] = []
var _interaction_refresh := 0.0
var _play_time_fraction_ms := 0.0
var _env_setup: WorldEnvSetup
var _level_builder: AshenLevelBuilder


func _ready() -> void:
	InputConfigScript.configure_inputs()
	_env_setup = WorldEnvScript.new()
	_env_setup.setup(self)
	_env_setup.create_environment()
	materials = _env_setup.create_materials()
	_level_builder = LevelBuilderScript.new()
	_level_builder.setup(self, materials, brazier_lights, brazier_flicker_phases)
	_level_builder.create_level()
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
	_update_brazier_flicker(delta)


func _update_brazier_flicker(delta: float) -> void:
	_env_setup.update_brazier_flicker(delta, brazier_lights, brazier_flicker_phases)


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


func _create_level() -> void:
	_level_builder.create_level()


func _create_gate(at: Vector3) -> Node3D:
	return _level_builder._create_gate(at)


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
