extends Node3D
## Eight encounter identities. All objects, delayed actions and rewards are scoped
## to their director; the world remains the authority for story/save transitions.
const Prop = preload("res://scripts/world/boss_arena_prop.gd")
const Copy = preload("res://scripts/ui/hud_theme.gd")
const Clone = preload("res://scripts/boss/boss_attack_clone.gd")
const Ending = preload("res://scripts/story/ending_resolver.gd")
const EscapeCourse = preload("res://scripts/world/boss_escape_course.gd")
var world: Node
var director: Node
var boss: Node3D
var player: Node3D
var boundary: Node
var center := Vector3.ZERO
var radius := 20.
var boss_id := ""
var phase := 1
var generation := 0
var props: Array[Node3D] = []
var events: Dictionary = {}
var judgement_flag: StringName
var combat_active := false
var aftermath_active := false
var aftermath_completed := false
var escape_remaining := 90.
var escape_checkpoint := Vector3.ZERO
var escape_goal := Vector3.ZERO
var _timers: Array[Tween] = []
var _seconds := 0.
var _cycle := 0.
var _watch_index := 0
var _watch_pause := 0.
var _ritual_index := 0
var _ritual_token := 0
var _salute_started := false
var _salute_finished := false
var _intro_remaining := 0.
var _desire_remaining := -1.
var _desire_attack := 0
var _noise_position := Vector3.ZERO
var _noise_strength := 0.
var _silence := 10.
var _mouth_hits := 0
var _deaf_remaining := 0.
var _last_embers := 0
var _decoy: Node3D
var _lunge_delay := -1.
var _lunge_moving := false
var _lunge_remaining := 0.
var _lunge_goal := Vector3.ZERO
var _invulnerable_boon := false
var _illusion_boon := false
var _hero_boon := false
var _gravity_flip := 1.
var _base_speed := 0.
var _personality := 0
var escape_course: Node3D
var _memory_active := false
var _counter_ready := true
var _original_attacks: Dictionary = {}
var _lowered_axe: Node3D
var _hidden_weapon_parts: Array[MeshInstance3D] = []
var _last_announced_attack := -1

func setup(owner_director: Node, enemy: Node3D, at: Vector3, extent: float) -> void:
	director = owner_director
	boss = enemy
	center = at
	radius = extent
	boss_id = String(boss.get("content_id"))
	world = enemy.world_node
	player = world.player
	_base_speed = float(boss.move_speed)
	_original_attacks = boss._content_phase_attacks.duplicate(true)
	name = "BossStoryArena"
	process_physics_priority = 5
	_build_identity()
	_build_judgement()
	if player.has_signal("embers_changed"):
		player.embers_changed.connect(_on_embers_changed)
	if player.has_signal("hit_landed"):
		player.hit_landed.connect(_on_player_hit)
	_last_embers = int(player.embers)
	reset_encounter()

func bind_encounter(value: Node) -> void:
	boundary = value
	if not value.encounter_started.is_connected(start_encounter):
		value.encounter_started.connect(start_encounter)
		value.encounter_reset.connect(reset_encounter)
		value.encounter_resolved.connect(_on_resolved)

func _add(role: String, part: String, at: Vector3, extra: Dictionary = {}) -> Node3D:
	var prop = Prop.new()
	add_child(prop)
	var data := {"role": role, "part": part}
	data.merge(extra, true)
	if not prop.setup(self, data):
		prop.queue_free()
		return null
	prop.global_position = at
	prop.set_meta("home_position", at)
	props.append(prop)
	return prop

func _ring(role: String, part: String, count: int, distance: float, extra: Dictionary = {}) -> void:
	for index in count:
		var angle := TAU * float(index) / count + PI * .25
		var prop := _add(role + str(index), part, center + Vector3(cos(angle), 0., sin(angle)) * distance, extra)
		if is_instance_valid(prop):
			prop.rotation.y = -angle

func _build_identity() -> void:
	match boss_id:
		"boss_giant_gate":
			_ring("pillar_", "CelestialSpire", 4, radius * .34, {"scale": .42})
			_ring("watch_", "WatchBrazier", 4, radius * .62, {"scale": .55, "prompt": Copy.copy("压住炉口，暂熄余火", "Smother the brazier")})
		"boss_xing_tian":
			_lowered_axe = Node3D.new()
			add_child(_lowered_axe)
			preload("res://scripts/core/real_model_resolver.gd").try_instance("player/weapon/axe_left", _lowered_axe)
			_lowered_axe.hide()
			_ring("chain_", "ChainAnchor", 4, radius * .52, {"scale": .65, "destructible": true, "health": 120.})
			_add("communion", "WatchBrazier", center + Vector3(0, 0, radius * .7), {"scale": .45, "prompt": Copy.copy("跪下，以怒意应战", "Kneel and prove your rage")})
		"boss_nine_tails":
			_ring("flower_", "IllusionTree", 9, radius * .68, {"scale": .45, "destructible": true, "health": 35., "prompt": Copy.copy("触碰幻花，辨认真实", "Touch the flower; reveal truth")})
			_add("truth_mirror", "MemoryMirror", center + Vector3(0, 0, radius * .52), {"scale": .55, "prompt": Copy.copy("举起真实之镜", "Raise the Mirror of Truth")})
		"boss_xuan_xiao_wrath":
			_ring("wrath_pillar_", "CelestialSpire", 5, radius * .5, {"scale": .4, "destructible": true, "health": 90., "impact_radius": 1.8})
		"boss_xuan_xiao_obsession":
			_ring("ritual_", "BronzeCauldron", 3, radius * .5, {"scale": .48, "destructible": true, "health": 55., "prompt": Copy.copy("打断未竟的仪式", "Interrupt the unfinished ritual")})
		"boss_xuan_xiao":
			_ring("mind_", "Orrery", 3, radius * .54, {"scale": .4, "destructible": true, "health": 75., "prompt": Copy.copy("镇住游离的残识", "Quiet the wandering fragment")})
			escape_course = EscapeCourse.new()
			add_child(escape_course)
			escape_course.setup(player, center, radius)
			escape_checkpoint = escape_course.checkpoint
			escape_goal = escape_course.goal
			escape_course.completed.connect(complete_aftermath)
			escape_course.failed.connect(_escape_failed)
			escape_course.navigation_changed.connect(director._request_navigation_update)
		"boss_zhu_yin":
			_ring("debris_", "BrokenArch", 5, radius * .43, {"scale": .5, "destructible": true, "health": 180.})
			_ring("gravity_", "Orrery", 3, radius * .64, {"scale": .38, "prompt": Copy.copy("扭转引力，稳住身形", "Turn gravity; steady your drift")})
			_add("dispel_mirror", "MemoryMirror", center + Vector3(0,0,radius * .55), {"scale": .45, "prompt": Copy.copy("消耗狐印，驱散眼前幻袭", "Spend the fox seal to dispel an illusion")})
		"boss_blind_bell":
			var mouth = preload("res://scripts/world/boss_bell_weakpoint.gd").new()
			add_child(mouth)
			mouth.setup(self)
			_ring("bell_", "DecoyBell", 12, 15., {"scale": .7, "prompt": Copy.copy("摇响诱铃", "Ring the decoy bell")})

