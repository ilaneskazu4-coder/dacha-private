extends Node
## Звуки, сгенерированные кодом (автозагрузка "Sfx"). Файлы со звуком не нужны.

var streams := {}
var pool: Array = []
var music_day: AudioStreamWAV
var music_night: AudioStreamWAV
var music_players: Array = []
var club_on := false
var music_disco: AudioStreamWAV


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for b in ["Music", "SFX"]:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var bi := AudioServer.bus_count - 1
			AudioServer.set_bus_name(bi, b)
			AudioServer.set_bus_send(bi, "Master")
	streams["honk"] = _synth([349.0, 440.0], 0.5, "square", 0.35, 3.0)
	streams["chop"] = _synth([180.0], 0.14, "noise", 0.7, 28.0)
	streams["fell"] = _synth([90.0, 140.0], 0.35, "saw", 0.5, 7.0, -0.5)
	streams["coin"] = _synth([988.0, 1319.0], 0.25, "sine", 0.45, 9.0)
	streams["goose"] = _synth([520.0, 560.0], 0.4, "saw", 0.3, 4.0, 0.4)
	streams["blip"] = _synth([660.0], 0.04, "square", 0.15, 20.0)
	streams["cheer"] = _synth([300.0, 400.0, 500.0], 0.7, "noise", 0.25, 3.0)
	streams["shout"] = _synth([220.0, 330.0], 0.35, "saw", 0.3, 5.0, 0.6)
	streams["engine"] = _synth([55.0, 82.0], 0.6, "saw", 0.4, 2.5, 0.8)
	streams["bite"] = _synth([140.0], 0.18, "noise", 0.6, 16.0)
	streams["build"] = _synth([220.0, 330.0], 0.2, "square", 0.3, 12.0)
	streams["hurt"] = _synth([120.0], 0.28, "saw", 0.5, 9.0, -0.6)
	streams["hit"] = _synth([110.0, 160.0], 0.12, "noise", 0.55, 24.0)
	streams["shot"] = _synth([95.0, 140.0], 0.22, "noise", 0.85, 17.0)
	streams["shotgun"] = _synth([70.0, 110.0], 0.4, "noise", 0.95, 9.0)
	streams["siren"] = _synth([700.0, 930.0], 1.0, "square", 0.18, 0.8, 0.3)
	streams["howl"] = _howl()
	streams["night"] = _synth([220.0, 165.0, 110.0], 0.9, "sine", 0.4, 2.5, -0.3)
	streams["dawn"] = _synth([523.0, 659.0, 784.0], 0.8, "sine", 0.35, 3.0)
	music_day = _music([261.6, 329.6, 392.0, 523.3, 392.0, 329.6, 293.7, 392.0, 440.0, 523.3, 440.0, 392.0, 349.2, 440.0, 392.0, 329.6], 0.5, 0.2, 0.9, true)
	music_night = _music([110.0, 0.0, 164.8, 0.0, 130.8, 0.0, 146.8, 0.0, 110.0, 0.0, 123.5, 0.0], 1.1, 0.26, 0.45, false)
	music_disco = _disco()
	for m in [music_day, music_night, music_disco]:
		var mp := AudioStreamPlayer.new()
		mp.stream = m
		mp.volume_db = -60.0
		mp.bus = "Music"
		add_child(mp)
		mp.play()
		music_players.append(mp)
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		pool.append(p)


func play(n: String, pitch: float = 1.0) -> void:
	if not streams.has(n):
		return
	for p in pool:
		if not p.playing:
			p.stream = streams[n]
			p.pitch_scale = pitch
			p.play()
			return


