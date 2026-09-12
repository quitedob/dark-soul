extends Node3D

const PlayerScene = preload("res://scenes/actors/player.tscn")
const _ProcUtils = preload("res://scripts/core/procedural_utils.gd")
const EnemyScene = preload("res://scenes/actors/enemy.tscn")
const EnemyScript = preload("res://scripts/enemy.gd")
const HudScene = preload("res://scenes/ui/hud.tscn")
const HudThemeScript = preload("res://scripts/ui/hud_theme.gd")
const LevelModuleVisuals = preload("res://scripts/levels/procedural_level_modules.gd")
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
const CampaignLevelRuntimeScript = preload("res://scripts/world/campaign_level_runtime.gd")
const CampaignModuleRuntimeScript = preload("res://scripts/world/campaign_module_runtime.gd")
const Chapter1ContentScript = preload("res://scripts/data/chapter_1_content.gd")
const Chapter2ContentScript = preload("res://scripts/data/chapter_2_content.gd")
const Chapter3ContentScript = preload("res://scripts/data/chapter_3_content.gd")
const Chapter4ContentScript = preload("res://scripts/data/chapter_4_content.gd")
const Chapter5ContentScript = preload("res://scripts/data/chapter_5_content.gd")
const OptionalBossContentScript = preload("res://scripts/data/optional_boss_content.gd")
const SafePlacement = preload("res://scripts/core/safe_placement.gd")
const HitStopManagerScript = preload("res://scripts/combat/hit_stop_manager.gd")
const TraumaShakeScript = preload("res://scripts/components/trauma_shake.gd")
const CombatCameraDirectorScript = preload("res://scripts/combat/combat_camera_director.gd")
const BossPhasePolisherScript = preload("res://scripts/boss/boss_phase_polisher.gd")
const ImpactVfxScript = preload("res://scripts/fx/impact_vfx.gd")
const PhaseEnvironmentScript = preload("res://scripts/fx/phase_environment.gd")
const ArenaDirectorScript = preload("res://scripts/world/arena_director.gd")
const BossEncounterBoundaryScript = preload("res://scripts/world/boss_encounter_boundary.gd")
const CampaignEncounterLayoutScript = preload("res://scripts/world/campaign_encounter_layout.gd")
const CampaignSceneDressingScript = preload("res://scripts/data/campaign_scene_dressing.gd")
const CampaignStoryProgressionScript = preload("res://scripts/world/campaign_story_progression.gd")
const CampaignStoryMechanismsScript = preload("res://scripts/world/campaign_story_mechanisms.gd")
const BossFlowControllerScript = preload("res://scripts/boss/boss_flow_controller.gd")
const FateChoiceOverlayScript = preload("res://scripts/ui/fate_choice_overlay.gd")
const FateCatalog = preload("res://scripts/combat/data/boss_fate_catalog.gd")
const DialogueOverlayScript = preload("res://scripts/ui/dialogue_overlay.gd")
const DialogueRunnerScript = preload("res://scripts/story/dialogue_runner.gd")
const ShrineNpcInteractScript = preload("res://scripts/world/shrine_npc_interact.gd")
const FurnaceMemoryCrystalScript = preload("res://scripts/world/furnace_memory_crystal.gd")
const SamsaraForkInteractScript = preload("res://scripts/world/samsara_fork_interact.gd")
const EndingResolverScript = preload("res://scripts/story/ending_resolver.gd")
const QuestStateScript = preload("res://scripts/story/quest_state.gd")
const CampaignContentScript = preload("res://scripts/data/campaign_content.gd")
const FastTravelOverlayScript = preload("res://scripts/ui/fast_travel_overlay.gd")
const InventoryOverlayScript = preload("res://scripts/ui/inventory_overlay.gd")
const MeridianDataScript = preload("res://scripts/player/meridian_data.gd")
const MeridianSystemScript = preload("res://scripts/player/meridian_system.gd")
const HandEquipmentScript = preload("res://scripts/data/hand_equipment.gd")

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
var respawn_position := Vector3(0.0, 1.1, 0.0)
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
var campaign_runtime: CampaignLevelRuntime
var _module_runtime: CampaignModuleRuntime
var _hit_stop_manager: HitStopManager
var _trauma_shake: TraumaShake
var _camera_director = null
var _phase_polisher = null  # G-04 Boss 相变抛光
var _impact_vfx = null  # L-24 命中冲击粒子池（GPU 一次性爆发）
var _phase_environment = null  # L-24 相变环境漂移（雾/光/调色渐变）
var _arena_director = null  # L-26 Boss 场地互动导演（塌陷环 / 药罐 / 相变塌陷）
var _boss_boundary = null
var _boss_aftermath_pending := false
var _fate_overlay = null
var _dialogue_overlay = null
var _pending_fate_boss = null
var _samsara_queue: Array = []
var _level_transition_locked := false
var _shrine_npcs: Array = []
var _fast_travel_overlay = null
var _inventory_overlay = null
var _restoring_run_state := false
var _systems_ready := false
# L-09：当前聚焦经脉（任脉起；休息时自动尝试升级，可被 set_meridian_focus 轮转）
var _meridian_focus := 0
# L-15：道行/魂器加成已应用到玩家的登记等级（幂等增量用）
var _applied_dao_level := 0
var _applied_vessel_level := 0


func _ready() -> void:
	assert(is_equal_approx(Engine.time_scale, 1.0), "Engine.time_scale must remain 1.0; use local hit-stop.")
	InputConfigScript.configure_inputs()
	_env_setup = WorldEnvScript.new()
	_env_setup.setup(self)
	_env_setup.create_environment()
	# L-24：补上历史漏赋值——world_environment 此前从未被赋值，低画质开关因此静默失效
	world_environment = get_node_or_null("NightEnvironment") as WorldEnvironment
	materials = _env_setup.create_materials()
	campaign_runtime = CampaignLevelRuntimeScript.new()
	campaign_runtime.name = "CampaignLevelRuntime"
	add_child(campaign_runtime)
	campaign_runtime.load_level(&"level_01_01")
	_update_level_markers()
	_apply_level_environment()
	_create_systems()
	_load_initial_state()
	_systems_ready = true
	_wire_destructible_rewards()
	call_deferred("_generate_navigation")
	if "--smoke-test" in OS.get_cmdline_user_args():
		get_tree().create_timer(2.0).timeout.connect(_run_smoke_test)
	if OS.is_debug_build() and OS.has_feature("web") and "--browser-audit" in OS.get_cmdline_user_args():
		var browser_audit = load("res://tests/tools/browser_gameplay_audit.gd").new()
		browser_audit.name = "BrowserGameplayAudit"
		add_child(browser_audit)


func _load_campaign_level(level_id: StringName) -> bool:
	if campaign_runtime == null:
		return false
	var level_root := campaign_runtime.load_level(level_id)
	if level_root == null:
		return false
	_clear_level_runtime()
	_update_level_markers()
	_apply_level_environment()
	call_deferred("_generate_navigation")
	_spawn_shrine_npc()
	if checkpoint != null:
		checkpoint.position = _checkpoint_position()
	if player != null and is_instance_valid(player):
		_spawn_chapter_encounters()
		_activate_campaign_modules()
		# K-系列多 Boss 存档修复：胜利态只按"本关" Boss id 是否已在 defeated_bosses 判定，
		# 不再用跨关卡共享的全局 victory 位，避免第二章及以后 Boss 关误判。
		var boss_id := _current_boss_id()
		victory = _is_boss_defeated(boss_id)
		var resume_escape := victory and boss_id == "boss_xuan_xiao" and not bool(run_state.get_choice_flag("aftermath_complete_" + boss_id, false))
		_boss_aftermath_pending = resume_escape
		if victory and guardian != null and is_instance_valid(guardian):
			if is_instance_valid(_boss_boundary):
				_boss_boundary.mark_cleared()
			guardian.queue_free()
			guardian = null
			_open_boss_victory_exit()
		player.respawn_at(respawn_position)
		if resume_escape and is_instance_valid(_arena_director):
			if not _arena_director.begin_aftermath(StringName(run_state.get_choice_flag("ch4_xuanxiao_fate", "remembered"))):
				push_error("Saved celestial victory requires its unfinished escape course")
	return true


func _clear_level_runtime() -> void:
	if is_instance_valid(player):
		player.clear_traversal_up()
		player.set_story_healing_locked(false)
		player.set_story_cast_locked(false)
		player.set_story_blessing_modifiers({})
	# Generated level children have just been freed. Stop world-owned encounter
	# controllers and invalidate their transient HUD messages before new setup.
	_clear_enemies()
	_arena_director = null
	_boss_boundary = null
	_boss_aftermath_pending = false
	if _module_runtime != null:
		_module_runtime.clear()
	if _phase_polisher != null:
		_phase_polisher.reset()
	for child in get_children():
		if String(child.name).begins_with("ArenaPhaseVfx_"):
			remove_child(child)
			child.queue_free()
	_samsara_queue.clear()
	_pending_fate_boss = null
	interaction_candidates.clear()
	_interaction_refresh = 0.0
	if hud != null:
		hud.show_message("", 0.0)
		hud.set_prompt("")
		hud.hide_boss()
		hud.set_lock_target(null)


func _apply_level_environment() -> void:
	# Cancel the previous boss tween before taking the next chapter's baseline.
	if _phase_environment != null:
		_phase_environment.restore_defaults(0.0)
	_env_setup.apply_theme(StringName(campaign_runtime.get_level_data().get("theme_id", &"theme_spirit_ruins")))
	if campaign_runtime.current_level_id == &"level_01_01":
		var environment := world_environment.environment
		environment.fog_density = 0.0035
		environment.background_color = Color("101c25")
		environment.fog_light_color = Color("354d58")
		environment.ambient_light_energy = 0.62
		environment.adjustment_contrast = 1.05
		for x in [-19.0, 19.0]:
			var light_name := "PavilionLightWest" if x < 0.0 else "PavilionLightEast"
			if campaign_runtime.current_level.has_node(light_name):
				continue
			var light := OmniLight3D.new()
			light.name = light_name
			light.position = Vector3(x, 4.3, -116.0)
			light.light_color = Color("ffb56a")
			light.light_energy = 1.7
			light.omni_range = 10.0
			light.shadow_enabled = true
			campaign_runtime.current_level.add_child(light)
		for point in [Vector3(-42, 4.6, -57), Vector3(-42, 4.6, -75), Vector3(42, 4.6, -69), Vector3(42, 4.6, -87)]:
			var light_name := "CloisterLight_%d_%d" % [int(point.x), int(point.z)]
			if campaign_runtime.current_level.has_node(light_name):
				continue
			var light := OmniLight3D.new()
			light.name = light_name
			light.position = point
			light.light_color = Color("d8ab75")
			light.light_energy = 0.85
			light.omni_range = 14.0
			campaign_runtime.current_level.add_child(light)
	_update_hud_location()
	if _phase_environment != null:
		_phase_environment.bind(world_environment, _find_key_light())
	var blank := get_node_or_null("BlankTestArea")
	if blank != null:
		remove_child(blank)
		blank.queue_free()


func _update_level_markers() -> void:
	if campaign_runtime == null:
		return
	var spawn_marker := campaign_runtime.get_spawn_marker()
	if spawn_marker != null:
		respawn_position = spawn_marker.global_position
	var checkpoint_position := _checkpoint_position()
	var shrine_glow := get_node_or_null("ShrineGlow") as OmniLight3D
	if shrine_glow != null:
		shrine_glow.position = checkpoint_position + Vector3(0.0, 2.4, 0.0)
		shrine_glow.light_energy = 3.0
	var shrine_fill := get_node_or_null("ShrineFill") as OmniLight3D
	if shrine_fill != null:
		shrine_fill.position = checkpoint_position + Vector3(0.0, 1.2, 1.5)
		shrine_fill.light_energy = 0.9
	if shortcut != null and is_instance_valid(shortcut):
		shortcut.position = _supported_campaign_position(checkpoint_position + Vector3(-6.0, 0.0, -2.0), 0.7, 0.0)
	if shortcut_gate != null and is_instance_valid(shortcut_gate):
		var exit_marker := campaign_runtime.get_exit_marker()
		if exit_marker != null:
			shortcut_gate.position = _supported_campaign_position(exit_marker.global_position + Vector3(0.0, 0.0, 2.0), 1.0, 1.5)
			if shortcut != null and is_instance_valid(shortcut):
				shortcut.setup(shortcut_gate, self)


func _checkpoint_position() -> Vector3:
	if campaign_runtime == null:
		return Vector3(0.0, 0.0, 6.0)
	var marker := campaign_runtime.get_checkpoint_marker()
	return marker.global_position if marker != null else Vector3(0.0, 0.0, 6.0)


func _update_hud_location() -> void:
	if hud == null or campaign_runtime == null:
		return
	var data := campaign_runtime.get_level_data()
	for chapter in CampaignContentScript.chapters():
		if chapter["id"] == data.get("chapter_id"):
			hud.set_location(String(chapter["display_name"]), String(data.get("display_name", "")))
			break


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("equipment") and not event.is_echo():
		if hud != null and hud.open_equipment():
			get_viewport().set_input_as_handled()


func _on_equipment_requested() -> void:
	hud.open_equipment()


func _on_inventory_equipment_requested() -> void:
	_inventory_overlay.close()
	hud.open_equipment()


func _on_weapon_loadout_changed() -> void:
	if _systems_ready and not _restoring_run_state:
		_save_run("weapon_loadout")


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	_play_time_fraction_ms += delta * 1000.0
	var elapsed_whole_ms := int(_play_time_fraction_ms)
	if elapsed_whole_ms > 0:
		run_state.play_time_ms += elapsed_whole_ms
		_play_time_fraction_ms -= elapsed_whole_ms
	if _module_runtime != null:
		_module_runtime.tick_hazards(delta)
	_interaction_refresh -= delta
	if _interaction_refresh > 0.0:
		return
	_interaction_refresh = 0.1
	_update_interaction_target()
	_update_scene_objective()
	_update_brazier_flicker(delta)


func _update_scene_objective() -> void:
	if hud == null:
		return
	var mechanisms := _story_mechanisms()
	var objective := String(mechanisms.exit_block_reason()) if is_instance_valid(mechanisms) else ""
	if is_instance_valid(mechanisms):
		var state: Dictionary = mechanisms.snapshot()
		if not String(state.get("trial", "")).is_empty():
			var remaining_seconds := ceili(float(state.get("trial_remaining", 0.0)))
			if String(state.get("trial", "")) == "gate_keeper":
				objective = HudThemeScript.copy("试炼进行中 · 第 %d 波 · %d 秒", "Trial in progress · Wave %d · %d s") % [maxi(1, int(state.get("trial_wave", 1))), remaining_seconds]
			else:
				objective = HudThemeScript.copy("试炼进行中 · %d 秒", "Trial in progress · %d s") % remaining_seconds
	hud.set_scene_objective(objective)


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


