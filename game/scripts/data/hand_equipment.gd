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
		"mesh_shape": "sword", "mesh_color": "a9a18c",
	},
	"reliquary_shield": {
		"hand": "left", "primary": "shield_guard", "secondary": "shield_parry",
		"primary_label": "SHIELD GUARD", "secondary_label": "SHIELD PARRY",
		"guard": {"absorption": 0.82, "stability": 0.72, "front_dot": 0.15},
		"parry": {"start": 0.06, "end": 0.26, "cost": 10.0},
		"mesh_shape": "shield", "mesh_color": "614725",
	},
	"xingtian_axe_right": {
		"hand": "right", "primary": "right_axe_strike", "secondary": "colossal_leap",
		"primary_label": "RIGHT AXE", "secondary_label": "AXE LEAP",
		"mesh_shape": "axe_right", "mesh_color": "858b91",
	},
	"xingtian_axe_left": {
		"hand": "left", "primary": "left_axe_strike", "secondary": "left_axe_heavy",
		"primary_label": "LEFT AXE", "secondary_label": "LEFT HEAVY",
		"mesh_shape": "axe_left", "mesh_color": "858b91",
	},
	"marksman_bow": {
		"hand": "right", "primary": "bow_quick_shot", "secondary": "bow_power_shot",
		"primary_label": "QUICK SHOT", "secondary_label": "POWER SHOT",
		"mesh_shape": "bow", "mesh_color": "b1a88d",
	},
	"marksman_dagger": {
		"hand": "left", "primary": "dagger_slash", "secondary": "dagger_feint",
		"primary_label": "DAGGER", "secondary_label": "FEINT",
		"mesh_shape": "dagger", "mesh_color": "b1a88d",
	},
	"five_elements_seal": {
		"hand": "right", "primary": "seal_bolt", "secondary": "seal_burst",
		"primary_label": "SEAL BOLT", "secondary_label": "SEAL BURST",
		"mesh_shape": "staff_seal", "mesh_color": "668ee0",
	},
	"spirit_stone": {
		"hand": "left", "primary": "spell_shield", "secondary": "stone_pulse",
		"primary_label": "SPELL SHIELD", "secondary_label": "STONE PULSE",
		"guard": {"absorption": 0.58, "stability": 0.55, "front_dot": 0.0},
		"mesh_shape": "spirit_stone", "mesh_color": "668ee0",
	},
	"prayer_beads": {
		"hand": "right", "primary": "beads_heal", "secondary": "ember_rite",
		"primary_label": "BEADS HEAL", "secondary_label": "EMBER RITE",
		"mesh_shape": "prayer_beads", "mesh_color": "d07a32",
	},
	"talisman_papers": {
		"hand": "left", "primary": "talisman_strike", "secondary": "talisman_burst",
		"primary_label": "TALISMAN", "secondary_label": "TALISMAN BURST",
		"mesh_shape": "talisman_papers", "mesh_color": "d07a32",
	},
}


static func get_item(item_id: String) -> Dictionary:
	return ITEMS.get(item_id, {}).duplicate(true)


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
