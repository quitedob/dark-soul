class_name PlayerSpells
extends RefCounted
## Spell casting, projectile spawning, and weapon-skill execution for the player.
## Composition helper — takes a player node reference and delegates spell logic.

const SpellProjectileScene = preload("res://scenes/components/spell_projectile.tscn")
const LocalizationScript = preload("res://scripts/core/localization.gd")
const CombatData = preload("res://scripts/data/player_combat_data.gd")
const SpiritSummonScript = preload("res://scripts/combat/spirit_summon.gd")

var _player: Node3D
var _world_node: Node
var _active_summons: Array = []
var _active_summon_kind := &"dharma_child"
## L-11：法术冷却表（cast_id -> 就绪毫秒时间戳），仅在带 cooldown 的施法上启用
var _cooldowns: Dictionary = {}


func setup(player_node: Node3D, world_node: Node) -> void:
	_player = player_node
	_world_node = world_node


# -- public API ------------------------------------------------------------


func try_cast_for_style(combat_style: int) -> String:
	## Returns the cast_id if a spell was begun, or "" if a style skill should be used.
	match combat_style:
		3: # VEILCRAFT
			begin_cast(&"veil_bolt", CombatData.SPELL_CONFIG["veil_bolt"]["focus_cost"], CombatData.SPELL_CONFIG["veil_bolt"]["cast_time"])
			return "veil_bolt"
		4: # EMBER_RITE
			begin_cast(&"ember_rite", CombatData.SPELL_CONFIG["ember_rite"]["focus_cost"], CombatData.SPELL_CONFIG["ember_rite"]["cast_time"])
			return "ember_rite"
		_:
			return ""


func begin_cast(cast_id: StringName, focus_cost: float, duration: float) -> bool:
	# L-11：冷却中禁止施法（不扣专注）
	if _is_on_cooldown(cast_id):
		return false
	if _player.focus < focus_cost:
		_player._show_message(LocalizationScript.text("NOT ENOUGH FOCUS"), 0.8)
		return false
	_player.focus = maxf(_player.focus - focus_cost, 0.0)
	_player._emit_focus()
	if cast_id == &"ember_rite":
		_player.healing_started.emit()
	_player._pending_cast = cast_id
	_player._cast_resolved = false
	_player._change_state(_player.State.CAST, duration)
	return true