## 调试：把玩家传送到空白开阔测试区（大平地 + 强光），便于目检模型/动作/朝向。
## 由 F2 触发（见 player.gd _unhandled_input）。远离当前关卡坐标，避免与敌人/关卡重叠。
func teleport_player_to_blank(player: Node3D) -> void:
	if player == null:
		return
	var blank := get_node_or_null("BlankTestArea") as Node3D
	if blank == null:
		blank = Node3D.new()
		blank.name = "BlankTestArea"
		blank.position = Vector3(0.0, -0.3, 60.0)
		add_child(blank)
		var floor := StaticBody3D.new()
		floor.name = "Floor"
		floor.collision_layer = 1
		var mi := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(80.0, 0.6, 80.0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.22, 0.24, 0.28)
		mat.roughness = 0.9
		mesh.material = mat
		mi.mesh = mesh
		floor.add_child(mi)
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = mesh.size
		col.shape = shape
		floor.add_child(col)
		blank.add_child(floor)
		var light := OmniLight3D.new()
		light.name = "KeyLight"
		light.position = Vector3(0.0, 8.0, 0.0)
		light.omni_range = 24.0
		light.light_energy = 5.0
		blank.add_child(light)
	player.global_position = blank.position + Vector3(0.0, 1.5, 0.0)
	if player is CharacterBody3D:
		player.velocity = Vector3.ZERO


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
	if hud.has_signal("combat_tip_mode_requested"):
		hud.combat_tip_mode_requested.connect(_on_hud_combat_tip_mode_requested)
	hud.play_started.connect(_on_play_started)
	hud.equipment_requested.connect(_on_equipment_requested)
	if hud.has_signal("epilogue_finished"):
		hud.epilogue_finished.connect(_on_epilogue_finished)

	player = PlayerScene.instantiate()
	player.position = respawn_position
	player.setup(self, audio, hud)
	player.died.connect(_on_player_died)
	player.stats_changed.connect(hud.update_stats)
	player.focus_changed.connect(hud.update_focus)
	player.poise_changed.connect(hud.update_poise)
	player.embers_changed.connect(hud.update_embers)
	player.lock_target_changed.connect(hud.set_lock_target)
	player.combat_style_changed.connect(hud.set_combat_style)
	player.hands_changed.connect(hud.set_hands)
	player.weapon_loadout_changed.connect(_on_weapon_loadout_changed)
	if player.has_signal("charge_progress_changed"):
		player.charge_progress_changed.connect(hud.update_charge_progress)
	player.healing_started.connect(_on_player_healing)
	add_child(player)
	player.combat_area.hit_landed.connect(_on_player_hit_landed)
	hud.setup(player)
	_update_hud_location()
	_hit_stop_manager = HitStopManagerScript.new()
	_hit_stop_manager.name = "HitStopManager"
	add_child(_hit_stop_manager)
	_trauma_shake = TraumaShakeScript.new()
	_trauma_shake.name = "TraumaShake"
	_trauma_shake.setup(player.camera)
	add_child(_trauma_shake)
	_camera_director = CombatCameraDirectorScript.new()
	_camera_director.name = "CombatCameraDirector"
	_camera_director.setup(player, _trauma_shake)
	add_child(_camera_director)
	_phase_polisher = BossPhasePolisherScript.new()
	_phase_polisher.name = "BossPhasePolisher"
	_phase_polisher.setup(_camera_director)
	add_child(_phase_polisher)
	_impact_vfx = ImpactVfxScript.new()
	_impact_vfx.name = "ImpactVfx"
	add_child(_impact_vfx)
	_phase_environment = PhaseEnvironmentScript.new()
	_phase_environment.name = "PhaseEnvironment"
	add_child(_phase_environment)
	if world_environment != null:
		_phase_environment.bind(world_environment, _find_key_light())
	_fate_overlay = FateChoiceOverlayScript.new()
	_fate_overlay.name = "FateChoiceOverlay"
	add_child(_fate_overlay)
	_fate_overlay.choice_made.connect(_on_fate_choice_made)
	_dialogue_overlay = DialogueOverlayScript.new()
	_dialogue_overlay.name = "DialogueOverlay"
	add_child(_dialogue_overlay)
	_dialogue_overlay.dialogue_finished.connect(_on_dialogue_finished)
	# L-12：快速旅行菜单（烬龛休息时打开）
	_fast_travel_overlay = FastTravelOverlayScript.new()
	_fast_travel_overlay.name = "FastTravelOverlay"
	add_child(_fast_travel_overlay)
	_fast_travel_overlay.destination_selected.connect(_on_fast_travel_selected)
	# L-10：背包/图鉴菜单（烬龛休息时打开）
	_inventory_overlay = InventoryOverlayScript.new()
	_inventory_overlay.name = "InventoryOverlay"
	add_child(_inventory_overlay)
	_inventory_overlay.inventory_closed.connect(_on_inventory_closed)
	_inventory_overlay.equipment_requested.connect(_on_inventory_equipment_requested)
	if player.has_signal("execution_started"):
		player.execution_started.connect(_on_player_execution_started)
	_create_interaction_sensor()

	checkpoint = CheckpointScene.instantiate()
	checkpoint.position = _checkpoint_position()
	var level_data := campaign_runtime.get_level_data() if campaign_runtime != null else {}
	checkpoint.setup(self, String(level_data.get("display_name", "Ember Shrine")))
	checkpoint.activated.connect(_on_checkpoint_activated)
	checkpoint.rested.connect(_on_checkpoint_rested)
	add_child(checkpoint)
	_spawn_shrine_npc()

	var exit_marker := campaign_runtime.get_exit_marker() if campaign_runtime != null else null
	var gate_pos := _supported_campaign_position(exit_marker.global_position + Vector3(0.0, 0.0, 2.0), 1.0, 1.5) if exit_marker != null else Vector3(0.0, 1.5, -5.6)
	shortcut_gate = _create_gate(gate_pos)
	shortcut = ShortcutScene.instantiate()
	shortcut.position = _supported_campaign_position(_checkpoint_position() + Vector3(-6.0, 0.0, -2.0), 0.7, 0.0)
	shortcut.setup(shortcut_gate, self)
	shortcut.opened.connect(_on_shortcut_opened)
	add_child(shortcut)

	_module_runtime = CampaignModuleRuntimeScript.new()
	_module_runtime.name = "CampaignModuleRuntime"
	add_child(_module_runtime)
	_module_runtime.bind(player, hud, audio)
	_module_runtime.exit_requested.connect(_on_campaign_exit_requested)
	_spawn_chapter_encounters()
	_activate_campaign_modules()


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
	var level_data := campaign_runtime.get_level_data() if campaign_runtime != null else {}
	var level_name := HudThemeScript.readable_name(String(level_data.get("display_name", "ASHEN HOLLOW")), game_settings.locale)
	hud.show_message(level_name, 3.0)


func _on_play_started() -> void:
	_show_intro()


func _activate_campaign_modules() -> void:
	# 激活当前关卡模块行为
	if _module_runtime == null or campaign_runtime == null:
		return
	var level_root := campaign_runtime.current_level
	var id := String(campaign_runtime.current_level_id)
	var suppressed := CampaignStoryMechanismsScript.suppressed_modules(id)
	var modules := level_root.get_node_or_null("Modules")
	if modules != null:
		for module in modules.get_children():
			if StringName(module.get_meta("module_id", &"")) in suppressed:
				modules.remove_child(module)
				module.free()
	_module_runtime.activate(level_root, suppressed)
	if not suppressed.is_empty() and not level_root.has_node("StoryMechanisms"):
		var mechanisms := CampaignStoryMechanismsScript.new()
		mechanisms.name = "StoryMechanisms"
		level_root.add_child(mechanisms)
		mechanisms.setup(self, id)
	player.set_story_blessing_modifiers(CampaignStoryMechanismsScript.final_battle_modifiers(run_state) if id == "level_05_05" else {})


func _clear_enemies() -> void:
	# 清除旧遭遇战敌人
	for enemy in enemies:
		if is_instance_valid(enemy):
			# A deferred boss-flow initializer can otherwise display its warning
			# after a same-frame level change, before queue_free is flushed.
			var flow: Node = enemy.get_node_or_null("FlowController")
			if flow != null and "flow_boss" in flow:
				flow.set("flow_boss", null)
			enemy.process_mode = Node.PROCESS_MODE_DISABLED
			if enemy.get_parent() != null:
				enemy.get_parent().remove_child(enemy)
			enemy.queue_free()
	enemies.clear()
	guardian = null


## L-25：主场景静态 GLB 药罐（hub_props 组）只在初始庭园（含烬火神龛）显示
func _update_hub_props() -> void:
	var is_start_level := campaign_runtime == null \
		or String(campaign_runtime.current_level_id) == "level_01_01"
	for prop in get_tree().get_nodes_in_group("hub_props"):
		if prop is Node3D and is_instance_valid(prop):
			prop.visible = is_start_level
			if prop is CollisionObject3D:
				prop.collision_layer = 1 if is_start_level else 0


## L-25：可破坏物奖励接线（hub 静态药罐 + 场地导演生成的药罐），幂等可重入
func _wire_destructible_rewards() -> void:
	for prop in get_tree().get_nodes_in_group("destructibles"):
		if prop is Node3D and prop.has_signal("broken"):
			var handler := _on_destructible_broken.bind(prop)
			if not prop.is_connected("broken", handler):
				prop.broken.connect(handler)


## L-25：药罐碎裂 → 余烬奖励 + 尘土冲击表现
func _on_destructible_broken(_source_position: Vector3, prop) -> void:
	if prop == null or not is_instance_valid(prop):
		return
	var reward := int(prop.get("ember_reward"))
	if reward > 0 and player != null:
		player.add_embers(reward)
	if _impact_vfx != null:
		_impact_vfx.spawn_impact((prop as Node3D).global_position + Vector3.UP * 0.4, Vector3.UP, "dust")


func _spawn_chapter_encounters() -> void:
	_spawn_chapter_encounter_roster()
	_distribute_modeled_encounters()
	var level_root: Node3D = campaign_runtime.current_level
	var clues := CampaignStoryProgressionScript.new()
	clues.name = "CampaignStoryProgression"
	level_root.add_child(clues)
	clues.setup(self, String(campaign_runtime.current_level_id))
	var expansion: Dictionary = level_root.get_meta("expansion", {})
	if not expansion.is_empty():
		var district = load("res://scripts/world/campaign_expansion_runtime.gd").new()
		district.name = "CampaignExpansionRuntime"
		level_root.add_child(district)
		district.setup(self, level_root, expansion)


func _distribute_modeled_encounters() -> void:
	if campaign_runtime == null or campaign_runtime.current_level == null:
		return
	var level_root := campaign_runtime.current_level
	var field_enemies: Array = enemies.filter(func(enemy): return is_instance_valid(enemy) and not enemy.guardian)
	if field_enemies.is_empty():
		return
	var roster: Array = []
	for enemy in field_enemies:
		roster.append({"content_id": enemy.content_id, "body_radius": enemy.chapter_content.get("body_radius", 0.6)})
	var layout: Dictionary = level_root.get_meta("story_layout", level_root.get_meta("modeled_layout", {}))
	if layout.is_empty():
		layout["cells"] = level_root.get_node("NavigationSurface").get_meta("walkable_cells", []) if level_root.has_node("NavigationSurface") else []
	var plans := CampaignEncounterLayoutScript.assign_encounters(String(campaign_runtime.current_level_id), layout, roster)
	if plans.size() != field_enemies.size():
		push_error("Authored encounter roster/placement missing for " + String(campaign_runtime.current_level_id))
		return
	for plan: Dictionary in plans:
		var enemy = field_enemies[int(plan["source_index"])]
		var content: Dictionary = enemy.chapter_content
		var radius := float(content.get("body_radius", 0.6))
		var clearance := maxf(0.05, float(content.get("body_height", 1.9)) * 0.5 - float(content.get("body_y", 0.95)) + 0.05)
		enemy.position = _supported_campaign_position(to_local(level_root.to_global(plan["position"] + Vector3.UP * clearance)), radius, clearance)
		enemy.spawn_origin = enemy.global_position
		enemy.velocity = Vector3.ZERO
		enemy.navigation_refresh = 0.0
		var runtime_plan := plan.duplicate(true)
		var patrol: Array[Vector3] = []
		for point: Vector3 in plan.get("patrol_points", []):
			patrol.append(level_root.to_global(point))
		runtime_plan["patrol_points"] = patrol
		enemy.assign_campaign_encounter(runtime_plan)


func _spawn_chapter_encounter_roster() -> void:
	# 相对标记点生成第一章教程遭遇
	_clear_enemies()
	_update_hub_props()
	if campaign_runtime == null:
		return
	var spawn_marker := campaign_runtime.get_spawn_marker()
	var origin := spawn_marker.global_position if spawn_marker != null else Vector3.ZERO
	var level_data := campaign_runtime.get_level_data()
	var level_id := StringName(level_data.get("id", &"level_01_01"))
	var chapter_id := String(level_data.get("chapter_id", &"chapter_01"))
	if chapter_id == "chapter_02":
		# 第二章·血铁战歌：接入正式内容表遭遇
		_spawn_chapter2_encounters(origin, level_id)
		return
	if chapter_id == "chapter_03":
		# 第三章·玉障迷心：接入正式内容表遭遇
		_spawn_chapter3_encounters(origin, level_id)
		return
	if chapter_id == "chapter_04":
		# 第四章·天崩陨落：接入正式内容表遭遇
		_spawn_chapter4_encounters(origin, level_id)
		return
	if chapter_id == "chapter_05":
		# 第五章·烬座归墟：接入正式内容表遭遇
		_spawn_chapter5_encounters(origin, level_id)
		return
	if chapter_id != "chapter_01":
		# 未注册章节兜底：兼容哨兵
		_spawn_enemy(origin + Vector3(-3.5, 0.95, -5.0), false)
		_spawn_enemy(origin + Vector3(3.5, 0.95, -9.0), false, EnemyScript.EnemyType.ASH_STALKER)
		_spawn_enemy(origin + Vector3(0.0, 0.95, -12.0), false, EnemyScript.EnemyType.EMBER_SKIRMISHER)
		return
	var roster: Array[Dictionary] = Chapter1ContentScript.enemies()
	if roster.is_empty():
		return
	match level_id:
		&"level_01_01":
			var layout: Dictionary = campaign_runtime.current_level.get_meta("awakening_temple_layout", {})
			var encounters: Array = layout.get("encounters", [])
			for index in encounters.size():
				var point: Array = encounters[index]
				var content := _chapter1_skirmisher(roster) if index in [2, 3] else roster[1] if index == 5 else roster[0]
				_spawn_content_enemy(Vector3(float(point[0]), float(point[1]) + 0.95, float(point[2])), content)
		&"level_01_02":
			# 守门廊：3× 失魂 + 1× 庙卫
			_spawn_content_enemy(origin + Vector3(-3.0, 0.95, -5.0), roster[0])
			_spawn_content_enemy(origin + Vector3(3.0, 0.95, -8.0), roster[0])
			_spawn_content_enemy(origin + Vector3(0.0, 0.95, -11.0), roster[0])
			_spawn_content_enemy(origin + Vector3(0.0, 0.95, -15.0), roster[1])
		&"level_01_03":
			# 明镜殿：3× 失魂 + 2× 镜影 + 1× 烬影伏击 + 精英
			_spawn_content_enemy(origin + Vector3(-4.0, 0.95, -5.0), roster[0])
			_spawn_content_enemy(origin + Vector3(4.0, 0.95, -7.0), roster[0])
			_spawn_content_enemy(origin + Vector3(0.0, 0.95, -10.0), roster[0])
			_spawn_content_enemy(origin + Vector3(-3.0, 0.95, -13.0), roster[2])
			_spawn_content_enemy(origin + Vector3(3.0, 0.95, -15.0), roster[2])
			_spawn_content_enemy(origin + Vector3(5.0, 0.95, -11.0), _chapter1_skirmisher(roster))
			var elite_03 := _chapter1_elite_for(level_id)
			if not elite_03.is_empty():
				_spawn_content_enemy(origin + Vector3(0.0, 1.0, -18.0), elite_03)
		&"level_01_04":
			# 炼丹房：2× 庙卫 + 1× 炉渣 + 精英
			_spawn_content_enemy(origin + Vector3(-3.5, 0.95, -6.0), roster[1])
			_spawn_content_enemy(origin + Vector3(3.5, 0.95, -9.0), roster[1])
			_spawn_content_enemy(origin + Vector3(0.0, 0.95, -13.0), roster[3])
			var elite_04 := _chapter1_elite_for(level_id)
			if not elite_04.is_empty():
				_spawn_content_enemy(origin + Vector3(0.0, 1.0, -17.0), elite_04)
		&"level_01_05":
			# 内廷：仅 Boss
			guardian = _spawn_content_enemy(origin + Vector3(0.0, 1.15, -18.0), Chapter1ContentScript.boss(), true)
		_:
			_spawn_content_enemy(origin + Vector3(-3.0, 0.95, -6.0), roster[0])
			_spawn_content_enemy(origin + Vector3(3.0, 0.95, -10.0), roster[min(1, roster.size() - 1)])


func _chapter1_skirmisher(roster: Array[Dictionary]) -> Dictionary:
	# 取 G-03 烬影伏击者条目；缺失时回退内联原型
	for entry in roster:
		if String(entry.get("id", "")) == "ember_shade_skirmisher":
			return entry
	return {
		"id": "ember_shade_skirmisher",
		"display_name": "Ember Shade Skirmisher / 烬影伏击者",
		"max_health": 48.0, "move_speed": 4.6, "aggro_range": 13.0,
		"disengage_range": 21.0, "leash_range": 15.0, "attack_range": 9.0,
		"preferred_distance": 7.0, "retreat_trigger": 4.0,
		"poise_limit": 12.0, "reward": 30, "stagger_duration": 0.55,
		"attack": {"windup": 0.52, "active": 0.12, "recovery": 0.72, "damage": 11.0, "stagger": 9.0, "lunge": 0.85},
		"body_color": "3a1830", "weapon_color": "cc4488", "eye_emission": "ff66aa",
		"weapon_shape": "glass_shard", "body_type": "ethereal_flicker",
		"behavior": "ranged_ambush", "archetype": "ember_skirmisher",
	}


func _chapter1_elite_for(level_id: StringName) -> Dictionary:
	# 按 appears_in 取精英并补齐战斗字段
	for elite in Chapter1ContentScript.elites():
		if String(elite.get("appears_in", "")) != String(level_id):
			continue
		var payload: Dictionary = elite.duplicate(true)
		if not payload.has("attack"):
			payload["attack"] = {
				"windup": 0.7, "active": 0.22, "recovery": 0.85,
				"damage": 26.0, "stagger": 32.0, "lunge": 1.6,
			}
		payload["disengage_range"] = float(payload.get("disengage_range", 22.0))
		payload["leash_range"] = float(payload.get("leash_range", 18.0))
		payload["stagger_duration"] = float(payload.get("stagger_duration", 0.42))
		payload["weapon_color"] = String(payload.get("weapon_color", "6a6040"))
		payload["eye_emission"] = String(payload.get("eye_emission", "ffcc44"))
		return payload
	return {}


func _chapter2_enemy_by_id(roster: Array[Dictionary], id: String) -> Dictionary:
	# 按 id 从二章敌人表中取条目；找不到时返回空字典交由调用方兜底
	for entry in roster:
		if String(entry.get("id", "")) == id:
			return entry
	return {}


func _chapter2_elite_for(level_id: StringName) -> Dictionary:
	# 按 appears_in 取二章精英并补齐战斗字段（同 Ch.1 精英兜底逻辑）
	for elite in Chapter2ContentScript.elites():
		if String(elite.get("appears_in", "")) != String(level_id):
			continue
		var payload: Dictionary = elite.duplicate(true)
		if not payload.has("attack"):
			payload["attack"] = {
				"windup": 0.7, "active": 0.22, "recovery": 0.85,
				"damage": 26.0, "stagger": 32.0, "lunge": 1.6,
			}
		payload["disengage_range"] = float(payload.get("disengage_range", 22.0))
		payload["leash_range"] = float(payload.get("leash_range", 18.0))
		payload["stagger_duration"] = float(payload.get("stagger_duration", 0.42))
		payload["weapon_color"] = String(payload.get("weapon_color", "6a6040"))
		payload["eye_emission"] = String(payload.get("eye_emission", "ffcc44"))
		return payload
	return {}


