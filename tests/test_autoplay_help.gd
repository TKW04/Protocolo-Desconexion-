# Textos, ayudas Q y sonidos del jefe Autoplay (paso 20 de docs/propuesta-mundo-2.md
# §8, 2026-10-23): las 7 ayudas nuevas existen en data/help.json (Mundo 2, primer
# nivel 2-boss, ficha del album) y las piezas del jefe las llevan (pantalla,
# cabezal gris, boton de pausa solo visible, tarjetas de la cinta, cuenta solo
# mientras se ve, clips solo mientras avisan o barren y el abanico de la «Cuenta
# atras»); las lineas del jefe las dice Eco por el (eco_boss, sin pausa en las
# fases y en la cura de la cuenta); mus_boss2 (AutoplayMusic) suena en la pelea y
# se quita en el golpe final; los IDs de audio de §6.4 estan en data/audio.json
# con su provisional y enganchados a una senal.
extends GutTest

const LEVEL_SCENE: PackedScene = preload("res://scenes/levels/2-boss.tscn")
const DT: float = 1.0 / 60.0
const NEW_TYPES: Array[String] = ["autoplay", "autoplay_playhead", "autoplay_pause_button", "autoplay_card",
	"autoplay_countdown", "autoplay_clip", "autoplay_fan"]
## IDs de §6.4 de la propuesta (todos con provisional de tools/gen_audio_placeholders.py).
const W2_SOUNDS: Array[String] = ["sfx_gesture_ground_pound", "sfx_w2_autoplay_start", "sfx_w2_card_crack",
	"sfx_w2_card_break", "sfx_w2_story_timer", "sfx_w2_clone_spawn", "sfx_w2_commenter_spit", "sfx_w2_scroll_speed",
	"sfx_w2_clock_skip", "amb_w2_feed", "mus_w2_level", "mus_boss2", "sfx_w2_edge_hit", "sfx_w2_loop_wrap",
	"sfx_w2_loading_wall_crack", "sfx_w2_pause_player", "sfx_boss2_intro", "sfx_boss2_clip_preview",
	"sfx_boss2_countdown", "sfx_boss2_pause", "sfx_boss2_resume"]

var _level: GeneratedLevel
var _boss: Autoplay


func before_all() -> void:
	EcoTextBox.pause_important = false


func after_all() -> void:
	EcoTextBox.pause_important = true


func before_each() -> void:
	DebugMode.input_enabled = false
	DebugMode.reset()


func after_each() -> void:
	get_tree().paused = false
	DebugMode.reset()
	DebugMode.input_enabled = true
	GameState.reset_progress()
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX


func _arena() -> void:
	_level = LEVEL_SCENE.instantiate() as GeneratedLevel
	_boss = _level.get_node(^"Objects/autoplay") as Autoplay
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
		assert_eq(int(entry.get("world", 0)), 2, "%s: carpeta del Mundo 2" % id)
		assert_eq(String(entry.get("first_level", "")), "2-boss")
		assert_false(String(entry.get("text", "")).is_empty())
		for word: String in ["vuelta", "Easy", "Normal", "Hard"]:
			assert_false(String(entry.get("text", "")).contains(word))
		assert_true(ResourceLoader.exists("res://assets/sprites/ui/album/album_card_%s.png" % id),
			"%s: ficha del album" % id)
	assert_true(catalog.types_of_level(&"2-boss").size() >= NEW_TYPES.size())


func test_boss_pieces_carry_their_help() -> void:
	await _arena()
	assert_eq(HelpCatalog.help_id_of(_boss.get_node(^"Screen")), Autoplay.HELP_SCREEN, "La pantalla: autoplay")
	assert_true(HelpCatalog.is_help_live(_boss.get_node(^"Screen")))
	var playhead: Node = _boss.get_node(^"Playhead")
	assert_eq(HelpCatalog.help_id_of(playhead), Autoplay.HELP_PLAYHEAD, "El cabezal gris")
	assert_true(HelpCatalog.is_help_live(playhead))
	for card: MovingPlatform in _boss.get_conveyor_cards():
		assert_eq(HelpCatalog.help_id_of(card), Autoplay.HELP_CARD, "Tarjetas de la cinta")
	var core: WeakPoint = _boss.get_core()
	assert_eq(HelpCatalog.help_id_of(core), Autoplay.HELP_PAUSE)
	_boss.start()
	assert_false(core.is_help_available(), "Boton oculto: sin ayuda (no delata que el cabezal es el boton)")
	core.set_mark_duration(4.0)
	core.call(&"_mark")
	assert_true(core.is_help_available(), "En pausa: se ve y tiene ayuda")