func resolve_cast(pending_cast: StringName) -> void:
	var config: Dictionary = CombatData.SUMMON_CONFIG.get(String(pending_cast), CombatData.SPELL_CONFIG.get(String(pending_cast), {}))
	if config.is_empty():
		return
	if String(config.get("spell_type", "")) == "summon":
		_spawn_summon(config, String(pending_cast))
		return
	# L-11：带冷却的施法在真正释放时记入冷却
	var cooldown := float(config.get("cooldown", 0.0))
	if cooldown > 0.0:
		_set_cooldown(pending_cast, cooldown)
	match pending_cast:
		&"veil_bolt", &"bow_quick_shot", &"bow_power_shot", &"seal_burst", &"spirit_fire_bolt", &"torch_dragon_breath":
			spawn_spell_projectile(config, String(pending_cast))
			_player._play_audio("recover", -6.0, 1.3)
		&"arcane_barrage":
			for i in range(5):
				var spread_angle := deg_to_rad(-16.0 + float(i) * 8.0)
				var base_dir: Vector3 = -_player.camera.global_transform.basis.z
				var spread_dir: Vector3 = base_dir.rotated(Vector3.UP, spread_angle).normalized()
				var barrage_config := config.duplicate()
				barrage_config["proj_lifetime"] = config["proj_lifetime"] + randf_range(-0.15, 0.15)
				spawn_spell_projectile(barrage_config, "arcane_barrage", spread_dir)
			_player._show_message("ARCANE BARRAGE", 0.7)
			_player._play_audio("recover", -5.0, 1.1)
		&"foxfire":
			var orb_count := int(config.get("orb_count", 3))
			for i in range(orb_count):
				var spread_angle := deg_to_rad(-20.0 + float(i) * 20.0)
				var fox_base_dir: Vector3 = -_player.camera.global_transform.basis.z
				var fox_dir: Vector3 = fox_base_dir.rotated(Vector3.UP, spread_angle).normalized()
				spawn_spell_projectile(config, "foxfire", fox_dir)
			_player._show_message("FOXFIRE", 0.7)
			_player._play_audio("recover", -5.0, 1.1)
		&"divine_smite":
			spawn_spell_projectile(config, "divine_smite")
			_player._show_message("DIVINE SMITE", 0.7)
			_player._play_audio("heavy", -5.0, 0.9)
		&"ember_rite":
			var heal_amount: float = config.get("heal", 28.0)
			var aoe_damage: float = config.get("aoe_damage", 22.0)
			var aoe_stagger: float = config.get("aoe_stagger", 20.0)
			var aoe_range: float = config.get("aoe_range", 6.0)
			_player.health = minf(_player.health + heal_amount, _player.max_health)
			_player._emit_stats()
			if _world_node != null and _world_node.has_method("get_target_candidates"):
				for candidate in _world_node.get_target_candidates():
					if candidate is Node3D and _player.global_position.distance_to(candidate.global_position) <= aoe_range:
						var direction: Vector3 = (
							candidate.global_position - _player.global_position
						).normalized()
						candidate.receive_hit(aoe_damage, aoe_stagger, direction, _player)
			_player._show_message(LocalizationScript.text("EMBER RITE CAST"), 0.75)
			_player._play_audio("rest", -4.0, 0.82)
		# -- L-11 法术 --
		&"restful_prayer":
			_player.health = minf(_player.health + float(config.get("heal", 40.0)), _player.max_health)
			_player._emit_stats()
			_player._show_message("RESTFUL PRAYER", 0.75)
			_player._play_audio("rest", -4.0, 0.9)
		&"stop_bleed", &"mind_clearing":
			# 状态（流血/净化）目标系统未实现：诚实降级为治疗 + 提示
			_player.health = minf(_player.health + float(config.get("heal", 15.0)), _player.max_health)
			_player._emit_stats()
			_player._show_message("STOP BLEED" if pending_cast == &"stop_bleed" else "MIND CLEARING", 0.7)
			_player._play_audio("rest", -4.0, 0.85)
		&"war_cry":
			_player.grant_fate_damage_boost(
				float(config.get("damage_multiplier", 1.15)),
				float(config.get("buff_duration", 45.0))
			)
			_player._show_message("WAR CRY", 0.8)
			_player._play_audio("heavy", -4.0, 0.9)
		&"iron_skin", &"furnace_oath", &"divine_soldier", &"immortality_mantra":
			if float(config.get("heal", 0.0)) > 0.0:
				_player.health = minf(_player.health + float(config["heal"]), _player.max_health)
				_player._emit_stats()
			_apply_armor_buff(
				float(config.get("pdr_boost", 0.2)),
				float(config.get("buff_duration", 30.0))
			)
			_player._show_message(_display_name(pending_cast), 0.8)
			_player._play_audio("heavy", -4.0, 0.85)
		&"fox_blessing":
			_apply_speed_buff(
				float(config.get("speed_multiplier", 1.15)),
				float(config.get("buff_duration", 40.0))
			)
			_player._show_message("FOX BLESSING", 0.8)
			_player._play_audio("rest", -4.0, 0.9)
		&"torch_contract":
			_player.grant_fate_damage_boost(
				float(config.get("damage_multiplier", 1.25)),
				float(config.get("buff_duration", 20.0))
			)
			_apply_armor_buff(
				-float(config.get("pdr_penalty", 0.25)),
				float(config.get("buff_duration", 20.0))
			)
			_player._show_message("TORCH CONTRACT", 0.8)
			_player._play_audio("heavy", -4.0, 0.9)
		&"ascension_prayer":
			_apply_gravity_buff(
				float(config.get("gravity_factor", 0.4)),
				float(config.get("buff_duration", 30.0))
			)
			_player._show_message("ASCENSION", 0.8)
			_player._play_audio("rest", -4.0, 0.9)
		&"soul_forger_memory":
			var forger_roll := randi() % 3
			var forger_duration := float(config.get("buff_duration", 20.0))
			if forger_roll == 0:
				_player.grant_fate_damage_boost(1.2, forger_duration)
				_player._show_message("FORGER: DAMAGE", 0.8)
			elif forger_roll == 1:
				_apply_speed_buff(1.2, forger_duration)
				_player._show_message("FORGER: SPEED", 0.8)
			else:
				_apply_armor_buff(0.25, forger_duration)
				_player._show_message("FORGER: ARMOR", 0.8)
			_player._play_audio("heavy", -5.0, 0.9)
		&"void_step":
			_teleport_player(float(config.get("teleport_range", 8.0)))
			_player._show_message("VOID STEP", 0.7)
			_player._play_audio("dodge", -6.0, 0.9)
		&"mirror_moon_swap":
			var swap_target: Node3D = _player.lock_target
			if swap_target != null and is_instance_valid(swap_target):
				var player_pos := _player.global_position
				var target_pos := swap_target.global_position
				swap_target.global_position = player_pos
				_player.global_position = target_pos
				_player._show_message("MIRROR SWAP", 0.7)
			else:
				_teleport_player(float(config.get("teleport_range", 15.0)))
				_player._show_message("MIRROR STEP", 0.7)
			_player.velocity = Vector3.ZERO
			_player._play_audio("dodge", -6.0, 0.95)
		&"mirror_clone", &"illusion_phantoms":
			var clone_count := int(config.get("clone_count", 1))
			var clone_lifetime := float(config.get("clone_lifetime", 3.0))
			for _i in range(clone_count):
				_spawn_spirit_ally(String(pending_cast), &"dharma_child", clone_lifetime, 0.0)
			_player._show_message(_display_name(pending_cast), 0.8)
			_player._play_audio("recover", -5.0, 1.1)
		&"beacon_signal", &"hero_spirit":
			_spawn_spirit_ally(
				String(pending_cast),
				&"dharma_child",
				float(config.get("lifetime", 45.0)),
				float(config.get("reserved_focus", 10.0))
			)
			_player._show_message(_display_name(pending_cast), 0.8)
			_player._play_audio("recover", -5.0, 0.9)
		&"battle_spirit":
			var summon_dmg_mult := float(config.get("summon_damage_mult", 1.3))
			var boosted_count := 0
			for summon in _active_summons:
				if is_instance_valid(summon) and "damage" in summon:
					summon.damage = float(summon.damage) * summon_dmg_mult
					boosted_count += 1
			_player._show_message(
				"BATTLE SPIRIT x%d" % boosted_count if boosted_count > 0 else "BATTLE SPIRIT",
				0.8
			)
			_player._play_audio("heavy", -4.0, 0.9)
		&"ksitigarbha_vow":
			_player.health = minf(_player.health + float(config.get("heal", 25.0)), _player.max_health)
			_player._emit_stats()
			var revived_count := 0
			for summon in _active_summons:
				if is_instance_valid(summon) and "health" in summon and "max_health" in summon:
					summon.health = summon.max_health
					revived_count += 1
			_player._show_message(
				"KSITIGARBHA VOW x%d" % revived_count if revived_count > 0 else "KSITIGARBHA VOW",
				0.8
			)
			_player._play_audio("rest", -4.0, 0.9)
		&"soul_release":
			var release_threshold := float(config.get("release_threshold", 0.3))
			var release_damage := float(config.get("release_damage", 999.0))
			var release_range := float(config.get("aoe_range", 10.0))
			var released_count := 0
			if _world_node != null and _world_node.has_method("get_target_candidates"):
				for candidate in _world_node.get_target_candidates():
					if not (candidate is Node3D):
						continue
					if _player.global_position.distance_to(candidate.global_position) > release_range:
						continue
					if not ("health" in candidate and "max_health" in candidate):
						continue
					if float(candidate.health) <= float(candidate.max_health) * release_threshold:
						candidate.receive_hit(release_damage, 0.0, -_player.global_transform.basis.z, _player)
						released_count += 1
			_player._show_message(
				"SOUL RELEASE x%d" % released_count if released_count > 0 else "SOUL RELEASE",
				0.8
			)
			_player._play_audio("heavy", -5.0, 0.9)
		&"scripture_scroll":
			var scroll_roll := randi() % 10
			if scroll_roll < 5:
				var bolt_cfg := config.duplicate()
				bolt_cfg["damage"] = 22.0
				bolt_cfg["proj_speed"] = 16.0
				bolt_cfg["proj_lifetime"] = 2.0
				bolt_cfg["homing"] = true
				spawn_spell_projectile(bolt_cfg, "scripture_scroll")
				_player._show_message("SCROLL: BOLT", 0.7)
			elif scroll_roll < 8:
				_player.health = minf(_player.health + float(config.get("heal", 30.0)), _player.max_health)
				_player._emit_stats()
				_player._show_message("SCROLL: HEAL", 0.7)
			else:
				_apply_speed_buff(1.25, 20.0)
				_player._show_message("SCROLL: SPEED", 0.7)
			_player._play_audio("recover", -5.0, 1.0)
		&"furnace_fire_ring", &"mind_confusion", &"great_silence":
			_aoe_damage(
				float(config.get("aoe_range", 5.0)),
				float(config.get("damage", 26.0)),
				float(config.get("stagger", 30.0))
			)
			_player._show_message(_display_name(pending_cast), 0.8)
			_player._play_audio("heavy", -5.0, 0.9)
		&"heavenly_thunder":
			_aoe_damage_delayed(
				float(config.get("delay", 2.0)),
				float(config.get("aoe_range", 8.0)),
				float(config.get("damage", 48.0)),
				float(config.get("stagger", 34.0))
			)
			_player._show_message("HEAVENLY THUNDER", 0.8)
			_player._play_audio("heavy", -6.0, 0.8)
		&"rot_touch":
			var touch_range := float(config.get("aoe_range", 2.5))
			var dot_damage := float(config.get("dot_damage", 5.0))
			var dot_ticks := int(config.get("dot_ticks", 4))
			_aoe_damage(touch_range, float(config.get("damage", 12.0)), float(config.get("stagger", 8.0)))
			# Celestial Rot：延时多次 tick 近似 DoT
			for tick in range(dot_ticks):
				_aoe_damage_delayed(0.6 + float(tick) * 0.7, touch_range, dot_damage, 0.0)
			_player._show_message("ROT TOUCH", 0.8)
			_player._play_audio("recover", -5.0, 0.9)
		&"void_rift":
			var rift_range := float(config.get("aoe_range", 7.0))
			var pull_delay := float(config.get("explode_delay", 0.6))
			if _world_node != null and _world_node.has_method("get_target_candidates"):
				for candidate in _world_node.get_target_candidates():
					if not (candidate is Node3D):
						continue
					if _player.global_position.distance_to(candidate.global_position) > rift_range:
						continue
					var pull_dir: Vector3 = _player.global_position - candidate.global_position
					pull_dir.y = 0.0
					if pull_dir.length_squared() < 0.001:
						pull_dir = Vector3.FORWARD
					pull_dir = pull_dir.normalized()
					candidate.receive_hit(0.0, 6.0, pull_dir, _player)
			_aoe_damage_delayed(
				pull_delay,
				rift_range,
				float(config.get("damage", 38.0)),
				float(config.get("stagger", 30.0))
			)
			_player._show_message("VOID RIFT", 0.8)
			_player._play_audio("heavy", -6.0, 0.85)
		&"final_flame":
			var self_cost_ratio := float(config.get("self_hp_cost", 0.3))
			_player.health = maxf(_player.health - _player.max_health * self_cost_ratio, 1.0)
			_player._emit_stats()
			_aoe_damage(
				float(config.get("aoe_range", 12.0)),
				float(config.get("damage", 65.0)),
				float(config.get("stagger", 40.0))
			)
			_player._show_message("FINAL FLAME", 0.9)
			_player._play_audio("heavy", -3.0, 0.7)


