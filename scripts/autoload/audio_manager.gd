## AudioManager (autoload; 2026-10-20, docs/lista-sonidos.md «Integracion del
## sistema de audio»). Reproduce sonidos por ID desde el catalogo
## data/audio.json (archivos, bus, volumen, variantes, bucle, tiempo del mundo,
## senales de accesibilidad) y los conecta a las senales que ya existen, SIN
## tocar la logica del juego:
## - event_bus: senales de EventBus.
## - nodes: senales de los nodos de una clase al entrar en el arbol
##   (SceneTree.node_added), con filtro por argumentos y sonido posicional.
## - ambience: bucle mientras un nodo de esa clase esta en el arbol (hub).
## - steps: pasos de Isak en los cuadros de contacto de walk/run.
## - text_blips: blips de la maquina de escribir de los EcoTextBox por
##   interlocutor; el de Eco cambia con el acceso (GameState.lap).
## Archivo ausente: la entrada se ignora en silencio (ResourceLoader.exists
## antes de cargar; nunca un error), para que los sonidos definitivos se
## anadan poco a poco con el mismo nombre. Bus inexistente: suena por Master.
## Volumenes por bus y «Senales sonoras de ritmo»: GameSettings (settings.cfg),
## que aplica los volumenes al AudioServer; aqui solo se consulta cue_enabled.
## Procesa siempre (la UI suena con el arbol en pausa).
## AUDIO EXTERNO (2026-10-21, para probar sonidos sin reexportar): un archivo
## <nombre>.ogg / .wav / .mp3 (en ese orden; mayusculas indiferentes) en la
## carpeta de override_dir() gana al empaquetado. <nombre> es cada nombre de
## files (una variante) o el propio ID (sustituye a todas sus variantes). Se
## carga en tiempo de ejecucion (load_from_buffer) sin bucle propio: el bucle y
## el bus siguen siendo los del catalogo. Archivo invalido: aviso una vez por ID
## en el log y suena el empaquetado (o nada). La carpeta se vuelve a leer al
## volver a la ventana del juego si cambio (o con reload_external_audio()).
extends Node

const DATA_PATH: String = "res://data/audio.json"
const FALLBACK_BUS: StringName = &"Master"
const TIME_WORLD: String = "world"
## Marca de los nodos ya conectados (no se conectan dos veces).
const BOUND_META: StringName = &"_audio_manager_bound"

## Entradas del catalogo (id -> Dictionary) y datos completos.
var _data: Dictionary = {}
var _sounds: Dictionary = {}
## id -> Array[AudioStream] ya resueltas (vacio = sin archivos).
var _streams: Dictionary = {}
## id -> indice de la ultima variante (para no repetirla).
var _last_variant: Dictionary = {}
## id -> ms del ultimo play (cooldown_s).
var _last_play_ms: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _players_2d: Array[AudioStreamPlayer2D] = []
var _next_player: int = 0
var _next_player_2d: int = 0
## Bucles en curso: clave (id o id + nodo) -> reproductor dedicado.
var _loops: Dictionary = {}
## Script -> Array de enlaces (bindings) de nodes / ambience / steps, en cache.
var _script_bindings: Dictionary = {}
## Cuadros de texto vigilados: instance_id -> [EcoTextBox, escritos, sin blip].
var _text_boxes: Dictionary = {}
var _rng := RandomNumberGenerator.new()
## Ultimos sonidos que sonaron (pruebas): ids, el mas reciente al final.
var history: Array[StringName] = []
const HISTORY_MAX: int = 32
## Espera al cerrar el juego con algo sonando (ms reales).
const EXIT_FLUSH_MS: int = 60
var _last_stop_ms: int = -100000

## Audio externo: carpeta del juego exportado (junto al ejecutable), la de
## desarrollo (editor) y la variable de entorno que las sustituye.
const EXTERNAL_DIR_NAME: String = "audio"
const EXTERNAL_DEV_DIR: String = "user://audio_override"
const EXTERNAL_DIR_ENV: String = "ISAK_AUDIO_DIR"
const EXTERNAL_EXTENSIONS: PackedStringArray = ["ogg", "wav", "mp3"]
## Carpeta fijada a mano (pruebas); null = la de por defecto, "" = desactivado.
var _external_dir_override: Variant = null
## Archivos de la carpeta: nombre en minusculas -> ruta completa.
var _external_files: Dictionary = {}
var _external_signature: String = ""
## id -> rutas de las que salen sus streams (externas o empaquetadas).
var _sources: Dictionary = {}
## ids ya avisados (un aviso por ID).
var _external_warned: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_scan_external()
	load_catalog(DATA_PATH)
	_report_external()
	GameSettings.apply_audio()
	get_tree().node_added.connect(_on_node_added)
	_scan(get_tree().root)


