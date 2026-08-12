extends SceneTree
## L-22：精英命名对齐合约（elite-name-alignment）
## 1) 全部 15 个 elite_* id 与硬编码期望 id 集合逐一相同（防止误改 id 破坏 spawn/掉落引用链）。
## 2) 每个精英的 display_name 与各章 chapter-supplement「👹 精英怪」名册一致（双语 "English / 中文"）。
## 3) 每个精英的 appears_in（出现位）与设计一致；三个移动位精英已落到目标层：
##    elite_siege_commander 2-2→2-5、elite_fox_bride 3-3→3-5、elite_void_sentinel 5-1→5-3。

const Chapter1ContentScript = preload("res://scripts/data/chapter_1_content.gd")
const Chapter2ContentScript = preload("res://scripts/data/chapter_2_content.gd")
const Chapter3ContentScript = preload("res://scripts/data/chapter_3_content.gd")
const Chapter4ContentScript = preload("res://scripts/data/chapter_4_content.gd")
const Chapter5ContentScript = preload("res://scripts/data/chapter_5_content.gd")

# 硬编码期望 id 集合：任一 elite_* id 被改（重命名/删除/新增）都会使本合约失败。
const EXPECTED_IDS: Array[String] = [
	"elite_bronze_mirror_keeper",
	"elite_elixir_golem",
	"elite_siege_commander",
	"elite_torture_master",
	"elite_beacon_lord",
	"elite_memory_eater",
	"elite_fox_bride",
	"elite_reflection_lord",
	"elite_ember_greed_ghost",
	"elite_celestial_swordsman",
	"elite_alchemy_master",
	"elite_scripture_keeper",
	"elite_void_sentinel",
	"elite_gravity_twister",
	"elite_soul_forger_echo",
]

# id → {display_name, appears_in}，display_name 以各章 chapter-supplement 设计名册为准。
const EXPECTED := {
	"elite_bronze_mirror_keeper": {"display_name": "Formation-Guarding Stone Sentinel / 守阵石卫", "appears_in": "level_01_03"},
	"elite_elixir_golem": {"display_name": "Alchemy-Obsessed Spirit / 炼丹痴魂", "appears_in": "level_01_04"},
	"elite_siege_commander": {"display_name": "Gluttonous Quartermaster / 贪噬军需官", "appears_in": "level_02_05"},
	"elite_torture_master": {"display_name": "Forge-Rage Engine / 炉暴刑具", "appears_in": "level_02_03"},
	"elite_beacon_lord": {"display_name": "Twin Beacon Generals / 双生烽火守将", "appears_in": "level_02_04"},
	"elite_memory_eater": {"display_name": "Thousand-Year Tree Spirit / 千年树魂", "appears_in": "level_03_02"},
	"elite_fox_bride": {"display_name": "Maze Poet / 迷宫诗人", "appears_in": "level_03_05"},
	"elite_reflection_lord": {"display_name": "Mirror Lake Dream-Weaver / 镜湖织梦者", "appears_in": "level_03_04"},
	"elite_ember_greed_ghost": {"display_name": "Ember-Greedy Ghost / 贪烬鬼", "appears_in": "level_03_04"},
	"elite_celestial_swordsman": {"display_name": "Cloud Bridge Guardian / 云桥守将", "appears_in": "level_04_01"},
	"elite_alchemy_master": {"display_name": "Falling Sky Artisan / 坠天工匠", "appears_in": "level_04_02"},
	"elite_scripture_keeper": {"display_name": "Scripture Guardian / 经文守卫", "appears_in": "level_04_03"},
	"elite_void_sentinel": {"display_name": "Sea of Possibilities / 可能性之海", "appears_in": "level_05_03"},
	"elite_gravity_twister": {"display_name": "Avatar of Anti-Entropy / 逆熵化身", "appears_in": "level_05_02"},
	"elite_soul_forger_echo": {"display_name": "The Last Torch-Servant / 最后的烛阴侍者", "appears_in": "level_05_04"},
}

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	_test_ids_unchanged()
	_test_names_and_positions()
	if _failures.is_empty():
		print("ELITE_NAME_CONTRACTS_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _all_elites() -> Array[Dictionary]:
	var all: Array[Dictionary] = []
	for script in [
		Chapter1ContentScript,
		Chapter2ContentScript,
		Chapter3ContentScript,
		Chapter4ContentScript,
		Chapter5ContentScript,
	]:
		for elite in script.elites():
			all.append(elite)
	return all


func _test_ids_unchanged() -> void:
	var actual: Array[String] = []
	for elite in _all_elites():
		actual.append(String(elite.get("id", "")))
	var actual_sorted := actual.duplicate()
	actual_sorted.sort()
	var expected_sorted := EXPECTED_IDS.duplicate()
	expected_sorted.sort()
	_expect(
		actual_sorted == expected_sorted,
		"elite id 集合被改动: got %s expected %s" % [actual_sorted, expected_sorted]
	)


func _test_names_and_positions() -> void:
	for elite in _all_elites():
		var id: String = String(elite.get("id", ""))
		var expected: Dictionary = EXPECTED.get(id, {})
		if expected.is_empty():
			_failures.append("未知 elite id（不在期望表内）: %s" % id)
			continue
		_expect(
			String(elite.get("display_name", "")) == String(expected.get("display_name", "")),
			"%s: display_name got '%s' expected '%s'" % [
				id, elite.get("display_name", ""), expected.get("display_name", "")
			]
		)
		_expect(
			String(elite.get("appears_in", "")) == String(expected.get("appears_in", "")),
			"%s: appears_in got '%s' expected '%s'" % [
				id, elite.get("appears_in", ""), expected.get("appears_in", "")
			]
		)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