func _build_judgement() -> void:
	var actions: Array = []
	match boss_id:
		"boss_giant_gate":
			actions = [["ch1_guardian_fate", "released", "WatchBrazier", "释放职责", "Release its duty"], ["ch1_guardian_fate", "preserved", "MemoryMirror", "保留守护核心", "Preserve the guardian core"]]
		"boss_xing_tian":
			actions = [["ch2_xingtian_fate", "honored", "ChainAnchor", "安放战烬，致以终礼", "Honor the warrior"], ["ch2_xingtian_fate", "absorbed", "WatchBrazier", "吸收战烬", "Absorb the War Ember"]]
		"boss_nine_tails":
			actions = [["ch3_nine_tails_fate", "redeemed", "MemoryMirror", "照见真身，救赎九尾", "Reveal and redeem Nine-Tails"], ["ch3_nine_tails_fate", "sealed", "WatchBrazier", "封印残灵", "Seal the remaining spirit"]]
		"boss_xuan_xiao":
			actions = [["ch4_xuanxiao_fate", "ascended", "Orrery", "送其完成飞升", "Complete his ascension"], ["ch4_xuanxiao_fate", "remembered", "MemoryMirror", "归忆人间", "Return him to memory"]]
		"boss_zhu_yin":
			actions = [["ending_state", "kindle", "WatchBrazier", "吸收终烬", "Absorb the Final Ember"], ["ending_state", "keeper", "Throne", "坐上烬座（攻击可击碎烬座）", "Sit on the throne; strike to shatter it"], ["ending_state", "forge", "BronzeCauldron", "交还炉忆，共铸新炉", "Return the memories; forge together"]]
	for index in actions.size():
		var row: Array = actions[index]
		var offset := Vector3((float(index) - float(actions.size() - 1) * .5) * 5., 0., 3.)
		var prop := _add("judgement_" + String(row[1]), String(row[2]), center + offset, {"scale": .5, "prompt": Copy.copy(row[3], row[4])})
		if prop != null:
			var action := {"flag": String(row[0]), "value": String(row[1])}
			prop.set_meta("boss_scene_action", action)
			prop.interaction.set_meta("boss_scene_action", action)

func reset_encounter() -> void:
	generation += 1
	for timer in _timers:
		if timer != null and timer.is_valid():
			timer.kill()
	_timers.clear()
	events.clear()
	phase = 1
	combat_active = false
	judgement_flag = &""
	_seconds = 0.
	_cycle = 0.
	_watch_index = 0
	_watch_pause = 0.
	_ritual_index = 0
	_ritual_token += 1
	_salute_started = false
	_salute_finished = false
	_intro_remaining = 0.
	_desire_remaining = -1.
	_silence = 10.
	_mouth_hits = 0
	_deaf_remaining = 0.
	_lunge_delay = -1.
	_lunge_moving = false
	_decoy = null
	_invulnerable_boon = false
	_illusion_boon = false
	_hero_boon = false
	_personality = 0
	_memory_active = false
	_counter_ready = true
	_last_announced_attack = -1
	for mesh in _hidden_weapon_parts:
		if is_instance_valid(mesh): mesh.show()
	_hidden_weapon_parts.clear()
	if is_instance_valid(_lowered_axe): _lowered_axe.hide()
	if is_instance_valid(boss):
		boss.set_visual_frozen(false)
		boss.move_speed = _base_speed
		boss._content_phase_attacks = _original_attacks.duplicate(true)
	if is_instance_valid(player):
		player.set_visual_frozen(false)
		_last_embers = int(player.embers)
	for prop in props:
		if is_instance_valid(prop):
			prop.reset_prop()
			prop.global_position = prop.get_meta("home_position", prop.global_position)
			if prop.role.begins_with("judgement_") or prop.role.begins_with("escape_"):
				prop.set_enabled(false)
	if not aftermath_active:
		aftermath_completed = false

