# Textos, ayudas Q y sonidos de El Visto y del Mundo 4 (paso 20 de
# docs/propuesta-mundo-4.md §8, 2026-10-28; §5.10 y §6.4): las 3 ayudas nuevas
# existen en data/help.json (Mundo 4, primer nivel 4-boss, ficha del album) y las
# piezas del jefe las llevan (el cuerpo mientras se ve; el escudo solo levantado;
# el «escribiendo…» gigante solo mientras se llenan los puntos); las lineas del
# jefe las dice Eco por el (eco_boss, sin pausa en las fases); mus_boss4
# (SeenMusic) suena en la pelea y se quita en el golpe final; cada punto del
# «escribiendo…» avisa (dot_added); los IDs de audio del Mundo 4 estan en
# data/audio.json con su provisional y enganchados a una senal; los niveles del
# Mundo 4 llevan su ambiente y, fuera de la arena, la musica del nivel, que se
# calla cuando la ola de «Visto» se apaga; las lineas nuevas de los niveles
# (Linterna, ola, cierre del 4-3) y el cartel «En linea hace 3 h» estan en datos.
extends GutTest

const LEVEL_SCENE: PackedScene = preload("res://scenes/levels/4-boss.tscn")
const CHAT_SCENE: PackedScene = preload("res://scenes/levels/4-1.tscn")
const WAVE_SCENE: PackedScene = preload("res://scenes/levels/ola_test.tscn")
const DT: float = 1.0 / 60.0
const NEW_TYPES: Array[String] = ["seen_boss", "seen_shield", "seen_typing"]
## IDs de §6.4 de la propuesta (todos con provisional de tools/gen_audio_placeholders.py).
const W4_SOUNDS: Array[String] = ["sfx_gesture_shake", "sfx_w4_typing", "sfx_w4_bubble_pop_in",
	"sfx_w4_seen_freeze", "sfx_w4_seen_break", "sfx_w4_troll_shot", "sfx_w4_ghost_vanish", "sfx_w4_ghost_appear",
	"sfx_w4_autocorrect", "sfx_w4_sticker_explode", "amb_w4_chat_night", "mus_w4_level", "mus_boss4",
	"sfx_w4_seen_interrupt", "sfx_w4_seen_wave", "sfx_w4_undo", "sfx_w4_typed_wall_erase", "sfx_w4_message_deleted",
	"sfx_w4_flashlight_on", "sfx_boss4_intro", "sfx_boss4_vanish", "sfx_boss4_shield_break", "sfx_boss4_typing",
	"sfx_boss4_send"]

var _level: GeneratedLevel
var _boss: Seen


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
	_boss = _level.get_node(^"Objects/seen") as Seen
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
		assert_eq(int(entry.get("world", 0)), 4, "%s: carpeta del Mundo 4" % id)
		assert_eq(String(entry.get("first_level", "")), "4-boss")
		assert_false(String(entry.get("text", "")).is_empty())
		assert_string_contains(String(entry.get("_notes", "")), "PROPUESTO")
		for word: String in ["vuelta", "Easy", "Normal", "Hard"]:
			assert_false(String(entry.get("text", "")).contains(word))
		assert_true(ResourceLoader.exists("res://assets/sprites/ui/album/album_card_%s.png" % id),
			"%s: ficha del album" % id)
	assert_true(catalog.types_of_level(&"4-boss").size() >= NEW_TYPES.size())
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/bosses/seen.json"))
	assert_eq((cfg.get("help", {}) as Dictionary).size(), NEW_TYPES.size())


func test_body_help_while_seen_and_not_while_hidden() -> void:
	await _arena()
	var body: Node = _boss.get_node(^"BodyHelp")
	assert_eq(HelpCatalog.help_id_of(body), Seen.HELP_BOSS, "El doble check: seen_boss")
	assert_true(HelpCatalog.is_help_live(body), "Antes de la pelea se ve")
	_boss.start()
	_advance_until(func() -> bool: return _boss.get_dash_stage() == Seen.DASH_HIDDEN, 30.0)
	assert_eq(_boss.get_dash_stage(), Seen.DASH_HIDDEN, "Se esfuma")
	assert_false(body.call(&"is_help_available"), "Oculto: sin ayuda")
	_advance_until(func() -> bool: return _boss.get_dash_stage() == Seen.DASH_READY, 5.0)
	assert_true(body.call(&"is_help_available"), "La silueta se ve: ayuda")
	assert_almost_eq((body as Node2D).global_position, _boss.get_silhouette_rect().get_center(), Vector2(1.0, 1.0),
		"La marca sigue a la silueta")
	while not _boss.is_defeated():
		_boss.take_core_hit(1)
	assert_false(body.call(&"is_help_available"), "Tras el golpe final: sin ayuda")


