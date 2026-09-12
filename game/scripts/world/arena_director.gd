# game/scripts/world/arena_director.gd
extends Node
signal navigation_changed
## Authored HP phases and named boss skills create level-owned physical effects.
## Warning precedes damage/collision; resets and ending choices cancel transients.

const ArenaEffect = preload("res://scripts/world/boss_arena_effect.gd")
const ArenaCover = preload("res://scripts/world/boss_arena_cover.gd")
const StoryProps = preload("res://scripts/world/boss_arena_story_props.gd")
const JarScene = preload("res://scenes/props/destructible_jar.tscn")

## 环带默认参数（build_arena options 可覆盖）
const DEFAULT_CHUNK_COUNT := 6
const DEFAULT_RING_RADIUS := 8.5
const DEFAULT_JAR_COUNT := 5
const JAR_MIN_CENTER_DIST := 3.0
const JAR_MIN_SPACING := 1.6
## 坍塌编排默认节奏（研究值：rumble 1.0-1.5s / 邻柱错峰 0.1-0.2s / 沉降 TRANS_QUAD EASE_IN）
const DEFAULT_RUMBLE_TIME := 1.2
const DEFAULT_SINK_TIME := 1.5
const DEFAULT_CHUNK_STAGGER := 0.12
const SINK_DEPTH := 12.0

var host: Node3D = null
var trauma_shake = null  # TraumaShake 实例（后注入，可能为 null）
var ring_collapsed := false

var _chunks: Array[Dictionary] = []  # {node, collision, mat, base_position, jitter_tween, flash_tween}
var _jars: Array[Node3D] = []
var _rumble_time := DEFAULT_RUMBLE_TIME
var _sink_time := DEFAULT_SINK_TIME
var _chunk_stagger := DEFAULT_CHUNK_STAGGER
var _boss: Node3D
var _center := Vector3.ZERO
var _arena_radius := 18.0
var _floor_y := 0.0
var _options: Dictionary = {}
var _fired_phases: Dictionary = {}
var _combat_stopped := false
var _effects_root: Node3D
var _event_tweens: Array[Tween] = []
var phase_event_count := 0
var skill_event_count := 0
var _navigation_update_pending := false
var story_props: Node3D
var encounter_boundary: Node


## 绑定布景父节点（所有生成的柱/罐挂其下）
func setup(host_node: Node3D) -> void:
	host = host_node


## 世界节点后注入震屏组件（null 安全：注入前不震）
func set_trauma_shake(shake) -> void:
	trauma_shake = shake


## 构建竞技场：center 环心（取 x/z），floor_y 地面高度。
## options: boss / arena_radius / ring_radius / floor_y and optional cover timings/counts.
func build_arena(center: Vector3, options := {}) -> void:
	if host == null or not is_instance_valid(host):
		push_warning("arena_director: setup(host) 未调用，跳过 build_arena")
		return
	_clear_existing()
	_center = center
	_options = options.duplicate()
	_arena_radius = maxf(5., float(options.get("arena_radius", 18.)))
	_floor_y = float(options.get("floor_y", center.y))
	_fired_phases.clear()
	_combat_stopped = false
	phase_event_count = 0
	skill_event_count = 0
	_effects_root = Node3D.new()
	_effects_root.name = "BossArenaTransient"
	host.add_child(_effects_root)
	_bind_boss(options.get("boss") as Node3D)
	ring_collapsed = false
	_rumble_time = maxf(float(options.get("rumble_time", DEFAULT_RUMBLE_TIME)), 0.05)
	_sink_time = maxf(float(options.get("sink_time", DEFAULT_SINK_TIME)), 0.05)
	_chunk_stagger = maxf(float(options.get("chunk_stagger", DEFAULT_CHUNK_STAGGER)), 0.0)
	var floor_y := _floor_y
	var ring_radius := maxf(float(options.get("ring_radius", DEFAULT_RING_RADIUS)), 5.0)
	if is_instance_valid(_boss) and bool(_boss.chapter_content.get("story_arena", false)):
		if not is_instance_valid(story_props):
			story_props = StoryProps.new()
			host.add_child(story_props)
			story_props.setup(self, _boss, center, _arena_radius)
		else:
			story_props.reset_encounter()
		if is_instance_valid(encounter_boundary):
			story_props.bind_encounter(encounter_boundary)
	else:
		_build_ring(center, floor_y, ring_radius, int(options.get("chunk_count", DEFAULT_CHUNK_COUNT)))
		_build_jars(center, floor_y, ring_radius, int(options.get("jar_count", DEFAULT_JAR_COUNT)), options)


