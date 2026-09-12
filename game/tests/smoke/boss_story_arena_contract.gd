extends SceneTree
## Real worlds/actors/props; isolated in-memory run state. Timers and collision
## publish through engine frames, while unrelated boss AI is held deterministic.
const WorldScene = preload("res://scenes/world/ashen_hollow.tscn")
const CombatArea = preload("res://scripts/combat_area.gd")
class AuditWorld extends "res://scripts/game_world.gd":
	func _load_initial_state() -> void: _apply_settings()
	func _save_run(_reason: String) -> bool: return true
var world: AuditWorld
var failures: Array[String] = []
var checks := 0
var arena: Node3D
var boss: Node3D
var player: Node3D

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	world = AuditWorld.new()
	var contents := WorldScene.instantiate()
	for child in contents.get_children():
		child.owner = null
		contents.remove_child(child)
		world.add_child(child)
	contents.free()
	root.add_child(world)
	await process_frame
	world.set_process(false)
	player = world.player
	world.run_state.inventory["keeper_rune"] = 1
	var selected := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--section="): selected = arg.trim_prefix("--section=")
	for entry in ["giant","xing","fox","wrath","obsession","xuan","zhu","bell"]:
		if not selected.is_empty() and entry not in selected.split(","): continue
		print("BOSS_STORY_BEGIN ",entry)
		await Callable(self,"_"+entry).call()
		print("BOSS_STORY_END ",entry," failures=",failures.size())
	world.free()
	await _frames(3)
	for message in failures: push_error(message)
	print("BOSS_STORY_ARENA_COUNTS bosses=8 checks=%d failures=%d" % [checks, failures.size()])
	if failures.is_empty(): print("ASHEN_BOSS_STORY_ARENA_OK")
	quit(0 if failures.is_empty() else 1)

func _load(id: StringName) -> void:
	_expect(world._load_campaign_level(id), "loads " + String(id))
	player = world.player
	player.set_physics_process(false)
	player.max_health = 500.
	player.health = 500.
	player.state = player.State.LOCOMOTION
	boss = world.guardian
	arena = world._arena_director.story_props
	_expect(is_instance_valid(arena), "actual story arena " + String(id))
	await _frames(4)
	player.global_position = world._boss_boundary.center + Vector3(0,.1,world._boss_boundary.radius-3.)
	await _frames(4)
	_expect(world._boss_boundary.combat_is_active() and arena.combat_active, "physical entry activates story mechanics " + String(id))
	boss.set_physics_process(false)
	arena.set_physics_process(false)
	arena._intro_remaining = 0.
	boss.set_visual_frozen(false)
	player.global_position = arena.center + Vector3(0,.1,5.)
	for prop in arena.props:
		_expect(not prop.visual.find_children("*", "MeshInstance3D", true, false).is_empty(), "authored mesh " + prop.role)
		_expect(not prop._shapes.is_empty(), "physical object " + prop.role)

func _giant() -> void:
	await _load(&"level_01_05")
	_expect(arena._roles("pillar_").size() == 4 and arena._roles("watch_").size() == 4, "four protective pillars and four watches")
	var pillar = arena._role("pillar_0")
	pillar.receive_hit(999.,0.,Vector3.ZERO,player)
	_expect(not pillar.is_broken, "guardian pillars survive player damage")
	arena._cycle = 4.
	var watch = arena._role("watch_0")
	boss.global_position = arena.center+Vector3.UP*.1
	boss.combat_area.begin_swing(25.,0.)
	await _frames(10)
	for frame in 720:
		arena._tick_watch(1./60.)
		await _frames(1)
		if arena._watch_pause > 0.: break
	print("GIANT_WATCH position=",boss.global_position," target=",watch.global_position.lerp(arena.center,.16)," capsule_radius=",boss.body_collision.shape.radius," path=",boss.navigation_agent.get_current_navigation_path())
	_expect(arena._watch_pause == 3., "arriving at a watch opens three-second punish window")
	_expect(not boss.combat_area.active,"watch movement and punish pause cannot retain an old damaging swing")
	boss.receive_hit(boss.health-boss.max_health*.59,0.,Vector3.ZERO,player)
	await _seconds(1.7)
	_expect(arena.phase == 2 and arena.events.has("watch_1"), "60 percent ignites braziers sequentially")
	player.global_position = arena.center
	_expect(not arena.try_interact(watch,player), "distant smother rejected")
	player.global_position = watch.global_position + Vector3(0,0,2.5)
	_expect(arena.try_interact(watch,player), "nearby brazier can be smothered")
	await _frames(2)
	var found := false
	for child in world._arena_director.get_effect_parent().get_children():
		if "specification" in child and child.specification.get("id") == "watch_0": found = true
	_expect(not found, "smother cancels actual fire damage volume")
	player.global_position = arena.center + Vector3(0,.1,arena.radius+5.)
	boss.reset_enemy()
	await _seconds(.2)
	_expect(not arena.combat_active and world._arena_director.get_effect_parent().get_child_count() == 0, "retry cancels fire and pending phase callbacks")