func _spawn_chapter2_encounters(origin: Vector3, level_id: StringName) -> void:
	# 第二章遭遇表：血染山道 → 铁啸关外墙 → 俘虏营 → 烽火台 → 将军营帐 → 刑天斗场
	var roster: Array[Dictionary] = Chapter2ContentScript.enemies()
	if roster.is_empty():
		return
	match level_id:
		&"level_02_01":
			# 血染山道：3× 残兵
			var soldier := _chapter2_enemy_by_id(roster, "battle_worn_soldier")
			_spawn_content_enemy(origin + Vector3(-3.0, 0.95, -6.0), soldier)
			_spawn_content_enemy(origin + Vector3(3.0, 0.95, -9.0), soldier)
			_spawn_content_enemy(origin + Vector3(0.0, 0.95, -13.0), soldier)
		&"level_02_02":
			# 铁啸关外墙：2× 残兵 + 2× 战犬亡灵
			var soldier_02 := _chapter2_enemy_by_id(roster, "battle_worn_soldier")
			var war_dog := _chapter2_enemy_by_id(roster, "war_dog_wraith")
			_spawn_content_enemy(origin + Vector3(-3.5, 0.95, -5.0), soldier_02)
			_spawn_content_enemy(origin + Vector3(3.5, 0.95, -8.0), soldier_02)
			_spawn_content_enemy(origin + Vector3(-2.0, 0.95, -11.5), war_dog)
			_spawn_content_enemy(origin + Vector3(2.0, 0.95, -12.5), war_dog)
			var elite_02 := _chapter2_elite_for(level_id)
			if not elite_02.is_empty():
				_spawn_content_enemy(origin + Vector3(0.0, 1.0, -16.0), elite_02)
		&"level_02_03":
			# 俘虏营：2× 营守亡灵 + 刑具精魄 + 精英·炉暴刑具
			var camp_guard := _chapter2_enemy_by_id(roster, "camp_guard_wraith")
			_spawn_content_enemy(origin + Vector3(-3.5, 0.95, -6.0), camp_guard)
			_spawn_content_enemy(origin + Vector3(3.5, 0.95, -9.0), camp_guard)
			_spawn_content_enemy(origin + Vector3(0.0, 0.95, -13.0), _chapter2_enemy_by_id(roster, "torture_device_spirit"))
			var elite_03 := _chapter2_elite_for(level_id)
			if not elite_03.is_empty():
				_spawn_content_enemy(origin + Vector3(0.0, 1.0, -17.0), elite_03)
		&"level_02_04":
			# 烽火台：2× 烽火守望者 + 残兵 + 精英·双生烽火守将
			var beacon := _chapter2_enemy_by_id(roster, "beacon_keeper_wraith")
			_spawn_content_enemy(origin + Vector3(-3.5, 0.95, -6.0), beacon)
			_spawn_content_enemy(origin + Vector3(3.5, 0.95, -9.0), beacon)
			_spawn_content_enemy(origin + Vector3(0.0, 0.95, -13.0), _chapter2_enemy_by_id(roster, "battle_worn_soldier"))
			var elite_04 := _chapter2_elite_for(level_id)
			if not elite_04.is_empty():
				_spawn_content_enemy(origin + Vector3(0.0, 1.0, -17.0), elite_04)
		&"level_02_05":
			# 将军营帐：3× 将军亲卫 + 精英·贪噬军需官
			var personal_guard := _chapter2_enemy_by_id(roster, "generals_personal_guard")
			_spawn_content_enemy(origin + Vector3(-3.5, 0.95, -6.0), personal_guard)
			_spawn_content_enemy(origin + Vector3(3.5, 0.95, -9.0), personal_guard)
			_spawn_content_enemy(origin + Vector3(0.0, 0.95, -13.0), personal_guard)
			var elite_05 := _chapter2_elite_for(level_id)
			if not elite_05.is_empty():
				_spawn_content_enemy(origin + Vector3(0.0, 1.0, -16.0), elite_05)
		&"level_02_06":
			# 刑天斗场：仅 Boss 血将军·刑天
			guardian = _spawn_content_enemy(origin + Vector3(0.0, 1.15, -18.0), Chapter2ContentScript.boss(), true)
		_:
			_spawn_content_enemy(origin + Vector3(-3.0, 0.95, -6.0), roster[0])
			_spawn_content_enemy(origin + Vector3(3.0, 0.95, -10.0), roster[min(1, roster.size() - 1)])


## 通用：从任意章节敌人表按 id 取条目
func _chapter_enemy_by_id(roster: Array[Dictionary], id: String) -> Dictionary:
	for entry in roster:
		if String(entry.get("id", "")) == id:
			return entry
	return {}


## 通用：按 appears_in 取章节精英并补齐战斗字段（Ch.1/2 逻辑复用）
func _chapter_elite_for(content_script, level_id: StringName) -> Dictionary:
	for elite in content_script.elites():
		if String(elite.get("appears_in", "")) != String(level_id):
			continue
		var payload: Dictionary = elite.duplicate(true)
		if not payload.has("attack"):
			payload["attack"] = {
				"windup": 0.7, "active": 0.22, "recovery": 0.85,
				"damage": 26.0, "stagger": 32.0, "lunge": 1.6,
			}
		payload["disengage_range"] = float(payload.get("disengage_range", 22.0))
		payload["leash_range"] = float(payload.get("leash_range", 18.0))
		payload["stagger_duration"] = float(payload.get("stagger_duration", 0.42))
		payload["weapon_color"] = String(payload.get("weapon_color", "6a6040"))
		payload["eye_emission"] = String(payload.get("eye_emission", "ffcc44"))
		return payload
	return {}


## 通用：按精英 id 取章节精英并补齐战斗字段（level_03_04 双精英场景专用）
func _chapter_elite_by_id(content_script, elite_id: String) -> Dictionary:
	for elite in content_script.elites():
		if String(elite.get("id", "")) != elite_id:
			continue
		var payload: Dictionary = elite.duplicate(true)
		if not payload.has("attack"):
			payload["attack"] = {
				"windup": 0.7, "active": 0.22, "recovery": 0.85,
				"damage": 26.0, "stagger": 32.0, "lunge": 1.6,
			}
		payload["disengage_range"] = float(payload.get("disengage_range", 22.0))
		payload["leash_range"] = float(payload.get("leash_range", 18.0))
		payload["stagger_duration"] = float(payload.get("stagger_duration", 0.42))
		payload["weapon_color"] = String(payload.get("weapon_color", "6a6040"))
		payload["eye_emission"] = String(payload.get("eye_emission", "ffcc44"))
		return payload
	return {}


func _spawn_chapter3_encounters(origin: Vector3, level_id: StringName) -> void:
	# 第三章·玉障迷心：翠微林入口 → 记忆回廊 → 狐嫁道 → 镜花水月亭 → 九尾迷宫 → 月华台
	var roster: Array[Dictionary] = Chapter3ContentScript.enemies()
	if roster.is_empty():
		return
	match level_id:
		&"level_03_01":
			# 翠微林入口：幻蝶群 + 狐火灯
			var butterfly := _chapter_enemy_by_id(roster, "illusion_butterfly")
			_spawn_content_enemy(origin + Vector3(-3.5, 0.95, -6.0), butterfly)
			_spawn_content_enemy(origin + Vector3(3.5, 0.95, -9.0), butterfly)
			_spawn_content_enemy(origin + Vector3(0.0, 0.95, -13.0), _chapter_enemy_by_id(roster, "foxfire_lantern"))
		&"level_03_02":
			# 记忆回廊：窃忆灵 ×2 + 回声灵 + 精英·千年树魂
			var memory_thief := _chapter_enemy_by_id(roster, "memory_thief")
			_spawn_content_enemy(origin + Vector3(-3.5, 0.95, -5.0), memory_thief)
			_spawn_content_enemy(origin + Vector3(3.5, 0.95, -8.0), memory_thief)
			_spawn_content_enemy(origin + Vector3(0.0, 0.95, -11.5), _chapter_enemy_by_id(roster, "echo_spirit"))
			var elite_02 := _chapter_elite_for(Chapter3ContentScript, level_id)
			if not elite_02.is_empty():
				_spawn_content_enemy(origin + Vector3(0.0, 1.0, -16.0), elite_02)
		&"level_03_03":
			# 狐嫁道：嫁衣女鬼 + 水月灵 + 狐火灯
			_spawn_content_enemy(origin + Vector3(-3.5, 0.95, -6.0), _chapter_enemy_by_id(roster, "wedding_gown_ghost"))
			_spawn_content_enemy(origin + Vector3(3.5, 0.95, -9.0), _chapter_enemy_by_id(roster, "water_moon_spirit"))
			_spawn_content_enemy(origin + Vector3(0.0, 0.95, -13.0), _chapter_enemy_by_id(roster, "foxfire_lantern"))
			var elite_03 := _chapter_elite_for(Chapter3ContentScript, level_id)
			if not elite_03.is_empty():
				_spawn_content_enemy(origin + Vector3(0.0, 1.0, -17.0), elite_03)
		&"level_03_04":
			# 镜花水月亭：岸边镜花精 ×2、真实石路水月灵 ×3、湖后精英与供茶支线。
			var mirror_flower := _chapter_enemy_by_id(roster, "mirror_flower_spirit")
			_spawn_content_enemy(origin + Vector3(-3.5, 0.95, -6.0), mirror_flower)
			_spawn_content_enemy(origin + Vector3(3.5, 0.95, -9.0), mirror_flower)
			for index in 3:
				_spawn_content_enemy(origin + Vector3(-3.0 + index * 3.0, .95, -12.0 - index * 3.0), _chapter_enemy_by_id(roster, "water_moon_spirit"))
			var elite_04 := _chapter_elite_for(Chapter3ContentScript, level_id)
			if not elite_04.is_empty():
				_spawn_content_enemy(origin + Vector3(0.0, 1.0, -16.0), elite_04)
			# 支线·桥头的供茶：潜伏的贪烬鬼（以情为饵的真凶，appears_in 同 level_03_04，按 id 单独取）
			var greed_ghost := _chapter_elite_by_id(Chapter3ContentScript, "elite_ember_greed_ghost")
			if not greed_ghost.is_empty():
				_spawn_content_enemy(origin + Vector3(0.0, 1.0, -20.0), greed_ghost)
			_spawn_tea_offering(origin + Vector3(4.0, 1.1, -13.0))
			_spawn_bridge_tea_npc(origin + Vector3(-4.0, 0.0, -13.0))
			# 可选 Boss 隐藏入口：桥头侧道通往无目钟塔
			_spawn_bell_tower_entrance(origin + Vector3(5.5, 1.1, -17.0))
		&"level_03_05":
			# 九尾迷宫：迷宫守卫 + 迷心狐妖 ×2 + 精英·迷宫诗人
			_spawn_content_enemy(origin + Vector3(-3.0, 0.95, -6.0), _chapter_enemy_by_id(roster, "maze_guardian"))
			var fox_demon := _chapter_enemy_by_id(roster, "mind_lost_fox_demon")
			_spawn_content_enemy(origin + Vector3(3.0, 0.95, -10.0), fox_demon)
			_spawn_content_enemy(origin + Vector3(0.0, 0.95, -14.0), fox_demon)
			var elite_05 := _chapter_elite_for(Chapter3ContentScript, level_id)
			if not elite_05.is_empty():
				_spawn_content_enemy(origin + Vector3(0.0, 1.0, -17.0), elite_05)
		&"level_03_06":
			# 月华台：仅 Boss 玉面狐·九尾
			guardian = _spawn_content_enemy(origin + Vector3(0.0, 1.15, -18.0), Chapter3ContentScript.boss(), true)
		_:
			_spawn_content_enemy(origin + Vector3(-3.0, 0.95, -6.0), roster[0])
			_spawn_content_enemy(origin + Vector3(3.0, 0.95, -10.0), roster[min(1, roster.size() - 1)])


func _spawn_chapter4_encounters(origin: Vector3, level_id: StringName) -> void:
	# 第四章·天崩陨落：登天梯 → 炼丹云台 → 藏经阁 → 嗔念台 → 执念台 → 天顶真身
	var roster: Array[Dictionary] = Chapter4ContentScript.enemies()
	if roster.is_empty():
		return
	match level_id:
		&"level_04_01":
			# 登天梯：天梯守灵 ×2 + 云天鹰 + 精英·云桥守将
			var stair_guard := _chapter_enemy_by_id(roster, "stairway_guard_wraith")
			_spawn_content_enemy(origin + Vector3(-3.5, 0.95, -6.0), stair_guard)
			_spawn_content_enemy(origin + Vector3(3.5, 0.95, -9.0), stair_guard)
			_spawn_content_enemy(origin + Vector3(0.0, 0.95, -13.0), _chapter_enemy_by_id(roster, "cloud_sky_eagle"))
			var elite_01 := _chapter_elite_for(Chapter4ContentScript, level_id)
			if not elite_01.is_empty():
				_spawn_content_enemy(origin + Vector3(0.0, 1.0, -17.0), elite_01)
		&"level_04_02":
			# 炼丹云台：丹炉精 + 丹堕仙 + 精英·坠天工匠
			_spawn_content_enemy(origin + Vector3(-3.5, 0.95, -6.0), _chapter_enemy_by_id(roster, "elixir_furnace_spirit"))
			_spawn_content_enemy(origin + Vector3(3.5, 0.95, -9.0), _chapter_enemy_by_id(roster, "alchemy_fallen_immortal"))
			var elite_02 := _chapter_elite_for(Chapter4ContentScript, level_id)
			if not elite_02.is_empty():
				_spawn_content_enemy(origin + Vector3(0.0, 1.0, -13.0), elite_02)
		&"level_04_03":
			# 藏经阁：书精 ×2 + 藏书守护灵 + 精英·经文守卫
			var book_spirit := _chapter_enemy_by_id(roster, "book_spirit")
			_spawn_content_enemy(origin + Vector3(-3.5, 0.95, -6.0), book_spirit)
			_spawn_content_enemy(origin + Vector3(3.5, 0.95, -9.0), book_spirit)
			_spawn_content_enemy(origin + Vector3(0.0, 0.95, -12.5), _chapter_enemy_by_id(roster, "library_guardian_spirit"))
			var elite_03 := _chapter_elite_for(Chapter4ContentScript, level_id)
			if not elite_03.is_empty():
				_spawn_content_enemy(origin + Vector3(0.0, 1.0, -16.0), elite_03)
		&"level_04_04":
			# 嗔念台：仅 Boss 玄霄·嗔念（副 Boss）
			guardian = _spawn_content_enemy(origin + Vector3(0.0, 1.15, -18.0), _chapter4_boss_by_id("boss_xuan_xiao_wrath"), true)
		&"level_04_05":
			# 执念台：仅 Boss 玄霄·执念（副 Boss）
			guardian = _spawn_content_enemy(origin + Vector3(0.0, 1.15, -18.0), _chapter4_boss_by_id("boss_xuan_xiao_obsession"), true)
		&"level_04_06":
			# 天顶·真身：仅 Boss 堕仙·玄霄
			guardian = _spawn_content_enemy(origin + Vector3(0.0, 1.15, -18.0), _chapter4_boss_by_id("boss_xuan_xiao"), true)
		_:
			_spawn_content_enemy(origin + Vector3(-3.0, 0.95, -6.0), roster[0])
			_spawn_content_enemy(origin + Vector3(3.0, 0.95, -10.0), roster[min(1, roster.size() - 1)])


## 第四章 bosses() 为数组：按 id 取子 Boss
func _chapter4_boss_by_id(id: String) -> Dictionary:
	for boss in Chapter4ContentScript.bosses():
		if String(boss.get("id", "")) == id:
			return boss
	return {}


func _spawn_chapter5_encounters(origin: Vector3, level_id: StringName) -> void:
	# 第五章·烬座归墟：烬海之岸 → 倒悬殿 → 轮回歧路 → 九铸魂者之墓 → 烬座·烛阴之缚
	var roster: Array[Dictionary] = Chapter5ContentScript.enemies()
	if roster.is_empty():
		return
	match level_id:
		&"level_05_01":
			# 烬海之岸：烬岸浮游灵 ×2 + 烬蝠 ×2
			var drifter := _chapter_enemy_by_id(roster, "ember_shore_drifter")
			_spawn_content_enemy(origin + Vector3(-3.5, 0.95, -6.0), drifter)
			_spawn_content_enemy(origin + Vector3(3.5, 0.95, -9.0), drifter)
			var ember_bat := _chapter_enemy_by_id(roster, "ember_bat")
			_spawn_content_enemy(origin + Vector3(-2.0, 0.95, -12.0), ember_bat)
			_spawn_content_enemy(origin + Vector3(2.0, 0.95, -13.0), ember_bat)
			var elite_01 := _chapter_elite_for(Chapter5ContentScript, level_id)
			if not elite_01.is_empty():
				_spawn_content_enemy(origin + Vector3(0.0, 1.0, -16.0), elite_01)
			_spawn_furnace_memory(origin + Vector3(-2.5, 1.1, -8.0), "furnace_memory_1")
		&"level_05_02":
			# 倒悬殿：倒悬卫士 ×2 + 精英·逆熵化身
			var inverted := _chapter_enemy_by_id(roster, "inverted_guardian")
			_spawn_content_enemy(origin + Vector3(-3.5, 0.95, -6.0), inverted)
			_spawn_content_enemy(origin + Vector3(3.5, 0.95, -9.0), inverted)
			var elite_02 := _chapter_elite_for(Chapter5ContentScript, level_id)
			if not elite_02.is_empty():
				_spawn_content_enemy(origin + Vector3(0.0, 1.0, -13.0), elite_02)
			_spawn_furnace_memory(origin + Vector3(3.0, 1.1, -10.0), "furnace_memory_2")
		&"level_05_03":
			# 轮回歧路：歧路影 ×2 + 可能性之影 + 精英·可能性之海
			var shade := _chapter_enemy_by_id(roster, "forked_path_shade")
			_spawn_content_enemy(origin + Vector3(-3.5, 0.95, -6.0), shade)
			_spawn_content_enemy(origin + Vector3(3.5, 0.95, -9.0), shade)
			_spawn_content_enemy(origin + Vector3(0.0, 0.95, -13.0), _chapter_enemy_by_id(roster, "shadow_of_possibility"))
			var elite_03 := _chapter_elite_for(Chapter5ContentScript, level_id)
			if not elite_03.is_empty():
				_spawn_content_enemy(origin + Vector3(0.0, 1.0, -16.0), elite_03)
			_spawn_furnace_memory(origin + Vector3(0.0, 1.1, -9.0), "furnace_memory_3")
			_spawn_samsara_review(origin + Vector3(0.0, 1.1, -4.0))
		&"level_05_04":
			# 九铸魂者之墓：铸魂者残影 ×2 + 精英·最后的烛阴侍者
			var remnant := _chapter_enemy_by_id(roster, "soul_forger_remnant")
			_spawn_content_enemy(origin + Vector3(-3.5, 0.95, -6.0), remnant)
			_spawn_content_enemy(origin + Vector3(3.5, 0.95, -9.0), remnant)
			var elite_04 := _chapter_elite_for(Chapter5ContentScript, level_id)
			if not elite_04.is_empty():
				_spawn_content_enemy(origin + Vector3(0.0, 1.0, -13.0), elite_04)
			_spawn_furnace_memory(origin + Vector3(-3.0, 1.1, -12.0), "furnace_memory_4")
			_spawn_soul_forger_communion(origin + Vector3(0.0, 1.1, -5.0))
		&"level_05_05":
			# 烬座·烛阴之缚：仅 Boss 烬渊之主·烛阴
			guardian = _spawn_content_enemy(origin + Vector3(0.0, 1.15, -18.0), Chapter5ContentScript.boss(), true)
		&"level_05_06":
			# 无目钟塔：仅可选 Boss 盲钟·听烬（致死，无命运覆盖）
			guardian = _spawn_content_enemy(origin + Vector3(0.0, 1.15, -18.0), OptionalBossContentScript.boss(), true)
		_:
			_spawn_content_enemy(origin + Vector3(-3.0, 0.95, -6.0), roster[0])
			_spawn_content_enemy(origin + Vector3(3.0, 0.95, -10.0), roster[min(1, roster.size() - 1)])


