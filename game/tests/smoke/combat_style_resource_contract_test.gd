extends SceneTree

const STYLE_PATHS := [
	"res://resources/combat_styles/reliquary_guard.tres",
	"res://resources/combat_styles/twin_colossi.tres",
	"res://resources/combat_styles/crescent_pair.tres",
	"res://resources/combat_styles/veilcraft.tres",
	"res://resources/combat_styles/ember_rite.tres",
]

var _failures: Array[String] = []


func _init() -> void:
	var ids := {}
	for path in STYLE_PATHS:
		ResourceLoader.load_threaded_request(path, "CombatStyleData", true)
		var resource = ResourceLoader.load(path, "CombatStyleData", ResourceLoader.CACHE_MODE_REPLACE)
		_expect(resource is CombatStyleData, "%s did not reload as CombatStyleData." % path)
		if not resource is CombatStyleData:
			continue
		_expect(not resource.style_id.is_empty(), "%s has no style ID." % path)
		_expect(not ids.has(resource.style_id), "Duplicate style ID %s." % resource.style_id)
		ids[resource.style_id] = true
		_expect(float(resource.value(&"stamina", false)) >= 0.0, "%s has invalid light stamina." % path)
		_expect(float(resource.value(&"stamina", true)) >= 0.0, "%s has invalid heavy stamina." % path)
	_expect(ids.size() == 5, "Exactly five combat style resources must load.")
	if _failures.is_empty():
		print("ASHEN_COMBAT_STYLE_RESOURCES_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
