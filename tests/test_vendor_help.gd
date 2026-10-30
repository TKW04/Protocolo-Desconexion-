# Textos, ayudas Q y sonidos de El Vendedor y del Mundo 5 (paso 20 de
# docs/propuesta-mundo-5.md §8, 2026-10-29; §5.10 y §6.4): las 4 ayudas nuevas
# existen en data/help.json (Mundo 5, primer nivel 5-boss, ficha del album) y las
# piezas del jefe las llevan (la maquina toda la pelea; cada etiqueta en la fase 1
# mientras se puede pagar; el ticket de devolucion lanzado; el cartel de la oferta
# en la fase 3); las lineas del jefe las dice Eco por el (sin pausa en las fases) e
# Isak contesta la intro; mus_boss5 (VendorMusic) suena en la pelea y se quita en
# el golpe final; el escaparate roto avisa (showcase_broken); los IDs de audio del
# Mundo 5 estan en data/audio.json con su provisional y enganchados a una senal;
# los niveles del Mundo 5 llevan su ambiente y, fuera de la arena, la musica del
# nivel; Calc comenta la victoria y la pared lleva sus carteles.
extends GutTest

const LEVEL_SCENE: PackedScene = preload("res://scenes/levels/5-boss.tscn")
const MALL_SCENE: PackedScene = preload("res://scenes/levels/5-1.tscn")
const DT: float = 1.0 / 60.0
const TILE: float = 64.0
const NEW_TYPES: Array[String] = ["vendor_boss", "priced_platform", "vendor_ticket", "vendor_offer"]
## IDs de §6.4 de la propuesta (todos con provisional de tools/gen_audio_placeholders.py).
const W5_SOUNDS: Array[String] = ["sfx_w5_temptation_pull", "sfx_w5_box_open_good", "sfx_w5_box_open_bad",
	"sfx_w5_subscription_attach", "sfx_w5_subscription_drain", "sfx_w5_subscription_cancel", "sfx_w5_pay",
	"sfx_w5_countdown", "amb_w5_mall", "mus_w5_level", "mus_boss5", "sfx_combo_ram", "sfx_combo_edge",
	"sfx_combo_quake", "sfx_combo_denied", "sfx_w5_shutter_break", "sfx_w5_shelf_restock", "sfx_w5_shelf_fall",
	"sfx_w5_terms_accept", "sfx_w5_terms_reject", "sfx_w5_free_trial", "sfx_w5_refund", "sfx_w5_wishlist_add",
	"sfx_boss5_intro", "sfx_boss5_turn", "sfx_boss5_throw", "sfx_boss5_processing", "sfx_boss5_glass_break",
	"sfx_hub_photo_complete", "sfx_hub_lock_open"]

var _level: GeneratedLevel
var _boss: Vendor


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
	_boss = _level.get_node(^"Objects/vendor") as Vendor
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


func _to_phase(phase: int) -> void:
	while _boss.get_phase() < phase:
		_boss.take_core_hit(1)


func test_help_types_exist_with_album_cards() -> void:
	var catalog: HelpCatalog = HelpCatalog.shared()
	for id: String in NEW_TYPES:
		assert_true(catalog.has(StringName(id)), "%s en data/help.json" % id)
		var entry: Dictionary = catalog.entry(StringName(id))
		assert_eq(int(entry.get("world", 0)), 5, "%s: carpeta del Mundo 5" % id)
		assert_eq(String(entry.get("first_level", "")), "5-boss")
		assert_false(String(entry.get("text", "")).is_empty())
		assert_string_contains(String(entry.get("_notes", "")), "PROPUESTO")
		for word: String in ["vuelta", "Easy", "Normal", "Hard"]:
			assert_false(String(entry.get("text", "")).contains(word))
		assert_true(ResourceLoader.exists("res://assets/sprites/ui/album/album_card_%s.png" % id),
			"%s: ficha del album" % id)
	assert_true(catalog.types_of_level(&"5-boss").size() >= NEW_TYPES.size())
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/bosses/vendor.json"))
	assert_eq((cfg.get("help", {}) as Dictionary).size(), NEW_TYPES.size())