## Al cerrar el juego (el autoload sale del arbol solo entonces): todo parado y
## una espera minima para que el hilo de mezcla suelte las reproducciones; si
## no, Godot 4.7 avisa de fugas de AudioStreamPlayback al salir.
func _exit_tree() -> void:
	var was_playing: bool = not _loops.is_empty()
	for player: AudioStreamPlayer in _players:
		was_playing = was_playing or player.playing
	for player: AudioStreamPlayer2D in _players_2d:
		was_playing = was_playing or player.playing
	stop_all()
	if was_playing or _stopped_recently():
		OS.delay_msec(EXIT_FLUSH_MS)


## Al volver a la ventana del juego, si la carpeta de audio externo cambio, se
## vuelve a leer (sin reiniciar: basta soltar el archivo y volver al juego).
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and is_node_ready():
		if _external_signature_now() != _external_signature:
			reload_external_audio()


func _process(_delta: float) -> void:
	if not _text_boxes.is_empty():
		poll_text_blips()


# --- Catalogo ---

## Carga un catalogo (pruebas: otro JSON). Rehace los reproductores y vuelve a
## conectar las senales de EventBus. Falso si no se pudo leer.
func load_catalog(path: String) -> bool:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	if not parsed is Dictionary:
		return false
	set_catalog(parsed as Dictionary)
	return true


## Usa `data` como catalogo (pruebas).
func set_catalog(data: Dictionary) -> void:
	_disconnect_event_bus()
	stop_all()
	_data = data
	var sounds: Variant = data.get("sounds", {})
	_sounds = sounds if sounds is Dictionary else {}
	_streams.clear()
	_sources.clear()
	_last_variant.clear()
	_last_play_ms.clear()
	_script_bindings.clear()
	_build_players()
	_connect_event_bus()


func get_catalog() -> Dictionary:
	return _data


func has_entry(id: StringName) -> bool:
	return _sounds.has(String(id))


func get_entry(id: StringName) -> Dictionary:
	var entry: Variant = _sounds.get(String(id), {})
	return entry if entry is Dictionary else {}


## Hay al menos un archivo para `id`.
func has_stream(id: StringName) -> bool:
	return not _resolve(id).is_empty()


## Bus por el que suena `id`: el de su entrada si existe en el AudioServer; si
## no, Master.
func bus_for(id: StringName) -> StringName:
	var bus := StringName(String(get_entry(id).get("bus", FALLBACK_BUS)))
	return bus if AudioServer.get_bus_index(bus) >= 0 else FALLBACK_BUS


## Rutas de los archivos que existen para `id` (en el orden de files).
func resolve_paths(id: StringName) -> PackedStringArray:
	var out: PackedStringArray = []
	var dir: String = String(_data.get("audio_dir", "res://assets/audio"))
	for file: String in _file_names(id):
		var path: String = _find_file(dir, file)
		if not path.is_empty():
			out.append(path)
	return out


## Nombres de archivo (sin carpeta) de `id`: su files o, sin files, el ID.
func _file_names(id: StringName) -> PackedStringArray:
	var files: Variant = get_entry(id).get("files", [String(id)])
	if not files is Array or (files as Array).is_empty():
		files = [String(id)]
	var out: PackedStringArray = []
	for file: Variant in files:
		out.append(String(file))
	return out


# --- Audio externo ---

## Carpeta de audio externo: la variable de entorno ISAK_AUDIO_DIR si existe; en
## el juego exportado, `audio` junto al ejecutable; en el editor,
## user://audio_override. "" = desactivado.
func external_dir() -> String:
	if _external_dir_override != null:
		return String(_external_dir_override)
	var env: String = OS.get_environment(EXTERNAL_DIR_ENV)
	if not env.is_empty():
		return env
	if OS.has_feature("template"):
		return OS.get_executable_path().get_base_dir().path_join(EXTERNAL_DIR_NAME)
	return EXTERNAL_DEV_DIR