func spawn_spell_projectile(config: Dictionary, action_id: String, override_direction: Vector3 = Vector3.ZERO) -> void:
	var projectile = SpellProjectileScene.instantiate()
	var cast_direction: Vector3 = override_direction if override_direction.length_squared() > 0.001 else -_player.camera.global_transform.basis.z
	var lock_target: Node3D = _player.lock_target
	if lock_target != null and is_instance_valid(lock_target) and override_direction.length_squared() < 0.001:
		var target_point: Vector3 = (
			lock_target.get_target_point()
			if lock_target.has_method("get_target_point")
			else lock_target.global_position
		)
		cast_direction = (
			target_point
			- (_player.global_position + Vector3.UP * 1.25)
		).normalized()

	var item_id: String = _player.right_hand_item
	var proj_damage: float = config.get("damage", 28.0)
	var proj_stagger: float = config.get("stagger", 18.0)

	var homing: Node3D = null
	if bool(config.get("homing", false)) and lock_target != null and is_instance_valid(lock_target):
		homing = lock_target

	var is_spell := action_id in [
		"veil_bolt", "seal_burst", "arcane_barrage", "divine_smite",
		"spirit_fire_bolt", "foxfire", "torch_dragon_breath", "scripture_scroll",
	]

	projectile.setup(_player, cast_direction, proj_damage, proj_stagger, {
		"hand": "right",
		"item_id": item_id,
		"action_id": action_id,
		"tags": ["projectile", "spell" if is_spell else "physical"],
		"blockable": true,
		"parryable": false,
		"spell_type": String(config.get("spell_type", "default")),
		"proj_speed": float(config.get("proj_speed", 15.0)),
		"proj_lifetime": float(config.get("proj_lifetime", 2.2)),
		"homing_target": homing,
		"homing_strength": float(config.get("homing_strength", 0.0)),
	})

	var projectile_parent: Node = (
		_world_node
		if _world_node != null and _world_node.is_inside_tree()
		else _player.get_tree().current_scene
	)
	projectile_parent.add_child(projectile)
	projectile.global_position = _player.global_position + Vector3.UP * 1.25 + cast_direction * 0.8

	var message_key := _display_name(StringName(action_id))
	if action_id == "bow_quick_shot" or action_id == "bow_power_shot":
		message_key = "QUICK SHOT" if action_id == "bow_quick_shot" else "POWER SHOT"
	elif action_id == "veil_bolt":
		message_key = "VEIL BOLT"
	elif action_id == "seal_burst":
		message_key = "SEAL BURST"
	elif action_id == "arcane_barrage":
		message_key = "ARCANE BARRAGE"
	elif action_id == "divine_smite":
		message_key = "DIVINE SMITE"
	_player._show_message(message_key, 0.6)