func _xing() -> void:
	await _load(&"level_02_06")
	boss.receive_hit(boss.health-boss.max_health*.29,0.,Vector3.ZERO,player)
	await _seconds(1.35)
	_expect(arena._roles("chain_").all(func(p): return p.is_broken), "70 percent breaks physical chains")
	_expect(arena._hidden_weapon_parts.size() >= 5 and arena._lowered_axe.visible, "30 percent lowers authored left axe")
	boss._active_attack_profile = {"name":"honor_counter_stance"}
	boss.state = boss.State.WINDUP
	var health: float = boss.health
	boss.receive_hit(10.,0.,Vector3.ZERO,player)
	_expect(is_equal_approx(boss.health,health) and arena.events.has("honor_counter"), "attacking counter stance rejects damage and arms delayed riposte")
	boss.state = boss.State.IDLE
	world._arena_director._clear_live_effects()
	player.global_position = arena.center + Vector3(0,.1,6.)
	var before: float = player.health
	boss.receive_hit(9999.,0.,Vector3.ZERO,player)
	_expect(arena._salute_started and not boss.is_in_story_resolution(), "ordinary damage starts salute before story judgement")
	_expect(not arena.try_interact(arena._role("judgement_honored"),player), "honor cannot be committed before final strike")
	await _seconds(3.2)
	_expect(arena._salute_finished and boss.is_in_story_resolution(), "salute completion enables judgement")
	_expect(is_equal_approx(player.health,before-80.), "unescaped final salute deals exactly eighty damage")
	var relic = arena._role("judgement_honored")
	player.global_position = relic.global_position + Vector3(0,0,2.)
	_expect(arena.try_interact(relic,player), "honor relic commits validated scene action")
	_expect(world.run_state.get_choice_flag("ch2_xingtian_fate","") == "honored", "honor choice stored")

func _fox() -> void:
	world.run_state.inventory["true_mirror"] = 1
	await _load(&"level_03_06")
	boss.receive_hit(boss.health-boss.max_health*.29,0.,Vector3.ZERO,player)
	_expect(not boss.is_in_story_resolution() and is_equal_approx(boss.health,boss.max_health*.29),"arriving with mirror does not auto-resolve at thirty percent")
	world.run_state.inventory.erase("true_mirror")
	await _load(&"level_03_06")
	world.run_state.inventory.erase("true_mirror")
	var mirror = arena._role("truth_mirror")
	player.global_position = mirror.global_position + Vector3(0,0,2.)
	_expect(not arena.try_interact(mirror,player), "mirror cannot be conjured in the boss arena")
	boss.receive_hit(boss.health-boss.max_health*.49,0.,Vector3.ZERO,player)
	await _frames(3)
	_expect(arena.events.get("memory_gaze",false), "50 percent invokes actual memory scene")
	await _seconds(1.8)
	arena._wedding_procession()
	await _frames(3)
	var guests: Array = []
	var clones: Array = []
	for child in world._arena_director.get_effect_parent().get_children():
		if child.has_meta("wedding_flower"): guests.append(child)
		if child.get_meta("illusion_clone",false): clones.append(child)
	_expect(guests.size() == 9 and guests[0].collision_layer & 1, "nine modeled wedding guests block actual movement")
	if not clones.is_empty():
		var before: float = player.health
		clones[0].receive_hit(1.,0.,Vector3.ZERO,player)
		_expect(is_equal_approx(player.health,before-10.), "one HP illusion reflects exactly ten damage")
	else: _expect(false,"phase2 spawned illusion clones")
	var flower = arena._role("flower_0")
	await _melee(flower,40.)
	_expect(flower.is_broken,"actual player CombatArea breaks a flower")
	await _frames(3)
	var remaining_guests := 0
	for child in world._arena_director.get_effect_parent().get_children():
		if child.has_meta("wedding_flower"): remaining_guests += 1
	_expect(remaining_guests == 8,"breaking flower removes its blocking wedding guest")
	boss.receive_hit(boss.health-boss.max_health*.14,0.,Vector3.ZERO,player)
	boss.combat_area.begin_swing(25.,0.)
	arena._tick_fox(0.)
	_expect(arena._desire_remaining == 10., "15 percent starts ten-second temptation")
	_expect(not boss.combat_area.active,"temptation cancels the previous active hitbox")
	player.state = player.State.ATTACK_ACTIVE
	arena._tick_fox(.1)
	_expect(arena.events.get("desire_broken",false),"an actual attack state breaks temptation")
	player.state = player.State.LOCOMOTION
	world.run_state.inventory["true_mirror"] = 1
	player.global_position = mirror.global_position + Vector3(0,0,2.)
	_expect(arena.try_interact(mirror,player),"recovered true mirror opens redemption at low health")
	var redemption = arena._role("judgement_redeemed")
	player.global_position = redemption.global_position + Vector3(0,0,2.)
	_expect(arena.try_interact(redemption,player),"physical mirror redemption commits")
	_expect(world.run_state.get_choice_flag("ch3_nine_tails_fate","") == "redeemed","redemption stored")
	world.run_state.defeated_bosses.erase("boss_nine_tails")
	world.run_state.choice_flags.erase("ch3_nine_tails_fate")
	world.run_state.inventory.erase("true_mirror")
	await _load(&"level_03_06")
	boss.receive_hit(9999.,0.,Vector3.ZERO,player)
	_expect(boss.health == 1. and arena._role("judgement_sealed").enabled,"no-mirror ordinary damage stops at one HP and exposes sealing")
	_expect(not arena._role("judgement_redeemed").enabled,"redemption cannot be selected without actually using mirror")
	var seal = arena._role("judgement_sealed")
	player.global_position = seal.global_position+Vector3(0,0,2.)
	_expect(arena.try_interact(seal,player),"ordinary one-HP sealing commits from physical relic")