func _spawn_content_enemy(spawn_position: Vector3, content: Dictionary, is_guardian := false):
	# 用章节内容生成敌人
	if is_guardian and campaign_runtime.current_level.has_meta("boss_spawn"):
		spawn_position = to_local(campaign_runtime.current_level.to_global(campaign_runtime.current_level.get_meta("boss_spawn")))
	var payload := content.duplicate(true)
	if is_guardian and not payload.has("body_type"):
		match String(payload.get("id", "")):
			"boss_xing_tian":
				# 血将军·刑天：重甲精英体型 + 双斧（工厂未注册 guandao 形状，双斧为可用近似）
				payload["body_type"] = "elite_armored"
				payload["weapon_shape"] = payload.get("weapon_shape", "blood_axe")
				payload["body_color"] = payload.get("body_color", "2a1515")
				payload["weapon_color"] = payload.get("weapon_color", "8a2a1a")
				payload["eye_emission"] = payload.get("eye_emission", "ff3300")
			"boss_nine_tails":
				# 玉面狐·九尾：兽型体型 + 狐爪
				payload["body_type"] = "beast_humanoid"
				payload["weapon_shape"] = payload.get("weapon_shape", "fox_claw")
				payload["body_color"] = payload.get("body_color", "88ccaa")
				payload["weapon_color"] = payload.get("weapon_color", "66ffcc")
				payload["eye_emission"] = payload.get("eye_emission", "00ffcc")
			"boss_xuan_xiao_wrath":
				# 嗔念：天界守卫 + 云戟
				payload["body_type"] = "celestial_guard"
				payload["weapon_shape"] = payload.get("weapon_shape", "cloud_glaive")
				payload["body_color"] = payload.get("body_color", "aa4422")
				payload["weapon_color"] = payload.get("weapon_color", "ff8844")
				payload["eye_emission"] = payload.get("eye_emission", "ff2200")
			"boss_xuan_xiao_obsession":
				# 执念：袍服施法者 + 炼丹剑
				payload["body_type"] = "robed_caster"
				payload["weapon_shape"] = payload.get("weapon_shape", "alchemy_sword")
				payload["body_color"] = payload.get("body_color", "4488aa")
				payload["weapon_color"] = payload.get("weapon_color", "88ccff")
				payload["eye_emission"] = payload.get("eye_emission", "4499ff")
			"boss_xuan_xiao":
				# 堕仙·玄霄：天界守卫 + 天剑
				payload["body_type"] = "celestial_guard"
				payload["weapon_shape"] = payload.get("weapon_shape", "celestial_sword")
				payload["body_color"] = payload.get("body_color", "eeddcc")
				payload["weapon_color"] = payload.get("weapon_color", "ffddaa")
				payload["eye_emission"] = payload.get("eye_emission", "ffdd44")
			"boss_zhu_yin":
				# 烬渊之主·烛阴：古巨体型 + 魂锤（龙形近似）
				payload["body_type"] = "ancient_giant"
				payload["weapon_shape"] = payload.get("weapon_shape", "soul_hammer")
				payload["body_color"] = payload.get("body_color", "1a1a2a")
				payload["weapon_color"] = payload.get("weapon_color", "553322")
				payload["eye_emission"] = payload.get("eye_emission", "ff4422")
			"boss_blind_bell":
				# 盲钟·听烬：悬垂青铜编钟 + 钟舌（内容表已含 body_type，此支为兜底）
				payload["body_type"] = "hanging_bell"
				payload["weapon_shape"] = payload.get("weapon_shape", "bell_tongue")
				payload["body_color"] = payload.get("body_color", "7a6a4a")
				payload["weapon_color"] = payload.get("weapon_color", "c8a050")
				payload["eye_emission"] = payload.get("eye_emission", "ffcc44")
			_:
				payload["body_type"] = "armored_medium"
				payload["weapon_shape"] = payload.get("weapon_shape", "temple_halberd")
				payload["body_color"] = payload.get("body_color", "2a2820")
				payload["weapon_color"] = payload.get("weapon_color", "5a5040")
				payload["eye_emission"] = payload.get("eye_emission", "ff5518")
	var enemy = EnemyScene.instantiate()
	enemy.name = String(payload.get("id", "ChapterEnemy"))
	enemy.position = spawn_position
	enemy.setup_from_content(self, player, audio, spawn_position, payload, is_guardian)
	var body_radius := float(enemy.chapter_content.get("body_radius", 0.6))
	var feet_clearance := maxf(0.05, float(enemy.chapter_content.get("body_height", 1.9)) * 0.5
		- float(enemy.chapter_content.get("body_y", 0.95)) + 0.05)
	enemy.position = _supported_campaign_position(spawn_position, body_radius, feet_clearance)
	enemy.spawn_origin = enemy.position
	_wire_enemy_signals(enemy)
	add_child(enemy)
	enemies.append(enemy)
	_attach_boss_flow(enemy, payload)
	if is_guardian:
		_setup_boss_arena(enemy)
	return enemy


## L-26：守卫 Boss 入场——场地导演建塌陷环 + 药罐，相变时联动塌陷
func _setup_boss_arena(boss_enemy) -> void:
	if _arena_director != null and is_instance_valid(_arena_director):
		_arena_director.queue_free()
	_arena_director = ArenaDirectorScript.new()
	_arena_director.name = "ArenaDirector"
	var level_root := campaign_runtime.current_level
	level_root.add_child(_arena_director)
	_arena_director.setup(level_root)
	_arena_director.set_trauma_shake(_trauma_shake)
	_arena_director.navigation_changed.connect(request_navigation_refresh.bind(level_root))
	var center: Vector3 = level_root.to_global(level_root.get_meta("boss_arena_center", level_root.to_local(boss_enemy.global_position)))
	var radius := float(level_root.get_meta("boss_arena_radius", 12.0))
	_arena_director.build_arena(center, {"boss": boss_enemy, "floor_y": center.y,
		"ring_radius": maxf(5.0, radius * 0.7), "arena_radius": radius})
	_boss_boundary = BossEncounterBoundaryScript.new()
	_boss_boundary.name = "BossEncounterBoundary"
	level_root.add_child(_boss_boundary)
	_boss_boundary.setup(boss_enemy, player, center, radius)
	_boss_boundary.navigation_changed.connect(request_navigation_refresh.bind(level_root))
	if _arena_director.has_method("bind_encounter"):
		_arena_director.bind_encounter(_boss_boundary)
	if _arena_director.has_method("can_begin_encounter"):
		_boss_boundary.admission_check = Callable(_arena_director, "can_begin_encounter")
		_boss_boundary.admission_denied = Callable(_arena_director, "on_entry_denied")
	var flow_host: Node = boss_enemy.get_node_or_null("BossFlowController")
	if flow_host != null and flow_host.has_method("bind_encounter"):
		flow_host.bind_encounter(_boss_boundary)
	_wire_destructible_rewards()


## P0-2：把内容 dict 的可选 "flow" 专属流程挂到 boss 上（BossFlowController 主机）。
## 无 flow 字段 / script 无效时零行为改变，现有 Boss 完全不受影响。
func _attach_boss_flow(enemy, content: Dictionary) -> void:
	var raw_flow: Variant = content.get("flow")
	if not raw_flow is Dictionary:
		return
	var flow: Dictionary = raw_flow
	var script_path := String(flow.get("script", ""))
	if script_path.is_empty() or not ResourceLoader.exists(script_path):
		return
	var controller = BossFlowControllerScript.new()
	controller.name = "BossFlowController"
	enemy.add_child(controller)
	controller.attach(enemy, content)


func _wire_enemy_signals(enemy) -> void:
	enemy.defeated.connect(_on_enemy_defeated)
	enemy.engagement_changed.connect(_on_enemy_engagement_changed)
	enemy.health_changed.connect(_on_guardian_health_changed.bind(enemy))
	if enemy.has_signal("execution_break_changed"):
		enemy.execution_break_changed.connect(_on_execution_break_changed.bind(enemy))
	if enemy.has_signal("story_threshold_reached"):
		enemy.story_threshold_reached.connect(_on_boss_story_threshold.bind(enemy))
	if enemy.has_signal("weak_point_exposed"):
		enemy.weak_point_exposed.connect(_on_boss_weak_point_exposed)
	if enemy.has_signal("grab_started"):
		enemy.grab_started.connect(_on_boss_grab_started.bind(enemy))
	if enemy.has_signal("phase_changed"):
		enemy.phase_changed.connect(_on_boss_phase_changed)


func _on_campaign_exit_requested(from_level_id: StringName) -> void:
	# 出口交互 → 推进下一关并记完成
	if _level_transition_locked:
		return
	var mechanisms := _story_mechanisms()
	if mechanisms != null:
		var reason: String = mechanisms.exit_block_reason()
		if not reason.is_empty():
			hud.show_message(reason, 3.0)
			return
	if _boss_aftermath_pending:
		hud.show_message(HudThemeScript.copy("先穿过正在坠落的断桥", "Cross the falling causeway first"), 2.5)
		return
	var boss_id := _current_boss_id()
	if not boss_id.is_empty() and not _is_boss_defeated(boss_id):
		hud.show_message(HudThemeScript.copy("守护者的裁决尚未结束", "The guardian's judgement is unfinished"), 2.5)
		return
	var current_id := from_level_id
	if current_id.is_empty() and campaign_runtime != null:
		current_id = campaign_runtime.current_level_id
	var next_level: Dictionary = campaign_runtime.registry.get_next_level(current_id) if campaign_runtime != null else {}
	if next_level.is_empty():
		# 可选隐藏 Boss 关（无下一关）→ 返回入口所在关卡，而不是误入终局尾声。
		var return_level := ""
		if campaign_runtime != null:
			return_level = String(campaign_runtime.get_level_data().get("return_level_id", ""))
		if not return_level.is_empty():
			_travel_to_level(return_level)
			return
		_show_ending_epilogue()
		return
	_level_transition_locked = true
	var completed := String(current_id)
	if completed not in run_state.completed_levels:
		run_state.completed_levels.append(completed)
	var next_id := StringName(next_level.get("id", &""))
	hud.show_message(LocalizationScript.text("THE SEAL OPENS\n%s") % String(next_level.get("display_name", "")), 2.2)
	audio.play_cue("rest", -6.0, 0.85)
	if not _load_campaign_level(next_id):
		_level_transition_locked = false
		return
	run_state.level_id = String(campaign_runtime.current_level_id)
	run_state.chapter_id = String(campaign_runtime.get_level_data().get("chapter_id", run_state.chapter_id))
	_save_run("level_advanced")
	_level_transition_locked = false


## 终局：走完 5-5 出口且无下一关时，读回 ending_state 显示分结局尾声（替代 "THE PATH ENDS HERE"）。
func _show_ending_epilogue() -> void:
	var ending_id := EndingResolverScript.resolve(run_state)
	if ending_id == EndingResolverScript.ENDING_NONE:
		hud.show_message(LocalizationScript.text("THE PATH ENDS HERE"), 2.0)
		return
	var data := DialogueRunnerScript.ending_epilogue(ending_id, run_state)
	if hud != null and hud.has_method("show_epilogue"):
		hud.show_epilogue(data)


func _on_epilogue_finished() -> void:
	# 尾声「返回标题」→ 重载主场景回到标题。
	get_tree().reload_current_scene()


func _supported_campaign_position(candidate: Vector3, radius := 0.6, clearance := 0.05) -> Vector3:
	if campaign_runtime == null or campaign_runtime.current_level == null:
		return candidate
	var level_root := campaign_runtime.current_level
	var navigation := level_root.get_node_or_null("NavigationSurface")
	if navigation == null:
		return candidate
	var local_candidate := level_root.to_local(to_global(candidate))
	var supported := CampaignLevelRuntimeScript.Builder.supported_spawn(
		navigation.get_meta("walkable_cells", []), local_candidate, radius, clearance)
	return to_local(level_root.to_global(supported))


func _spawn_enemy(spawn_position: Vector3, is_guardian: bool, enemy_type = -1):
	var enemy = EnemyScene.instantiate()
	enemy.name = "HollowSentinel" if not is_guardian else "CinderGuardian"
	enemy.position = spawn_position
	var type_arg := enemy_type as int
	if type_arg >= 0:
		enemy.setup(self, player, audio, spawn_position, is_guardian, type_arg)
	else:
		enemy.setup(self, player, audio, spawn_position, is_guardian)
	_wire_enemy_signals(enemy)
	add_child(enemy)
	enemies.append(enemy)
	return enemy


func rest_at_checkpoint(shrine: Node3D, _interacting_player: Node = null) -> void:
	if _boss_aftermath_pending or is_instance_valid(_pending_fate_boss) or (is_instance_valid(_boss_boundary) and _boss_boundary.combat_is_active()):
		hud.show_message(HudThemeScript.copy("当前遭遇结束后才能休息", "Finish the encounter before resting"), 2.0)
		return
	var mechanisms := _story_mechanisms()
	if mechanisms != null and not String(mechanisms.trial_mode).is_empty():
		hud.show_message(HudThemeScript.copy("试炼仍在进行", "The trial is still in progress"), 2.0)
		return
	respawn_position = _resolve_respawn_position(shrine.global_position + Vector3(0.0, 1.1, 2.0))
	var level_data := campaign_runtime.get_level_data() if campaign_runtime != null else {}
	run_state.checkpoint_id = String(level_data.get("checkpoint_id", "ember_shrine"))
	player.heal_full()
	_try_shrine_upgrade()
	_try_dao_upgrade()
	_try_vessel_upgrade()
	_try_meridian_upgrade()
	for enemy in enemies:
		if _can_reset_enemy(enemy):
			enemy.reset_enemy()
	if _phase_polisher != null:
		_phase_polisher.reset()
	if _phase_environment != null:
		_phase_environment.restore_defaults()
	audio.play_cue("rest", -4.0)
	hud.show_message(LocalizationScript.text("EMBER RESTORED\nEnemies return to the hollow."), 2.5)
	_save_run("checkpoint_rest")
	# L-12：第二章起且已有其他已激活祠堂时，休息后弹出快速旅行菜单；
	# 否则（无传送目的地）打开背包/图鉴菜单
	_open_fast_travel_if_available()
	_open_inventory()


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


## L-15：道行升级 —— 每级 +5 HP / +1 耐力 / +1 灵蕴（恢复至新上限）+ 1 天赋点
func _try_dao_upgrade() -> void:
	if player == null or run_state == null:
		return
	var cost := _dao_upgrade_cost()
	if cost < 0:
		hud.show_message(LocalizationScript.text("DAO ASCENSION: cultivation is complete"), 2.0)
		return
	if player.embers < cost:
		hud.show_message(
			LocalizationScript.text("DAO ASCENSION: need %d embers (next Lv%d)") % [cost, _dao_level() + 1],
			2.0
		)
		return
	player.embers -= cost
	player.embers_changed.emit(player.embers)
	var new_level := _dao_level() + 1
	run_state.progression_values["dao_level"] = new_level
	# "+1 per level" 效果：存档侧天赋点（供未来天赋树系统消费）
	run_state.progression_values["talent_points"] = int(run_state.progression_values.get("talent_points", 0)) + 1
	_apply_progression_stats()
	hud.show_message(
		LocalizationScript.text("DAO ASCENSION LV%d  +5 HP +1 STA +1 FOC +1 TALENT") % new_level,
		2.5
	)
	audio.play_cue("recover", -5.0, 0.7)
	_save_run("dao_upgrade")


## L-15：魂器强化 —— 五阶永久加成（+1..+5），花费递增烬
func _try_vessel_upgrade() -> void:
	if player == null or run_state == null:
		return
	var level := int(run_state.progression_values.get("vessel_level", 0))
	if level >= VESSEL_COSTS.size():
		hud.show_message(LocalizationScript.text("SOUL VESSEL: reinforcement is complete"), 2.0)
		return
	var cost: int = VESSEL_COSTS[level]
	if player.embers < cost:
		hud.show_message(
			LocalizationScript.text("SOUL VESSEL: need %d embers for +%d") % [cost, level + 1],
			2.0
		)
		return
	player.embers -= cost
	player.embers_changed.emit(player.embers)
	var new_level := level + 1
	run_state.progression_values["vessel_level"] = new_level
	_apply_progression_stats()
	var bound := _vessel_stats_for(new_level)
	hud.show_message(
		LocalizationScript.text("SOUL VESSEL +%d  (+%d HP +%d STA +%d FOC)") % [
			new_level,
			int(bound.get("max_health", 0.0)),
			int(bound.get("max_stamina", 0.0)),
			int(bound.get("max_focus", 0.0)),
		],
		2.5
	)
	audio.play_cue("recover", -5.0, 0.7)
	_save_run("vessel_upgraded")