func try_arcane_barrage() -> bool:
	var cfg: Dictionary = CombatData.SPELL_CONFIG["arcane_barrage"]
	if _player.focus < cfg["focus_cost"]:
		_player._show_message(LocalizationScript.text("NOT ENOUGH FOCUS"), 0.8)
		return false
	_player.focus = maxf(_player.focus - cfg["focus_cost"], 0.0)
	_player._emit_focus()
	_player._pending_cast = &"arcane_barrage"
	_player._cast_resolved = false
	_player._change_state(_player.State.CAST, 0.55)
	return true


func try_divine_smite() -> bool:
	var cfg: Dictionary = CombatData.SPELL_CONFIG["divine_smite"]
	if _player.focus < cfg["focus_cost"]:
		_player._show_message(LocalizationScript.text("NOT ENOUGH FOCUS"), 0.8)
		return false
	_player.focus = maxf(_player.focus - cfg["focus_cost"], 0.0)
	_player._emit_focus()
	_player._pending_cast = &"divine_smite"
	_player._cast_resolved = false
	_player._change_state(_player.State.CAST, 0.68)
	return true


# -- L-06 召唤物 API ---------------------------------------------------------


## 当前灵符装备的召唤 spell id（默认护法灵童）
func active_summon_spell_id() -> StringName:
	return StringName("summon_%s" % String(_active_summon_kind))