func _wrath() -> void:
	await _load(&"level_04_04")
	boss._active_attack_profile = {"name":"wrathful_charge"}
	boss.state = boss.State.ACTIVE
	var pillar = arena._role("wrath_pillar_0")
	arena._tick_wrath()
	_expect(not pillar.is_broken,"distant charge does not break unrelated architecture")
	boss.global_position = pillar.global_position + Vector3(2.8,0,0)
	arena._tick_wrath()
	_expect(pillar.is_broken and boss.state == boss.State.STAGGER,"lured charge shatters pillar and staggers Wrath")

func _obsession() -> void:
	await _load(&"level_04_05")
	arena._cycle = 7.
	arena._tick_ritual()
	var altar = arena._role("ritual_0")
	player.global_position = arena.center
	_expect(not arena.try_interact(altar,player),"ritual cannot be interrupted remotely")
	player.global_position = altar.global_position + Vector3(0,0,2.5)
	_expect(arena.try_interact(altar,player),"nearby altar interruption succeeds")
	await _seconds(2.2)
	_expect(not arena.events.has("ritual_completed"),"interruption cancels delayed summon and field")
	arena._cycle = 7.
	arena._tick_ritual()
	await _seconds(2.2)
	_expect(arena.events.get("ritual_completed",0) == 1,"uninterrupted ritual summons once")
	var before: float = boss.health
	boss.receive_hit(10.,0.,Vector3.ZERO,player)
	_expect(is_equal_approx(before-boss.health,3.5),"completed ritual shield changes actual incoming damage")
	var fighters: Array = []
	for child in world._arena_director.get_effect_parent().get_children():
		if "fighter" in child and child.fighter: fighters.append(child)
	_expect(not fighters.is_empty(),"ritual creates a real animated attacking guardian")
	if not fighters.is_empty():
		var fighter = fighters[0]
		fighter.set_physics_process(false)
		fighter.global_position = player.global_position + Vector3(1.5,0,0)
		var hp: float = player.health
		fighter._physics_process(3.)
		_expect(player.health < hp,"summoned guardian actually attacks")