func _dao_level() -> int:
	if run_state == null:
		return 0
	return int(run_state.progression_values.get("dao_level", 0))


## 道行下一级花费：目标等级 ×100 烬；60 级后 ×3
func _dao_upgrade_cost() -> int:
	var level := _dao_level()
	if level >= DAO_MAX_LEVEL:
		return -1
	var cost := (level + 1) * 100
	if level + 1 > DAO_SOFT_CAP:
		cost *= 3
	return cost


func _dao_stats_for(level: int) -> Dictionary:
	return {"max_health": float(level * 5), "max_stamina": float(level), "max_focus": float(level)}


## 魂器各阶累计加成（VESSEL_TIER_BONUSES 为增量，此处汇总到指定等级）
func _vessel_stats_for(level: int) -> Dictionary:
	var hp := 0.0
	var stamina := 0.0
	var focus := 0.0
	var tier_count := mini(level, VESSEL_TIER_BONUSES.size())
	for tier in range(tier_count):
		var bonus: Dictionary = VESSEL_TIER_BONUSES[tier]
		hp += float(bonus.get("max_health", 0.0))
		stamina += float(bonus.get("max_stamina", 0.0))
		focus += float(bonus.get("max_focus", 0.0))
	return {"max_health": hp, "max_stamina": stamina, "max_focus": focus}


func _accumulate_stats(target: Dictionary, source: Dictionary) -> void:
	for key in source:
		target[key] = float(target.get(key, 0.0)) + float(source[key])


## L-15：把道行/魂器加成幂等地应用到玩家（存档等级是权威；增量=目标-已应用）。
## 在 _apply_run_state 装载旧档、以及每次升级后调用。
func _apply_progression_stats() -> void:
	if player == null or not is_instance_valid(player) or run_state == null:
		return
	var dao_level := int(run_state.progression_values.get("dao_level", 0))
	var vessel_level := int(run_state.progression_values.get("vessel_level", 0))
	var applied := _dao_stats_for(_applied_dao_level)
	_accumulate_stats(applied, _vessel_stats_for(_applied_vessel_level))
	var desired := _dao_stats_for(dao_level)
	_accumulate_stats(desired, _vessel_stats_for(vessel_level))
	var hp_delta := float(desired.get("max_health", 0.0)) - float(applied.get("max_health", 0.0))
	var stamina_delta := float(desired.get("max_stamina", 0.0)) - float(applied.get("max_stamina", 0.0))
	var focus_delta := float(desired.get("max_focus", 0.0)) - float(applied.get("max_focus", 0.0))
	_applied_dao_level = dao_level
	_applied_vessel_level = vessel_level
	if (
		is_zero_approx(hp_delta)
		and is_zero_approx(stamina_delta)
		and is_zero_approx(focus_delta)
	):
		return
	player.max_health += hp_delta
	player.max_stamina += stamina_delta
	player.max_focus += focus_delta
	# 恢复当前值至新上限
	player.health = minf(player.health + hp_delta, player.max_health)
	player.stamina = minf(player.stamina + stamina_delta, player.max_stamina)
	player.focus = minf(player.focus + focus_delta, player.max_focus)
	if player.has_method("_emit_stats"):
		player._emit_stats()
	if player.has_method("_emit_focus"):
		player._emit_focus()
	# L-09：与道行/魂器平行，幂等应用经脉等级
	_apply_meridian_stats()


func _on_checkpoint_activated(_shrine: Node, _interacting_player: Node) -> void:
	var level_data := campaign_runtime.get_level_data() if campaign_runtime != null else {}
	var checkpoint_id := String(level_data.get("checkpoint_id", "ember_shrine"))
	run_state.checkpoint_id = checkpoint_id
	# L-12：点亮即登记为可传送点（保存侧 _sync_compatibility_fields 也会补登记，这里显式记录）
	if checkpoint_id not in run_state.activated_checkpoints:
		run_state.activated_checkpoints.append(checkpoint_id)
	_save_run("checkpoint_activated")


func _on_checkpoint_rested(shrine: Node, interacting_player: Node) -> void:
	rest_at_checkpoint(shrine, interacting_player)


## L-12：休息后若满足条件则弹出快速旅行菜单
func _open_fast_travel_if_available() -> void:
	if _fast_travel_overlay == null or _fast_travel_overlay.is_open():
		return
	if not _fast_travel_available():
		return
	if _fast_travel_overlay.open(
		_fast_travel_destinations(),
		String(campaign_runtime.current_level_id) if campaign_runtime != null else ""
	):
		audio.play_cue("rest", -6.0, 0.85)


## L-10：休息后打开背包/图鉴菜单（快速旅行菜单已弹出时跳过，避免模态重叠）
func _open_inventory() -> void:
	if _inventory_overlay == null or _inventory_overlay.is_open():
		return
	if _fast_travel_overlay != null and _fast_travel_overlay.is_open():
		return
	if _inventory_overlay.open(player, run_state):
		audio.play_cue("rest", -6.0, 0.8)


func _on_inventory_closed() -> void:
	# 背包关闭即恢复世界（若还有其它模态未关，其各自管理暂停态）
	if player != null and is_instance_valid(player) and player.has_method("_emit_stats"):
		player._emit_stats()


## L-09：烬龛经脉修炼 —— 自动尝试升级当前聚焦经脉；不可负担时轮转到下一个可升的经脉。
## 等级/费用存档在 run_state.progression_values["meridian_<id>"]，幂等应用安全。
func _try_meridian_upgrade() -> void:
	if player == null or run_state == null:
		return
	var order := MeridianDataScript.all_ids()
	if order.is_empty():
		return
	var focus_id := String(order[clampi(_meridian_focus, 0, order.size() - 1)])
	var check := MeridianSystemScript.can_upgrade(run_state.progression_values, focus_id, int(player.embers))
	if bool(check["ok"]):
		_complete_meridian_upgrade(focus_id)
		return
	# 当前聚焦不可升：扫描顺序，找到下一个可负担的经脉
	for meridian_id in order:
		if String(meridian_id) == focus_id:
			continue
		var alt_check := MeridianSystemScript.can_upgrade(
			run_state.progression_values, String(meridian_id), int(player.embers)
		)
		if bool(alt_check["ok"]):
			_meridian_focus = order.find(meridian_id)
			_complete_meridian_upgrade(String(meridian_id))
			return
	var next_cost := MeridianSystemScript.upgrade_cost(
		MeridianSystemScript.level_for(run_state.progression_values, focus_id)
	)
	if next_cost > 0:
		hud.show_message(LocalizationScript.text("MERIDIAN: need %d embers for %s") % [next_cost, focus_id], 2.0)
	else:
		hud.show_message(LocalizationScript.text("MERIDIAN TRAINING: complete"), 2.0)


## L-09：扣除费用并写入等级（调用方已校验可负担）
func _complete_meridian_upgrade(meridian_id: String) -> void:
	var level := MeridianSystemScript.level_for(run_state.progression_values, meridian_id)
	var cost := MeridianSystemScript.upgrade_cost(level)
	if cost < 0:
		return
	player.embers -= cost
	player.embers_changed.emit(player.embers)
	var new_level := MeridianSystemScript.upgrade(run_state.progression_values, meridian_id)
	_apply_meridian_stats()
	var mat := MeridianSystemScript.material_for(level)
	var msg := LocalizationScript.text("MERIDIAN %s LV%d  (%s)") % [
		meridian_id.to_upper(), new_level, String(mat.get("material_name", "")),
	]
	hud.show_message(msg, 2.5)
	audio.play_cue("recover", -5.0, 0.7)
	_save_run("meridian_upgrade")


## L-09：设置当前聚焦经脉（overlay/HUD 调用）；非法 id 返回 false
func set_meridian_focus(meridian_id: String) -> bool:
	var order := MeridianDataScript.all_ids()
	var index := order.find(meridian_id)
	if index < 0:
		return false
	_meridian_focus = index
	return true


## L-09：把存档经脉等级幂等应用到玩家（等级权威；与 _apply_progression_stats 平行）
func _apply_meridian_stats() -> void:
	if player == null or not is_instance_valid(player) or run_state == null:
		return
	if not player.has_method("apply_meridian_levels"):
		return
	player.apply_meridian_levels(_meridian_levels_from_state())


func _meridian_levels_from_state() -> Dictionary:
	var levels := {}
	if run_state == null:
		return levels
	for meridian in MeridianDataScript.all():
		var id := String(meridian["id"])
		levels[id] = MeridianSystemScript.level_for(run_state.progression_values, id)
	return levels


## L-12：第二章起开放跨烬龛传送（任一第二章及以后的祠堂点亮即可）
func _fast_travel_available() -> bool:
	if run_state == null:
		return false
	if not _has_reached_chapter_two():
		return false
	return _fast_travel_destinations().size() > 0


func _has_reached_chapter_two() -> bool:
	if run_state == null:
		return false
	for checkpoint_id in run_state.activated_checkpoints:
		var record := _level_record_for_checkpoint(checkpoint_id)
		var chapter_id := String(record.get("chapter_id", ""))
		if chapter_id.begins_with("chapter_"):
			var chapter_num := int(chapter_id.substr(8, 2))
			if chapter_num >= 2:
				return true
	return false


## L-12：构建传送目的地（已激活祠堂 → 关卡记录）
func _fast_travel_destinations() -> Array[Dictionary]:
	var destinations: Array[Dictionary] = []
	if run_state == null:
		return destinations
	var current_checkpoint := ""
	if campaign_runtime != null:
		current_checkpoint = String(campaign_runtime.get_level_data().get("checkpoint_id", ""))
	for checkpoint_id in run_state.activated_checkpoints:
		if checkpoint_id == current_checkpoint:
			continue
		var record := _level_record_for_checkpoint(checkpoint_id)
		if record.is_empty():
			continue
		destinations.append({
			"level_id": String(record.get("id", "")),
			"display_name": String(record.get("display_name", checkpoint_id)),
			"checkpoint_id": checkpoint_id,
		})
	return destinations


func _level_record_for_checkpoint(checkpoint_id: String) -> Dictionary:
	for record in CampaignContentScript.levels():
		if String(record.get("checkpoint_id", "")) == checkpoint_id:
			return record
	return {}


func _level_display_name(level_id: String) -> String:
	for record in CampaignContentScript.levels():
		if String(record.get("id", "")) == level_id:
			return String(record.get("display_name", level_id))
	return level_id


func _on_fast_travel_selected(level_id: String) -> void:
	_travel_to_level(level_id)


## L-12：跨烬龛传送 —— 直接重载目标关卡并保存
func _travel_to_level(level_id: String) -> void:
	if _level_transition_locked or level_id.is_empty():
		return
	if campaign_runtime == null or String(campaign_runtime.current_level_id) == level_id:
		return
	_level_transition_locked = true
	audio.play_cue("rest", -6.0, 0.85)
	hud.show_message(LocalizationScript.text("TRAVELING TO\n%s") % _level_display_name(level_id), 2.2)
	if not _load_campaign_level(StringName(level_id)):
		_level_transition_locked = false
		return
	run_state.level_id = String(campaign_runtime.current_level_id)
	run_state.chapter_id = String(campaign_runtime.get_level_data().get("chapter_id", run_state.chapter_id))
	var destination_checkpoint := String(campaign_runtime.get_level_data().get("checkpoint_id", run_state.checkpoint_id))
	run_state.checkpoint_id = destination_checkpoint
	if destination_checkpoint not in run_state.activated_checkpoints:
		run_state.activated_checkpoints.append(destination_checkpoint)
	_save_run("fast_travel")
	_level_transition_locked = false


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
	var level_at_death: Node = campaign_runtime.current_level
	var aftermath_at_death := _boss_aftermath_pending
	if is_instance_valid(_pending_fate_boss):
		_pending_fate_boss = null
		if _fate_overlay != null and _fate_overlay.is_open():
			_fate_overlay.close()
		if _camera_director != null:
			_camera_director.release()
	var lost_amount: int = int(player.lose_embers())
	if lost_echo != null and is_instance_valid(lost_echo):
		lost_echo.queue_free()
		lost_echo = null
	if lost_amount > 0:
		_spawn_lost_echo(lost_amount, death_position + Vector3.UP * 0.35)
		run_state.lost_echo_amount = lost_amount
		run_state.lost_echo_position = lost_echo.global_position
	_save_run("player_death")
	if not aftermath_at_death:
		for enemy in enemies:
			if _can_reset_enemy(enemy):
				enemy.reset_enemy()
		if _phase_polisher != null:
			_phase_polisher.reset()
		if _phase_environment != null:
			_phase_environment.restore_defaults()
	hud.show_death()
	await get_tree().create_timer(2.2).timeout
	if not is_instance_valid(level_at_death) or campaign_runtime.current_level != level_at_death:
		return
	if aftermath_at_death and _boss_aftermath_pending and is_instance_valid(_arena_director) and _arena_director.retry_aftermath():
		if is_instance_valid(lost_echo):
			lost_echo.global_position = player.global_position + Vector3(1., .35, 0)
			run_state.lost_echo_position = lost_echo.global_position
			_save_run("escape_echo_recovery")
		hud.clear_death()
		hud.show_message(HudThemeScript.copy("断桥再临 · 玄霄已解脱", "Return to the causeway · Xuan Xiao remains at rest"), 2.5)
		return
	respawn_position = _resolve_respawn_position(respawn_position)
	player.respawn_at(respawn_position)
	hud.clear_death()
	hud.show_message(LocalizationScript.text("RISE AGAIN"), 1.5)


func _spawn_lost_echo(amount: int, at: Vector3) -> void:
	if lost_echo != null and is_instance_valid(lost_echo):
		lost_echo.queue_free()
		lost_echo = null
	var safe_at := at
	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	if space != null:
		safe_at = SafePlacement.resolve_standing_position(space, at)
	lost_echo = LostEchoScene.instantiate()
	lost_echo.position = safe_at
	lost_echo.setup(amount, self)
	lost_echo.recovered.connect(_on_lost_echo_recovered)
	add_child(lost_echo)


func _resolve_respawn_position(candidate: Vector3) -> Vector3:
	# 祠堂/标记点重生前做地面投影
	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	if space == null:
		return candidate
	var exclude: Array[RID] = []
	if player != null and is_instance_valid(player):
		exclude.append(player.get_rid())
	return SafePlacement.resolve_standing_position(space, candidate, exclude)


func _on_enemy_defeated(enemy, reward: int, is_guardian: bool) -> void:
	if is_instance_valid(enemy) and bool(enemy.get_meta("story_trial_owned", false)):
		return
	if is_guardian and _is_boss_defeated(_boss_id_for_enemy(enemy)):
		return
	player.add_embers(reward)
	if is_guardian:
		var boss_id := _boss_id_for_enemy(enemy)
		# K-01：按"这只 Boss 自己的 id"判定，不再用跨关卡共享的全局 victory 位，
		# 否则第二章及以后的 Boss 会因为第一章 victory 已为 true 而无法触发胜利。
		if not _is_boss_defeated(boss_id):
			# L-10：首次胜出掉落其武器/神器（记入背包/图鉴），重复挑战不再重复入账
			_grant_loot(String(BOSS_LOOT_BY_ID.get(boss_id, "spirit_talisman")))
			if not boss_id.is_empty():
				run_state.defeated_bosses.append(boss_id)
			victory = true
			hud.hide_boss()
			hud.show_victory()
			audio.play_cue("victory", -2.0)
			# L-24/L-26：Boss 战后恢复环境基调并清场（塌陷环收尾）
			if _phase_environment != null:
				_phase_environment.restore_defaults()
			if _arena_director != null:
				_arena_director.on_boss_died()
			_save_run("guardian_defeated")
			# Boss 胜后解封并打开通往下一关出口
			_open_boss_victory_exit()
			call_deferred("_spawn_shrine_npc")
	else:
		hud.show_message(LocalizationScript.text("EMBER CLAIMED  +%d") % reward, 1.2)
		# L-10：精锐击败时确定性小概率掉落一件物品（同一精锐 → 同一次结果/同一掉落，扩充图鉴）
		var content_id := _enemy_content_id(enemy)
		if content_id == "elite_memory_eater":
			run_state.set_choice_flag("story_memory_thief_defeated", true)
			_save_run("memory_thief_defeated")
		if content_id.begins_with("elite") and not ELITE_LOOT_POOL.is_empty():
			var seed := absi(content_id.hash())
			if seed % 100 < 35:
				_grant_loot(ELITE_LOOT_POOL[seed % ELITE_LOOT_POOL.size()])


func _can_reset_enemy(enemy: Node) -> bool:
	if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
		return false
	if bool(enemy.get_meta("story_trial_owned", false)):
		return false
	return not bool(enemy.get("guardian")) or not _is_boss_defeated(_boss_id_for_enemy(enemy))


## 取当前关卡注册的 Boss id（非 Boss 关返回空串）
func _current_boss_id() -> String:
	if campaign_runtime == null:
		return ""
	return String(campaign_runtime.get_level_data().get("boss_id", ""))


## 某 Boss id 是否已记录在存档 defeated_bosses 中
func _is_boss_defeated(boss_id: String) -> bool:
	return not boss_id.is_empty() and boss_id in run_state.defeated_bosses


