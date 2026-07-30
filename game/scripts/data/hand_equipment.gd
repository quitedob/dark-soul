class_name HandEquipment
extends RefCounted

const STYLE_LOADOUTS := [
	{"right_hand": "guardian_sword", "left_hand": "reliquary_shield"},
	{"right_hand": "xingtian_axe_right", "left_hand": "xingtian_axe_left"},
	{"right_hand": "marksman_bow", "left_hand": "marksman_dagger"},
	{"right_hand": "five_elements_seal", "left_hand": "spirit_stone"},
	{"right_hand": "prayer_beads", "left_hand": "talisman_papers"},
]

const ITEMS := {
	"guardian_sword": {
		"hand": "right", "primary": "sword_light", "secondary": "sword_heavy",
		"primary_label": "SWORD LIGHT", "secondary_label": "SWORD HEAVY",
		"weapon_type": "sword", "mesh_shape": "sword", "mesh_color": "a9a18c",
	},
	"reliquary_shield": {
		"hand": "left", "primary": "shield_guard", "secondary": "shield_parry",
		"primary_label": "SHIELD GUARD", "secondary_label": "SHIELD PARRY",
		"weapon_type": "shield",
		"guard": {"absorption": 0.82, "stability": 0.72, "front_dot": 0.15},
		"parry": {"startup": 0.40, "active": 0.20, "recovery": 0.60, "miss_penalty": 1.5, "cost": 10.0},
		"parry_feedback": {"cue": "parry_shield", "message": "SHIELD PARRY", "vfx_scale": 0.8},
		"mesh_shape": "shield", "mesh_color": "614725",
	},
	"jade_buckler": {
		"hand": "left", "primary": "shield_guard", "secondary": "shield_parry",
		"primary_label": "BUCKLER GUARD", "secondary_label": "BUCKLER PARRY",
		"weapon_type": "shield",
		"guard": {"absorption": 0.62, "stability": 0.45, "front_dot": 0.15},
		"parry": {"startup": 0.266, "active": 0.333, "recovery": 0.80, "miss_penalty": 2.0, "cost": 8.0},
		"parry_feedback": {"cue": "parry_buckler", "message": "BUCKLER PARRY", "vfx_scale": 1.35},
		"mesh_shape": "shield", "mesh_color": "5f8f72",
	},
	"parry_dagger": {
		"hand": "left", "primary": "dagger_slash", "secondary": "shield_parry",
		"primary_label": "DAGGER", "secondary_label": "DAGGER PARRY",
		"weapon_type": "dagger",
		"parry": {"startup": 0.333, "active": 0.266, "recovery": 0.40, "miss_penalty": 1.0, "cost": 8.0},
		"parry_feedback": {"cue": "parry_dagger", "message": "DAGGER PARRY", "vfx_scale": 0.65},
		"mesh_shape": "dagger", "mesh_color": "b8c2ca",
	},
	"fist_guard": {
		"hand": "left", "primary": "fist_guard", "secondary": "shield_parry",
		"primary_label": "FIST GUARD", "secondary_label": "FIST PARRY",
		"weapon_type": "fist",
		"parry": {"startup": 0.266, "active": 0.266, "recovery": 0.50, "miss_penalty": 1.2, "cost": 6.0},
		"parry_feedback": {"cue": "parry_fist", "message": "FIST PARRY", "vfx_scale": 0.45},
		"mesh_shape": "default", "mesh_color": "8b6f5a",
	},
	"xingtian_axe_right": {
		"hand": "right", "primary": "right_axe_strike", "secondary": "colossal_leap",
		"primary_label": "RIGHT AXE", "secondary_label": "AXE LEAP",
		"weapon_type": "axe", "mesh_shape": "axe_right", "mesh_color": "858b91",
	},
	"xingtian_axe_left": {
		"hand": "left", "primary": "left_axe_strike", "secondary": "left_axe_heavy",
		"primary_label": "LEFT AXE", "secondary_label": "LEFT HEAVY",
		"weapon_type": "axe", "mesh_shape": "axe_left", "mesh_color": "858b91",
	},
	"marksman_bow": {
		"hand": "right", "primary": "bow_quick_shot", "secondary": "bow_power_shot",
		"primary_label": "QUICK SHOT", "secondary_label": "POWER SHOT",
		"weapon_type": "bow", "mesh_shape": "bow", "mesh_color": "b1a88d",
	},
	"marksman_dagger": {
		"hand": "left", "primary": "dagger_slash", "secondary": "dagger_feint",
		"primary_label": "DAGGER", "secondary_label": "FEINT",
		"weapon_type": "dagger", "mesh_shape": "dagger", "mesh_color": "b1a88d",
	},
	"five_elements_seal": {
		"hand": "right", "primary": "seal_bolt", "secondary": "seal_burst",
		"primary_label": "SEAL BOLT", "secondary_label": "SEAL BURST",
		"weapon_type": "seal", "mesh_shape": "staff_seal", "mesh_color": "668ee0",
	},
	"spirit_stone": {
		"hand": "left", "primary": "spell_shield", "secondary": "stone_pulse",
		"primary_label": "SPELL SHIELD", "secondary_label": "STONE PULSE",
		"weapon_type": "catalyst",
		"guard": {"absorption": 0.58, "stability": 0.55, "front_dot": 0.0},
		"mesh_shape": "spirit_stone", "mesh_color": "668ee0",
	},
	"prayer_beads": {
		"hand": "right", "primary": "beads_heal", "secondary": "ember_rite",
		"primary_label": "BEADS HEAL", "secondary_label": "EMBER RITE",
		"weapon_type": "prayer", "mesh_shape": "prayer_beads", "mesh_color": "d07a32",
	},
	"talisman_papers": {
		"hand": "left", "primary": "talisman_strike", "secondary": "talisman_burst",
		"primary_label": "TALISMAN", "secondary_label": "TALISMAN BURST",
		"weapon_type": "talisman", "mesh_shape": "talisman_papers", "mesh_color": "d07a32",
	},
}


