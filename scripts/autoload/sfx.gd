extends Node
## Ses efektleri. Hiç ses dosyası yok: hepsi açılışta kodla sentezlenir (AudioStreamWAV).
## Kullanım: Sfx.play("kaching")

const RATE := 22050

var _streams: Dictionary = {}
var _pool: Array = []
var _hum: AudioStreamPlayer
var _rain: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 7
	_streams["chime"] = _wav(_chime())
	_streams["kaching"] = _wav(_kaching())
	_streams["bubble"] = _wav(_bubbles())
	_streams["splash"] = _wav(_splash())
	_streams["click"] = _wav(_tone(1200.0, 0.025, 0.4))
	_streams["alarm"] = _wav(_alarm())
	_streams["shutter"] = _wav(_shutter())
	_streams["bad"] = _wav(_buzz())
	_streams["good"] = _wav(_arpeggio())
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_hum = AudioStreamPlayer.new()
	_hum.stream = _wav(_hum_loop(), true)
	_hum.volume_db = -60.0
	add_child(_hum)
	_hum.play()
	_rain = AudioStreamPlayer.new()
	_rain.stream = _wav(_rain_loop(), true)
	_rain.volume_db = -14.0
	add_child(_rain)


func play(name: String, volume_db: float = -6.0) -> void:
	if not _streams.has(name):
		return
	for p in _pool:
		if not p.playing:
			p.stream = _streams[name]
			p.volume_db = volume_db
			p.pitch_scale = _rng.randf_range(0.96, 1.04)
			p.play()
			return


## Filtre/hava motoru uğultusu, tank sayısına göre
func set_hum(tanks: int, power_on: bool) -> void:
	_hum.volume_db = -60.0 if (tanks == 0 or not power_on) else clamp(-30.0 + tanks * 1.5, -30.0, -18.0)


func set_rain(on: bool) -> void:
	if on and not _rain.playing:
		_rain.play()
	elif not on and _rain.playing:
		_rain.stop()


# ------------------------------------------------------------------ Sentez

func _wav(data: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(data.size() * 2)
	for i in data.size():
		bytes.encode_s16(i * 2, int(clamp(data[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = data.size()
	return w


func _tone(freq: float, dur: float, vol: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		out[i] = sin(TAU * freq * t) * vol * (1.0 - float(i) / n)
	return out


func _bell(out: PackedFloat32Array, start: float, freq: float, dur: float, vol: float) -> void:
	var s0 := int(start * RATE)
	for i in int(dur * RATE):
		var idx := s0 + i
		if idx >= out.size():
			break
		var t := float(i) / RATE
		var env := exp(-t * 4.0)
		out[idx] += (sin(TAU * freq * t) + 0.4 * sin(TAU * freq * 2.76 * t) * exp(-t * 8.0)) * vol * env


func _buffer(dur: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(dur * RATE))
	return out


func _chime() -> PackedFloat32Array:
	var out := _buffer(1.4)
	_bell(out, 0.0, 1318.5, 1.0, 0.35)
	_bell(out, 0.32, 1046.5, 1.1, 0.35)
	return out


func _kaching() -> PackedFloat32Array:
	var out := _buffer(0.9)
	for i in int(0.06 * RATE):
		out[i] += _rng.randf_range(-1, 1) * 0.5 * (1.0 - float(i) / (0.06 * RATE))
	_bell(out, 0.05, 2093.0, 0.8, 0.3)
	_bell(out, 0.05, 2637.0, 0.8, 0.25)
	_bell(out, 0.05, 3136.0, 0.8, 0.2)
	return out


func _bubbles() -> PackedFloat32Array:
	var out := _buffer(0.6)
	for b in 6:
		var start := int(_rng.randf_range(0.0, 0.45) * RATE)
		var f0 := _rng.randf_range(350.0, 700.0)
		var n := int(0.06 * RATE)
		var ph := 0.0
		for i in n:
			var k := float(i) / n
			ph += TAU * (f0 + k * f0 * 1.8) / RATE
			if start + i < out.size():
				out[start + i] += sin(ph) * 0.35 * sin(PI * k)
	return out


func _splash() -> PackedFloat32Array:
	var out := _buffer(0.6)
	var lp := 0.0
	for i in out.size():
		var t := float(i) / RATE
		lp = lerp(lp, _rng.randf_range(-1, 1), 0.35)
		out[i] = lp * exp(-t * 7.0) * 0.8
	return out


func _alarm() -> PackedFloat32Array:
	var out := _buffer(1.2)
	for i in out.size():
		var t := float(i) / RATE
		var f := 950.0 if int(t * 6.0) % 2 == 0 else 700.0
		out[i] = (1.0 if sin(TAU * f * t) > 0.0 else -1.0) * 0.18
	return out


func _shutter() -> PackedFloat32Array:
	var out := _buffer(0.25)
	for burst in [0.0, 0.09]:
		var s0 := int(burst * RATE)
		for i in int(0.03 * RATE):
			out[s0 + i] += _rng.randf_range(-1, 1) * 0.6 * (1.0 - float(i) / (0.03 * RATE))
	return out


func _buzz() -> PackedFloat32Array:
	var out := _buffer(0.35)
	for i in out.size():
		var t := float(i) / RATE
		out[i] = (fmod(t * 140.0, 1.0) * 2.0 - 1.0) * 0.18 * (1.0 - t / 0.35)
	return out


func _arpeggio() -> PackedFloat32Array:
	var out := _buffer(0.7)
	_bell(out, 0.0, 1046.5, 0.5, 0.25)
	_bell(out, 0.1, 1318.5, 0.5, 0.25)
	_bell(out, 0.2, 1568.0, 0.5, 0.25)
	return out


func _hum_loop() -> PackedFloat32Array:
	var out := _buffer(1.0)
	var lp := 0.0
	for i in out.size():
		var t := float(i) / RATE
		lp = lerp(lp, _rng.randf_range(-1, 1), 0.05)
		out[i] = sin(TAU * 60.0 * t) * 0.25 + sin(TAU * 120.0 * t) * 0.12 + lp * 0.3
	return out


func _rain_loop() -> PackedFloat32Array:
	var out := _buffer(2.0)
	var lp := 0.0
	for i in out.size():
		lp = lerp(lp, _rng.randf_range(-1, 1), 0.25)
		out[i] = lp * 0.45 + (_rng.randf_range(-1, 1) * 0.6 if _rng.randf() < 0.002 else 0.0)
	return out