func start_encounter() -> void:
	combat_active = true
	_intro_remaining = 2.2 if boss_id in ["boss_nine_tails", "boss_zhu_yin", "boss_xing_tian"] else 0.
	if _intro_remaining > 0.:
		boss.set_visual_frozen(true)
	match boss_id:
		"boss_giant_gate": _say("四处旧灯，仍是它的守望。", "Four old braziers still mark its watch.")
		"boss_xing_tian": _say("两军都在等同一道终战的命令。", "Both armies await the same command to end the war.")
		"boss_nine_tails": _say("这里的记忆不属于你。你还愿意醒来吗？", "These memories are not yours. Will you still choose to wake?")
		"boss_xuan_xiao_wrath": _say("将怒意引向旧柱。", "Lead his wrath into the old pillars.")
		"boss_xuan_xiao_obsession": _say("炉火依次亮起，仪式仍未完成。", "The ritual fires kindle in sequence, forever unfinished.")
		"boss_xuan_xiao": _say("三道残识归来，未竟的飞升再次开始。", "Three fragments return. The unfinished ascension begins again.")
		"boss_zhu_yin": _say("旧轮回只会消耗灵魂。告诉我，你能选择怎样的未来？", "The old cycle consumes every soul. Show me a future you can choose.")
		"boss_blind_bell": _say("它没有眼睛。静下来，或摇响另一口铃。", "It has no eyes. Be still, or ring another bell.")

func on_phase(value: int) -> void:
	phase = value
	events["phase_" + str(value)] = true
	match boss_id:
		"boss_giant_gate":
			if value == 2:
				boss.set_visual_frozen(false)
				boss.move_speed = _base_speed * 1.2
				for index in 4:
					_later(float(index) * 1.5, _ignite_brazier.bind(index))
		"boss_xing_tian":
			if value == 2:
				for prop in _roles("chain_"):
					prop.illuminate(Color("e27646"), .6)
					_later(1.2, prop.break_apart.bind(center))
				boss.move_speed = _base_speed * 1.5
			elif value == 3:
				boss.move_speed = _base_speed * 1.16
				for mesh: MeshInstance3D in boss.visual_root.find_children("*", "MeshInstance3D", true, false):
					var part_name := String(mesh.name)
					if (part_name.begins_with("axe_") and part_name.contains("_l")) or part_name.begins_with("grip_wrap_l"):
						mesh.hide()
						_hidden_weapon_parts.append(mesh)
				_lowered_axe.global_position = boss.global_position + Vector3(1.8, .16, 0.)
				_lowered_axe.rotation.z = PI * .5
				_lowered_axe.show()
				_say("怒意止息，刑天放下一斧，等待你的应答。", "His rage stills. Xing Tian lowers one axe and awaits your answer.")
		"boss_nine_tails":
			if value == 2:
				_spawn_clones(3, true)
			if value == 3:
				for prop in _roles("flower_"):
					prop.illuminate(Color("6689bd"), .25)
		"boss_xuan_xiao_obsession":
			_cycle = 6.
		"boss_xuan_xiao":
			if value >= 2:
				_spawn_clones(2, false)
			_cycle = 0.
		"boss_zhu_yin":
			if value == 3:
				for prop in _roles("debris_"):
					if not prop.is_broken:
						var tween := create_tween().set_loops()
						tween.tween_property(prop, "position:y", center.y + .8, 2.)
						tween.tween_property(prop, "position:y", center.y, 2.)
						_timers.append(tween)
		"boss_blind_bell":
			if value == 2:
				_say("聋世。高双响是快刺，低长鸣是横扫，三响是冲锋。", "Darkness. Two high notes: thrusts. One low toll: sweep. Three: charge.")

func _ignite_brazier(index: int) -> void:
	var prop := _role("watch_" + str(index))
	if prop == null or not combat_active:
		return
	prop.illuminate(Color("de7336"), 1.)
	_field({"id": prop.role, "color": "d47036", "radius": 2.1, "warning": 1.2, "lifetime": 0., "damage": 8., "interval": 1.}, prop.global_position)
	events[prop.role] = true

func _physics_process(delta: float) -> void:
	if aftermath_active:
		escape_remaining = escape_course.remaining
		return
	if not combat_active or not is_instance_valid(boss) or not is_instance_valid(player):
		return
	if float(player.health) <= 0. or bool(boss.is_in_story_resolution()):
		return
	_seconds += delta
	_cycle += delta
	if _intro_remaining > 0.:
		_intro_remaining -= delta
		if _intro_remaining <= 0.:
			boss.set_visual_frozen(false)
		return
	if _salute_started and not _salute_finished:
		return
	if _memory_active:
		return
	if int(boss.state) == boss.State.WINDUP and boss.attack_index != _last_announced_attack:
		_last_announced_attack = boss.attack_index
		on_windup(boss._active_attack_profile)
	match boss_id:
		"boss_giant_gate": _tick_watch(delta)
		"boss_nine_tails": _tick_fox(delta)
		"boss_xuan_xiao_wrath": _tick_wrath()
		"boss_xuan_xiao_obsession": _tick_ritual()
		"boss_xuan_xiao": _tick_personality()
		"boss_zhu_yin": _tick_cosmos(delta)
		"boss_blind_bell": _tick_bell(delta)

