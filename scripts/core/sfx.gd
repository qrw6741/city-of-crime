extends Node
## Procedurally generated audio: UI sounds, engine loops, ambience and original music.

const RATE := 22050
var streams: Dictionary = {}
var engine_loops: Dictionary = {}
var music_streams: Dictionary = {}
var pool: Array[AudioStreamPlayer] = []
var music_player: AudioStreamPlayer
var current_music := ""
var _thread: Thread

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for b in ["Music", "SFX"]:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, b)
			AudioServer.set_bus_send(idx, "Master")
	for i in 12:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		pool.append(p)
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	add_child(music_player)
	_build_sfx()
	for t in ["small", "v6", "v8", "high", "super", "bike", "diesel"]:
		engine_loops[t] = _engine_loop(t)
	streams["ambience"] = _ambience()
	_thread = Thread.new()
	_thread.start(_build_music)

func _exit_tree() -> void:
	if _thread and _thread.is_started():
		_thread.wait_to_finish()

# ------------------------------------------------------------------ playback
func play(sound_name: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if not streams.has(sound_name):
		return
	for p in pool:
		if not p.playing:
			p.stream = streams[sound_name]
			p.pitch_scale = pitch
			p.volume_db = volume_db
			p.play()
			return

func play_music(track: String) -> void:
	if current_music == track and music_player.playing:
		return
	current_music = track
	if music_streams.has(track):
		music_player.stream = music_streams[track]
		music_player.volume_db = -6.0
		music_player.play()

func stop_music() -> void:
	current_music = ""
	music_player.stop()

func _process(_d: float) -> void:
	# Music may finish generating after it was requested.
	if current_music != "" and not music_player.playing and music_streams.has(current_music):
		music_player.stream = music_streams[current_music]
		music_player.play()

# ------------------------------------------------------------------ synthesis helpers
func _to_wav(samples: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clamp(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w

func _tone(freq_from: float, freq_to: float, dur: float, wave: String = "sine", vol: float = 0.5, attack: float = 0.005, noise_amt: float = 0.0) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / n
		var f: float = lerp(freq_from, freq_to, t)
		ph += f / RATE
		var s := 0.0
		match wave:
			"sine": s = sin(ph * TAU)
			"square": s = 1.0 if fmod(ph, 1.0) < 0.5 else -1.0
			"saw": s = fmod(ph, 1.0) * 2.0 - 1.0
			"tri": s = abs(fmod(ph, 1.0) * 4.0 - 2.0) - 1.0
		if noise_amt > 0.0:
			s = lerp(s, randf() * 2.0 - 1.0, noise_amt)
		var env: float = min(1.0, float(i) / max(1.0, attack * RATE)) * pow(1.0 - t, 1.6)
		out[i] = s * env * vol
	return out

func _concat(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var o := a.duplicate()
	o.append_array(b)
	return o

func _mix(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var n: int = max(a.size(), b.size())
	var o := PackedFloat32Array()
	o.resize(n)
	for i in n:
		o[i] = (a[i] if i < a.size() else 0.0) + (b[i] if i < b.size() else 0.0)
	return o

func _build_sfx() -> void:
	streams["click"] = _to_wav(_tone(900, 700, 0.05, "sine", 0.35))
	streams["hover"] = _to_wav(_tone(1400, 1300, 0.025, "sine", 0.15))
	streams["back"] = _to_wav(_tone(600, 380, 0.08, "sine", 0.35))
	streams["cash"] = _to_wav(_concat(_tone(1320, 1320, 0.07, "square", 0.18), _tone(1760, 1760, 0.18, "square", 0.18)))
	streams["buy"] = _to_wav(_concat(_concat(_tone(880, 880, 0.06, "tri", 0.4), _tone(1100, 1100, 0.06, "tri", 0.4)), _tone(1320, 1320, 0.2, "tri", 0.4)))
	streams["error"] = _to_wav(_concat(_tone(220, 200, 0.12, "square", 0.2), _tone(180, 160, 0.18, "square", 0.2)))
	var lv := PackedFloat32Array()
	for f in [523.0, 659.0, 784.0, 1047.0]:
		lv.append_array(_tone(f, f, 0.12, "tri", 0.4))
	lv.append_array(_tone(1047, 1047, 0.5, "tri", 0.4))
	streams["levelup"] = _to_wav(lv)
	streams["checkpoint"] = _to_wav(_concat(_tone(988, 988, 0.08, "sine", 0.45), _tone(1319, 1319, 0.2, "sine", 0.45)))
	streams["horn"] = _to_wav(_mix(_tone(370, 370, 0.5, "square", 0.22, 0.01), _tone(440, 440, 0.5, "square", 0.22, 0.01)))
	streams["crash"] = _to_wav(_tone(140, 40, 0.45, "saw", 0.8, 0.001, 0.75))
	streams["thud"] = _to_wav(_tone(110, 50, 0.18, "sine", 0.7, 0.001, 0.3))
	streams["door"] = _to_wav(_concat(_tone(300, 200, 0.05, "square", 0.25, 0.001, 0.5), _tone(160, 90, 0.12, "sine", 0.6, 0.001, 0.2)))
	streams["step"] = _to_wav(_tone(180, 90, 0.06, "sine", 0.25, 0.001, 0.6))
	streams["jump"] = _to_wav(_tone(200, 120, 0.1, "sine", 0.3, 0.001, 0.4))
	streams["splash"] = _to_wav(_tone(400, 100, 0.8, "saw", 0.6, 0.01, 0.95))
	streams["explosion"] = _to_wav(_tone(90, 25, 1.4, "saw", 1.0, 0.001, 0.85))
	streams["phone"] = _to_wav(_concat(_tone(1200, 1200, 0.04, "sine", 0.3), _tone(1600, 1600, 0.06, "sine", 0.3)))
	streams["fail"] = _to_wav(_concat(_concat(_tone(392, 392, 0.2, "tri", 0.4), _tone(330, 330, 0.2, "tri", 0.4)), _tone(262, 262, 0.5, "tri", 0.4)))
	streams["win"] = _to_wav(_concat(_concat(_tone(523, 523, 0.15, "tri", 0.45), _tone(659, 659, 0.15, "tri", 0.45)), _concat(_tone(784, 784, 0.15, "tri", 0.45), _tone(1047, 1047, 0.6, "tri", 0.45))))
	streams["skid"] = _to_wav(_tone(900, 700, 0.35, "saw", 0.12, 0.02, 0.9), true)
	streams["countdown"] = _to_wav(_tone(660, 660, 0.15, "sine", 0.5))
	streams["go"] = _to_wav(_tone(1320, 1320, 0.4, "sine", 0.5))

func _engine_loop(kind: String) -> AudioStreamWAV:
	# A seamless loop of an idling engine at f0; pitched up with RPM in-game.
	var f0 = {"small": 45.0, "v6": 40.0, "v8": 30.0, "high": 50.0, "super": 55.0, "bike": 60.0, "diesel": 25.0}[kind]
	var harm = {"small": [1.0, 0.5, 0.3, 0.15], "v6": [1.0, 0.6, 0.35, 0.2, 0.1], "v8": [1.0, 0.8, 0.5, 0.3, 0.2], "high": [0.7, 0.8, 0.6, 0.4, 0.3, 0.2], "super": [0.6, 0.7, 0.7, 0.5, 0.4, 0.3], "bike": [0.8, 0.6, 0.5, 0.4, 0.3], "diesel": [1.0, 0.9, 0.6, 0.3]}[kind]
	var lope = {"small": 0.1, "v6": 0.15, "v8": 0.45, "high": 0.1, "super": 0.15, "bike": 0.3, "diesel": 0.35}[kind]
	var cycles := 40
	var period := int(round(RATE / f0))
	var n := period * cycles
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind)
	var grit := PackedFloat32Array()
	grit.resize(period)
	for i in period:
		grit[i] = rng.randf() * 2.0 - 1.0
	for i in n:
		var ph := float(i) / period
		var s := 0.0
		for h in harm.size():
			s += sin(ph * TAU * (h + 1)) * harm[h]
		# saw-like firing pulses
		s += (1.0 - fmod(ph, 1.0)) * 0.6
		# lumpy idle: amplitude modulation every 4 cycles
		s *= 1.0 - lope * (0.5 + 0.5 * sin(ph * TAU / 4.0))
		s += grit[i % period] * 0.12
		out[i] = s * 0.18
	return _to_wav(out, true)

func _ambience() -> AudioStreamWAV:
	var n := RATE * 4
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in n:
		lp = lerp(lp, rng.randf() * 2.0 - 1.0, 0.03)
		var fade: float = min(1.0, min(float(i), float(n - i)) / 2000.0)
		out[i] = lp * 0.5 * fade + lp * 0.5 * (1.0 - fade)
	return _to_wav(out, true)

# ------------------------------------------------------------------ music (original, generated)
func _build_music() -> void:
	var a := _compose(84.0, [[57, 60, 64], [53, 57, 60], [55, 59, 62], [52, 55, 59]], 42, 0)
	call_deferred("_music_ready", "menu", a)
	var b := _compose(96.0, [[50, 53, 57], [46, 50, 53], [48, 52, 55], [45, 49, 52]], 38, 1)
	call_deferred("_music_ready", "radio", b)

func _music_ready(track: String, w: AudioStreamWAV) -> void:
	music_streams[track] = w

func _midi(n: float) -> float:
	return 440.0 * pow(2.0, (n - 69.0) / 12.0)

func _compose(bpm: float, chords: Array, bass_root: int, style: int) -> AudioStreamWAV:
	var rate := 16000
	var beat := 60.0 / bpm
	var bars := chords.size() * 2
	var total := int(bars * 4 * beat * rate)
	var out := PackedFloat32Array()
	out.resize(total)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234 + style
	var spb := int(beat * rate)
	for bar in bars:
		var chord: Array = chords[bar % chords.size()]
		var bar_start := bar * 4 * spb
		# pad chord
		for note in chord:
			var f := _midi(float(note))
			for i in 4 * spb:
				var idx := bar_start + i
				if idx >= total:
					break
				var t := float(i) / rate
				var env: float = min(1.0, t * 3.0) * (1.0 - float(i) / (4 * spb)) * 0.6 + 0.2
				out[idx] += (sin(TAU * f * t) + 0.3 * sin(TAU * f * 2.0 * t + 0.5)) * 0.05 * env
		# bass line (root and fifth)
		var root := _midi(float(chord[0] - 24))
		for b in 8:
			var f2: float = root * (1.5 if b % 4 == 3 else 1.0)
			var s0 := bar_start + b * spb / 2
			for i in spb / 2:
				var idx2 := s0 + i
				if idx2 >= total:
					break
				var t2 := float(i) / rate
				var ph := fmod(f2 * t2, 1.0)
				out[idx2] += (ph * 2.0 - 1.0) * 0.10 * exp(-t2 * 5.0)
		# drums
		for b in 4:
			var kick := bar_start + b * spb
			for i in int(0.15 * rate):
				if kick + i >= total:
					break
				var t3 := float(i) / rate
				out[kick + i] += sin(TAU * (50.0 + 90.0 * exp(-t3 * 30.0)) * t3) * 0.35 * exp(-t3 * 18.0)
			if b % 2 == 1:
				for i in int(0.12 * rate):
					if kick + i >= total:
						break
					out[kick + i] += (rng.randf() * 2.0 - 1.0) * 0.12 * exp(-float(i) / rate * 25.0)
			for h in 2:
				var hat := kick + h * spb / 2
				for i in int(0.04 * rate):
					if hat + i >= total:
						break
					out[hat + i] += (rng.randf() * 2.0 - 1.0) * 0.04 * exp(-float(i) / rate * 80.0)
		# simple arpeggio lead in second half
		if style == 1 or bar >= chords.size():
			for k in 8:
				var note2: int = chord[(k * 2 + bar) % chord.size()] + 12
				var f3 := _midi(float(note2))
				var s1 := bar_start + k * spb / 2
				for i in spb / 2:
					var idx3 := s1 + i
					if idx3 >= total:
						break
					var t4 := float(i) / rate
					var sq := 1.0 if fmod(f3 * t4, 1.0) < 0.5 else -1.0
					out[idx3] += sq * 0.025 * exp(-t4 * 6.0)
	var bytes := PackedByteArray()
	bytes.resize(total * 2)
	for i in total:
		bytes.encode_s16(i * 2, int(clamp(out[i], -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = bytes
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_end = total
	return w
