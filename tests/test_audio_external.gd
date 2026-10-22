# Audio externo del AudioManager (2026-10-21; docs/lista-sonidos.md,
# «Probar sonidos sin reexportar»): un <ID>.ogg / .wav / .mp3 en la carpeta de
# audio externo gana al empaquetado (prioridad ogg > wav > mp3; variantes por
# nombre de files o el ID para todas), el bucle y el bus siguen siendo los del
# catalogo, un archivo invalido avisa y suena el empaquetado sin fallar, y sin
# carpeta nada cambia. Los WAV y MP3 de prueba se generan aqui; el OGG real se
# toma de ISAK_TEST_OGG o del SDK de Android si esta instalado (si no, esa
# prueba queda pendiente: no hay codificador Vorbis en el repo).
extends GutTest

const DIR: String = "user://test_audio_external"
const ANDROID_OGG: String = "~/Library/Android/sdk/platforms/android-34/data/res/raw/fallbackring.ogg"
const PACKED_JUMP: String = "res://assets/audio/sfx_isak_jump.wav"


func before_each() -> void:
	_clear_dir()
	DirAccess.make_dir_recursive_absolute(DIR)
	AudioManager.load_catalog(AudioManager.DATA_PATH)
	AudioManager.set_external_dir(DIR)


func after_each() -> void:
	AudioManager.stop_all()
	_clear_dir()
	AudioManager.set_external_dir(null)
	AudioManager.load_catalog(AudioManager.DATA_PATH)


func _clear_dir() -> void:
	if not DirAccess.dir_exists_absolute(DIR):
		return
	for file: String in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(file))
	DirAccess.remove_absolute(DIR)


## WAV PCM (format 1) o coma flotante (3) de `frames` cuadros a `rate` Hz.
static func wav_bytes(rate: int = 11025, bits: int = 16, channels: int = 1, fmt: int = 1, frames: int = 1100) -> PackedByteArray:
	var bps: int = bits / 8
	var data := PackedByteArray()
	data.resize(frames * channels * bps)
	var out := PackedByteArray()
	out.append_array("RIFF".to_ascii_buffer())
	var head := PackedByteArray()
	head.resize(4)
	head.encode_u32(0, 36 + data.size())
	out.append_array(head)
	out.append_array("WAVEfmt ".to_ascii_buffer())
	var fmt_chunk := PackedByteArray()
	fmt_chunk.resize(20)
	fmt_chunk.encode_u32(0, 16)
	fmt_chunk.encode_u16(4, fmt)
	fmt_chunk.encode_u16(6, channels)
	fmt_chunk.encode_u32(8, rate)
	fmt_chunk.encode_u32(12, rate * channels * bps)
	fmt_chunk.encode_u16(16, channels * bps)
	fmt_chunk.encode_u16(18, bits)
	out.append_array(fmt_chunk)
	out.append_array("data".to_ascii_buffer())
	var size := PackedByteArray()
	size.resize(4)
	size.encode_u32(0, data.size())
	out.append_array(size)
	out.append_array(data)
	return out


## MP3 minimo: `count` cuadros MPEG-1 capa III de 128 kbps a 44,1 kHz en silencio.
static func mp3_bytes(count: int = 20) -> PackedByteArray:
	var out := PackedByteArray()
	for i: int in count:
		var frame := PackedByteArray()
		frame.resize(417)
		frame[0] = 0xFF
		frame[1] = 0xFB
		frame[2] = 0x90
		frame[3] = 0x64
		out.append_array(frame)
	return out


func _write(name: String, bytes: PackedByteArray) -> String:
	var path: String = DIR.path_join(name)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	return path


func _real_ogg() -> PackedByteArray:
	var path: String = OS.get_environment("ISAK_TEST_OGG")
	if path.is_empty():
		path = ANDROID_OGG.replace("~", OS.get_environment("HOME"))
	return FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()


func _rescan() -> void:
	AudioManager.reload_external_audio()


# --- Sin carpeta ---

func test_without_folder_nothing_changes() -> void:
	AudioManager.set_external_dir("user://test_audio_external_no_existe")
	assert_eq(AudioManager.external_files().size(), 0)
	assert_eq(AudioManager.stream_sources(&"sfx_isak_jump"), PackedStringArray([PACKED_JUMP]))
	AudioManager.set_external_dir("")
	assert_eq(AudioManager.stream_sources(&"sfx_isak_jump"), PackedStringArray([PACKED_JUMP]))
	assert_false(AudioManager.has_stream(&"sfx_eco_line"), "sin archivo sigue en silencio")


func test_empty_folder_nothing_changes() -> void:
	assert_eq(AudioManager.stream_sources(&"sfx_isak_jump"), PackedStringArray([PACKED_JUMP]))