func _tick_watch(delta: float) -> void:
	if phase != 1:
		return
	var prop := _role("watch_" + str(_watch_index))
	if prop == null:
		return
	if _watch_pause > 0.:
		_watch_pause -= delta
		boss.set_visual_frozen(true)
		if _watch_pause <= 0.:
			boss.set_visual_frozen(false)
			_watch_index = (_watch_index + 1) % 4
			_cycle = 0.
		return
	# Give each stop a three-second punish window and each leg a combat window.
	if _cycle < 4.:
		return
	boss.combat_area.end_swing()
	var target := prop.global_position.lerp(center, .16)
	var direction := target - boss.global_position
	direction.y = 0.
	boss.set_visual_frozen(true)
	if direction.length() <= 1.:
		_watch_pause = 3.
		events["watch_stops"] = int(events.get("watch_stops", 0)) + 1
	else:
		# The baked walk surface sits half a voxel above the physical floor. A
		# smaller 3D waypoint tolerance otherwise traps the agent at its first point.
		boss.navigation_agent.path_desired_distance = maxf(boss.navigation_agent.path_desired_distance, .7)
		if boss.navigation_agent.target_position.distance_squared_to(target) > .01:
			boss.navigation_agent.target_position = target
		var travel: Vector3 = boss._safe_navigation_direction(target)
		boss.velocity = travel * 2.
		boss.velocity.y = -2.
		boss.move_and_slide()
		boss._face_direction(travel, delta * 5.)

func _tick_fox(delta: float) -> void:
	var ratio := float(boss.get_health_ratio())
	if ratio <= .5 and not events.has("wedding"):
		events["wedding"] = true
		_later(2.0, _wedding_procession)
	if phase >= 2 and _cycle >= 12.:
		_cycle = 0.
		_spawn_clones(3, true)
	if ratio <= .15 and not events.has("desire"):
		events["desire"] = true
		_desire_remaining = 10.
		_desire_attack = int(player.state)
		boss.set_visual_frozen(true)
		boss.combat_area.end_swing()
		_say("停留，便永远拥有这场梦。挥击，才能醒来。", "Remain, and the dream is yours forever. Strike to wake.")
		for prop in _roles("flower_"):
			prop.illuminate(Color("e5c58a"), .8)
	if _desire_remaining > 0.:
		_desire_remaining -= delta
		if _is_player_attacking():
			_desire_remaining = -1.
			boss.set_visual_frozen(false)
			events["desire_broken"] = true
		elif _desire_remaining <= 0.:
			_damage(player, float(player.max_health) * 5., boss.global_position, ["desire"])
			boss.set_visual_frozen(false)

func _wedding_procession() -> void:
	if not combat_active:
		return
	_say("狐嫁过境。破开幻花，便能散去宾客。", "The wedding passes. Break the flowers to disperse its guests.")
	for prop in _roles("flower_"):
		if not prop.is_broken:
			var guest = Clone.new()
			director.get_effect_parent().add_child(guest)
			guest.global_position = prop.global_position.lerp(center, .36)
			guest.set_meta("wedding_flower", prop.role)
			guest.setup({"lifetime": 15., "health": 1., "blocking": true, "model_id": "enemy/body/by_id/mind_lost_fox_demon"})
			director._request_navigation_update()
			guest.tree_exited.connect(director._request_navigation_update)

func _tick_wrath() -> void:
	var action := String(boss._active_attack_profile.get("name", ""))
	if int(boss.state) != boss.State.ACTIVE or not (action.contains("charge") or action.contains("slam")):
		return
	for prop in _roles("wrath_pillar_"):
		if not prop.is_broken and boss.global_position.distance_to(prop.global_position) <= 3.3:
			prop.break_apart(boss.global_position)
			boss._change_state(boss.State.STAGGER, 2., true)
			events["pillar_stagger"] = int(events.get("pillar_stagger", 0)) + 1
			break

func _tick_ritual() -> void:
	if _cycle < 7.:
		return
	_cycle = 0.
	var living: Array[Node3D] = []
	for prop in _roles("ritual_"):
		if not prop.is_broken:
			living.append(prop)
	if living.is_empty():
		return
	var altar: Node3D = living[_ritual_index % living.size()]
	_ritual_index += 1
	_ritual_token += 1
	var token := _ritual_token
	altar.illuminate(Color("7fc5dc"), 1.)
	_say("炉印正在聚拢——此刻打断它。", "The ritual gathers. Interrupt the seal now.")
	_later(2., func() -> void:
		if token != _ritual_token or not is_instance_valid(altar) or altar.is_broken:
			return
		_field({"id": "ritual_wave", "color": "70b6d2", "warning": 1.1, "radius": 4., "lifetime": 6., "damage": 6., "slow": .5}, player.global_position)
		_spawn_clones(1, false)
		events["ritual_completed"] = int(events.get("ritual_completed", 0)) + 1
		events["ritual_shield"] = true
		_later(5., func() -> void: events["ritual_shield"] = false)
	)

func _tick_personality() -> void:
	if phase < 3 or _cycle < 20.:
		return
	_cycle = 0.
	_personality = (_personality + 1) % 3
	var colors := [Color("eee2b4"), Color("ca6646"), Color("739ec6")]
	var anchor := _role("mind_" + str(_personality))
	if anchor != null and not anchor.is_broken:
		anchor.illuminate(colors[_personality], 1.)
		if _personality == 1:
			boss.move_speed = _base_speed * 1.7
			boss._content_phase_attacks[3] = [{"name": "wrathful_charge", "windup": .55, "active": .3, "recovery": .7, "damage": 30., "stagger": 36., "lunge": 5.5, "heavy": true}]
			_field({"id": "wrath_mind", "color": "ca6646", "warning": 1.2, "radius": 4., "lifetime": 7., "damage": 9.}, player.global_position)
		elif _personality == 2:
			boss.move_speed = _base_speed * .7
			boss._content_phase_attacks[3] = [{"name": "memory_ice_lance", "type": "projectile", "windup": .65, "active": .2, "recovery": .8, "damage": 22., "stagger": 16., "lunge": 0.}]
			_spawn_clones(2, false)
		else:
			boss.move_speed = _base_speed
			boss._content_phase_attacks[3] = _original_attacks.get(3, []).duplicate(true)
		events["personality"] = _personality