## 切换灵符当前召唤的灵（护法灵童/金甲力士/往生莲/怨灵/白鹤童子）
func set_active_summon(kind: StringName) -> void:
	_active_summon_kind = kind


## 开始一次召唤施法（扣专注 → CAST 状态 → resolve_cast 分支生成灵）
func try_summon(spell_id: StringName) -> bool:
	var cfg: Dictionary = CombatData.SUMMON_CONFIG.get(String(spell_id), {})
	if cfg.is_empty():
		return false
	var cost := float(cfg.get("focus_cost", 30.0))
	if _player.focus < cost:
		_player._show_message(LocalizationScript.text("NOT ENOUGH FOCUS"), 0.8)
		return false
	_player.focus = maxf(_player.focus - cost, 0.0)
	_player._emit_focus()
	_player._pending_cast = spell_id
	_player._cast_resolved = false
	_player._change_state(_player.State.CAST, float(cfg.get("cast_time", 0.7)))
	return true


## 遣散全部在场召唤物（保留占用返还）
func dismiss_all() -> void:
	for summon in _active_summons:
		if is_instance_valid(summon) and summon.has_method("_despawn"):
			summon._despawn()
	_active_summons.clear()


func summon_count() -> int:
	return _active_summons.size()


## 生成召唤物；灵消失时返还 reserved_focus
func _spawn_summon(config: Dictionary, action_id: String) -> void:
	if _world_node == null or not _world_node.is_inside_tree():
		_player._show_message(LocalizationScript.text("CANNOT SUMMON HERE"), 0.8)
		return
	var kind := StringName(String(config.get("kind", "dharma_child")))
	var reserved := float(config.get("reserved_focus", 0.0))
	var summon := SpiritSummonScript.new()
	summon.name = "SpiritSummon_%s" % String(kind)
	summon.position = _player.global_position + Vector3(0.0, 0.0, 1.6)
	summon.setup(kind, _player, _world_node)
	var refund := reserved
	summon.despawned.connect(func(_s): _refund_focus(refund))
	_world_node.add_child(summon)
	_active_summons.append(summon)
	_player._show_message(LocalizationScript.text("SPIRIT SUMMONED"), 0.8)
	_player._play_audio("recover", -5.0, 0.9)