# --- El externo gana ---

func test_external_wav_wins_over_packed() -> void:
	var path: String = _write("sfx_isak_jump.wav", wav_bytes(11025))
	_rescan()
	assert_eq(AudioManager.stream_sources(&"sfx_isak_jump"), PackedStringArray([path]))
	assert_true(AudioManager.play(&"sfx_isak_jump"))
	var found: AudioStreamPlayer = null
	for child: Node in AudioManager.get_children():
		if child is AudioStreamPlayer and (child as AudioStreamPlayer).playing \
				and child.get_meta(&"sound_id", &"") == &"sfx_isak_jump":
			found = child
	assert_not_null(found, "suena con un reproductor")
	if found != null:
		assert_true(found.stream is AudioStreamWAV)
		assert_eq((found.stream as AudioStreamWAV).mix_rate, 11025, "es el externo, no el empaquetado (44100)")
		assert_eq(found.bus, AudioManager.bus_for(&"sfx_isak_jump"))


func test_external_fills_an_id_without_packed_file() -> void:
	assert_false(AudioManager.has_stream(&"sfx_eco_line"))
	_write("sfx_eco_line.mp3", mp3_bytes())
	_rescan()
	assert_true(AudioManager.has_stream(&"sfx_eco_line"))
	assert_true(AudioManager.play(&"sfx_eco_line"))


func test_file_names_ignore_case() -> void:
	var path: String = _write("SFX_Isak_Jump.WAV", wav_bytes())
	_rescan()
	assert_eq(AudioManager.stream_sources(&"sfx_isak_jump"), PackedStringArray([path]))


func test_wav_formats_decode() -> void:
	for spec: Array in [[8, 1, 1], [16, 2, 1], [24, 1, 1], [32, 2, 3], [64, 1, 3]]:
		var stream: AudioStream = AudioManager._decode_audio(wav_bytes(22050, spec[0], spec[1], spec[2]), "wav")
		assert_true(stream is AudioStreamWAV, "WAV %s" % [spec])
		if stream is AudioStreamWAV:
			assert_eq((stream as AudioStreamWAV).stereo, spec[1] == 2)
			assert_eq((stream as AudioStreamWAV).mix_rate, 22050)
			assert_eq((stream as AudioStreamWAV).loop_mode, AudioStreamWAV.LOOP_DISABLED)


# --- Prioridad ogg > wav > mp3 ---

func test_priority_wav_over_mp3() -> void:
	_write("sfx_isak_jump.mp3", mp3_bytes())
	var wav: String = _write("sfx_isak_jump.wav", wav_bytes())
	_rescan()
	assert_eq(AudioManager.stream_sources(&"sfx_isak_jump"), PackedStringArray([wav]))


func test_priority_order_of_candidates() -> void:
	var mp3: String = _write("sfx_isak_jump.mp3", mp3_bytes())
	var wav: String = _write("sfx_isak_jump.wav", wav_bytes())
	var ogg: String = _write("sfx_isak_jump.ogg", PackedByteArray([1, 2, 3]))
	_rescan()
	assert_eq(AudioManager._external_candidates("sfx_isak_jump"), PackedStringArray([ogg, wav, mp3]))


func test_real_ogg_wins_over_wav_and_mp3() -> void:
	var bytes: PackedByteArray = _real_ogg()
	if bytes.is_empty():
		pending("sin OGG real (define ISAK_TEST_OGG)")
		return
	_write("sfx_isak_jump.mp3", mp3_bytes())
	_write("sfx_isak_jump.wav", wav_bytes())
	var ogg: String = _write("sfx_isak_jump.ogg", bytes)
	_rescan()
	assert_eq(AudioManager.stream_sources(&"sfx_isak_jump"), PackedStringArray([ogg]))
	var stream: AudioStream = AudioManager._resolve(&"sfx_isak_jump")[0]
	assert_true(stream is AudioStreamOggVorbis)
	assert_false((stream as AudioStreamOggVorbis).loop, "sin bucle propio")
	assert_gt(stream.get_length(), 0.1)
	assert_true(AudioManager.play(&"sfx_isak_jump"))


# --- Invalidos ---

func test_invalid_file_falls_back_to_packed_without_failing() -> void:
	_write("sfx_isak_jump.ogg", "esto no es audio".to_utf8_buffer())
	_rescan()
	assert_eq(AudioManager.stream_sources(&"sfx_isak_jump"), PackedStringArray([PACKED_JUMP]))
	assert_true(AudioManager.play(&"sfx_isak_jump"), "suena el empaquetado")
	assert_push_warning("sfx_isak_jump")


