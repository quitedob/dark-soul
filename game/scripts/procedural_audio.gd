extends Node

# 重击低通 duck：闷住高频后短时恢复
const DUCK_CUTOFF_OPEN_HZ := 20500.0
const DUCK_CUTOFF_CLOSED_HZ := 650.0
const DUCK_DURATION_DEFAULT := 0.18

var library: Dictionary = {}
var players: Array[AudioStreamPlayer] = []
var _shutting_down := false
var _audio_enabled := true
var _next_voice := 0
# Master 总线低通效果引用（headless 下保持 null）
var _low_pass: AudioEffectLowPassFilter = null
var _low_pass_bus := -1
var _low_pass_effect_idx := -1
var _low_pass_owned := false
var _duck_tween: Tween = null


func _ready() -> void:
	_audio_enabled = DisplayServer.get_name() != "headless"
	if not _audio_enabled:
		return
	library = {
		"swing": _make_tone(150.0, 0.13, 0.22, true),
		"heavy": _make_tone(95.0, 0.22, 0.3, true),
		"hit": _make_noise(0.09, 0.35),
		"parry_shield": _make_layered_tone([220.0, 660.0], 0.18, 0.16),
		"parry_buckler": _make_layered_tone([330.0, 880.0], 0.24, 0.18),
		"parry_dagger": _make_layered_tone([440.0, 990.0], 0.14, 0.12),
		"parry_fist": _make_tone(180.0, 0.10, 0.16, true),
		"hurt": _make_tone(75.0, 0.18, 0.24, false),
		"dodge": _make_noise(0.14, 0.14),
		"rest": _make_chime(),
		"death": _make_tone(55.0, 0.7, 0.3, false),
		"recover": _make_tone(520.0, 0.25, 0.18, false),
		"victory": _make_victory(),
	}
	for index in 6:
		var player := AudioStreamPlayer.new()
		player.name = "Voice%d" % index
		player.finished.connect(_on_voice_finished.bind(index))
		add_child(player)
		players.append(player)
	# 挂载/复用 Master 低通，供重击 duck
	_ensure_low_pass()


func play_cue(cue: String, volume_db: float = -7.0, pitch: float = 1.0) -> void:
	if not _audio_enabled or _shutting_down or players.is_empty() or not library.has(cue):
		return
	# Round-robin: prefer an idle voice; if none idle, steal from _next_voice and advance.
	var player := players[_next_voice % players.size()]
	for candidate in players:
		if not candidate.playing:
			player = candidate
			break
	if player.playing:
		player.stop()
		_next_voice += 1
	player.stream = null
	player.stream = library[cue]
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()