func test_clips_help_only_while_they_warn_or_sweep() -> void:
	await _arena()
	_boss.start()
	var floor_banner: Node = _boss.get_banners()["floor"]
	assert_eq(HelpCatalog.help_id_of(floor_banner), &"", "En reposo, la ola no tiene ayuda")
	_advance_until(func() -> bool: return _boss.get_clip() == Autoplay.CLIP_WAVE)
	assert_eq(HelpCatalog.help_id_of(floor_banner), Autoplay.HELP_CLIP, "La ola, mientras avisa o barre")
	_advance_until(func() -> bool: return _boss.is_window_open())
	assert_eq(HelpCatalog.help_id_of(floor_banner), &"", "Acabado el clip, sin ayuda")
	_boss.close_window()
	_advance_until(func() -> bool: return _boss.get_clip() == Autoplay.CLIP_RAYS)
	_advance(0.1)
	var tagged: int = 0
	for bell: AlarmBell in _boss.get_bells():
		if HelpCatalog.help_id_of(bell) == Autoplay.HELP_CLIP:
			tagged += 1
	assert_gt(tagged, 0, "Los rayos que avisan llevan la ayuda del clip")


func test_countdown_help_while_it_shows_and_fan_shots_tagged() -> void:
	await _arena()
	_boss.start()
	_to_phase(2)
	var marker: Node = _boss.get_node(^"CountdownHelp")
	assert_eq(HelpCatalog.help_id_of(marker), Autoplay.HELP_COUNTDOWN)
	_advance_until(func() -> bool: return _boss.get_clip() == Autoplay.CLIP_COUNTDOWN)
	assert_true(marker.call(&"is_help_available"), "«3-2-1» en pantalla: ayuda")
	_advance_until(func() -> bool: return not _boss.get_shots().is_empty(), 3.0)
	var shots: Array[NotificationShot] = _boss.get_shots()
	assert_gt(shots.size(), 0, "Abanico en vuelo")
	for shot: NotificationShot in shots:
		assert_eq(HelpCatalog.help_id_of(shot), Autoplay.HELP_FAN)
	_advance_until(func() -> bool: return _boss.is_window_open())
	assert_true(marker.call(&"is_help_available"), "«Siguiente video en N»: ayuda")
	_boss.get_core().set_mark_duration(4.0)
	_boss.get_core().call(&"_mark")
	assert_false(marker.call(&"is_help_available"), "En pausa la cuenta no corre: sin ayuda")


func test_lines_use_the_boss_speaker_without_pause() -> void:
	await _arena()
	var box := _level.get_node(^"EcoTextBox") as EcoTextBox
	var texts: Dictionary = _boss.get_config().get("texts", {})
	assert_string_contains(String(_boss.get_config().get("texts_status", "")), "PROPUESTA")
	_boss.start()
	_to_phase(2)
	assert_eq(box.get_speaker_id(), Autoplay.SPEAKER, "Eco habla por el jefe")
	assert_string_contains(box.get_text(), "el siguiente empieza solo", "Linea de la fase 2")
	assert_false(box.is_important(), "Los cambios de fase no pausan")
	assert_false(get_tree().paused)
	# La cuenta llega a 0 con un golpe que recuperar: linea de la cura, sin pausa.
	_boss.take_core_hit(1)
	watch_signals(_boss)
	_advance_until(func() -> bool: return _boss.is_window_open())
	_advance_until(func() -> bool: return not _boss.is_window_open(), 8.0)
	assert_signal_emitted_with_parameters(_boss, "line_said", [&"heal"])
	assert_false(String(texts.get("heal_line", "")).is_empty(), "Linea de la cura (propuesta)")
	assert_false(get_tree().paused, "La cura no pausa")


func test_music_during_the_fight_and_not_after_the_final_blow() -> void:
	await _arena()
	assert_null(_boss.get_music(), "Sin musica antes de empezar")
	_boss.start()
	assert_not_null(_boss.get_music(), "mus_boss2 (AutoplayMusic) en la pelea")
	var music: Node = _boss.get_music()
	assert_false(music is BossMusic, "No es BossMusic (sonaria mus_boss1)")
	while not _boss.is_defeated():
		_boss.take_core_hit(1)
	assert_null(_boss.get_music(), "Se quita en el golpe final")


func test_world2_sound_ids_with_placeholders_and_bindings() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/audio.json"))
	var sounds: Dictionary = data.get("sounds", {})
	var used: Dictionary = {}
	for section: String in ["event_bus", "nodes", "ambience"]:
		for item: Variant in data.get(section, []):
			used[String((item as Dictionary).get("sound", ""))] = true
	for id: String in W2_SOUNDS:
		assert_true(sounds.has(id), "%s en data/audio.json" % id)
		assert_true(used.has(id), "%s enganchado a una senal" % id)
		assert_true(FileAccess.file_exists("res://assets/audio/%s.wav" % id), "%s: provisional" % id)
	for id: String in ["sfx_w2_story_timer", "sfx_w2_scroll_speed", "sfx_boss2_countdown"]:
		assert_true(bool((sounds[id] as Dictionary).get("cue", false)), "%s: senal de ritmo (accesibilidad)" % id)
	assert_eq(AudioManager.blip_id_for(Autoplay.SPEAKER), &"vox_boss_eco_filter", "Blip con filtro")
