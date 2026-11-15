extends Node
## Música persistente e mixagem de eventos de missão. Os controles atuam nos buses.

const THEME_PATH := "res://assets/audio/music/descent_to_tranquility.ogg"
const DESCENT_PATH := "res://assets/audio/music/cosmic_ascent.ogg"
const SETTINGS_PATH := "user://audio_settings.cfg"
const CHANNELS := ["Master", "Music", "Voice", "SFX", "Ambience"]
const RATE := 22050
const MUSIC_LEVELS := {
	"menu": -2.0, "planning": -10.0, "cutscene": -12.0, "separation": -18.0,
	"cabin": -16.0, "landing": -19.0, "report": -7.0, "transition": -10.0, "reentry": -22.0,
}
# Frequências em sequência, duração e contribuição de ruído das sínteses originais.
const CUES := {
	"add": [[520, 780], 0.14, 0.04], "remove": [[450, 310], 0.14, 0.05],
	"confirm": [[392, 587, 784], 0.31, 0.03], "back": [[440, 330], 0.13, 0.03],
	"switch": [[185], 0.09, 0.55], "belt": [[145, 227], 0.20, 0.57],
	"food": [[170, 123, 185], 0.26, 0.78], "water": [[330, 260, 420], 0.31, 0.22],
	"contact": [[84, 112], 0.16, 0.63], "hatch": [[122, 88, 145], 0.40, 0.68],
	"ignition": [[92, 72, 57], 0.77, 0.52], "cutoff": [[150, 85, 52], 0.34, 0.46],
	"dock": [[106, 82, 197], 0.61, 0.58], "success": [[330, 494, 659], 0.58, 0.04],
	"assist": [[330, 440, 587, 659], 0.65, 0.14], "radio": [[1250, 790], 0.15, 0.44],
	"warning": [[710, 450], 0.26, 0.06], "abort": [[425, 258, 163], 0.55, 0.23],
	"impact": [[78, 58, 41], 0.86, 0.73],
}

var _theme_player: AudioStreamPlayer
var _descent_player: AudioStreamPlayer
var _descent_active := false
var _fan: AudioStreamPlayer
var _engine: AudioStreamPlayer
var _pulse: AudioStreamPlayer
var _voices: Array[AudioStreamPlayer] = []
var _bank: Dictionary = {}
var _last_cue: Dictionary = {}
var _scene := ""
var _music_level := -60.0
var _motor_power := 0.0
var _risk := false
var _priority_time := 0.0
var _music_wait := 0.0
var _theme_has_started := false
var _audio_enabled := true
var _report_wait := 0.0
var _settings := ConfigFile.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_settings.load(SETTINGS_PATH)
	for channel: String in CHANNELS:
		if _settings.has_section_key("volume", channel):
			_apply_volume(channel, clampf(float(_settings.get_value("volume", channel)), 0.0, 1.0))
	_theme_player = _player("Music", load(THEME_PATH) if ResourceLoader.exists(THEME_PATH) else null)
	_theme_player.finished.connect(func():
		_theme_has_started = false
		_music_wait = 3.0)
	_descent_player = _player("Music", load(DESCENT_PATH) if ResourceLoader.exists(DESCENT_PATH) else null)
	# O driver sem saída dos testes headless não precisa instanciar reproduções.
	_audio_enabled = DisplayServer.get_name() != "headless"
	set_process(_audio_enabled)
	_fan = _player("Ambience", _loop("fan"))
	_engine = _player("SFX", _loop("engine"))
	_pulse = _player("Music", _loop("pulse"))
	for index in range(8):
		_voices.append(_player("SFX", null))


func _player(bus_name: String, stream: AudioStream) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = bus_name
	player.stream = stream
	player.volume_db = -60.0
	add_child(player)
	return player


