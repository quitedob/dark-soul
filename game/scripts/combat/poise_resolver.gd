class_name PoiseResolver
extends RefCounted
## 韧性结算：站立储备与动作护甲共用同一池，WAM=0 仍可扛击


## current_poise: 当前储备；wam: 动作护甲倍率；holds 表示未硬直
static func resolve(
	current_poise: float,
	base_poise: float,
	wam: float,
	pdr: float,
	incoming_poise_damage: float
) -> Dictionary:
	var normalized_current := maxf(current_poise, 0.0)
	var normalized_base := maxf(base_poise, 0.0)
	var normalized_wam := maxf(wam, 0.0)
	var normalized_pdr := clampf(pdr, 0.0, 0.5)
	var raw_damage := maxf(incoming_poise_damage, 0.0)
	var reduced_damage := raw_damage * (1.0 - normalized_pdr)
	# 动作护甲可抬高当次容量；站立时靠 current_poise 吸收
	var action_capacity := normalized_base * normalized_wam
	var capacity := maxf(normalized_current, action_capacity)
	var settled_poise := capacity - reduced_damage
	return {
		"reduced_damage": reduced_damage,
		"settled_poise": settled_poise,
		"holds": settled_poise > 0.0,
	}
