extends Node

var library: Dictionary = {}
var players: Array[AudioStreamPlayer] = []
var _shutting_down := false
var _audio_enabled := true


func _ready() -> void:
	_audio_enabled = DisplayServer.get_name() != "headless"
	if not _audio_enabled:
		return
	library = {
		"swing": _make_tone(150.0, 0.13, 0.22, true),
		"heavy": _make_tone(95.0, 0.22, 0.3, true),
		"hit": _make_noise(0.09, 0.35),
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


func play_cue(cue: String, volume_db: float = -7.0, pitch: float = 1.0) -> void:
	if not _audio_enabled or _shutting_down or players.is_empty() or not library.has(cue):
		return
	var player := players[0]
	for candidate in players:
		if not candidate.playing:
			player = candidate
			break
	if player.playing:
		player.stop()
	player.stream = null
	player.stream = library[cue]
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()


func _on_voice_finished(index: int) -> void:
	if _shutting_down or index < 0 or index >= players.size():
		return
	var player := players[index]
	if is_instance_valid(player) and not player.playing:
		player.stream = null


func _exit_tree() -> void:
	_shutting_down = true
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