func test_machine_help_all_fight_and_not_after_the_final_blow() -> void:
	await _arena()
	var body: Node = _boss.get_node(^"BodyHelp")
	assert_eq(HelpCatalog.help_id_of(body), Vendor.HELP_BOSS, "La maquina: vendor_boss")
	assert_true(HelpCatalog.is_help_live(body), "Antes de la pelea se ve")
	assert_almost_eq((body as Node2D).global_position, _boss.get_machine_rect().get_center(), Vector2(1.0, 1.0))
	_boss.start()
	_to_phase(3)
	assert_true(body.call(&"is_help_available"), "En la fase 3 tambien")
	while not _boss.is_defeated():
		_boss.take_core_hit(1)
	assert_false(body.call(&"is_help_available"), "Tras el golpe final: sin ayuda")


func test_label_help_only_while_it_can_be_paid() -> void:
	await _arena()
	var marker: Node = _boss.get_node(^"PlatformHelp_a")
	assert_eq(HelpCatalog.help_id_of(marker), Vendor.HELP_PLATFORM)
	assert_false(marker.call(&"is_help_available"), "Sin pelea, sin ayuda")
	_boss.start()
	assert_true(marker.call(&"is_help_available"), "Fase 1, sin pagar: ayuda")
	assert_almost_eq((marker as Node2D).global_position, _boss.get_label_rect("a").get_center(), Vector2(1.0, 1.0))
	assert_true(_boss.pay_platform("a"))
	assert_false(marker.call(&"is_help_available"), "Pagada: sin ayuda")
	_boss.take_core_hit(1)
	assert_true(_boss.is_restocking())
	assert_false(_boss.get_node(^"PlatformHelp_b").call(&"is_help_available"), "Reponiendo: sin ayuda")
	_to_phase(2)
	assert_false(_boss.get_node(^"PlatformHelp_b").call(&"is_help_available"), "Fase 2: sin ayuda")


func test_ticket_and_offer_helps() -> void:
	await _arena()
	_boss.start()
	var offer: Node = _boss.get_node(^"OfferHelp")
	assert_eq(HelpCatalog.help_id_of(offer), Vendor.HELP_OFFER)
	assert_false(offer.call(&"is_help_available"), "Fase 1: sin oferta")
	_to_phase(2)
	var ticket: SurpriseBox = _boss.spawn_box(6, 10, SurpriseBox.CONTENT_TICKET)
	var bomb: SurpriseBox = _boss.spawn_box(13, 10, SurpriseBox.CONTENT_BOMB)
	assert_eq(HelpCatalog.help_id_of(ticket), Vendor.HELP_TICKET, "El ticket lanzado: vendor_ticket")
	assert_ne(HelpCatalog.help_id_of(bomb), Vendor.HELP_TICKET, "La bomba no lo es")
	_to_phase(3)
	assert_true(offer.call(&"is_help_available"), "Fase 3: el cartel de la oferta")
	assert_almost_eq((offer as Node2D).global_position, _boss.get_offer_sign_rect().get_center(), Vector2(1.0, 1.0))


func test_lines_boss_speaker_and_isak_answers_the_intro() -> void:
	await _arena()
	var box := _level.get_node(^"EcoTextBox") as EcoTextBox
	var texts: Dictionary = _boss.get_config().get("texts", {})
	assert_string_contains(String(_boss.get_config().get("texts_status", "")), "PROPUESTA")
	assert_string_contains(String(texts.get("intro", "")), "{apodo}", "La intro lleva el apodo")
	for key: String in ["intro", "isak_intro", "final_system", "defeat"]:
		assert_false(String(texts.get(key, "")).is_empty(), "Texto %s" % key)
	assert_eq(((texts.get("signs", {}) as Dictionary).get("wall", []) as Array).size(), 2, "Dos carteles en la pared")
	var speakers: Array = []
	box.line_started.connect(func(_t: String, speaker: StringName) -> void: speakers.append(speaker))
	_boss.begin_intro()
	await wait_physics_frames(2)
	assert_eq(box.get_speaker_id(), BossBase.SPEAKER, "La intro la dice Eco por el jefe")
	assert_false(_boss.is_fighting(), "Aun no empieza")
	# Se cierra la intro (como al aceptar).
	box.emit_signal(&"line_finished", BossBase.SPEAKER)
	await wait_physics_frames(2)
	assert_false(_boss.is_fighting(), "Antes, Isak contesta")
	assert_true(speakers.has(Vendor.SPEAKER_ISAK), "Isak contesta")
	box.emit_signal(&"line_finished", Vendor.SPEAKER_ISAK)
	await wait_physics_frames(1)
	assert_true(_boss.is_fighting(), "Tras la respuesta de Isak empieza la pelea")