func test_invalid_without_packed_is_silence() -> void:
	_write("sfx_eco_line.wav", "RIFF0000WAVEnada".to_utf8_buffer())
	_write("sfx_eco_line.mp3", PackedByteArray([0, 1, 2, 3, 4, 5]))
	_rescan()
	assert_false(AudioManager.has_stream(&"sfx_eco_line"))
	assert_false(AudioManager.play(&"sfx_eco_line"))
	assert_push_warning_count(1, "un solo aviso por ID")


func test_invalid_ogg_falls_to_next_valid_format() -> void:
	_write("sfx_isak_jump.ogg", "OggS roto".to_utf8_buffer())
	var wav: String = _write("sfx_isak_jump.wav", wav_bytes())
	_rescan()
	assert_eq(AudioManager.stream_sources(&"sfx_isak_jump"), PackedStringArray([wav]))


func test_unsupported_wav_codec_is_rejected() -> void:
	var adpcm: PackedByteArray = wav_bytes(22050, 4, 1, 2)
	assert_string_contains(AudioManager._check_audio_bytes(adpcm, "wav"), "no admitido")
	assert_eq(AudioManager._check_audio_bytes(wav_bytes(), "wav"), "")
	assert_eq(AudioManager._check_audio_bytes(mp3_bytes(), "mp3"), "")
	assert_ne(AudioManager._check_audio_bytes("OggS".to_ascii_buffer(), "ogg"), "")


func test_unknown_file_name_is_reported() -> void:
	_write("sonido_que_no_existe.wav", wav_bytes())
	_rescan()
	assert_push_warning("sonido_que_no_existe.wav")


# --- Bucle, bus y variantes ---

func test_loop_and_bus_come_from_catalog() -> void:
	_write("amb_hub.wav", wav_bytes(11025))
	_rescan()
	assert_true(bool(AudioManager.get_entry(&"amb_hub").get("loop", false)))
	assert_true(AudioManager.play(&"amb_hub"))
	assert_true(AudioManager.is_loop_playing("amb_hub"))
	var player: AudioStreamPlayer = AudioManager.get_node_or_null("Loop_amb_hub") as AudioStreamPlayer
	assert_not_null(player)
	if player != null:
		assert_eq((player.stream as AudioStreamWAV).mix_rate, 11025)
		assert_eq(player.bus, AudioManager.bus_for(&"amb_hub"))
		assert_eq(player.bus, &"Ambience")
		assert_true(player.finished.is_connected(player.play), "bucle manual del catalogo")
	AudioManager.stop_loop("amb_hub")


func test_variant_file_replaces_only_that_variant() -> void:
	var path: String = _write("sfx_isak_step_2.wav", wav_bytes())
	_rescan()
	var sources: PackedStringArray = AudioManager.stream_sources(&"sfx_isak_step")
	assert_eq(sources.size(), 4)
	assert_eq(sources[1], path)
	assert_eq(sources[0], "res://assets/audio/sfx_isak_step_1.wav")


func test_id_file_replaces_all_variants() -> void:
	var path: String = _write("sfx_isak_step.wav", wav_bytes())
	_rescan()
	assert_eq(AudioManager.stream_sources(&"sfx_isak_step"), PackedStringArray([path]))


func test_reload_picks_up_new_files() -> void:
	assert_eq(AudioManager.stream_sources(&"sfx_isak_jump"), PackedStringArray([PACKED_JUMP]))
	var path: String = _write("sfx_isak_jump.wav", wav_bytes())
	assert_eq(AudioManager.stream_sources(&"sfx_isak_jump"), PackedStringArray([PACKED_JUMP]), "cacheado hasta recargar")
	AudioManager.reload_external_audio()
	assert_eq(AudioManager.stream_sources(&"sfx_isak_jump"), PackedStringArray([path]))
	DirAccess.remove_absolute(path)
	AudioManager.reload_external_audio()
	assert_eq(AudioManager.stream_sources(&"sfx_isak_jump"), PackedStringArray([PACKED_JUMP]))


func test_focus_in_reloads_only_if_folder_changed() -> void:
	assert_eq(AudioManager.stream_sources(&"sfx_isak_jump"), PackedStringArray([PACKED_JUMP]))
	var path: String = _write("sfx_isak_jump.wav", wav_bytes())
	AudioManager.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	assert_eq(AudioManager.stream_sources(&"sfx_isak_jump"), PackedStringArray([path]))


func test_default_dir_in_editor_is_user_override() -> void:
	AudioManager.set_external_dir(null)
	if not OS.get_environment(AudioManager.EXTERNAL_DIR_ENV).is_empty():
		pending("ISAK_AUDIO_DIR definido")
		return
	assert_false(OS.has_feature("template"))
	assert_eq(AudioManager.external_dir(), AudioManager.EXTERNAL_DEV_DIR)