static func get_item(item_id: String) -> Dictionary:
	return ITEMS.get(item_id, {}).duplicate(true)


static func get_parry_feedback(item_id: String) -> Dictionary:
	return ITEMS.get(item_id, {}).get("parry_feedback", {}).duplicate(true)


static func is_valid_for_hand(item_id: String, hand: String) -> bool:
	return ITEMS.has(item_id) and String(ITEMS[item_id].get("hand", "")) == hand


static func get_style_loadout(style_id: int) -> Dictionary:
	return STYLE_LOADOUTS[clampi(style_id, 0, STYLE_LOADOUTS.size() - 1)].duplicate()


static func get_style_for_loadout(right_hand: String, left_hand: String) -> int:
	for style_id in range(STYLE_LOADOUTS.size()):
		var loadout: Dictionary = STYLE_LOADOUTS[style_id]
		if loadout["right_hand"] == right_hand and loadout["left_hand"] == left_hand:
			return style_id
	return 0


static func get_action_labels(right_hand: String, left_hand: String) -> Dictionary:
	var right := get_item(right_hand)
	var left := get_item(left_hand)
	return {
		"right_primary": String(right.get("primary_label", "R1")),
		"right_secondary": String(right.get("secondary_label", "R2")),
		"left_primary": String(left.get("primary_label", "L1")),
		"left_secondary": String(left.get("secondary_label", "L2")),
	}


static func get_mesh_shape(item_id: String) -> String:
	return String(ITEMS.get(item_id, {}).get("mesh_shape", "box"))


static func get_mesh_color(item_id: String) -> Color:
	var hex := String(ITEMS.get(item_id, {}).get("mesh_color", "9aa3aa"))
	return Color(hex)


static func get_weapon_type(item_id: String) -> StringName:
	# 左右手武器类型，用于同型跳劈判定
	return StringName(String(ITEMS.get(item_id, {}).get("weapon_type", "unknown")))


static func is_jump_slash_weapon_type(weapon_type: StringName) -> bool:
	# 仅近战同族可跳劈；盾/弓/法器不可
	return weapon_type in [&"sword", &"axe", &"curved", &"dagger", &"fist", &"hammer", &"spear"]


static func are_same_weapon_type(right_hand: String, left_hand: String) -> bool:
	var right_type := get_weapon_type(right_hand)
	var left_type := get_weapon_type(left_hand)
	if right_type == &"unknown" or left_type == &"unknown":
		return false
	return right_type == left_type


static func can_jump_slash(right_hand: String, left_hand: String, grip_mode: StringName) -> bool:
	# 双持：双手握同一主武器 → 允许（主手类型可跳劈即可）
	# 成对/单持：左右必须同类型且该类型可跳劈
	var right_type := get_weapon_type(right_hand)
	if not is_jump_slash_weapon_type(right_type):
		return false
	if grip_mode == &"two_handed":
		return true
	return are_same_weapon_type(right_hand, left_hand) and is_jump_slash_weapon_type(get_weapon_type(left_hand))