## Boss 相变入口：读 content 表 phases[str(phase)].arena_event（同 boss_phase_polisher 的 vfx 读法）
func on_boss_phase(enemy: Node3D, new_phase: int) -> void:
	if not is_instance_valid(enemy) or (_boss != null and enemy != _boss):
		return
	if _boss == null:
		_bind_boss(enemy)
	_apply_phase(new_phase)


## Boss 死亡：温和清理残柱（快速沉降、无震屏，不打扰胜利镜头）
func on_boss_died() -> void:
	_combat_stopped = true
	_clear_live_effects()
	_cancel_event_tweens()
	ring_collapsed = true
	for entry in _chunks:
		var node = entry.get("node")
		if not is_instance_valid(node):
			continue
		_kill_entry_tweens(entry)
		var collision = entry.get("collision")
		if is_instance_valid(collision):
			collision.set_deferred("disabled", true)
		if not is_inside_tree():
			continue
		var base_y := (entry["base_position"] as Vector3).y
		var sink := create_tween()
		_event_tweens.append(sink)
		entry["sink_tween"] = sink
		sink.tween_property(node, "global_position:y", base_y - SINK_DEPTH, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		sink.tween_callback(node.queue_free)
	_request_navigation_update()


# -- 内部 -------------------------------------------------------------------


## Imported chapter cover, foot-aligned physical box, destructible by real impacts.
func _build_ring(center: Vector3, floor_y: float, ring_radius: float, chunk_count: int) -> void:
	var count := maxi(chunk_count, 3)
	for i in range(count):
		var ang := TAU * float(i) / float(count) + PI / 6.0
		var chunk = ArenaCover.new()
		chunk.name = "ArenaPlinth%d" % i
		host.add_child(chunk)
		var layout: Dictionary = host.get_meta("modeled_layout", {})
		if not chunk.setup(StringName(String(layout.get("theme", "theme_spirit_ruins")))):
			chunk.queue_free()
			continue
		chunk.broken.connect(_on_cover_broken.bind(chunk))
		var base := Vector3(
			center.x + cos(ang) * ring_radius,
			floor_y,
			center.z + sin(ang) * ring_radius
		)
		chunk.global_position = base
		_chunks.append({
			"node": chunk,
			"collision": chunk.collision,
			"mat": chunk.materials[0] if not chunk.materials.is_empty() else null,
			"base_position": base,
			"jitter_tween": null,
			"flash_tween": null,
			"sink_tween": null,
		})


## 环内散布可破坏药罐：避开中心 3m、罐间距下限；固定种子可复现
func _build_jars(center: Vector3, floor_y: float, ring_radius: float, jar_count: int, options: Dictionary) -> void:
	var count := maxi(jar_count, 0)
	if count == 0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(options.get("seed", "ashen_arena_l26")))
	var inner := JAR_MIN_CENTER_DIST + 1.5
	var outer := maxf(ring_radius - 1.5, inner + 1.0)
	var placed: Array[Vector3] = []
	var tries := 0
	while placed.size() < count and tries < count * 40:
		tries += 1
		var dist := rng.randf_range(inner, outer)
		var ang := rng.randf() * TAU
		var pos := Vector3(center.x + cos(ang) * dist, floor_y, center.z + sin(ang) * dist)
		var ok := true
		for other in placed:
			if Vector2(other.x, other.z).distance_to(Vector2(pos.x, pos.z)) < JAR_MIN_SPACING:
				ok = false
				break
		if ok:
			placed.append(pos)
	# 兜底：拒绝采样不足时按环角补齐
	var i := 0
	while placed.size() < count:
		var ang := TAU * float(i) / float(count) + 0.35
		var dist := lerpf(inner, outer, 0.5)
		placed.append(Vector3(center.x + cos(ang) * dist, floor_y, center.z + sin(ang) * dist))
		i += 1
	for pos in placed:
		var jar := JarScene.instantiate()
		jar.add_to_group("campaign_navigation_source")
		jar.broken.connect(_on_jar_broken)
		host.add_child(jar)
		jar.global_position = pos
		_jars.append(jar)


