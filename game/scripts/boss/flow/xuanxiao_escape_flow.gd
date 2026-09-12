extends Node
## Post-judgement escape is owned by the level, so freeing the boss cannot cancel it.
var flow_boss: Node
var flow_config: Dictionary = {}
var _encounter: Node
var _elapsed := 0.0
var _countdown_active := false
var _defeated := false
var _escaped := false

func bind_encounter(boundary: Node) -> void:
	_encounter = boundary

func _on_encounter_started() -> void:
	_elapsed = 0.
	_countdown_active = false
	_defeated = false
	_escaped = false

func _on_encounter_reset() -> void:
	_on_encounter_started()

func _on_encounter_resolved() -> void:
	_defeated = true

func _on_phase(_new_phase: int) -> void:
	return

func _on_story_threshold(_flag: String, _ratio: float) -> void:
	_countdown_active = false