func test_shield_help_only_while_the_shield_is_up() -> void:
	await _arena()
	var marker: Node = _boss.get_node(^"ShieldHelp")
	assert_eq(HelpCatalog.help_id_of(marker), Seen.HELP_SHIELD)
	_boss.start()
	assert_false(marker.call(&"is_help_available"), "Fase 1: sin escudo, sin ayuda")
	_to_phase(2)
	assert_true(_boss.is_shield_up())
	assert_true(marker.call(&"is_help_available"), "Escudo levantado: ayuda")
	assert_almost_eq((marker as Node2D).global_position, _boss.get_shield_rect().get_center(), Vector2(1.0, 1.0))
	_boss.open_window(3.0)
	assert_false(marker.call(&"is_help_available"), "En la ventana el escudo ha caido: sin ayuda")


func test_typing_help_only_while_the_dots_fill_and_each_dot_signals() -> void:
	await _arena()
	var marker: Node = _boss.get_node(^"TypingHelp")
	assert_eq(HelpCatalog.help_id_of(marker), Seen.HELP_TYPING)
	_boss.start()
	_to_phase(3)
	assert_false(marker.call(&"is_help_available"), "Sin «escribiendo…»: sin ayuda")
	var dots: Array[int] = []
	_boss.dot_added.connect(func(n: int) -> void: dots.append(n))
	_advance_until(func() -> bool: return _boss.get_typing_state() == Seen.TYPING_ON, 20.0)
	assert_true(marker.call(&"is_help_available"), "Escribiendo: ayuda")
	assert_almost_eq((marker as Node2D).global_position, _boss.get_typing_rect().get_center(), Vector2(1.0, 1.0))
	_boss.interrupt_typing()
	assert_false(marker.call(&"is_help_available"), "En silencio: sin ayuda")
	_boss.close_window()
	_advance_until(func() -> bool: return _boss.get_typing_state() == Seen.TYPING_SENT, 40.0)
	var expected: Array[int] = []
	for i: int in range(1, _boss.get_dots_total() + 1):
		expected.append(i)
	assert_eq(dots.slice(dots.size() - expected.size()), expected, "Un aviso por punto hasta el ultimo (sfx_boss4_typing)")


func test_lines_use_the_boss_speaker_and_the_intro_has_the_nickname() -> void:
	await _arena()
	var box := _level.get_node(^"EcoTextBox") as EcoTextBox
	var texts: Dictionary = _boss.get_config().get("texts", {})
	assert_string_contains(String(_boss.get_config().get("texts_status", "")), "PROPUESTA")
	assert_string_contains(String(texts.get("intro", "")), "{apodo}", "La intro lleva el apodo")
	for key: String in ["intro", "final_system", "defeat"]:
		assert_false(String(texts.get(key, "")).is_empty(), "Texto %s" % key)
	_boss.start()
	_to_phase(2)
	assert_eq(box.get_speaker_id(), BossBase.SPEAKER, "Eco habla por el jefe")
	assert_string_contains(box.get_text(), "Ninguno te escribe", "Linea de la fase 2")
	assert_false(box.is_important(), "Los cambios de fase no pausan")
	assert_false(get_tree().paused)


func test_music_during_the_fight_and_not_after_the_final_blow() -> void:
	await _arena()
	assert_null(_boss.get_music(), "Sin musica antes de empezar")
	_boss.start()
	var music: Node = _boss.get_music()
	assert_not_null(music, "mus_boss4 (SeenMusic) en la pelea")
	assert_false(music is BossMusic or music is AutoplayMusic or music is CuratorMusic, "Solo mus_boss4")
	while not _boss.is_defeated():
		_boss.take_core_hit(1)
	assert_null(_boss.get_music(), "Se quita en el golpe final")


