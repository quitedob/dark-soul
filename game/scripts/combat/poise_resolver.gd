class_name PoiseResolver
extends RefCounted


static func resolve(base_poise: float, wam: float, pdr: float, incoming_poise_damage: float) -> Dictionary:
	var normalized_base := maxf(base_poise, 0.0)
	var normalized_wam := clampf(wam, 0.0, 1.0)
	var normalized_pdr := clampf(pdr, 0.0, 0.5)
	var raw_damage := maxf(incoming_poise_damage, 0.0)
	var reduced_damage := raw_damage * (1.0 - normalized_pdr)
	var settled_poise := normalized_base * normalized_wam - reduced_damage
	return {
		"reduced_damage": reduced_damage,
		"settled_poise": settled_poise,
		"holds": normalized_wam > 0.0 and settled_poise > 0.0,
	}
