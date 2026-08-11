class_name RealModelResolver
extends RefCounted
## Real-model swap resolver — replaces procedural placeholder geometry with GLB
## models when a model exists for a category/key, falling back to the procedural
## builders otherwise.
##
## Contract (consumed by character_meshes.gd / weapon_meshes.gd / enemy_factory.gd):
##   _clear_children(parent)
##   if RealModelResolver.try_instance(<id>, parent):
##       return
##   ...procedural build...
##
## Registry schema:
##   id -> {
##       path:      res:// path to the GLB (required)
##       sub_node:  node name to extract from the GLB and re-parent to the pivot
##                  origin (weapons/shields); whole model used when absent
##       root_name: name of the container node added to `parent`
##                  (default "ModelRoot"; "BodyRoot" satisfies the player lookup)
##       scale:     uniform scale
##       scale_x:   extra X scale (negative mirrors for left-hand)
##       y_offset:  vertical offset in metres
##       yaw_deg:   rotation around Y in degrees
##       position:  additional position offset (weapon-grip compensation)
##   }
## Dropping a GLB into game/assets/models/<category>/<key>.glb and registering it
## here makes that entity real with zero changes to the consumers.

## The 85 three.js-authored GLBs (build/glb-models/out/) are imported under
## game/assets/models/ and registered here. `align_ground` lifts a model so its
## lowest mesh sits at the container origin (authors export feet-on-origin).
const _E := "res://assets/models/enemies/"
const _BOSS := "res://assets/models/bosses/"
const _SUB := "res://assets/models/bosses/sub-bosses/"
const _PC := "res://assets/models/characters/player-classes/"
const _NPC := "res://assets/models/characters/npcs/"
const _SUMMON := "res://assets/models/characters/summons/"
const _WP := "res://assets/models/weapons/"

