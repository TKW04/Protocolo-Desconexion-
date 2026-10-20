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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	load_catalog(DATA_PATH)
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
	var entry: Dictionary = get_entry(id)
	var files: Variant = entry.get("files", [String(id)])
	if not files is Array or (files as Array).is_empty():
		files = [String(id)]
	var dir: String = String(_data.get("audio_dir", "res://assets/audio"))
	for file: Variant in files:
		var path: String = _find_file(dir, String(file))
		if not path.is_empty():
			out.append(path)
	return out


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


func _resolve(id: StringName) -> Array:
	if _streams.has(id):
		return _streams[id]
	var streams: Array = []
	for path: String in resolve_paths(id):
		var stream: Variant = load(path)
		if stream is AudioStream:
			streams.append(stream)
	_streams[id] = streams
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
	var bindings: Dictionary = _script_bindings.get((node as Node).get_script(), {})
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
