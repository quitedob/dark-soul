extends SceneTree
## Smoke contract for PhaseEnvironment (boss-phase lighting shifter).
## Verifies:
##   1) known_keys lists the content-file lighting keys (incl. both chapter-1 keys);
##   2) apply_lighting_key(..., 0.0) applies instantly (fire-orange profile);
##   3) cool_blue_moonlight lands on the world defaults;
##   4) restore_defaults() returns to the bind()-time snapshot (glow sentinel proves
##      it is the snapshot, not the table entry);
##   5) unknown keys fall back to the generic phase ramp without crashing;
##   6) tween path: values hold at start, converge after the duration elapses.
## Prints ASHEN_PHASE_ENV_OK on success.
## Run: godot --headless --path game --script res://tests/smoke/phase_environment_contract_test.gd
const PhaseEnvironment = preload("res://scripts/fx/phase_environment.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	# 现搭一套 world_environment.gd 的默认环境（glow 用哨兵值 0.62）
	var env := Environment.new()
	env.fog_enabled = true
	env.fog_light_color = Color("26405a")
	env.fog_density = 0.010
	env.fog_light_energy = 0.42
	env.ambient_light_color = Color("526882")
	env.ambient_light_energy = 0.28
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.62  # sentinel: restore must return here, not to table 0.55
	env.glow_bloom = 0.25
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 0.95
	var we := WorldEnvironment.new()
	we.name = "NightEnvironment"
	we.environment = env
	var moon := DirectionalLight3D.new()
	moon.name = "Moonlight"
	moon.light_color = Color("a8c2de")
	moon.light_energy = 1.05
	get_root().add_child(we)
	get_root().add_child(moon)

	var shifter := PhaseEnvironment.new()
	shifter.name = "PhaseEnvironmentUnderTest"
	get_root().add_child(shifter)
	await process_frame

	# 1) known keys
	var keys: Array[String] = PhaseEnvironment.known_keys()
	for expected in ["cool_blue_moonlight", "flickering_fire_orange", "crimson_rage_glow", "chaotic_multicolor_void", "darkness_ember_only"]:
		if not keys.has(expected):
			failures.append("known_keys missing: " + expected)
	if keys.size() < 21:
		failures.append("known_keys only %d entries (< 21)" % keys.size())

	# 2) bind + instant fire-orange
	shifter.bind(we, moon)
	if shifter.active_key != "":
		failures.append("active_key not empty after bind")
	shifter.apply_lighting_key("flickering_fire_orange", 0.0)
	if absf(env.fog_density - 0.026) > 0.0005:
		failures.append("instant fog_density %.4f != 0.026" % env.fog_density)
	if absf(moon.light_energy - 0.75) > 0.001:
		failures.append("instant moon energy %.4f != 0.75" % moon.light_energy)
	if _color_dist(env.fog_light_color, Color("3a1f14")) > 0.004:
		failures.append("instant fog color off")
	if shifter.active_key != "flickering_fire_orange":
		failures.append("active_key not set after apply")

	# 3) cool blue → world defaults
	shifter.apply_lighting_key("cool_blue_moonlight", 0.0)
	if absf(env.fog_density - 0.010) > 0.0005:
		failures.append("cool_blue fog_density %.4f != 0.010" % env.fog_density)
	if absf(moon.light_energy - 1.05) > 0.001:
		failures.append("cool_blue moon energy %.4f != 1.05" % moon.light_energy)
	if absf(env.glow_intensity - 0.55) > 0.001:
		failures.append("cool_blue glow %.4f != 0.55 table entry" % env.glow_intensity)

	# 4) restore to bind() snapshot (sentinel 0.62)
	shifter.restore_defaults(0.0)
	if absf(env.glow_intensity - 0.62) > 0.001:
		failures.append("restore glow %.4f != 0.62 snapshot sentinel" % env.glow_intensity)
	if absf(env.fog_density - 0.010) > 0.0005:
		failures.append("restore fog_density %.4f != 0.010" % env.fog_density)
	if absf(moon.light_energy - 1.05) > 0.001:
		failures.append("restore moon energy %.4f != 1.05" % moon.light_energy)
	if _color_dist(env.fog_light_color, Color("26405a")) > 0.004:
		failures.append("restore fog color off")
	if shifter.active_key != "":
		failures.append("active_key not cleared after restore")

	# 5) unknown key → generic phase ramp (digit 9 → clamp phase 4), no crash
	shifter.apply_lighting_key("phase_9_unknown_gloom", 0.0)
	if not is_instance_valid(shifter):
		failures.append("shifter freed on unknown key")
	else:
		if absf(env.fog_density - 0.036) > 0.0005:
			failures.append("unknown-key fallback fog_density %.4f != 0.036" % env.fog_density)
		if shifter.active_key != "phase_9_unknown_gloom":
			failures.append("active_key not set for unknown key")

	# 6) tween path: hold at start, converge after the wait
	shifter.restore_defaults(0.0)
	shifter.apply_lighting_key("flickering_fire_orange", 0.2)
	if absf(env.fog_density - 0.010) > 0.005:
		failures.append("tween jumped instantly (fog_density %.4f at t=0)" % env.fog_density)
	await create_timer(0.45).timeout
	if absf(env.fog_density - 0.026) > 0.002:
		failures.append("tweened fog_density %.4f != 0.026 after wait" % env.fog_density)
	if absf(moon.light_energy - 0.75) > 0.01:
		failures.append("tweened moon energy %.4f != 0.75 after wait" % moon.light_energy)
	if _color_dist(env.fog_light_color, Color("3a1f14")) > 0.02:
		failures.append("tweened fog color not converged")

	_finish(failures)


func _color_dist(a: Color, b: Color) -> float:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("ASHEN_PHASE_ENV_OK")
	else:
		for f in failures:
			print("FAIL: " + f)
	print("ASHEN_DONE")
	quit(1 if not failures.is_empty() else 0)
