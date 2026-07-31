class_name TalentSystem
extends RefCounted
## L-09：天赋系统纯逻辑（无状态，仅读写 player 上的 talent_points / talent_spent）。
##
## - spend_point：校验天赋点/前置/上限 → 扣点 → 记档 → 让 player 重算并落地派生数值
## - compute_bonuses：由 talent_spent 幂等重算总增益（重应用安全）
## - unlocks_for：混合职业解锁判定（双亲各 ≥ HYBRID_PARENT_POINTS）
## - respec_class：返还某职业全部点（数据幂等，重算落地）

const TalentDataScript = preload("res://scripts/player/talent_data.gd")


## 总增益重算。multiplier 类（damage_mult/move_speed/focus_regen/parry_window/dodge_i_frames）
## 以 1.0 为基逐点累加；flat 类（health/stamina/focus/armor_pdr/summon_reserve）以 0 为基累加。
static func compute_bonuses(talent_spent: Dictionary) -> Dictionary:
	var totals := {
		"max_health": 0.0, "max_stamina": 0.0, "max_focus": 0.0,
		"damage_mult": 1.0, "armor_pdr": 0.0, "move_speed": 1.0,
		"focus_regen": 1.0, "parry_window": 1.0, "dodge_i_frames": 1.0,
		"summon_reserve": 0.0,
	}
	for class_key in talent_spent.keys():
		var spent: Array = talent_spent[class_key]
		for talent_id in spent:
			var t := TalentDataScript.talent(StringName(class_key), StringName(talent_id))
			if t.is_empty():
				continue
			var effect_type := String(t["effect_type"])
			if totals.has(effect_type):
				totals[effect_type] = float(totals[effect_type]) + float(t["value"])
	return totals


## 尝试消费 1 天赋点学习指定天赋
static func spend_point(class_id: StringName, talent_id: StringName, player: Node) -> bool:
	var check := can_spend(class_id, talent_id, player)
	if not bool(check["ok"]):
		return false
	var class_key := String(class_id)
	var points := int(player.get("talent_points"))
	player.set("talent_points", maxi(points - 1, 0))
	var spent: Array = player.get("talent_spent").get(class_key, [])
	spent.append(String(talent_id))
	player.get("talent_spent")[class_key] = spent
	player.call("_apply_talent_stats")
	return true


## 只读校验；返回 {"ok": bool, "reason": String}
static func can_spend(class_id: StringName, talent_id: StringName, player: Node) -> Dictionary:
	if player == null:
		return {"ok": false, "reason": "NO_PLAYER"}
	var t := TalentDataScript.talent(class_id, talent_id)
	if t.is_empty():
		return {"ok": false, "reason": "NO_TALENT"}
	if int(player.get("talent_points")) < 1:
		return {"ok": false, "reason": "NO_POINTS"}
	var spent: Array = player.get("talent_spent").get(String(class_id), [])
	var class_spent := {String(class_id): spent}
	if level_of(StringName(t["id"]), class_id, class_spent) >= int(t["max_level"]):
		return {"ok": false, "reason": "MAXED"}
	if points_in_tiers(class_id, int(t["tier"]), class_spent) < int(t["points_required"]):
		return {"ok": false, "reason": "PREREQ"}
	return {"ok": true, "reason": ""}


## 某天赋当前等级（数组中重复出现次数 = 级数）
static func level_of(talent_id: StringName, class_id: StringName, talent_spent: Dictionary) -> int:
	var spent: Array = talent_spent.get(String(class_id), [])
	var target := String(talent_id)
	var level := 0
	for tid in spent:
		if String(tid) == target:
			level += 1
	return level


## 某职业已投入的总天赋点
static func points_for_class(class_id: StringName, talent_spent: Dictionary) -> int:
	return (talent_spent.get(String(class_id), []) as Array).size()


## 各职业投入点数映射 class_id(String) -> int
static func points_by_class(talent_spent: Dictionary) -> Dictionary:
	var result := {}
	for class_key in talent_spent.keys():
		result[String(class_key)] = (talent_spent[class_key] as Array).size()
	return result


## 前导阶（tier 以下）已投入点数；用于 tier 前置判定
static func points_in_tiers(class_id: StringName, upto_tier_exclusive: int, talent_spent: Dictionary) -> int:
	var tree := TalentDataScript.tree_for(class_id)
	var spent: Array = talent_spent.get(String(class_id), [])
	var total := 0
	for t in tree:
		if int(t["tier"]) >= upto_tier_exclusive:
			continue
		total += level_of(StringName(t["id"]), class_id, talent_spent)
	return total


## 混合职业是否已解锁（双亲各 ≥ HYBRID_PARENT_POINTS）
static func unlocks_for(class_id: StringName, spent_by_class: Dictionary) -> bool:
	var cls := TalentDataScript.class_for_id(class_id)
	if cls.is_empty() or not bool(cls["hybrid"]):
		return false
	var parents: Array = cls["parents"]
	if parents.size() < 2:
		return false
	for p in parents:
		if int(spent_by_class.get(String(p), 0)) < TalentDataScript.HYBRID_PARENT_POINTS:
			return false
	return true


## 当前已解锁职业 id 列表（基础恒解锁；混合按双亲阈值）
static func unlocked_classes(talent_spent: Dictionary) -> Array:
	var spent_by_class := points_by_class(talent_spent)
	var result: Array = []
	for cls in TalentDataScript.all_classes():
		var id := StringName(cls["id"])
		if bool(cls["hybrid"]):
			if unlocks_for(id, spent_by_class):
				result.append(id)
		else:
			result.append(id)
	return result


## 解锁进度 0..1（已解锁混合 / 总混合）
static func class_unlock_ratio(talent_spent: Dictionary) -> float:
	var spent_by_class := points_by_class(talent_spent)
	var unlocked := 0
	var total := 0
	for cls in TalentDataScript.all_classes():
		if bool(cls["hybrid"]):
			total += 1
			if unlocks_for(StringName(cls["id"]), spent_by_class):
				unlocked += 1
	if total <= 0:
		return 0.0
	return float(unlocked) / float(total)


## 返还某职业全部天赋点；返回返还数量
static func respec_class(class_id: StringName, player: Node) -> int:
	if player == null:
		return 0
	var class_key := String(class_id)
	var spent: Array = player.get("talent_spent").get(class_key, [])
	var refund := spent.size()
	if refund <= 0:
		return 0
	player.set("talent_points", int(player.get("talent_points")) + refund)
	player.get("talent_spent")[class_key] = []
	player.call("_apply_talent_stats")
	return refund