func _xuan() -> void:
	await _load(&"level_04_06")
	boss.receive_hit(boss.health-boss.max_health*.29,0.,Vector3.ZERO,player)
	arena._cycle = 20.
	arena._tick_personality()
	_expect(boss._content_phase_attacks[3][0].name == "wrathful_charge","Wrath dominance changes actual attack table")
	arena._cycle = 20.
	arena._tick_personality()
	_expect(boss._content_phase_attacks[3][0].name == "memory_ice_lance","Obsession dominance changes actual attack table")
	var anchor = arena._role("mind_2")
	player.global_position = anchor.global_position + Vector3(0,0,2.)
	_expect(arena.try_interact(anchor,player) and anchor.is_broken,"mind anchor can be physically quieted")
	boss.receive_hit(9999.,0.,Vector3.ZERO,player)
	var relic = arena._role("judgement_ascended")
	player.global_position = relic.global_position + Vector3(0,0,2.)
	_expect(arena.try_interact(relic,player),"ascension commits before escape")
	await _frames(3)
	var course = arena.escape_course
	_expect(arena.aftermath_active and course.active and world._boss_aftermath_pending,"post-boss course remains active after victory")
	_expect(course.goal.distance_to(arena.center) > arena.radius + 50.,"escape extends beyond arena")
	_expect(course.platforms.size() == 13,"escape has thirteen modeled physical courts")
	for pad in course.platforms:
		var ray := PhysicsRayQueryParameters3D.create(pad.global_position+Vector3.UP,pad.global_position-Vector3.UP,1)
		_expect(not world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"course floor physically supports actor")
	var gap: Vector3 = (course.platforms[2].global_position+course.platforms[3].global_position)*.5
	var query := PhysicsRayQueryParameters3D.create(gap+Vector3.UP,gap-Vector3.UP*2.,1)
	_expect(world.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),"jump gap has no concealed floor collider")
	course.collapse(3)
	await _frames(3)
	var at: Vector3 = course.platforms[3].get_meta("original_transform").origin
	query = PhysicsRayQueryParameters3D.create(at+Vector3.UP,at-Vector3.UP*2.,1)
	_expect(world.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),"collapse removes actual floor collision")
	player.global_position = course.checkpoint-Vector3.UP*5.
	course._physics_process(.01)
	await _frames(3)
	_expect(arena.aftermath_active,"failure does not restart boss combat")
	arena.retry_aftermath()
	await _frames(3)
	_expect(course.collapsed.is_empty() and player.global_position.distance_to(course.checkpoint)<.1,"retry restores course checkpoint and floor")
	player.global_position = course.goal
	arena.complete_aftermath()
	_expect(arena.aftermath_active,"teleport to exit cannot skip route checkpoints")
	arena.retry_aftermath()
	await _frames(3)
	var saved: Dictionary = world._snapshot_run_state()
	var saved_embers := int(player.embers)+int(world.run_state.lost_echo_amount)
	world._apply_run_state(preload("res://scripts/core/run_state.gd").from_dictionary(saved))
	await _frames(4)
	arena = world._arena_director.story_props
	course = arena.escape_course
	player.set_physics_process(false)
	_expect(course.active and arena.aftermath_active and player.global_position.distance_to(course.checkpoint)<.1,"full Continue restores unfinished course checkpoint")
	var restored_embers := int(player.embers)+int(world.run_state.lost_echo_amount)
	print("ESCAPE_CONTINUE guardian=",world.guardian," saved_total=",saved_embers," restored_total=",restored_embers)
	_expect(world.guardian == null and restored_embers==saved_embers,"Continue neither revives boss nor duplicates its reward")
	await _walk_course(course)
	_expect(arena.aftermath_completed and not world._boss_aftermath_pending,"actual capsule traverses ramps/jumps before escape judgement")

