# Textos, ayudas Q y sonidos de La Curadora (paso 19 de docs/propuesta-mundo-3.md
# §8, 2026-10-27; §5.10 y §6.4): las 3 ayudas nuevas existen en data/help.json
# (Mundo 3, primer nivel 3-boss, ficha del album) y las piezas del jefe las llevan
# (el marco; la lente solo mientras baja a encuadrar; el marco que se cierra solo
# mientras avisa o se cierra); las lineas del jefe las dice Eco por ella (eco_boss,
# sin pausa en las fases); mus_boss3 (CuratorMusic) suena en la pelea y se quita en
# el golpe final; los IDs de audio del Mundo 3 estan en data/audio.json con su
# provisional y enganchados a una senal; la galeria lleva su ambiente y, fuera de
# la arena, la musica del nivel.
extends GutTest

const LEVEL_SCENE: PackedScene = preload("res://scenes/levels/3-boss.tscn")
const GALLERY_SCENE: PackedScene = preload("res://scenes/levels/3-1.tscn")
const DT: float = 1.0 / 60.0
const NEW_TYPES: Array[String] = ["curator_boss", "curator_lens", "closing_frame"]
## IDs de §6.4 de la propuesta (todos con provisional de tools/gen_audio_placeholders.py).
const W3_SOUNDS: Array[String] = ["sfx_gesture_pinch", "sfx_gesture_unpinch", "sfx_w3_like_collect",
	"sfx_w3_like_stolen", "sfx_w3_like_platform", "sfx_w3_flash_charge", "sfx_w3_flash", "sfx_w3_mirror_bounce",
	"sfx_w3_filter_shimmer", "amb_w3_gallery", "mus_w3_level", "mus_boss3", "sfx_w3_like_source",
	"sfx_w3_like_reset", "sfx_w3_crop_tool", "sfx_w3_hunter_turn", "sfx_w3_reflection_spawn", "sfx_w3_pose_plate",
	"sfx_boss3_intro", "sfx_boss3_turn", "sfx_boss3_frame_close"]

var _level: GeneratedLevel
var _boss: Curator


func before_all() -> void:
	EcoTextBox.pause_important = false


func after_all() -> void:
	EcoTextBox.pause_important = true


func before_each() -> void:
	DebugMode.input_enabled = false
	DebugMode.reset()


func after_each() -> void:
	_level = null
	_boss = null
	get_tree().paused = false
	DebugMode.reset()
	DebugMode.input_enabled = true
	GameState.reset_progress()
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX


func _arena() -> void:
	_level = LEVEL_SCENE.instantiate() as GeneratedLevel
	_boss = _level.get_node(^"Objects/curator") as Curator
	_boss.intro_on_arrival = false
	_boss.defeat_sequence = false
	_boss.auto_process = false
	_boss.lap_override = 1
	add_child_autofree(_level)
	_boss.get_core().auto_process = false
	await wait_physics_frames(2)


func _advance(seconds: float) -> void:
	for i: int in ceili(seconds / DT - 0.001):
		_boss.advance(DT)
		_boss.get_core().advance_mark(DT)


func _advance_until(cond: Callable, max_s: float = 20.0) -> void:
	var t: float = 0.0
	while t < max_s and not cond.call():
		_advance(DT)
		t += DT


func _to_phase(phase: int) -> void:
	while _boss.get_phase() < phase:
		_boss.take_core_hit(1)


func test_help_types_exist_with_album_cards() -> void:
	var catalog: HelpCatalog = HelpCatalog.shared()
	for id: String in NEW_TYPES:
		assert_true(catalog.has(StringName(id)), "%s en data/help.json" % id)
		var entry: Dictionary = catalog.entry(StringName(id))
		assert_eq(int(entry.get("world", 0)), 3, "%s: carpeta del Mundo 3" % id)
		assert_eq(String(entry.get("first_level", "")), "3-boss")
		assert_false(String(entry.get("text", "")).is_empty())
		for word: String in ["vuelta", "Easy", "Normal", "Hard"]:
			assert_false(String(entry.get("text", "")).contains(word))
		assert_true(ResourceLoader.exists("res://assets/sprites/ui/album/album_card_%s.png" % id),
			"%s: ficha del album" % id)
	assert_true(catalog.types_of_level(&"3-boss").size() >= NEW_TYPES.size())
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/bosses/curator.json"))
	assert_false(cfg.has("_help_planned"), "Sin ayudas pendientes")
	assert_eq((cfg.get("help", {}) as Dictionary).size(), NEW_TYPES.size())


func test_boss_frame_carries_its_help() -> void:
	await _arena()
	var frame: Node = _boss.get_node(^"Frame")
	assert_eq(HelpCatalog.help_id_of(frame), Curator.HELP_BOSS, "El marco: curator_boss")
	assert_true(HelpCatalog.is_help_live(frame))