## 从敌人实例解析章节内容 Boss id；缺失章节内容时退回当前关注册 id（兼容旧哨兵 Boss）
func _boss_id_for_enemy(enemy) -> String:
	if enemy != null and is_instance_valid(enemy):
		if "chapter_content" in enemy:
			var content: Dictionary = enemy.chapter_content
			var id_from_content := String(content.get("id", ""))
			if not id_from_content.is_empty():
				return id_from_content
		if "content_id" in enemy and not String(enemy.content_id).is_empty():
			return String(enemy.content_id)
	return _current_boss_id()


## L-10：读取敌人的章节内容 id（无则返回空串）
func _enemy_content_id(enemy) -> String:
	if enemy != null and is_instance_valid(enemy) and "content_id" in enemy:
		return String(enemy.content_id)
	return ""


## L-10：把一件战利品记入背包（collected_loot 去重追加 + inventory 计数）
func _grant_loot(item_id: String) -> void:
	if run_state == null or item_id.is_empty():
		return
	if item_id not in run_state.collected_loot:
		run_state.collected_loot.append(item_id)
	run_state.inventory[item_id] = int(run_state.inventory.get(item_id, 0)) + 1


func _open_boss_victory_exit() -> void:
	if _boss_aftermath_pending:
		return
	# 解封竞技场并生成通往下一章的出口交互
	if _module_runtime != null:
		_module_runtime.release_arena_seals()
		_module_runtime.spawn_victory_exit(campaign_runtime.current_level if campaign_runtime else null)
	hud.show_message(LocalizationScript.text("THE SEAL OPENS\nPath to the next ruin"), 2.5)


func on_boss_escaped() -> void:
	# Legacy flow entry must obey the same actual route judgement as the course.
	if _boss_aftermath_pending and is_instance_valid(_arena_director):
		_arena_director.complete_aftermath()


func _boss_display_name(enemy) -> String:
	# Use the same locale-aware bilingual name selection as equipment.
	if enemy != null and is_instance_valid(enemy) and "chapter_content" in enemy:
		var content: Dictionary = enemy.chapter_content
		var display := String(content.get("display_name", ""))
		if not display.is_empty():
			return HudThemeScript.readable_name(display, game_settings.locale if game_settings != null else "")
	return LocalizationScript.text("CINDER GUARDIAN")


func _on_enemy_engagement_changed(enemy, is_guardian: bool, engaged: bool) -> void:
	if not is_guardian:
		return
	if engaged and enemy.is_targetable():
		hud.show_boss(_boss_display_name(enemy), enemy.health, enemy.max_health)
	else:
		hud.hide_boss()


func _on_guardian_health_changed(current: float, maximum: float, enemy) -> void:
	if enemy == guardian and is_instance_valid(enemy) and enemy.engaged:
		hud.show_boss(_boss_display_name(enemy), current, maximum)
		hud.update_execution_break(float(enemy.execution_break), float(enemy.max_execution_break))


func _on_execution_break_changed(current: float, maximum: float, enemy) -> void:
	if enemy == guardian and is_instance_valid(enemy) and enemy.engaged:
		hud.update_execution_break(current, maximum)


func _on_boss_story_threshold(story_flag: StringName, health_ratio: float, enemy = null) -> void:
	# 可选 Boss 兜底：空命运旗标永不可触发剧情冻结/命运覆盖（致死击杀）
	if String(story_flag).is_empty():
		return
	if not is_instance_valid(enemy) or enemy != guardian or health_ratio < 0.0:
		return
	if is_instance_valid(_arena_director) and _arena_director.has_method("defer_story_judgement"):
		if _arena_director.defer_story_judgement(story_flag):
			return
	start_boss_scene_judgement(enemy, story_flag)


func start_boss_scene_judgement(enemy: Node3D, story_flag: StringName) -> void:
	if enemy != guardian or not is_instance_valid(enemy) or enemy.boss_break_profile == null:
		return
	if StringName(enemy.boss_break_profile.story_flag) != story_flag or _is_boss_defeated(_boss_id_for_enemy(enemy)):
		return
	if enemy != null and is_instance_valid(enemy) and enemy.has_method("enter_story_resolution"):
		enemy.enter_story_resolution()
		_pending_fate_boss = enemy
	if is_instance_valid(_arena_director) and _arena_director.has_method("on_story_judgement"):
		if _arena_director.on_story_judgement(story_flag):
			if _camera_director != null:
				_camera_director.release()
			return
	if _camera_director != null:
		_camera_director.play_shot_id(&"fate_halfbody", enemy if enemy != null else guardian)
	if _fate_overlay != null and FateCatalog.entry_for_flag(story_flag).size() > 0:
		_fate_overlay.open_for_flag(story_flag)
		# L-04：烛阴终幕 —— 三真相齐备时追加隐藏结局"共铸新炉"
		if String(story_flag) == "ending_state" and run_state != null:
			if EndingResolverScript.reachable(run_state).has(&"forge"):
				_fate_overlay.add_extra_option(
					"forge", "共铸新炉", "三真相齐备——以双律重铸轮回之炉"
				)
	else:
		hud.show_message(LocalizationScript.text("FATE UNRESOLVED\n%s") % String(story_flag), 2.0)


func _on_fate_choice_made(story_flag: StringName, value: String) -> void:
	# 5-3 轮回歧路：samsara 段旗独立处理（写旗 + 链式回放下一章），不落命运抉择闭环
	if String(story_flag).begins_with("samsara_stance_"):
		if run_state != null and run_state.has_method("set_choice_flag"):
			run_state.set_choice_flag(story_flag, value)
		_open_next_samsara()
		return
	if run_state != null and run_state.has_method("set_choice_flag"):
		run_state.set_choice_flag(story_flag, value)
	elif run_state != null:
		run_state.choice_flags[String(story_flag)] = value
	if String(story_flag) == "ending_state":
		EndingResolverScript.commit(run_state, StringName(value))
	# L-01：兑现 fate 选项承诺的即时效果（旗标 + 爆发增益等）
	_apply_fate_boon(story_flag, value)
	_save_run("fate_choice")
	if _camera_director != null:
		_camera_director.release()
	# L-01：命运抉择闭环 —— 非致死终结 Boss 并开出口（defeated 信号 → 奖励/存档/解封）
	if _pending_fate_boss != null and is_instance_valid(_pending_fate_boss):
		if is_instance_valid(_arena_director) and _arena_director.has_method("begin_aftermath"):
			_boss_aftermath_pending = _arena_director.begin_aftermath(StringName(value))
		if String(story_flag) == "ending_state":
			if guardian == _pending_fate_boss:
				run_state.guardian_defeated = true
		if _pending_fate_boss.has_method("conclude_story_fate"):
			_pending_fate_boss.conclude_story_fate()
		else:
			_pending_fate_boss.defeated.emit(
				_pending_fate_boss, _pending_fate_boss.reward, _pending_fate_boss.guardian
			)
	_pending_fate_boss = null
	if hud != null:
		hud.hide_boss()
	var fate: Dictionary = FateCatalog.entry_for_flag(story_flag)
	var choice_label := value
	for option: Dictionary in fate.get("options", []):
		if String(option.get("id", "")) == value:
			choice_label = String(option.get("label", value))
	hud.show_message("%s\n%s" % [String(fate.get("title", HudThemeScript.copy("裁决已定", "Judgement made"))), choice_label], 2.4)
	audio.play_cue("rest", -5.0, 0.9)


func has_story_item(item_id: String) -> bool:
	return run_state != null and int(run_state.inventory.get(item_id, 0)) > 0


func commit_boss_scene_action(boss: Node3D, flag: StringName, value: String, actor: Node3D, source: Node3D) -> bool:
	if not is_instance_valid(boss) or boss != guardian or boss != _pending_fate_boss or not boss.is_in_story_resolution():
		return false
	if actor != player or not is_instance_valid(source) or actor.global_position.distance_to(source.global_position) > 4.0:
		return false
	if not is_instance_valid(_arena_director) or not "story_props" in _arena_director:
		return false
	var props: Node = _arena_director.story_props
	if not is_instance_valid(props) or not (props == source or props.is_ancestor_of(source)):
		return false
	var action: Dictionary = source.get_meta("boss_scene_action", {})
	if String(action.get("flag", "")) != String(flag) or String(action.get("value", "")) != value:
		return false
	if boss.boss_break_profile == null or StringName(boss.boss_break_profile.story_flag) != flag:
		return false
	if flag == &"ending_state":
		if StringName(value) not in EndingResolverScript.reachable(run_state):
			return false
	elif not FateCatalog.is_valid_choice(flag, value):
		return false
	if flag == &"ch3_nine_tails_fate" and value == "redeemed" and not has_story_item("true_mirror"):
		return false
	_on_fate_choice_made(flag, value)
	return true


func finish_boss_aftermath(boss_id: String) -> void:
	if not _boss_aftermath_pending or boss_id != _current_boss_id() or not _is_boss_defeated(boss_id):
		return
	_boss_aftermath_pending = false
	run_state.set_choice_flag("aftermath_complete_" + boss_id, true)
	_save_run("boss_aftermath")
	_open_boss_victory_exit()
	var current := campaign_runtime.current_level
	var exit_area := current.find_child("VictoryExitInteract", true, false) as Area3D
	if exit_area == null:
		exit_area = current.find_child("GateExitInteract", true, false) as Area3D
	if exit_area != null:
		# The safe end of the collapsed causeway is the actual chapter exit.
		exit_area.global_position = player.global_position
		for shape: CollisionShape3D in exit_area.find_children("*", "CollisionShape3D", true, false):
			shape.position = Vector3.UP * 1.2
		LevelModuleVisuals.add_story_visual(exit_area, "memory_rings", _current_visual_theme())


func filter_boss_player_hit(payload: Dictionary) -> Dictionary:
	if is_instance_valid(_arena_director) and is_instance_valid(_boss_boundary) and _boss_boundary.combat_is_active():
		if _arena_director.has_method("filter_incoming_player_damage"):
			return _arena_director.filter_incoming_player_damage(payload)
	return payload


func filter_boss_incoming_hit(boss: Node, payload: Dictionary) -> Dictionary:
	if boss == guardian and is_instance_valid(_arena_director) and _arena_director.has_method("filter_incoming_boss_damage"):
		return _arena_director.filter_incoming_boss_damage(payload)
	return payload


## L-01：命运抉择副作用 —— 兑现 boss_fate_catalog 选项承诺。
## 即时型（刑天·吸收爆发增益、巨阙·保留终局防护）落地；其余写旗标供终章消费。
func _apply_fate_boon(story_flag: StringName, value: String) -> void:
	if run_state == null or player == null:
		return
	match String(story_flag):
		"ch1_guardian_fate":
			if value == "released":
				run_state.set_choice_flag("fate_remnant_trust", true)
				hud.show_message(LocalizationScript.text("REMNANTS HOLD YOU IN HIGH REGARD"), 2.0)
			elif value == "preserved":
				# 终局一次性防护：记录旗标 + 立即可用的一次格挡韧性保险
				run_state.set_choice_flag("fate_guardian_protection", true)
				if player.has_method("grant_fate_damage_boost"):
					player.grant_fate_damage_boost(1.0, 0.0)  # no-op 哨兵，仅防残留增益
				hud.show_message(LocalizationScript.text("A PROTECTION IS GRAVEN INTO YOUR SIGNET"), 2.0)
		"ch2_xingtian_fate":
			if value == "honored":
				run_state.set_choice_flag("fate_heroes_aid", true)
				hud.show_message(LocalizationScript.text("THE STANDS WILL AID YOU AT THE FINALE"), 2.0)
			elif value == "absorbed":
				# 爆发增益（+25% 伤害 30s）；烛阴更狂由终章 Boss 读取旗标
				run_state.set_choice_flag("fate_zhu_yin_wrath", true)
				if player.has_method("grant_fate_damage_boost"):
					player.grant_fate_damage_boost(1.25, 30.0)
				hud.show_message(LocalizationScript.text("BURST BOON +25%% DMG — ZHU YIN BURNS WILDER"), 2.2)
		"ch3_nine_tails_fate":
			if value == "redeemed":
				run_state.set_choice_flag("fate_safe_illusion", true)
				hud.show_message(LocalizationScript.text("A SAFE ILLUSION AWAITS IN THE SOUL STORM"), 2.0)
			elif value == "sealed":
				run_state.set_choice_flag("fate_dispel_illusion", true)
				hud.show_message(LocalizationScript.text("YOU MAY DISPEL ONE ILLUSION"), 2.0)
		"ch4_xuanxiao_fate":
			if value == "ascended":
				run_state.set_choice_flag("fate_gravity_boost", true)
				hud.show_message(LocalizationScript.text("GRAVITY MANIPULATION STRENGTHENED"), 2.0)
			elif value == "remembered":
				run_state.set_choice_flag("fate_zhu_yin_weakness", true)
				hud.show_message(LocalizationScript.text("THE REMNANT REVEALS ZHU YIN'S WEAKNESS"), 2.0)
		"bridge_tea_fate":
			# 支线·桥头的供茶：月圆之判落笔 → 完成支线，记录结局
			QuestStateScript.complete(run_state, QuestStateScript.QUEST_BRIDGE_TEA)
			if value == "exposed":
				run_state.set_choice_flag("bridge_tea_exposed", true)
				hud.show_message(LocalizationScript.text("真相抵岸：贪烬鬼现形，那杯茶终于被渡了过去"), 2.0)
				audio.play_cue("rest", -5.0, 0.9)
			elif value == "mob":
				run_state.set_choice_flag("bridge_tea_mob", true)
				hud.show_message(LocalizationScript.text("众怒如潮：茶魂被封，怒烬落入你手中"), 2.0)
				audio.play_cue("rest", -5.0, 0.9)


## L-05：烬龛旁按章节生成跨章 NPC（云游/铁心/忆姬/玄霄残识/寂灭）
const SHRINE_NPC_PRESETS := [
	{"npc_id": &"npc_cloud_wanderer", "prompt": "与云游交谈", "min_chapter": 1, "offset": Vector3(1.5, 0.0, 1.8)},
	{"npc_id": &"npc_iron_heart", "prompt": "与铁心交谈（锻造）", "min_chapter": 2, "offset": Vector3(-1.5, 0.0, 1.8)},
	{"npc_id": &"npc_lady_of_memories", "prompt": "与忆姬交谈", "min_chapter": 3, "offset": Vector3(1.5, 0.0, -1.8)},
	{"npc_id": &"npc_xuanxiao_remnant", "prompt": "与玄霄残识交谈", "min_chapter": 4, "offset": Vector3(-1.5, 0.0, -1.8)},
	{"npc_id": &"npc_silence_bringer", "prompt": "与寂灭交谈", "min_chapter": 5, "offset": Vector3(1.5, 0.0, -4.2)},
]

func _spawn_shrine_npc() -> void:
	# 先清旧 NPC，避免跨章残留
	for npc in _shrine_npcs:
		if is_instance_valid(npc):
			npc.queue_free()
	_shrine_npcs.clear()
	if campaign_runtime == null or run_state == null:
		return
	var base := _checkpoint_position()
	var chapter_num := _current_chapter_number()
	for preset in SHRINE_NPC_PRESETS:
		if int(preset.get("min_chapter", 99)) > chapter_num:
			continue
		var npc_id := String(preset["npc_id"])
		if not _story_npc_available(npc_id):
			continue
		var npc = ShrineNpcInteractScript.new()
		npc.name = "ShrineNpc_%s" % String(preset["npc_id"])
		npc.collision_layer = INTERACTABLE_LAYER
		npc.collision_mask = 0
		npc.monitoring = false
		npc.monitorable = true
		npc.add_to_group("interactable")
		npc.prompt_text = LocalizationScript.text(String(preset["prompt"]))
		npc.npc_id = preset["npc_id"]
		npc.world_callback = Callable(self, "_on_shrine_npc_talk")
		var shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 1.4
		shape.shape = sphere
		shape.position = Vector3(0.0, 1.0, 0.0)
		npc.add_child(shape)
		var offset: Vector3 = preset["offset"]
		var story_anchor := _story_npc_anchor(npc_id)
		if not story_anchor.is_empty():
			npc.position = _story_anchor_position(story_anchor, base + offset)
			npc.set_meta("story_anchor", story_anchor)
		else:
			npc.position = _supported_shrine_position(base + offset)
		add_child(npc)
		# 真实 NPC 模型(npc/<id>)优先;未注册时退回胶囊占位体
		if not RealModelResolver.try_instance("npc/%s" % String(preset["npc_id"]), npc):
			var mesh := MeshInstance3D.new()
			var cap := CapsuleMesh.new()
			cap.radius = 0.28
			cap.height = 1.4
			mesh.mesh = cap
			mesh.position = Vector3(0.0, 0.9, 0.0)
			npc.add_child(mesh)
		_shrine_npcs.append(npc)


func _story_npc_available(npc_id: String) -> bool:
	var level_id := String(campaign_runtime.current_level_id)
	match npc_id:
		"npc_cloud_wanderer":
			return _is_boss_defeated("boss_giant_gate")
		"npc_iron_heart":
			return level_id == "level_02_03" or bool(run_state.get_choice_flag("npc_iron_heart_met", false))
		"npc_lady_of_memories":
			return level_id == "level_03_02" or bool(run_state.get_choice_flag("npc_lady_of_memories_met", false))
		"npc_xuanxiao_remnant":
			return level_id == "level_04_03" or (has_story_item("xuanxiao_record") and _is_boss_defeated("boss_xuan_xiao_wrath") and _is_boss_defeated("boss_xuan_xiao_obsession"))
		"npc_silence_bringer":
			return level_id == "level_05_04" or bool(run_state.get_choice_flag("npc_silence_bringer_met", false))
	return false


func _story_npc_anchor(npc_id: String) -> String:
	var anchors := CampaignSceneDressingScript.story_anchors(String(campaign_runtime.current_level_id))
	var key := ""
	match npc_id:
		"npc_iron_heart":
			if not bool(run_state.get_choice_flag("npc_iron_heart_met", false)):
				key = "iron_heart_cage"
		"npc_lady_of_memories":
			if not bool(run_state.get_choice_flag("npc_lady_of_memories_met", false)):
				key = "memory_keeper"
		"npc_xuanxiao_remnant":
			key = "xuanxiao_remnant"
		"npc_silence_bringer":
			key = "silence_threshold"
	return key if anchors.has(key) else ""