## Fija la carpeta de audio externo (pruebas; null = la de por defecto, "" =
## sin audio externo) y la vuelve a leer.
func set_external_dir(dir: Variant) -> void:
	_external_dir_override = dir
	reload_external_audio()


## Vuelve a leer la carpeta de audio externo y olvida los streams ya cargados
## (los bucles en curso siguen con el suyo hasta que vuelvan a empezar).
func reload_external_audio() -> void:
	_external_warned.clear()
	_streams.clear()
	_sources.clear()
	_last_variant.clear()
	_scan_external()
	_report_external()


## Rutas de las que sale el sonido `id` (externas o empaquetadas; pruebas y log).
func stream_sources(id: StringName) -> PackedStringArray:
	_resolve(id)
	return _sources.get(id, PackedStringArray())


## Archivos de audio de la carpeta externa (nombre en minusculas -> ruta).
func external_files() -> Dictionary:
	return _external_files


func _scan_external() -> void:
	_external_files.clear()
	_external_signature = _external_signature_now()
	var dir: String = external_dir()
	if dir.is_empty() or not DirAccess.dir_exists_absolute(dir):
		return
	for file: String in DirAccess.get_files_at(dir):
		if EXTERNAL_EXTENSIONS.has(file.get_extension().to_lower()):
			_external_files[file.to_lower()] = dir.path_join(file)


## Huella de la carpeta (nombres, tamanos y fechas) para saber si cambio.
func _external_signature_now() -> String:
	var dir: String = external_dir()
	if dir.is_empty() or not DirAccess.dir_exists_absolute(dir):
		return dir + "|-"
	var parts: PackedStringArray = [dir]
	for file: String in DirAccess.get_files_at(dir):
		var path: String = dir.path_join(file)
		parts.append("%s:%d:%d" % [file, FileAccess.get_size(path), FileAccess.get_modified_time(path)])
	return "|".join(parts)


## Linea en el log: donde se busca el audio externo y que se encontro (y los
## archivos que no corresponden a ningun sonido del catalogo).
func _report_external() -> void:
	var dir: String = external_dir()
	if dir.is_empty():
		return
	var shown: String = ProjectSettings.globalize_path(dir) if dir.contains("://") else dir
	if not DirAccess.dir_exists_absolute(dir):
		print("AudioManager: audio externo: la carpeta %s no existe (se usan los sonidos del juego)." % shown)
		return
	print("AudioManager: audio externo: %d archivo(s) en %s" % [_external_files.size(), shown])
	var known: Dictionary = {}
	for id: Variant in _sounds:
		known[String(id).to_lower()] = true
		for file: String in _file_names(StringName(String(id))):
			known[file.get_basename().to_lower() if not file.get_extension().is_empty() else file.to_lower()] = true
	for key: Variant in _external_files:
		if not known.has(String(key).get_basename()):
			push_warning("AudioManager: audio externo: '%s' no corresponde a ningun ID de data/audio.json (se ignora)." % String(_external_files[key]).get_file())