func _tick_cosmos(delta: float) -> void:
	if phase != 3:
		return
	if _cycle >= 15.:
		_cycle = 0.
		_gravity_flip *= -1.
		_say("引力将翻转——触碰星仪，稳住漂流。", "Gravity turns. Touch an orrery to steady your drift.")
		_later(1.5, func() -> void:
			if is_instance_valid(player):
				player.velocity.y = 4. * _gravity_flip
		)
		events["illusion_attack_active"] = true
		_field({"id": "soul_illusion", "color": "8976bf", "warning": 4., "radius": 4., "lifetime": 2., "damage": 24.}, player.global_position)
		_later(6., func() -> void: events["illusion_attack_active"] = false)
	# Soft altitude containment is local to this zero-G mechanic.
	if player.global_position.y > center.y + 6.:
		player.velocity.y = minf(player.velocity.y, -1.)
	if player.global_position.y < center.y + .3:
		player.velocity.y = maxf(player.velocity.y, .4)
	var flags = world.run_state
	if bool(flags.get_choice_flag("fate_zhu_yin_wrath", false)) and not events.has("wrath_echo"):
		events["wrath_echo"] = true
		_field({"id": "war_ember_echo", "color": "b6473c", "warning": 2., "radius": 3., "lifetime": 8., "damage": 8.}, player.global_position)
	if bool(flags.get_choice_flag("fate_heroes_aid", false)) and not _hero_boon:
		_hero_boon = true
		for index in 4:
			var hero = Clone.new()
			director.get_effect_parent().add_child(hero)
			hero.global_position = center + Vector3(cos(float(index) * PI * .5), 0., sin(float(index) * PI * .5)) * 5.
			hero.setup({"lifetime": 12., "health": 40., "attacker": player, "target": boss, "fighter": true, "friendly": true, "model_id": "enemy/body/by_id/temple_guardian_warrior"})
		events["heroes_aid"] = true
		_say("两军英魂应终战之令，为你破开星幕。", "The honored armies break the veil of stars for you.")

func _supernova() -> void:
	_field({"id": "supernova_warning", "warning": 5., "radius": radius - 1., "lifetime": .15, "color": "e2be69"}, center)
	_say("星核聚光。躲在漂浮残骸之后。", "The core gathers light. Shelter behind the floating debris.")
	for prop in _roles("debris_"):
		if not prop.is_broken:
			prop.illuminate(Color("bd935c"), .4)
	_later(5., func() -> void:
		if not combat_active:
			return
		if not protected_by_cover(player, center + Vector3.UP * 1.4):
			_damage(player, 70., center, ["supernova"])
		else:
			events["supernova_sheltered"] = int(events.get("supernova_sheltered", 0)) + 1
		events["supernova"] = int(events.get("supernova", 0)) + 1
	)

func _tick_bell(delta: float) -> void:
	_silence += delta
	_deaf_remaining = maxf(0., _deaf_remaining - delta)
	if _deaf_remaining > 0.:
		boss.set_visual_frozen(true)
		return
	var moving := Vector2(player.velocity.x, player.velocity.z).length()
	if moving > 4.8 or _is_player_attacking() or int(player.state) == player.State.DODGE:
		emit_noise(player.global_position, 2., null)
	if _lunge_delay >= 0.:
		_lunge_delay -= delta
		boss.set_visual_frozen(true)
		if _lunge_delay <= 0.:
			_lunge_delay = -1.
			_lunge_moving = true
			_lunge_remaining = 3.
			_lunge_goal = _decoy.global_position.lerp(center,.14) if is_instance_valid(_decoy) else _noise_position
		return
	if _lunge_moving:
		boss.set_visual_frozen(true)
		_lunge_remaining -= delta
		var direction: Vector3 = _lunge_goal-boss.global_position
		direction.y = 0.
		boss.velocity = direction.normalized()*9.
		boss.velocity.y = -2.
		boss.move_and_slide()
		boss._face_direction(direction.normalized(),delta*8.)
		if direction.length() <= 1.1 or _lunge_remaining <= 0.:
			_lunge_moving = false
			boss.velocity = Vector3.ZERO
			if direction.length() <= 1.1:
				if is_instance_valid(_decoy) and not _decoy.is_broken:
					_decoy.hits += 1
					_decoy.illuminate(Color("c37738"),float(_decoy.hits)*.2)
					if _decoy.hits >= 3: _decoy.break_apart(boss.global_position)
					events["decoy_hits"] = int(events.get("decoy_hits",0))+1
				elif player.global_position.distance_to(_noise_position)<2.5:
					_damage(player,28.,boss.global_position,["hearing_lunge"])
			_decoy = null
			boss.set_visual_frozen(false)
			_silence = 0.
		return
	if _silence >= 3.:
		boss.set_visual_frozen(true)
		boss.combat_area.end_swing()
		events["listening"] = true
	else:
		boss.set_visual_frozen(false)
		events["listening"] = false