## 召唤物消失：返还保留专注
func _refund_focus(amount: float) -> void:
	if amount <= 0.0 or _player == null or not is_instance_valid(_player):
		return
	_player.focus = minf(_player.focus + amount, _player.max_focus)
	_player._emit_focus()


# -- L-11 辅助 ------------------------------------------------------------------


## 可读显示名（snake_case → "SOME SPELL"）
func _display_name(cast_id: StringName) -> String:
	return String(cast_id).replace("_", " ").to_upper()


## 冷却检查：冷却中返回 true 并提示剩余秒数；过期即清除
func _is_on_cooldown(cast_id: StringName) -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	if not _cooldowns.has(cast_id):
		return false
	var ready_at := int(_cooldowns[cast_id])
	if Time.get_ticks_msec() >= ready_at:
		_cooldowns.erase(cast_id)
		return false
	var remain := int(ceil((ready_at - Time.get_ticks_msec()) / 1000.0))
	_player._show_message("%s CD %dS" % [_display_name(cast_id), remain], 0.8)
	return true


## 记录冷却（毫秒时间戳）
func _set_cooldown(cast_id: StringName, seconds: float) -> void:
	if seconds <= 0.0:
		return
	_cooldowns[cast_id] = Time.get_ticks_msec() + int(seconds * 1000.0)


