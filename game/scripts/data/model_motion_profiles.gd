class_name ModelMotionProfiles
extends RefCounted
## 85 个 GLB 模型的专属动效档案聚合器。
## 子代理按批次文件(scripts/data/motion/profiles_*.gd)逐条填写,
## 运行时按 resolver id(如 "enemy/body/by_id/lost_soul_soldier")取档;
## 无档的模型退回默认行为(无额外运动/特效),保证永远安全。
##
## Schema(每条):
## {
##   "movement": { "type": "none|bob|sway|float|rock|drift", "amplitude": 米, "speed": Hz },
##   "vfx": {
##     "windup_ember": Color,   # 蓄力余烬喷发色(敌人/首领)
##     "ambient": { "type": "embers|motes|dust|none", "color": Color, "count": int },
##     "aura": Color,           # 可选:模型周围环境点光源
##   },
## }

const Ch1 = preload("res://scripts/data/motion/profiles_ch1.gd")
const Ch2 = preload("res://scripts/data/motion/profiles_ch2.gd")
const Ch3 = preload("res://scripts/data/motion/profiles_ch3.gd")
const Ch4 = preload("res://scripts/data/motion/profiles_ch4.gd")
const Ch5 = preload("res://scripts/data/motion/profiles_ch5.gd")
const Bosses = preload("res://scripts/data/motion/profiles_bosses.gd")
const SummonsNpcs = preload("res://scripts/data/motion/profiles_summons_npcs.gd")
const ClassesWeaponsProps = preload("res://scripts/data/motion/profiles_classes_weapons_props.gd")

static var _cache: Dictionary = {}


static func profile_for(resolver_id: String) -> Dictionary:
	if _cache.is_empty():
		_cache = _merge_all()
	return _cache.get(resolver_id, {})


static func _merge_all() -> Dictionary:
	var out := {}
	for src in [Ch1, Ch2, Ch3, Ch4, Ch5, Bosses, SummonsNpcs, ClassesWeaponsProps]:
		for k in src.profiles():
			out[k] = src.profiles()[k]
	return out