func emit_noise(at: Vector3, strength: float, decoy: Node3D = null) -> void:
	if boss_id != "boss_blind_bell" or not combat_active or _deaf_remaining > 0.:
		return
	if (_lunge_delay >= 0. or _lunge_moving) and strength <= _noise_strength:
		return
	_noise_position = at
	_noise_strength = strength
	_silence = 0.
	_decoy = decoy
	if decoy != null or strength >= 5.:
		_lunge_delay = .9
		boss.combat_area.end_swing()
		_toll(1.2, 1)

func _on_embers_changed(amount: int) -> void:
	if amount > _last_embers:
		emit_noise(player.global_position, 10., null)
	_last_embers = amount

func _on_player_hit(_target: Node, _heavy: bool) -> void:
	# Mouth stuns are judged by BellMouthWeakpoint's physical overlap, never by
	# merely attacking the boss while standing near its center.
	pass

func register_mouth_hit() -> void:
	if boss_id != "boss_blind_bell" or not combat_active or _deaf_remaining > 0.: return
	_mouth_hits += 1
	if _mouth_hits >= 3:
		_mouth_hits = 0
		_deaf_remaining = 4.
		_lunge_delay = -1.
		_lunge_moving = false
		boss.combat_area.end_swing()
		events["mouth_stun"] = int(events.get("mouth_stun", 0)) + 1

func on_skill(attack: Dictionary) -> void:
	var action := String(attack.get("name", ""))
	if action == "supernova" and boss_id == "boss_zhu_yin":
		_supernova()
	if boss_id == "boss_giant_gate" and action in ["ember_slam", "overhead_slam"]:
		if float(boss.get_health_ratio()) <= .25:
			_field({"id": "desperate_crack", "color": "c66b40", "radius": 2.4, "warning": 1.8, "lifetime": 0., "damage": 8.}, player.global_position)

func on_windup(attack: Dictionary) -> void:
	if boss_id != "boss_blind_bell": return
	var action := String(attack.get("name", ""))
	_toll(.65 if action.contains("sweep") else 1.45, 3 if action.contains("triple") else (2 if action.contains("silent") else 1))
	events["announced_attack"] = action

func try_interact(prop: Node3D, actor: Node3D) -> bool:
	if actor != player or prop not in props or not prop.can_reach(actor):
		return false
	var role := String(prop.role)
	if role.begins_with("judgement_"):
		return _commit_prop(prop, actor)
	if aftermath_active and role == "escape_exit":
		complete_aftermath()
		return true
	if not combat_active:
		return false
	if role.begins_with("bell_"):
		emit_noise(prop.global_position, 6., prop)
		return true
	if role.begins_with("ritual_"):
		_ritual_token += 1
		events["ritual_shield"] = false
		prop.break_apart(actor.global_position)
		boss._change_state(boss.State.STAGGER, 2., true)
		events["ritual_interrupted"] = true
		return true
	if role.begins_with("flower_"):
		prop.break_apart(actor.global_position)
		return true
	if role == "truth_mirror":
		if not has_truth_mirror() or float(boss.get_health_ratio()) > .3:
			_say("真实之镜尚未寻回，或她仍拒绝直视。", "The true mirror is missing, or she is not yet ready to look.")
			return false
		events["mirror_used"] = true
		world.start_boss_scene_judgement(boss, &"ch3_nine_tails_fate")
		return true
	if role == "communion":
		if not String(player.get_active_class_id()).contains("berserker") or phase != 1:
			return false
		boss.receive_hit(maxf(0., float(boss.health) - float(boss.max_health) * .7), 0., Vector3.ZERO, player)
		player.grant_fate_damage_boost(1.25, 600.)
		player.stamina = player.max_stamina
		events["rage_communion"] = true
		prop.set_enabled(false)
		return true
	if role.begins_with("watch_") and phase >= 2:
		_clear_effects_containing(role)
		prop.illuminate(Color.WHITE, 0.)
		_later(8., _ignite_brazier.bind(int(role.trim_prefix("watch_"))))
		return true
	if role.begins_with("mind_"):
		prop.break_apart(actor.global_position)
		boss.move_speed = _base_speed
		boss._content_phase_attacks[3] = _original_attacks.get(3, []).duplicate(true)
		boss._change_state(boss.State.STAGGER, 2., true)
		return true
	if role == "dispel_mirror":
		if not bool(world.run_state.get_choice_flag("fate_dispel_illusion", false)) or events.has("illusion_dispelled") or not events.get("illusion_attack_active", false): return false
		events["illusion_dispelled"] = true
		events["illusion_attack_active"] = false
		_clear_effects_containing("soul_illusion")
		prop.set_enabled(false)
		return true
	if role.begins_with("gravity_") and phase == 3:
		var boosted := bool(world.run_state.get_choice_flag("fate_gravity_boost", false))
		player.velocity = Vector3(0, 3. if boosted else 1.8, 0)
		_later(2., func() -> void:
			if is_instance_valid(player): player.velocity.y = 0.
		)
		events["gravity_anchor"] = int(events.get("gravity_anchor", 0)) + 1
		return true
	return false

func has_truth_mirror() -> bool:
	return bool(world.has_story_item("true_mirror"))

func on_prop_hit(prop: Node3D, payload: Dictionary) -> bool:
	var role := String(prop.role)
	if role == "judgement_keeper" and judgement_flag == &"ending_state":
		var source = payload.get("source")
		if source != player or not prop.can_reach(player) or float(payload.get("damage", 0.)) <= 0.:
			return true
		prop.hits += 1
		prop.illuminate(Color("bd6444"), .25 * prop.hits)
		if prop.hits >= 3:
			prop.set_meta("boss_scene_action", {"flag": "ending_state", "value": "void"})
			if _commit_prop(prop, player):
				prop.break_apart(player.global_position)
		return true
	if not combat_active:
		return true
	if role.begins_with("bell_"):
		if payload.get("source") == player:
			emit_noise(prop.global_position, 6., prop)
		return true
	return false