## Rutas externas de `name` (sin extension) en orden de prioridad: ogg, wav, mp3.
func _external_candidates(name: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var base: String = name.get_basename() if not name.get_extension().is_empty() else name
	for ext: String in EXTERNAL_EXTENSIONS:
		var key: String = ("%s.%s" % [base, ext]).to_lower()
		if _external_files.has(key):
			out.append(String(_external_files[key]))
	return out


## [stream, ruta] externos de `name` para `id`: el primer candidato que se
## carga; [] si no hay o ninguno vale (avisa una vez por ID).
func _load_external(id: StringName, name: String) -> Array:
	for path: String in _external_candidates(name):
		var problem: String = ""
		var stream: AudioStream = null
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
		if bytes.is_empty():
			problem = "no se pudo leer o esta vacio"
		else:
			problem = _check_audio_bytes(bytes, path.get_extension().to_lower())
		if problem.is_empty():
			stream = _decode_audio(bytes, path.get_extension().to_lower())
			if stream == null:
				problem = "no se pudo decodificar"
		if stream != null:
			return [stream, path]
		if not _external_warned.has(id):
			_external_warned[id] = true
			push_warning("AudioManager: audio externo '%s' para %s no vale (%s); suena el del juego." % [path, id, problem])
	return []


## Comprueba la cabecera antes de decodificar (asi un archivo que no es audio
## no llega al decodificador de Godot, que lo daria como error). "" = valido.
static func _check_audio_bytes(bytes: PackedByteArray, ext: String) -> String:
	match ext:
		"ogg":
			if bytes.size() < 36 or bytes.slice(0, 4).get_string_from_ascii() != "OggS":
				return "no es un archivo Ogg"
			if bytes[28] != 1 or bytes.slice(29, 35).get_string_from_ascii() != "vorbis":
				return "no es Ogg Vorbis (Opus u otro codec no se admiten)"
		"wav":
			if bytes.size() < 12 or bytes.slice(0, 4).get_string_from_ascii() != "RIFF" \
					or bytes.slice(8, 12).get_string_from_ascii() != "WAVE":
				return "no es un archivo WAV (RIFF/WAVE)"
			return _check_wav_format(bytes)
		"mp3":
			if bytes.size() < 4:
				return "demasiado corto"
			var id3: bool = bytes.slice(0, 3).get_string_from_ascii() == "ID3"
			if not id3 and not (bytes[0] == 0xFF and (bytes[1] & 0xE0) == 0xE0):
				return "no es un archivo MP3"
		_:
			return "extension no admitida"
	return ""


## Formato del bloque fmt de un WAV: PCM de 8, 16, 24 o 32 bits o coma
## flotante de 32 o 64 bits (lo que decodifica Godot). "" = valido.
static func _check_wav_format(bytes: PackedByteArray) -> String:
	var pos: int = 12
	while pos + 8 <= bytes.size():
		var chunk: String = bytes.slice(pos, pos + 4).get_string_from_ascii()
		var size: int = bytes.decode_u32(pos + 4)
		if chunk == "fmt ":
			if pos + 24 > bytes.size():
				return "bloque fmt incompleto"
			var tag: int = bytes.decode_u16(pos + 8)
			var channels: int = bytes.decode_u16(pos + 10)
			var bits: int = bytes.decode_u16(pos + 22)
			if channels < 1 or channels > 2:
				return "%d canales (solo mono o estereo)" % channels
			if tag == 0xFFFE and pos + 34 <= bytes.size():
				tag = bytes.decode_u16(pos + 32)
			if tag == 1 and bits in [8, 16, 24, 32]:
				return ""
			if tag == 3 and bits in [32, 64]:
				return ""
			return "formato WAV no admitido (codigo %d, %d bits): usa PCM de 16 bits" % [tag, bits]
		pos += 8 + size + (size & 1)
	return "sin bloque fmt"


## Decodifica `bytes` sin bucle propio (el bucle lo lleva el catalogo).
static func _decode_audio(bytes: PackedByteArray, ext: String) -> AudioStream:
	match ext:
		"ogg":
			var ogg: AudioStreamOggVorbis = AudioStreamOggVorbis.load_from_buffer(bytes)
			if ogg != null:
				ogg.loop = false
			return ogg
		"wav":
			# edit/loop_mode 1 = desactivado (ignora los bucles guardados en el WAV).
			var wav: AudioStreamWAV = AudioStreamWAV.load_from_buffer(bytes, {"edit/loop_mode": 1})
			if wav != null:
				wav.loop_mode = AudioStreamWAV.LOOP_DISABLED
			return wav
		"mp3":
			var mp3: AudioStreamMP3 = AudioStreamMP3.load_from_buffer(bytes)
			if mp3 != null:
				mp3.loop = false
			return mp3
	return null


## Errores del catalogo `data` (vacio = valido). `bus_names`: buses que existen.
## Lo usan las pruebas (y equivale a tools/validate_audio.py).
static func validate_catalog(data: Dictionary, bus_names: PackedStringArray) -> PackedStringArray:
	var errors: PackedStringArray = []
	var buses: Variant = data.get("buses", [])
	if not buses is Array:
		errors.append("buses no es una lista")
		buses = []
	var sounds: Variant = data.get("sounds", {})
	if not sounds is Dictionary:
		return PackedStringArray(["sounds no es un diccionario"])
	for bus: Variant in buses:
		if not bus_names.has(String(bus)):
			errors.append("bus '%s' no existe en default_bus_layout.tres" % bus)
	for id: Variant in sounds:
		var entry: Variant = sounds[id]
		if not entry is Dictionary:
			errors.append("%s: la entrada no es un diccionario" % id)
			continue
		var bus: String = String((entry as Dictionary).get("bus", ""))
		if not (buses as Array).has(bus):
			errors.append("%s: bus '%s' no es uno de buses" % [id, bus])
		var files: Variant = (entry as Dictionary).get("files", [])
		if not files is Array:
			errors.append("%s: files no es una lista" % id)
		var time: String = String((entry as Dictionary).get("time", "real"))
		if time != "real" and time != TIME_WORLD:
			errors.append("%s: time '%s' no es real ni world" % [id, time])
	for section: String in ["event_bus", "nodes", "ambience"]:
		var list: Variant = data.get(section, [])
		if not list is Array:
			errors.append("%s no es una lista" % section)
			continue
		for item: Variant in list:
			if not item is Dictionary or not (sounds as Dictionary).has(String((item as Dictionary).get("sound", ""))):
				errors.append("%s: sonido desconocido en %s" % [section, item])
	return errors


# --- Reproduccion ---

## Reproduce `id` (si `at` es un Vector2, en esa posicion del mundo). Falso si
## no suena: sin entrada, sin archivo, en enfriamiento o senal de ritmo
## desactivada. Nunca da error.
func play(id: StringName, at: Variant = null) -> bool:
	var entry: Dictionary = get_entry(id)
	if entry.is_empty():
		return false
	if bool(entry.get("cue", false)) and not GameSettings.are_rhythm_cues_enabled():
		return false
	var now: int = Time.get_ticks_msec()
	var cooldown_ms: int = int(float(entry.get("cooldown_s", 0.0)) * 1000.0)
	if cooldown_ms > 0 and _last_play_ms.has(id) and now - int(_last_play_ms[id]) < cooldown_ms:
		return false
	var stream: AudioStream = _pick_stream(id)
	if stream == null:
		return false
	if bool(entry.get("loop", false)):
		return play_loop(id, String(id))
	_last_play_ms[id] = now
	var player: Node = _take_player_2d() if at is Vector2 else _take_player()
	if player == null:
		return false
	_configure(player, id, entry, stream)
	if at is Vector2:
		(player as AudioStreamPlayer2D).global_position = at
	player.call(&"play")
	_remember(id)
	return true


## Empieza el bucle `id` con la clave `key` (uno por clave). Falso si no hay archivo.
func play_loop(id: StringName, key: String) -> bool:
	if _loops.has(key) and is_instance_valid(_loops[key]):
		return true
	var entry: Dictionary = get_entry(id)
	var stream: AudioStream = _pick_stream(id)
	if entry.is_empty() or stream == null:
		return false
	var player := AudioStreamPlayer.new()
	player.name = "Loop_%s" % String(id)
	add_child(player)
	_configure(player, id, entry, stream)
	# Bucle manual (vuelve a empezar al terminar) y no loop_mode del WAV: un WAV
	# en bucle que suena al cerrar el juego deja una fuga en Godot 4.7, y asi
	# sirve igual para .wav, .ogg y .mp3 sin tocar su importacion.
	player.finished.connect(player.play)
	player.play()
	_loops[key] = player
	_remember(id)
	return true


## Algo se paro hace muy poco (el hilo de mezcla aun puede retenerlo).
func _stopped_recently() -> bool:
	return Time.get_ticks_msec() - _last_stop_ms < EXIT_FLUSH_MS * 4


## Para el bucle de clave `key`.
func stop_loop(key: String) -> void:
	_last_stop_ms = Time.get_ticks_msec()
	var player: Variant = _loops.get(key)
	_loops.erase(key)
	if player != null and is_instance_valid(player):
		(player as AudioStreamPlayer).finished.disconnect((player as AudioStreamPlayer).play)
		(player as AudioStreamPlayer).stop()
		(player as AudioStreamPlayer).queue_free()


## Bucles en curso (ambientes).
func loop_count() -> int:
	var count: int = 0
	for key: Variant in _loops:
		if is_instance_valid(_loops[key]):
			count += 1
	return count


func is_loop_playing(key: String) -> bool:
	return _loops.has(key) and is_instance_valid(_loops[key]) and (_loops[key] as AudioStreamPlayer).playing


## Para todo (cambio de catalogo, pruebas).
func stop_all() -> void:
	for key: Variant in _loops.keys():
		stop_loop(String(key))
	for player: AudioStreamPlayer in _players:
		player.stop()
		player.stream = null
	for player: AudioStreamPlayer2D in _players_2d:
		player.stop()
		player.stream = null


## Reproductores (no posicionales) que suenan ahora con `id`.
func playing_count(id: StringName) -> int:
	var count: int = 0
	for player: AudioStreamPlayer in _players:
		if player.playing and player.get_meta(&"sound_id", &"") == id:
			count += 1
	return count


## Blip del interlocutor `speaker` (&"" = Eco) segun el acceso actual.
func blip_id_for(speaker: StringName, lap: int = GameState.lap) -> StringName:
	var speakers: Dictionary = _text_blips().get("speakers", {})
	var spec: Variant = speakers.get(String(speaker), speakers.get("", {}))
	if not spec is Dictionary:
		return &""
	var by_lap: Variant = (spec as Dictionary).get("by_lap", {})
	if by_lap is Dictionary and not (by_lap as Dictionary).is_empty():
		var key: String = str(clampi(lap, GameState.LAP_EASY, GameState.LAP_HARD))
		return StringName(String((by_lap as Dictionary).get(key, (by_lap as Dictionary).get("1", ""))))
	return StringName(String((spec as Dictionary).get("sound", "")))


# --- Interno: reproductores ---

func _build_players() -> void:
	for player: AudioStreamPlayer in _players:
		player.queue_free()
	for player: AudioStreamPlayer2D in _players_2d:
		player.queue_free()
	_players.clear()
	_players_2d.clear()
	for i: int in maxi(1, int(_data.get("voices", 16))):
		var player := AudioStreamPlayer.new()
		player.name = "Voice_%d" % i
		add_child(player)
		_players.append(player)
	for i: int in maxi(1, int(_data.get("positional_voices", 8))):
		var player_2d := AudioStreamPlayer2D.new()
		player_2d.name = "Voice2D_%d" % i
		add_child(player_2d)
		_players_2d.append(player_2d)


func _take_player() -> AudioStreamPlayer:
	for i: int in _players.size():
		var index: int = (_next_player + i) % _players.size()
		if not _players[index].playing:
			_next_player = (index + 1) % _players.size()
			return _players[index]
	var oldest: AudioStreamPlayer = _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	return oldest


func _take_player_2d() -> AudioStreamPlayer2D:
	for i: int in _players_2d.size():
		var index: int = (_next_player_2d + i) % _players_2d.size()
		if not _players_2d[index].playing:
			_next_player_2d = (index + 1) % _players_2d.size()
			return _players_2d[index]
	var oldest: AudioStreamPlayer2D = _players_2d[_next_player_2d]
	_next_player_2d = (_next_player_2d + 1) % _players_2d.size()
	return oldest


func _configure(player: Node, id: StringName, entry: Dictionary, stream: AudioStream) -> void:
	var pitch: float = 1.0
	var spread: float = clampf(float(entry.get("pitch_random", 0.0)), 0.0, 0.5)
	if spread > 0.0:
		pitch *= _rng.randf_range(1.0 - spread, 1.0 + spread)
	if String(entry.get("time", "real")) == TIME_WORLD:
		pitch *= clampf(GameState.world_time_scale, float(_data.get("world_pitch_min", 0.75)), 1.0)
	player.set(&"stream", stream)
	player.set(&"bus", bus_for(id))
	player.set(&"volume_db", float(entry.get("volume_db", 0.0)))
	player.set(&"pitch_scale", maxf(pitch, 0.01))
	player.set_meta(&"sound_id", id)


func _remember(id: StringName) -> void:
	history.append(id)
	if history.size() > HISTORY_MAX:
		history.remove_at(0)


## Streams de `id`: por cada nombre de files, el externo si lo hay y vale; si
## no, el empaquetado. Un externo con el nombre del ID (que no sea uno de files)
## sustituye a todas las variantes cuando ninguna tiene externo propio.
func _resolve(id: StringName) -> Array:
	if _streams.has(id):
		return _streams[id]
	var streams: Array = []
	var sources: PackedStringArray = []
	var names: PackedStringArray = _file_names(id)
	var any_external: bool = false
	var dir: String = String(_data.get("audio_dir", "res://assets/audio"))
	for name: String in names:
		var external: Array = _load_external(id, name) if not _external_files.is_empty() else []
		if not external.is_empty():
			streams.append(external[0])
			sources.append(String(external[1]))
			any_external = true
			continue
		var path: String = _find_file(dir, name)
		if path.is_empty():
			continue
		var stream: Variant = load(path)
		if stream is AudioStream:
			streams.append(stream)
			sources.append(path)
	if not any_external and not names.has(String(id)) and not _external_files.is_empty():
		var whole: Array = _load_external(id, String(id))
		if not whole.is_empty():
			streams = [whole[0]]
			sources = PackedStringArray([String(whole[1])])
	_streams[id] = streams
	_sources[id] = sources
	return streams


func _pick_stream(id: StringName) -> AudioStream:
	var streams: Array = _resolve(id)
	if streams.is_empty():
		return null
	var index: int = 0
	if streams.size() > 1:
		index = _rng.randi_range(0, streams.size() - 2)
		if index >= int(_last_variant.get(id, -1)):
			index += 1
	_last_variant[id] = index
	return streams[index]


## Busca `name` en `dir`: tal cual si trae extension; si no, con cada una de
## extensions (en orden). Solo devuelve rutas importables (ResourceLoader.exists).
func _find_file(dir: String, name: String) -> String:
	var base: String = dir.path_join(name)
	if not name.get_extension().is_empty():
		return base if ResourceLoader.exists(base) else ""
	for ext: Variant in _data.get("extensions", ["ogg", "wav"]):
		var path: String = "%s.%s" % [base, ext]
		if ResourceLoader.exists(path):
			return path
	return ""


# --- Interno: conexiones ---

func _connect_event_bus() -> void:
	var list: Variant = _data.get("event_bus", [])
	if not list is Array:
		return
	# Una conexion por senal (Godot no admite dos del mismo metodo aunque
	# cambien los argumentos ligados); el manejador recorre sus enlaces.
	for item: Variant in list:
		if not item is Dictionary:
			continue
		var signal_name := StringName(String((item as Dictionary).get("signal", "")))
		if EventBus.has_signal(signal_name) and not EventBus.is_connected(signal_name, _on_event_bus):
			EventBus.connect(signal_name, _on_event_bus.bind(signal_name))


func _disconnect_event_bus() -> void:
	for connection: Dictionary in get_incoming_connections():
		if connection.get("signal") is Signal and (connection["signal"] as Signal).get_object() == EventBus:
			(connection["signal"] as Signal).disconnect(connection["callable"])


func _on_event_bus(...args: Array) -> void:
	var signal_name: String = String(args.pop_back())
	for item: Variant in _data.get("event_bus", []):
		if item is Dictionary and String((item as Dictionary).get("signal", "")) == signal_name \
				and _matches(item, args):
			play(StringName(String((item as Dictionary).get("sound", ""))))


func _scan(node: Node) -> void:
	_on_node_added(node)
	for child: Node in node.get_children():
		_scan(child)


func _on_node_added(node: Node) -> void:
	if node == self or node.get_parent() == self:
		return
	if node is EcoTextBox:
		_text_boxes[node.get_instance_id()] = [node, 0, 0]
		if not node.tree_exiting.is_connected(_forget_text_box):
			node.tree_exiting.connect(_forget_text_box.bind(node.get_instance_id()), CONNECT_ONE_SHOT)
	var script: Script = node.get_script() as Script
	if script == null:
		return
	if not _script_bindings.has(script):
		_script_bindings[script] = _bindings_for(script)
	var bindings: Dictionary = _script_bindings[script]
	# Un nodo que sale y vuelve a entrar en el arbol conserva sus conexiones.
	var first_time: bool = not node.has_meta(BOUND_META)
	node.set_meta(BOUND_META, true)
	for index: int in bindings.get("nodes", []):
		var item: Dictionary = (_data.get("nodes", []) as Array)[index]
		var signal_name := StringName(String(item.get("signal", "")))
		if first_time and node.has_signal(signal_name) and not node.is_connected(signal_name, _on_node_signal):
			node.connect(signal_name, _on_node_signal.bind(signal_name, node))
	for index: int in bindings.get("ambience", []):
		var item_amb: Dictionary = (_data.get("ambience", []) as Array)[index]
		var key: String = "%s#%d" % [String(item_amb.get("sound", "")), node.get_instance_id()]
		play_loop(StringName(String(item_amb.get("sound", ""))), key)
		node.tree_exiting.connect(stop_loop.bind(key), CONNECT_ONE_SHOT)
	if first_time and bindings.get("steps", false):
		_connect_steps(node)


func _forget_text_box(id: int) -> void:
	_text_boxes.erase(id)


## Enlaces que tocan a los nodos de `script` (su clase o una base).
func _bindings_for(script: Script) -> Dictionary:
	var names: PackedStringArray = []
	var current: Script = script
	while current != null:
		var global: String = String(current.get_global_name())
		if not global.is_empty():
			names.append(global)
		current = current.get_base_script()
	var out: Dictionary = {"nodes": [], "ambience": [], "steps": false}
	if names.is_empty():
		return out
	for section: String in ["nodes", "ambience"]:
		var list: Variant = _data.get(section, [])
		if list is Array:
			for i: int in (list as Array).size():
				if list[i] is Dictionary and names.has(String((list[i] as Dictionary).get("class", ""))):
					(out[section] as Array).append(i)
	var steps: Variant = _data.get("steps", {})
	out["steps"] = steps is Dictionary and names.has(String((steps as Dictionary).get("class", "")))
	return out


func _on_node_signal(...args: Array) -> void:
	var node: Variant = args.pop_back()
	var signal_name: String = String(args.pop_back())
	if not is_instance_valid(node):
		return
	var script: Script = (node as Node).get_script() as Script
	if script == null:
		return
	if not _script_bindings.has(script):
		# Catalogo recargado (pruebas): las conexiones siguen, los enlaces se rehacen.
		_script_bindings[script] = _bindings_for(script)
	var bindings: Dictionary = _script_bindings[script]
	for index: int in bindings.get("nodes", []):
		var item: Dictionary = (_data.get("nodes", []) as Array)[index]
		if String(item.get("signal", "")) != signal_name or not _matches(item, args):
			continue
		var at: Variant = null
		if bool(item.get("positional", false)) and node is Node2D:
			at = (node as Node2D).global_position
		play(StringName(String(item.get("sound", ""))), at)


## `when` de un enlace: indice de argumento -> valor o lista de valores (texto).
func _matches(item: Dictionary, args: Array) -> bool:
	var when: Variant = item.get("when", {})
	if not when is Dictionary:
		return true
	for key: Variant in when:
		var i: int = int(key)
		if i < 0 or i >= args.size():
			return false
		var expected: Variant = when[key]
		var actual: String = str(args[i])
		if expected is Array:
			var found: bool = false
			for value: Variant in expected:
				found = found or str(value) == actual
			if not found:
				return false
		elif str(expected) != actual:
			return false
	return true


# --- Pasos de Isak ---

func _connect_steps(node: Node) -> void:
	var steps: Dictionary = _data.get("steps", {})
	var sprite: AnimatedSprite2D = node.get_node_or_null(NodePath(String(steps.get("sprite", "AnimatedSprite2D")))) as AnimatedSprite2D
	if sprite == null:
		return
	sprite.frame_changed.connect(_on_step_frame.bind(node, sprite))


func _on_step_frame(body: Node, sprite: AnimatedSprite2D) -> void:
	if not is_instance_valid(body) or not is_instance_valid(sprite):
		return
	if body is CharacterBody2D and not (body as CharacterBody2D).is_on_floor():
		return
	var steps: Dictionary = _data.get("steps", {})
	var frames: Variant = (steps.get("frames", {}) as Dictionary).get(String(sprite.animation), [])
	if frames is Array and (frames as Array).has(sprite.frame):
		play(StringName(String(steps.get("sound", ""))), (body as Node2D).global_position if body is Node2D else null)


# --- Blips de texto ---

func _text_blips() -> Dictionary:
	var blips: Variant = _data.get("text_blips", {})
	return blips if blips is Dictionary else {}


## Mira cuanto ha escrito cada cuadro de texto y suena su blip (cada frame;
## publico para las pruebas).
func poll_text_blips() -> void:
	var every: int = maxi(1, int(_text_blips().get("every_chars", 2)))
	for key: Variant in _text_boxes.keys():
		var state: Array = _text_boxes[key]
		var box: EcoTextBox = state[0] as EcoTextBox
		if not is_instance_valid(box):
			_text_boxes.erase(key)
			continue
		var typed: int = box.get_typed_count()
		var last: int = int(state[1])
		if typed < last:
			state[1] = typed
			state[2] = 0
			continue
		if typed == last:
			continue
		var text: String = box.get_text()
		var pending: int = int(state[2])
		for i: int in range(last, mini(typed, text.length())):
			if text[i] != " " and text[i] != "\n":
				pending += 1
		state[1] = typed
		if pending >= every:
			pending = 0
			var id: StringName = blip_id_for(box.get_speaker_id())
			if id != &"":
				play(id)
		state[2] = pending