func test_lens_help_only_while_lowered_to_frame() -> void:
	await _arena()
	var lens: Node = _boss.get_node(^"LensHelp")
	assert_eq(HelpCatalog.help_id_of(lens), Curator.HELP_LENS)
	_boss.start()
	assert_false(lens.call(&"is_help_available"), "Arriba, sin ventana: la lente no ayuda")
	_advance_until(func() -> bool: return _boss.is_window_open(), 10.0)
	assert_true(_boss.is_window_open())
	_advance(0.5)
	assert_true(lens.call(&"is_help_available"), "Baja a encuadrar: ayuda")
	assert_almost_eq((lens as Node2D).global_position, _boss.get_lens_point(), Vector2(1.0, 1.0),
		"La marca sigue a la lente")
	_boss.close_window()
	assert_false(lens.call(&"is_help_available"), "Vuelve a subir: sin ayuda")
	_to_phase(2)
	_advance_until(func() -> bool: return _boss.is_window_open(), 12.0)
	assert_true(_boss.is_window_open(), "Posa de espaldas")
	assert_false(lens.call(&"is_help_available"), "De espaldas no baja: sin ayuda")


func test_closing_frame_help_only_while_it_warns_or_closes() -> void:
	await _arena()
	var marker: Node = _boss.get_node(^"ClosingFrameHelp")
	assert_eq(HelpCatalog.help_id_of(marker), Curator.HELP_CLOSING_FRAME)
	_boss.start()
	_to_phase(3)
	assert_false(marker.call(&"is_help_available"), "Sin marco cerrandose: sin ayuda")
	_advance_until(func() -> bool: return _boss.get_frame_state() == Curator.FRAME_WARN, 8.0)
	assert_true(marker.call(&"is_help_available"), "Mientras avisa: ayuda")
	assert_almost_eq((marker as Node2D).global_position, _boss.get_closing_rect().get_center(), Vector2(1.0, 1.0))
	_advance_until(func() -> bool: return _boss.get_frame_state() == Curator.FRAME_IDLE, 3.0)
	assert_false(marker.call(&"is_help_available"), "Cerrado y abierto otra vez: sin ayuda")


func test_lines_use_the_boss_speaker_without_pause() -> void:
	await _arena()
	var box := _level.get_node(^"EcoTextBox") as EcoTextBox
	var texts: Dictionary = _boss.get_config().get("texts", {})
	assert_string_contains(String(_boss.get_config().get("texts_status", "")), "PROPUESTA")
	for key: String in ["intro", "final_system", "defeat"]:
		assert_false(String(texts.get(key, "")).is_empty(), "Texto %s" % key)
	_boss.start()
	_to_phase(2)
	assert_eq(box.get_speaker_id(), BossBase.SPEAKER, "Eco habla por el jefe")
	assert_string_contains(box.get_text(), "De espaldas sales mejor", "Linea de la fase 2")
	assert_false(box.is_important(), "Los cambios de fase no pausan")
	assert_false(get_tree().paused)


func test_music_during_the_fight_and_not_after_the_final_blow() -> void:
	await _arena()
	assert_null(_boss.get_music(), "Sin musica antes de empezar")
	_boss.start()
	assert_not_null(_boss.get_music(), "mus_boss3 (CuratorMusic) en la pelea")
	var music: Node = _boss.get_music()
	assert_false(music is BossMusic or music is AutoplayMusic, "Ni mus_boss1 ni mus_boss2")
	while not _boss.is_defeated():
		_boss.take_core_hit(1)
	assert_null(_boss.get_music(), "Se quita en el golpe final")


func test_gallery_background_ambience_and_level_music_outside_the_arena() -> void:
	await _arena()
	var bg := _level.get_node(^"Background") as World3Background
	assert_not_null(bg, "La arena usa el fondo de la galeria (amb_w3_gallery)")
	await wait_physics_frames(1)
	assert_null(bg.get_music(), "En la arena no suena la musica del nivel (manda mus_boss3)")
	# Fuera de la arena (sin nodos del grupo «boss»): la musica del nivel.
	_level.queue_free()
	_boss = null
	await wait_physics_frames(2)
	var gallery := GALLERY_SCENE.instantiate() as GeneratedLevel
	add_child_autofree(gallery)
	await wait_physics_frames(2)
	var bg31 := gallery.get_node(^"Background") as World3Background
	assert_not_null(bg31, "El 3-1 usa el fondo de la galeria")
	assert_not_null(bg31.get_music(), "mus_w3_level (GalleryMusic) en el 3-1")


func test_world3_sound_ids_with_placeholders_and_bindings() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/audio.json"))
	var sounds: Dictionary = data.get("sounds", {})
	var used: Dictionary = {}
	for section: String in ["event_bus", "nodes", "ambience"]:
		for item: Variant in data.get(section, []):
			used[String((item as Dictionary).get("sound", ""))] = true
	for id: String in W3_SOUNDS:
		assert_true(sounds.has(id), "%s en data/audio.json" % id)
		assert_true(used.has(id), "%s enganchado a una senal" % id)
		assert_true(FileAccess.file_exists("res://assets/audio/%s.wav" % id), "%s: provisional" % id)
	for id: String in ["sfx_w3_hunter_turn", "sfx_boss3_frame_close"]:
		assert_true(bool((sounds[id] as Dictionary).get("cue", false)), "%s: senal de ritmo (accesibilidad)" % id)
