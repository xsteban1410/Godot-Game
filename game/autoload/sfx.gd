extends Node
## Efectos de sonido sintetizados al arrancar: el juego no necesita archivos de audio.
## Cada efecto es una lista de notas [frecuencia, inicio_s, duración_s, frecuencia_final?].

const RATE := 22050
const VOICES := 8

var _sounds := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_sounds = {
		"click": _synth([[880.0, 0.0, 0.06]], 0.35),
		"hover": _synth([[1320.0, 0.0, 0.035]], 0.15),
		"step": _synth([[700.0, 0.0, 0.07]], 0.5, "noise"),
		"jump": _synth([[300.0, 0.0, 0.16, 620.0]], 0.3),
		"land": _synth([[400.0, 0.0, 0.1]], 0.7, "noise"),
		"success": _synth([[523.0, 0.0, 0.3], [659.0, 0.08, 0.3], [784.0, 0.16, 0.35], [1047.0, 0.24, 0.6]], 0.3),
		"error": _synth([[220.0, 0.0, 0.15], [165.0, 0.13, 0.3]], 0.3, "square"),
		"whoosh": _synth([[500.0, 0.0, 0.45, 180.0]], 0.6, "noise"),
		"pickup": _synth([[988.0, 0.0, 0.12], [1319.0, 0.06, 0.12], [1976.0, 0.12, 0.25]], 0.35),
		"boom": _synth([[220.0, 0.0, 0.7, 60.0]], 1.0, "noise"),
		"splash": _synth([[1800.0, 0.0, 0.5, 600.0]], 0.5, "noise"),
		"hop": _synth([[400.0, 0.0, 0.1, 800.0]], 0.25),
	}
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)


func play(sound: String, pitch_jitter := 0.0) -> void:
	var player := _players[_next]
	_next = (_next + 1) % VOICES
	player.stream = _sounds[sound]
	player.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	player.play()


func _synth(notes: Array, volume: float, wave := "sine") -> AudioStreamWAV:
	var length := 0.0
	for n: Array in notes:
		length = maxf(length, n[1] + n[2])
	var buffer := PackedFloat32Array()
	buffer.resize(int(length * RATE) + 1)
	for n: Array in notes:
		var start := int(n[1] * RATE)
		var count := int(n[2] * RATE)
		var f0: float = n[0]
		var f1: float = n[3] if n.size() > 3 else f0
		var phase := 0.0
		var low := 0.0
		for j in count:
			var k := float(j) / count
			var env := minf(j / (0.004 * RATE), 1.0) * (1.0 - k) * (1.0 - k)
			phase += TAU * lerpf(f0, f1, k) / RATE
			var w: float
			if wave == "square":
				w = signf(sin(phase)) * 0.45
			elif wave == "noise":
				low += (randf_range(-1.0, 1.0) - low) * minf(TAU * f0 / RATE, 1.0)  # ruido filtrado: golpe sordo
				w = low * 2.5
			else:
				w = sin(phase) + 0.25 * sin(2.0 * phase)
			buffer[start + j] += w * env
	var data := PackedByteArray()
	data.resize(buffer.size() * 2)
	for i in buffer.size():
		data.encode_s16(i * 2, int(clampf(buffer[i] * volume, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = data
	return wav
