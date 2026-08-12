extends SceneTree
## L-23 合约：音频系统（procedural_audio.gd / audio-system.md）。
## 1) procedural_audio.tscn 可实例化且暴露 play_cue / duck_heavy_impact 契约 API。
## 2) headless 静默契约：_audio_enabled = (DisplayServer != headless)；headless 下
##    play_cue / duck_heavy_impact 为安全 no-op，不建 cue 库 / 语音池。
## 3) 过程化 PCM 生成器产出合法 16-bit / 22050Hz WAV（音效系统真实可运行入口）。
## 4) C-06 总线布局：Master / Music / SFX 存在且 Music 总线音量可设。

const AudioScene = preload("res://scenes/audio/procedural_audio.tscn")
const AudioScript = preload("res://scripts/procedural_audio.gd")

var _failures: Array[String] = []


func _init() -> void:
	_test_scene_instantiates_with_api()
	_test_headless_silent_contract()
	_test_procedural_wav_generators()
	_test_audio_bus_layout_and_volume()
	if _failures.is_empty():
		print("ASHEN_AUDIO_CONTRACTS_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_scene_instantiates_with_api() -> void:
	var audio = AudioScene.instantiate()
	_expect(audio != null, "Procedural audio scene must instantiate.")
	_expect(audio.has_method("play_cue"), "Audio node must expose play_cue.")
	_expect(audio.has_method("duck_heavy_impact"), "Audio node must expose duck_heavy_impact.")
	_expect(audio.get("_audio_enabled") is bool, "Audio node must track its enabled flag.")
	audio.free()


func _test_headless_silent_contract() -> void:
	var audio = AudioScene.instantiate()
	# SceneTree --script 的 _init 阶段不会触发子节点 _ready，导致默认 _audio_enabled=true。
	# 手动调用 _ready 使其进入既定状态；headless 下 _ready 只设标志并提前返回，幂等安全。
	audio._ready()
	var is_headless := DisplayServer.get_name() == "headless"
	var expected_enabled := DisplayServer.get_name() != "headless"
	_expect(
		bool(audio._audio_enabled) == expected_enabled,
		"Audio enable flag must follow the headless contract."
	)
	# 这些调用在 headless 下必须静默 no-op，不崩溃、不告警
	audio.play_cue("swing", -6.0, 1.1)
	audio.play_cue("totally_unknown_cue")
	audio.duck_heavy_impact()
	if is_headless:
		_expect(audio.library.is_empty(), "Headless must not build the cue library.")
		_expect(audio.players.is_empty(), "Headless must not build the voice pool.")
	audio.free()


func _test_procedural_wav_generators() -> void:
	var generator = AudioScript.new()
	var tone: AudioStreamWAV = generator._make_tone(150.0, 0.13, 0.22, true)
	var noise: AudioStreamWAV = generator._make_noise(0.09, 0.35)
	var chime: AudioStreamWAV = generator._make_chime()
	var victory: AudioStreamWAV = generator._make_victory()
	for stream in [tone, noise, chime, victory]:
		_expect(stream != null, "Procedural generator must return an AudioStreamWAV.")
		if stream == null:
			continue
		_expect(stream.format == AudioStreamWAV.FORMAT_16_BITS, "Generated audio must be 16-bit.")
		_expect(stream.mix_rate == 22050, "Generated audio must use 22050 Hz.")
		_expect(stream.data.size() > 0, "Generated audio must contain PCM samples.")
	generator.free()


func _test_audio_bus_layout_and_volume() -> void:
	var master := AudioServer.get_bus_index("Master")
	_expect(master >= 0, "Master audio bus must exist.")
	var music := AudioServer.get_bus_index("Music")
	_expect(music >= 0, "Music audio bus must exist (C-06 music bus).")
	var sfx := AudioServer.get_bus_index("SFX")
	_expect(sfx >= 0, "SFX audio bus must exist.")
	if music >= 0:
		var previous := AudioServer.get_bus_volume_db(music)
		AudioServer.set_bus_volume_db(music, linear_to_db(0.42))
		_expect(
			is_equal_approx(AudioServer.get_bus_volume_db(music), linear_to_db(0.42)),
			"Music bus volume must be settable."
		)
		AudioServer.set_bus_volume_db(music, previous)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