func on_prop_broken(prop: Node3D) -> void:
	director._request_navigation_update()
	var role := String(prop.role)
	events["broken_" + role] = true
	if role.begins_with("flower_"):
		_clear_effects_containing("wedding_" + role)
		for clone in director.get_effect_parent().get_children():
			if clone.get_meta("illusion_clone", false) or clone.get_meta("wedding_flower", "") == role:
				clone.queue_free()
	if role.begins_with("ritual_"):
		_ritual_token += 1
		events["ritual_shield"] = false
		_say("炉底刻着同一句誓言：再试一次，便能救回他们。", "One vow covers the furnace: one more attempt will bring them home.")
	if role.begins_with("wrath_pillar_"):
		_say("断柱露出旧铭：他曾在此守住最后一群逃离天城的人。", "The broken pillar reveals a vow: here he protected the last people fleeing the city.")

func defer_story_judgement(flag: StringName) -> bool:
	if boss_id != "boss_xing_tian" or _salute_finished:
		return false
	if _salute_started:
		return true
	_salute_started = true
	boss.set_visual_frozen(true)
	boss.combat_area.end_swing()
	_say("刑天举斧致礼——最后一击将震裂大地。", "Xing Tian raises his axe in salute. The last strike will split the earth.")
	var strike := player.global_position
	_field({"id": "final_salute_warning", "color": "d19662", "radius": 5., "warning": 3., "lifetime": .2}, strike)
	_later(3., func() -> void:
		if not combat_active:
			return
		if player.global_position.distance_to(strike) <= 5.:
			_damage(player, 80., strike, ["final_salute"])
		for prop in props:
			if is_instance_valid(prop) and prop.role.begins_with("chain_"):
				prop.apply_boss_impact(strike, 5.)
		events["final_salute"] = true
		_salute_finished = true
		boss.set_visual_frozen(false)
		world.start_boss_scene_judgement(boss, flag)
	)
	return true

func on_story_judgement(flag: StringName) -> bool:
	judgement_flag = flag
	combat_active = false
	generation += 1
	boss.set_visual_frozen(false)
	player.set_visual_frozen(false)
	director._clear_live_effects()
	var count := 0
	for prop in _roles("judgement_"):
		var action: Dictionary = prop.get_meta("boss_scene_action", {})
		var available := String(action.get("flag", "")) == String(flag)
		if action.get("value") == "forge":
			available = available and Ending.reachable(world.run_state).has(&"forge")
		if action.get("value") == "redeemed":
			available = available and has_truth_mirror() and bool(events.get("mirror_used", false))
		if action.get("value") == "sealed":
			available = available and not bool(events.get("mirror_used", false)) and float(boss.health) <= 1.001
		prop.set_enabled(available)
		if available:
			prop.illuminate(Color("bea267"), .35)
			count += 1
	_say("战斗已停。走近遗物，以行动作答。", "Combat has ended. Approach the relics and answer through action.")
	director._request_navigation_update()
	return count > 0

func _commit_prop(prop: Node3D, actor: Node3D) -> bool:
	var action: Dictionary = prop.get_meta("boss_scene_action", {})
	if action.is_empty() or String(action.flag) != String(judgement_flag):
		return false
	if action.value == "redeemed" and not has_truth_mirror():
		return false
	if action.value == "forge" and not Ending.reachable(world.run_state).has(&"forge"):
		return false
	return bool(world.commit_boss_scene_action(boss, StringName(action.flag), String(action.value), actor, prop))

func begin_aftermath(_outcome: StringName) -> bool:
	if boss_id != "boss_xuan_xiao" or aftermath_completed:
		return false
	aftermath_active = true
	combat_active = false
	escape_course.begin()
	_say("天城正在坠落。九十息内越过断桥，奔向炉心敕印。", "The city falls. Cross the broken causeway to the Mandate in ninety seconds.")
	return true

func _escape_failed() -> void:
	if not aftermath_active: return
	events["escape_failed"] = int(events.get("escape_failed", 0)) + 1
	_damage(player, float(player.max_health) * 5., player.global_position, ["city_collapse"])
	# If an external invulnerability test mode rejects the lethal hit, the failed
	# course still cannot be completed. A normal death is handled by the world.
	if float(player.health) > 0.: retry_aftermath()

func retry_aftermath() -> bool:
	if not aftermath_active: return false
	escape_course.retry()
	escape_remaining = 90.
	events["escape_retries"] = int(events.get("escape_retries", 0)) + 1
	return true

func complete_aftermath() -> void:
	if not aftermath_active or escape_course.visited.size() < 11 or player.global_position.distance_to(escape_goal) > 4.:
		return
	aftermath_active = false
	aftermath_completed = true
	events["escape_complete"] = true
	world.finish_boss_aftermath(boss_id)

func begin_memory_gaze() -> void:
	if not combat_active: return
	_memory_active = true
	player.set_visual_frozen(true)
	events["memory_gaze"] = true
	for flower in _roles("flower_"):
		flower.illuminate(Color("9fcb8c"), .25)
	_say("那是狐族尚未被焚毁的林地。她守着别人的家，等了太久。", "An unburned forest: her people's home, remembered long after they were gone.")

func end_memory_gaze() -> void:
	_memory_active = false
	if is_instance_valid(player): player.set_visual_frozen(false)
	for flower in _roles("flower_"):
		flower.illuminate(Color.WHITE, 0.)