func enter_scene(scene: String) -> void:
	_scene = scene
	_music_level = MUSIC_LEVELS.get(scene, -60.0)
	_music_wait = 0.0
	_report_wait = 0.65 if scene == "report" else 0.0
	_motor_power = 0.0
	_risk = false
	_priority_time = 0.0
	_last_cue.clear()
	_descent_active = false
	_descent_player.stop()
	_engine.stop()
	_pulse.stop()
	_fan.stop()
	for voice in _voices:
		if voice.bus != "Interface":
			voice.stop()


func cutscene_segment(sequence: String, index: int, has_video: bool) -> void:
	_motor_power = 0.0
	_music_level = -26.0 if has_video else -17.0
	if has_video:
		return
	match sequence:
		"launch":
			if index == 0 or index == 2:
				play_cue("ignition")
				_music_level = -7.0 if index == 2 else -12.0
				_motor_power = 0.85 if index == 2 else 0.24
		"docking", "undocking":
			if index == 0:
				play_cue("dock")
		"landing_success":
			_music_level = -27.0
		"landing_fail", "separation_fail":
			_music_level = -34.0
			if sequence == "separation_fail":
				play_cue("abort", "Voice", true)


func set_motor(power: float) -> void:
	_motor_power = clampf(power, 0.0, 1.0)


func set_landing_margin(fuel_ratio: float) -> void:
	if not _risk and fuel_ratio < 0.20:
		_risk = true
		play_cue("warning", "Voice", true)
	elif _risk and fuel_ratio > 0.25:
		_risk = false


func start_descent() -> void:
	if not _audio_enabled or _descent_player.stream == null:
		return
	_music_level = -60.0
	_descent_active = true
	_descent_player.volume_db = -60.0
	_descent_player.play(48.0)


func end_maneuver() -> void:
	_descent_active = false
	_motor_power = 0.0
	_risk = false


func play_cue(id: String, bus_name := "SFX", priority := false) -> void:
	if not _audio_enabled or not CUES.has(id):
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_cue.get(id, -1000)) < 110:
		return
	var player: AudioStreamPlayer
	for voice in _voices:
		if not voice.playing:
			player = voice
			break
	if player == null and priority:
		for voice in _voices:
			if voice.bus != "Voice":
				player = voice
				break
	if player == null:
		return
	_last_cue[id] = now
	if priority:
		_priority_time = maxf(_priority_time, 1.1)
	player.stop()
	player.bus = bus_name
	player.stream = _cue(id)
	player.volume_db = -10.0 if priority else -16.0
	player.play()


func play_at(id: String, parent: Node3D) -> void:
	if not _audio_enabled or not CUES.has(id):
		return
	var player := AudioStreamPlayer3D.new()
	player.bus = "SFX"
	player.stream = _cue(id)
	player.volume_db = -13.0
	player.unit_size = 0.55
	player.max_distance = 7.0
	parent.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func volume(channel: String) -> float:
	var index := AudioServer.get_bus_index(channel)
	return 0.0 if AudioServer.is_bus_mute(index) else db_to_linear(AudioServer.get_bus_volume_db(index))


func set_volume(channel: String, value: float) -> void:
	_apply_volume(channel, value)
	_settings.set_value("volume", channel, value)
	var error := _settings.save(SETTINGS_PATH)
	if error != OK:
		push_warning("Não foi possível salvar o volume: %s" % error_string(error))


func _apply_volume(channel: String, value: float) -> void:
	var index := AudioServer.get_bus_index(channel)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, 0.001)))
	AudioServer.set_bus_mute(index, value <= 0.0)


