extends RefCounted
## Three right-hand slots. Save values stay compatible with the scalar v2 map.

const Equipment = preload("res://scripts/data/hand_equipment.gd")
const SLOT_COUNT := 3
const STARTER_WEAPONS := ["guardian_sword", "xingtian_axe_right", "class_greatsword"]
const SLOT_PREFIX := "right_weapon_slot_"
const ACTIVE_KEY := "right_weapon_active_slot"

var slots: Array[String] = ["guardian_sword", "xingtian_axe_right", "class_greatsword"]
var active_slot := 0
var _inherited_weapons: Array[String] = []


func owned_weapons(inventory: Dictionary, current_item: String) -> Array[String]:
	var owned: Array[String] = []
	for item_id in Equipment.QUICKSLOT_WEAPONS:
		if item_id in STARTER_WEAPONS or item_id in _inherited_weapons or item_id == current_item or int(inventory.get(item_id, 0)) > 0:
			owned.append(item_id)
	return owned


func restore(values: Dictionary, inventory: Dictionary, current_item: String) -> void:
	slots.assign(STARTER_WEAPONS)
	_inherited_weapons.clear()
	# Old saves can carry an equipped weapon without a separate inventory count.
	if current_item in Equipment.QUICKSLOT_WEAPONS:
		_inherited_weapons.append(current_item)
	var owned := owned_weapons(inventory, current_item)
	for index in SLOT_COUNT:
		var raw: Variant = values.get(SLOT_PREFIX + str(index), slots[index])
		if not raw is String:
			continue
		var item_id := String(raw)
		if item_id in owned:
			var previous := slots.find(item_id)
			if previous >= 0 and previous != index:
				slots[previous] = slots[index]
			slots[index] = item_id
	active_slot = clampi(int(values.get(ACTIVE_KEY, 0)), 0, SLOT_COUNT - 1)
	# Current hand is the save authority, including pre-quickslot saves.
	track_equipped(current_item)


func track_equipped(item_id: String) -> void:
	if item_id not in Equipment.QUICKSLOT_WEAPONS:
		return
	var existing := slots.find(item_id)
	if existing >= 0:
		active_slot = existing
	else:
		slots[active_slot] = item_id


func snapshot(values: Dictionary) -> void:
	for index in SLOT_COUNT:
		values[SLOT_PREFIX + str(index)] = slots[index]
	values[ACTIVE_KEY] = active_slot


func inherited_weapons() -> Array[String]:
	return _inherited_weapons.duplicate()
