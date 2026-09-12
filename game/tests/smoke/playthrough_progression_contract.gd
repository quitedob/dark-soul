extends SceneTree
## 脚本化通关合约：驱动真实 game_world 依序推进主线 29 关，击败 8 个 Boss（真实
## defeated → victory → 出口 → 转场流），终局提交裁决并触发分结局尾声。
## 这是最接近「真实玩家通关」的确定性证据（真实游戏循环，非纯数据断言）。

const WorldScene = preload("res://scenes/world/ashen_hollow.tscn")
const EndingResolverScript = preload("res://scripts/story/ending_resolver.gd")

## 命运抉择 Boss（剧情阈值 → 命运抉择 → conclude → defeated）
const FATE_BY_BOSS := {
	"boss_giant_gate": [&"ch1_guardian_fate", "released"],
	"boss_xing_tian": [&"ch2_xingtian_fate", "honored"],
	"boss_nine_tails": [&"ch3_nine_tails_fate", "redeemed"],
	"boss_xuan_xiao": [&"ch4_xuanxiao_fate", "ascended"],
	"boss_zhu_yin": [&"ending_state", "kindle"],
}

var _failures: Array[String] = []
var _world


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	# 清掉可能残留的存档，保证从 1-1 新局（`_on_campaign_exit_requested` 会写档，此处双端清理防污染）
	_clear_save()
	_world = WorldScene.instantiate()
	root.add_child(_world)
	# 等 game_world._ready 完成（系统建立 + 初始状态 + call_deferred 导航）。smoke 用 2s。
	await create_timer(2.0).timeout
	var campaign_runtime = _world.get("campaign_runtime")
	_expect(campaign_runtime != null, "campaign_runtime missing after boot")
	if campaign_runtime == null:
		_world.free()
		_finish()
		return

	var boss_defeated := 0
	var reached_ending := false
	var current := StringName(campaign_runtime.current_level_id)
	var steps := 0
	while steps < 30:
		steps += 1
		var level_data: Dictionary = campaign_runtime.get_level_data()
		var boss_id := String(level_data.get("boss_id", ""))
		_expect(
			campaign_runtime.current_level_id == current,
			"runtime id mismatch at %s (got %s)" % [current, campaign_runtime.current_level_id]
		)
		if not boss_id.is_empty():
			var guardian = _world.get("guardian")
			_expect(guardian != null and is_instance_valid(guardian), "boss %s missing" % boss_id)
			if guardian != null and is_instance_valid(guardian):
				if boss_id in FATE_BY_BOSS:
					var fc: Array = FATE_BY_BOSS[boss_id]
					if guardian.has_method("enter_story_resolution"):
						guardian.enter_story_resolution()
					_world._pending_fate_boss = guardian
					_world._on_fate_choice_made(fc[0], fc[1])
				else:
					guardian.receive_hit(999999.0, 0.0, Vector3.ZERO, null)
				await process_frame
				await process_frame
				boss_defeated += 1
				_expect(bool(_world.get("victory")), "boss %s did not set victory" % boss_id)
		var next: Dictionary = campaign_runtime.registry.get_next_level(current)
		if next.is_empty():
			reached_ending = true
			break
		_world._on_campaign_exit_requested(current)
		await process_frame
		await process_frame
		current = StringName(campaign_runtime.current_level_id)

	_expect(boss_defeated == 7, "expected 7 main-chain bosses, got %d" % boss_defeated)
	_expect(reached_ending, "did not reach terminal level 5-5")

	# 终末裁决已提交 → resolve 读回 kindle
	var run_state = _world.get("run_state")
	var ending := EndingResolverScript.resolve(run_state)
	_expect(ending == EndingResolverScript.ENDING_KINDLE, "ending not kindle, got %s" % ending)

	# 可选 Boss 盲钟（level_05_06 独立关，next 为空，不承主线）
	_world._load_campaign_level(&"level_05_06")
	await process_frame
	var bell = _world.get("guardian")
	_expect(bell != null and is_instance_valid(bell), "optional boss 盲钟 missing")
	if bell != null and is_instance_valid(bell):
		bell.receive_hit(999999.0, 0.0, Vector3.ZERO, null)
		await process_frame
		boss_defeated += 1
		_expect(bool(_world.get("victory")), "盲钟 did not set victory")

	_expect(boss_defeated == 8, "expected 8 total bosses, got %d" % boss_defeated)

	# Use the optional arena's real return exit first, then traverse its parent
	# chapter back to the terminal arena. An exit ID cannot stand in for loading
	# that level: the production handler uses the active level's return metadata.
	var return_level := StringName(campaign_runtime.get_level_data().get("return_level_id", ""))
	_expect(not return_level.is_empty(), "optional boss arena must declare its return level")
	_world._on_campaign_exit_requested(StringName(campaign_runtime.current_level_id))
	await process_frame
	await process_frame
	_expect(campaign_runtime.current_level_id == return_level, "optional boss exit did not return to its entrance level")
	var return_steps := 0
	while campaign_runtime.current_level_id != &"level_05_05" and return_steps < campaign_runtime.registry.get_levels().size():
		return_steps += 1
		var from_level := StringName(campaign_runtime.current_level_id)
		var next: Dictionary = campaign_runtime.registry.get_next_level(from_level)
		if next.is_empty():
			_expect(false, "optional return cannot reach final arena from %s" % from_level)
			break
		_world._on_campaign_exit_requested(from_level)
		await process_frame
		await process_frame
		_expect(campaign_runtime.current_level_id == StringName(next["id"]),
			"return transition did not reach %s" % next["id"])
	_expect(campaign_runtime.current_level_id == &"level_05_05", "terminal exit requires the active final arena")
	if campaign_runtime.current_level_id == &"level_05_05":
		_world._on_campaign_exit_requested(StringName(campaign_runtime.current_level_id))
	var hud = _world.get("hud")
	_expect(
		hud != null and hud.epilogue_overlay != null and hud.epilogue_overlay.visible,
		"epilogue overlay did not show after 5-5 exit"
	)

	_world.free()
	_clear_save()
	_finish()


func _clear_save() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://ashen_hollow_run_v1.json"))


func _finish() -> void:
	if _failures.is_empty():
		print("ASHEN_PLAYTHROUGH_PROGRESSION_CONTRACTS_OK")
		quit(0)
	else:
		for f in _failures:
			push_error(f)
		quit(1)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)