func _zhu() -> void:
	for flag in ["fate_safe_illusion","fate_guardian_protection","fate_heroes_aid","fate_zhu_yin_wrath","fate_zhu_yin_weakness"]:
		world.run_state.set_choice_flag(flag,false)
	await _load(&"level_05_05")
	boss.receive_hit(boss.health-boss.max_health*.39,0.,Vector3.ZERO,player)
	await _frames(3)
	_expect(player.gravity_override == 0.,"40 percent enters zero gravity")
	world._arena_director._clear_live_effects()
	world.run_state.set_choice_flag("fate_guardian_protection",true)
	var hp: float = player.health
	player.receive_hit_payload({"damage":20.,"source":boss,"blockable":false,"parryable":false})
	_expect(player.health == hp,"guardian core prevents first incoming hit")
	world.run_state.set_choice_flag("fate_safe_illusion",false)
	player.receive_hit_payload({"damage":20.,"source":boss,"blockable":false,"parryable":false})
	_expect(player.health < hp,"guardian protection cannot repeat")
	world.run_state.set_choice_flag("fate_safe_illusion",true)
	hp = player.health
	player.receive_hit_payload({"damage":20.,"source":boss,"blockable":false,"parryable":false})
	_expect(player.health == hp and arena.events.get("safe_illusion",false),"redeemed fox provides one real safe illusion")
	world.run_state.set_choice_flag("fate_safe_illusion",false)
	world.run_state.set_choice_flag("fate_heroes_aid",true)
	world.run_state.set_choice_flag("fate_zhu_yin_wrath",true)
	arena._tick_cosmos(0.)
	var heroes: Array = []
	for effect in world._arena_director.get_effect_parent().get_children():
		if "fighter" in effect and effect.fighter and effect.friendly:
			heroes.append(effect)
			effect.set_physics_process(false)
	_expect(heroes.size()==4,"honored armies appear as four modeled allies")
	if not heroes.is_empty():
		var hp_boss: float = boss.health
		heroes[0].global_position = boss.global_position+Vector3(1.5,0,0)
		heroes[0]._physics_process(3.)
		_expect(boss.health<hp_boss,"honored army actually damages final boss")
	_expect(arena.events.get("wrath_echo",false),"absorbed war ember adds the final boss wrath field")
	var gravity_prop = arena._role("gravity_0")
	player.global_position = gravity_prop.global_position+Vector3(0,0,2.)
	world.run_state.set_choice_flag("fate_gravity_boost",false)
	_expect(arena.try_interact(gravity_prop,player),"normal gravity anchor interaction")
	var normal_impulse: float = player.velocity.y
	world.run_state.set_choice_flag("fate_gravity_boost",true)
	_expect(arena.try_interact(gravity_prop,player) and player.velocity.y>normal_impulse,"ascended fate increases actual gravity-control impulse")
	world.run_state.set_choice_flag("fate_zhu_yin_weakness",true)
	var hp_boss: float = boss.health
	boss.receive_hit(10.,0.,Vector3.ZERO,player)
	_expect(is_equal_approx(hp_boss-boss.health,11.),"remembered remnant weak-point knowledge changes actual damage")
	world.run_state.set_choice_flag("fate_zhu_yin_weakness",false)
	world.run_state.set_choice_flag("fate_dispel_illusion",true)
	arena._cycle = 15.
	arena._tick_cosmos(0.)
	var mirror = arena._role("dispel_mirror")
	player.global_position = mirror.global_position + Vector3(0,0,2.)
	_expect(arena.try_interact(mirror,player),"sealed fox boon actively dispels an existing illusion")
	_expect(not arena.try_interact(mirror,player),"active dispel is one use")
	world._arena_director._clear_live_effects()
	var protected := false
	for prop in arena._roles("debris_"):
		for shape in prop._shapes:
			var direction: Vector3 = shape.global_position - (arena.center+Vector3.UP*1.4)
			player.global_position = shape.global_position + direction.normalized()*3.-Vector3.UP
			if arena.protected_by_cover(player,arena.center+Vector3.UP*1.4):
				protected = true
				break
		if protected: break
	_expect(protected,"modeled debris genuinely occludes a ray from supernova core")
	arena._supernova()
	hp = player.health
	await _seconds(5.2)
	_expect(arena.events.get("supernova_sheltered",0)==1 and is_equal_approx(player.health,hp),"debris shelters from delayed supernova")
	player.global_position = arena.center + Vector3(0,.1,3.)
	arena._supernova()
	hp = player.health
	await _seconds(5.2)
	_expect(is_equal_approx(player.health,hp-70.),"uncovered supernova deals exactly seventy")
	boss.receive_hit(9999.,0.,Vector3.ZERO,player)
	_expect(boss.is_in_story_resolution() and player.gravity_override<0.,"ten percent judgement restores gravity")
	_expect(not arena._role("judgement_forge").enabled,"hidden forge is unavailable without truth prerequisites")
	var throne = arena._role("judgement_keeper")
	player.global_position = throne.global_position+Vector3(0,0,2.)
	for index in 2: throne.receive_hit(1.,0.,Vector3.ZERO,player)
	_expect(world.run_state.get_choice_flag("ending_state","")=="","two throne strikes cannot prematurely choose void")
	throne.receive_hit(1.,0.,Vector3.ZERO,player)
	_expect(world.run_state.get_choice_flag("ending_state","")=="void","third physical throne strike selects void")
	for outcome in ["kindle","keeper","forge"]:
		world.run_state.defeated_bosses.erase("boss_zhu_yin")
		world.run_state.choice_flags.erase("ending_state")
		if outcome == "forge":
			for quest in ["quest_soul_return","quest_forge_last_question","quest_furnace_whisper"]:
				world.run_state.set_choice_flag("quest_stage_"+quest,"complete")
			for index in 4: world.run_state.set_choice_flag("furnace_memory_"+str(index+1),true)
		await _load(&"level_05_05")
		boss.receive_hit(9999.,0.,Vector3.ZERO,player)
		var relic = arena._role("judgement_"+outcome)
		player.global_position = relic.global_position+Vector3(0,0,2.)
		_expect(arena.try_interact(relic,player),"physical ending action " + outcome)
		_expect(world.run_state.get_choice_flag("ending_state","")==outcome,"ending committed " + outcome)