func test_phase_lines_by_the_boss_without_pause() -> void:
	await _arena()
	var box := _level.get_node(^"EcoTextBox") as EcoTextBox
	_boss.start()
	_to_phase(2)
	assert_eq(box.get_speaker_id(), BossBase.SPEAKER, "Eco habla por el jefe")
	assert_string_contains(box.get_text(), "sorpresa", "Linea de la fase 2")
	assert_false(box.is_important(), "Los cambios de fase no pausan")


func test_music_during_the_fight_and_not_after_the_final_blow() -> void:
	await _arena()
	assert_null(_boss.get_music(), "Sin musica antes de empezar")
	_boss.start()
	var music: Node = _boss.get_music()
	assert_not_null(music, "mus_boss5 (VendorMusic) en la pelea")
	assert_false(music is SeenMusic or music is CuratorMusic, "Solo mus_boss5")
	while not _boss.is_defeated():
		_boss.take_core_hit(1)
	assert_null(_boss.get_music(), "Se quita en el golpe final")


func test_showcase_broken_signal() -> void:
	await _arena()
	_boss.start()
	_to_phase(3)
	var got: Array = []
	_boss.showcase_broken.connect(func() -> void: got.append(true))
	var shutter: Shutter = _boss.get_shutter()
	EventBus.combo_landed.emit(Isak.COMBO_RAM, shutter.get_shutter_rect().grow(8.0), _level.get_isak())
	assert_true(shutter.is_broken())
	assert_eq(got, [true], "El escaparate roto avisa (sfx_boss5_glass_break)")


func test_mall_background_ambience_and_level_music_outside_the_arena() -> void:
	await _arena()
	var bg := _level.get_node(^"Background") as World5Background
	assert_not_null(bg, "La arena usa el fondo del Mundo 5 (amb_w5_mall)")
	await wait_physics_frames(1)
	assert_null(bg.get_music(), "En la arena no suena la musica del nivel (manda mus_boss5)")
	_level.queue_free()
	_boss = null
	await wait_physics_frames(2)
	var mall := MALL_SCENE.instantiate() as GeneratedLevel
	add_child_autofree(mall)
	await wait_physics_frames(2)
	var bg51 := mall.get_node(^"Background") as World5Background
	assert_not_null(bg51, "El 5-1 usa el fondo del Mundo 5")
	assert_not_null(bg51.get_music(), "mus_w5_level (MallMusic) en el 5-1")


func test_calc_remarks_the_victory() -> void:
	var hub: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/hub.json"))
	var found: Dictionary = {}
	for r: Variant in (hub.get("calc", {}) as Dictionary).get("remarks", []):
		if String((r as Dictionary).get("after_level", "")) == "5-boss":
			found = r
	assert_false(found.is_empty(), "Calc comenta al volver de El Vendedor")
	assert_false(String(found.get("text", "")).is_empty())


func test_world5_sound_ids_with_placeholders_and_bindings() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/audio.json"))
	var sounds: Dictionary = data.get("sounds", {})
	var used: Dictionary = {}
	for section: String in ["event_bus", "nodes", "ambience"]:
		for item: Variant in data.get(section, []):
			used[String((item as Dictionary).get("sound", ""))] = true
	for id: String in W5_SOUNDS:
		assert_true(sounds.has(id), "%s en data/audio.json" % id)
		assert_true(used.has(id), "%s enganchado a una senal" % id)
		assert_true(FileAccess.file_exists("res://assets/audio/%s.wav" % id), "%s: provisional" % id)
	for id: String in ["sfx_w5_countdown", "sfx_boss5_turn", "sfx_w5_temptation_pull"]:
		assert_true(bool((sounds[id] as Dictionary).get("cue", false)), "%s: senal de ritmo (accesibilidad)" % id)
	var bindings: Array = []
	for item: Variant in data.get("nodes", []):
		var d: Dictionary = item
		bindings.append("%s.%s" % [d.get("class", ""), d.get("signal", "")])
	for b: String in ["HubRoom.wallpaper_completed", "FolderStation.lock_opened", "Vendor.turn_warned",
			"Vendor.shelf_restocked", "Vendor.showcase_broken"]:
		assert_true(bindings.has(b), "%s enganchado" % b)