## 解析相变的 arena_event（空表/缺键安全返回 ""）
func _resolve_arena_event(enemy: Node3D, new_phase: int) -> String:
	if enemy == null or not is_instance_valid(enemy):
		return ""
	if not ("chapter_content" in enemy):
		return ""
	var content: Dictionary = enemy.chapter_content
	if content.is_empty():
		return ""
	var phases = content.get("phases", {})
	if typeof(phases) != TYPE_DICTIONARY:
		return ""
	var key := str(new_phase)
	if not phases.has(key):
		return ""
	var phase_data: Dictionary = phases[key]
	return String(phase_data.get("arena_event", ""))


## 坍塌编排：每柱错峰 0.12s → rumble 预警（抖动+emission 闪）→ 关碰撞 → 沉降 12m → 释放
func _collapse_ring() -> void:
	if ring_collapsed:
		return
	if _chunks.is_empty():
		return
	ring_collapsed = true
	# 公平链第一环：物理变化前先给震屏提示（组件可能未注入）
	if trauma_shake != null and trauma_shake.has_method("inject_weight"):
		trauma_shake.inject_weight(&"explosion")
	var tree := get_tree()
	if tree == null:
		return
	for i in range(_chunks.size()):
		var entry: Dictionary = _chunks[i]
		var node = entry.get("node")
		if not is_instance_valid(node):
			continue
		var rumble_delay := float(i) * _chunk_stagger
		var sink_delay := rumble_delay + _rumble_time
		var rumble := create_tween()
		rumble.tween_interval(rumble_delay)
		rumble.tween_callback(_start_rumble.bind(entry))
		_event_tweens.append(rumble)
		var sinking := create_tween()
		sinking.tween_interval(sink_delay)
		sinking.tween_callback(_sink_chunk.bind(entry))
		_event_tweens.append(sinking)



## rumble 预警：位置抖动（约 0.2s 一循环）+ emission 橙红预警闪
func _start_rumble(entry: Dictionary) -> void:
	if not is_inside_tree() or not is_instance_valid(entry.get("node")):
		return
	var node = entry.get("node")
	var mat: StandardMaterial3D = entry["mat"]
	var base: Vector3 = entry["base_position"]
	var offset := Vector3(0.06, 0.0, 0.06)
	var jitter := create_tween()
	jitter.set_loops()
	jitter.tween_property(node, "global_position", base + offset, 0.05)
	jitter.tween_property(node, "global_position", base - offset, 0.1)
	jitter.tween_property(node, "global_position", base, 0.05)
	entry["jitter_tween"] = jitter
	if node.has_method("set_warning"):
		node.set_warning(.4)
		var flash := create_tween().set_loops()
		flash.tween_method(node.set_warning, .4, 1.8, .18)
		flash.tween_method(node.set_warning, 1.8, .4, .18)
		entry["flash_tween"] = flash
	elif mat != null:
		mat.emission_enabled = true
		mat.emission = Color("ff5522")
		mat.emission_energy_multiplier = 0.4
		var flash := create_tween()
		flash.set_loops()
		flash.tween_property(mat, "emission_energy_multiplier", 1.8, 0.18)
		flash.tween_property(mat, "emission_energy_multiplier", 0.5, 0.18)
		entry["flash_tween"] = flash


