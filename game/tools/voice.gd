extends SceneTree
## Graba la voz de Eevee: cada frase de eevee/lineas.json pasa a eevee/voz/<hash>.ogg con Piper (voz neuronal, sin
## internet) y ffmpeg. Solo graba las frases nuevas o cambiadas y borra los audios que ya nadie usa.
##   godot --headless --path game --script res://tools/voice.gd && godot --headless --path game --import
## Con `-- --todo` lo vuelve a grabar todo (tras cambiar MODEL o ROBOT). Necesita `piper` (uv tool install
## piper-tts), ffmpeg y la voz en art/voices/ (ver eevee/GUIA.md); el juego solo usa los .ogg.

const MODEL := "../art/voices/es_MX-claude-high.onnx"  # voz femenina de México (Apache-2.0)
const ROBOT := "asetrate=22050*1.06,aresample=22050,aecho=0.8:0.9:8:0.3,alimiter=limit=0.89:level=0"  # algo más aguda, eco metálico corto, sin saturar


func _initialize() -> void:
	var eevee: GDScript = load("res://eevee/eevee.gd")  # load(): este script se compila antes que los autoloads
	if eevee.data().has("roto"):
		quit(1)
		return
	var model := ProjectSettings.globalize_path("res://").path_join(MODEL).simplify_path()
	var out := ProjectSettings.globalize_path(eevee.VOICE.get_base_dir())
	DirAccess.make_dir_recursive_absolute(out)
	var wav := OS.get_cache_dir().path_join("eevee_voice.wav")
	var keep := {}
	var made := 0
	for text: String in eevee.all_lines():
		var ogg := ProjectSettings.globalize_path(eevee.voice_path(text))
		keep[ogg.get_file()] = true
		if FileAccess.file_exists(ogg) and not "--todo" in OS.get_cmdline_user_args():
			continue
		var output := []
		if OS.execute("piper", ["-m", model, "-f", wav, "--", eevee.spoken(text)], output, true) != 0 \
				or OS.execute("ffmpeg", ["-y", "-loglevel", "error", "-i", wav, "-af", ROBOT, "-ac", "1",
					"-c:a", "libvorbis", "-q:a", "3", ogg], output, true) != 0:
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