## 临时增益到期后恢复（通过 SceneTreeTimer）
func _apply_timed_restore(duration: float, restore: Callable) -> void:
	if _player == null or not is_instance_valid(_player) or _player.get_tree() == null:
		return
	_player.get_tree().create_timer(maxf(duration, 0.1)).timeout.connect(func():
		if _player != null and is_instance_valid(_player) and restore.is_valid():
			restore.call()
	)


## 临时物伤减免增益（恢复快照值）
func _apply_armor_buff(boost: float, duration: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var original: float = _player.armor_pdr
	_player.armor_pdr = maxf(_player.armor_pdr + boost, -0.5)
	_apply_timed_restore(duration, func():
		if _player != null and is_instance_valid(_player):
			_player.armor_pdr = original
	)


## 临时移速增益（恢复快照值）
func _apply_speed_buff(multiplier: float, duration: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var orig_move: float = _player.move_speed
	var orig_sprint: float = _player.sprint_speed
	_player.move_speed = orig_move * multiplier
	_player.sprint_speed = orig_sprint * multiplier
	_apply_timed_restore(duration, func():
		if _player != null and is_instance_valid(_player):
			_player.move_speed = orig_move
			_player.sprint_speed = orig_sprint
	)


## 临时重力增益（恢复快照值）
func _apply_gravity_buff(factor: float, duration: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var original: float = _player.gravity
	_player.gravity = original * factor
	_apply_timed_restore(duration, func():
		if _player != null and is_instance_valid(_player):
			_player.gravity = original
	)


## 面向方向固定距离传送；Y 保持地面高度
func _teleport_player(distance: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var forward := -_player.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.001:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	var target := _player.global_position + forward * distance
	target.y = _player.global_position.y
	_player.global_position = target
	_player.velocity = Vector3.ZERO


## 玩家周身 AoE 伤害（命中方向=朝外，敌人据此击退）
func _aoe_damage(aoe_range: float, damage: float, stagger: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if _world_node == null or not _world_node.has_method("get_target_candidates"):
		return
	for candidate in _world_node.get_target_candidates():
		if not (candidate is Node3D):
			continue
		if _player.global_position.distance_to(candidate.global_position) > aoe_range:
			continue
		var hit_dir: Vector3 = candidate.global_position - _player.global_position
		hit_dir.y = 0.0
		if hit_dir.length_squared() < 0.001:
			hit_dir = -_player.global_transform.basis.z
		candidate.receive_hit(damage, stagger, hit_dir.normalized(), _player)


## 延迟 AoE（在施法原点，施法后再起跳）
func _aoe_damage_delayed(delay: float, aoe_range: float, damage: float, stagger: float) -> void:
	if _player == null or not is_instance_valid(_player) or _player.get_tree() == null:
		return
	var origin := _player.global_position
	_player.get_tree().create_timer(maxf(delay, 0.05)).timeout.connect(func():
		if _player == null or not is_instance_valid(_player):
			return
		if _world_node == null or not _world_node.has_method("get_target_candidates"):
			return
		for candidate in _world_node.get_target_candidates():
			if not (candidate is Node3D):
				continue
			if origin.distance_to(candidate.global_position) > aoe_range:
				continue
			var hit_dir: Vector3 = candidate.global_position - origin
			hit_dir.y = 0.0
			if hit_dir.length_squared() < 0.001:
				hit_dir = -_player.global_transform.basis.z
			candidate.receive_hit(damage, stagger, hit_dir.normalized(), _player)
	)


## 灵体盟友（英雄/烽火/分身）：复用召唤机制，kind 不在 KIND_DATA 时回退护法灵童
func _spawn_spirit_ally(cast_id: String, kind: StringName, lifetime: float, reserved: float) -> void:
	var cfg := {
		"kind": String(kind),
		"reserved_focus": reserved,
		"focus_cost": 0.0,
		"cast_time": 0.0,
		"spell_type": "summon",
	}
	var before := _active_summons.size()
	_spawn_summon(cfg, cast_id)
	if _active_summons.size() > before:
		var ally = _active_summons.back()
		if is_instance_valid(ally) and lifetime > 0.0:
			ally._lifetime_left = lifetime