func _story_anchor_position(key: String, fallback: Vector3) -> Vector3:
	var anchors := CampaignSceneDressingScript.story_anchors(String(campaign_runtime.current_level_id))
	if not anchors.has(key):
		return fallback
	return to_local(campaign_runtime.current_level.to_global(anchors[key]))


func _supported_shrine_position(candidate: Vector3) -> Vector3:
	var best := _supported_campaign_position(candidate, 1.1, 0.0)
	var best_distance := INF
	# Narrow or diagonal paths can project two slots onto one tile edge. Reserve
	# a distinct supported slot for each NPC, including the widest spirit model.
	for x_offset in [0.0, -3.0, 3.0, -6.0, 6.0]:
		for z_offset in [0.0, -3.0, 3.0, -6.0, 6.0]:
			var point := _supported_campaign_position(candidate + Vector3(x_offset, 0.0, z_offset), 1.1, 0.0)
			var clear := true
			for existing: Node3D in _shrine_npcs:
				if point.distance_to(existing.position) < 2.2:
					clear = false
			var distance := point.distance_squared_to(candidate)
			if clear and distance < best_distance:
				best = point
				best_distance = distance
	return best


## 支线·桥头的供茶：茶魂 NPC（桥头茶摊守者，被怨魂归罪）
func _spawn_bridge_tea_npc(at: Vector3) -> void:
	var npc = ShrineNpcInteractScript.new()
	npc.name = "ShrineNpc_bridge_tea_soul"
	npc.collision_layer = INTERACTABLE_LAYER
	npc.collision_mask = 0
	npc.monitoring = false
	npc.monitorable = true
	npc.add_to_group("interactable")
	npc.prompt_text = LocalizationScript.text("与茶魂交谈")
	npc.npc_id = &"npc_bridge_tea_soul"
	npc.world_callback = Callable(self, "_on_shrine_npc_talk")
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.4
	shape.shape = sphere
	shape.position = Vector3(0.0, 1.0, 0.0)
	npc.add_child(shape)
	# 真实 NPC 模型(npc/npc_bridge_tea_soul)优先;未注册时退回胶囊占位体
	if not RealModelResolver.try_instance("npc/%s" % String(npc.npc_id), npc):
		var mesh := MeshInstance3D.new()
		var cap := CapsuleMesh.new()
		cap.radius = 0.28
		cap.height = 1.4
		mesh.mesh = cap
		mesh.position = Vector3(0.0, 0.9, 0.0)
		npc.add_child(mesh)
	npc.position = _grounded_campaign_prop(_story_anchor_position("tea_soul", at), 0.6)
	_add_level_prop(npc)


## 可选 Boss 隐藏入口：无目钟塔（镜花水月亭桥头侧道，任一烬龛侧道亦可延展）
func _spawn_bell_tower_entrance(at: Vector3) -> void:
	var entrance = ShrineNpcInteractScript.new()
	entrance.name = "BellTowerEntrance"
	entrance.collision_layer = INTERACTABLE_LAYER
	entrance.collision_mask = 0
	entrance.monitoring = false
	entrance.monitorable = true
	entrance.add_to_group("interactable")
	entrance.prompt_text = LocalizationScript.text("进入无目钟塔")
	entrance.npc_id = &"npc_bell_tower_entrance"
	entrance.world_callback = Callable(self, "_on_bell_tower_entrance_entered")
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.4
	shape.shape = sphere
	shape.position = Vector3(0.0, 1.0, 0.0)
	entrance.add_child(shape)
	LevelModuleVisuals.add_story_visual(entrance, "bell_portal", _current_visual_theme())
	entrance.position = _grounded_campaign_prop(_story_anchor_position("bell_tower_entrance", at), 1.3)
	_add_level_prop(entrance)


## 无目钟塔入口交互 → 传送至 level_05_06（走 _travel_to_level 的统一锁门）
func _on_bell_tower_entrance_entered(_entrance: Node, _player: Node) -> void:
	if _level_transition_locked:
		return
	_travel_to_level("level_05_06")


## 当前章节数字（chapter_01 → 1）
func _current_chapter_number() -> int:
	var chapter_id: String = run_state.chapter_id if run_state != null else "chapter_01"
	if campaign_runtime != null:
		chapter_id = String(campaign_runtime.get_level_data().get("chapter_id", chapter_id))
	if chapter_id.begins_with("chapter_"):
		return int(chapter_id.substr(8, 2))
	return 1


func _on_shrine_npc_talk(npc: Node, _player: Node) -> void:
	if _dialogue_overlay == null or _dialogue_overlay.is_open():
		return
	var npc_id: StringName = npc.npc_id if "npc_id" in npc else &"npc_cloud_wanderer"
	if npc_id == &"npc_silence_bringer":
		var mechanisms := _story_mechanisms()
		if mechanisms != null and mechanisms.interact_silence(_player):
			return
	var requirement := _story_npc_requirement(npc_id)
	if not requirement.is_empty():
		_dialogue_overlay.open_lines(&"story_evidence_hint", [requirement])
		return
	var lines := DialogueRunnerScript.resolve_lines(npc_id, run_state)
	if lines.is_empty():
		return
	_dialogue_overlay.open_lines(npc_id, lines)


func _story_mechanisms() -> Node:
	if campaign_runtime == null or not is_instance_valid(campaign_runtime.current_level):
		return null
	return campaign_runtime.current_level.get_node_or_null("StoryMechanisms")


func _story_npc_requirement(npc_id: StringName) -> String:
	if npc_id == &"npc_iron_heart" and not bool(run_state.get_choice_flag("npc_iron_heart_met", false)):
		var keys := 0
		for index in range(1, 4):
			if has_story_item("cage_key_" + str(index)):
				keys += 1
		if keys < 3:
			return HudThemeScript.copy("铁心：三道军印锁住了炉火。替我找到营地的三把笼钥（%d/3）。" % keys, "Iron Heart: Three military seals bind this forge. Find the camp's three cage keys (%d/3)." % keys)
		if not bool(run_state.get_choice_flag("iron_forge_seal_broken", false)):
			return HudThemeScript.copy("铁心：钥匙齐了。请先解开门上的强制锻造印。", "Iron Heart: You have the keys. Break the forced-forge seal on the door.")
	if npc_id == &"npc_lady_of_memories" and not bool(run_state.get_choice_flag("npc_lady_of_memories_met", false)):
		var memories := 0
		for index in range(1, 4):
			if has_story_item("true_memory_" + str(index)):
				memories += 1
		if memories < 3 or not bool(run_state.get_choice_flag("story_memory_thief_defeated", false)):
			return HudThemeScript.copy("忆姬：三段记忆都属于别人。辨认真相，并击败记忆窃贼，我才能离开这片苔（%d/3）。" % memories, "Lady of Memories: These memories belong to other souls. Identify all three and defeat the memory thief to release me (%d/3)." % memories)
	if npc_id == &"npc_xuanxiao_remnant" and not (has_story_item("xuanxiao_record") and _is_boss_defeated("boss_xuan_xiao_wrath") and _is_boss_defeated("boss_xuan_xiao_obsession")):
		return HudThemeScript.copy("残识：这里保存着未经篡改的记录。带走实录，平息嗔念与执念，再来听玄霄真正的声音。", "Remnant: This record remains unaltered. Take it and calm Wrath and Obsession to hear Xuan Xiao's true voice.")
	return ""


## L-04：第五章 5-1..5-4 各刷一红晶证物（隐藏结局"共铸新炉"链）
func _spawn_furnace_memory(at: Vector3, memory_key: String) -> void:
	if run_state != null and bool(run_state.get_choice_flag(memory_key, false)):
		return
	var crystal = FurnaceMemoryCrystalScript.new()
	crystal.name = "FurnaceMemory_%s" % memory_key
	crystal.collision_layer = INTERACTABLE_LAYER
	crystal.collision_mask = 0
	crystal.monitoring = false
	crystal.monitorable = true
	crystal.add_to_group("interactable")
	crystal.prompt_text = LocalizationScript.text("Read the red crystal memory")
	crystal.memory_key = memory_key
	crystal.world_callback = Callable(self, "_on_furnace_memory_claimed")
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.1
	shape.shape = sphere
	shape.position = Vector3(0.0, 1.0, 0.0)
	crystal.add_child(shape)
	LevelModuleVisuals.add_story_visual(crystal, "crystal_shrine", _current_visual_theme())
	crystal.position = _grounded_campaign_prop(_story_anchor_position("furnace_memory", at), 0.8)
	_add_level_prop(crystal)


## 5-3 轮回歧路·因果回放交互节点
func _spawn_samsara_review(at: Vector3) -> void:
	var node = SamsaraForkInteractScript.new()
	node.name = "SamsaraReview"
	node.collision_layer = INTERACTABLE_LAYER
	node.collision_mask = 0
	node.monitoring = false
	node.monitorable = true
	node.add_to_group("interactable")
	node.prompt_text = LocalizationScript.text("回望往昔的选择")
	node.world_callback = Callable(self, "_on_samsara_review")
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.1
	shape.shape = sphere
	shape.position = Vector3(0.0, 1.0, 0.0)
	node.add_child(shape)
	LevelModuleVisuals.add_story_visual(node, "memory_rings", _current_visual_theme())
	node.position = _grounded_campaign_prop(_story_anchor_position("samsara_replay", at), 1.0)
	_add_level_prop(node)


func _on_samsara_review(_node: Node, _player: Node) -> void:
	_begin_samsara_review()


## 逐章链式回放：ch1→ch2→ch3→ch4，每章接受/悔
func _begin_samsara_review() -> void:
	_samsara_queue = [&"samsara_stance_ch1", &"samsara_stance_ch2", &"samsara_stance_ch3", &"samsara_stance_ch4"]
	_open_next_samsara()


func _open_next_samsara() -> void:
	if _samsara_queue.is_empty():
		return
	var flag := StringName(_samsara_queue.pop_front())
	if _fate_overlay != null and FateCatalog.entry_for_flag(flag).size() > 0:
		_fate_overlay.open_for_flag(flag)


## 5-4 九铸魂者之墓·证词汇合交互节点（复用 shrine_npc_interact 开对白）
func _spawn_soul_forger_communion(at: Vector3) -> void:
	var node = ShrineNpcInteractScript.new()
	node.name = "SoulForgerCommunion"
	node.collision_layer = INTERACTABLE_LAYER
	node.collision_mask = 0
	node.monitoring = false
	node.monitorable = true
	node.add_to_group("interactable")
	node.npc_id = &"npc_soul_forgers"
	node.prompt_text = LocalizationScript.text("与九铸魂者交谈")
	node.world_callback = Callable(self, "_on_shrine_npc_talk")
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.1
	shape.shape = sphere
	shape.position = Vector3(0.0, 1.0, 0.0)
	node.add_child(shape)
	# The nine named memorials are imported scene architecture. This area gives
	# that actual ring its conversation; do not add a second set of graves.
	node.position = _grounded_campaign_prop(_story_anchor_position("nine_forgers_memorial", at), 1.0)
	_add_level_prop(node)


## 支线·桥头的供茶：桥头栏杆上一盏仍温的供茶（烬茶倌未及送出的那杯）
func _spawn_tea_offering(at: Vector3) -> void:
	if run_state != null and bool(run_state.get_choice_flag("bridge_tea_offering", false)):
		return
	var crystal = FurnaceMemoryCrystalScript.new()
	crystal.name = "TeaOffering"
	crystal.collision_layer = INTERACTABLE_LAYER
	crystal.collision_mask = 0
	crystal.monitoring = false
	crystal.monitorable = true
	crystal.add_to_group("interactable")
	crystal.prompt_text = LocalizationScript.text("拾起桥头那杯供茶")
	crystal.memory_key = "bridge_tea_offering"
	crystal.world_callback = Callable(self, "_on_tea_offering_claimed")
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.1
	shape.shape = sphere
	shape.position = Vector3(0.0, 1.0, 0.0)
	crystal.add_child(shape)
	LevelModuleVisuals.add_story_visual(crystal, "tea_cup", _current_visual_theme())
	crystal.position = _grounded_campaign_prop(_story_anchor_position("tea_offering", at), 0.5)
	_add_level_prop(crystal)


func _current_visual_theme() -> String:
	return String(campaign_runtime.get_level_data().get("theme_id", &"theme_spirit_ruins"))


func _grounded_campaign_prop(candidate: Vector3, radius: float) -> Vector3:
	# Character spawn support preserves authored height; static plinths must
	# explicitly snap to the terrain before the new physics space is published.
	var point := _supported_campaign_position(candidate, radius, 0.0)
	var level_root := campaign_runtime.current_level
	var local := level_root.to_local(to_global(point))
	var navigation := level_root.get_node("NavigationSurface")
	var floor_y := CampaignLevelRuntimeScript.Builder._tile_floor_at(navigation.get_meta("walkable_cells", []), local)
	if is_finite(floor_y):
		local.y = floor_y
	return to_local(level_root.to_global(local))


func _add_level_prop(prop: Node3D) -> void:
	# Story props belong to the level that spawned them. Unloading that root
	# removes visuals, interaction areas, and their callbacks together.
	var level_root := campaign_runtime.current_level
	prop.position = level_root.to_local(to_global(prop.position))
	prop.add_to_group("campaign_level_props")
	prop.set_meta("level_id", campaign_runtime.current_level_id)
	level_root.add_child(prop)


## 支线·桥头的供茶：拾取 → 开启 quest_bridge_tea
func _on_tea_offering_claimed(crystal: Node, _player: Node) -> void:
	if crystal == null or not is_instance_valid(crystal):
		return
	if run_state != null and not bool(run_state.get_choice_flag("bridge_tea_offering", false)):
		run_state.set_choice_flag("bridge_tea_offering", true)
		hud.show_message(LocalizationScript.text("桥头的供茶：月圆将至，茶还温着"), 2.0)
		audio.play_cue("rest", -6.0, 0.8)
		QuestStateScript.start(run_state, QuestStateScript.QUEST_BRIDGE_TEA)
		_save_run("bridge_tea_offering")
	if is_instance_valid(crystal):
		crystal.queue_free()


## L-04：红晶证物拾取 → 置 furnace_memory_N + 推进三真相任务
func _on_furnace_memory_claimed(crystal: Node, _player: Node) -> void:
	if crystal == null or not is_instance_valid(crystal):
		return
	var memory_key := String(crystal.memory_key)
	if run_state != null and not bool(run_state.get_choice_flag(memory_key, false)):
		run_state.set_choice_flag(memory_key, true)
		var index := memory_key.trim_prefix("furnace_memory_")
		hud.show_message(LocalizationScript.text("FURNACE MEMORY %s\n低语在烬中回响") % index, 2.0)
		audio.play_cue("rest", -6.0, 0.8)
		_memory_quest_progress()
		_save_run("furnace_memory")
	if is_instance_valid(crystal):
		crystal.queue_free()


## L-04：三真相任务进度（第 1 块开启，第 4 块齐备）
func _memory_quest_progress() -> void:
	if run_state == null:
		return
	var memories := _furnace_memories_found()
	if memories == 1:
		QuestStateScript.start(run_state, &"quest_soul_return")
		QuestStateScript.start(run_state, &"quest_furnace_whisper")
		QuestStateScript.start(run_state, &"quest_forge_last_question")
	if memories >= 4:
		QuestStateScript.complete(run_state, &"quest_furnace_whisper")
		QuestStateScript.complete(run_state, &"quest_soul_return")
		QuestStateScript.complete(run_state, &"quest_forge_last_question")
		hud.show_message(LocalizationScript.text("THE FURNACE WHISPERS ITS TRUE NAME"), 2.5)


func _furnace_memories_found() -> int:
	var count := 0
	for key in ["furnace_memory_1", "furnace_memory_2", "furnace_memory_3", "furnace_memory_4"]:
		if bool(run_state.get_choice_flag(key, false)):
			count += 1
	return count


func _on_dialogue_finished(dialogue_id: StringName) -> void:
	DialogueRunnerScript.apply_aftermath(dialogue_id, run_state)
	_save_run("dialogue_finished")
	if dialogue_id in [&"npc_iron_heart", &"npc_lady_of_memories", &"npc_xuanxiao_remnant", &"npc_silence_bringer"]:
		call_deferred("_spawn_shrine_npc")
	if dialogue_id == &"npc_iron_heart":
		_try_iron_heart_forge()
	# 支线·桥头的供茶：茶魂倾诉后开启月圆之判（任务进行中且未落笔）
	if dialogue_id == &"npc_bridge_tea_soul":
		var tea_stage := QuestStateScript.get_stage(run_state, QuestStateScript.QUEST_BRIDGE_TEA)
		var tea_chosen := String(run_state.get_choice_flag("bridge_tea_fate", "")) != ""
		if tea_stage == QuestStateScript.STAGE_ACTIVE and not tea_chosen and _fate_overlay != null:
			_fate_overlay.open_for_flag(&"bridge_tea_fate")
	if hud != null:
		hud.show_message(LocalizationScript.text("WORDS SETTLE"), 1.0)


## L-05：铁心工坊锻造 —— 武器 +1..+10（+5%/级），花费递增烬
const FORGE_COSTS := [120, 180, 260, 380, 540, 760, 1050, 1450, 1950, 2600]

## L-15：道行（cultivation）—— 花费 (Lv+1)×100 烬，60 级后 ×3；每级 +5 HP/+1 耐力/+1 灵蕴
const DAO_MAX_LEVEL := 99
const DAO_SOFT_CAP := 60

