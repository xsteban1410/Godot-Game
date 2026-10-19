extends SceneTree
## Graba la voz de Ivy: cada frase de ivy/lineas.json pasa a ivy/voz/<hash>.ogg con Piper (voz neuronal, sin
## internet) y ffmpeg. Solo graba las frases nuevas o cambiadas y borra los audios que ya nadie usa.
##   godot --headless --path game --script res://tools/voice.gd && godot --headless --path game --import
## Con `-- --todo` lo vuelve a grabar todo (tras cambiar MODEL, PIPER o EFFECT). Necesita `piper` (uv tool install
## piper-tts), ffmpeg y la voz en art/voices/ (ver ivy/GUIA.md); el juego solo usa los .ogg.

const MODEL := "../art/voices/es_AR-daniela-high.onnx"  # voz femenina argentina (CC BY-SA 4.0), elegida por el usuario
const PIPER := ["--noise-w-scale", "1.0", "--length-scale", "1.1", "--sentence-silence", "0.2"]  # ritmo más natural y algo más pausado
# Más dulce: 2 semitonos más aguda sin efecto ardilla (formantes intactos); más cálida: sin rumor grave, algo más de
# cuerpo y menos agudos ásperos; un poco de ambiente para que no suene seca; compresión suave y sin saturar.
const EFFECT := "rubberband=pitch=1.122:formant=preserved,highpass=f=90,lowshelf=g=2:f=250,highshelf=g=-3:f=6000," \
	+ "aecho=0.85:0.8:45|75:0.16|0.1,acompressor=threshold=0.25:ratio=2:attack=10:release=150,alimiter=limit=0.89:level=0"


func _initialize() -> void:
	var ivy: GDScript = load("res://ivy/ivy.gd")  # load(): este script se compila antes que los autoloads
	if ivy.data().has("roto"):
		quit(1)
		return
	var model := ProjectSettings.globalize_path("res://").path_join(MODEL).simplify_path()
	var out := ProjectSettings.globalize_path(ivy.VOICE.get_base_dir())
	DirAccess.make_dir_recursive_absolute(out)
	var wav := OS.get_cache_dir().path_join("ivy_voice.wav")
	var keep := {}
	var made := 0
	for text: String in ivy.all_lines():
		var ogg := ProjectSettings.globalize_path(ivy.voice_path(text))
		keep[ogg.get_file()] = true
		if FileAccess.file_exists(ogg) and not "--todo" in OS.get_cmdline_user_args():
			continue
		var output := []
		if OS.execute("piper", ["-m", model, "-f", wav] + PIPER + ["--", ivy.spoken(text)], output, true) != 0 \
				or OS.execute("ffmpeg", ["-y", "-loglevel", "error", "-i", wav, "-af", EFFECT, "-ac", "1",
					"-c:a", "libvorbis", "-q:a", "4", ogg], output, true) != 0:
			push_error("No se pudo grabar «%s»: %s" % [text, output])
			quit(1)
			return
		made += 1
	var removed := 0
	for file in DirAccess.get_files_at(out):
		if not keep.has(file.trim_suffix(".import")):
			DirAccess.remove_absolute(out.path_join(file))
			removed += int(file.ends_with(".ogg"))
	DirAccess.remove_absolute(wav)
	print("VOZ: %d frases grabadas, %d borradas, %d en total" % [made, removed, keep.size()])
	quit()