func _synth(freqs: Array, dur: float, wave: String, vol: float, decay: float, sweep: float = 0.0) -> AudioStreamWAV:
	var rate := 22050
	var n := int(dur * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := PackedFloat32Array()
	phase.resize(freqs.size())
	for i in n:
		var t := float(i) / rate
		var env := exp(-decay * t) * minf(1.0, t * 200.0)
		var s := 0.0
		for k in freqs.size():
			var f: float = freqs[k] * (1.0 + sweep * t)
			phase[k] += f / rate
			var ph := fposmod(phase[k], 1.0)
			if wave == "square":
				s += 1.0 if ph < 0.5 else -1.0
			elif wave == "saw":
				s += ph * 2.0 - 1.0
			elif wave == "noise":
				s += randf() * 2.0 - 1.0
			else:
				s += sin(ph * TAU)
		s = s / freqs.size() * vol * env
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	return w


func _howl() -> AudioStreamWAV:
	var rate := 22050
	var n := int(1.7 * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	var ph := 0.0
	for i in n:
		var t := float(i) / rate
		var f := 300.0 + 260.0 * sin(PI * minf(t / 1.1, 1.0)) - 90.0 * maxf(0.0, (t - 1.1) / 0.6) + 9.0 * sin(t * 38.0)
		ph += f / rate
		var env := minf(1.0, t * 6.0) * maxf(0.0, 1.0 - maxf(0.0, t - 1.3) / 0.4)
		var s := (sin(ph * TAU) + 0.35 * sin(ph * TAU * 2.0)) * 0.3 * env
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	return w


## Фоновая музыка: днём бодрая, ночью тревожная; darkness 0..1.
func set_club(on: bool) -> void:
	club_on = on
	if music_players.size() >= 3:
		(music_players[2] as AudioStreamPlayer).volume_db = -9.0 if on else -60.0
		if on:
			(music_players[0] as AudioStreamPlayer).volume_db = -60.0
			(music_players[1] as AudioStreamPlayer).volume_db = -60.0


func set_music(darkness: float) -> void:
	if music_players.size() < 3 or club_on:
		return
	(music_players[0] as AudioStreamPlayer).volume_db = lerpf(-15.0, -60.0, clampf(darkness * 1.6, 0.0, 1.0))
	(music_players[1] as AudioStreamPlayer).volume_db = lerpf(-60.0, -13.0, clampf(darkness * 1.3, 0.0, 1.0))


func _music(notes: Array, step: float, vol: float, decay: float, bright: bool) -> AudioStreamWAV:
	var rate := 22050
	var n := int(notes.size() * step * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	var per := int(step * rate)
	for i in n:
		var idx := i / per
		var f: float = notes[idx]
		var t := float(i % per) / rate
		var s := 0.0
		if f > 0.0:
			var env := exp(-decay * t * (3.0 if bright else 1.2)) * minf(1.0, t * 40.0)
			var ph := t * f
			s = sin(ph * TAU) * env
			if bright:
				s += 0.35 * sin(ph * TAU * 2.0) * env
			else:
				s += 0.5 * sin((ph * 1.007) * TAU) * env + 0.25 * sin(ph * TAU * 0.5) * env
		data.encode_s16(i * 2, int(clampf(s * vol, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	return w


func _disco() -> AudioStreamWAV:
	var rate := 22050
	var step := 0.1875
	var steps := 32
	var bass := [55.0, 55.0, 82.4, 55.0, 65.4, 65.4, 98.0, 65.4]
	var lead := [440.0, 0.0, 523.3, 659.3, 0.0, 523.3, 440.0, 0.0, 587.3, 0.0, 698.5, 880.0, 0.0, 698.5, 587.3, 0.0]
	var n := int(steps * step * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	var per := int(step * rate)
	for i in n:
		var st := i / per
		var t := float(i % per) / rate
		var s := 0.0
		if st % 4 == 0:
			s += sin(TAU * (120.0 * exp(-t * 18.0) + 45.0) * t) * exp(-t * 7.0) * 0.9
		if st % 4 == 2:
			s += (randf() * 2.0 - 1.0) * exp(-t * 28.0) * 0.28
		if st % 2 == 1:
			s += (randf() * 2.0 - 1.0) * exp(-t * 60.0) * 0.1
		var bf: float = bass[(st / 4) % bass.size()]
		s += (fposmod(t * bf, 1.0) * 2.0 - 1.0) * 0.18 * exp(-t * 3.0) * (1.0 if st % 4 != 0 else 0.6)
		var lf: float = lead[st % lead.size()]
		if lf > 0.0:
			s += sin(t * lf * TAU) * 0.13 * exp(-t * 6.0)
		data.encode_s16(i * 2, int(clampf(s * 0.55, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	return w