## L-15：魂器（soul vessel）—— +1..+5 五阶，永久叠加属性（累计 10/15/10/5/10）
const VESSEL_COSTS := [200, 500, 1000, 2000, 4000]
const VESSEL_TIER_BONUSES := [
	{"max_health": 10.0, "max_stamina": 0.0, "max_focus": 0.0},   # +1 +10 HP（10% 基准）
	{"max_health": 0.0, "max_stamina": 15.0, "max_focus": 0.0},   # +2 +15 耐力（15% 基准）
	{"max_health": 0.0, "max_stamina": 0.0, "max_focus": 10.0},   # +3 +10 灵蕴
	{"max_health": 5.0, "max_stamina": 5.0, "max_focus": 5.0},    # +4 +5% 全属性
	{"max_health": 10.0, "max_stamina": 10.0, "max_focus": 10.0}, # +5 终极 +10% 全属性
]

## L-10：Boss 掉落物（boss_id → 物品 id），胜后记入背包/图鉴
const BOSS_LOOT_BY_ID := {
	"boss_giant_gate": "reliquary_shield",
	"boss_nine_tails": "five_elements_seal",
	"boss_xuan_xiao_wrath": "xingtian_axe_right",
	"boss_xuan_xiao_obsession": "xingtian_axe_left",
	"boss_xuan_xiao": "spirit_talisman",
	"boss_zhu_yin": "prayer_beads",
	"boss_xing_tian": "xingtian_axe_right",
	"boss_blind_bell": "blind_bell_tongue",
}

## L-10：精锐掉落池（可选防具/副手；玩家非起始装备，能扩充图鉴）
const ELITE_LOOT_POOL := [
	"jade_buckler", "parry_dagger", "fist_guard",
	"furnace_greatshield", "spirit_stone", "marksman_dagger", "talisman_papers",
]

func _try_iron_heart_forge() -> void:
	if player == null or run_state == null:
		return
	var level := int(run_state.progression_values.get("weapon_forge_level", 0))
	if level >= FORGE_COSTS.size():
		hud.show_message(LocalizationScript.text("IRON HEART: weapon already fully forged"), 2.0)
		return
	var cost: int = FORGE_COSTS[level]
	if player.embers < cost:
		hud.show_message(
			LocalizationScript.text("IRON HEART: need %d embers to forge +%d") % [cost, level + 1],
			2.0
		)
		return
	player.embers -= cost
	player.embers_changed.emit(player.embers)
	level += 1
	run_state.progression_values["weapon_forge_level"] = level
	if player.has_method("set_forge_level"):
		player.set_forge_level(level)
	hud.show_message(LocalizationScript.text("WEAPON FORGED  +%d  (+%d%% DMG)") % [level, level * 5], 2.5)
	audio.play_cue("recover", -5.0, 0.7)
	_save_run("weapon_forged")


func _on_boss_weak_point_exposed(enemy) -> void:
	if _camera_director != null:
		_camera_director.play_shot_id(&"weak_point_expose", enemy)


func _on_boss_phase_changed(enemy, new_phase: int) -> void:
	# G-04：相变抛光（动画混合 / 镜头焦点 / 场地 VFX）
	on_boss_phase_changed(enemy, new_phase)


func on_boss_phase_changed(enemy, new_phase: int) -> void:
	if _phase_polisher == null or enemy == null or not is_instance_valid(enemy):
		return
	if not bool(enemy.get("guardian")):
		return
	_phase_polisher.play_transition(enemy, int(new_phase))
	# L-24/L-26：相变环境漂移（读取该阶段 phases.lighting 键）+ 场地事件（arena_event）+ 短促 hit-stop 镜头节拍
	if _phase_environment != null and _phase_environment.is_bound():
		var lighting_key := _phase_lighting_key(enemy, int(new_phase))
		_phase_environment.apply_lighting_key(lighting_key)
	if _arena_director != null:
		_arena_director.on_boss_phase(enemy, int(new_phase))
	if _hit_stop_manager != null and not bool(game_settings.reduced_motion):
		_hit_stop_manager.trigger(player, enemy, 0.1, float(Engine.physics_ticks_per_second))
	if hud != null and int(new_phase) >= 2:
		hud.show_message(
			LocalizationScript.text("PHASE %d") % int(new_phase),
			1.2
		)


## L-24：读 Boss 内容 phases[str(phase)]["lighting"]；缺失回退空串（由环境器做通用渐变）
func _phase_lighting_key(enemy, phase: int) -> String:
	if not ("chapter_content" in enemy):
		return ""
	var phases: Variant = enemy.chapter_content.get("phases", {})
	if typeof(phases) != TYPE_DICTIONARY or not (phases as Dictionary).has(str(phase)):
		return ""
	return String((phases as Dictionary)[str(phase)].get("lighting", ""))


## L-24：找主方向光（Moonlight），供环境器绑定
func _find_key_light() -> Light3D:
	for child in get_children():
		if child is DirectionalLight3D:
			return child
	return null


## L-24：Boss AoE 落点冲击表现（boss_attack_executor 以 has_method 探测调用）
func spawn_boss_impact_vfx(position: Vector3, radius: float) -> void:
	if _impact_vfx != null:
		_impact_vfx.spawn_slam_ring(position, "ember")
		_impact_vfx.spawn_impact(position, Vector3.UP, "ember", clampf(radius * 0.35, 0.8, 2.2))
	if _trauma_shake != null:
		_trauma_shake.inject(clampf(radius * 0.12, 0.3, 0.8))


func _on_boss_grab_started(_target, enemy) -> void:
	if _camera_director != null:
		_camera_director.play_shot_id(&"grab_hold", enemy)


func _on_player_execution_started(kind: StringName, target: Node) -> void:
	if kind == &"weak_point" and _camera_director != null:
		_camera_director.play_shot_id(&"weak_point_exec", target as Node3D)


func get_target_candidates() -> Array[Node]:
	var candidates: Array[Node] = []
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.is_targetable():
			candidates.append(enemy)
	return candidates


func is_position_in_sanctuary(at: Vector3) -> bool:
	return at.distance_to(respawn_position) <= 5.0


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
	_restoring_run_state = true
	run_state = state
	if not _load_campaign_level(StringName(run_state.level_id)):
		_load_campaign_level(&"level_01_01")
	run_state.level_id = String(campaign_runtime.current_level_id)
	var level_data := campaign_runtime.get_level_data()
	run_state.chapter_id = String(level_data.get("chapter_id", &"chapter_01"))
	if player.has_method("set_embers"):
		player.set_embers(run_state.embers)
	else:
		player.embers = run_state.embers
		player.embers_changed.emit(player.embers)
	player.set_focus(run_state.focus)
	# Restore identity before equipment; the selected weapon must not infer a new body.
	player.set_combat_style(run_state.combat_style)
	player.apply_body_class_override()
	player.restore_weapon_loadout(run_state)
	if player.has_method("set_upgrade_tier"):
		player.set_upgrade_tier(run_state.upgrade_tier)
	if player.has_method("set_forge_level"):
		player.set_forge_level(int(run_state.progression_values.get("weapon_forge_level", 0)))
	# L-15：装载道行/魂器加成（存档等级为权威，幂等补齐到玩家统计）
	_apply_progression_stats()
	checkpoint.activate()
	if "ancient_gate" in run_state.activated_shortcuts:
		shortcut.open_immediately()
	if run_state.lost_echo_amount > 0:
		_spawn_lost_echo(run_state.lost_echo_amount, run_state.lost_echo_position)
	# 多 Boss 存档修复：本关 Boss 若已在 defeated_bosses 中，_load_campaign_level 已按
	# 该 Boss 自己的 id 释放守卫并打开出口，这里不再重复用全局 victory 位处理。
	# 有已激活祠堂时，重生点回到 checkpoint marker 而非出生点
	if not String(run_state.checkpoint_id).is_empty():
		respawn_position = _resolve_respawn_position(_checkpoint_position() + Vector3(0.0, 1.1, 2.0))
	if _boss_aftermath_pending and is_instance_valid(_arena_director):
		# Full save/host restore applies identity and upgrades after loading the
		# level. Its final spawn must return to the unfinished course, not the shrine.
		_arena_director.retry_aftermath()
		if is_instance_valid(lost_echo):
			lost_echo.global_position = player.global_position + Vector3(1., .35, 0)
	else:
		player.respawn_at(respawn_position)
		hud.show_message(LocalizationScript.text("THE HOLLOW REMEMBERS"), 1.8)
	_restoring_run_state = false


func _snapshot_run_state() -> Dictionary:
	run_state.level_id = String(campaign_runtime.current_level_id)
	var level_data := campaign_runtime.get_level_data()
	run_state.chapter_id = String(level_data.get("chapter_id", run_state.chapter_id))
	run_state.embers = int(player.embers)
	run_state.focus = float(player.focus)
	run_state.max_focus = float(player.max_focus)
	run_state.combat_style = int(player.combat_style)
	if player.has_method("get_hand_loadout"):
		var hand_loadout: Dictionary = player.get_hand_loadout()
		run_state.right_hand = String(hand_loadout.get("right_hand", run_state.right_hand))
		run_state.left_hand = String(hand_loadout.get("left_hand", run_state.left_hand))
	player.snapshot_weapon_loadout(run_state)
	if player.has_method("get_upgrade_tier"):
		run_state.upgrade_tier = player.get_upgrade_tier()
	# Ch.1 兼容位：仅当巨阙已被记录进 defeated_bosses 时才为真，defeated_bosses 才是权威来源
	run_state.guardian_defeated = ("boss_giant_gate" in run_state.defeated_bosses)
	if shortcut != null and shortcut.is_open:
		if "ancient_gate" not in run_state.activated_shortcuts:
			run_state.activated_shortcuts.append("ancient_gate")
	if lost_echo != null and is_instance_valid(lost_echo) and not lost_echo.is_queued_for_deletion():
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


func _on_hud_combat_tip_mode_requested(enabled: bool) -> void:
	# 暂停菜单切换战斗提示模式并持久化
	game_settings.combat_tip_mode = enabled
	game_settings.save_to_path(SETTINGS_PATH)
	_apply_settings()


func _on_player_hit_landed(target: Node3D, is_heavy: bool) -> void:
	# 本地 hit-stop：重击更长；创伤按武器重量档注入
	var duration := 0.08 if is_heavy else 0.04
	_hit_stop_manager.trigger(player, target, duration, float(Engine.physics_ticks_per_second))
	var weight := _resolve_hit_trauma_weight(is_heavy)
	_trauma_shake.inject_weight(weight)
	# L-24：命中点冲击粒子（Boss 石躯 = 石火，其余 = 钢火）
	if _impact_vfx != null and target is Node3D:
		var hit_point: Vector3 = target.get_target_point() if target.has_method("get_target_point") else (target as Node3D).global_position
		var kind := "stone_sparks" if bool(target.get("guardian")) else "steel"
		_impact_vfx.spawn_impact(hit_point, Vector3.UP, kind, 1.4 if is_heavy else 1.0)
	# 重击命中：短时 Master 低通 duck（headless 内为 no-op）
	if is_heavy and audio != null and is_instance_valid(audio) and audio.has_method("duck_heavy_impact"):
		audio.duck_heavy_impact()


## 从命中载荷 / 玩家状态解析 light(0.3) / heavy(0.8) / explosion(1.0)
func _resolve_hit_trauma_weight(is_heavy: bool) -> StringName:
	var tags: Array = []
	var action_id := ""
	if player != null and player.combat_area != null:
		var payload: Dictionary = player.combat_area.hit_payload
		tags = payload.get("tags", [])
		action_id = String(payload.get("action_id", ""))
	# 跳劈进行中视为爆炸档最大创伤
	if player != null:
		if player.state == player.State.LEAP_ACTIVE:
			return &"explosion"
		if String(player.attack_action_id).to_lower().contains("leap"):
			return &"explosion"
	return TraumaShakeScript.resolve_weight(is_heavy, tags, action_id)


func _on_player_healing() -> void:
	if enemies == null:
		return
	for enemy in enemies:
		if enemy != null and is_instance_valid(enemy) and enemy.has_method("on_player_healing"):
			enemy.on_player_healing()


func _apply_settings() -> void:
	Engine.max_fps = game_settings.target_fps
	if _trauma_shake != null:
		_trauma_shake.set_settings(
			game_settings.screen_shake_enabled and not game_settings.reduced_motion,
			game_settings.screen_shake_intensity
		)
	if _camera_director != null:
		_camera_director.set_reduced_motion(game_settings.reduced_motion)
	if _phase_polisher != null:
		_phase_polisher.set_reduced_motion(game_settings.reduced_motion)
	TranslationServer.set_locale(game_settings.locale)
	if player != null and player.has_method("apply_game_settings"):
		player.apply_game_settings(game_settings.to_dictionary())
	if hud != null and hud.has_method("apply_accessibility_settings"):
		hud.apply_accessibility_settings(game_settings.to_dictionary())
	if _inventory_overlay != null:
		_inventory_overlay.apply_accessibility_settings(game_settings.to_dictionary())
	var master_index := AudioServer.get_bus_index("Master")
	if master_index >= 0:
		var linear_volume: float = maxf(
			game_settings.master_volume * game_settings.effects_volume,
			0.0001
		)
		AudioServer.set_bus_volume_db(master_index, linear_to_db(linear_volume))
	# C-06：Music 总线音量（无总线时静默跳过）
	var music_index := AudioServer.get_bus_index("Music")
	if music_index >= 0:
		AudioServer.set_bus_volume_db(
			music_index,
			linear_to_db(maxf(game_settings.music_volume, 0.0001))
		)
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
	_load_campaign_level(&"level_01_01")


func _create_gate(at: Vector3) -> Node3D:
	var gate := Node3D.new()
	gate.name = "ShortcutGate"
	gate.position = at
	for offset: float in [-1.6, -0.8, 0.0, 0.8, 1.6]:
		var bar := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.22, 3.0, 0.3)
		mesh.material = materials["metal"]
		bar.mesh = mesh
		bar.position.x = offset
		gate.add_child(bar)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4.0, 3.0, 0.5)
	collision.shape = shape
	body.add_child(collision)
	gate.add_child(body)
	add_child(gate)
	return gate


func request_navigation_refresh(level_root: Node3D) -> void:
	if not is_instance_valid(level_root) or campaign_runtime.current_level != level_root:
		return
	var region := level_root.get_node_or_null("NavigationSurface") as NavigationRegion3D
	if region == null:
		return
	region.set_meta("geometry_dirty", true)
	if bool(region.get_meta("refresh_queued", false)):
		return
	region.set_meta("refresh_queued", true)
	# Node-owned method callables disconnect when the world is freed. A weak
	# level reference also permits a transition while this frame is pending.
	_queue_navigation_step(_begin_navigation_bake.bind(weakref(level_root)))


func _queue_navigation_step(step: Callable) -> void:
	if not is_inside_tree() or not step.is_valid():
		return
	# Each refresh owns its next physics tick. Reusing SceneTree.physics_frame
	# one-shots lost pending callbacks when field cleanup and new-level setup
	# queued work in the same frame, leaving refresh_queued permanently latched.
	var next_tick := get_tree().create_timer(1.0 / Engine.physics_ticks_per_second, true, true)
	next_tick.timeout.connect(step, CONNECT_ONE_SHOT)


func _begin_navigation_bake(level_ref: WeakRef) -> void:
	var level_root := level_ref.get_ref() as Node3D
	if level_root == null or campaign_runtime.current_level != level_root:
		return
	var region := level_root.get_node_or_null("NavigationSurface") as NavigationRegion3D
	if region == null or region.navigation_mesh == null:
		return
	if region.is_baking():
		_queue_navigation_step(_begin_navigation_bake.bind(level_ref))
		return
	region.set_meta("geometry_dirty", false)
	region.set_meta("bake_requested", true)
	region.set_meta("bake_complete", false)
	var initial_iteration := NavigationServer3D.map_get_iteration_id(region.get_navigation_map())
	region.bake_finished.connect(_on_navigation_baked.bind(level_ref, initial_iteration), CONNECT_ONE_SHOT)
	region.bake_navigation_mesh(false)


func _generate_navigation() -> void:
	if campaign_runtime == null or campaign_runtime.current_level == null:
		return
	var level_root := campaign_runtime.current_level
	var region := level_root.get_node_or_null("NavigationSurface") as NavigationRegion3D
	if region == null or bool(region.get_meta("bake_requested", false)) or bool(region.get_meta("refresh_queued", false)):
		return
	request_navigation_refresh(level_root)


func _on_navigation_baked(level_ref: WeakRef, initial_iteration: int) -> void:
	var level_root := level_ref.get_ref() as Node3D
	if level_root == null or campaign_runtime.current_level != level_root:
		return
	var region := level_root.get_node("NavigationSurface") as NavigationRegion3D
	region.set_meta("bake_complete", true)
	region.set_meta("baked_polygon_count", region.navigation_mesh.get_polygon_count())
	_queue_navigation_step(_publish_navigation.bind(level_ref, initial_iteration, 90))


func _publish_navigation(level_ref: WeakRef, initial_iteration: int, frames_left: int) -> void:
	var level_root := level_ref.get_ref() as Node3D
	if level_root == null or campaign_runtime.current_level != level_root:
		return
	var region := level_root.get_node("NavigationSurface") as NavigationRegion3D
	if frames_left > 0 and NavigationServer3D.map_get_iteration_id(region.get_navigation_map()) == initial_iteration:
		_queue_navigation_step(_publish_navigation.bind(level_ref, initial_iteration, frames_left - 1))
		return
	# Publish after the initial empty-map update so it cannot overwrite the bake.
	NavigationServer3D.region_set_navigation_mesh(region.get_rid(), region.navigation_mesh)
	region.set_meta("geometry_revision", int(region.get_meta("geometry_revision", 0)) + 1)
	region.set_meta("refresh_queued", false)
	if bool(region.get_meta("geometry_dirty", false)):
		request_navigation_refresh(level_root)


func _run_smoke_test() -> void:
	var SmokeTest = load("res://tests/smoke/smoke_test.gd")
	SmokeTest.run(self)
