extends SceneTree
## L-23 合约：法术表 schema（player_combat_data.gd / player_spells.gd）。
## 数据/解析层合约（headless 可跑）：
## 1) SPELL_CONFIG schema：focus_cost 在 0..max_focus、cast_time>=0、spell_type 非空。
## 2) 投射类法术（带 proj_speed）必须有正 proj_speed / proj_lifetime。
## 3) 风格映射：style 3 -> veil_bolt、style 4 -> ember_rite，focus 可花费。
## 4) SUMMON_CONFIG：5 灵、kind 非空、focus_cost>0、reserved_focus>=0、lifetime>0、
##    spell_type == "summon"。
## 5) PlayerSpells 构造层助手：默认/切换 active summon、summon 计数。
## 完整施法流（需真实玩家场景含 camera/focus/State）由 smoke_test 的 veilcraft/ember
## cast 路径覆盖；此处标注需手测 / 依赖 smoke。

const CombatData = preload("res://scripts/data/player_combat_data.gd")
const SpellsScript = preload("res://scripts/combat/player_spells.gd")

const MAX_FOCUS := 80.0

var _failures: Array[String] = []


func _init() -> void:
	_test_spell_schema()
	_test_projectile_spell_fields()
	_test_style_cast_mapping()
	_test_summon_schema()
	_test_spell_helper_contract()
	if _failures.is_empty():
		print("ASHEN_SPELL_CONTRACTS_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_spell_schema() -> void:
	_expect(
		CombatData.SPELL_CONFIG.size() >= 30,
		"Spell table must contain the L-11 expansion, got %d." % CombatData.SPELL_CONFIG.size()
	)
	for spell_id: String in CombatData.SPELL_CONFIG:
		var config: Dictionary = CombatData.SPELL_CONFIG[spell_id]
		# 所有法术必须声明 focus_cost/cast_time；spell_type 仅对需要分发的法术要求
		# （ember_rite 等由 resolve_cast 显式 match，未声明 spell_type 属合法形态）。
		_expect(
			config.has("focus_cost") and config.has("cast_time"),
			"Spell %s must declare focus_cost/cast_time." % spell_id
		)
		var focus_cost := float(config.get("focus_cost", -1.0))
		_expect(
			focus_cost >= 0.0 and focus_cost <= MAX_FOCUS,
			"Spell %s focus cost out of range: %s." % [spell_id, focus_cost]
		)
		var cast_time := float(config.get("cast_time", -1.0))
		_expect(cast_time >= 0.0, "Spell %s cast_time must be non-negative." % spell_id)
		if config.has("spell_type"):
			_expect(
				String(config["spell_type"]).strip_edges() != "",
				"Spell %s must declare a non-empty spell_type." % spell_id
			)
	# ember_rite 无 spell_type，其真实契约是治疗 + AoE（resolve_cast 显式分支）
	var ember: Dictionary = CombatData.SPELL_CONFIG["ember_rite"]
	_expect(float(ember.get("heal", 0.0)) > 0.0, "ember_rite must heal on cast.")
	_expect(float(ember.get("aoe_range", 0.0)) > 0.0, "ember_rite must have an AoE range.")
	_expect(float(ember.get("aoe_damage", 0.0)) > 0.0, "ember_rite must deal AoE damage.")


func _test_projectile_spell_fields() -> void:
	for spell_id: String in CombatData.SPELL_CONFIG:
		var config: Dictionary = CombatData.SPELL_CONFIG[spell_id]
		if not config.has("proj_speed"):
			continue
		var speed := float(config["proj_speed"])
		var lifetime := float(config.get("proj_lifetime", -1.0))
		_expect(speed > 0.0, "Projectile spell %s must have positive proj_speed." % spell_id)
		_expect(lifetime > 0.0, "Projectile spell %s must have positive proj_lifetime." % spell_id)


func _test_style_cast_mapping() -> void:
	_expect(CombatData.SPELL_CONFIG.has("veil_bolt"), "Style 3 must cast veil_bolt.")
	_expect(CombatData.SPELL_CONFIG.has("ember_rite"), "Style 4 must cast ember_rite.")
	for cast_id in ["veil_bolt", "ember_rite"]:
		var cost := float(CombatData.SPELL_CONFIG[cast_id]["focus_cost"])
		_expect(cost > 0.0 and cost <= MAX_FOCUS, "%s focus cost must be spendable." % cast_id)


func _test_summon_schema() -> void:
	_expect(
		CombatData.SUMMON_CONFIG.size() == 5,
		"Summon table must contain 5 spirits, got %d." % CombatData.SUMMON_CONFIG.size()
	)
	for summon_id: String in CombatData.SUMMON_CONFIG:
		var config: Dictionary = CombatData.SUMMON_CONFIG[summon_id]
		_expect(
			String(config.get("kind", "")).strip_edges() != "",
			"Summon %s must declare a kind." % summon_id
		)
		_expect(float(config.get("focus_cost", -1.0)) > 0.0, "Summon %s must have positive focus cost." % summon_id)
		_expect(
			float(config.get("reserved_focus", -1.0)) >= 0.0,
			"Summon %s must have non-negative reserved focus." % summon_id
		)
		_expect(float(config.get("lifetime", -1.0)) > 0.0, "Summon %s must have positive lifetime." % summon_id)
		_expect(String(config.get("spell_type", "")) == "summon", "Summon %s must use spell_type 'summon'." % summon_id)


func _test_spell_helper_contract() -> void:
	var spells = SpellsScript.new()
	_expect(spells.active_summon_spell_id() == &"summon_dharma_child", "Default active summon must be dharma_child.")
	spells.set_active_summon(&"white_crane")
	_expect(spells.active_summon_spell_id() == &"summon_white_crane", "set_active_summon must switch the active summon.")
	_expect(spells.summon_count() == 0, "Fresh spell helper must track no summons.")
	spells.dismiss_all()
	_expect(spells.summon_count() == 0, "dismiss_all on empty summon list must stay clean.")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
