# game/scripts/enemy/enemy_behavior_registry.gd
extends RefCounted
## G-05：behavior 标签 → 行为族模块（不膨胀 EnemyType）

const PatrolBehavior = preload("res://scripts/enemy/behaviors/patrol_behavior.gd")
const HoldBehavior = preload("res://scripts/enemy/behaviors/hold_behavior.gd")
const AmbushBehavior = preload("res://scripts/enemy/behaviors/ambush_behavior.gd")
const SkirmishBehavior = preload("res://scripts/enemy/behaviors/skirmish_behavior.gd")
const HazardBehavior = preload("res://scripts/enemy/behaviors/hazard_behavior.gd")
const SpecialBehavior = preload("res://scripts/enemy/behaviors/special_behavior.gd")

const FAMILY_BY_TAG := {
	"slow_patrol": &"patrol",
	"patrol_route": &"patrol",
	"float_patrol": &"patrol",
	"slow_drift": &"patrol",
	"inverted_patrol": &"patrol",
	"slow_crusher": &"patrol",
	"formation_fight": &"hold",
	"defensive_hold": &"hold",
	"shield_wall": &"hold",
	"slow_berserk": &"hold",
	"teleport_ambush": &"ambush",
	"illusion_dash": &"ambush",
	"seduce_and_strike": &"ambush",
	"hit_and_run": &"skirmish",
	"aggressive_flank": &"skirmish",
	"pack_hunter": &"skirmish",
	"swarm_flutter": &"skirmish",
	"swarm_dive": &"skirmish",
	"ranged_ambush": &"ranged",
	"ranged_artillery": &"ranged",
	"ranged_barrage": &"ranged",
	"ranged_homing": &"ranged",
	"petal_barrage": &"ranged",
	"area_denial": &"hazard",
	"poison_mist_zone": &"hazard",
	"gravity_zone": &"hazard",
	"proximity_explode": &"hazard",
	"explosive_burst": &"hazard",
	"dive_bomb": &"special",
	"mirror_self": &"special",
	"split_clone": &"special",
	"random_form": &"special",
	"soul_drain_aura": &"special",
}


static func family_for(behavior: String) -> StringName:
	var key := behavior.to_lower().strip_edges()
	return FAMILY_BY_TAG.get(key, &"patrol") as StringName


static func is_registered(behavior: String) -> bool:
	return FAMILY_BY_TAG.has(behavior.to_lower().strip_edges())


static func all_tags() -> Array[String]:
	var out: Array[String] = []
	for k in FAMILY_BY_TAG.keys():
		out.append(String(k))
	out.sort()
	return out


static func create_module(behavior: String) -> RefCounted:
	match family_for(behavior):
		&"patrol":
			return PatrolBehavior.new(behavior)
		&"hold":
			return HoldBehavior.new(behavior)
		&"ambush":
			return AmbushBehavior.new(behavior)
		&"skirmish", &"ranged":
			return SkirmishBehavior.new(behavior)
		&"hazard":
			return HazardBehavior.new(behavior)
		&"special":
			return SpecialBehavior.new(behavior)
		_:
			return PatrolBehavior.new(behavior)