func _bell() -> void:
	await _load(&"level_05_06")
	_expect(arena._roles("bell_").size()==12,"twelve authoritative modeled decoys")
	var decoy = arena._role("bell_0")
	player.global_position = decoy.global_position+Vector3(0,0,2.)
	for index in 3:
		_expect(arena.try_interact(decoy,player),"decoy ring is reachable")
		for frame in 250:
			arena._tick_bell(1./60.)
			await _frames(1)
			if decoy.hits > index: break
	_expect(decoy.is_broken and decoy.get_node_or_null("BrokenVisual")!=null,"third lunge leaves actual broken bell model")
	_expect(not arena.try_interact(decoy,player),"broken decoy cannot lure a fourth time")
	player.velocity = Vector3.ZERO
	player.state = player.State.LOCOMOTION
	arena._silence = 3.1
	arena._tick_bell(.01)
	_expect(boss._visual_frozen,"silent player makes blind boss listen")
	arena._on_player_hit(boss,false)
	_expect(arena._mouth_hits==0,"ordinary nearby body hit is not a mouth hit")
	var mouth = arena.get_node("BellMouthWeakpoint")
	for index in 3: await _melee(mouth,1.)
	_expect(arena._deaf_remaining>0. and arena.events.get("mouth_stun",0)==1,"actual mouth overlap three times causes deaf stun")
	boss.reset_enemy()
	await _frames(3)
	_expect(not decoy.is_broken and decoy.hits==0 and arena._deaf_remaining==0.,"retry restores all decoy/hearing state")

func _melee(target: Node3D, damage: float) -> void:
	var carrier := Node3D.new()
	world.add_child(carrier)
	carrier.global_position = target.global_position + Vector3.UP
	var area := CombatArea.new()
	carrier.add_child(area)
	area.configure(player,1.4,2.8,Vector3.ZERO)
	area.collision_layer = 0
	area.collision_mask = 4
	await _frames(2)
	area.begin_swing(damage,0.,{"hitbox_radius":1.4,"hitbox_height":2.,"hitbox_offset":Vector3.ZERO})
	await _frames(3)
	area.end_swing()
	carrier.queue_free()
	await _frames(2)


func _walk_course(course: Node3D) -> void:
	var target_index := 1
	var jumps := 0
	for frame in 1800:
		if not course.active:
			print("COURSE_STOP frame=",frame," target=",target_index," position=",player.global_position," state=",player.state," jumps=",jumps," visited=",course.visited.keys())
			break
		var goal_point: Vector3 = course.platforms[target_index].global_position
		var offset: Vector3 = goal_point-player.global_position
		offset.y = 0.
		if offset.length() < .75 and target_index < 12:
			target_index += 1
			print("COURSE_STEP target=",target_index," position=",player.global_position," floor=",player.is_on_floor())
			continue
		if player.is_on_floor() and target_index % 3 == 0 and offset.length() < 5.7 and offset.length() > 4.3:
			player._try_jump()
			jumps += 1
		player.velocity.x = offset.normalized().x * 6.
		player.velocity.z = offset.normalized().z * 6.
		player.velocity.y -= player.gravity/60.
		player.move_and_slide()
		for collision_index in player.get_slide_collision_count():
			var collision = player.get_slide_collision(collision_index)
			if not course.is_ancestor_of(collision.get_collider()):
				print("COURSE_EXTERNAL_COLLISION ",collision.get_collider().get_path()," point=",collision.get_position())
		await _frames(1)
	print("COURSE_RESULT target=",target_index," position=",player.global_position," state=",player.state," jumps=",jumps," visited=",course.visited.keys())
	_expect(jumps >= 4,"course requires four actual character jumps")
	_expect(target_index == 12,"all thirteen court targets reached with capsule physics")

func _frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func _seconds(value: float) -> void:
	await create_timer(value).timeout
	await _frames(2)

func _expect(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
