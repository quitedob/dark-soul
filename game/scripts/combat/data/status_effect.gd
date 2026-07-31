class_name StatusEffect
extends RefCounted
## L-10：装备状态效果 —— 数据 + 纯逻辑解析（无场景依赖；调用方驱动 tick）。
## 四种状态：bleed（出血，叠层→阈值爆发）、foxfire（狐火，火 DoT）、
##           confusion（迷心，短暂反转操作）、poison（中毒，DoT）。
##
## status_bar 约定为 { status_id(StringName) : {"stacks": float, "elapsed": float, "tick_accum": float} }
## - apply() 叠加层、刷新持续时间；bleed 达到 burst_threshold 时触发爆发并清零。
## - tick()  推进 elapsed / bleed 衰减 / DoT 计时；返回事件数组，由调用方把 damage 落到 health。
## 纯逻辑，不持有任何场景节点引用。

const STATUS_DEFS := {
	"bleed": {
		"label": "出血",
		"max_stacks": 100.0,
		"burst_threshold": 100.0,
		"burst_damage": 22.0,
		"decay_per_second": 6.0,
	},
	"foxfire": {
		"label": "狐火",
		"max_stacks": 30.0,
		"dps_per_stack": 0.35,
		"tick_interval_seconds": 1.0,
		"duration_seconds": 3.0,
	},
	"confusion": {
		"label": "迷心",
		"max_stacks": 1.0,
		"duration_seconds": 2.0,
	},
	"poison": {
		"label": "中毒",
		"max_stacks": 50.0,
		"dps_per_stack": 0.12,
		"tick_interval_seconds": 1.0,
		"duration_seconds": 10.0,
	},
}


## 叠加状态；bleed 达阈值时爆发并清零。返回事件 dict（可含 burst_damage）。
static func apply(status_bar: Dictionary, status_id: StringName, stacks: float) -> Dictionary:
	var def: Dictionary = STATUS_DEFS.get(status_id, {})
	if def.is_empty() or stacks <= 0.0:
		return {}
	var entry: Variant = status_bar.get(status_id)
	if entry == null or not entry is Dictionary:
		entry = {"stacks": 0.0, "elapsed": 0.0, "tick_accum": 0.0}
	var max_stacks := float(def.get("max_stacks", 1.0))
	var current := minf(float(entry.get("stacks", 0.0)) + stacks, max_stacks)
	entry["stacks"] = current
	entry["elapsed"] = 0.0  # 刷新持续时间
	entry["tick_accum"] = 0.0
	status_bar[status_id] = entry
	var event := {"status": status_id, "stacks": current}
	var threshold := float(def.get("burst_threshold", 0.0))
	if threshold > 0.0 and current >= threshold:
		event["burst"] = true
		event["burst_damage"] = float(def.get("burst_damage", 0.0)) + current * 0.15
		entry["stacks"] = 0.0
	return event


## 推进计时 / 衰减 / DoT。返回事件数组，调用方负责把 damage 打到 health。
static func tick(status_bar: Dictionary, delta: float) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for status_id in status_bar.keys():
		var def: Dictionary = STATUS_DEFS.get(status_id, {})
		var entry: Variant = status_bar[status_id]
		if def.is_empty() or not entry is Dictionary:
			status_bar.erase(status_id)
			continue
		entry["elapsed"] = float(entry.get("elapsed", 0.0)) + delta
		var duration := float(def.get("duration_seconds", 0.0))
		if duration > 0.0 and float(entry["elapsed"]) >= duration:
			events.append({"status": status_id, "ended": true})
			status_bar.erase(status_id)
			continue
		var decay := float(def.get("decay_per_second", 0.0))
		if decay > 0.0:
			var stacks := maxf(float(entry.get("stacks", 0.0)) - decay * delta, 0.0)
			entry["stacks"] = stacks
			if stacks <= 0.001:
				events.append({"status": status_id, "ended": true})
				status_bar.erase(status_id)
				continue
		var dps := float(def.get("dps_per_stack", 0.0))
		if dps > 0.0:
			entry["tick_accum"] = float(entry.get("tick_accum", 0.0)) + delta
			var interval := float(def.get("tick_interval_seconds", 1.0))
			if float(entry["tick_accum"]) >= interval:
				entry["tick_accum"] = 0.0
				events.append({
					"status": status_id,
					"damage": dps * float(entry.get("stacks", 0.0)),
				})
	return events


static func has_status(status_bar: Dictionary, status_id: StringName) -> bool:
	return status_bar.has(status_id)


static func get_stacks(status_bar: Dictionary, status_id: StringName) -> float:
	var entry: Variant = status_bar.get(status_id)
	if entry is Dictionary:
		return float(entry.get("stacks", 0.0))
	return 0.0


static func clear_status(status_bar: Dictionary, status_id: StringName) -> void:
	status_bar.erase(status_id)


## 标准化的 status_inflict 条目 → {stacks, chance}。支持 {id: 数值} 与 {id: {stacks, chance}}。
static func normalize_inflict_entry(entry: Variant) -> Dictionary:
	if entry is Dictionary:
		return {
			"stacks": float(entry.get("stacks", 1.0)),
			"chance": float(entry.get("chance", 1.0)),
		}
	return {"stacks": float(entry), "chance": 1.0}