const REGISTRY := {
	# ── Player ──
	"player/body": {
		"path": "res://assets/models/player/mannyquin.glb",
		"root_name": "BodyRoot",
		"scale": 1.0,
		"y_offset": 0.0,
	},
	"player/weapon/sword": {
		"path": "res://assets/models/weapons/templateweapons.glb",
		"sub_node": "Sword",
		"scale": 0.8,
		"yaw_deg": 180.0,
	},
	"player/weapon/axe_right": {
		"path": "res://assets/models/weapons/02-XingTian-Twin-Axes.glb",
		"sub_node": "axe_right",
		"scale": 0.6,
	},
	"player/weapon/axe_left": {
		"path": "res://assets/models/weapons/02-XingTian-Twin-Axes.glb",
		"sub_node": "axe_left",
		"scale": 0.6,
	},
	"player/shield": {
		"path": "res://assets/models/weapons/templateweapons.glb",
		"sub_node": "Shield",
		"scale": 1.0,
	},
	# ── Themed weapon GLBs ×12 — keys are motion-profile aligned (weapon/<NN>-<name>) ──
	# Grip nodes are authored at/near the model origin (dump-verified), so whole-model
	# instancing with a uniform hand scale keeps the grip on the pivot. Uniform scale 0.6:
	# the raw GLBs are ~1.5-2 m long; 0.6 brings hand-held weapons into the 0.6-1.1 m
	# readable range while the player pivot sits at ~y1.25 in the hand.
	"weapon/01-WindHunter-Bow":            {"path": _WP + "01-WindHunter-Bow.glb", "scale": 0.6},
	"weapon/02-XingTian-Twin-Axes":        {"path": _WP + "02-XingTian-Twin-Axes.glb", "scale": 0.6},
	"weapon/03-Mystic-Gate-Seal":          {"path": _WP + "03-Mystic-Gate-Seal.glb", "scale": 0.6},
	"weapon/04-Sandalwood-Beads-Talisman": {"path": _WP + "04-Sandalwood-Beads-Talisman.glb", "scale": 0.6},
	"weapon/05-Sun-Falling-Bow":           {"path": _WP + "05-Sun-Falling-Bow.glb", "scale": 0.6},
	"weapon/06-Five-Elements-Seal":        {"path": _WP + "06-Five-Elements-Seal.glb", "scale": 0.6},
	"weapon/07-XingTian-Indomitable":      {"path": _WP + "07-XingTian-Indomitable.glb", "scale": 0.6},
	"weapon/08-XuanXiao-Falling-Star":     {"path": _WP + "08-XuanXiao-Falling-Star.glb", "scale": 0.6},
	"weapon/09-ZhuYin-The-End":            {"path": _WP + "09-ZhuYin-The-End.glb", "scale": 0.6},
	"weapon/10-JuQue-Gatekeeper":          {"path": _WP + "10-JuQue-Gatekeeper.glb", "scale": 0.6},
	"weapon/11-NineTails-Illusion-Moon":   {"path": _WP + "11-NineTails-Illusion-Moon.glb", "scale": 0.6},
	"weapon/12-Weapon-Types":              {"path": _WP + "12-Weapon-Types.glb", "scale": 0.6},
	# ── Player classes (8) — build_player() threads the class id ──
	"player/body/class_barbarian":      {"path": _PC + "02-Frenzied-Warrior.glb", "root_name": "BodyRoot", "align_ground": true},
	"player/body/class_marksman":       {"path": _PC + "01-Divine-Marksman.glb", "root_name": "BodyRoot", "align_ground": true},
	"player/body/class_mystic":         {"path": _PC + "03-Mystic-Mage.glb", "root_name": "BodyRoot", "align_ground": true},
	"player/body/class_invoker":        {"path": _PC + "04-Invocation-Master.glb", "root_name": "BodyRoot", "align_ground": true},
	"player/body/class_yin_yang":       {"path": _PC + "05-Yin-Yang-Master.glb", "root_name": "BodyRoot", "align_ground": true},
	"player/body/class_war_shaman":     {"path": _PC + "06-War-Shaman.glb", "root_name": "BodyRoot", "align_ground": true},
	"player/body/class_arcane_archer":  {"path": _PC + "07-Arcane-Archer.glb", "root_name": "BodyRoot", "align_ground": true},
	"player/body/class_asura":          {"path": _PC + "08-Asura.glb", "root_name": "BodyRoot", "align_ground": true},
	# ── Ch.1 enemies ──
	"enemy/body/by_id/lost_soul_soldier":       {"path": _E + "01-spirit-ruins/01-Lost-Soul-Soldier.glb", "align_ground": true},
	"enemy/body/by_id/temple_guardian_warrior": {"path": _E + "01-spirit-ruins/02-Temple-Guardian-Warrior.glb", "align_ground": true},
	"enemy/body/by_id/mirror_shade":            {"path": _E + "01-spirit-ruins/03-Mirror-Shade.glb", "align_ground": true},
	"enemy/body/by_id/furnace_slag_beast":      {"path": _E + "01-spirit-ruins/04-Furnace-Slag-Beast.glb", "align_ground": true},
	"enemy/body/by_id/ember_shade_skirmisher":  {"path": _E + "01-spirit-ruins/03-Mirror-Shade.glb", "align_ground": true},
	# ── Ch.2 enemies ──
	"enemy/body/by_id/battle_worn_soldier":      {"path": _E + "02-blood-iron/01-Lost-Soldier-BattleWorn.glb", "align_ground": true},
	"enemy/body/by_id/war_dog_wraith":           {"path": _E + "02-blood-iron/02-War-Dog-Wraith.glb", "align_ground": true},
	"enemy/body/by_id/camp_guard_wraith":        {"path": _E + "02-blood-iron/03-Camp-Guard-Wraith.glb", "align_ground": true},
	"enemy/body/by_id/torture_device_spirit":    {"path": _E + "02-blood-iron/04-Torture-Device-Spirit.glb", "align_ground": true},
	"enemy/body/by_id/generals_personal_guard":  {"path": _E + "02-blood-iron/05-Generals-Personal-Guard.glb", "align_ground": true},
	"enemy/body/by_id/beacon_keeper_wraith":     {"path": _E + "02-blood-iron/06-Beacon-Keeper-Wraith.glb", "align_ground": true},
	# ── Ch.3 enemies ──
	"enemy/body/by_id/illusion_butterfly":       {"path": _E + "03-jade-veil/01-Illusion-Butterfly.glb", "align_ground": true},
	"enemy/body/by_id/memory_thief":             {"path": _E + "03-jade-veil/02-Memory-Thief.glb", "align_ground": true},
	"enemy/body/by_id/echo_spirit":              {"path": _E + "03-jade-veil/03-Echo-Spirit.glb", "align_ground": true},
	"enemy/body/by_id/foxfire_lantern":          {"path": _E + "03-jade-veil/04-Foxfire-Lantern-Spirit.glb", "align_ground": true},
	"enemy/body/by_id/wedding_gown_ghost":       {"path": _E + "03-jade-veil/05-Wedding-Gown-Ghost.glb", "align_ground": true},
	"enemy/body/by_id/water_moon_spirit":        {"path": _E + "03-jade-veil/06-Water-Moon.glb", "align_ground": true},
	"enemy/body/by_id/mirror_flower_spirit":     {"path": _E + "03-jade-veil/07-Mirror-Flower-Spirit.glb", "align_ground": true},
	"enemy/body/by_id/maze_guardian":            {"path": _E + "03-jade-veil/08-Maze-Guardian.glb", "align_ground": true},
	"enemy/body/by_id/mind_lost_fox_demon":      {"path": _E + "03-jade-veil/09-MindLost-Fox-Demon.glb", "align_ground": true},
	"enemy/body/by_id/ember_greedy_ghost":       {"path": _E + "03-jade-veil/10-Ember-Greedy-Ghost.glb", "align_ground": true},
	# ── Ch.4 enemies ──
	"enemy/body/by_id/stairway_guard_wraith":    {"path": _E + "04-celestial-fall/01-Stairway-Guard-Wraith.glb", "align_ground": true},
	"enemy/body/by_id/cloud_sky_eagle":          {"path": _E + "04-celestial-fall/02-Cloud-Sky-Eagle.glb", "align_ground": true},
	"enemy/body/by_id/elixir_furnace_spirit":    {"path": _E + "04-celestial-fall/03-Elixir-Furnace-Spirit.glb", "align_ground": true},
	"enemy/body/by_id/alchemy_fallen_immortal":  {"path": _E + "04-celestial-fall/04-Alchemy-Fallen-Immortal.glb", "align_ground": true},
	"enemy/body/by_id/book_spirit":              {"path": _E + "04-celestial-fall/05-Book-Spirit.glb", "align_ground": true},
	"enemy/body/by_id/library_guardian_spirit":  {"path": _E + "04-celestial-fall/06-Library-Guardian-Spirit.glb", "align_ground": true},
	"enemy/body/by_id/broken_immortal_body":     {"path": _E + "04-celestial-fall/07-Broken-Immortal-Body.glb", "align_ground": true},
	# ── Ch.5 enemies ──
	"enemy/body/by_id/ember_shore_drifter":      {"path": _E + "05-throne-of-ashes/01-Ember-Shore-Drifter.glb", "align_ground": true},
	"enemy/body/by_id/inverted_guardian":        {"path": _E + "05-throne-of-ashes/02-Inverted-Guardian.glb", "align_ground": true},
	"enemy/body/by_id/ember_bat":                {"path": _E + "05-throne-of-ashes/03-Ember-Bat.glb", "align_ground": true},
	"enemy/body/by_id/forked_path_shade":        {"path": _E + "05-throne-of-ashes/04-Forked-Path-Guardian.glb", "align_ground": true},
	"enemy/body/by_id/shadow_of_possibility":    {"path": _E + "05-throne-of-ashes/05-Shadow-of-Possibility.glb", "align_ground": true},
	# ── Bosses (8) ──
	"enemy/body/by_id/boss_giant_gate":          {"path": _BOSS + "01-Furnace-Keeper-JuQue.glb", "align_ground": true},
	"enemy/body/by_id/boss_xing_tian":           {"path": _BOSS + "02-Blood-General-XingTian.glb", "align_ground": true},
	"enemy/body/by_id/boss_nine_tails":          {"path": _BOSS + "03-Jade-Faced-Fox-NineTails.glb", "align_ground": true},
	"enemy/body/by_id/boss_xuan_xiao_wrath":     {"path": _SUB + "01-WrathFragment.glb", "align_ground": true},
	"enemy/body/by_id/boss_xuan_xiao_obsession": {"path": _SUB + "02-ObsessionFragment.glb", "align_ground": true},
	"enemy/body/by_id/boss_xuan_xiao":           {"path": _BOSS + "04-Fallen-Immortal-XuanXiao.glb", "align_ground": true},
	"enemy/body/by_id/boss_zhu_yin":             {"path": _BOSS + "05-Lord-of-the-Ember-Abyss-ZhuYin.glb", "align_ground": true},
	"enemy/body/by_id/boss_blind_bell":          {"path": _BOSS + "06-Blind-Bell-Hearer.glb", "align_ground": true},
	# ── Body-type fallbacks (shared/unmapped enemies, elites) ──
	"enemy/body/wraith_thin":           {"path": _E + "01-spirit-ruins/01-Lost-Soul-Soldier.glb", "align_ground": true},
	"enemy/body/armored_medium":        {"path": _E + "01-spirit-ruins/02-Temple-Guardian-Warrior.glb", "align_ground": true},
	"enemy/body/ethereal_flicker":      {"path": _E + "01-spirit-ruins/03-Mirror-Shade.glb", "align_ground": true},
	"enemy/body/hulking_molten":        {"path": _E + "01-spirit-ruins/04-Furnace-Slag-Beast.glb", "align_ground": true},
	"enemy/body/ragged_soldier":        {"path": _E + "02-blood-iron/01-Lost-Soldier-BattleWorn.glb", "align_ground": true},
	"enemy/body/hound_spectral":        {"path": _E + "02-blood-iron/02-War-Dog-Wraith.glb", "align_ground": true},
	"enemy/body/armored_heavy":         {"path": _E + "02-blood-iron/03-Camp-Guard-Wraith.glb", "align_ground": true},
	"enemy/body/immobile_turret":       {"path": _E + "02-blood-iron/04-Torture-Device-Spirit.glb", "align_ground": true},
	"enemy/body/elite_armored":         {"path": _E + "02-blood-iron/05-Generals-Personal-Guard.glb", "align_ground": true},
	"enemy/body/tower_ranged":          {"path": _E + "02-blood-iron/06-Beacon-Keeper-Wraith.glb", "align_ground": true},
	"enemy/body/floating_small":        {"path": _E + "03-jade-veil/01-Illusion-Butterfly.glb", "align_ground": true},
	"enemy/body/ethereal_thin":         {"path": _E + "03-jade-veil/02-Memory-Thief.glb", "align_ground": true},
	"enemy/body/floating_orb":          {"path": _E + "03-jade-veil/03-Echo-Spirit.glb", "align_ground": true},
	"enemy/body/lantern_float":         {"path": _E + "03-jade-veil/04-Foxfire-Lantern-Spirit.glb", "align_ground": true},
	"enemy/body/floating_dress":        {"path": _E + "03-jade-veil/05-Wedding-Gown-Ghost.glb", "align_ground": true},
	"enemy/body/reflection_clone":      {"path": _E + "03-jade-veil/06-Water-Moon.glb", "align_ground": true},
	"enemy/body/flower_stationary":     {"path": _E + "03-jade-veil/07-Mirror-Flower-Spirit.glb", "align_ground": true},
	"enemy/body/beast_humanoid":        {"path": _E + "03-jade-veil/09-MindLost-Fox-Demon.glb", "align_ground": true},
	"enemy/body/celestial_guard":       {"path": _E + "04-celestial-fall/01-Stairway-Guard-Wraith.glb", "align_ground": true},
	"enemy/body/flying_large":          {"path": _E + "04-celestial-fall/02-Cloud-Sky-Eagle.glb", "align_ground": true},
	"enemy/body/barrel_heavy":          {"path": _E + "04-celestial-fall/03-Elixir-Furnace-Spirit.glb", "align_ground": true},
	"enemy/body/robed_caster":          {"path": _E + "04-celestial-fall/04-Alchemy-Fallen-Immortal.glb", "align_ground": true},
	"enemy/body/floating_book":         {"path": _E + "04-celestial-fall/05-Book-Spirit.glb", "align_ground": true},
	"enemy/body/shambling_giant":       {"path": _E + "04-celestial-fall/07-Broken-Immortal-Body.glb", "align_ground": true},
	"enemy/body/void_wraith":           {"path": _E + "05-throne-of-ashes/01-Ember-Shore-Drifter.glb", "align_ground": true},
	"enemy/body/gravity_armor":         {"path": _E + "05-throne-of-ashes/02-Inverted-Guardian.glb", "align_ground": true},
	"enemy/body/flying_small":          {"path": _E + "05-throne-of-ashes/03-Ember-Bat.glb", "align_ground": true},
	"enemy/body/shadow_form":           {"path": _E + "05-throne-of-ashes/04-Forked-Path-Guardian.glb", "align_ground": true},
	"enemy/body/quantum_shimmer":       {"path": _E + "05-throne-of-ashes/05-Shadow-of-Possibility.glb", "align_ground": true},
	# ── Summons (5) — spirit_summon.gd resolves summon/<kind> ──
	"summon/dharma_child":       {"path": _SUMMON + "01-DharmaProtectingChildSpirit.glb", "align_ground": true},
	"summon/golden_guardian":    {"path": _SUMMON + "02-GoldenArmoredGuardian.glb", "align_ground": true},
	"summon/rebirth_lotus":      {"path": _SUMMON + "03-RebirthLotus.glb", "align_ground": true},
	"summon/resentful_spirit":   {"path": _SUMMON + "04-ResentfulSpirit.glb", "align_ground": true},
	"summon/white_crane":        {"path": _SUMMON + "05-WhiteCraneAttendant.glb", "align_ground": true},
	# ── NPCs (7) — game_world.gd resolves npc/<id> ──
	"npc/npc_cloud_wanderer":      {"path": _NPC + "01-Cloud-Wanderer.glb", "align_ground": true},
	"npc/npc_iron_heart":          {"path": _NPC + "02-Iron-Heart.glb", "align_ground": true},
	"npc/npc_lady_of_memories":    {"path": _NPC + "03-Lady-of-Memories.glb", "align_ground": true},
	"npc/npc_xuanxiao_remnant":    {"path": _NPC + "04-XuanXiao-Remnant.glb", "align_ground": true},
	"npc/npc_silence_bringer":     {"path": _NPC + "05-Silence-Bringer.glb", "align_ground": true},
	"npc/npc_bridge_tea_soul":     {"path": _NPC + "06-Tea-Soul.glb", "align_ground": true},
	"npc/npc_ember_tea_keeper":    {"path": _NPC + "07-Ember-Tea-Keeper.glb", "align_ground": true},
}