func test_chat_background_ambience_and_level_music_outside_the_arena() -> void:
	await _arena()
	var bg := _level.get_node(^"Background") as World4Background
	assert_not_null(bg, "La arena usa el fondo del Mundo 4 (amb_w4_chat_night)")
	await wait_physics_frames(1)
	assert_null(bg.get_music(), "En la arena no suena la musica del nivel (manda mus_boss4)")
	_level.queue_free()
	_boss = null
	await wait_physics_frames(2)
	var chat := CHAT_SCENE.instantiate() as GeneratedLevel
	add_child_autofree(chat)
	await wait_physics_frames(2)
	var bg41 := chat.get_node(^"Background") as World4Background
	assert_not_null(bg41, "El 4-1 usa el fondo del Mundo 4")
	assert_not_null(bg41.get_music(), "mus_w4_level (ChatMusic) en el 4-1")


func test_level_music_goes_silent_when_the_wave_switches_off() -> void:
	var room := WAVE_SCENE.instantiate() as GeneratedLevel
	add_child_autofree(room)
	await wait_physics_frames(2)
	var bg := room.get_node(^"Background") as World4Background
	assert_not_null(bg.get_music(), "Con la ola: musica del nivel")
	var wave: SeenWave = null
	for node: Node in room.find_children("*", "", true, false):
		if node is SeenWave:
			wave = node
	assert_not_null(wave, "La sala tiene ola")
	wave.state_changed.emit(SeenWave.State.MOVING)
	assert_not_null(bg.get_music(), "Moviendose sigue la musica")
	wave.state_changed.emit(SeenWave.State.OFF)
	await wait_physics_frames(1)
	assert_null(bg.get_music(), "Ola apagada: la musica se queda en silencio")


func test_new_level_lines_and_sign_in_data() -> void:
	var by_id: Dictionary = {}
	for level: String in ["4-1", "4-3"]:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels/%s.json" % level))
		for obj: Variant in data.get("objects", []):
			var params: Dictionary = (obj as Dictionary).get("params", {})
			by_id[String(params.get("id", ""))] = obj
	var torch: Dictionary = by_id.get("eco_linterna", {})
	assert_eq(String(torch.get("type", "")), "eco_line")
	assert_eq(String(torch["params"].get("trigger_event", "")), "ally_met", "Sale al conocer la Linterna")
	assert_false(bool(torch["params"].get("important", false)), "No pausa")
	assert_string_contains(String(torch["params"]["text"]), "linterna")
	var sign: Dictionary = by_id.get("cartel_en_linea", {})
	assert_eq(String(sign["params"].get("text", "")), "En línea hace 3 h")
	for id: String in ["eco_ola", "eco_cierre"]:
		assert_eq(String((by_id.get(id, {}) as Dictionary).get("type", "")), "eco_line", "%s en el 4-3" % id)
	var hub: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/hub.json"))
	var remark_ids: Array = []
	for remark: Variant in hub["calc"]["remarks"]:
		remark_ids.append(String((remark as Dictionary).get("after_level", "")))
	assert_has(remark_ids, "4-3", "Calc comenta al volver del 4-3")


func test_world4_sound_ids_with_placeholders_and_bindings() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/audio.json"))
	var sounds: Dictionary = data.get("sounds", {})
	var used: Dictionary = {}
	for section: String in ["event_bus", "nodes", "ambience"]:
		for item: Variant in data.get(section, []):
			used[String((item as Dictionary).get("sound", ""))] = true
	for id: String in W4_SOUNDS:
		assert_true(sounds.has(id), "%s en data/audio.json" % id)
		assert_true(used.has(id), "%s enganchado a una senal" % id)
		assert_true(FileAccess.file_exists("res://assets/audio/%s.wav" % id), "%s: provisional" % id)
	for id: String in ["sfx_w4_typing", "sfx_w4_seen_wave", "sfx_boss4_typing"]:
		assert_true(bool((sounds[id] as Dictionary).get("cue", false)), "%s: senal de ritmo (accesibilidad)" % id)