func _process(delta: float) -> void:
	var paused := get_tree().paused
	_priority_time = maxf(_priority_time - delta, 0.0)
	var priority := Houston.is_busy() or _priority_time > 0.0
	_music_wait = maxf(0.0, _music_wait - delta)
	_report_wait = maxf(0.0, _report_wait - delta)
	if not paused and _theme_player.stream != null and not _theme_has_started and _music_wait == 0.0 and _report_wait == 0.0 and _scene in ["menu", "planning", "cutscene", "report", "transition"]:
		_theme_has_started = true
		_theme_player.play()
	var music_db := (-33.0 if _report_wait > 0.0 else _music_level) - (12.0 if priority else 0.0) - (8.0 if _risk else 0.0)
	_fade(_theme_player, music_db, delta)
	_theme_player.stream_paused = paused
	var descent_db := -10.0 - (12.0 if priority else 0.0) - (8.0 if _risk else 0.0)
	_fade(_descent_player, descent_db if _descent_active else -60.0, delta)
	if not _descent_active and _descent_player.playing and _descent_player.volume_db <= -58.0:
		_descent_player.stop()
	_descent_player.stream_paused = paused
	_mix_loop(_fan, _scene == "cabin", -28.0 - (8.0 if priority else 0.0), paused, delta)
	_mix_loop(_engine, _motor_power > 0.005, lerpf(-36.0, -15.0, _motor_power) - (9.0 if priority else 0.0), paused, delta)
	_engine.pitch_scale = lerpf(0.75, 1.13, _motor_power)
	_mix_loop(_pulse, _risk, -23.0 - (12.0 if priority else 0.0), paused, delta)
	for player in _voices:
		player.stream_paused = paused and player.bus != "Interface"


func _mix_loop(player: AudioStreamPlayer, active: bool, level: float, paused: bool, delta: float) -> void:
	if active and not paused and not player.playing:
		player.volume_db = -60.0
		player.play()
	_fade(player, level if active else -60.0, delta)
	if not active and player.volume_db <= -58.0:
		player.stop()
	player.stream_paused = paused


func _fade(player: AudioStreamPlayer, level: float, delta: float) -> void:
	var speed := 9.0 if level < player.volume_db else 3.5
	player.volume_db = lerpf(player.volume_db, level, 1.0 - exp(-delta * speed))


func _cue(id: String) -> AudioStreamWAV:
	if _bank.has(id):
		return _bank[id]
	var spec: Array = CUES[id]
	var notes: Array = spec[0]
	var count := int(RATE * float(spec[1]))
	var noise_mix: float = spec[2]
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = id.hash()
	var filtered := 0.0
	var phase := 0.0
	for i in range(count):
		var segment := float(i) * notes.size() / count
		phase += TAU * float(notes[int(segment)]) / RATE
		filtered = lerpf(filtered, rng.randf_range(-1.0, 1.0), 0.46)
		var edge := minf(1.0, minf(i / 110.0, (count - i) / 660.0))
		var decay := 1.0 - 0.7 * fmod(segment, 1.0)
		var tone := 0.8 * sin(phase) + 0.12 * sin(2.01 * phase)
		data.encode_s16(i * 2, int(22000.0 * edge * decay * lerpf(tone, filtered, noise_mix)))
	var stream := _pcm(data)
	_bank[id] = stream
	return stream


func _loop(id: String) -> AudioStreamWAV:
	var count := RATE * 2
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in range(count):
		var t := float(i) / RATE
		var sample: float
		match id:
			"pulse":
				var beat := fmod(t, 0.5)
				var envelope := minf(1.0, beat * 190.0) * exp(-18.0 * beat)
				sample = envelope * (0.72 * sin(TAU * 63.0 * beat) + 0.22 * sin(TAU * 126.0 * beat))
			"fan":
				var air := sin(TAU * 107.0 * t) * sin(TAU * 131.5 * t)
				sample = 0.45 * sin(TAU * 59.5 * t) + 0.24 * air + 0.09 * sin(TAU * 2.5 * t)
			_:
				var rumble := sin(TAU * 87.5 * t) * sin(TAU * 111.5 * t)
				sample = 0.44 * sin(TAU * 42.0 * t) + 0.25 * sin(TAU * 54.5 * t) + 0.23 * rumble
		data.encode_s16(i * 2, int(sample * 24000.0))
	var stream := _pcm(data)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = count
	return stream


func _pcm(data: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	return stream