## path -> PackedScene (or null on failed load). Process-lifetime cache.
static var _scene_cache: Dictionary = {}
## paths already warned about — avoid spam on every missing asset.
static var _warned: Dictionary = {}


## Try to instance the real model registered for `id` under `parent`.
## Returns true on success; the caller must clear `parent`'s children first.
## Never throws: a missing/unloadable model degrades to the procedural path.
static func try_instance(id: String, parent: Node3D) -> bool:
	var entry: Dictionary = REGISTRY.get(id, {})
	if entry.is_empty():
		return false
	var path := String(entry.get("path", ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return false
	var scene: PackedScene = _scene_cache.get(path, null)
	if scene == null:
		scene = load(path) as PackedScene
		_scene_cache[path] = scene
		if scene == null:
			if not _warned.has(path):
				_warned[path] = true
				push_warning("RealModelResolver: cannot load model: %s" % path)
			return false

	var instance: Node3D = scene.instantiate()
	_neutralize_animation_players(instance)

	# Null-mesh MeshInstance3D is a legal transform/visibility anchor — satisfies
	# the player's BodyRoot cast and gives the enemy palette gate a single marker.
	var root := MeshInstance3D.new()
	root.name = String(entry.get("root_name", "ModelRoot"))
	var s := float(entry.get("scale", 1.0))
	root.scale = Vector3(s * float(entry.get("scale_x", 1.0)), s, s)
	root.position = Vector3(0.0, float(entry.get("y_offset", 0.0)), 0.0)
	if entry.has("position"):
		root.position += entry["position"] as Vector3
	root.rotation.y = deg_to_rad(float(entry.get("yaw_deg", 0.0)))

	if entry.has("sub_node"):
		var sub_name := String(entry["sub_node"])
		if _attach_sub_node(instance, sub_name, root):
			instance.free()
		else:
			root.add_child(instance)
	else:
		root.add_child(instance)

	# 接地对齐:把模型最低点抬到容器原点(作者以脚踩原点导出,部分模型埋在 y<0)。
	if entry.get("align_ground", false):
		var min_y := _scene_min_y(instance)
		if min_y < 0.0:
			root.position.y -= s * min_y

	parent.add_child(root)
	return true


## True when a real model is registered for `id` and its GLB path resolves.
static func has_model(id: String) -> bool:
	var entry: Dictionary = REGISTRY.get(id, {})
	if entry.is_empty():
		return false
	var path := String(entry.get("path", ""))
	return not path.is_empty() and ResourceLoader.exists(path)


## Disable any animation players/trees embedded in the GLB so the model stays in
## its rest pose. The game poses models by rotating their PARENT (visual_root /
## weapon_pivot), so embedded skeletal clips would otherwise fight that.
static func _neutralize_animation_players(node: Node) -> void:
	if node is AnimationPlayer:
		node.autoplay = ""
		node.active = false
		node.stop()
	elif node is AnimationTree:
		node.active = false
	for child in node.get_children():
		_neutralize_animation_players(child)


## Extract the named sub-node from the instanced scene and re-parent it to the
## container with a zeroed transform, so the weapon/shield grip sits at the
## pivot origin. Returns false (caller falls back to the whole model) if absent.
static func _attach_sub_node(instance: Node3D, sub_name: String, container: Node3D) -> bool:
	var target := _find_named(instance, sub_name)
	if target == null:
		return false
	target.get_parent().remove_child(target)
	target.owner = null  # detach scene ownership so re-parenting doesn't warn
	target.position = Vector3.ZERO
	target.rotation = Vector3.ZERO
	target.scale = Vector3.ONE
	container.add_child(target)
	return true


static func _find_named(node: Node, name: String) -> Node3D:
	if node.name == name and node is Node3D:
		return node
	for child in node.get_children():
		var hit := _find_named(child, name)
		if hit != null:
			return hit
	return null


## Lowest mesh AABB min-Y in the node's local space — ground-alignment offset.
static func _scene_min_y(top: Node3D) -> float:
	var min_y := INF
	for mi in _collect_meshes(top):
		if mi.mesh == null:
			continue
		var bb: AABB = _xf_to(top, mi) * mi.mesh.get_aabb()
		min_y = minf(min_y, bb.position.y)
	return min_y if min_y != INF else 0.0


static func _collect_meshes(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		out.append(node)
	for child in node.get_children():
		out.append_array(_collect_meshes(child))
	return out


## Accumulate local transforms from `mi` up to `top` (instanced scene root).
static func _xf_to(top: Node3D, mi: Node3D) -> Transform3D:
	var t := Transform3D()
	var p: Node3D = mi
	while p != top:
		t = p.transform * t
		p = p.get_parent() as Node3D
		if p == null:
			break
	return t