## 重击命中时短时降低截止频率，制造闷击感；headless 直接 no-op
func duck_heavy_impact(duration: float = DUCK_DURATION_DEFAULT) -> void:
	if not _audio_enabled or _shutting_down or _low_pass == null:
		return
	var duck_seconds := maxf(duration, 0.05)
	if _duck_tween != null and is_instance_valid(_duck_tween):
		_duck_tween.kill()
	_low_pass.cutoff_hz = DUCK_CUTOFF_CLOSED_HZ
	_duck_tween = create_tween()
	# 先短暂保持闷声，再平滑恢复通透
	var hold := duck_seconds * 0.35
	var release := duck_seconds * 0.65
	_duck_tween.tween_interval(hold)
	_duck_tween.tween_property(
		_low_pass, "cutoff_hz", DUCK_CUTOFF_OPEN_HZ, release
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


func _ensure_low_pass() -> void:
	_low_pass_bus = AudioServer.get_bus_index("Master")
	if _low_pass_bus < 0:
		return
	# 优先复用总线上已有低通，避免重复叠加
	for effect_idx in AudioServer.get_bus_effect_count(_low_pass_bus):
		var effect := AudioServer.get_bus_effect(_low_pass_bus, effect_idx)
		if effect is AudioEffectLowPassFilter:
			_low_pass = effect as AudioEffectLowPassFilter
			_low_pass_effect_idx = effect_idx
			_low_pass_owned = false
			_low_pass.cutoff_hz = DUCK_CUTOFF_OPEN_HZ
			return
	_low_pass = AudioEffectLowPassFilter.new()
	_low_pass.cutoff_hz = DUCK_CUTOFF_OPEN_HZ
	AudioServer.add_bus_effect(_low_pass_bus, _low_pass)
	_low_pass_effect_idx = AudioServer.get_bus_effect_count(_low_pass_bus) - 1
	_low_pass_owned = true


func _on_voice_finished(index: int) -> void:
	if _shutting_down or index < 0 or index >= players.size():
		return
	var player := players[index]
	if is_instance_valid(player) and not player.playing:
		player.stream = null


func _exit_tree() -> void:
	_shutting_down = true
	if _duck_tween != null and is_instance_valid(_duck_tween):
		_duck_tween.kill()
	_duck_tween = null
	# 离开场景时恢复截止频率；自建效果则卸下
	if _low_pass != null:
		_low_pass.cutoff_hz = DUCK_CUTOFF_OPEN_HZ
		if _low_pass_owned and _low_pass_bus >= 0 and _low_pass_effect_idx >= 0:
			if _low_pass_effect_idx < AudioServer.get_bus_effect_count(_low_pass_bus):
				AudioServer.remove_bus_effect(_low_pass_bus, _low_pass_effect_idx)
	_low_pass = null
	_low_pass_bus = -1
	_low_pass_effect_idx = -1
	_low_pass_owned = false
	for player in players:
		if not is_instance_valid(player):
			continue
		player.stop()
		player.stream = null
	players.clear()
	library.clear()


func _make_tone(frequency: float, duration: float, amplitude: float, sweep_down: bool) -> AudioStreamWAV:
	var sample_rate := 22050
	var frames := int(duration * sample_rate)
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	for frame in frames:
		var progress := float(frame) / float(maxi(frames - 1, 1))
		var envelope := sin(progress * PI) * amplitude
		var current_frequency := frequency * (1.0 - progress * 0.45) if sweep_down else frequency * (1.0 + progress * 0.08)
		var sample := sin(TAU * current_frequency * float(frame) / float(sample_rate)) * envelope
		_write_sample(bytes, frame, sample)
	return _wav_from_bytes(bytes, sample_rate)


func _make_noise(duration: float, amplitude: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var frames := int(duration * sample_rate)
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	var seed_value := 918273
	for frame in frames:
		seed_value = int((seed_value * 1103515245 + 12345) & 0x7fffffff)
		var noise := (float(seed_value % 2000) / 1000.0) - 1.0
		var progress := float(frame) / float(maxi(frames - 1, 1))
		_write_sample(bytes, frame, noise * (1.0 - progress) * amplitude)
	return _wav_from_bytes(bytes, sample_rate)


func _make_chime() -> AudioStreamWAV:
	return _make_layered_tone([330.0, 495.0, 660.0], 0.75, 0.12)


func _make_victory() -> AudioStreamWAV:
	return _make_layered_tone([220.0, 277.0, 330.0, 440.0], 1.2, 0.1)


func _make_layered_tone(frequencies: Array[float], duration: float, amplitude: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var frames := int(duration * sample_rate)
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	for frame in frames:
		var progress := float(frame) / float(maxi(frames - 1, 1))
		var sample := 0.0
		for frequency in frequencies:
			sample += sin(TAU * frequency * float(frame) / float(sample_rate))
		sample /= float(frequencies.size())
		_write_sample(bytes, frame, sample * pow(1.0 - progress, 1.6) * amplitude)
	return _wav_from_bytes(bytes, sample_rate)


func _write_sample(bytes: PackedByteArray, frame: int, value: float) -> void:
	var sample := int(clampf(value, -1.0, 1.0) * 32767.0)
	if sample < 0:
		sample += 65536
	bytes[frame * 2] = sample & 0xff
	bytes[frame * 2 + 1] = (sample >> 8) & 0xff


func _wav_from_bytes(bytes: PackedByteArray, sample_rate: int) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = bytes
	return stream