## rumble 结束：停抖复位 → set_deferred 关碰撞 → TRANS_QUAD EASE_IN 沉降 12m → 释放
func _sink_chunk(entry: Dictionary) -> void:
	if not is_instance_valid(entry.get("node")):
		return
	_kill_entry_tweens(entry)
	var node = entry.get("node")
	var collision = entry.get("collision")
	node.global_position = entry["base_position"]
	if is_instance_valid(collision):
		collision.set_deferred("disabled", true)
	_request_navigation_update()
	if not is_inside_tree():
		node.queue_free()
		return
	var base_y := (entry["base_position"] as Vector3).y
	var sink := create_tween()
	_event_tweens.append(sink)
	entry["sink_tween"] = sink
	sink.tween_property(node, "global_position:y", base_y - SINK_DEPTH, _sink_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	sink.tween_callback(node.queue_free)


func _kill_entry_tweens(entry: Dictionary) -> void:
	for key in ["jitter_tween", "flash_tween", "sink_tween"]:
		var tween: Tween = entry.get(key)
		if tween != null and tween.is_valid():
			tween.kill()
		entry[key] = null


## 重复 build 前清理旧布景
func _clear_existing() -> void:
	_cancel_event_tweens()
	_clear_live_effects()
	if is_instance_valid(_effects_root):
		_effects_root.queue_free()
	_effects_root = null
	for entry in _chunks:
		_kill_entry_tweens(entry)
		var node = entry.get("node")
		if is_instance_valid(node):
			node.queue_free()
	_chunks.clear()
	for jar in _jars:
		if is_instance_valid(jar):
			jar.queue_free()
	_jars.clear()


func _bind_boss(enemy: Node3D) -> void:
	if is_instance_valid(_boss) and _boss != enemy:
		if _boss.has_signal("health_changed") and _boss.is_connected("health_changed", _on_health_changed):
			_boss.disconnect("health_changed", _on_health_changed)
		if _boss.has_signal("story_threshold_reached") and _boss.is_connected("story_threshold_reached", _on_story_threshold):
			_boss.disconnect("story_threshold_reached", _on_story_threshold)
		if _boss.has_signal("reset_completed") and _boss.is_connected("reset_completed", _on_boss_reset):
			_boss.disconnect("reset_completed", _on_boss_reset)
		if _boss.has_meta("boss_arena_director") and _boss.get_meta("boss_arena_director") == self:
			_boss.remove_meta("boss_arena_director")
	_boss = enemy
	if not is_instance_valid(_boss):
		return
	_boss.set_meta("boss_arena_director", self)
	if _boss.has_signal("health_changed") and not _boss.is_connected("health_changed", _on_health_changed):
		_boss.connect("health_changed", _on_health_changed)
	if _boss.has_signal("story_threshold_reached") and not _boss.is_connected("story_threshold_reached", _on_story_threshold):
		_boss.connect("story_threshold_reached", _on_story_threshold)
	if _boss.has_signal("reset_completed") and not _boss.is_connected("reset_completed", _on_boss_reset):
		_boss.connect("reset_completed", _on_boss_reset)


func _on_health_changed(current: float, maximum: float) -> void:
	if not is_instance_valid(_boss) or maximum <= 0.:
		return
	if current <= 0.:
		_combat_stopped = true
		_clear_live_effects()
		return
	var ratio := current / maximum
	if not _boss.has_signal("reset_completed") and ratio >= .999 and (not _fired_phases.is_empty() or _combat_stopped):
		build_arena(_center, _options)
		return
	if _combat_stopped or not ("chapter_content" in _boss):
		return
	var phases: Dictionary = _boss.chapter_content.get("phases", {})
	var numbers: Array[int] = []
	for key in phases:
		numbers.append(int(key))
	numbers.sort()
	for phase in numbers:
		if phase > 1 and ratio <= float(phases[str(phase)].get("threshold", 0.)) + .00001:
			_apply_phase(phase)


func _apply_phase(phase: int) -> void:
	if phase <= 1 or _combat_stopped or _fired_phases.has(phase) or not is_instance_valid(_boss):
		return
	var phases: Dictionary = _boss.chapter_content.get("phases", {}) if "chapter_content" in _boss else {}
	var data: Dictionary = phases.get(str(phase), {})
	if data.is_empty():
		return
	_fired_phases[phase] = true
	phase_event_count += 1
	_clear_live_effects()
	if is_instance_valid(story_props):
		story_props.on_phase(phase)
	var event := String(data.get("arena_event", ""))
	if event == "ring_collapse" or event == "chains_break":
		_collapse_ring()
	if event == "final_stillness":
		_combat_stopped = true
		return
	for specification: Dictionary in data.get("arena_effects", []):
		_spawn_pattern(specification, _center, Vector3.FORWARD, "phase_%d" % phase)


func _on_story_threshold(_flag: StringName, _ratio: float) -> void:
	if is_instance_valid(story_props) and story_props.defer_story_judgement(_flag):
		return
	_combat_stopped = true
	_clear_live_effects()


## Exact named attacks opt in via arena_effect; ordinary attack balance is unchanged.
func on_boss_skill(enemy: Node3D, target: Node3D, attack: Dictionary) -> bool:
	if _combat_stopped or not is_instance_valid(enemy) or enemy != _boss:
		return false
	if is_instance_valid(story_props):
		story_props.on_skill(attack)
	var raw: Variant = attack.get("arena_effect")
	if not raw is Dictionary or raw.is_empty():
		return false
	var data: Dictionary = raw
	var origin := enemy.global_position
	var direction := Vector3.FORWARD
	if is_instance_valid(target):
		direction = target.global_position - origin
		direction.y = 0.
		if direction.length_squared() > .001:
			direction = direction.normalized()
		if String(data.get("origin", "boss")) == "target":
			origin = target.global_position
	var count := _spawn_pattern(data, origin, direction, String(attack.get("name", "boss_skill")))
	if count > 0:
		skill_event_count += 1
	return count > 0

func filter_incoming_boss_damage(payload: Dictionary) -> Dictionary:
	return story_props.filter_incoming_boss_damage(payload) if is_instance_valid(story_props) else payload


func _spawn_pattern(data: Dictionary, origin: Vector3, direction: Vector3, event_id: String) -> int:
	if not is_instance_valid(_effects_root):
		return 0
	var count := clampi(int(data.get("count", 1)), 1, 8)
	var layout := String(data.get("layout", "point"))
	var distance := float(data.get("distance", _arena_radius * .5))
	var radius := float(data.get("radius", 1.5))
	var spawned := 0
	for index in count:
		var point := origin
		var angle := TAU * float(index) / float(count) + float(data.get("rotation", PI * .25))
		if layout == "ring":
			point += Vector3(cos(angle), 0., sin(angle)) * distance
		elif layout == "line":
			point += direction * (float(index) + 1.) * float(data.get("spacing", 2.2))
		var flat := point - _center
		flat.y = 0.
		var limit := maxf(1., _arena_radius - radius - 1.)
		if flat.length() > limit:
			point = _center + flat.normalized() * limit
		var supported: Variant = _supported_point(point)
		if supported == null:
			continue
		var effect = ArenaEffect.new()
		_effects_root.add_child(effect)
		effect.global_position = supported
		effect.global_rotation.y = -angle if layout == "ring" else atan2(direction.x, direction.z)
		var specification := data.duplicate(true)
		specification["id"] = event_id + "_%d" % index
		effect.setup(_boss, specification)
		effect.activated.connect(_on_effect_activated)
		effect.navigation_changed.connect(_request_navigation_update)
		spawned += 1
	return spawned


func _supported_point(point: Vector3) -> Variant:
	# Stub-only legacy contracts intentionally have no terrain. Runtime always binds a boss.
	if not _options.has("boss"):
		return Vector3(point.x, _floor_y, point.z)
	if not is_instance_valid(host) or not host.is_inside_tree():
		return null
	var query := PhysicsRayQueryParameters3D.create(Vector3(point.x, _floor_y + 2., point.z), Vector3(point.x, _floor_y - 2., point.z), 1)
	var excluded: Array[RID] = []
	for entry in _chunks:
		var chunk = entry.get("node")
		if is_instance_valid(chunk):
			excluded.append(chunk.get_rid())
	if is_instance_valid(_effects_root):
		for obstacle in _effects_root.find_children("*", "StaticBody3D", true, false):
			excluded.append(obstacle.get_rid())
	query.exclude = excluded
	var hit := host.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or (hit["normal"] as Vector3).dot(Vector3.UP) < .7:
		return null
	return hit["position"]


func _on_effect_activated(effect: Node3D) -> void:
	if not is_instance_valid(effect) or not bool(effect.specification.get("break_props", false)):
		return
	var point: Vector3 = effect.global_position
	var radius := float(effect.specification.get("radius", 1.5))
	# Limit mutations to this level. Other loaded scenes and the effect itself are excluded.
	for prop in get_tree().get_nodes_in_group("destructibles"):
		if is_instance_valid(prop) and host.is_ancestor_of(prop) and not effect.is_ancestor_of(prop):
			prop.apply_boss_impact(point, radius)
	effect.impact_applied = true


func get_effect_parent() -> Node3D:
	return _effects_root if is_instance_valid(_effects_root) else host


func get_arena_state() -> Dictionary:
	var effects: Array[Dictionary] = []
	if is_instance_valid(_effects_root):
		for effect in _effects_root.get_children():
			if "specification" in effect and not effect.is_queued_for_deletion():
				effects.append({"id": effect.specification.get("id", ""), "active": effect.active, "position": effect.global_position, "blocker": effect.specification.get("blocker", false)})
	return {"phases": _fired_phases.keys(), "phase_events": phase_event_count, "skill_events": skill_event_count, "stopped": _combat_stopped, "effects": effects, "story_events": story_props.events.duplicate() if is_instance_valid(story_props) else {}, "story_props": story_props.props.size() if is_instance_valid(story_props) else 0}


func bind_encounter(boundary: Node) -> void:
	encounter_boundary = boundary
	if is_instance_valid(story_props):
		story_props.bind_encounter(boundary)


func can_begin_encounter() -> bool:
	if not is_instance_valid(_boss) or String(_boss.content_id) != "boss_giant_gate":
		return true
	return bool(_boss.world_node.has_story_item("keeper_rune"))


func on_entry_denied() -> void:
	if is_instance_valid(story_props):
		story_props._say("旧印拒绝回应。先去炼丹房寻回守炉符文。", "The old seal refuses you. Recover the Keeper Rune in the Elixir Hall.")


func spawn_story_effect(specification: Dictionary, point: Vector3) -> Node3D:
	if not is_instance_valid(_effects_root):
		return null
	var effect := ArenaEffect.new()
	_effects_root.add_child(effect)
	effect.global_position = Vector3(point.x, _floor_y, point.z)
	effect.setup(_boss, specification)
	effect.activated.connect(_on_effect_activated)
	effect.navigation_changed.connect(_request_navigation_update)
	return effect


func defer_story_judgement(flag: StringName) -> bool:
	return bool(story_props.defer_story_judgement(flag)) if is_instance_valid(story_props) else false


func on_story_judgement(flag: StringName) -> bool:
	return bool(story_props.on_story_judgement(flag)) if is_instance_valid(story_props) else false


func begin_aftermath(outcome: StringName) -> bool:
	return bool(story_props.begin_aftermath(outcome)) if is_instance_valid(story_props) else false


func retry_aftermath() -> bool:
	return bool(story_props.retry_aftermath()) if is_instance_valid(story_props) else false


func complete_aftermath() -> void:
	if is_instance_valid(story_props):
		story_props.complete_aftermath()


func filter_incoming_player_damage(payload: Dictionary) -> Dictionary:
	return story_props.filter_incoming_player_damage(payload) if is_instance_valid(story_props) else payload


func _clear_live_effects() -> void:
	if is_instance_valid(_effects_root):
		for child in _effects_root.get_children():
			child.queue_free()


func _cancel_event_tweens() -> void:
	for tween in _event_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_event_tweens.clear()


func _on_boss_reset(enemy: Node3D) -> void:
	if enemy == _boss:
		build_arena(_center, _options)
		_request_navigation_update()


func _on_cover_broken(_point: Vector3, cover: Node3D) -> void:
	for entry in _chunks:
		if is_instance_valid(entry.get("node")) and entry["node"] == cover:
			_kill_entry_tweens(entry)
	_request_navigation_update()


func _on_jar_broken(_point: Vector3) -> void:
	_request_navigation_update()


func _request_navigation_update() -> void:
	if _navigation_update_pending or not is_inside_tree():
		return
	_navigation_update_pending = true
	call_deferred("_emit_navigation_update")


func _emit_navigation_update() -> void:
	_navigation_update_pending = false
	if is_inside_tree() and is_instance_valid(host) and not host.is_queued_for_deletion():
		navigation_changed.emit()


func _exit_tree() -> void:
	_cancel_event_tweens()
	for entry in _chunks:
		_kill_entry_tweens(entry)
	_bind_boss(null)