func filter_incoming_boss_damage(payload: Dictionary) -> Dictionary:
	if not combat_active or not is_instance_valid(boss): return payload
	var result := payload.duplicate(true)
	if boss_id == "boss_xing_tian" and phase == 3 and _counter_ready and String(boss._active_attack_profile.get("name", "")) == "honor_counter_stance" and int(boss.state) == boss.State.WINDUP:
		_counter_ready = false
		result["damage"] = 0.
		result["stagger"] = 0.
		result["poise"] = 0.
		var attack_point := player.global_position
		_field({"id": "honor_counter", "warning": .7, "radius": 2.3, "lifetime": .2, "damage": 40., "color": "c69e64"}, attack_point)
		events["honor_counter"] = int(events.get("honor_counter", 0)) + 1
		_later(2., func() -> void: _counter_ready = true)
	if boss_id == "boss_xuan_xiao_obsession" and events.get("ritual_shield", false):
		result["damage"] = float(result.get("damage", 0.)) * .35
	if boss_id == "boss_zhu_yin" and bool(world.run_state.get_choice_flag("fate_zhu_yin_weakness", false)):
		result["damage"] = float(result.get("damage", 0.)) * 1.1
	return result

func filter_incoming_player_damage(payload: Dictionary) -> Dictionary:
	if not combat_active or boss_id != "boss_zhu_yin":
		return payload
	var result := payload.duplicate(true)
	var run = world.run_state
	if not _invulnerable_boon and bool(run.get_choice_flag("fate_guardian_protection", false)) and float(result.get("damage", 0.)) > 0.:
		_invulnerable_boon = true
		result["damage"] = 0.
		result["stagger"] = 0.
		result["poise"] = 0.
		events["guardian_protection"] = true
		_say("巨阙的核心为你挡下了一击。", "The guardian core shields you from one blow.")
	elif not _illusion_boon and phase == 3 and bool(run.get_choice_flag("fate_safe_illusion", false)):
		_illusion_boon = true
		result["damage"] = 0.
		events["safe_illusion"] = true
		_spawn_clones(1, true, true)
	return result

func protected_by_cover(actor: Node3D, origin: Vector3) -> bool:
	if not is_instance_valid(actor) or not is_inside_tree():
		return false
	var query := PhysicsRayQueryParameters3D.create(origin, actor.global_position + Vector3.UP, 1)
	query.exclude = [boss.get_rid(), actor.get_rid()] if actor is CollisionObject3D else [boss.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var collider = hit["collider"]
	return collider in props and not collider.is_broken and (String(collider.role).begins_with("pillar_") or String(collider.role).begins_with("debris_"))

func _field(data: Dictionary, at: Vector3) -> Node3D:
	return director.spawn_story_effect(data, at)

func _clear_effects_containing(key: String) -> void:
	for child in director.get_effect_parent().get_children():
		if "specification" in child and String(child.specification.get("id", "")).contains(key):
			child.queue_free()

func _spawn_clones(count: int, illusion: bool, friendly := false) -> void:
	for index in count:
		var clone = Clone.new()
		director.get_effect_parent().add_child(clone)
		var angle := TAU * float(index) / maxi(count, 1) + .4
		clone.global_position = center + Vector3(cos(angle), 0., sin(angle)) * 5.
		clone.set_meta("illusion_clone", illusion)
		clone.setup({"lifetime": 15., "health": 1. if illusion else 35., "attacker": player if friendly else boss, "target": boss if friendly else player, "reflect_damage": 10. if illusion and not friendly else 0., "fighter": not illusion, "friendly": friendly, "model_id": "enemy/body/by_id/boss_nine_tails" if illusion else "enemy/body/by_id/temple_guardian_warrior"})

func _damage(actor: Node3D, amount: float, at: Vector3, tags: Array = []) -> void:
	actor.receive_hit_payload({"damage": amount, "stagger": 15., "poise": 15., "source": boss if is_instance_valid(boss) else null, "direction": (actor.global_position - at).normalized(), "tags": tags, "blockable": false, "parryable": false})

func _later(seconds: float, callback: Callable) -> void:
	var current := generation
	var tween := create_tween()
	_timers.append(tween)
	tween.tween_interval(seconds)
	tween.tween_callback(func() -> void:
		if current == generation and callback.is_valid():
			callback.call()
	)

func _role(role: String) -> Node3D:
	for prop in props:
		if is_instance_valid(prop) and String(prop.role) == role:
			return prop
	return null

func _roles(prefix: String) -> Array[Node3D]:
	var found: Array[Node3D] = []
	for prop in props:
		if is_instance_valid(prop) and String(prop.role).begins_with(prefix):
			found.append(prop)
	return found

func _is_player_attacking() -> bool:
	return int(player.state) in [player.State.ATTACK_WINDUP, player.State.ATTACK_ACTIVE, player.State.LEAP_ACTIVE, player.State.CAST, player.State.GUARD_THRUST]

func _toll(pitch: float, count: int) -> void:
	for index in count:
		_later(float(index) * .18, func() -> void:
			if is_instance_valid(world.audio):
				world.audio.play_cue("rest", -7., pitch)
		)

func _say(zh: String, en: String) -> void:
	if is_instance_valid(world) and is_instance_valid(world.hud):
		world.hud.show_message(Copy.copy(zh, en), 3.5)

func _on_resolved() -> void:
	combat_active = false
	if not aftermath_active:
		generation += 1

func _exit_tree() -> void:
	generation += 1
	for timer in _timers:
		if timer != null and timer.is_valid(): timer.kill()
	if is_instance_valid(player):
		player.set_visual_frozen(false)
